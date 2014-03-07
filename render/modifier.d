module render.modifier;

import std.bitmanip;

/**
 * @brief Base for modifiers.
 * 
 * Modifiers implement a process or algorithm that is applied to a mesh.
 * They are applied in a tree structure, where a Model attaches to a leaf
 * 
 * With respect to optimisation, there are two types of modifier: pure and impure.
 * A pure modifier returns a new, arbitrary mesh, and does not touch the input.
 * An impure modifier can modify the input mesh, though it must not alter array sizes.
 * 
 * 
 * 
 * A modifier may create and return a new mesh if it needs to adjust array sizes.
 * 
 * 
 * This allows modifiers that allocate to perform blits after the initial allocation.
 * To creates and return a new mesh as part of its action, any allocated
 * memory is guaranteed to remain.
 * 
 * Modifiers must be implemented in software, but may
 * also provide an equivalent vertex shader.
 * Modifiers at the bottom of the stack (applied last)
 * with vertex shader implementations will be run as such.
 */
abstract class Modifier
{private:
	mixin(bitfields!(
		bool, "marked", 1, //Output has potentially changed since last application.
		bool, "impure", 1, //Modifies the input.
		uint, "", 6));

public:
	this(bool impure)
	{
		marked = true;
		this.impure = impure;
	}

	Mesh apply(Mesh);
}


/**
 * @brief Creates a copy of the mesh.
 * Can be inserted in the stack after expensive, rarely changing modifiers.
 * Or, where a Model splits off from the tree..?

*/
class CacheModifier
{

}

class NormalsModifier
{
	bool normalize;
}

class ElementRangeModifier
{
	Mesh apply(Mesh mesh)
	{
		return mesh;
	}
}

/**
 * @brief Creates a copy of its input as its output.
 * Cache modifiers
class CacheModifier
{

}


/*
 * Weights: Deformer groups must be normalised - weights for a vertex must add up to 1.
 */
class ArmatureModifier
{
	this()
	{
		// Constructor code
	}

	Mesh apply(Mesh mesh) { return mesh; }
}

