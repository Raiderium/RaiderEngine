module raider.engine.entity;

import std.bitmanip;
import std.conv;
import core.atomic : atomicOp;
import raider.engine.factory;
import raider.engine.game;
import raider.render;
import raider.tools.array;
import raider.tools.bag;
import raider.math.misc;
import raider.tools.reference;

/**
 * Something in a game that does stuff.
 * 
 * Entities live in a hierarchy. There are two
 * kinds of entity. Normal entities don't have 
 * children, only having siblings and a parent
 * 'meta' entity. Meta entities have children,
 * and their purpose is to provide a container
 * for groups. When destroyed, a meta entity's
 * children are also destroyed. They also help
 * add developer logic to the game loop.
 * 
 * This class is the centerpiece for a non-ECS
 * entity framework that contrasts hugely with
 * the structuring of modern game engines. For
 * a discussion of the advantages of ECS, with
 * copious arguments against inheritance, see:
 * 
 * http://www.npruehs.de/tag/entity/
 * 
 * For a simple rebuttal, remember that a) the
 * diamond problem is almost exclusively a C++
 * design flaw, not to be used as a reason for
 * composition over inheritance, and b) mostly
 * all of the 'problems' are language-related,
 * or poor use of inheritance, or mysteriously
 * easily solved by using interfaces. Whatever
 * happened to interfaces?
 * 
 * I hereby contend with the industry's choice
 * to aggressively promote composition. I have
 * no quarrel with individuals, ECS is a great
 * option; but inheritance is not the terrible
 * "beginner's mistake" people claim it to be.
 * 
 * We dissolve most issues with one rule:
 * 
 * All classes inheriting Entity are final.
 * 
 * This rule is enforced at compile time. :)
 */
abstract class Entity
{package:
	P!Game _game;
	R!Factory _factory;
	EntityProxy* _proxy;
	shared ushort dependees;
	Pocket!(P!Entity) dependers;

	//this is the first invariant I ever used
	invariant { assert(_proxy.e._referent == this); }
	//it has .. proven its worth 

public:
	@property string name() { return _factory.entityName; }
	@property P!Game game() { return _game; }
	@property R!Factory factory() { return _factory; }
	@property P!Entity parent() { return _proxy.parent; }

	this(P!Game game, R!Factory factory, P!Entity parent, uint phaseFlags)
	{
		_game = game;
		_factory = factory;

		EntityProxy proxy; //Do NOT use a struct initialiser.
		proxy.flags = phaseFlags; 
		proxy.e = R!Entity(this); //They don't copy the reference properly.
		proxy.parent = parent;

		//congratulationsyouhaveachildokaybye
		if(parent !is null)
		{
			assert(parent._proxy.hasMeta);
			parent._proxy.isParent = true;
		}

		game.creche.add(proxy);

		//Update proxy (consider adding move semantics to Array..)
		if(game.creche.moved)
			foreach(ref e; game.creche) e.e._proxy = &e;
		else
			_proxy = &game.creche[][$-1];

		game.creche.moved = false;
	}

protected:

	/**
	 * Obtain permission to read an entity.
	 * 
	 * Call during the look phase, then read from the entity in 
	 * the step phase. The entity is guaranteed to step before 
	 * this one.
	 * 
	 * Cyclic shenanigans will be detected and roused on.
	 */
	void depend(Entity other)
	{
		assert(game.phase == Phase.Look);
		game.dependencies.add(P!Entity(this), other.dependers);
		atomicOp!"+="(dependees, 1);
		assert(dependees != 0); 
	}

	/**
	 * Create an entity.
	 * 
	 * Pass an entity name, a factory, or a concrete factory.
	 * Pass 'false' for the second argument unless you're a meta entity.
	 * If you pass a concrete factory you can add extra arguments that
	 * will be passed to the entity's ctor(). 
	 */

	P!Entity create(P!Factory factory, bool child = false)
	{
		return factory.create(game, child ? P!Entity(this) : parent, P!Entity(this));
	}

