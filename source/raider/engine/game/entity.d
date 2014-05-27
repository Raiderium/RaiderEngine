module raider.engine.game.entity;

import std.algorithm;

import raider.engine.game.game;
import raider.engine.game.layer;
import raider.engine.game.spawner;
import raider.engine.game.factory;
import raider.engine.render.model;
import raider.engine.render.camera;
import raider.engine.tool.array;
import raider.engine.tool.reference;

/**
 * Something in a layer of a game.
 * 
 * Let's not mince words; entities are
 * just your favourite metasyntactic 
 * variables dipped in semantic concrete.
 * 
 * They're like actors on a stage,
 * particles in a collider,
 * anime fans at a convention,
 * tribbles in a storage compartment;
 * their collective behaviour is curious,
 * and you eventually want them to stop.
 * 
 * TL;DR you know the crates your game will
 * have? "class Crate : Entity". Boom.
 */
abstract class Entity
{
package:
	W!Layer _layer;
	W!Entity _parent;
	Factory _factory;
	
public:
	@property W!Layer layer() { return _layer; }        ///The layer this thing is on.
	@property W!Entity parent() { return _parent; }     ///The thing that spawned this thing.
	@property W!Factory factory() { return _factory; }  ///The factory for this thing.
	@property W!Game game() { return _layer._game; }

	this(EntityArgs args)
	{
		_layer = args.layer;
		_parent = args.parent;
		_factory = args.factory;

		//Get everything ready for the subclass constructor
		_layer.entities.add(R!Entity(this));
		_factory.incref;
	}

	~this()
	{
		_factory.decref;
	}

	/**
	 * Look phase.
	 * 
	 * During this phase, the entity reads whatever it likes, but
	 * only writes to private members. It should use this time to 
	 * observe what has happened around it and do any processing it
	 * can based on that information. It is unaware of time passing.
	 * 
	 * Use depend() in this phase to require other entities to step()
	 * before this one, allowing read access to updated information.
	 */
	void look();

	/**
	 * Step phase.
	 * 
	 * During this phase, the entity may write to public members,
	 * read from dependencies, spawn entities, and destroy itself.
	 * It should step through time by dt seconds. It should update
	 * model positions, transforms and bounding spheres.
	 * 
	 * Return false to destroy.
	 */
	bool step(double dt);

	/**
	 * Pose phase.
	 * 
	 * During this phase, the entity does expensive graphical
	 * updates, e.g. armature and shape key deformations. These
	 * must not expand the bounding spheres. (Frustum checks
	 * are already done.) 
	 * 
	 * If you wish to implement slow motion and motion blur, the
	 * normalized time (nt) of the frame between the second-last
	 * and last step phases is provided.
	 */
	void pose(double nt);

	/**
	 * Smile phase.
	 * 
	 * During this phase, the entity updates its graphical appearance
	 * with respect to a particular camera. This is an ideal place
	 * to implement levels of detail and split-screen HUD visibility.
	 */
	void smile(const Camera camera);

	//TODO Flags for implemented phases to avoid unnecessary dynamic dispatch
	//TODO Opt-in automatic decimation LOD to avoid a lot of boring smiles

package:
	size_t _dependencies;
	Array!(W!Entity) _dependers;

public:
	/**
	 * Obtain permission to read an entity.
	 * 
	 * Call during the look phase, then read from the entity in the step
	 * phase. The entity is guaranteed to step before this one.
	 */
	void depend(W!Entity other)
	{
		_dependencies++;
		other._dependers.add(W!Entity(this));
	}

	/**
	 * Obtain permission to write to an entity.
	 * 
	 * !! This feature may not be necessary or wise.
	 * 
	 * Call during the look phase, then write to the entity in the step
	 * phase. The entity is guaranteed to step after this one. Access
	 * is guaranteed to be unique.
	 * 
	 * This relationship should be avoided. It limits parallel optimization
	 * and tends to indicate an improperly structured game. However, 
	 * sometimes it is unavoidable. (citation needed)
	 * 
	 * Controlling a dependency is a stupid idea.
	 */
	//void control(W!Entity other)
}