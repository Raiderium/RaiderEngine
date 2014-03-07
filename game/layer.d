module game.layer;

import game.entity;
import game.game;
import physics.ode;
import physics.world;
import render.model;
import tool.container;
import tool.memory;

/**
 * A space for entities.
 * 
 * TODO Make Layer extendable.
 * 
 * A customised layer named MainLayer must exist. It forms the starting point.
 * MainLayer is instanced once whenever a Game is constructed. From there, the
 * designer may use the layer to create other layers and entities and set up 
 * or tear down constructs of the game. When the game finishes, the MainLayer
 * is destroyed.
 * 
 * Layers are not automatically disposed of. If you create one, you clean it up.
 */
class Layer
{package:
	Game _game;
	World _world;
	mixin(SList!("Entity", "layerEntities"));
	mixin(SList!("Model", "layerEnabledModels"));
	mixin(SList!("Model", "layerObservedModels"));
	mixin(SListItem!("gameLayers"));

	dSpaceID dspaceModels;
	
public:
	@property Game game() { return _game; }
	@property World world() { return _world; }
	
	int z; //Rendering height. A layer is rendered after all layers with lower Z values are rendered.
	
	this(Game game, int z = 0)
	{
		_game = game;
		_world = New!World();
		dspaceModels = dSweepAndPruneSpaceCreate();
		this.z = z;
		mixin(SListAdd!("_game", "gameLayers", "this"));
	}

	~this()
	{
		mixin(SListForEach!("entity", "this", "layerEntities", "Delete(entity)")); //Destroy all remaining entities
		mixin(SListRemove!("_game", "gameLayers", "this"));
		dSpaceDestroy(dspaceModels);
		Delete(_world);
	}

	/**
	 * Enable a model for rendering in this layer.
	 * 
	 * Attempting to enable a model that is already enabled has no effect.
	 */
	void enableModel(Model model)
	{
		if(!model.enabledLayer)
		{
			mixin(SListAdd!("this", "layerEnabledModels", "model"));
			model.enabledLayer = this;
			//TODO Add to dspaceModels
		}
	}

	/**
	 * Disable rendering of a model in this layer.
	 * 
	 * This removes the model from frustum and lighting checks.
	 * Disable models whenever possible.
	 * 
	 * Attempting to disable a model that is already disabled or enabled in another another layer has no effect.
	 */
	void disableModel(Model model)
	{
		if(model.enabledLayer == this)
		{
			mixin(SListRemove!("this", "layerEnabledModels", "model"));
			model.enabledLayer = null;
			//TODO Remove from dspaceModels
		}
	}
	
	void step(double dt)
	{
		_world.step(dt);

		//TODO Reimplement this to properly resolve dependencies.
		//layer.step may disappear. game.step has to run foreaches
		//across all layers multiple times.

		//Previous naive implementation
		//mixin(SListFilter!("entity", "this", "layerEntities", "entity.step(dt)", "Delete(entity)"));
	}
	
	void draw(Camera camera)
	{
		//TODO Implement
		/*
		Update enabled models.
		Update geometry of enabled models.
		Update frustum geom.
		Find observed models using frustum check.
		ADDITIONAL FILTRATION, E.G. OBSTRUCTORS, PORTALS, BSP?
		Collide lights against models to find 8 most influencing lights.
		Idea: Once space for lights, one space for models. Use space-against-space collision.
		We don't want light-light or model-model results.
		There should be a special SAP implementation for space-space collision..
		Sort models and draw.
		*/

		//Previous naive implementation
		//mixin(SListForEach!("model", "this", "layerEnabledModels", "model.draw"));
	}
}
