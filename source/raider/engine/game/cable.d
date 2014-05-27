module raider.engine.game.cable;

import derelict.opengl3.gl;

import raider.math.all;
import raider.engine.game.layer;
import raider.engine.render.camera;
import raider.engine.render.window;
import raider.engine.tool.reference;

/**
 * Connects a layer and camera to a window.
 * 
 * Cable is analogous to a video cable connecting a camera to a monitor.
 * It is associated with a layer and window throughout its life.
 * When provided with a camera, it will cause the layer to be seen in
 * the window from that camera's perspective.
 * 
 * To disable a cable, simply 'unplug' the camera by setting it null.
 * 
 * A viewport may also be configured to limit the rendered region.
 * 
 * Note that currently there is only one window per game, which is 
 * automatically used as the destination for all cables. In future 
 * there may be multiple windows, but there are a few technical 
 * concerns in the way.
 */
final class Cable
{package:
	R!Layer layer;

public:
	R!Camera camera;
	vec4 viewport; ///Rectangular region of the window described by normalized (0..1) coordinates.

	this(R!Layer layer)
	{
		this.layer = layer;

		layer.game.cables.add(W!Cable(this));
		
		viewport = vec4(0,0,1,1);
	}

	~this()
	{
		layer.game.cables.removeItem(W!Cable(this));
	}
	
	int opCmp(Cable c)
	{
		return _layer.z - c._layer.z;
	}
}