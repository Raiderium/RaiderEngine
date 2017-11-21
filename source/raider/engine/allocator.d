module raider.engine.allocator;

/* A statically-typed allocator assembly governing allocation of EVERYTHING.
 * If a game is concerned with its allocation strategy it can roll its own.
 * Have multiple static-typed allocators for each aspect of the engine?
 * 
 * This moves everything to one place. 
 * 
 * Warmstarting is a great feature, we should all do that more often.
 */

import std.experimental.allocator.building_blocks.quantizer : Quantizer;

//TODO: The magic 

