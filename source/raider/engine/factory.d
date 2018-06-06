module raider.engine.factory;

import raider.engine.game;
import raider.engine.entity;
import raider.tools.reference;

/**
 * Entity factory.
 * 
 * Each entity has an associated factory, and every instance of
 * an entity is created by and linked to an instance of the factory.
 * 
 * Factories keep a list of what interfaces the entity implements,
 * and may store arbitrary tags and data. They are effectively a 
 * soft implementation of class reflection, allowing a game to
 * instance or list entities without knowing concrete types.
 * 
 * It is also a convenient place to store resources shared amongst
 * multiple instances of an entity. However, it is not guaranteed
 * that all instances share the same factory, nor should factories
 * be used as a place for supposedly 'global' game variables - they
 * may be shared between multiple game instances, corrupting logic.
 * 
 * Developers can obtain a reference to a factory via the Register.
 */
@RC abstract class Factory
{public:

	/**
	 * The name of the entity this factory creates.
	 */
	@property string entityName() const;
	@property string fullyQualifiedEntityName();
	
	/**
	 * Instance an entity.
	 */
	Entity create(Game game, Entity parent = null, Entity creator = null);
}
