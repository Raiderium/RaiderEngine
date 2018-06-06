module raider.engine.register;

import core.sync.mutex;
import raider.engine.factory;
import raider.tools.map;
import raider.tools.reference;
import std.array : split, join;
import std.uni : toLower;
import std.array : insertInPlace;
import std.algorithm : cmp;
import std.conv : to;


/**
 * Wrangles factories.
 * 
 * Entities all share an instance of their associated factory.
 * That instance only lives while there is at least one entity,
 * or something is holding a reference to the factory.
 * 
 * The name of an entity is its fully qualified class name.
 * The module can be omitted if the class name is unambiguous.
 * An entity class Car in vehicles/car.d is called vehicles.car.Car
 * or just Car.
 * 
 * Examples:
 * auto carFactory = game.factories["vehicles.car.Car"];
 * auto carFactory = game.factories["Car"];
 */
@RC final class Register
{private:
	struct Key
	{
		string entity_name;
		string entity_module;

		string toString() const
		{
			return entity_module ~ "." ~ entity_name;
		}

		import std.stdio; //DEBUG

		this(string pqen) // 'possibly qualified entity name' .. 
		{ 
			auto parts = split(pqen, ".");
			entity_name = parts[$-1];
			if(parts.length >= 2)
				entity_module = parts[0..$-1].join(".");
		}

		/* Keys are sorted lexicographically by the entity name,
		 * then by the entity module.
		 */
		int opCmp(const Key that) const
		{
			if(entity_name == that.entity_name && entity_module != "" && that.entity_module != "")
				return cmp(entity_module, that.entity_module);
			else
				return cmp(entity_name, that.entity_name);
		}

		/* Keys match if the entity names match, and
		 * one or both of the module names are either 
		 * undefined or match.
		 */
		bool opEquals(const Key that) const
		{
			return entity_name == that.entity_name &&
				(entity_module == "" || 
				that.entity_module == "" ||
				entity_module == that.entity_module);
		}
	}

	struct Value { W!Factory factory_weak; R!Factory function() metafactory; }

	__gshared Map!(Key, Value) factories;
	__gshared Mutex mutex; //Here be a dragon's mother

public:

	static void add(string fqen, R!Factory function() metafactory)
	{
		Key k = Key(fqen); // 'fully qualified entity name'
		assert(k.entity_module);

		Value v;
		v.metafactory = metafactory;
		
		factories[k] = v;
	}
	
public:
	this()
	{
		mutex = new Mutex();
	}
	
	R!Factory opIndex(string name)
	{
		R!Factory result;

		if(name == "") return result;

		synchronized(mutex)
		{
			Key k = Key(name);

			//Obtain factory
			Value* v = k in factories;

			if(v) result = v.factory_weak._r; //Is the factory alive?
			else throw new Exception("No entity called "~name~".");

			//If not found, create it
			if(result is null)
			{
				result = v.metafactory();
				v.factory_weak = result._w;
			}
		}
		
		return result;
	}

	/**
	 * Obtain a concrete factory type.
	 */
	R!F get(F:Factory)(string mod)
	{
		//TODO Implement!
		//Strip the 'Factory' from fullyQualifiedName(F)
	}
}
