/**
 * Reference-count garbage collection
 * 
 * Provides garbage collection based on reference
 * counting instead of scanning. This gives a tight 
 * object lifespan with guaranteed destruction and
 * no processing bursts. Uses malloc and free from 
 * the C standard library. Thread-safe.
 * 
 * This is better for games because scanning for garbage
 * stops the world, which is a Bad Thing In This Case.
 * The work bunches up into frame-shattering chunks
 * because D doesn't have an incremental collector yet.
 * The cost of incrementing and decrementing reference 
 * counts is so tolerable in this situation it's embarassing.
 * 
 * The GC is made aware of RC memory if it contains 
 * aliasing - that is, pointers, references, arrays, or 
 * delegates that might lead to GC memory. To avoid being 
 * scanned, don't store things the GC is interested in.
 * (hasAliasing! from std.traits should evaluate false.)
 * RC references are stored in a non-interesting field 
 * type so they don't register.
 * 
 * Just to be clear, use of the GC is minimised, not prohibited.
 * Sometimes it is valuable / inevitable, particularly
 * with exception handling. But, by using a little 
 * determinism where it counts, we make our games smoother.
 *
 * Very important warning you saw coming miles off:
 * Do not create structures capable of circular references.
 * This system cannot detect them.
 * Use weak references to avoid them and clarify ownership.
 * 
 * TODO ... actually compile this and profile performance
 * i really hope this was necessary
 */

module raider.engine.tool.reference;

import std.conv;
import std.algorithm;
import std.traits;
import core.atomic;
import core.exception;
import core.memory;
import core.stdc.stdlib;

/**
 * Allocates and constructs a reference counted object.
 * 
 * Space is allocated to store the object and a size_t refcount.
 * When it drops to 0, the object is immediately deconstructed
 * and the memory is released.
 * 
 * To update refcounts and prevent the special instances from 
 * unintentionally escaping into the wild and being mishandled, 
 * they are encapsulated within R! and W! structs.
 * 
 * In debug mode, there are two ushort refcounts, one strong,
 * one weak. When the strong refcount drops to 0, the object is 
 * deconstructed, but the memory lingers until the weak refcount 
 * is 0. Attempts to dereference a weak pointer to a destroyed 
 * object can then be detected.
 */
R!T New(T, Args...)(Args args) if(is(T == class))
{
	enum size = __traits(classInstanceSize, T);

	//Allocate.
	//Adding space for the refcount(s) is a bit of a kludge. 
	//But, it avoids invading the class definition. :)
	debug void* m = malloc(size + ushort.sizeof*2);
	else  void* m = malloc(size + size_t.sizeof);

	if(m == null) onOutOfMemoryError; //throws OutOfMemoryError
	scope(failure) core.stdc.stdlib.free(m);

	//Got anything the GC needs to worry about?
	static if(hasAliasing!T)
	{
		GC.addRange(m, size);
		scope(failure) GC.removeRange(m);
	}

	//Constructeth!
	R!T r;
	*r.refcount_ptr = 1;
	debug *r.weak_refcount_ptr = 0;
	r.__obj = cast(size_t) emplace!(T)(m[0..size], args);

	return r;
}

/**
 * A strong reference.
 * 
 * The T object reference is aliased so the struct 
 * can be manipulated as if it were the reference.
 */
struct R(T) if(is(T == class))
{private:
	size_t __obj = 0; //Reference hidden from hasAliasing

	debug
	{
		ushort* refs()
		{ return cast(ushort*)( (cast(T*)&__obj) + 1); }
		ushort* weakrefs()
		{ return (cast(ushort*)( (cast(T*)&__obj) + 1)) + 1; }
		//TODO blehr. Move refcounts to BEFORE the pointed-at address.
		//A mental block is stopping me from conceptualising what happens 
		//when you do maths with an interface pointer

		//instinct says there will be alignment issues or something
		//whatever
		//sleeep ~
	}
	else
	{
		size_t* refs()
		{ return cast(size_t*)( (cast(T*)&__obj) + 1);}
	}

public:
	@property T _obj() { return cast(T)__obj; }
	alias _obj this;

	/**
	 * If a T reference is divorced from its container
	 * for some reason (e.g. access via 'this')
	 * then restore order with this constructor. But 
	 * don't pass T references not originally allocated 
	 * by New. Please.
	 */
	this(const T that)
	{
		__obj = cast(size_t)that;
		_incref;
	}

	this(this)
	{
		_incref;
	}
	
	~this()
	{
		_decref;
	}
	
	//Assignment of T and inheritors
	void opAssign(U:T)(R!U rhs)
	{
		//Copy-and-swap
		swap(__obj, rhs.__obj);
	}

	//Prevent assignment of external references to T and inheritors
	//void opAssign(U:T)(U rhs)
	//{
	//	//alias this would otherwise forward T.opAssign (for structs, anyway)
	//	static assert(0);
	//} UUH So this dun compile lol. Methings R! for structs will need some work.
	
	//Cast to inheritors
	R!U opCast(U:T)(R!U) const
	{
		R!U result;		
		result.__obj = cast(size_t)cast(U)cast(T)__obj;
		result.incref;
		return result;
	}
	
	bool opCast(B)() if(is(B == bool))
	{
		return cast(bool)__obj;
	}
	
private:
	void _incref()
	{
		if(__obj) atomicOp!"+="(cast(shared)refcount_ptr, 1);
	}

	void _decref()
	{
		if(__obj)
		{
			if(atomicOp!"-="(cast(shared)refcount_ptr, 1) == 0)
			{
				void* m = cast(void*)__obj;
				__obj = 0;
				
				scope(exit)
				{
					static if(hasAliasing!T) GC.removeRange(m);
					core.stdc.stdlib.free(m);
				}
				
				destroy(cast(T)older);
			}
		}
	}
}

/**
 * A weak reference.
 */
struct W(T) if(is(T == class))
{public:
	// TODO Weak references.
}