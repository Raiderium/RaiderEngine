module render.cable;

import derelict.opengl3.gl;

import rm;
import game.layer;
import render.camera;
import render.window;
import tool.container;

/**
 * Connects a camera to a window.
 * 
 * Cable is analogous to a video cable connecting a camera to a screen.
 * It is associated with a layer (and thus a game) throughout its life.
 * If provided with a valid camera and window, it will cause the layer
 * to be seen from that camera's perspective in that window.
 * To disable it, simply 'unplug' the camera or window (set them null).
 * 
 * A viewport may also be configured, defining the rendered region.
 */
final class Cable
{package:
	mixin(SListItem!("gameCables"));
	Layer _layer;

public:
	this(Layer layer)
	{
		_layer = layer;
		mixin(SListAddSorted!("layer.game", "gameCables", "this"));
	}

	~this()
	{
		mixin(SListRemove!("_layer", "gameCables", "this"));
	}

	@property Layer layer() { return _layer; viewport = vec4(0,0,1,1); }

	Camera camera;
	Window window;
	vec4 viewport; ///Rectangular region described by normalized (0-1) coordinates.
	
	int opCmp(Cable c)
	{
		return _layer.z - c._layer.z;
	}

package:
	void draw()
	{
		if(camera && window)
		{
			//Setup GL
			window.bind;
			window.viewport = viewport;
			camera.bind(window.viewportAspect);
			
			//Draw layer
			layer.draw; glFlush();
			
			//Swap buffers, check input, clear backbuffer
			window.swapBuffers;
			window.processEvents; //TODO Move this to just before logic update, if possible.
			printGLError("after draw");
			glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
		}
	}
}