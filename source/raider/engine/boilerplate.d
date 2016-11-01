/**
 * A metaprogramming disaster area.
 * 
 * Somehow helps to define semantically correct entities.
 */
module raider.engine.boilerplate;

/**
 * Entity definition boilerplate.
 */
mixin template Boilerplate(E, F)
{
	static assert(F.stringof == E.stringof ~ "Factory", 
		"Please rename the factory "~F.stringof~" to '"~E.stringof~"Factory'");

	static assert(__traits(isFinalClass, E), "class " ~ E.stringof ~ " not final. All entities must be final.");
	static assert(__traits(isFinalClass, F), "class " ~ F.stringof ~ " not final. All factories must be final.");

	shared static this()
	{
		import std.traits : fullyQualifiedName;
		Register.add(fullyQualifiedName!E,
			(){ return cast(R!Factory)New!F(); });
	}
}

mixin template EntityBoilerplate()
{
	enum hasMeta = __traits(compiles, meta(Phase.init));
	enum hasLook = __traits(compiles, look());
	enum hasStep = __traits(compiles, step(0.0));
	enum hasDraw = __traits(compiles, draw(P!Artist.init, 0.0));
	enum hasDtor = __traits(compiles, dtor());

	static assert(hasMeta != (hasLook || hasStep || hasDraw), 
		"A meta-entity cannot implement non-meta phases.");
		
	static if(!hasMeta) override void meta(Phase phase) { assert(0, "AUGH"); }
	static if(!hasLook) override void look() { assert(0, "AUGH"); }
	static if(!hasStep) override void step(double dt) { assert(0, "AUGH"); }
	static if(!hasDraw) override void draw(P!Artist a, double nt) { assert(0, "AUGH"); }
	static if(!hasDtor) override void dtor() { assert(0, "AUGH"); }
	// "AUGH"

	this(Args...)(P!Game game, R!Factory factory, P!Entity parent, P!Entity creator, auto ref Args args)
	{
		uint phaseFlags = 	hasLook << 0 | hasStep << 1 | hasDraw << 2 | hasMeta << 3 | hasDtor << 4 | 
							hasStep << 5 | 1 << 7; //stepped, isAlive
		super(game, factory, parent, phaseFlags);
		static if(args.length != 0) ctor(creator, args);
		else {static if(__traits(compiles, ctor(creator))) ctor(creator);
		else {static if(__traits(compiles, ctor())) ctor(); } }
	}

	~this()
	{
		/* Dubious assertion. Good because it highlights an error, bad 
		 * because all assertions indirectly cause the error, adding to
		 * the chain the developer sees. */

		//import std.conv;
		//assert(game.phase == Phase.Cleanup, "Entity deconstructed in " ~ to!string(game.phase));
	}

	/* Pay this no mind, a solution is imminent.
	@property auto factory()
	{
		mixin("return cast(R!"~name~"Factory)(cast(Entity)this).factory;");
	}
	*/
}

mixin template FactoryBoilerplate()
{
	import std.array : replace;
	import std.traits : fullyQualifiedName;
	enum entity_name = typeof(this).stringof.replace("Factory", "");

	override string entityName() const
	{
		return entity_name;
	}

	override string fullyQualifiedEntityName() const
	{
		mixin("return fullyQualifiedName!"~entity_name~";");
	}

	override P!Entity create(P!Game game, P!Entity parent = null, P!Entity creator = null)
	{
		mixin("return P!Entity(New!"~entity_name~"(game, R!Factory(this), parent, creator));");
	}

	/**
	 * Create with arguments
	 * 
	 * With a reference to the concrete factory type, call
	 * 'create' and any arguments in addition to the basic
	 * ones will be passed to the entity's ctor().
	 * 
	 * This also returns with concrete entity type.
	 */
	auto create(Args...)(P!Game game, P!Entity parent, P!Entity creator, auto ref Args args) if(args.length)
	{
		mixin("return P!"~entity_name~"(New!"~entity_name~"(game, R!Factory(this), parent, creator, args));");
	}
}
