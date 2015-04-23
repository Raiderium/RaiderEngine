module raider.engine.layer;

import raider.engine.entity;
import raider.engine.game;
import raider.physics.world;
import raider.render.model;
import raider.render.camera;
import raider.render.light;
import raider.tools.array;
import raider.tools.reference;

/**
 * May contain interacting entities.
 * 
 * A layer is a basic container for entities, 
 * providing easy construction and destruction 
 * of multiple instances.
 */
class Layer
{package:
	P!Game _game;
	R!World _world;
	int _z; ///Graphical depth. Layers draw in ascending order.

	Array!Plug plugs;
	Array!Plug addBuffer;

public:
	@property P!Game game() { return _game; }
	@property R!World world() { return _world; }
	@property int z() { return _z; }

	this(Game game, int z = 0)
	{
		_game = P!Game(game);
		_world = /*brave*/New!World();
		_z = z;

		_game.layers.add(P!Layer(this));
	}

	~this()
	{
		assert(_game.layers.contains(P!Layer(this)));

		plugs.clear;

		_game.layers.removeItem(P!Layer(this));
	}
}