	P!Entity create(string name, bool child = false)
	{
		auto factory = game.factories[name];
		auto result = factory.create(game, child ? P!Entity(this) : parent, P!Entity(this));
		return result;
	}

	P!(F.ET) create(F:Factory, Args...)(P!F factory, bool child, Args args)
	{
		return P!(F.ET)(factory.create(game, child ? P!Entity(this) : parent, P!Entity(this), args));
	}

	/**
	 * Meta phase assistant.
	 * 
	 * Calls look() on non-meta children and schedules 
	 * them for step(), specifying dt in seconds.
	 */
	void scheduleChildren(double dt)
	{
		assert(game.phase == Phase.MetaLook);
		game._phase = Phase.Look;
		
		foreach(ref e; game.entities) //Parallelify
		{
			if(!e.hasMeta && P!Entity(this) == e.parent && true) //TODO Add user filter (same for drawChildren)
			{
				if(e.hasLook) e.e.look;
				if(e.hasStep) {
					version(assert) {
						//TODO Trace cycles and report offending entities.
						assert(e.stepped, "Dependency cycle or metaphasic congruency violation detected.");
						//No, seriously, it's an actual thing.
					}
					e.stepped = false;
					assert(0.0 <= dt && dt <= 1.0, "Delta time "~to!string(dt)~" is outside acceptable range.");
					e.dt = ftni!ushort(dt);
				}
			}
		}
		game._phase = Phase.MetaLook;
	}
	
	/**
	 * Meta phase assistant.
	 * 
	 * Calls draw on non-meta children.
	 */
	void drawChildren(P!Artist artist, double nt)
	{
		assert(game.phase == Phase.MetaDraw);
		game._phase = Phase.Draw;
		
		foreach(ref e; game.entities) //Parallelify
		{
			if(e.hasDraw && !e.hasMeta && P!Entity(this) == e.parent && true) //Add user filter
				e.e.draw(artist, nt);
		}
		
		game._phase = Phase.MetaDraw;
	}

public:

	/**
	 * Doom this entity.
	 * 
	 * The entity will be destroyed at the end of
	 * the current logic update.
	 * 
	 * Entities must be prepared to be destroyed
	 * at any time. They cannot avoid or undo it.
	 * However, if destruction would violate the
	 * rules of your application, use asserts to 
	 * enforce them.
	 * 
	 * Upon destruction, all references to an
	 * entity must be cleaned up, except weak
	 * references, which must be cleaned up in
	 * the next logic update.
	 */
	void destroy()
	{
		_proxy.isAlive = false;
	}

	/**
	 * Constructor phase.
	 * 
	 * All developers are recommended to use Boilerplate
	 * to define entities. Because it defines a this(),
	 * it calls ctor to inject developer construction.
	 * There is no overridable method.
	 * 
	 * The rules of the step phase apply.
	 * 
	 * ctor can optionally accept a P!Entity reference to
	 * the entity that created this entity, plus other
	 * arbitrary arguments if the creator is using a
	 * concrete factory type.
	 * 
	 * Examples:
	 * void ctor() { }
	 * void ctor(P!Entity creator) { }
	 * void ctor(P!Entity creator, uint x, ...) { }
	 */
	void _ctor() { /* Huzzah */ };

	/**
	 * Destructor phase.
	 * 
	 * Dtor (destructor) phase is called in place of ~this().
	 * The true ~this() is only called sometime later, after 
	 * deletions are finished cascading, but you don't need
	 * to know that. It's just a fun fact. Or a boring one.
	 * 
	 * Step phase rules apply. You can destroy other entities, 
	 * create things, etc.
	 * 
	 * Examples:
	 * override void dtor() { }
	 */
	void dtor();

	/**
	 * Look phase.
	 *
	 * During this phase, the entity reads whatever it likes, 
	 * but only writes to private members. It should use this 
	 * phase to observe what has happened around it and do any 
	 * processing it can based on that information. It is 
	 * unaware of time passing. Physics and other contextual
	 * information is likely to be available through a parent
	 * 'container' entity.
	 * 
	 * Use depend() in this phase to require other entities to 
	 * step() before this one, allowing to read updated state.
	 */
	void look();

