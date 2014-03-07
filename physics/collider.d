module physics.collider;

import rm;
import game.entity;
import physics.shape;

/**
 * Custom handler for collisions between shapes.
 */
abstract class Collider
{public:
	Entity entity;
	Shape shapeA;	/// The shape that triggered this collision handler.
	Shape shapeB;	/// The shape it collided with.

	bool broad(Collider) nothrow;
	bool contact(Collider c, vec3 pos, vec3 nor) nothrow;
}