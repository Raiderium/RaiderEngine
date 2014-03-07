module game.factory;

import core.sync.mutex;
import game.entity;
import game.game;

/**
 * The core of the entity framework.
 * 
 * Creates entities and calls their load/unload methods at the right time.
 * Do not use this class to spawn entities - use Spawner.create().
 */
abstract class Factory
{
private:
	Mutex mutex;
	uint refcount; //Total number of spawners / instances
	string _name;
	__gshared Mutex registerMutex;

public:
	@property string name() { return _name; }
	__gshared Factory[string] register;

	Entity create();
	void load();
	void unload();

	this(string name)
	{
		mutex = new Mutex();
		refcount = 0;
		_name = name;
	}

package:
	void incref()
	{
		synchronized(mutex)
		{
			if(refcount == 0) load();
			refcount++;
		}
	}
	
	void decref()
	{
		synchronized(mutex)
		{
			assert(refcount != 0);
			if(refcount == 1) unload();
			refcount--;
		}
	}

	static Factory opIndex(string name)
	{
		synchronized(registerMutex)
		{
			Factory* f = name in register;
			return f ? *f : null;
		}
	}
}

static this()
{
	Factory.registerMutex = new Mutex();
}

template FactoryMixin(string name)
{
	const char* FactoryMixin = "
	override Entity create(EntityArgs args) { return New!"~name~"(args); }
	this() { super(\""~name~"\"); }

	static this()
	{
		Factory.register[\""~name~"\"] = new "~name~"Factory();
	}
	";
}
