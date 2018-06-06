/**
 * A metaprogramming disaster area.
 * 
 * Somehow helps to define semantically correct entities.
 */
module raider.engine.boilerplate;

/**
 * Entity definition boilerplate.
 */
mixin template Export(E)
{
	shared static this()
	{
		//TODO User-friendly error detection here and in factory stuff.
		mixin("alias F = " ~ E.stringof ~ "Factory;");

		import std.traits : hasUDA, fullyQualifiedName;

		//static assert(F.stringof == E.stringof ~ "Factory", "Please rename "~F.stringof~" to '"~E.stringof~"Factory'");
		static assert(is(E P == super) && is(P[0] == Entity), E.stringof ~ " must directly extend Entity.");
		static assert(is(F P == super) && is(P[0] == Factory), F.stringof ~ " must directly extend Factory.");
		static assert(hasUDA!(E, RC), E.stringof ~ " needs @RC.");
		static assert(hasUDA!(F, RC), F.stringof ~ " needs @RC.");

		Register.add(fullyQualifiedName!E, () { return cast(R!Factory)New!F(); } );
	}
}

mixin template Stuff()
{
	static if(is(typeof(super) == Entity))
	{
		enum hasMeta = __traits(compiles, meta(Phase.init));
		enum hasLook = __traits(compiles, look());
		enum hasStep = __traits(compiles, step());
		enum hasDraw = __traits(compiles, draw(Artist.init, 0.0));
		enum hasDtor = __traits(compiles, dtor());

		static assert(hasMeta || hasLook || hasStep || hasDraw,
			typeof(this).stringof ~ " needs to define at least one phase.");

		static assert(hasMeta != (hasLook || hasStep || hasDraw), 
			"A meta-entity cannot implement non-meta phases.");

		/* It is illegal in D to fail to provide an implementation for a
		 * method stub in the base class. However, it would annoy 
		 * developers to write empty method stubs, so the boilerplate 
		 * inserts them as necessary (and sets appropriate phase flags).*/
			
		static if(!hasMeta) override void meta(Phase phase) { assert(0, "AUGH"); }
		static if(!hasLook) override void look() { assert(0, "AUGH"); }
		static if(!hasStep) override void step() { assert(0, "AUGH"); }
		static if(!hasDraw) override void draw(Artist a, double nt) { assert(0, "AUGH"); }
		static if(!hasDtor) override void dtor() { assert(0, "AUGH"); }
		// AUGH

		this(Args...)(Game game, R!Factory factory, Entity parent, Entity creator, auto ref Args args)
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
	else static if(is(typeof(super) == Factory))
	{
		static import std.array;
		mixin("alias E = " ~ std.array.replace(typeof(this).stringof, "Factory", "") ~ ";");
		
		override string entityName() const
		{
			return E.stringof;
		}
		
		override string fullyQualifiedEntityName() const
		{
			import std.traits : fullyQualifiedName;
			return fullyQualifiedName!E;
		}
		
		override Entity create(Game game, Entity parent = null, Entity creator = null)
		{
			return New!E(game, R!Factory(this), parent, creator);
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
		auto create(Args...)(Game game, Entity parent, Entity creator, auto ref Args args) if(args.length)
		{
			return New!E(game, R!Factory(this), parent, creator, args);
		}
	}
	else static assert(0, "Stuff doesn't go in "~typeof(this).stringof ~ ". Did you forget to inherit Entity or Factory?");
}
