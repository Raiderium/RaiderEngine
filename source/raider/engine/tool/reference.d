/**
 * Reference-count garbage collection
 * 
 * Provides garbage collection based on reference
 * counting instead of scanning. This gives a tight 
 * object lifespan with guaranteed destruction and
 * no processing bursts. Uses malloc and free from 
 * the C standard library and is thread-safe.
 * 
 * This is better for games because D currently has a
 * stop-the-world scanning collector. The work bunches 
 * up into frame-shattering chunks, causing the game
 * to pause intermittently. The overhead of incrementing 
 * and decrementing reference counts is so tolerable 
 * in this situation it's embarassing.
 * 
 * The GC is made aware of RC memory if it contains 
 * indirections - that is, pointers, references, arrays 
 * or delegates that might lead to GC memory. To avoid 
 * being scanned, don't store things the GC cares about,
 * that is, anything detected by std.traits.hasIndirections.
 * This does not include RC references themselves, which
 * are ignored via some reflective cruft.
 * 
 * Just to be clear, GC use is minimised, not prohibited.
 * Sometimes it is valuable or inevitable, particularly
 * with exception handling. But, by using determinism 
 * where it counts, we make our games smoother.
 *
 * Very important warning you saw coming miles off:
 * Do not create circular references.
 * This system cannot detect them.
 * Use weak references to avoid them.
 */

module raider.engine.tool.reference;

import std.stdio;
import std.conv;
import std.algorithm;
import std.traits;
import core.atomic;
import core.exception;
import core.memory;
import core.stdc.stdlib;

//Evaluates true if an aggregate type has scannable fields.
private template hasGarbage(T)
{
	template Impl(T...)
	{
		static if (!T.length)
			enum Impl = false;
		else static if(isInstanceOf!(R, T[0]) || isInstanceOf!(W, T[0]))
			enum Impl = Impl!(T[1 .. $]);
		else static if(is(T[0] == struct) || is(T[0] == union))
			enum Impl = Impl!(FieldTypeTuple!(T[0]), T[1 .. $]);
		else
			enum Impl = hasIndirections!(T[0]) || Impl!(T[1 .. $]);
	}
	
	static if(isInstanceOf!(R, T) || isInstanceOf!(W, T))
		enum hasGarbage = false;
	else
		enum hasGarbage = Impl!(FieldTypeTuple!T);
}

version(unittest)
{
	struct S1 { void* ptr; }
	struct S2 { int ptr; }
	struct S3 { R!int i; }
	struct S4 { int l; union { int i; R!int j; void* k; }}
	class C1 { void* ptr; }
	class C2 { int ptr; }
	class C3 { R!int i; }
	
	static assert(hasGarbage!S1);
	static assert(!hasGarbage!S2);
	static assert(!hasGarbage!S3);
	static assert(hasGarbage!S4);
	static assert(hasGarbage!C1);
	static assert(!hasGarbage!C2);
	static assert(!hasGarbage!C3);
	static assert(!hasGarbage!(R!int));
	//static assert(!hasGarbage!(R!(void*))); TODO Allow boxing of pointers.
	static assert(hasGarbage!(void*));
}

/**
 * Allocates and constructs a reference counted object.
 */
R!T New(T, Args...)(Args args)
	if(is(T == class) || is(T == struct) || isScalarType!T)
{
	enum size = __traits(classInstanceSize, (R!T).B);

	//Allocate space for the object and a refcount.
	void* m = malloc(ulong.sizeof + size);
	if(!m) onOutOfMemoryError;
	scope(failure) core.stdc.stdlib.free(m);
	
	void* o = m + ulong.sizeof;
	
	//Got anything the GC needs to worry about?
	static if(hasGarbage!T)
	{
		GC.addRange(o, size);
		scope(failure) GC.removeRange(o);
	}
	
	//Initialise refcounts to 0
	*cast(ulong*)m = 0;
	return R!T(emplace!(R!(T).B)(o[0..size], args));
}

/**
 * A strong reference.
 * 
 * The reference is held in a struct with incref/decref 
 * semantics. It is aliased so the struct can be used
 * as if it were the reference.
 * 
 * When there are no more strong references to an object
 * it is immediately deconstructed. This guarantee is 
 * what makes reference counting actually useful.
 */
struct R(T) if(is(T == struct) || isScalarType!T ||
               is(T == class) || is(T == interface))
{private:
	
	//Box value types.
	static if(is(T == struct) || isScalarType!T)
		class B {
			T _t; alias _t this;
			static
				if(is(T == struct)) this(A...)(A a) { _t = T(a); }
			else
				this(T t) { _t = t; }
	}
	else alias T B;

	//The reference. Union with void* allows convenient access.
	union { B _b = null; void* _void; }

	//Reference counting semantics.
	shared(uint)* refs() { return (cast(shared(uint)*)_void) - 2; }
	shared(uint)* wefs() { return (cast(shared(uint)*)_void) - 1; }
	void _incref() { if(_b) atomicOp!"+="(*refs, 1); }
	void _decref() { if(_b && atomicOp!"-="(*refs, 1) == 0) _delete; }

	//Delete is the counterpart to New.
	void _delete()
	{
		void* o = _void;
		
		//alias this makes it mildly impossible to call B.~this
		static if(is(T == struct)) destroy(_b._t);
		else static if(!isScalarType!T) destroy(_b);
		//FIXME Likely to explode if T uses alias this...
		
		//Let's not let a throwing destructor ruin the fun
		scope(exit)
		{
			assert(*wefs == 0);
			//TODO Zombies.
			
			static if(hasGarbage!T) GC.removeRange(o);
			core.stdc.stdlib.free(o - ulong.sizeof);
			
			_b = null;
		}
	}
	
public:
	alias _b this;
	
	this(A:B)(A that) { _b = that; _incref; }
	this(this) { _incref; }
	~this() { _decref; }

	void opAssign(A:T)(R!A rhs) { swap(_b, rhs._b); }
	void opAssign(typeof(null) wut) { _decref; _b = null; }

	A opCast(A)() const if(isInstanceOf!(R, A) || isInstanceOf!(W, A))
	{ return A(cast(A.B)_b); }
	
	A opCast(A)() const if(!isInstanceOf!(R, A) && !isInstanceOf!(W, A))
	{ return cast(A)_b; }
}

