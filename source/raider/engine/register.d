module raider.engine.register;

import core.sync.mutex;
import raider.engine.factory;
import raider.tools.map;
import raider.tools.reference;


/**
 * Caches entity factories.
 * 
 * Obtain factory with opIndex.
 * All users share one instance.
 * Factory dies when all references die.
 */
final class Register
{private:
	__gshared Map!(string, W!Factory) factories;
	__gshared Mutex mutex; //Here be a dragon's mother
	
public:
	this()
	{
		mutex = new Mutex();
	}
	
	R!Factory opIndex(string name)
	{
		R!Factory result;
		
		synchronized(mutex)
		{
			//Obtain factory
			W!(Factory)* f = factories.get(name);
			if(f) result = (*f).strengthen;
			
			//If not found, create it
			if(result is null)
			{
				result = cast(R!Factory)New(name~"Factory");
				if(result) factories[name] = cast(W!Factory)result;
			}
		}
		
		//Well, at least we tried
		if(result is null) throw new Exception("No entity called "~name~".");
		
		return result;
	}
	
	//TODO Folders & search paths, to improve modding
}