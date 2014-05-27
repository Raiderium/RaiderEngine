module raider.engine.render.texture;

import derelict.opengl3.gl;

/**
 * Bitmap tapestry.
 * 
 * A straight wrapper around an RGBA 32bpp GL texture ID.
 */
class Texture
{private:
	uint _width;
	uint _height;
	GLuint _id;

public:
	this()
	{
		//
	}

	~this()
	{
		release();
	}

	///Calls glDeleteTextures to release GPU resources and invalidate this texture.
	void release()
	{
		/*"glDeleteTextures silently ignores 0's and names that
		do not correspond to existing textures." - OpenGL reference*/
		glDeleteTextures(1, &_id);
		_id = 0;
		_width = 0;
		_height = 0;
	}

	///Bind texture with glBindTexture (optionally to a specific texture unit).
	void bind(int textureUnit = 0)
	{
		assert(0 <= textureUnit && textureUnit <= 7);
		glActiveTexture(GL_TEXTURE0 + textureUnit);
		glBindTexture(GL_TEXTURE_2D, _id);
		//glActiveTexture(GL_TEXTURE0); Set active texture back to something..?
	}

	///Bind no texture.
	static void unbind()
	{
		glBindTexture(GL_TEXTURE_2D, 0);
	}

	@property uint width() { return _width; }
	@property uint height() { return _height; }
	@property GLuint id() { return _id; }
}