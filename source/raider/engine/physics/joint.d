module raider.engine.physics.joint;

import raider.engine.physics.ode;
import raider.engine.physics.bod;
import raider.engine.tool.reference;

final class Joint
{private:
	dJointID djoint;

public:
	this(R!Body body1, R!Body body2 = null)
	{
		assert(body1);
		assert(body1 != body2); 
		if(body2) assert(body1._world == body2._world);

		djoint = null;
	}

	//TODO A heap of copypasting.
}