	/**
	 * Step phase.
	 * 
	 * During this phase, the entity may write to public members
	 * and read from dependencies. It should step through time 
	 * by dt seconds. This is the place to spawn or destroy 
	 * entities, play sounds, adjust models, advance animations,
	 * apply forces, set positions, update bounds, etc.
	 * 
	 * Note that many parts of the physics engine are thread-safe
	 * and may be used during this phase. Other APIs might also
	 * be available if they are properly synchronised.
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
	 * specific cameras. The camera is available as artist.camera.
	 */
	void draw(P!Artist artist, double nt);

	/**
	 * Meta phase.
	 * 
	 * Invoked several times to inject developer logic into the 
	 * game loop. It must be propagated throughout the hierarchy 
	 * manually; the game simply calls main.meta to run the phase.
	 * Thus, meta entities must be aware of and responsible for 
	 * meta entities below them in the hierarchy. 
	 * 
	 * meta(Phase.MetaLook) is responsible for updating physics, 
	 * window event procedures, and similar systems. It also
	 * schedules non-meta children for the look and step phases
	 * by calling scheduleChildren.
	 * 
	 * For every invocation of the look phase, there must be a 
	 * matching invocation of the step phase. scheduleChildren
	 * guarantees this, but if a metaphase meddles and violates 
	 * this congruency, you will be gently informed of the issue.
	 * 
	 * The step phase has no user-serviceable parts. Consequently, 
	 * there is no Phase.MetaStep.
	 * 
	 * meta(Phase.MetaDraw) controls all drawing routines, 
	 * configuring artists and windows, and calling drawChildren.
	 */
	void meta(Phase phase);
}

/**
 * Entity reference and flags.
 * 
 * Every entity has flags and attributes checked in the main loop.
 * These would be stored on the entity object, but they often flag 
 * situations where a dereference is avoidable. So we store them 
 * next to the reference instead, allowing the loop to hit the cache
 * more often and thus run faster.
 * 
 * It unfortunately introduces a confusing situation where the
 * game.entities list actually contains EntityProxy, not Entity 
 * references. We could use alias this, but I'm not that insane.
 * 
 * Disclaimer: I actually am that insane, but EntityProxy simply
 * isn't used enough to be worth the effort.
 */
package struct EntityProxy
{
	R!Entity e;
	P!Entity parent;
	union
	{
		uint flags = 0;
		mixin(bitfields!(
			//Phase implementation flags.
			bool, "hasLook", 1,
			bool, "hasStep", 1,
			bool, "hasDraw", 1,
			bool, "hasMeta", 1,
			bool, "hasDtor", 1,
			
			//If false, the entity is scheduled to be stepped (or it doesn't implement step)
			bool, "stepped", 1,
			
			//If true, the dtor phase has run.
			bool, "destroyed", 1,
			
			//Self-explanatory, sort of
			bool, "isAlive", 1,
			
			//Note that only meta entities can have children, so isParent implies hasMeta.
			bool, "isParent", 1,
			
			//Not yet implemented. May be unnecessary.
			bool, "boundsDirty", 1,
			
			//Timestep for the step phase, normalised to a 16 bit unsigned integer.
			ushort, "dt", 16,
			
			//Six bits for the developer to use to filter children.
			uint, "user", 6,
				)); 
	}

	/**
	 * Iterate all immediate children.
	 */
	int children(int delegate(ref EntityProxy child) dg)
	{
		assert(hasMeta);
		
		int result;
		
		if(isParent)
		{
			foreach(ref child; e.game.entities)
			{
				if(e == child.parent) result = dg(child);
				if(result) break;
			}
		}
		
		return result;
	}
}

