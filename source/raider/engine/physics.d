module raider.engine.physics;

import rc = raider.collision;
import rp = raider.physics;
import raider.engine.entity : Entity;
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

public alias rc.Space!(rp.ShapeData!(BU, SU)) Space;
public alias rc.Shape!(rp.ShapeData!(BU, SU)) Shape;
public alias rc.Sphere!(rp.ShapeData!(BU, SU)) Sphere;
public alias rc.Box!(rp.ShapeData!(BU, SU)) Box;

public alias rp.Collider!(BU, SU) Collider;
public alias rp.World!(BU, SU) World;
public alias rp.Body!(BU, SU) Body;
public alias rp.Joint!(BU, SU) Joint;
public alias rp.Surface Surface;


