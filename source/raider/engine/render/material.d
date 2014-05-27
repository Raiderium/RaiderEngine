module raider.engine.render.material;

import derelict.opengl3.gl;
import raider.math.vec;
import raider.engine.render.shader;
import raider.engine.render.texture;
import raider.engine.tool.array;

/**
 * Controls how meshes are coloured.
 * 
 * Provides standard Ambient-Diffuse-Specular shading 
 * with colours and texturing. On limited hardware, the 
 * fixed function pipeline is used with colour from the 
 * first texture in the texture stack.
 * 
 * If shaders are available, it.. uses a shader. If a 
 * custom shader is set, it uses that.
 * 
 * TODO Choose to ignore multitexturing
 */
class Material
{
	vec4f ambient;
	vec4f diffuse;
	vec4f specular;
	double sharpness;

	Shader shader;
	Array!Texture textures;

	this()
	{
		ambient = vec4f(0,0,0,1);
		diffuse = vec4f(1,1,1,1);
		specular = vec4f(1,1,1,1);
		sharpness = 10.0;
	}

	void bind()
	{
		/* 'Here,' said the GL, 'are some functions that do not accept double precision.'
	    I looked and was concerned, and about to speak, but it interrupted.
	    'Shushush. Don't be querulous. These are special. They must defy convention.'
	    I was distressed, but went about my business. */
		glMaterialfv(GL_FRONT, GL_AMBIENT, ambient.ptr);
		glMaterialfv(GL_FRONT, GL_DIFFUSE, diffuse.ptr);
		glMaterialfv(GL_FRONT, GL_SPECULAR, specular.ptr);
		glMaterialf(GL_FRONT,  GL_SHININESS, sharpness);

		//TODO Get down with shaders and attributes and things
	}
}