module render.window;

import derelict.opengl3.gl;

import derelict.sfml2.window;
import derelict.sfml2.system;
import vec;
import render.camera;

/**
 * A window for rendering in.
 * 
 * This is a wrapper around SFML's Window class.
 */
class Window
{
private:
	sfWindow* sfwindow;			//Underlying SFML window
	vec4 _viewport;
	static Window _activeWindow;	//The window active for this thread.
	bool _closeRequested;
public:
	@property static Window activeWindow() { return _activeWindow; }
	@property bool closeRequested() { return _closeRequested; }

	/*
	 * If width is 0, use desktop dimensions.
	 */
	this(uint width, uint height, string title = "", bool fullscreen = false)
	{
		sfContextSettings cs = sfContextSettings(32, 0, 0, 2, 0);
		sfVideoMode vm = (width == 0) ? sfVideoMode_getDesktopMode() : sfVideoMode(width, height, 32);
		sfwindow = sfWindow_create(vm, cast(char*)title, fullscreen ? sfFullscreen : sfDefaultStyle, &cs);

		if(!sfWindow_isOpen(sfwindow)) throw new Exception("Window failed to open.");

		bind;

		mouseVisible = true;

		//Add a model transform matrix to sit on top of the camera inverse matrix.
		glMatrixMode(GL_MODELVIEW); glPushMatrix();

		glEnable(GL_TEXTURE_2D);
		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		glClearColor(0,0.05,0.1,255);
		
		glEnableClientState(GL_VERTEX_ARRAY);
		glEnableClientState(GL_NORMAL_ARRAY);
		glEnableClientState(GL_TEXTURE_COORD_ARRAY);
		
		glEnable(GL_LIGHTING);
		glEnable(GL_DEPTH_TEST);
		
		glEnable(GL_CULL_FACE);
		glCullFace(GL_BACK);
	}

	~this()
	{
		sfWindow_destroy(sfwindow);
	}

	@property void viewport(vec4 value)
	{
		assert(0.0 <= value[0] && value[0] < value[2] && value[2] <= 1.0);
		assert(0.0 <= value[1] && value[1] < value[3] && value[3] <= 1.0);
		bind;
		uint vpX = cast(uint)(value[0]*width);
		uint vpY = cast(uint)(value[1]*height);
		uint vpWidth = cast(uint)((value[2] - value[0])*width);
		uint vpHeight = cast(uint)((value[3] - value[1])*height);

		glViewport(vpX, vpY, vpWidth, vpHeight);
	}

	@property vec4 viewport() { return _viewport; }
	@property double viewportAspect() { return (_viewport[2] - _viewport[0]) / (_viewport[3] - _viewport[1]); }

	@property void title(string value) { sfWindow_setTitle(sfwindow, cast(char*)value); }
	@property uint width() { return sfWindow_getSize(sfwindow).x; }
	@property void width(uint w) { sfWindow_setSize(sfwindow, sfVector2u(w, height)); }
	@property uint height() { return sfWindow_getSize(sfwindow).y; }
	@property void height(uint h) { sfWindow_setSize(sfwindow, sfVector2u(h, width)); }
	@property vec2u size()
	{
		sfVector2u sfv = sfWindow_getSize(sfwindow);
		return vec2u(sfv.x, sfv.y);
	}

	@property void size(vec2u s)
	{
		sfWindow_setSize(sfwindow, sfVector2u(s[0], s[1]));
	}

	@property double aspect()
	{
		sfVector2u sfv = sfWindow_getSize(sfwindow);
		return cast(double)sfv.x / cast(double)sfv.y;
	}

	@property vec2i mouse()
	{
		sfVector2i sfv = sfMouse_getPosition(sfwindow);
		return vec2i(sfv.x, sfv.y);
	}

	@property void mouse(vec2i m)
	{
		sfMouse_setPosition(sfVector2i(m[0], m[1]), sfwindow);
	}

	@property void mouseVisible(bool v) { sfWindow_setMouseCursorVisible(sfwindow, v); }

	void bind()
	{
		if(_activeWindow != this)
		{
			if(sfWindow_setActive(sfwindow, true)) _activeWindow = this;
			else throw new Exception("Couldn't bind window.");
		}
	}

	void swapBuffers()
	{
		bind;
		sfWindow_display(sfwindow);
	}

	void processEvents()
	{
		bind;
		sfEvent event;
		while(sfWindow_pollEvent(sfwindow, &event))
		{
			switch(event.type)
			{
				case sfEvtResized:
					//Inform the camera of resize events. They affect both field of view and viewport.
					/*if(_activeCamera)
					{
						_activeCamera.fov = _activeCamera.fov;
						_activeCamera.viewport = _activeCamera.viewport;
					}*/ //Changes to Camera's update system have rendered this unnecessary, probably
					break;

				case sfEvtClosed:
					_closeRequested = true;
					break;
				
				default:
					break;
			}
		}
	}
}
