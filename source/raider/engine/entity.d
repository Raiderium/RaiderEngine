module raider.engine.entity;

import std.bitmanip;
import core.atomic : atomicOp;
import raider.engine.factory;
import raider.engine.game;
import raider.engine.layer;
import raider.render.model;
import raider.render.camera;
import raider.render.light;
import raider.tools.array;
import raider.tools.reference;

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
 */
abstract class Entity
{package:

	shared ushort dependencies;
	Array!(P!Entity) dependers;
	P!Layer _layer;
	R!Factory _factory;
	EntityProxy* _proxy; //Valid for this entity during step phase.

public:

	/**
	 * Obtain permission to read an entity.
	 * 
	 * Call during the look phase, then read from the entity in the step
	 * phase. The entity is guaranteed to step before this one.
	 */
	void depend(Entity other)
	{
		atomicOp!"+="(dependencies, 1);
		assert(dependencies != 0);

		//FIXME Dependers list needs lock-free add().
		other.dependers.add(P!Entity(this));
	}

	/**
	 * Destroy this entity.
	 * 
	 * Call during the step phase to cause self-destruction.
	 */
	void destroy()
	{
		assert(_proxy !is null);
		_proxy.alive = false;
	}

	@property P!Layer layer() { return _layer; }
	@property R!Factory factory() { return _factory; }
	@property P!Game game() { return _layer._game; }

	this(Layer layer, R!Factory factory, ubyte phaseFlags)
	{
		_layer = P!Layer(layer);
		_factory = factory;

		EntityProxy ep; //Lesson learnt: do NOT use = { R!Entity(this), flags:phaseFlags };
		ep.flags = phaseFlags; //Struct initialisers don't copy the reference properly
		ep.e = R!Entity(this);
		_layer.entities.add(ep);
	}

	mixin template boilerplate()
	{
		enum hasLook = __traits(compiles, look());
		enum hasStep = __traits(compiles, step(0.0));
		enum hasDraw = __traits(compiles, draw(R!Camera.init, 0.0));

		static if(!hasLook) override void look() { }
		static if(!hasStep) override void step(double dt) { }
		static if(!hasDraw) override void draw(R!Camera c, double nt) { }

		this(Layer layer, R!Factory factory)
		{
			super(layer, factory,
			      hasLook<<0 | 
			      hasStep<<1 | 
			      hasDraw<<2 | 
								//parity
			            1<<4 |  //alive
			      hasStep<<5 ); //stepped

			static if(__traits(compiles, init())) init();
		}
	}

	/**
	 * Look phase.
	 *
	 * During this phase, the entity reads whatever it likes, 
	 * but only writes to private members. It should use this 
	 * time to observe what has happened around it and do any 
	 * processing it can based on that information. It is 
	 * unaware of time passing.
	 * 
	 * Use depend() in this phase to require other entities to 
	 * step() before this one, allowing to read updated state.
	 * 
	 */
	void look();

	/**
	 * Step phase.
	 * 
	 * During this phase, the entity may write to public members
	 * and read from dependencies. It should step through time 
	 * by dt seconds. This is the place to spawn or destroy 
	 * entities, play sounds, adjust models, advance animations,
	 * apply forces, set positions, etc.
	 * 
	 * Applying forces to other bodies is a little different,
	 * apparently. What.. what does this mean, hm? Should
	 * entities provide separate write/read interfaces?
	 * 
	 * How about asserting step'd?
	 * 
	 * Should also update entity bounds.
	 */
	void step(double dt);

	/**
	 * Draw phase.
	 * 
	 * During this phase, the entity submits models for drawing
	 * and (if they are not culled) does expensive graphical
	 * updates that have no effect on the game simulation, 
	 * e.g. armature and shape key deformations. It should not 
	 * touch game data. Note that frustum checks are performed
	 * before deformation, so bounding geometry should have an 
	 * appropriate amount of slop.
	 * 
	 * In a server, drawing is skipped.
	 * 
	 * If you wish to implement slow motion and motion blur, the
	 * normalized time (nt) of the frame is provided.
	 * 
	 * This phase is repeated for each observing camera. To skip
	 * unnecessary work, a flag is provided on each model that 
	 * is true whenever the model's LOD has changed between 
	 * cameras or time has progressed. If it is false, an update 
	 * is unnecessary unless the model must appear different to 
	 * specific cameras.
	 */
	void draw(R!Camera camera, double nt);
}

/**
 * Entity reference and flags.
 * 
 * Every entity has flags used in the main loop.
 * These would be stored on the entity object, but they
 * often flag situations where a dereference is avoidable. 
 * So we store them next to the reference instead,
 * allowing the loop to run faster.
 * 
 * This is beneficial because resolving entity dependencies 
 * requires repeated iterations with a lot of no-ops.
 * 
 * It unfortunately introduces a confusing situation where 
 * layer.entities is actually a list of proxy structs, 
 * not direct Entity references. *shrug* :I
 */
package struct EntityProxy
{
	R!Entity e;

	union
	{
		ubyte flags = 0;
		mixin(bitfields!(
			bool, "hasLook", 1,
			bool, "hasStep", 1,
			bool, "hasDraw", 1,
			bool, "parity", 1,
			bool, "alive", 1,
			bool, "stepped", 1,
			bool, "boundsDirty", 1,
			bool, "", 1,));
	}
}




/* Let's talk briefly about game objects.
 * 
 * There is a pattern in engine design where
 * you have The Game Object, an entity that
 * potentially contains one of everything
 * (a sound emitter, a physical body, a shape, 
 * a mesh, an armature, a particle emitter, 
 * a script, etc) as the only element with
 * true agency. This is nice because it 
 * simplifies the engine.
 * 
 * This is also hamfisted and wasteful. It adds
 * busywork for the game developer, revoking 
 * their object-oriented design tools in an 
 * object-oriented language, requiring multiple 
 * GameObjects per actual game object, resulting
 * at best in a functional but graceless pile of 
 * spaghetti code.
 * 
 * Long story short, I don't like this pattern.
 * 
 * Disclaimer: If the game objects are part of a 
 * component-driven engine, the above does not
 * apply. It's only a problem if the developer
 * must directly manipulate them without any
 * supporting infrastructure.
 */