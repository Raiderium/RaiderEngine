module render.material;

import vec;
import derelict.opengl3.gl;

/**
 * Optical properties of a surface.
 * 
 * If shaders are not available, the fixed function pipeline will be
 * used with the standard Ambient-Diffuse-Specular attributes, drawing
 * colour from the first texture in the texture stack.
 */
class Material
{
	vec4f ambient;
	vec4f diffuse;
	vec4f specular;
	double sharpness;
	Texture[] textures;

	//TODO Figure out how materials should work, combining shaders and textures

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
	}
}

/*
* How do shaders interact with multitexturing? How to get multiple UV coords to a shader?
* Ehn.
*/
