module render.shader;

import derelict.opengl3.gl;
import render.texture;

/*
 * A combined fragment and vertex program.
 */
class Shader
{private:
	GLuint _program;
	//TODO Somehow provide a default ADS shader.
	static string defaultVertexSource = "
            #version 120
            attribute vec4 re_Position;
            uniform mat4 re_ModelviewMatrix;
            uniform mat4 re_ProjectionMatrix;
            void main() { gl_Position = re_ProjectionMatrix * re_ModelviewMatrix * re_Position; } ";

	static string defaultFragmentSource = "
            ";

public:
	this()
	{
		_program = 0;
	}

	~this()
	{
		release();
	}

	void compile(string fragSource = null, string vertSource = null)
	{
		if(supported)
		{
			release();

			if(!fragSource)
			{
				fragSource = defaultFragmentSource;
			}

			if(!vertSource)
			{
				vertSource = defaultVertexSource;
			}

			//To pass inputs to a vertex shader in we use glVertexAttribPointer.

			char log[400];

			//Create program
			_program = glCreateProgram();
			GLuint frag = glCreateShader(GL_FRAGMENT_SHADER);
			GLuint vert = glCreateShader(GL_VERTEX_SHADER);

			if(!_program || !frag || !vert)
			{
				release();
				glDeleteShader(frag);
				glDeleteShader(vert);
				throw new Exception("Could not create shader.");
			}

			//Attach shaders
			glAttachShader(_program, frag);
			glAttachShader(_program, vert);

			//Compile
			glShaderSource(frag, 1, cast(char**)fragSource.ptr, null);
			glCompileShader(frag);

			int compiled = 0;
			glGetShaderiv(frag, GL_COMPILE_STATUS, &compiled);

			//Check for compile errors
			if(!compiled)
			{
				glGetShaderInfoLog(frag, log.sizeof, null, log.ptr);
			}
		}
	}

	void release()
	{
		if(supported && _program)
		{
			glDeleteProgram(_program);
			_program = 0;
		}
	}

	void bind()
	{
		if(supported && compiled) glUseProgram(_program);
	}

	void unbind()
	{
		if(supported) glUseProgram(0);
	}

	@property bool compiled() { return cast(bool)_program; }
	@property GLuint program() { return _program; }
	@property bool supported() { return DerelictGL.loadedVersion >= GLVersion.GL20; }

	void uniform(T)(string name, T u)
	{
		if(supported && compiled)
		{
			glUseProgram(_program);
			int l = glGetUniformLocation(_program, name);
			static if(is(T == float)) glUniform1f(l, u);
			else static if(is(T == int)) glUniform1i(l, u);
			else static if(is(T == vec2f)) glUniform2fv(l, 1, u.ptr);
			else static if(is(T == vec3f)) glUniform3fv(l, 1, u.ptr);
			else static if(is(T == vec4f)) glUniform4fv(l, 1, u.ptr);
			else static if(is(T == vec2f[])) glUniform2fv(l, u.length, u.ptr);
			else static if(is(T == vec3f[])) glUniform3fv(l, u.length, u.ptr);
			else static if(is(T == vec4f[])) glUniform4fv(l, u.length, u.ptr);
			else static if(is(T == mat2f)) glUniformMatrix2fv(l, 1, false, u.ptr);
			else static if(is(T == mat3f)) glUniformMatrix3fv(l, 1, false, u.ptr);
			else static if(is(T == mat4f)) glUniformMatrix4fv(l, 1, false, u.ptr);
			else static assert(0);
		}
	}

	void sampler(string name, Texture texture, int textureUnit)
	{
		if(supported && compiled)
		{
			glUseProgram(_program);
			//Give the textureUnit to the shader variable
			glUniform1i(glGetUniformLocation(_program, name.ptr), textureUnit);
			//Bind the texture to the textureUnit
			texture.bind(textureUnit);
		}
	}
}