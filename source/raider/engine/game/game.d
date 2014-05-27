module raider.engine.game.game;

import raider.engine.render.gl;
import raider.engine.render.window;
import raider.engine.render.model;
import raider.engine.game.cable;
import raider.engine.game.layer;
import raider.engine.game.spawner;
import raider.engine.physics.world;
import raider.engine.tool.array;
import raider.engine.tool.looper;
import raider.engine.tool.reference;

/**
 * A container for all that is and all that might be.
 */
final class Game
{package:
	Array!(W!Layer) layers;
	Array!(W!Cable) cables;
	R!Layer soil; //The startup layer
public:
	R!Window window;
	R!Looper looper;

	this()
	{
		window = New!Window(800, 640);
		looper = New!Looper();
		soil = New!Layer(W!Game(this));
		Spawner.create("Seed", soil); //or perhaps "Batman"
	}

	~this()
	{
		//soil.~this() triggers a cascade of destruction
	}

	void run()
	{
		looper.start();

		while(looper.running)
		{
			while(looper.step) step(looper.logicDelta);

			draw;
			looper.sleep;
		}
	}
	
	void step(double dt)
	{
		window.processEvents;

		//TODO Play whack-a-cycle with the cpu
		//(..parallelize everything)

		//Physics
		foreach(layer; layers)
			layer.world.step(dt);

		//Look phase
		foreach(layer; layers)
		{
			foreach(entity; layer.entities)
			{
				entity.look;
				//If I had a frame parity bit to avoid duplicate pose phases, I'd set it now
			}
		}

		//Step phase
		foreach(layer; layers)
		{
			foreach(entity; layer.entities)
			{
				entity.step(dt);
				//TODO Check dGeomSphereSetRadius is safe to multithread
				//Weep loudly if it isn't
			}
		}

		/* Look/step phase needs dependency awareness.
		 * This means repeated parallel iteration of all entities.
		 * Thread-per-core with busy waiting may be the most 
		 * appropriate mechanism here.
		 * 
		 * Access to layer physics will need locking
		 * for some features.
		 */
	}

	void draw()
	{
		window.bind;

		double nt = looper.partialTime;

		foreach(cable; cables)
		{
			if(cable.camera)
			{
				window.viewport = cable.viewport;

				//Update cable.layer frustum geom from cable.camera

				//Find entities within frustum and do pose(nt) + smile(cable.camera)
				//Only pose once per frame (use parity bit).
				//Find models within frustum, and 8 most influencing lights per model
				//Compile models and lights into a list for later GL submission.
				//Give each entity a space geom for models. In most cases this
				//produces a lovely hierarchy

			}
		}

		//Submit models and lights to Artist
		
		window.swapBuffers;
		printGLError("after draw");
		glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
	}
}
