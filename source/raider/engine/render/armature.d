module raider.engine.render.armature;

import raider.math.mat;
import raider.engine.render.mesh;
import raider.engine.tool.array;
import raider.engine.tool.reference;

struct Bone
{
	string name;
	Bone parent;
}

struct BoneTransform
{
	mat4 local; //Relative to parent
	mat4 pose; //Relative to armature root
}

/**
 * A hierarchy of named transformations.
 */
class Armature
{
	R!(Array!Bone) bones;
	R!(Array!BoneTransform) transforms;

	this()
	{
		//..
	}

	void doConstraints()
	{
		//um
	}
}

class Binding
{
	R!(Array!Bone) bones;
	R!(Array!Group) groups;
	Array!uint links;
}

R!Binding bind(R!(Array!Bone) bones, R!(Array!Group) groups)
{
	R!Binding binding = New!Binding();
	binding.bones = bones;
	binding.groups = groups;

	//Match names. Need predicate-based Array search :I Like std.algorithm.find.

	return binding;
}

void deform(R!Mesh mesh, R!Mesh dest, R!Armature armature, R!Binding binding)
{
	assert(armature.bones is binding.bones);
	assert(mesh.groups is binding.groups);
	assert(dest.groups is binding.groups);

	//Do deformation!
}

//void deform(R!Armature armature, R!Armature dest, animation stuff)

/* Miscellaneous ramblings
When a bone transform is changed, a flag is set that indicates 
children are invalid. Getting pose transform requires recursion 
into parents. Must find deepest flagged parent and recalculate.

How to do armatures:

1. Load basis mesh.
2. Load basis armature.
3. Create presentable mesh linked to basis except for vertices.
4. Create presentable armature linked to basis except for bone transforms.
5. Bind mesh groups to armature bones.
6. Deform armature with animations.
7. Deform mesh with armature and binding.

*/

