module raider.engine.physics;

import raider.collision;
import raider.physics;
import raider.engine.entity;
import raider.tools.reference;

/* The Shape and Body classes, and all related
 * classes, store user data. The type of that
 * data is given through a template argument.
 * 
 * The engine makes use of such userdata. 
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
 * All this is done because void pointers 
 * are unwise and people should feel bad 
 * about using them.
 */
package struct ShapeUserData
{
	
}

package struct BodyUserData
{
	P!Entity e;
}

public alias raider.collision.Space!ShapeUserData Space;
public alias raider.collision.Shape!ShapeUserData Shape;
public alias raider.collision.Collider!ShapeUserData Collider;
public alias raider.physics.World!(BodyUserData, ShapeUserData) World;
public alias raider.physics.Body!(BodyUserData, ShapeUserData) Body;
public alias raider.physics.Joint!(BodyUserData, ShapeUserData) Joint;
public alias raider.physics.Surface Surface;


