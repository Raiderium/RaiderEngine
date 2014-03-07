module tool.looper;

import std.stdio;
import core.thread;
import core.time;
import vec;
import derelict.sfml2.system;

/**
* Controls a deterministic game update and render loop.
*
* How to use:
* Call start() when ready to begin looping.
* While looper.running is true...
* While looper.step() returns true, advance game logic by looper.logicDelta seconds.
* Draw the game.
* Call sleep() to sleep off excess time.
* 
* Use looper.partialTime (0..1) to interpolate graphics between the last two logic updates.
* Graphics interpolation can be difficult to implement, but it provides smoother motion and slow-motion effects.
*/
class Looper
{public:
	bool running;
	double time = 0.0;				///< Game time elapsed since start().
	double timeScale = 1.0;			///< Time elapsed in seconds for every real second.
	double logicTime = 0.0;			///< Logical time elapsed since start().
	double logicDelta = 1.0/60.0;	///< Time between logic updates.
	double partialTime = 0.0;		///< Normalised time (0..1) from the last update to the next. For interpolating graphics.
	int substepMax = 8;				///< Graphical frame skip limit.

private:
	int substep = 0;			///< Substeps taken inside a frame.
	sfClock* clock;
	double clockTime = 0.0;		///< Real time elapsed since start().

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
		//timeScale = 1.0;		//Default 1-1 correlation between game and real time.
		//logicDelta = 1.0/60.0;	//Default 60 Hz update.
		//substepMax = 8;			//Default maximum of 8 logic updates between graphical frames.
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
		partialTime = 0.0;
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

		partialTime = (1.0 - (logicTime - time) / logicDelta);

		return false;
	}

	void sleep()
	{
		//Sleep until real time matches game time
		long nanoseconds = cast(long)((logicTime - time)*1000000.0);
		if(nanoseconds < 0) nanoseconds = 0;

		Thread.sleep(dur!("usecs")(nanoseconds));
		//da_sfSleep(logicTime - (time - timeStart)); //Use vsync.
		substep = 0;
	}
}