version(unittest)
{
	class C4
	{
		C5 c5; //Garbage collector is interested in this!

		this(int x) { printf("C4\n"); }
		~this() { printf("~C4\n"); }
	}
	
	class C5
	{
		R!S5 s5; //Garbage collector finds this insignificant and boring!
		R!C4 c4; //Forms a reference cycle if c4.c5 is initialised to this.

		this(R!C4 c4, R!S5 s5) { printf("C5\n"); this.c4 = c4; this.s5 = s5; }
		~this() { printf("~C5\n"); }
	}
	
	//FIXME Defining S5 above C5 causes isNumeric to explode.
	//Uncommenting the line below and putting it above S5 fixes it.
	//static if(isNumeric!C5) {}
	//Is this a DMD bug? Feels vaguely like one.
	struct S5
	{
		R!C4 c4;
		R!C5 c5;
		this(int foo) { printf("S5\n"); this.foo = foo; }
		this(this) { assert(0, "Boxed S5 struct copy"); }
		~this() { printf("~S5\n"); }
		int foo;
	}
}

unittest
{
	//TODO Unittest this with assert, not printf :/
	//how to do that is beyond me at this point
	
	static assert(hasGarbage!C4);
	static assert(!hasGarbage!C5);
	static assert(hasIndirections!C5);
	static assert(!hasGarbage!S5);
	static assert(hasIndirections!S5);
	
	R!S5 s5;
	s5 = New!S5(3);

	//up-periscope!
	{
		R!C5 c5 = New!C5(New!C4(4), New!S5(4));
		s5 = c5.s5;
	}
	//dive, dive, dive!
}

//Test inheritance
version(unittest)
{
	class Animal
	{
		this() { printf("Animal\n"); }
		~this() { printf("~Animal\n"); }
		abstract void bite();
	}
	
	class Dog : Animal
	{
		this() { printf("Dog\n"); }
		~this() { printf("~Dog\n"); }
		override void bite() { printf("Dog.bite\n"); }
	}
	
	class Cat : Animal
	{
		this() { printf("Cat\n"); }
		~this() { printf("~Cat\n"); }
		override void bite() { printf("Cat.bite\n"); }
	}
	
	void poke(R!Animal animal)
	{
		animal.bite();
	}
}

unittest
{
	R!Animal a = New!Dog();
	
	R!Dog d = cast(R!Dog)a;
	assert(d != null);
	R!Cat c = cast(R!Cat)a;
	assert(c == null);
	assert(cast(R!Cat)a == null);

	//Cannot implicitly downcast, requires language support.
	//poke(d); //Doesn't work. Sadface.
	poke(cast(R!Animal)d); //Works. Meh.
}

/**
 * A weak reference.
 * 
 * Weak references do not keep objects alive and
 * help describe ownership. They also break
 * reference cycles that lead to memory leaks.
 * 
 * Currently, all weak references must be nulled before 
 * the last strong reference expires. This is not an 
 * unreasonable constraint as it encourages good program 
 * design, but in future it will be relaxed for the sake 
 * of flexibility (read: rustling fewer modders' jimmies).
 * This flexibility requires two reference counts and a 
 * 'zombie' object state, arguably a worthwhile feature
 * in and of itself.
 * 
 * When this feature is implemented, weak reference validity
 * can be checked, and attempting to dereference a weak 
 * reference to a destroyed object can be reliably detected 
 * and treated as an exception offence in scripts instead 
 * of a lethal assert. It can be disabled for well-tested 
 * releases, reducing the garbage collection footprint.
 * 
 * Weak reference checks are disabled in release mode.
 */
struct W(T)
	if(is(T == class) || is(T == struct) || 
	   is(T == interface) || isScalarType!T)
{private:
	alias R!(T).B B; union { B _b = null; void* _void; }
	shared(uint)* wefs() { return (cast(shared(uint)*)_void) - 1; }

	version(assert)
	{
		void _incwef() { if(_b) atomicOp!"+="(*wefs, 1); }
		void _decwef() { if(_b) atomicOp!"-="(*wefs, 1); }
	}
	
public:
	alias _b this;
	
	this(A:B)(A that) { _b = that._b; version(assert) _incwef; }
	version(assert)
	{
		this(this) { _incwef; } 
		~this() { _decwef; }
	}
	
	void opAssign(A:T)(R!A rhs) { swap(_b, rhs._b); }
	void opAssign(A:T)(W!A rhs) { swap(_b, rhs._b); }
	void opAssign(typeof(null) wut) { version(assert) _decwef; _b = null; }
	
	A opCast(A)() const if(isInstanceOf!(W, A)) { return A(cast(A.B)_b); }
	A opCast(A)() const if(!isInstanceOf!(W, A)) { return cast(A)_b; }
}

unittest
{
	R!Cat cat = New!Cat();
	W!Cat wcat = cat;
	assert(*cat.refs == 1);
	assert(*cat.wefs == 1);
	wcat = null;
	assert(*cat.wefs == 0);
	assert(wcat == null);
	cat = null;
	assert(cat == null);

	//how am I supposed to assert that the cat died?
	//this is dumb :c
}