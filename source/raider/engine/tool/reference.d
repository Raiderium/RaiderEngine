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
 * Not compatible with any system that mishandles structs.
 * I.e. associative arrays. Use tool.map.
 */

module raider.engine.tool.reference;

import std.conv : emplace;
import std.traits;
import core.atomic;
import core.exception : onOutOfMemoryError;
import core.memory : GC;
import core.stdc.stdlib : malloc, free;

import raider.engine.tool.array;

//Evaluates true if an aggregate type has GC-scannable fields.
package template hasGarbage(T)
{
	template Impl(T...)
	{
		static if (!T.length)
			enum Impl = false;
		else static if(isInstanceOf!(R, T[0]) || 
		               isInstanceOf!(W, T[0]) ||
		               isInstanceOf!(P, T[0]) ||
		               isInstanceOf!(Array, T[0]))
			enum Impl = Impl!(T[1 .. $]);
		else static if(is(T[0] == struct) || is(T[0] == union))
			enum Impl = Impl!(FieldTypeTuple!(T[0]), T[1 .. $]);
		else
			enum Impl = hasIndirections!(T[0]) || Impl!(T[1 .. $]);

		/* TODO Allow weak references to break cycles.
		 * 
		 * Reference template evaluation fails when
		 * references form a cycle. T.tupleof fails 
		 * because T is a forward reference.
		 * 
		 * Presumably a recursion issue; how can it
		 * know the structure of T until evaluating
		 * R!T; how can it finish evaluating R!T until
		 * it knows the structure of T, etc.
		 * 
		 * Oddly enough, T.tupleof only fails in 
		 * ~this() and static scope; it works fine 
		 * in this() and other methods.
		 * 
		 * Electing to ignore until the manure hits 
		 * the windmill and a class absolutely must
		 * have a non-pointer reference to its kin.
		 * The solution is to change the weak
		 * reference strategy from zombies to a list 
		 * of weak references, or a zombie monitor.
		 * 
		 * Serendipitously, the evaluation failure
		 * can be used to detect reference cycles
		 * at compile time.
		 */
	}

	static if(isInstanceOf!(R, T) || 
	          isInstanceOf!(W, T) ||
	          isInstanceOf!(P, T) ||
	          isInstanceOf!(Array, T))
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
		struct S4 { union { int i; R!int j; }} static assert(!hasGarbage!S4);
		class C1 { void* ptr; } static assert(hasGarbage!C1);
		class C2 { int ptr; } static assert(!hasGarbage!C2);
		class C3 { R!int i; } static assert(!hasGarbage!C3);
		class C4 { R!(R!int) ii; } static assert(!hasGarbage!C4);
		//class C5 { W!C5 i; } //See to-do in hasGarbage.
		class C7 { P!C7 i; } static assert(!hasGarbage!C7);
		static assert(!hasGarbage!(R!int));
		//static assert(!hasGarbage!(R!(void*))); TODO Pointer boxing?
		static assert(hasGarbage!(void*));
	}
}

private template Box(T)
{
	static if(is(T == class) || is(T == interface)) alias T Box;
	else static if(is(T == struct) || isScalarType!T)
	{
		class Box
		{
			T _t; alias _t this;
			static if(is(T == struct))
			this(A...)(A a) { _t = T(a); } 
			else this(T t = 0) { _t = t; }
		}
	}
	else static assert(0, T.stringof~" can't be boxed");
}

private struct Header(string C = "")
{
	ushort strongCount = 0;
	ushort weakCount = 0;
	version(assert)
	{
		ushort pointerCount = 0;
		ushort padding; //make CAS happy (needs 8, 16, 32 or 64 bits)
	}

	//Convenience alias to a reference's count.
	static if(C == "R") alias strongCount count;
	static if(C == "W") alias weakCount count;
	static if(C == "P") version(assert) alias pointerCount count;
}

/**
 * Allocates and constructs a reference counted object.
 */
