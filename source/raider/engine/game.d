module raider.engine.game;

import core.atomic;
import raider.render.gl;
import raider.render.window;
import raider.engine.cable;
import raider.engine.layer;
import raider.engine.entity;
import raider.engine.register;
import raider.tools.array;
import raider.tools.looper;
import raider.tools.reference;

/**
 * A container for all that is.
 * 
 * Oddly enough, if you're trying to make a game, you
 * don't start here. Go make some Entity subclasses.
 */
final class Game
{package:
	Array!(P!Layer) layers;
	Array!(P!Cable) cables;
	R!Layer main_layer; //The initial layer
	R!Register register;

public:
	R!Window window;
	R!Looper looper;

	this()
	{
		window = New!Window(800, 640);
		looper = New!Looper();
		main_layer = New!Layer(this);
		register["Main"].create(cast(P!Layer)main_layer);
	}

	~this()
	{
		//main_layer.~this() triggers a cascade of destruction
	}

	void run()
	{
		looper.start();

		while(looper.running)
		{
			while(looper.step) step(looper.stepSize);

			draw;
			looper.sleep;
		}
	}
	
	void step(double dt)
	{
		window.processEvents;

		//Physics phase
		foreach(layer; layers) layer.world.step(dt);

		//Look phase
		foreach(layer; layers)
		{
			foreach(plug; layer.plugs)
			{
				if(plug.hasLook) plug.e.look;

				if(plug.hasStep)
				{
					assert(plug.stepped, "Dependency cycle detected.");
					plug.stepped = false;
				}
			}
		}

		//Step phase
		uint steps = 0xD15EA5E;
		while(steps)
		{
			steps = 0;

			//For all entities (this iteration can be parallel)
			foreach(layer; layers)
			{
				foreach(plug; layer.plugs)
				{
					if(plug.hasStep)
					{
						//If not stepped..
						if(!plug.stepped)
						{
							//If there are no remaining dependencies..
							if(plug.e.dependencies == 0)
							{
								//Step.
								plug.e._plug = &plug;
								plug.e.step(dt);
								steps++;
								plug.stepped = true;

								//Mark dependers.
								foreach(depender; plug.e.dependers)
								{ ushort e = atomicOp!"-="(depender.dependencies, 1);
									
									assert(e != ushort.max, "Dependency count underflow.");
								}
							}
						}
					}
					else
					{
						assert(plug.e.dependers.length == 0, "Cannot depend on an entity with no step phase.");
						assert(plug.e.dependencies == 0, "An entity with no step phase cannot depend on others.");
					}
				}
			}
		}

		//Delete phase
		foreach(layer; layers)
		{
			//Compact the dead at the end of the array
			uint prune = layer.plugs.length;
			
			for(uint x = layer.plugs.length; x >= 0; x--)
			{
				if(!layer.plugs[x].alive)
				{
					prune--;
					swap(layer.plugs[x], layer.plugs[prune]);
				}
			}

			//Remove them
			layer.plugs.resize(prune);
		}

		//TODO Basic model LOD (sets active level for pose phase, renders different mesh)
	}

	void draw()
	{
		window.bind;

		double nt = looper.frameTime;

		foreach(cable; cables)
		{
			if(cable.camera)
			{
				window.viewport = cable.viewport;

			}
		}

		printGLError("after draw");
	}
}

/**
 * Helps with the main loop.
 * 
 * The main loop benefits from parallel execution with
 * a certain optimum number of helper threads. These
 * wait-idle until the game signals the start of a phase,
 * then begin processing entities.
 */
private final class GameThread
{
}