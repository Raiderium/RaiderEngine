module raider.engine.game.spawner;

import raider.engine.game.entity;
import raider.engine.game.factory;
import raider.engine.game.layer;
import raider.engine.tool.reference;

/**
 * Spawns entities.
 * 
 * R!Spawner spawner = New!Spawner("EntityName");
 * W!Entity entity = spawner.create(layer);
 * 
 * Alternative for one-offs:
 * W!Entity entity = Spawner.create("EntityName", layer);
 * 
 * While a spawner or instance lives, factory data is guaranteed to remain loaded.
 * When all instances and spawners are gone, it is unloaded to reduce memory consumption.
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
		if(!_factory) throw new Exception("Can't get spawner for unknown entity '"~entityName~"'.");
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
	 * 
	 * Returns a weak reference to the entity.
	 * (The layer holds ownership.)
	 */
	W!Entity create(W!Layer layer, W!Entity parent = null)
	{
		return W!Entity(_factory.create(EntityArgs(layer, parent, _factory)));
	}

	static W!Entity create(string entityName, W!Layer layer, W!Entity parent = null)
	{
		Factory factory = Factory[entityName];
		if(!factory) throw new Exception("Can't spawn unknown entity '"~entityName~"'.");
		return W!Entity(_factory.create(EntityArgs(layer, parent, _factory)));
	}
}

/**
 * Encapsulates all that must be passed to the base class for initialisation purposes.
 * Using a struct allows easier modification later and less typing for the developer.
 */
package struct EntityArgs
{package:
	this(W!Layer layer, W!Entity parent, Factory factory)
	{
		this.layer = layer;
		this.parent = parent;
		this.factory = factory;
	}
	W!Layer layer;
	W!Entity parent;
	Factory factory;
}