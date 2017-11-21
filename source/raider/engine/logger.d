module raider.engine.logger;

import raider.math;
import raider.tools;
import raider.engine.physics;
import raider.render.gl;
import raider.render.camera;

/**
 * A facility for complex debugging.
 * 
 * This is available both in debug and release.
 * It directs messages to a stream (defaulting to stderr).
 * Non-string payloads such as vectors are made available
 * through a draw command.
 */
class Logger
{private:
	struct Vertex { vec3f colour; vec3f pos; }
	Array!Vertex verts;

	immutable vec3[] cube = [
		vec3f( 1, 1, 1), vec3f(-1, 1, 1), vec3f( 1, 1, 1), vec3f( 1,-1, 1),
		vec3f( 1, 1, 1), vec3f( 1, 1,-1), vec3f(-1, 1, 1), vec3f(-1,-1, 1),
		vec3f(-1, 1, 1), vec3f(-1, 1,-1), vec3f( 1,-1, 1), vec3f(-1,-1, 1),
		vec3f( 1,-1, 1), vec3f( 1,-1,-1), vec3f(-1,-1, 1), vec3f(-1,-1,-1),
		vec3f( 1, 1,-1), vec3f(-1, 1,-1), vec3f( 1, 1,-1), vec3f( 1,-1,-1),
		vec3f(-1, 1,-1), vec3f(-1,-1,-1), vec3f( 1,-1,-1), vec3f(-1,-1,-1)
	];

public:
	this()
	{
		verts.cached = true;
	}
	
	/**
	 * Add a plain-coloured line to be drawn above everything.
	 */
	void line(F)(Vec!(3, F) p0, Vec!(3, F) p1, vec3f colour)
	{
		Vertex v0; v0.pos = p0; v0.colour = colour;
		Vertex v1; v1.pos = p1; v1.colour = colour;
		verts.add(v0); verts.add(v1);
	}
	
	void vec(F)(Vec!(3, F) v, Vec!(3, F) pos, vec3f colour, float scale = 1.0f) 
	{
		line(pos, pos+(v*scale), colour);
	}
	
	void mat(F)(Mat!(3, F) m, Vec!(3, F) pos, float scale = 1.0f)
	{
		vec(m[0]*scale, pos, vec3f(1,0,0));
		vec(m[1]*scale, pos, vec3f(0,1,0));
		vec(m[2]*scale, pos, vec3f(0,0,1));
	}

	void aabb(F)(Aabb!(3, F) a)
	{
		auto p = a.centre;
		auto r = a.radius;
		for(uint x; x<cube.length; x+=2)
			line(p + r*cube[x], p + r*cube[x+1], vec3f(1,1,1));
	}
	
	void shape(Shape shape)
	{
		if(Sphere sphere = cast(Sphere)shape)
		{
			vec( sphere.ori[0], sphere.pos, vec3f(1,1,1), sphere.radius);
			vec(-sphere.ori[0], sphere.pos, vec3f(1,1,1), sphere.radius);
			vec( sphere.ori[1], sphere.pos, vec3f(1,1,1), sphere.radius);
			vec(-sphere.ori[1], sphere.pos, vec3f(1,1,1), sphere.radius);
			vec( sphere.ori[2], sphere.pos, vec3f(1,1,1), sphere.radius);
			vec(-sphere.ori[2], sphere.pos, vec3f(1,1,1), sphere.radius);
		}

		if(Box box = cast(Box)shape)
		{
			for(uint x; x<cube.length; x+=2)
				line(box.pos + box.ori * (cube[x  ] * box.dim), 
					 box.pos + box.ori * (cube[x+1] * box.dim), vec3f(1,1,1));
		}

	}

	void msg(Args...)(Args args)
	{
		import std.stdio;
		writeln(args);
		stdout.flush;
	}
	
	void draw()
	{
		Camera.modelTransform = mat4.identity;
		glInterleavedArrays(GL_C3F_V3F, Vertex.sizeof, verts.ptr);
		glDrawArrays(GL_LINES, 0, verts.size);
	}
	
	void clear()
	{
		verts.clear;
	}
}
