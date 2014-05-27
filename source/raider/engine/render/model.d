module raider.engine.render.model;

import raider.math.all;

import raider.engine.game.layer;
import raider.engine.physics.collider;
import raider.engine.physics.ode;
import raider.engine.render.armature;
import raider.engine.render.material;
import raider.engine.render.mesh;
import raider.engine.tool.reference;

/**
 * An instance of a mesh.
 * 
 * A model turns a mesh into something presentable by adding 
 * transform, materials, colour modulation and blending.
 */
class Model
{package:
	W!Layer layer;
	R!Mesh mesh;
	dGeomID geom;

public:
	this(W!Layer layer, R!Mesh mesh, double radius)
	{
		this.layer = layer;
		this.mesh = mesh;
		geom = dCreateSphere(layer.modelSpace, radius);
	}

	~this()
	{
		dGeomDestroy(geom);
	}

	@property void radius(double value) { dGeomSphereSetRadius(geom, value); }
	@property vec3 position() { return vec3(dGeomGetPosition(geom)); }
	@property void position(vec3 value) { dGeomSetPosition(geom, value[0], value[1], value[2]); }
	@property mat3 orientation() { mat3 r; convert(dGeomGetRotation(geom)[0..12], r); return r; }
	@property void orientation(mat3 value) { dMatrix3 d; convert(value, d); dGeomSetRotation(geom, d); }
	@property mat4 transform() { return mat4(orientation, position); }

	vec4 colour;
	Array!(R!Material) materials; 

	/*enum BlendMode
	{
		Opaque,	//Enable depth write
		Add,	//Disable depth write, additive blending
		Alpha	//Disable depth write, sort faces by Z, enable backfaces, draw last
	}*/


	/**
	 * Enable model for rendering in a layer.
	 * 
	 * Has no effect if already enabled.
	 */
	void enable(W!Layer layer)
	{
		assert(layer);

		if(this.layer == layer)
		{
			dGeomEnable(geom);
		}
		else
		{
			this.layer = layer;
			double radius = dGeomSphereGetRadius(geom);
			dGeomDestroy(geom);
			geom = dCreateSphere(layer.modelSpace, radius);
		}
	}
	
	/**
	 * Disable model rendering.
	 * 
	 * This removes the model from frustum and lighting checks.
	 * Disable models whenever your personal machinations can 
	 * prove they are invisible.
	 * 
	 * Has no effect if already disabled.
	 */
	void disableModel()
	{
		dGeomDisable(geom);
	}
}

