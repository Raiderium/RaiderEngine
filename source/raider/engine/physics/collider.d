module raider.engine.physics.collider;

import raider.math.vec;
import raider.engine.physics.shape;
import raider.engine.tool.reference;

/**
 * An interface for things interested in collisions.
 * 
 * A collider is associated with one or more shapes.
 * It defines callbacks for broadphase and narrowphase 
 * events, and contact force feedback.
 * 
 * It is intended that entities will inherit Collider
 * and register with their shapes, implementing all
 * collision behaviour at a single point. This is
 * not a general event listener framework; only one 
 * collider may be registered with each shape.
 */
interface Collider
{public:

	enum Result { Ignore, Accept, Inspect }

	/**
	 * Broadphase callback.
	 * 
	 * This is called when two shapes potentially intersect.
	 * 
	 * Returns:
	 * Ignore if narrowphase is to be skipped.
	 * Accept if narrowphase is to proceed.
	 * Inspect to do narrowphase and check each contact.
	 * 
	 * If one collider ignores, the narrowphase is skipped.
	 * Lack of a collider implies acceptance.
	 */
	Result near(W!Shape A, W!Shape B) nothrow;

	/**
	 * Narrowphase callback.
	 * 
	 * This is called for each contact discovered between
	 * two shapes, if the collider requested narrowphase
	 * inspection.
	 * 
	 * Returns:
	 * Ignore to discard the contact.
	 * Accept to use the contact.
	 * Inspect to use the contact and get feedback.
	 * 
	 * If one collider ignores, the contact is discarded.
	 */
	Result contact(vec3 pos, vec3 nor) nothrow;

	/**
	 * Feedback callback.
	 * 
	 * This is called for each contact after the world 
	 * has stepped to accumulate joint forces, if the 
	 * collider requested contact inspection.
	 * 
	 * The 'force' field of the Contact is valid here.
	 */
	void feedback(const ref Contact) nothrow;
}

struct Contact
{
	Shape A, B;		///The shapes touching
	vec3 pos;       ///The position of the contact in global space.
	vec3 nor;       ///The surface normal of the contact (on shape A)
	vec3 force;     ///The force applied by the contact (valid after world step)
}