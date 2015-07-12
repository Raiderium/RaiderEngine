module raider.engine.layer;

import raider.engine.entity;
import raider.engine.game;
import raider.engine.physics;
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

	Array!EntityProxy entities; //
	Array!EntityProxy creche; //Newly created entities live here, briefly.

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

		entities.clear;

		_game.layers.removeItem(P!Layer(this));
	}
}
