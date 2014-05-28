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
 * Space is allocated to store the object and a refcount.
 */
R!T New(T, Args...)(Args args) if(is(T == class))
{
	enum size = __traits(classInstanceSize, T);

	void* m = malloc(uint.sizeof + size);
	if(!m) onOutOfMemoryError;
	scope(failure) core.stdc.stdlib.free(m);

	void* o = m + uint.sizeof;

	//Got anything the GC needs to worry about?
	static if(hasAliasing!T)
	{
		GC.addRange(o, size);
		scope(failure) GC.removeRange(o);
	}

	//Initialise refcounts to 0
	*cast(uint*)m = 0;

	return R!T(emplace!(T)(o[0..size], args));
}

/**
 * A strong reference.
 * 
 * The T object reference is held in a struct with
 * auto incref/decref semantics. It is aliased so the 
 * struct can be manipulated as if it were the reference.
 * 
 * When there are no more strong references to an object
 * it is immediately deconstructed. This guarantee is 
 * essential for some systems to behave correctly.
 */
struct R(T) if(is(T == class) || is(T == interface))
{private:
	size_t __obj = 0; //Reference hidden from hasAliasing

	ushort* refs() { return (cast(ushort*)&__obj) - 2; }
	ushort* weakrefs() { return (cast(ushort*)&__obj) - 1; }

public:
	@property T _obj() { return cast(T)__obj; }
	alias _obj this;

	/**
	 * T's allocated with New! only, please.
	 */
	this(const T that)
	{
		__obj = cast(size_t)cast(void*)that;
		_incref;
	}

	this(this) { _incref; }
	~this() { _decref; }
	void opAssign(U:T)(R!U rhs) { swap(__obj, rhs.__obj); }
	R!U opCast(U)(R!U) const { return R!U(cast(U)_obj); }
	
	bool opCast(B)() if(is(B == bool))
	{
		return cast(bool)__obj;
	}
	
private:
	void _incref()
	{
		if(__obj) atomicOp!"+="(cast(shared)refs, 1);
	}

	void _decref()
	{
		if(__obj)
		{
			if(atomicOp!"-="(cast(shared)refs, 1) == 0)
			{
				void* o = cast(void*)__obj;
				void* m = o - uint.sizeof;
				__obj = 0;
				
				scope(exit)
				{
					static if(hasAliasing!T) GC.removeRange(o);
					if(*weakrefs == 0)
						core.stdc.stdlib.free(m);
				}
				
				destroy(cast(T)older);
			}
		}
	}
}

/**
 * A weak reference.
 * 
 * Weak references do not keep objects alive and
 * help describe ownership. They also break
 * reference cycles that lead to memory leaks.
 * 
 * Attempting to dereference a weak reference to a 
 * destroyed object is reliably detected. This 
 * feature may be disabled for well-tested releases,
 * reducing the garbage collection footprint and 
 * breaking systems that unwisely rely on testing 
 * weak reference validity.
 * 
 * It is done by having two reference counts and
 * allowing objects to exist in a zombie state. It
 * wastes a little memory and performance.
 */
struct W(T) if(is(T == class) || is(T == interface))
{private:
	size_t __obj = 0; //Reference hidden from hasAliasing
	
	ushort* refs() { return (cast(ushort*)&__obj) - 2; }
	ushort* weakrefs() { return (cast(ushort*)&__obj) - 1; }
	
public:
	@property T _obj() { return cast(T)__obj; }
	alias _obj this;

	this(const T that)
	{
		__obj = cast(size_t)cast(void*)that;
	}

	//TODO Implement version disabling of weakref validation
	//also implement the rest of this
}