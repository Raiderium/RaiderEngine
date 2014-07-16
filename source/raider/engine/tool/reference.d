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
 * 
 * Not compatible with any system that mishandles structs.
 * I.e. associative arrays. Use tool.map.
 */

module raider.engine.tool.reference;

import std.conv;
import std.algorithm;
import std.traits;
import core.atomic;
import core.exception;
import core.memory;
import core.stdc.stdlib;

import raider.engine.tool.array;

//Evaluates true if an aggregate type has GC-scannable fields.
package template hasGarbage(T)
{
	template Impl(T...)
	{
		static if (!T.length)
			enum Impl = false;
		else static if(isInstanceOf!(R, T[0]) || 
		               isInstanceOf!(P, T[0]) ||
		               isInstanceOf!(W, T[0]) ||
		               isInstanceOf!(Array, T[0]))
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
	struct hasGarbageTest
	{
	struct S1 { void* ptr; } static assert(hasGarbage!S1);
	struct S2 { int ptr; } static assert(!hasGarbage!S2);
	struct S3 { R!int i; } static assert(!hasGarbage!S3);
	struct S4 { int l; union { int i; R!int j; void* k; }} static assert(hasGarbage!S4);
	class C1 { void* ptr; } static assert(hasGarbage!C1);
	class C2 { int ptr; } static assert(!hasGarbage!C2);
	class C3 { R!int i; } static assert(!hasGarbage!C3);
	class C4 { R!(R!int) ii; } static assert(!hasGarbage!C4);
	static assert(!hasGarbage!(R!int));
	//static assert(!hasGarbage!(R!(void*))); TODO Allow boxing of pointers.
	static assert(hasGarbage!(void*));
	}
}

private:

private template isReference(T)
{
	enum isReference = 
		isInstanceOf!(R, T) || 
		isInstanceOf!(W, T) ||
		isInstanceOf!(P, T);
}

//Encapsulates value types.
template Box(T)
{
	static if(is(T == class) || is(T == interface))
	{
		alias T Box;
	}
	else static if(is(T == struct) || isScalarType!T)
	{
		class Box
		{
			T _t; alias _t this;
			static if(is(T == struct))
				this(A...)(A a) { _t = T(a); } 
			else
				this(T t) { _t = t; }
		}
	}
	else
		static assert(0, T.stringof~" is not a boxable type");
}

//This is prepended to referenced objects
struct Header
{
	ushort refs = 0; //references
	ushort wefs = 0; //weak references
	version(assert)
	{
		ushort pefs = 0; //pointer references
		ushort padding; //make CAS happy (needs 8, 16, 32 or 64 bits)
	}
}

/**
 * Allocates and constructs a reference counted object.
 */
R!T New(T, Args...)(Args args)
if(is(T == class) || is(T == struct) || isScalarType!T)
{
	enum size = __traits(classInstanceSize, Box!T);

	//Allocate space for the header + object
	void* m = malloc(Header.sizeof + size);
	if(!m) onOutOfMemoryError;
	scope(failure) core.stdc.stdlib.free(m);
	
	void* o = m + Header.sizeof;
	
	//Got anything the GC needs to worry about?
	static if(hasGarbage!T)
	{
		GC.addRange(o, size);
		scope(failure) GC.removeRange(o);
	}
	
	//Initialise header
	*cast(Header*)m = Header.init;

	//Construct with emplace
	R!T result;
	result._referent = emplace!(Box!T)(o[0..size], args);
	result.header.refs = 1;
	return result;
}

/**
 * A strong reference.
 * 
 * When there are no more strong references to an object
 * it is immediately deconstructed. This guarantee is 
 * what makes reference counting actually useful.
 *
 * This struct implements incref/decref semantics. The 
 * reference is aliased so the struct can be used as if 
 * it were the reference.
 */
struct R(T)
if(is(T == class) || is(T == interface) ||
   is(T == struct) || isScalarType!T)
{private:
	alias Box!T B;

	//The referent. _void gives convenient access.
	union { public B _referent = null; void* _void; }

	//The header.
	ref shared(Header) header()
	{ return *((cast(shared(Header)*)_void) - 1); }

	//Reference counting semantics.
	void _incref()
	{
		if(_referent) atomicOp!"+="(header.refs, 1);
	}

	void _decref()
	{
		/* Let us discuss lockless weak references
		 * 
		 * There are three rules:
		 * - The object is destructed when refs reach 0.
		 * - The memory is freed when refs and wefs reach 0.
		 * - Must be destructed and freed once, in that order.
		 * 
		 * Decref:
		 * If no more refs, dtor and set refs max.
		 * If no more refs OR wefs, do as above, then 
		 * decwef. If wefs max, free.
		 * 
		 * Decwef:
		 * If no more wefs, and refs max,
		 * decwef. If wefs max, free.
		 * 
		 * You are not expected to understand this.
		 * Or its implementation.
		 * I sure don't.
		 */

		if(_referent)
		{
			//Do a CAS, locking on the entire header
			Header get, set;

			do
			{
				get = set = atomicLoad(header);
				set.refs -= 1;
			}
			while(!cas(&header(), get, set));

			//If no more refs, dtor and set refs max.
			if(set.refs == 0)
			{
				_dtor;
				scope(exit) //the memory must be freed, come what may
				{
					atomicStore(header.refs, ushort.max); //Mark dtor complete

					//If no more wefs, decwef. If wefs max, free.
					if(atomicLoad(header.wefs) == 0 &&
					atomicOp!"-="(header.wefs, 1) == ushort.max)
						_free;
				}
			}
		}
	}
	
public:
	alias _referent this;

	/**
	 * Promote to a strong reference from a raw pointer.
	 * The pointer is trusted to point at valid header'd
	 * memory for the duration.
	 * 
	 * A weak reference fulfills that trust.
	 * A pointer reference often does not (don't risk it).
	 */
	this(A:B)(A that)
	{
		if(that)
		{
			Header get, set;
			do
			{
				_referent = that;
				get = set = atomicLoad(header);

				//If refs are 0 or max, do not acquire.
				//(destruction in progress or complete)
				if(set.refs == ushort.max || set.refs == 0)
					_referent = null;

				//Otherwise, incref.
				else
					set.refs += 1; 
			}
			while(!cas(&header(), get, set));
		}
	}
	this(this) { _incref; }
	~this() { _decref; }

	void opAssign(A:T)(R!A rhs) { swap(_referent, rhs._referent); }
	void opAssign(A:T)(W!A rhs) { this = R!A(rhs); }
	void opAssign(typeof(null) wut) { _decref; _referent = null; }

	A opCast(A)() const if(isReference!A)
	{ return A(cast(A.B)_referent); }
	
	A opCast(A)() const if(!isReference!A)
	{ return cast(A)_referent; }

private:
	void _dtor()
	{
		void* o = _void;
		
		//alias this makes it mildly impossible to call B.~this
		//FIXME Likely to explode if an encapsulated T uses alias this
		static if(is(T == struct))
		{
			destroy(_referent._t);
		}
		else static if(is(T == class) || is(T == interface))
		{
			destroy(_referent);
		}
		//numeric types don't need destruction
		
		//Reestablish referent (destroy() assigns null)
		_void = o;
		
		assert(header.pefs == 0);
	}

	void _free()
	{
		static if(hasGarbage!T) GC.removeRange(_void);
		core.stdc.stdlib.free(_void - Header.sizeof);
	}
}

version(unittest)
{
	import std.stdio;
	int printfNope(in char* fmt, ...) { return 0; }
	alias printf log;

	class C4 { C5 c5; this(int x) { log("C4\n"); } ~this() { log("~C4\n"); } }

	struct S5 { R!C4 c4; R!C5 c5; int foo;
		this(int foo) { this.foo = foo; log("S5\n"); } ~this() { log("~S5\n"); }
		this(this) { assert(0, "Boxed S5 struct copy"); } }

	class C5 { R!S5 s5; R!C4 c4;
		this(R!C4 c4, R!S5 s5) { this.c4 = c4; this.s5 = s5; log("C5\n"); }
		~this() { log("~C5\n"); }}

	unittest
	{
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
}



//Test inheritance
version(unittest)
{
	class Animal
	{
		this() { log("new animal\n") ;}
		~this() { log("dead animal\n") ;}
		abstract void bite();
	}
	
	class Dog : Animal
	{
		this() { log("new dog\n");}
		~this() { log("dead dog\n"); }
		override void bite() { }
	}
	
	class Cat : Animal
	{
		this() { log("new cat\n"); }
		~this() { log("dead cat\n"); }
		override void bite() { log("cat bite\n") ;}
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
 * so help describe ownership. They also break
 * reference cycles that lead to memory leaks.
 * 
 * Weak references are like pointers, except they 
 * do not need to be nullified manually, they can 
 * promote to a strong reference, and they can 
 * check if the referent is alive.
 * 
 * That said, don't use a weak reference if a
 * pointer reference will do. They impose a 
 * performance penalty.
 */
struct W(T)
if(is(T == class) || is(T == interface) ||
   is(T == struct)|| isScalarType!T)
{private:
	alias Box!T B; union { public B _referent = null; void* _void; }

	ref shared(Header) header()
	{ return *((cast(shared(Header)*)_void) - 1); }

	void _incwef() { if(_referent) atomicOp!"+="(header.wefs, 1); }
	void _decwef()
	{
		if(_referent)
		{
			Header get, set;
			
			do
			{
				get = set = atomicLoad(header);
				set.wefs -= 1;
			}
			while(!cas(&header(), get, set));

			//If no more wefs
			if(set.wefs == 0)
			{
				//If refs max, decwef. If wefs max, free.
				if(atomicLoad(header.refs) == ushort.max &&
				atomicOp!"-="(header.wefs, 1) == ushort.max)
					_free;
			}
		}
	}
	
public:
	alias _referent this;

	this(A:B)(A that) { _referent = that; _incwef; }
	this(this) { _incwef; } 
	~this() { _decwef; }

	void opAssign(A:T)(W!A rhs) { swap(_referent, rhs._referent); }
	void opAssign(A:T)(R!A rhs) { this = W!A(rhs); }
	void opAssign(typeof(null) wut) { _decwef; _referent = null; }
	
	A opCast(A)() const if(isReference(A)) { return A(cast(A.B)_referent); }
	A opCast(A)() const if(!isReference(A)) { return cast(A)_referent; }
}

/**
 * A pointer reference.
 * 
 * Pointer references are like weak references, but
 * they cannot check validity, and must not be accessed
 * unless validity is assured by the programmer.

 * An assert will raise if pointer refs remain when the 
 * last strong reference expires. Make sure to nullify 
 * all pointer refs in the object destructor. In release
 * mode, the assert is removed, and pointer refs become
 * as efficient as their namesake, reducing the garbage 
 * collection footprint.
 */
struct P(T)
if(is(T == class) || is(T == interface) ||
   is(T == struct)|| isScalarType!T)
{private:
	alias Box!T B; union { public B _referent = null; void* _void; }

	ref shared(Header) header()
	{ return *((cast(shared(Header)*)_void) - 1); }

	version(assert)
	{
		void _incpef() { if(_referent) atomicOp!"+="(header.pefs, 1); }
		void _decpef() { if(_referent) atomicOp!"-="(header.pefs, 1); }
	}
	
public:
	alias _referent this;

	version(assert)
	{
		this(A:B)(A that) { _referent = that; _incpef; }
		this(this) { _incpef; } 
		~this() { _decpef; }
	}
	else
		this(A:B)(A that) { _referent = that; }

	void opAssign(A:T)(P!A rhs) { swap(_referent, rhs._referent); }
	void opAssign(A:T)(R!A rhs) { this = P!A(rhs); }
	void opAssign(A:T)(W!A rhs) { this = P!A(rhs); }

	void opAssign(typeof(null) wut) { version(assert) _decpef; _referent = null; }
	
	A opCast(A)() const if(isInstanceOf!(P, A)) { return A(cast(A.B)_referent); }
	A opCast(A)() const if(!isInstanceOf!(P, A)) { return cast(A)_referent; }
}

unittest
{
	R!Cat cat = New!Cat();
	P!Cat wcat = cat;
	assert(cat.header.refs == 1);
	assert(cat.header.pefs == 1);
	wcat = null;
	assert(cat.header.wefs == 0);
	assert(wcat == null);

	//how am I supposed to assert that the cat died?
	//this is dumb :c
}