interface Placeable
{
	/* aabb, obb
	 * @property position, orientation
	 * Simple placement testing (collision check against world)
	 * Complex placement (create ghost presence, try to find
	 * a solution by simulating a few frames with a static world).
	 */
}

interface Environment
{
	/* Physics world
	 * Sound context
	 */
}

/* The rules, in brief:
 * 
 * Public data may only be written in the step and ctor phases.
 * A dependency's public data may only be read in the step phase.
 * Factory data may only be written with explicit synchronisation.
 * Only graphical data may be written during the draw phase.
 * 
 * The meta phases are single-threaded and have no rules.
 */

/* 18-10-2016
 * Regarding compound entities..
 * 
 * If you say, 'I want this entity to be composed of a few others',
 * well, first of all, consider not doing that, because that's a
 * door back to composition over inheritance. An entity is its own 
 * being; it doesn't share the fact of its existence with others.
 * 
 * That said, if your entity needs to manage others, that's fine; 
 * just store a list of them in some fashion. You have the tools
 * you need. For reasons of efficiency and design sanity, the 
 * parenting hierarchy is not among them.
 * 
 * Above all, don't make a meta-entity. There's a reason the meta
 * phase excludes defining look, step or draw; it replaces all of
 * them and creates an unseen authority. It is no longer part of 
 * the system; it is above the system, over it, beyond it.
 */

/*
 * Regarding xentities (extensible entities)
 * This is a concept for a 'scripted' entity, driven entirely by XML.
 * It's designed to easily and dynamically create entities with simple behaviours.
 * Essentially it's a scripting language built from xml tags. They specify the same
 * look / step / draw phases, but only very simple instructions are available.
 * For instance, it can specify to create a physical object with a name, bounds, 
 * and model; it might then specify that model's material, colour, mesh, texture etc.
 * 
 * It is expected that xentities can replace the concept of prefabs. They avoid the 
 * overhead of maintaining code for them and compiling a huge number of nearly
 * empty entity definitions. It would be tempting to create a Prop entity type
 * and substitute different models, but this isn't ideal.
 * 
 * xentities can also instance real entities and manipulate them through common
 * Interface types (transform, etc). Maps in particular would be xentities,
 * with a huge list of declared instances. When a map xentity spawns them, it is
 * equivalent to a true entity spawning them via factories, sinces that's what 
 * happens under the surface.
 * 
 * Apart from these declarative aspects it also has an imperative graph-like scripting
 * system. This allows multiplayer games to share reasonably complex behaviours at 
 * run-time without exposing vulnerabilities. The script graphs (basically simplified 
 * abstract syntax trees) can be statically analysed to detect abusive operations. 
 * For instance, they can be checked for unbounded loops.
 * 
 * Also, games can extend the basic xentity and implement their own types, with special tags.
 * 
 * As an example, the vehicles in HAGK will all be vehicle xentities. This means they
 * can declare motors, wheels, wings, rockets, fuel tanks, seats, cameras, fuel lines, sensors, etc. 
 * Custom tags! It's a powerful idea innit? And no dynamic compilation required.
 * 
 * This means new vehicles can be added without touching any code, and new features
 * can be added without touching existing XML data.
 * 
 * xentities will be necessarily duck-typed. Checking the type identifier is equivalent
 * to trying to cast an entity and checking for a null result.
 */

/* 21-10-2016
 * Regarding dependency injection..
 * 
 * If we have a user-defined-attribute (UDA) attached to entity class members,
 * they can be 'injected' from an external source, such as a browsing program
 * in another window, or an XML file, or a scripting language. This is just the 
 * basic mechanic. The applications are many and varied.
 * 
 * An XML file, for instance, could define a model - with a mesh and multiple 
 * materials, all linked from inside the XML file or separate files.
 * 
 * A script could be run in a separate thread or process for security. If it
 * crashes, the values stop updating, but the game continues.
 * 
 * An asset management component rears its head. What do we do when multiple
 * factories need the same resource? And so on, and so forth. Injection
 * is a powerful word and we'll definitely want to use it.
 */
