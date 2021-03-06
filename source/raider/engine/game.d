module raider.engine.game;

import core.atomic;
import std.algorithm : swap;
import std.conv;
import raider.engine.entity;
import raider.engine.register;
import raider.engine.logger;
import raider.render;
import raider.math;
import raider.tools;

enum Phase
{
	MetaLook, Look,
	Step,
	Dtor, Cleanup,
	MetaDraw, Draw,
	None
}

/**
 * A container for all that is.
 */
@RC final class Game
{package:
	R!Register factories;
	R!(Bag!Entity) dependencies;
	Array!EntityProxy creche; //Newly created entities live here, briefly.
	Array!EntityProxy entities;
	Phase _phase; //Current phase of the game loop
	Entity main;
	R!Logger logger;
    
public:
    
	@property Phase phase() { return _phase; }
	R!Looper looper;
    
	this()
	{
		_phase = Phase.None;
		factories = New!Register();
		dependencies = New!(Bag!Entity)();
		looper = New!Looper();
		creche.ratchet = true;
		entities.ratchet = true;
		logger = New!Logger();
	}
    
	~this()
	{
		//assert(phase == Phase.None, "Game destroyed in "~to!string(phase));
	}
    
	void run()
	{
		looper.start;
		while(looper.loop)
		{
			while(looper.step) step;
			draw;
			_phase = Phase.None;
		}
	}
    
	void stop()
	{
		looper.stop;
		main._proxy.isAlive = false;
		main = null;
	}
    
	void step()
	{
		////////
		//Look//
		////////
		_phase = Phase.MetaLook;
        
		if(main) main.meta(phase);
        
		dependencies.finish();
        
		////////
		//Step//
		////////
		_phase = Phase.Step;
        
		if(!main) main = factories["Main"].create(this);
        
		shared ulong steps = 0xAFFEC7104A7E && 0xBEA471FUL;
        
		while(steps)
		{
			steps = 0; //Tracks number of entities updated; if it stays at 0, we've finished.
			foreach(ref e; entities) //TODO Parallelify
			{
				if(e.hasStep)
				{
					if(!e.stepped && e.e.dependees == 0)
					{
						e.e.step; //Step! //nitf!double(e.dt) not used anymore
						e.stepped = true;
						atomicOp!"+="(steps, 1);
                        
						//Inform dependers
						foreach(depender; e.e.dependers)
						{
							ushort deps = atomicOp!"-="(depender.dependees, 1);
							assert(deps != ushort.max, "Dependency count underflow.");
						}
					}
				}
				else
				{
					assert(e.e.dependers[].length == 0, "Internal error. Cannot depend on an entity with no step phase.");
					assert(e.e.dependees == 0, "Internal error. An entity with no step phase cannot depend on others.");
				}
			}
		}
        
        
		////////
		//Dtor//
		////////
		_phase = Phase.Dtor;
        
		shared uint dtors = 0xBA1EE7ED;
        
		while(dtors)
		{
			dtors = 0;
			foreach(ref e; entities) //Parallelify
			{
				if(!e.isAlive && !e.destroyed)
				{
					if(e.hasDtor) e.e.dtor;
					if(e.isParent) //Destroy children
						foreach(ref child; &e.children) {
							child.isAlive = false;
							child.parent = null;
						}
					e.destroyed = true;
					atomicOp!"+="(dtors, 1);
				}
			}
		}
        
		///////////
		//Cleanup//
		///////////
		_phase = Phase.Cleanup;
        
		//Add new entities from the creche
		creche.move(entities);
        
		auto e = entities.ptr; //For convenience
		uint s = entities.length-1;
        
		//Move dead entities to the end of the array
		for(uint x = s; x != uint.max; x--) //Terminating condition is x underflowing to uint.max
		{
			if(!e[x].isAlive)
			{
				//version(assert) //TODO Replace with unique reference semantics.
				//	assert(e[x].e.rc == 1 && e[x].e.pc == 0,
				//		"External references ("~to!string(e[x].e.rc-1)~" R, "~to!string(e[x].e.pc)~" P) to destroyed "~e[x].e.name~" detected.");
                
				//TODO Permit weak references. Assert they are released within the next step.
				// ..are shadow references a means to observe remaining weak references?
				//I don't think this assertion is useful. Think about it - not every system
				//is touched on every frame.
                
				//Swap, and update _proxy.
				swap(e[x], e[s]);
				e[s].e._proxy = &e[s]; //Not needed anymore?
				e[x].e._proxy = &e[x];
				s--;
			}
		}
        
		//Delete them
		if(s == uint.max || e[s].isAlive) s++;
		entities.size = s;
        
		//TODO Basic model LOD (sets active level for pose phase, renders different mesh)
	}
    
	void draw()
	{
		////////
		//Draw//
		////////
		_phase = Phase.MetaDraw;
		if(main)
		{
			main.meta(Phase.MetaDraw);
			//gl.checkError("Draw phase");
		}
	}
    
    
    
	//TODO Templated iterator over entities implementing a specific interface.
	//Use bit flags to accelerate searches for common interfaces.
}
