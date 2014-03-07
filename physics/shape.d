module physics.shape;

import rm;
import physics.bod;
import physics.collider;
import physics.ode;
import physics.world;
import render.mesh;

final class Shape
{package:
	Body _body;
	dGeomID dgeom;
	dTriMeshDataID tmdata;
public:
	Collider collider;
	//Surface properties
	double friction;    /// Coloumb coefficient of friction for this shape.
	double restitution; /// Restitution, or 'bounciness' of collisions for this shape.
	double erp;         /// Error reduction parameter for contact joints
	double cfm;         /// Constraint force mixing for contact joints

	this(Body bod)
	{
		_body = bod;
		dgeom = null;
		collider = null;
		tmdata = null;

		friction = 1.0;
		restitution = 0.0;
		erp = 0.2;
		cfm = 0.0;
	}

	this(World world)
	{
		this(world.staticBody);
	}

	void destruct()
	{
		reset;
	}

	@property vec3 position() { return vec3(dGeomGetOffsetPosition(dgeom)); }
	@property void position(vec3 value) { dGeomSetOffsetPosition(dgeom, value[0], value[1], value[2]); }
	@property mat3 orientation() { mat3 r; convert(dGeomGetOffsetRotation(dgeom)[0..12], r); return r; }
	@property void orientation(mat3 value) { dMatrix3 d; convert(value, d); dGeomSetOffsetRotation(dgeom, d); }

	///Destroy the dgeom so a new one can be created. Called automatically when necessary.
	void reset()
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

	void setTriangleMesh(vec3[] verts, Face[] tris)
	{
		reset;

		tmdata = dGeomTriMeshDataCreate();
		dGeomTriMeshDataBuildDouble(tmdata,
		cast(const(void)*)verts.ptr, vec3.sizeof, verts.length,
		cast(const(void)*)tris.ptr, tris.length*3, Face.sizeof);
		dgeom = dCreateTriMesh(_body._world.dspace, tmdata, null, null, null);
		dGeomSetBody(dgeom, _body.dbody);
		dGeomSetData(dgeom, cast(void*)this); 
	}

	void setCube(vec3 dim)
	{
		reset;

		dgeom = dCreateBox(_body._world.dspace, dim[0], dim[1], dim[2]);
		dGeomSetBody(dgeom, _body.dbody);
		dGeomSetData(dgeom, cast(void*)this);
	}

	void setSphere(double radius)
	{
		reset;

		dgeom = dCreateSphere(_body._world.dspace, radius);
		dGeomSetBody(dgeom, _body.dbody);
		dGeomSetData(dgeom, cast(void*)this);
	}

	///Set ERP/CFM such that contacts behave like a spring, with spring constant (N/m) k and damping coefficient d (N*s/m).
	void setSpringDamp(double k, double d)
	{
		double tk = 0.0;//_body._world.timestep*k; TODO Fix
		double tk_d = tk + d;
		if(tk_d != 0.0)
		{
			erp = tk / (tk_d);
			cfm = 1.0 / (tk_d);
		}
	}
}