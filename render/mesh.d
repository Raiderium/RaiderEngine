module render.mesh;

import std.bitmanip;
import derelict.opengl3.gl;
import vec;
import render.material;
import tool.packable;



struct Vertex
{
	vec2f uv;
	vec3f nor;
	vec3f pos;
	ubyte flags;
	@property bool part() { return (flags & 1<<0)>>0; }
	@property void part(bool value) { flags ^= (-value ^ flags) & (1<<0); }
	@property bool uvPart() { return (flags & 1<<1)>>1; }
	@property void uvpart(bool value) { flags ^= (-value ^ flags) & (1<<1); }
	@property bool norPart() { return (flags & 1<<2)>>2; }
	@property void norpart(bool value) { flags ^= (-value ^ flags) & (1<<2); }

	//bitfields can't be used because it hides the variable.
	/*mixin(bitfields!(
		bool, "part", 1,		//Inherit position from the last non-part vertex.
		bool, "uvPart", 1,		//Inherit texture coordinates from the same.
		bool, "norPart", 1,		//Inherit (and contribute to) shared normal.
		uint, "", 5));*/

	void describePack(PackTask task)
	{
		task.describe(uv);
		task.describe(nor);
		task.describe(pos);
		task.describe(flags);
	}

	//TODO Fix the inherited normal thing not actually allowing arbitrary splitting
}

struct Face { uint a, b, c; }
struct Weight { uint i; float weight; }			//A vertex weight
struct Group { string name; Weight[] weights; }	//A group of weights
struct Key { uint i; vec3f pos; }				//A vertex location key
struct Morph { string name; Key[] keys; }		//A group of keys


/**
* Graphical triangle mesh.
* 
* TODO Quadrilaterals.
*/
class Mesh
{private:
	Vertex[] verts;
	Face[] faces;
	Group[] groups;
	Morph[] morphs;
	uint[] materialRanges;
	Mesh _basis;

public:
	
	/**
	 * Set the deformation basis mesh.
	 * 
	 * The basis is used to reset deformed vertices.
	 */
	//TODO Scrap basis system. Replace storage with Array template.
	//Use Array.share for basis sharing and allow direct mesh manipulation.
	@property void basis(Mesh value)
	{
		_basis = value;

		//Copy vertices
		verts.length = _basis.verts.length;
		verts[] = _basis.verts[];

		//Share everything else
		faces = _basis.faces;
		groups = _basis.groups;
		morphs = _basis.morphs;
		materialRanges = _basis.materialRanges;
	}

	/**
	 * Undo deformations.
	 */
	void applyBasis()
	{
		assert(_basis);

		verts[] = _basis.verts[];
	}

	void applyArmature()
	{

	}

	void applyMorph()
	{

	}

	/**
	 * Calculate smoothed normals for all vertices.
	 */
	void calculateNormals()
	{
		//Set all vertex normals to (0,0,0)
		foreach(ref Vertex v; verts) v.nor = vec3f(0,0,0);

		//Sum face normals to vertices
		foreach(ref Face f; faces)
		{
			vec3f x = verts[f.a].pos - verts[f.b].pos;
			vec3f y = verts[f.c].pos - verts[f.b].pos;
			vec3f n = y.cross(x);
			n.normalize();

			verts[f.a].nor += n;
			verts[f.b].nor += n;
			verts[f.c].nor += n;
		}

		//Normalize 
		vec3f sum = vec3f(0,0,0);
		foreach(size_t x, ref Vertex v; verts)
		{
			if(!v.part)
			{
				sum = v.nor;
				//Look ahead for parts
				uint y = x+1;
				while(y < verts.length && verts[y].part)
				{
					sum += verts[y].nor;
				}
				sum.normalize();
				v.nor = sum;
			}
			else
			{
				verts[x].nor = sum;
			}
		}
	}

	//TODO Move GL drawing to a dedicated class. This follows the definition of Mesh and Model better.
	void drawRange(uint f0, uint f1)
	{
		assert(f0 <= f1 && f0 < faces.length && f1 <= faces.length);
		Face[] f = faces[f0..f1];

		glInterleavedArrays(GL_T2F_N3F_V3F, Vertex.sizeof, verts.ptr);
		glDrawElements(GL_TRIANGLES, f.length*3, GL_UNSIGNED_INT, f.ptr);
	}

	void draw(Material[] materials)
	{
		uint rangeMin = 0;

		foreach(uint x, uint rangeMax; materialRanges)
		{
			if(x < materials.length) materials[x].bind();
			drawRange(rangeMin, rangeMax);
			rangeMin = rangeMax;
		}
	}

	void describePack(PackTask task)
	{
		task.describeArray(verts);
		task.describeArray(faces);
	}
}

/*
* Regarding geometrically defined vertices...
*
* The OpenGL defines a vertex as a vector of attributes, including 
* position, normal, color and position in texture space. If any of 
* these attributes change, it is considered a different vertex.
* 
* However, it is often desireable to define a vertex by
* position only (a 'geometric' vertex) and attach other 
* attributes to the face elements instead.
* 
* An example is texture mapping, where seams are necessary to 
* unwrap the model - neighbouring elements have different UV
* coordinates at the same vertex.
* 
* To submit geometric vertices, it is necessary to create and 
* track additional vertices with the same position. These are
* referred to as 'partial vertices' or 'parts'.
* 
* To keep track of them, they are lumped together in the 
* vertex stream. The 'part' flag is used to indicate a vertex
* inherits its position from the last unflagged vertex. 
* The 'uvPart' and 'norPart' flags might also be set, indicating
* the vertex also inherits those attributes from the same source.
* 
* Algorithms that modify vertex attributes can process the first
* part in the lump, cache the result, and copy it to inheriting parts.
* Non-inheriting parts can be processed without updating the cache.
* 
* Algorithms must be written with an understanding of the part flags.
*/