module raider.engine.entity;

import std.bitmanip;
import std.conv;
import core.atomic : atomicOp;
import raider.engine.factory;
import raider.engine.game;
import raider.engine.logger;
import raider.render;
import raider.tools.array;
import raider.tools.bag;
import raider.math.misc;
import raider.tools.reference;

/**
 * Something in a game that does stuff.
 * 
 * Entities live in a hierarchy. They can have
 * siblings and children, and removing parents
 * removes their children. The root is created
 * when the game starts, by spawning an entity
 * called 'Main', defined by the developer. It
 * serves as the launching point for the whole
 * affair, and is parent to everything else in
 * the game.
 * 
 * There are two kinds of entity - normal, and
 * meta. Normal entities do not have children,
 * and are only ever children to a meta entity
 * that acts as a container for them.
 * 
 * Normal entities implement normal game logic
 * concerned with the interactions between the
 * inhabitants of a world. Meta entities offer
 * the developer a seamless way to control the
 * main loop and inject logic that, in engines
 * with more traditional views on such things,
 * might require an interminable collection of
 * callbacks and event managers. The developer
 * uses them (for instance) to hold references
 * to a physics world, and entities below them
 * access that world intuitively, avoiding the
 * temptation to use global variables.
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
 * Entities must directly inherit Entity.
 * 
 * This flattens the inheritance tree, so that
 * entities are effectively final, without the
 * keyword being strictly required. The entity
 * mixin 'Stuff' statically enforces the rule.
 * 
 * It might seem silly to take away one of the
 * most defining tools of the paradigm, but in
 * doing so, we avoid its pitfalls. In trading
 * runtime composition for interfaces, we lose
 * some flexibility, but gain simplicity and a
 * not inconsequential measure of performance.
 * 
 * Is it worth it? The correct answer, that it
 * comes down to preference, is apparently not
 * correct, according to some. I get emotional
 * when people are wrong on the Internet, thus
 * this dumb little rant has a cause to exist.
 * 
 * The flexibility of ECS is the same found in
 * scripting languages. It is duck typing, and
 * while it has unquestionable advantages, the
 * tradeoff is excessive in my mind. Having it
 * available throughout a game engine, when in
 * reality most entities don't need it at all,
 * suggests a failure to optimise. And I could
 * be wrong, but I think interfaces provide an
 * alternative with potential that hasn't been
 * realised. They are fast, very hard to abuse
 * without meaning to, and easy to understand.
 * 
 * Let's at least see where this all leads. If
 * I'm wrong, I'm wrong, and I'll admit ECS is
 * the one true way to make big, modern games.
 * If I'm right, no-one will particularly care
 * about it, but I'll actually have a finished
 * game to show y'all! That'll be exciting. :D
 */
@RC abstract class Entity
{package:
	Game _game;
	R!Factory _factory;
	EntityProxy* _proxy;
	shared ushort dependees;
	Pocket!Entity dependers;

	invariant {	//this is the first invariant I ever used
		assert(_proxy !is null);
		assert(_proxy.e is this);
	} //it has proven its worth 

public:
	@property string name() { return _factory.entityName; }
	@property Game game() { return _game; }
	@property R!Factory factory() { return _factory; }
	@property Entity parent() { return _proxy.parent; }
	@property Logger log() { return _game.logger; }

	this(Game game, R!Factory factory, Entity parent, uint phaseFlags)
	{
		_game = game;
		_factory = factory;

		//Using a struct initialiser will fail to copy the 'e' reference correctly.
		EntityProxy proxy; 
		proxy.flags = phaseFlags;
		proxy.e = this; 
		proxy.parent = parent;
		_proxy = &proxy; //Does this look dangerous to you? Hoi hoi hoi.

		//congratulationsyouhaveachildokaybye
		if(parent !is null)
		{
			assert(parent._proxy.hasMeta);
			parent._proxy.isParent = true;
		}

		game.creche.add(proxy);
	}

protected:

	/**
	 * Obtain permission to read an entity.
	 * 
	 * Call during the look phase, then read from the other entity 
	 * in the step phase. It is guaranteed to step before this one.
	 * 
	 * Cyclic shenanigans will be detected and roused on.
	 */
	void depend(Entity other)
	{
		assert(game.phase == Phase.Look);
		game.dependencies.add(this, other.dependers);
		atomicOp!"+="(dependees, 1);
		assert(dependees != 0); 
	}

	/**
	 * Create an entity.
	 * 
	 * Pass an entity name, a Factory, or a derived (concrete) factory.
	 * Pass 'false' for the second argument unless you're a meta entity.
	 * If you pass a concrete factory you can add extra arguments that
	 * will be passed to the entity's ctor(). 
	 */
	Entity create(string name, bool child = false)
	{
		auto factory = game.factories[name];
		auto result = factory.create(game, child ? this : parent, this);
		return result; //todo why not return directly..? 
	}

	///ditto
	Entity create(Factory factory, bool child = false)
	{
		return factory.create(game, child ? this : parent, this);
	}

