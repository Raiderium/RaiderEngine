module raider.engine.allocator;

/* A statically-typed allocator governing all allocations.
 * 
 * If a game is concerned with a specific allocation strategy it can roll its own,
 * but the intention is that such modification shouldn't be necessary unless the
 * developer has a VERY complex and outlandish feature in mind.
 * 
 * Perhaps have multiple static-typed allocators for each aspect of the engine?
 * 
 * Warmstarting is very important. Don't ignore it. 
 */

import std.experimental.allocator.building_blocks.quantizer : Quantizer;

//TODO: Everything

