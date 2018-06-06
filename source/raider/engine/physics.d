module raider.engine.physics;

import raider.collision;
import raider.physics;
import raider.engine.entity;
import raider.tools.reference;

/* The Shape and Body classes, and all related
 * classes, store user data. The type of that
 * data is given through a template argument.
 * 
 * The engine makes use of such data internally.
 * To avoid requiring the developer to type
 * in the template arguments each time they
 * use bodies and shapes, aliases are defined
 * and the original templates remain hidden.
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
package struct SU
{
	int foo; 
	//An instance of this struct is available as shape.data.
	//It is alias this'd, but note that this only works when
	//accessing a native reference. R! also uses alias this,
	//and the nesting seems to give D a headache. 
}

package struct BU
{
	Entity e;
}

public alias raider.collision.Space!(ShapeData!(BU, SU)) Space;
public alias raider.collision.Shape!(ShapeData!(BU, SU)) Shape;
public alias raider.collision.Sphere!(ShapeData!(BU, SU)) Sphere;
public alias raider.collision.Box!(ShapeData!(BU, SU)) Box;

public alias raider.physics.Collider!(BU, SU) Collider;
public alias raider.physics.World!(BU, SU) World;
public alias raider.physics.Body!(BU, SU) Body;
public alias raider.physics.Joint!(BU, SU) Joint;
public alias raider.physics.Surface Surface;


