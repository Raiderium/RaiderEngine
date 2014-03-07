module physics.joint;

import physics.ode;
import physics.bod;

final class Joint
{private:
	dJointID djoint;

public:
	this(Body body1, Body body2 = null)
	{
		assert(body1); assert(body1 != body2); if(body2) assert(body1._world == body2._world);
		djoint = null;
	}

	//TODO A heap of copypasting.
}