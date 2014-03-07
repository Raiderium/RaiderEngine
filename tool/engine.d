module tool.engine;

import std.stdio;

import derelict.util.exception;
import derelict.opengl3.gl;
import derelict.sfml2.window;
import derelict.sfml2.system;

shared static this()
{
	//Load GL 1.1
	DerelictGL.load();

	//Load SFML System and Window
	DerelictSFML2System.load();
	DerelictSFML2Window.load();

	//Create context so reload has stuff to work with
	auto context = sfContext_create();

	//Load further GL versions
	DerelictGL.reload();

	sfContext_destroy(context);
}

void printGLError(string source)
{
	int errorcode = glGetError();
	string errorstring;
	if(errorcode)
	{
		switch(errorcode)
		{
			case GL_INVALID_ENUM: errorstring = "invalid enum"; break;
			case GL_INVALID_VALUE: errorstring = "invalid value"; break;
			case GL_INVALID_OPERATION: errorstring = "invalid operation"; break;
			case GL_STACK_OVERFLOW: errorstring = "stack overflow"; break;
			case GL_STACK_UNDERFLOW: errorstring = "stack underflow"; break;
			case GL_OUT_OF_MEMORY: errorstring = "out of memory"; break;
			default: errorstring = "unknown!";
		}
	
		writeln("OpenGL error (" ~ errorstring ~ ") occurred at" ~ source);
	}
}

void printFramebufferInfo()
{
	int auxbuffers, depthbits, stencilbits;
	int[4] accumbits, colourbits;
	int major, minor, rev;
	GLboolean doublebuf, stereobuf;

	glGetIntegerv(GL_DEPTH_BITS, &depthbits);
	glGetIntegerv(GL_STENCIL_BITS, &stencilbits);
	glGetIntegerv(GL_AUX_BUFFERS, &auxbuffers);
	
	glGetIntegerv(GL_ACCUM_RED_BITS, &accumbits[0]);
	glGetIntegerv(GL_ACCUM_GREEN_BITS, &accumbits[1]);
	glGetIntegerv(GL_ACCUM_BLUE_BITS, &accumbits[2]);
	glGetIntegerv(GL_ACCUM_ALPHA_BITS, &accumbits[3]);
	
	glGetIntegerv(GL_RED_BITS, &colourbits[0]);
	glGetIntegerv(GL_GREEN_BITS, &colourbits[1]);
	glGetIntegerv(GL_BLUE_BITS, &colourbits[2]);
	glGetIntegerv(GL_ALPHA_BITS, &colourbits[3]);
	
	glGetBooleanv(GL_DOUBLEBUFFER, &doublebuf);
	glGetBooleanv(GL_STEREO, &stereobuf);
	
	int accumbits_total = accumbits[0]+accumbits[1]+accumbits[2]+accumbits[3];
	int colourbits_total = colourbits[0]+colourbits[1]+colourbits[2]+colourbits[3];
	
	writeln(glGetString(GL_VERSION));
	writeln("Colour bits: ", colourbits_total);
	writeln("Depth bits: ", depthbits);
	writeln("Stencil bits: ", stencilbits);
	writeln("Accum bits: ", accumbits_total);
	writeln("Double buffered: ", doublebuf);
	writeln("Stereo buffered: ", stereobuf);
	writeln("Auxilliary buffers: ", auxbuffers);
}

void printDesktopVideoModeInfo()
{
	auto mode = sfVideoMode_getDesktopMode();
	writeln("Desktop: ", mode.width, "x", mode.height, " ", mode.bitsPerPixel, "bpp");
}