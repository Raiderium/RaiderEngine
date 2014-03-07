module render.model;

import mat;
import vec;

import game.layer;
import physics.collider;
import physics.ode;
import render.armature;
import render.material;
import render.mesh;
import tool.container;

/**
 * An instance of a mesh.
 * 
 * A model turns a mesh into something presentable by adding 
 * transform, mirroring, armature / shape key deformation,
 * subdivision surfacing, textures, materials, colour and shaders.
 * 
 * TODO Reconsider Model's purpose. Deformation is now controlled by Entity.draw
 * for greater parallelism. Model should simply conduct mesh data to the drawing
 * system (acting as an instance of the mesh, as the brief says), with the added
 * feature of maintaining frustum check geometry.
 */
class Model
{package:
	mixin(SListItem!("layerEnabledModels"));
	mixin(SListItem!("layerObservedModels"));
	Mesh mesh;
public:
	//Uh.. still gotta figure this out.
	mat4 transform;
	vec4 colour;
	//Material[] materials; 
	//Armature armature;
	//bool mirrorX, mirrorY, mirrorZ;
	//uint subdivisionLevel;
	Layer enabledLayer;

	/*enum BlendMode
	{
		Opaque,	//Enable depth write
		Add,	//Disable depth write, additive blending
		Alpha	//Disable depth write, sort faces by Z, enable backfaces, draw last
	}*/
}

