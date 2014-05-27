module raider.engine.tool.looper;

import std.stdio;
import core.thread;
import core.time;
import raider.math.vec;
import derelict.sfml2.system;

/**
 * Controls a deterministic game loop.
 *
 * How to use:
 * Call start() when ready to begin looping.
 * While looper.running is true...
 * While looper.step() returns true, advance game logic by looper.logicDelta seconds.
 * Draw the game.
 * Call sleep() to sleep off excess time.
 * 
 * Use looper.frameTime to interpolate graphics between the last two logic updates.
 */
class Looper
{public:
	bool running;
	double time = 0.0; ///< Game time elapsed since start().
	double timeScale = 1.0; ///< Time elapsed in seconds for every real second.
	double logicTime = 0.0; ///< Logical time elapsed since start().
	double logicDelta = 1.0/60.0; ///< Time between logic updates.
	double frameTime = 0.0; ///< Normalised frame time (0..1) since the last update.
	int substepMax = 8; ///< Graphical frame skip limit.

private:
	int substep = 0; ///< Substeps taken inside a frame.
	sfClock* clock;
	double clockTime = 0.0; ///< Real time elapsed since start().

	@property double clockDelta()
	{
		double clockTimeNow = sfTime_asSeconds(sfClock_getElapsedTime(clock));
		double result = clockTimeNow - clockTime;
		clockTime = clockTimeNow;
		return result;
	}

public:

	this()
	{
		clock = sfClock_create();
		running = false;
	}

	~this()
	{
		sfClock_destroy(clock);
	}

	void start()
	{
		sfClock_restart(clock);
		time = 0.0;
		clockTime = 0.0;
		substep = 0;
		logicTime = 0.0;
		frameTime = 0.0;
		running = true;
	}

	bool step()
	{
		if(!running) return false;

		time += clockDelta * timeScale;

		//If logic is behind time..
		if(logicTime < time)
		{
			//If substeps remain
			if(substep < substepMax)
			{
				substep++;
				logicTime += logicDelta;
				return true;
			}
			else //Logic is unrecoverably slow. Jump back in time.
			{
				time = logicTime;
			}
		}

		frameTime = (1.0 - (logicTime - time) / logicDelta);

		return false;
	}

	void sleep()
	{
		//Sleep until real time matches game time
		long nanoseconds = cast(long)((logicTime - time)*1000000.0);
		if(nanoseconds < 0) nanoseconds = 0;

		Thread.sleep(dur!("usecs")(nanoseconds));
		//eehhh. Use vsync where possible.
		substep = 0;
	}
}

