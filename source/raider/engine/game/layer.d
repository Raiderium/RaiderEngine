module raider.engine.game.layer;

import raider.engine.game.entity;
import raider.engine.game.game;
import raider.engine.physics.ode;
import raider.engine.physics.world;
import raider.engine.render.model;
import raider.engine.render.camera;
import raider.engine.render.light;
import raider.engine.tool.array;
import raider.engine.tool.reference;

/**
 * May contain interacting entities.
 * 
 * A layer is a container for entities, combining
 * several technically separate facilities that are
 * almost always unified in practice.
 * 
 * 1. Entity grouping. Games always need this.
 * Unloading a map to return to a main menu means 
 * destroying a bunch of entities, but which ones?
 * Best solution is to keep a list. Call it a layer. 
 * You specify a layer to spawn new entities in. It 
 * defaults to the layer the parent entity inhabits. 
 * Destroy a layer to destroy the entities. Woop woop!
 * 
 * 2. Physics grouping.
 * If entities have a physical presence, you need
 * them to create it in a specific physical world.
 * This can be done in any number of ways depending
 * on what is needed. But the most common result is
 * one physical world for each entity group.
 * So, layers have one.
 * 
 * 3. Graphics layering.
 * If something has to be drawn in front of another,
 * regardless of depth occlusion, layers do this. 
 * Generally this coincides with needing a separate 
 * physical world and entity group. Layers, huzzah!
 * 
 * 4. Dirty work.
 * Frustum culling, light and shadow, parallel processing,
 * GL optimisation... layers are important beasts.
 */
class Layer
{package:
	W!Game _game;
	R!World _world;
	int _z; ///Graphical depth. Lower = behind stuff.

	Array!(R!Entity) entities;

	dSpaceID modelSpace;
	dSpaceID lightSpace;

public:
	@property W!Game game() { return _game; }
	@property R!World world() { return _world; }
	@property int z() { return _z; }

	this(W!Game game, int z = 0)
	{
		_game = game;
		_world = /*brave*/New!World();
		_z = z;

		modelSpace = dSweepAndPruneSpaceCreate();
		lightSpace = dSweepAndPruneSpaceCreate();

		_game.layers.add(W!Layer(this));
	}

	~this()
	{
		assert(_game.layers.contains(W!Layer(this)));

		entities.clear;

		assert(dSpaceGetNumGeoms(modelSpace) == 0);
		assert(dSpaceGetNumGeoms(lightSpace) == 0);
		
		dSpaceDestroy(modelSpace);
		dSpaceDestroy(lightSpace);

		_game.layers.removeItem(W!Layer(this));
	}
}