	///ditto
	F.ET create(F:Factory, Args...)(F factory, bool child, Args args)
	{
		return F.ET(factory.create(game, child ? this : parent, this, args)); 
		//I don't think a template method of the same name can coexist..
		//..which means we can omit the child arg.
		//Wait a minute we KNOW if an entity is meta.. ..oh but they can create siblings? erm..
		//call parent.create! 
		//If called on a non-meta entity (MUST HAVE PARENT), it creates a sibling. 
		//On a meta (MAIN CANNOT HAVE PARENT), it creates a child.
	}

	/**
	 * Meta phase convenience method.
	 * 
	 * Calls look() on all non-meta children and schedules them for step().
	 */
	void scheduleChildren()
	{
		assert(game.phase == Phase.MetaLook);
		game._phase = Phase.Look;
		
		foreach(ref e; game.entities) //Parallelify
		{
			if(!e.hasMeta && this is e.parent && true) //TODO Add user filter (same for drawChildren)
			{
				if(e.hasLook) e.e.look;
				if(e.hasStep) {
					version(assert) {
						//TODO Trace cycles and report offending entities.
						assert(e.stepped, "Dependency cycle or metaphasic congruency violation detected.");
						//No, seriously, it's an actual thing.
					}
					e.stepped = false;
					//assert(0.0 <= dt && dt <= 1.0, "Delta time "~to!string(dt)~" is outside acceptable range.");
					//e.dt = ftni!ushort(dt); //ftni is float-to-normalised-integer (ushort in this case)
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
	void drawChildren(Artist artist, double nt)
	{
		assert(game.phase == Phase.MetaDraw);
		game._phase = Phase.Draw;
		
		foreach(ref e; game.entities) //Parallelify
		{
			if(e.hasDraw && !e.hasMeta && this is e.parent && true) //Add user filter
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
	 * enforce them. Your entities don't need no
	 * mods trying to give them trouble, nuh-uh.
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
	 * ctor can optionally accept an Entity reference to
	 * the entity that created this entity, plus other
	 * arbitrary arguments if the creator is using a
	 * concrete factory type.
	 * 
	 * Examples:
	 * void ctor() { }
	 * void ctor(Entity creator) { }
	 * void ctor(Entity creator, uint x, ...) { }
	 * 
	 * This stub exists for documentation purposes only.
	 */
	void _ctor() { /* Huzzah */ };

	/**
	 * Destructor phase.
	 * 
	 * Dtor (destructor) phase is called instead of ~this().
	 * The true ~this() is only called some time later after 
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
	 * 'container' entity. (But I don't know how you'll build
	 * your game.)
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
	 * by some arbitrary measure; perhaps game.looper.dt, or the
	 * time stepped by one of the physical bodies it owns (to 
	 * match any effects applied through the physics engine).
	 * 
	 * This is the place to spawn or destroy entities, play 
	 * sounds, adjust models, advance animations, apply forces, 
	 * set positions, update bounds, etc. 
	 * 
	 * Note that many parts of the physics engine are thread-safe
	 * and may be used during this and other phases. Other APIs 
	 * might also be available if they are properly synchronised.
	 */
	void step();

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
	 * If you wish to implement motion blur, the normalized time 
	 * (nt) of the frame is provided. The phase will be repeated
	 * for each sample composited. 
	 * 
	 * This phase is repeated for each observing camera. To skip
	 * unnecessary work, a flag is provided on each model that 
	 * is true whenever the model's LOD has changed between 
	 * cameras or time has progressed. If it is false, an update 
	 * is unnecessary unless the model must appear different to 
	 * specific cameras. The camera is available as artist.camera.
	 */
	void draw(Artist artist, double nt);

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
	 * meta(Phase.MetaDraw) controls all rendering, by configuring 
	 * artists and windows, and calling drawChildren.
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
	@disable this(this);

	void _moved()
	{
		assert(e);
		e._proxy = &this;
	}

	R!Entity e;
	Entity parent;
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
				if(e is child.parent) result = dg(child);
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

/*
import raider.engine.physics;

interface Environment
{
	World world();
}
*/

/* The rules, in brief:
 * 
 * Public data may only be written in the step and ctor phases.
 * A dependency's public data may only be read in the step phase.
 * Factory data may only be written with explicit synchronisation.
 * Only graphical data may be written during the draw phase.
 * 
 * The meta phases are single-threaded and have no rules.
 */

/* 2-8-2017
 * Regarding compound entities..
 * 
 * If you say, 'I want this entity to be composed of a few others',
 * well, first of all, consider not doing that, because that's a
 * door back to composition over inheritance. An entity is its own 
 * being; it doesn't share the fact of its existence with others.
 * The components you wish to compose need to exist below the level
 * of a game entity.
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
 * Regarding xentities (extensible entities.. extensities?)
 * This is a concept for a 'scripted' entity, driven entirely by XML.
 * It's designed to easily and dynamically create entities with simple behaviours.
 * Essentially it's a scripting language built from xml tags. They specify the same
 * look / step / draw phases, but only very simple instructions are available.
 * For instance, it can use logic gates, then specify to create a physical object 
 * with a name, bounds, and model; it might then specify that model's material, 
 * colour, mesh, texture etc.
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
 * More complex and specialised logic tools can embed within this graph system.
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
