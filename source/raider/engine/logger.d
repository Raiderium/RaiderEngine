module raider.engine.logger;

import raider.math;
import raider.tools;
import raider.engine.physics;
import raider.render.gl;
import raider.render.camera;

/**
 * A facility for debugging.
 * 
 * Allows to log strings in console, and draw 3D objects on-screen.
 * If instances of this class are accessed through a variable 'log',
 * it creates a pleasing verb-object chain. E.g., log.msg("bwah").
 * 
 * The following methods are available:
 * 
 * msg (string, written to stdout and flushed immediately)
 * line (global point to global point, with colour)
 * vec (vector at global point, with colour and scaling factor)
 * mat (matrix at global point, red-green-blue axes with scaling factor)
 * quat (same as matrix)
 * aabb (axis-aligned bounding box, with colour)
 * physical shape (with colour)
 * 
 * Default colour is white (1,1,1).
 */
@RC class Logger
{/++private:
	struct Vertex { vec3f colour; vec3f pos; }
	Array!Vertex verts;
    
public:
	this()
	{
		verts.ratchet = true;
	}
    
	void draw()
	{
		Camera.modelTransform = mat4.identity;
    glVertexPointer(3, GL_FLOAT, Vertex.sizeof, verts.ptr);
    glColorPointer(3, GL_FLOAT, Vertex.sizeof, verts.ptr + Vertex.colour.offsetof);
    glDrawArrays(GL_LINES, 0, verts.size);
    
		//glInterleavedArrays(GL_C3F_V3F, Vertex.sizeof, verts.ptr); Deprecated.
	}
    
	void clear()
	{
		verts.clear;
	}
    
	/**
	 * Add a plain-coloured line to be drawn above everything.
	 */
	void line(F)(Vec!(3, F) p0, Vec!(3, F) p1, vec3f colour = vec3f(1,1,1))
	{
		Vertex v0; v0.pos = p0; v0.colour = colour;
		Vertex v1; v1.pos = p1; v1.colour = colour;
		verts.add(v0); verts.add(v1);
	}
    
	void cube(F)(Vec!(3, F) pos, Mat!(3, F) ori, Vec!(3, F) dim, vec3f colour = vec3f(1,1,1))
	{
		foreach(x; 0..12)
		{
			auto u = dim;
			auto v = dim;
            
			auto a = 7&238>>x/3*3; //hello darkness
			auto b = 7&679>>(x/3+x%3*4)/3*3; //my old friend
            
			//Generate cube edges by flipping sign bits
			if(a&1) u[0] = -u[0]; if(a&2) u[1] = -u[1]; if(a&4) u[2] = -u[2];
			if(b&1) v[0] = -v[0]; if(b&2) v[1] = -v[1]; if(b&4) v[2] = -v[2];
            
			line(pos + ori * u, pos + ori * v, colour);
		}
	}
    
	void vec(F)(Vec!(3, F) v, Vec!(3, F) pos, vec3f colour = vec3f(1,1,1), float scale = 1.0f)
	{
		line(pos, pos+(v*scale), colour);
	}
    
	void mat(F)(Mat!(3, F) m, Vec!(3, F) pos, float scale = 1.0f)
	{
		vec(m[0]*scale, pos, vec3f(1,0,0));
		vec(m[1]*scale, pos, vec3f(0,1,0));
		vec(m[2]*scale, pos, vec3f(0,0,1));
	}
    
	void aabb(F)(Aabb!(3, F) a, vec3f colour = vec3f(1,1,1))
	{
		cube(a.centre, Mat!(F, 3).identity, a.radius, colour);
	}
    
	void sphere(float radius, vec3 pos, vec3f colour = vec3f(1,1,1))
	{

	}
    
	void shape(Shape shape, vec3f colour = vec3f(1,1,1))
	{
		//FRONT FACING LINES SHOULD BE BRIGHTER AND DRAWN LAST?
		if(Sphere sphere = cast(Sphere)shape)
		{
			vec( sphere.ori[0], sphere.pos, colour, sphere.radius);
			vec(-sphere.ori[0], sphere.pos, colour, sphere.radius);
			vec( sphere.ori[1], sphere.pos, colour, sphere.radius);
			vec(-sphere.ori[1], sphere.pos, colour, sphere.radius);
			vec( sphere.ori[2], sphere.pos, colour, sphere.radius);
			vec(-sphere.ori[2], sphere.pos, colour, sphere.radius);
		}
        
		if(Box box = cast(Box)shape)
		{
			for(uint x; x<cube.length; x+=2)
				line(box.pos + box.ori * (cube[x  ] * box.dim),
					 box.pos + box.ori * (cube[x+1] * box.dim), colour);
		}
        
	}
    
	void msg(Args...)(Args args)
	{
		import std.stdio;
		writeln(args);
		stdout.flush;
	}
    
++/
}
