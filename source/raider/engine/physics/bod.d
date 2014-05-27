module raider.engine.physics.bod;

import raider.math.all;
import raider.engine.physics.ode;
import raider.engine.physics.world;
import raider.engine.tool.reference;

/**
 * A dynamic mass.
 * 
 * Bodies are clothed in shapes to create rigidbodies.
 * 
 * A body must not outlive the World it inhabits.
 */
final class Body
{package:
	dBodyID dbody;
	Array!(R!Shape) shapes; 

public:
	this(W!World world)
	{
		dbody = dBodyCreate(world.dworld);
	}

	~this()
	{
		dBodyDestroy(dbody);
	}

	///Get the total mass of the body.
	@property double mass()
	{
		dMass m; dBodyGetMass(dbody, &m);
		return m.mass;
	}

	///Set the total mass of the body.
	@property void mass(double value)
	{
		dMass m; dBodyGetMass(dbody, &m);
		m.mass = value;
		dBodySetMass(dbody, &m);
	}

	///Set the mass shape to a sphere.
	void setSphereMass(double radius)
	{
		dMass m; dBodyGetMass(dbody, &m);
		dMassSetSphereTotal(&m, m.mass, radius);
		dBodySetMass(dbody, &m);
	}

	///Set the mass shape to a box.
	void setBoxMass(vec3 dim)
	{
		dMass m; dBodyGetMass(dbody, &m);
		dMassSetBoxTotal(&m, m.mass, dim[0], dim[1], dim[2]);
		dBodySetMass(dbody, &m);
	}

	@property bool kinematic() { return cast(bool)dBodyIsKinematic(dbody); }
	@property void kinematic(bool value) { if(value) dBodySetKinematic(dbody); else dBodySetDynamic(dbody); }
	@property vec3 position() { return vec3(dBodyGetPosition(dbody)); }
	@property void position(vec3 value) { dBodySetPosition(dbody, value[0], value[1], value[2]); }
	@property mat3 orientation() { mat3 r; convert(dBodyGetRotation(dbody)[0..12], r); return r; }
	@property void orientation(mat3 value) { dMatrix3 d; convert(value, d); dBodySetRotation(dbody, d); }
	@property mat4 transform() { return mat4(orientation, position); }
	@property vec3 velocity() { return vec3(dBodyGetLinearVel(dbody)); }
	@property void velocity(vec3 value) { dBodySetLinearVel(dbody, value[0], value[1], value[2]); }
	@property vec3 localVelocity() { return orientation * velocity; }
	@property void localVelocity(vec3 value) { velocity = value * orientation; }
	@property vec3 angularVelocity() { return vec3(dBodyGetAngularVel(dbody)); }
	@property void angularVelocity(vec3 value) { dBodySetAngularVel(dbody, value[0], value[1], value[2]); }
	@property vec3 localAngularVelocity() { return orientation * angularVelocity; }
	@property void localAngularVelocity(vec3 value) { angularVelocity = value * orientation; }

	vec3 getVelocityAt(vec3 point, bool localPoint = true)
	{
		return velocity + angularVelocity.cross(localPoint ? point * orientation : point - position);
	}

	void applyForce(vec3 f, vec3 pos = vec3(0,0,0), bool localForce = false, bool localPos = true)
	{
		if(pos == vec3(0,0,0))
			if (localForce) dBodyAddRelForce(dbody, f[0], f[1], f[2]);
			else dBodyAddForce(dbody, f[0], f[1], f[2]);
		else
			if (localForce)
				if (localPos) dBodyAddRelForceAtRelPos(dbody, f[0], f[1], f[2], pos[0], pos[1], pos[2]);
				else dBodyAddRelForceAtPos(dbody, f[0], f[1], f[2], pos[0], pos[1], pos[2]);
			else
				if (localPos) dBodyAddForceAtRelPos(dbody, f[0], f[1], f[2], pos[0], pos[1], pos[2]);
				else dBodyAddForceAtPos(dbody, f[0], f[1], f[2], pos[0], pos[1], pos[2]);
	}

	void applyTorque(vec3 t, bool localTorque)
	{
		if(localTorque) dBodyAddRelTorque(dbody, t[0], t[1], t[2]);
		else dBodyAddTorque(dbody, t[0], t[1], t[2]);
	}
}