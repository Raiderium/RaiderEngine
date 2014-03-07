module game.game;

import core.sync.mutex;

import game.layer;
import game.spawner;
import render.window;
import render.cable;
import render.camera;
import tool.container;
import tool.looper;
import tool.engine;
import tool.memory;

/**
 * Encapsulates a set of entity layers and an update / render loop.
 */
class Game
{package:
	mixin(SList!("Layer", "gameLayers"));
	mixin(SList!("Cable", "gameCables"));
	Mutex mutex;
	Layer main;
public:
	Looper looper;

	this()
	{
		mutex = New!Mutex();
		looper = New!Looper();
		main = New!MainLayer(this);
	}

	~this()
	{
		Delete(main);
		Delete(looper);
		Delete(mutex);
	}

	void run()
	{
		looper.start();

		while(looper.running)
		{
			while(looper.step()) step(looper.logicDelta);

			draw;
			looper.sleep;
		}
	}
	
	void step(double dt)
	{
		//TODO Reimplement
		//mixin(SListForEach!("layer", "this", "gameLayers", "layer.step(dt)"));
	}

	void draw()
	{
		//TODO Reimplement
		//mixin(SListForEach!("cable", "this", "gameCables", "cable.draw"));
	}
}