public R!T New(T, Args...)(Args args)
	if(is(T == class) || is(T == struct) || isScalarType!T)
{
	enum size = __traits(classInstanceSize, Box!T);
	
	//Allocate space for the header + object
	void* m = malloc(Header!().sizeof + size);
	if(!m) onOutOfMemoryError;
	scope(failure) core.stdc.stdlib.free(m);
	
	void* o = m + Header!().sizeof;
	
	//Got anything the GC needs to worry about?
	static if(hasGarbage!T)
	{
		GC.addRange(o, size);
		scope(failure) GC.removeRange(o);
	}
	
	//Initialise header
	*cast(Header!()*)m = Header!().init;

	//Construct with emplace
	R!T result;
	result._referent = emplace!(Box!T)(o[0..size], args);
	result.header.strongCount = 1;
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
public alias Reference!"R" R;

/**
 * A weak reference.
 * 
 * Weak references do not keep objects alive and
 * so help describe ownership. They also break
 * reference cycles that lead to memory leaks.
 * (..Except they don't, yet.)
 * 
 * Weak references are like pointers, except they 
 * do not need to be nullified manually, they can 
 * promote to a strong reference, and they can 
 * check if the referent is alive.
 * 
 * That said, don't use a weak reference if a
 * pointer reference will do. They impose a 
 * performance penalty.
 * 
 * When you use a weak reference, it is promoted
 * automatically on each access. Better to assign 
 * it to a strong reference, then access that.
 */
public alias Reference!"W" W;

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
public alias Reference!"P" P;

//This is a template that returns a template
//I can honestly say it is necessary and useful
private template Reference(string C)
if(C == "R" || C == "W" || C == "P")
{
	struct Reference(T)
	if(is(T == class) || is(T == interface) || is(T == struct) || isScalarType!T)
	{ private:
		alias Box!T B;

		//Referent
		union { public B _referent = null; void* _void; }

		//Header
		ref shared(Header!C) header()
		{ return *((cast(shared(Header!C)*)_void) - 1); }

	public:

		//Make the reference behave like the referent
		static if(C == "W")
		{
			//Automatically promote weak references
			@property R!T _strengthen() { return R!T(_referent); }
			alias _strengthen this;
		}
		else alias _referent this; 

		//Incref/decref semantics
		this(this) { _incref; }
		~this() { _decref;  }

		//Construct weak and pointer refs from a raw ref
		static if(C != "R")
			this(B that) { _referent = that; _incref; }

		//Assign null
		void opAssign(typeof(null) wut)
		{
			static if(C == "P") { version(assert) { _decref; _referent = null; } }
			else { _decref; _referent = null; }
		}

		//Assign a reference of the same type
		void opAssign(D, A:T)(D!A rhs) if(is(D == Reference!C))
		{
			swap(_referent, rhs.referent);
		}

		//Assign a reference of a different type
		void opAssign(D, A:T)(D!A rhs)
		if(isInstanceOf(D, Reference) && !is(D == Reference!C))
		{
			alias Reference!C RefC; //for some reason D dislikes (Reference!C)!A
			this = RefC!A(rhs._referent); //can't really blame it
		}

		//Cast to a reference type
		A opCast(A)() const
		if(isInstanceOf!(R, A) || isInstanceOf!(W, A) || isInstanceOf!(P, A))
		{
			return A(cast(A.B)_referent);
		}

		//Cast to a non-reference type
		A opCast(A)() const
		if(!isInstanceOf!(R, A) && !isInstanceOf!(W, A) && !isInstanceOf!(P, A))
		{
			// ..I've no idea why D should dislike cast(bool)_referent, but it does.
			static if(is(A == bool)) return _referent is null ? false : true;
			else return cast(A)_referent;
		}

	private:

		//Incref / decref
		void _incref()
		{
			if(_referent) atomicOp!"+="(header.count, 1);
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
				//CAS the whole header, we need atomicity
				Header!C get, set;
				
				do {
					get = set = atomicLoad(header);
					set.count -= 1; }
				while(!cas(&header(), get, set));

				static if(C != "P")
				{
					if(set.count == 0)
					{
						static if(C == "R")
						{
							_dtor;
							scope(exit) //the memory must be freed, come what may
							{
								atomicStore(header.count, ushort.max);

								//If no more wefs, decwef. If wefs max, free.
								if(atomicLoad(header.weakCount) == 0 &&
								   atomicOp!"-="(header.weakCount, 1) == ushort.max)
									_free;
							}
						}
						static if(C == "W")
						{
							//If refs max, decwef. If wefs max, free.
							if(atomicLoad(header.strongCount) == ushort.max &&
							   atomicOp!"-="(header.weakCount, 1) == ushort.max)
								_free;
						}
					}
				}
			}
		}
		
		static if(C != "P")
		{
			void _free()
			{
				static if(__traits(compiles, FieldTypeTuple!T))
				{ static if(hasGarbage!T) GC.removeRange(_void); }
				else static assert(0, "Reference cycle!");

				core.stdc.stdlib.free(_void - Header!().sizeof);
			}
		}

		static if(C == "R")
		{
			/**
			 * Promote to a strong reference from a raw pointer.
			 * The pointer is trusted to point at valid header'd
			 * memory for the duration. Intended for use with
			 * the 'this' pointer, i.e. return R!MyClass(this).
			 */
			public this(B that)
			{
				if(that)
				{
					_referent = that;
					
					bool acquire;
					Header!C get, set;

					do {
						acquire = true;
						get = set = atomicLoad(header);

						//If refs are 0 or max, do not acquire.
						//(destruction in progress or complete)
						if(set.count == ushort.max || set.count == 0)
							acquire = false;
						//Otherwise, incref.
						else
							set.count += 1;
					}
					while(!cas(&header(), get, set));

					if(!acquire) _referent = null;
				}
			}

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
				
				//assert(header.pointerCount == 0);
			}
		}
	}
}

