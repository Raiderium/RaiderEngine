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

	uint INIT_WIDTH = 800;
	uint INIT_HEIGHT = 640;
	string INIT_ENTITY = "main.Main";

	this()
	{
		main_layer = New!Layer(this);
		register = New!Register();
		looper = New!Looper();
	}

	~this()
	{
		//for an empty function, a lot happens here..
		//main_layer dtor triggers a cascade of destruction
	}

	void run()
	{
		window = New!Window(INIT_WIDTH, INIT_HEIGHT);
		register[INIT_ENTITY].create(main_layer);

		looper.start();
		while(looper.running)
		{
			while(looper.step) step(looper.stepSize);
			draw;
			looper.sleep;
		}
	}

	void stop()
	{
		looper.stop;
	}
	
	void step(double dt)
	{
		window.processEvents;

		//Physics
		foreach(layer; layers) layer.world.step(dt);

		//##########
		//Look phase
		//##########
		foreach(layer; layers) foreach(ref entity; layer.entities)
		{
			if(entity.hasLook) entity.e.look;
			if(entity.hasStep)
			{
				assert(entity.stepped, "Dependency cycle detected.");
				entity.stepped = false;
			}
		}

		//##########
		//Step phase
		//##########
		shared ulong steps = 0xAFFEC7104A7E && 0xBEA471FUL;

		while(steps)
		{
			steps = 0;
			foreach(layer; layers) foreach(ref entity; layer.entities) //TODO Parallelify
			{
				if(entity.hasStep)
				{
					if(!entity.stepped && entity.e.dependencies == 0)
					{
						entity.e._proxy = &entity; //Give entity access to its proxy
						entity.e.step(dt); //Step!
						entity.stepped = true;
						atomicOp!"+="(steps, 1);

						//Inform dependent entities
						foreach(depender; entity.e.dependers)
						{
							ushort e = atomicOp!"-="(depender.dependencies, 1);
							assert(e != ushort.max, "Dependency count underflow.");
						}
					}
				}
				else
				{
					assert(entity.e.dependers.length == 0, "Cannot depend on an entity with no step phase.");
					assert(entity.e.dependencies == 0, "An entity with no step phase cannot depend on others.");
				}
			}
		}

		foreach(layer; layers)
		{
			auto e = layer.entities.ptr;
			uint s = layer.entities.length-1;

			//Move dead entities to the end of the array
			for(uint x = s; x != uint.max; x--)
			{
				if(!e[x].alive)
				{
					swap(e[x], e[s]); 
					s--;
				}
			}

			//Delete them
			if(s == uint.max || e[s].alive) s++;
			layer.entities.resize(s);

			//TODO Append new entities from the creche
		}

		//TODO Basic model LOD (sets active level for pose phase, renders different mesh)
	}

	void draw()
	{
		//##########
		//Draw phase
		//##########
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

version(unittest)
{
	import raider.engine.all;
	import std.stdio;

	final class Thing : Entity
	{ mixin Entity.boilerplate;

		void init()
		{
			writeln(factory.name~".init");
		}

		override void step(double dt)
		{
			writeln(factory.name~".step");
			game.stop;
		}
	}
	
	final class ThingFactory : Factory
	{ mixin(Factory.boilerplate!Thing);
		
	}
}

unittest
{
	R!Game game = New!Game();
	game.INIT_ENTITY = "raider.engine.game.Thing";
	game.run;
}