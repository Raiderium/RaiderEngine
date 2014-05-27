module raider.engine.physics.world;

import raider.math.all;
import raider.engine.physics.bod;
import raider.engine.physics.collider;
import raider.engine.physics.ode;
import raider.engine.physics.shape;
import raider.engine.tool.reference;

/**
 * Physical world encapsulating both collision and dynamics.
 */

class World
{package:
	dWorldID dworld;
	dSpaceID dspace;
	dJointGroupID contactGroup;
	R!Body staticBody;
	int _pairs;
public:

	@property int pairs() { return _pairs; }
	immutable static uint maxContactsPerPair = 8;

	this()
	{
		dworld = dWorldCreate();

		gravity = vec3(0,0,-9.81);

		dspace = dSweepAndPruneSpaceCreate(null, dSAP_AXES_XYZ);
		dSpaceSetCleanup(dspace, 1); 
		
		contactGroup = dJointGroupCreate(0);

		staticBody = New!Body(this);
		staticBody.kinematic = true;
	}

	~this()
	{
		assert(dSpaceGetNumGeoms(dspace) == 0);
		dJointGroupDestroy(contactGroup);
		dWorldDestroy(dworld);
		dSpaceDestroy(dspace);
	}

	void step(double dt)
	{
		dJointGroupEmpty(contactGroup);
		dSpaceCollide(dspace, cast(void*)this, &nearCallback);
		/* Dance the */ dWorldQuickStep(dworld, dt);
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
			if (dGeomIsSpace(o1)) dSpaceCollide(cast(dSpaceID)o1, data, &nearCallback);
			if (dGeomIsSpace(o2)) dSpaceCollide(cast(dSpaceID)o2, data, &nearCallback);
		}
		else
		{
			// BROADPHASE

			//Colliding two non-space geoms. Get associated shapes.
			W!Shape s1 = cast(Shape)dGeomGetData(o1);
			W!Shape s2 = cast(Shape)dGeomGetData(o2);
			
			W!Collider c1 = s1.collider;
			W!Collider c2 = s2.collider;

			Collider.Result r1 = Collider.Accept;
			Collider.Result r2 = Collider.Accept;

			//Both near callbacks must agree to do narrowphase.
			if(c1) r1 = c1.near(s1, s2);
			if(c2) r2 = c2.near(s2, s1);

			if(r1 && r2)
			{
				// NARROWPHASE
				W!World world = cast(World)data;
				world._pairs++;

				//Find contacts
				dContact[maxContactsPerPair] contactArray; 
				int numContacts = dCollide(o1, o2, contactArray.length, &(contactArray[0].geom), dContact.sizeof);
				
				//Process contacts
				for(int x=0; x<numContacts; x++)
				{
					dContact c = contactArray[x];

					//Copy position and normal data
					vec3 pos = vec3(c.geom.pos);
					vec3 nor = vec3(c.geom.normal);
					
					//Both contact callbacks must agree for the contact to be created
					if(r1 == Collider.Inspect) r1 = c1.contact(pos, nor);
					if(r2 == Collider.Inspect) r2 = c2.contact(pos, -nor);

					// CONTACT REGISTRATION
					if(r1 && r2)
					{
						//Surface properties
						c.surface.mode = dContactBounce | dContactApprox1 | dContactSoftCFM | dContactSoftERP;
						c.surface.mu = s1.friction * s2.friction;
						c.surface.bounce = s1.restitution * s2.restitution;
						c.surface.bounce_vel = 0.001;
						
						c.surface.soft_erp = (s1.erp + s2.erp) / 2.0;
						c.surface.soft_cfm = s1.cfm + s2.cfm;

						dJointID j = dJointCreateContact(world.dworld, world.contactGroup, &c);
						dJointAttach(j, s1._body.dbody, s2._body.dbody);

						//Feedback setup
						if(r1 == Collider.Inspect || r2 == Collider.Inspect)
						{
							//TODO Contact force feedback.
							//dJointSetFeedback()
						}//whee
					}//eee
				}//eee
			}//hee
		}//eee
	}//ee
}//eeee