version(unittest)
{
	/* Of all the things that need to print stuff for
	 * debugging purposes, reference counting is about
	 * the neediest. */
	import std.stdio;
	int printfNope(in char* fmt, ...) { return 0; }
	alias printfNope log;
	//alias printf log;

	struct RTest
	{
		class C1 { P!C3 c3; } //Change to R!C3 to get a reference cycle error
		class C2 { R!C1 c1; }
		class C3 { R!C2 c2; }
	}

	struct PTest
	{
		unittest
		{
			R!int r = New!int();
			P!int p = r;
			assert(r.header.strongCount == 1);
			assert(r.header.pointerCount == 1);
			p = null;
			assert(r.header.pointerCount == 0);
			assert(p is null);
			assert(p == null);
		}
	}

	struct WTest
	{
		class C1 {
			int x;
			this() { log("WC1()\n"); }
			~this() { log("~WC1()\n"); } }
		
		unittest
		{
			R!C1 r = New!C1();
			assert(r != null);
			assert(r !is null);
			assert(r);
			assert(r.header.strongCount == 1);
			assert(r.header.weakCount == 0);
			assert(r.header.pointerCount == 0);
			
			W!C1 w = r;
			assert(w != null);
			assert(w !is null);
			assert(w);
			assert(r.header.strongCount == 1);
			assert(r.header.weakCount == 1);
			assert(r.header.pointerCount == 0);
			
			w.x = 1;
			assert(r.x == 1);
			r.x = w.x + w.x;
			assert(w.x == 2);
			assert(r.header.strongCount == 1);
			assert(r.header.weakCount == 1);
			assert(r.header.pointerCount == 0);
			
			R!C1 rr = w;
			assert(rr);
			assert(r.header.strongCount == 2);
			assert(r.header.weakCount == 1);
			assert(r.header.pointerCount == 0);
			
			r = null;
			assert(r == null);
			assert(r is null);
			assert(r._referent is null);
			assert(w);
			assert(w.header.strongCount == 1);
			assert(w.header.weakCount == 1);
			assert(w.header.pointerCount == 0);
			
			rr = null;
			assert(w == null);
			assert(w is null);
			assert(w._referent !is null);
			assert(w.header.strongCount == ushort.max);
			assert(w.header.weakCount == 1);
			assert(w.header.pointerCount == 0);
			
			r = w;
			assert(r is null);
			assert(w.header.strongCount == ushort.max);
			assert(w.header.weakCount == 1);
			assert(w.header.pointerCount == 0);
			
			w = null;
		}
	}

	struct RInheritanceTest
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
			override void bite() { log("dog bite\n"); }
		}
		
		class Cat : Animal
		{
			this() { log("new cat\n"); }
			~this() { log("dead cat\n"); }
			override void bite() { log("cat bite\n"); }
		}
		
		static void poke(R!Animal animal)
		{
			animal.bite();
		}

		unittest
		{
			R!Animal a = New!Dog();
			
			R!Dog d = cast(R!Dog)a; assert(d);
			R!Cat c = cast(R!Cat)a; assert(c == null);
			assert(cast(R!Cat)a == null);
			poke(cast(R!Animal)d);
			//Cannot implicitly downcast, requires language support.
		}
	}
}