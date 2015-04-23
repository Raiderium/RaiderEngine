module raider.engine.framework.cable;

import raider.math.all;
import raider.engine.layer;
import raider.render.camera;
import raider.tools.reference;

/**
 * Connects a layer to a camera and window.
 * 
 * Cable is analogous to a video cable. When provided with a camera, 
 * layer and window, it will cause the layer to be seen in the window 
 * from that camera's perspective.
 * 
 * To disable a cable, simply 'unplug' the camera by setting it null.
 * 
 * A viewport may also be configured to limit the rendered region.
 * 
 * Note that currently there is only one window per game, which is 
 * automatically used as the destination for all cables. In future 
 * there may be multiple windows, but there are a few technical 
 * concerns in the way. Namely, vsync.
 */
final class Cable
{package:
	R!Layer layer;

public:
	R!Camera camera;
	vec4 viewport; //Normalised coordinates

	this(R!Layer layer)
	{
		this.layer = layer;

		layer.game.cables.add(P!Cable(this));
		
		viewport = vec4(0,0,1,1);
	}

	~this()
	{
		layer.game.cables.removeItem(P!Cable(this));
	}
	
	int opCmp(Cable c)
	{
		return layer.z - c.layer.z;
	}
}