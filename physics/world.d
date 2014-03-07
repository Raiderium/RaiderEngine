module physics.world;

import rm;
import physics.bod;
import physics.collider;
import physics.ode;
import physics.shape;
import tool.memory;

/**
 * Physical world encapsulating both collision and dynamics.
 * 
 * A world must outlive any bodies created in it.
 */

class World
{package:
	dWorldID dworld;
	dSpaceID dspace;
	dJointGroupID contactGroup;
	Body staticBody;
	int _pairs;
public:

	@property int pairs() { return _pairs; }
	immutable uint maxContactsPerPair = 8;

	this()
	{
		dworld = dWorldCreate();

		gravity = vec3(0,0,-9.81);

		//Setup space
		dspace = dSweepAndPruneSpaceCreate(null, dSAP_AXES_XYZ);
		dSpaceSetCleanup(dspace, 1); 

		//Setup contact constraint group
		contactGroup = dJointGroupCreate(0);
		staticBody = New!Body(this);
		staticBody.kinematic = true;
	}

	~this()
	{
		Delete(staticBody);
		dJointGroupDestroy(contactGroup);
		dWorldDestroy(dworld);
		dSpaceDestroy(dspace);
	}

	void step(double dt)
	{
		dJointGroupEmpty(contactGroup);
		dSpaceCollide(dspace, cast(void*)this, &nearCallback);
		//Dance the
		dWorldQuickStep(dworld, dt);
	}

	@property void gravity(vec3 value)
	{
		dWorldSetGravity(dworld, value[0], value[1], value[2]);
	}

	@property vec3 gravity()
	{
		dVector3 g;
		dWorldGetGravity(dworld, g);
		return vec3(g[0], g[1], g[2]);
	}

private:
	extern(C) static void nearCallback(void* data, dGeomID o1, dGeomID o2) nothrow
	{
		if (dGeomIsSpace(o1) || dGeomIsSpace (o2))
		{
			//Colliding a space with something
			dSpaceCollide2(o1, o2, data, &nearCallback);
			
			//Collide all geoms internal to the space(s)
			if (dGeomIsSpace(o1)) dSpaceCollide (cast(dSpaceID)o1, data, &nearCallback);
			if (dGeomIsSpace(o2)) dSpaceCollide(cast(dSpaceID)o2, data, &nearCallback);
		}
		else
		{
			//Colliding two non-space geoms. Get associated shapes.
			Shape s1 = *cast(Shape*)dGeomGetData(o1);
			Shape s2 = *cast(Shape*)dGeomGetData(o2);
			
			Collider c1 = s1.collider;
			Collider c2 = s2.collider;
			
			c1.shapeA = c2.shapeB = s1;
			c2.shapeA = c1.shapeB = s2;
			
			bool doNarrow = true;
			
			//Both broad callbacks must agree for contact generation to go ahead
			if(c1) doNarrow &= c1.broad(c2);
			if(c2) doNarrow &= c2.broad(c1);
			
			if(doNarrow)
			{
				//Find contacts between o1 and o2
				World world = *cast(World*)data;
				world._pairs++;

				dContact[maxContactsPerPair] contactArray; 
				int numContacts = dCollide(o1, o2, contactArray.length, &(contactArray[0].geom), dContact.sizeof);
				
				//Process contacts
				for(int x=0; x<numContacts; x++)
				{
					dContact c = contactArray[x];

					//Surface properties
					c.surface.mode = dContactBounce | dContactApprox1 | dContactSoftCFM | dContactSoftERP;
					c.surface.mu =     s1.friction * s2.friction;
					c.surface.bounce = s1.restitution * s2.restitution;
					c.surface.bounce_vel = 0.001;
					
					c.surface.soft_erp = (s1.erp + s2.erp) / 2.0;
					c.surface.soft_cfm = s1.cfm + s2.cfm;
					
					//Copy position and normal data
					vec3 pos = vec3(c.geom.pos);
					vec3 nor = vec3(c.geom.normal);
					
					bool doContact = true;

					//Both contact callbacks must agree for the contact to be created
					if(c1) doContact &= c1.contact(c2, pos, nor);
					if(c2) doContact &= c2.contact(c1, pos, -nor);

					if(doContact)
					{
						dJointID j = dJointCreateContact(world.dworld, world.contactGroup, &c);
						dJointAttach(j, s1._body.dbody, s2._body.dbody);
					}
				}
			}
		}
	}
}

