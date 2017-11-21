# RaiderEngine

This is a 3D game engine. It tries to be small, fast and as simple as possible, but not simpler.

Thanks for taking a look. It's not complete, but one day it will be. This repository is functionally a last-resort backup, rarely up to date with the working copy - expect inconsistency.

## Features (required to reach 1.0)
- Support for low end hardware
- Physically based materials, variable colour depth
- Translucent radiosity and probe baking/streaming (various types)
- Bezier f-curves, armatures, shape keys, IK and non-linear mixing
- Mesh booleans, mirroring, subdivision, surface nets, bevel, extrusion
- Mid spec antialiasing (SMAA?), variance/soft shadows (PCSS?)
- Accumulation-based 'true' soft shadows, motion blur, AA and DoF
- Singularity-resistant rigidbody and deformable mass-spring dynamics
- Discrete MPR collision with per-body measures against tunnelling
- 3D sound with dynamic envelopes, propagation delay and effect regions
- Object-oriented entity framework
- XML parser (the killer feature)
- Stupidly fast binary formats, Blender asset exporters
- Opus and VP8 (lossy and lossless) in webm and webp containers 
- Unified networking, file access and (de)serialisation mechanisms
- Strictly one thread per logical core, spare time task scheduling
- Cache-friendly with aggressive parallel execution strategies
- Fun...?

## Platforms
- Windows, Linux, (Mac?)
- x86, x86-64, (armhf?) 

## Differences
### One language
It omits an embedded companion scripting language. D is friendly and compiles fast, reducing the relevant advantages. It means the developer must write in D and compile directly against the engine source, but there are no switches and few or no libraries to link.

Without scripts, we avoid their typical disadvantages: a crippling drop in performance, a terrifying increase in complexity, and poor exception handling. Script interpreters also rarely run on multiple threads, for who would use that feature? When the woodcutter complains of a dull axe, we don't give them an arbitrary number of additional dull axes.

We lose the ability to interpret general-purpose code at runtime, but that feature is quite dangerous and rarely appropriate outside authoring tools. If necessity compels, there are domain-specific alternatives that are performant, safe, and friendlier to use. For everything else, there's ~master code.

### Multithreading strategy
The engine locks a thread to each logical core, then uses parallel foreach as the basis for all work distribution. It scales nearly perfectly for correctly adapted problems and is implemented in a few comparatively bug-proof lines of code. Not fancy, not flexible, but effective - a hammer in the toolbox of multithreading. 

Consequently, the main loop can be described as a sequence of algorithms solving problems made to look as much like nails as possible. Every step makes a special effort to be embarassingly parallel, or at worst distressingly concurrent, without taking power from the developer or making unreasonable demands of them. Most logic they (you) write is already thread-safe; this framework takes advantage of that.

The engine likes to completely finish each task before starting the next. This does mean that the CPU and GPU have downtime as they process exclusive loads, but there are ways to blur that line and increase utilisation without pipelining. We're not rendering a movie here, despite the industry suggesting otherwise.

Besides, with new graphics APIs promising multicore rendering advantages, having the CPU conceptually 'dead' while rendering isn't the worst architectural decision I can think of. And likewise, we know the GPU is (probably) free while the CPU is working, available for GPGPU stuff.

### Parallel pragmatism
It is common to avoid exposing shared memory to the developer, only using threads behind the scenes. For example, an engine can update certain component lists in parallel when it knows they will not cause trouble. With double buffered state, it can process multiple frames at the same time. Normally sequential tasks like physics, logic and rendering can be pipelined. These strategies suffer primarily from limited scaleability, wasted memory, and input latency respectively. In the name of.. what? Answers may vary.

My answer is, their use is understandable in established engines (or new engines designed to cater to established conventions), where people have certain expectations, and large architectural changes are difficult. Features need to slot in gradually, and desktop processors with enough cores to make scalability relevant haven't been around long. Also, trying to leverage multiple threads is hard enough in most systems languages, and even harder to present to the end-developer as a surmountable obstacle. It would be difficult to justify in an environment designed for non-programmers, and impossible to justify in a C++ environment designed for human beings.

Therefore, this engine comes with a disclaimer - it's not for beginners. It's designed for programmers willing to write multithreaded code (in a sane language). Every effort is being made to provide a simple, convenient interface, but it does not hide necessary complexity. Depending on what the developer wants to do, they will infrequently write code that must synchronise access to shared resources, which requires following some simple rules. It's not too difficult, but it's certainly not suited to teaching newcomers programming in D or game development unless it's combined with some dynamite tutorials and a crash-course on sync primitives (and how to avoid them).

Then again, D has repeatedly demonstrated that it doesn't really care what I think is impossible. 

### Object oriented
All game logic is implemented through entities, which are final classes that inherit from Entity. Developers are expected to make effective use of static composition, interfaces and weak references to implement logic that might otherwise rely on components, messaging or event systems.

Decomposing a game into entities is an artistic decision; the systems they access have no concept of them, and see only a stream of instructions that might come from one or many sources. Entities are not 'game objects', capable of hosting only one of every type of asset. They could be trivially replaced, if the developer wished to use a more specific framework like ECS. 

The entity system is designed to support large populations with frequent creation and destruction. It has a dependency resolving feature (entity A requests that entity B step before it) and entities can be referenced weakly to gracefully detect zombies.

### Small
No bloat, no duplicated functionality, no built-in store with microtransactions (expardon me?). The compiled size with UPX compression will likely be under 500kb. Creating assets from reduced data is encouraged. A variety of tools will be available to generate and manipulate meshes, textures and sound.

There is no float precision switch, because the engine makes use of float, double and fixed-point math depending on context. It assumes it will be used for a space simulation, but developers are free to change the source to suit their needs.

### Fast
Structures are generally flat and stored in contiguous arrays. Algorithms are written for correct meaning first, cache-friendly access patterns second, and micro-optimisations last, with snarky self-deprecating comments to make them obvious. Allocations are currently through malloc, but specialised allocators will be injected later. Allowances are being made for memory compaction (anyone who's written an allocator will be chortling heartily, but I swear I'm not bluffing).

Priority is placed on avoiding spikes in frame timing. Templated reference counting replaces the tracing garbage collector. Tasks normally removed to a separate thread (audio mixing, asset streaming, networking) are instead completed in slack time between frames, using the yielding semantics of D fibers to avoid heavy context switches. Must-complete tasks are run first, then others are scheduled by timing small chunks and stopping before overrun occurs. Textures are uploaded incrementally, and compressed formats (video, image, sound) have yielding codec implementations. All serialisation tasks use the same interface.

Conditional optimisations are ignored if developers aren't expected to be aware of them, much less able to ensure their criteria are met. Temporal coherency is valued on a case-by-case basis. Always remember, O(n) is only wrong until it runs faster in the worst case and prevents unexpected framerate drops. The engine is designed to keep chugging along at a stable frequency, consuming reasonable amounts of memory, even if the game is throwing ridiculous scenarios at it.

Physics updates are taken adaptively to account for local complexity. A constraint under low stress will take fewer cycles, even if it's connected to a large island.

### Simple
Or, as complex as it needs to be, and no more. The codebase is flat and most class names are a single plain english word. Different aspects of the engine (physics, audio, rendering, math etc) are in separate libraries that can be used on their own.