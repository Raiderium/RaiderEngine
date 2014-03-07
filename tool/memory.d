/**
 * C/C++ style memory management
 * 
 * Allows programmer control over object and memory lifespan,
 * instead of untimely garbage finalization and collection.
 * Uses malloc and free from the C standard library.
 * 
 * To allocate and construct, call New!ClassName(args).
 * To destruct and deallocate, call Delete(object).
 * 
 * The GC will scan objects created by this sytem, so
 * feel free to mix and match memory management styles.
 * However, if a class is designed with timely destruction
 * in mind, only YOU can prevent undefined behaviour.
 */ 

module tool.memory;

import std.conv;
import core.memory : GC;
import core.stdc.stdlib;

T New(T, Args...)(Args args) if(is(T == class))
{
	enum classSize = __traits(classInstanceSize, T);
	void* m = core.stdc.stdlib.malloc(classSize); if(!m) throw new Exception("Out of memory");
	GC.addRange(m, classSize);
	return emplace!(T)(m[0..classSize], args);
}

void Delete(ref Object obj)
{
	destroy(obj);
	GC.removeRange(cast(void*)obj);
	core.stdc.stdlib.free(cast(void*)obj);
	obj = null;
}