module raider.engine.factory;

import core.sync.mutex;
import raider.engine.entity;
import raider.engine.game;
import raider.engine.layer;
import raider.render.camera;
import raider.tools.array;
import raider.tools.map;
import raider.tools.reference;

/**
 * Shared entity data.
 * 
 * Every entity has an associated factory.
 * An instance of the factory is injected into the entity on spawn.
 */
abstract class Factory
{public:
	@property string name();
	
	/**
	 * Instance an entity in the specified layer.
	 * 
	 * Returns a pointer reference to the entity.
	 * (The layer holds ownership.)
	 */
	P!Entity create(Layer layer);
	
	template boilerplate(E)
	{
		private enum entity_name = E.stringof;
		private enum factory_name = entity_name~"Factory";
		enum boilerplate = "
		static assert( typeof(this).stringof == \""~factory_name~"\", \"entity "~entity_name~" needs a factory called "~factory_name~".\");
		override string name() { return \""~entity_name~"\"; }
		override P!Entity create(Layer layer) { return P!Entity(New!"~entity_name~"(layer, R!Factory(this))); }";	
	}
}