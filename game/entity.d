module game.entity;

import std.algorithm;

import game.game;
import game.layer;
import game.spawner;
import render.model;
import tool.container;

/**
 * An object in a layer of a game.
 * 
 * In RE, a game is defined as a set of entity types.
 * These are like actors on a stage, reacting to each other in customised
 * ways that collectively describe a game.
 * 
 * Entities must not depend on global variables.
 * 
 * Do not Delete() entities. Entities may delete themselves by returning false from step().
 */
abstract class Entity
{
package:
	Layer _layer;
	Entity _parent;
	Factory _factory;
	mixin(SListItem!"layerEntities");
	bool stepPhase;
public:
	@property Layer layer() { return _layer; }			///The layer this entity is on.
	@property Entity parent() { return _parent; }		///This entity's parent. May be null.
	@property Factory factory() { return _factory; }	///This entity's factory.
	@property Game game() { return _layer._game; }

	this(EntityArgs args)
	{
		_layer = args.layer;
		_parent = args.parent;
		_factory = args.factory;
		mixin(SListAdd!("this", "layerEntities", "entity"));
		_factory.incref;
	}

	~this()
	{
		//Not removed from layerEntities here because layer.step() does that
		_factory.decref;
	}

	/**
	 * Look phase.
	 * 
	 * During this phase, the entity may only write to private members.
	 * It should use this time to observe what has happened around it.
	 * Use depend(Entity other) to require other entities to be step()'d before this one.
	 * This is usually a quite short phase.
	 */
	void look();

	/**
	 * Step phase.
	 * 
	 * During this phase, the entity may write to public members,
	 * read the public members of entities require()'d in look(),
	 * and spawn other entities.
	 * 
	 * It may also destroy itself by returning false.
	 */
	bool step(double dt);

	/**
	 * Draw phase.
	 * 
	 * During this phase, the entity updates its graphical appearance.
	 * If you wish to support slow-motion and motion blur, the
	 * normalized time (nt) of the frame between the second-last
	 * and last step phases is provided.
	 */
	void draw(double nt);

	///Prioritise this entity below another during the step phase.
	void depend(Entity other)
	{
		//TODO Implement
	}
}

/**
 * Encapsulates all that must be passed to the base class for initialisation purposes.
 * Using a struct allows easier modification later and less typing for the developer.
 * See example entity definitions for usage.
 */
package struct EntityArgs
{package:
	this(Layer layer, Parent parent, Factory factory)
	{
		this.layer = layer;
		this.parent = parent;
		this.factory = factory;
	}
	Layer layer;
	Parent parent;
	Factory factory;
}