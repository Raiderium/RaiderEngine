module raider.engine.factory;

import raider.engine.game;
import raider.engine.entity;
import raider.tools.reference;

/**
 * Shared entity data and instancing method.
 * 
 * Every entity has an associated factory.
 * An instance of the factory is injected into the entity on spawn.
 * It isn't guaranteed to be the same instance for all instances
 * of an entity type, but in practice it will be.
 */
abstract class Factory
{public:

	/**
	 * The name of the entity this factory creates.
	 */
	@property string entityName() const;
	@property string fullyQualifiedEntityName();
	
	/**
	 * Instance an entity.
	 */
	P!Entity create(P!Game game, P!Entity parent = null, P!Entity creator = null);
}
