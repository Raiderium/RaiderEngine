module game.spawner;

import game.entity;
import game.factory;
import game.layer;

/**
 * Spawns entities.
 * 
 * To spawn entities:
 * Spawner spawner = New!Spawner("EntityName");
 * Entity entity = spawner.create(layer);
 * Delete(spawner);
 * 
 * Alternative for one-offs:
 * Entity entity = Spawner.create("EntityName", layer);
 * 
 * While a spawner or instance lives, factory data is guaranteed to remain loaded.
 * When all instances and spawners are gone, unload() is called to reduce memory consumption.
 * 
 * As an example, keep a bullet spawner in the gun to make sure bullets always fire instantly.
 */
final class Spawner
{package:
	Factory _factory;

public:
	this(string entityName)
	{
		_factory = Factory[entityName];
		if(!_factory) throw new Exception("Could not get spawner for '"~entityName~"': Entity not found.");
		_factory.incref;
	}

	~this()
	{
		_factory.decref;
	}

	@property Factory factory() { return _factory; }
	
	/**
	 * Instance an entity in the specified layer.
	 * 
	 * Optionally pass a parent entity.
	 * Entities may inspect and complain about their parent.
	 */
	Entity create(Layer layer, Entity parent = null)
	{
		return _factory.create(EntityArgs(layer, parent, _factory));
	}

	static Entity create(string entityName, Layer layer, Entity parent = null)
	{
		Factory factory = Factory[entityName];
		if(!factory) throw new Exception("Could not spawn '"~entityName~"': Entity not found.");
		return _factory.create(EntityArgs(layer, parent, factory));
	}
}