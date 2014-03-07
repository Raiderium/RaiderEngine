module render.armature;

import mat;

/*
 * An armature is a hierarchy of transformations.
 */
class Armature
{
	Bone[] bones;

	this()
	{
		// Constructor code
	}

	void doConstraints()
	{
		//Uuuh.
		//IK, stretch-to, angle limits? TODO Stare at Blender for a couple of hours to gain inspiration.
	}
}

class Bone
{
	Bone parent;
	mat4 localTransform;	//Relative to parent
	mat4 poseTransform;		//Relative to armature root
}

/* Miscellaneous ramblings
When an object's local transform is changed, a flag is set that indicates the children of the object do not contain the correct global transform.
When global transform is set, the parent global transform is requested so that the local transform can be set. (Which then sets the flag.)
The most complex action is requesting global transform. The function traces all parents to the root object. If it encounters any objects with the flag set, it finds the one closest to the root, and recalculates all child transforms recursively. (This is a separate function.)
*/

