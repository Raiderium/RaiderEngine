module raider.engine.physics;

import raider.collision.all;
import raider.physics.all;
import raider.engine.entity;
import raider.tools.reference;

/**
 * The Shape and Body classes, and all related
 * classes, have template arguments for storing 
 * user data.
 * 
 * The Engine makes use of such userdata. 
 * To avoid requiring the developer to type
 * in the template arguments each time they
 * use the classes, aliases are defined and
 * the original templates remain hidden.
 * 
 * If the developer wishes to create systems
 * with custom userdata, they will need to
 * import and distinguish the originals.
 * The lesser of two inconveniences.
 * 
 * Void pointers are unwise.
 */
package struct ShapeUserData
{
	
}

package struct BodyUserData
{
	P!Entity e;
}

public alias raider.collision.all.Space!ShapeUserData Space;
public alias raider.collision.all.Shape!ShapeUserData Shape;
public alias raider.collision.all.Collider!ShapeUserData Collider;
public alias raider.physics.all.World!(BodyUserData, ShapeUserData) World;
public alias raider.physics.all.Body!(BodyUserData, ShapeUserData) Body;
public alias raider.physics.all.Joint!(BodyUserData, ShapeUserData) Joint;
public alias raider.physics.all.Surface Surface;


