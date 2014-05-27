module raider.engine.render.mesh;

import derelict.opengl3.gl;
import raider.math.vec;
import raider.engine.render.material;
import raider.engine.tool.array;
import raider.engine.tool.packable;
import raider.engine.tool.reference;

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

	void toPack(Pack pack)
	{
		pack.write(uv);
		pack.write(nor);
		pack.write(pos);
		pack.write(flags);
	}

	void fromPack(Pack pack)
	{
		pack.read(uv);
		pack.read(nor);
		pack.read(pos);
		pack.read(flags);
	}

	//TODO Fix the inherited normal thing not actually allowing arbitrary splitting
}

struct TriFace { uint a, b, c; }
struct QuadFace { uint a, b, c, d; }
struct Weight { uint i; float weight; }
struct Group { string name; Array!Weight weights; }
struct Key { uint i; vec3f pos; }
struct Morph { string name; Array!Key keys; }

/**
 * Latently visible floating things.
 */
class Mesh : Packable
{public:
	Array!Vertex verts;
	Array!TriFace tris;
	Array!QuadFace quads;
	Array!Group groups;
	Array!Morph morphs;
	Array!uint materialRanges;

	/**
	 * Calculate smoothed normals for all vertices.
	 */
	void calculateNormals()
	{
		//Set all vertex normals to (0,0,0)
		foreach(ref Vertex v; verts) v.nor = vec3f(0,0,0);

		//Sum triface normals to vertices
		foreach(ref TriFace f; tris)
		{
			vec3f x = verts[f.a].pos - verts[f.b].pos;
			vec3f y = verts[f.c].pos - verts[f.b].pos;
			vec3f n = y.cross(x);
			n.normalize();

			verts[f.a].nor += n;
			verts[f.b].nor += n;
			verts[f.c].nor += n;
		}

		//Sum quadface normals to vertices
		foreach(ref QuadFace f; quads)
		{
			vec3f x = verts[f.a].pos - verts[f.b].pos;
			vec3f y = verts[f.c].pos - verts[f.b].pos;
			vec3f n = y.cross(x);

			x = verts[f.c].pos - verts[f.d].pos;
			y = verts[f.a].pos - verts[f.d].pos;
			n += y.cross(x);
			n.normalize();
			
			verts[f.a].nor += n;
			verts[f.b].nor += n;
			verts[f.c].nor += n;
			verts[f.d].nor += n;
		}

		//Normalize 
		vec3f sum;
		foreach(size_t x, ref Vertex v; verts)
		{
			if(v.part) verts[x].nor = sum;
			else
			{
				sum = v.nor;

				//Look ahead for parts like an engineer driving through the apocalypse.
				uint y = x+1;
				while(y < verts.length && verts[y].part)
					sum += verts[y].nor;
				sum.normalize();
				v.nor = sum;
			}
		}
	}

	//TODO Move this tech from drawRange and draw to Artist.
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

	override void toPack(Pack pack)
	{
		pack.writeArray(verts);
		pack.writeArray(tris);
		pack.writeArray(quads);
	}

	override void fromPack(Pack pack)
	{
		pack.readArray(verts);
		pack.readArray(tris);
		pack.readArray(quads);
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
* track additional vertices with the same position. I refer to
* these as 'partial vertices' or 'parts'.
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