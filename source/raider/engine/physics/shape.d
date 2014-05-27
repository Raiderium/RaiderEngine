module raider.engine.physics.shape;

import raider.math.all;
import raider.engine.physics.bod;
import raider.engine.physics.collider;
import raider.engine.physics.ode;
import raider.engine.physics.world;
import raider.engine.render.mesh;
import raider.engine.tool.reference;

/*
 * Body geometry element.
 * 
 * A shape must not outlive its body.
 */
final class Shape
{package:
	W!Body _body;
	R!Collider _collider;
	dGeomID dgeom;
	dTriMeshDataID tmdata;

public:
	double friction;    /// Coloumb coefficient of friction for this shape.
	double restitution; /// Restitution, or 'bounciness' of collisions for this shape.
	double erp;         /// Error reduction parameter for contact joints
	double cfm;         /// Constraint force mixing for contact joints

	//TODO Surface types for automatic collision effects (sparks, dirt clumps, sounds, etc).

	this(W!Body bod, R!Collider collider = null)
	{
		_body = bod;
		_collider = collider;
		dgeom = null;
		tmdata = null;

		friction = 1.0;
		restitution = 0.0;
		erp = 0.2;
		cfm = 0.0;
	}

	this(W!World world)
	{
		this(world.staticBody);
	}

	~this()
	{
		reset;
	}

	@property vec3 position() { return vec3(dGeomGetOffsetPosition(dgeom)); }
	@property void position(vec3 value) { dGeomSetOffsetPosition(dgeom, value[0], value[1], value[2]); }
	@property mat3 orientation() { mat3 r; convert(dGeomGetOffsetRotation(dgeom)[0..12], r); return r; }
	@property void orientation(mat3 value) { dMatrix3 d; convert(value, d); dGeomSetOffsetRotation(dgeom, d); }

	private void reset()
	{
		if(tmdata) dGeomTriMeshDataDestroy(tmdata);
		if(dgeom) dGeomDestroy(dgeom);
		tmdata = null;
		dgeom = null;
	}

	void setConvexHull(vec3[] points)
	{
		reset;
		//TODO Implement convex hull
	}

	void setTriangleMesh(vec3[] verts, TriFace[] tris)
	{
		reset;

		//Build TriMeshData 
		tmdata = dGeomTriMeshDataCreate();
		dGeomTriMeshDataBuildDouble(tmdata,
		cast(const(void)*)verts.ptr, vec3.sizeof, verts.length,
		cast(const(void)*)tris.ptr, tris.length*3, Face.sizeof);

		//Make the geom
		dgeom = dCreateTriMesh(_body._world.dspace, tmdata, null, null, null);
		dGeomSetBody(dgeom, _body.dbody);
		dGeomSetData(dgeom, cast(void)* this);
	}

	void setCube(vec3 dim)
	{
		reset;

		dgeom = dCreateBox(_body._world.dspace, dim[0], dim[1], dim[2]);
		dGeomSetBody(dgeom, _body.dbody);
		dGeomSetData(dgeom, cast(void)* this);
	}

	void setSphere(double radius)
	{
		reset;

		dgeom = dCreateSphere(_body._world.dspace, radius);
		dGeomSetBody(dgeom, _body.dbody);
		dGeomSetData(dgeom, cast(void)* this);
	}

	/**
	 * Set ERP/CFM such that contacts behave like springs,
	 * with spring constant k (N/m) and damping coefficient d (N*s/m).
	 */
	void setSpringDamp(double timestep, double k, double d)
	{
		double tk = timestep*k;
		double tk_d = tk + d;
		if(tk_d != 0.0)
		{
			erp = tk / (tk_d);
			cfm = 1.0 / (tk_d);
		}
	}
}