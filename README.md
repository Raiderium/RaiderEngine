#RaiderEngine


This is a 3D game engine written from scratch in D. It tries to be small, fast and as simple as possible, but not simpler.

It is not complete. The following describes the minimum featureset required for a 1.0 release.

##Features
- OpenGL 1.3 and up with graceful fallback to fixed function
- Dynamic lighting with light probes and soft shadows
- Baked lighting with translucent radiosity
- Bezier f-curves, armatures, shape keys, soft bodies, IK and non-linear mixing
- Mesh tools: cuts, booleans, mirrors, subdivision, bevel, extrusion, deformations
- Multiple pass anti-aliasing, motion blur and depth of field
- Explosion- and singularity-resistant soft-constraint rigidbody and softbody dynamics
- Discrete MPR collision with measures against tunnelling and constraint violation
- 3D sound with dynamic envelopes, propagation delay, effect regions
- Object-oriented entity framework (not ECS)
- Blender asset exporters, stupidly fast native binary formats
- (A)synchronous filing and networking
- Cache-friendly with aggressive parallel execution strategies


##Platforms
- Windows, Linux, (Mac?)
- x86, x86-64, (armhf?) 


##Differences
###One language
It omits a scripting language. D is friendly and compiles fast, reducing the key advantages of scripting. We lose the ability to interpret code at runtime, but this is fairly dangerous and rarely used. If necessity compels, visual logic graphs are a safe and performant alternative, and even friendlier than scripts. 

Without scripts, we avoid their typical disadvantages: a crippling drop in performance, a terrifying increase in overall complexity, and poor exception handling. Script interpreters also rarely run on multiple threads, for who would use that feature? When the woodcutter complains of a dull axe, we don't give them two dull axes.


###Parallel strategy
The main loop makes a special effort to be embarassingly parallel, or at worst distressingly concurrent, without taking power from the developer or making excessive demands on their skills with regards to shared memory. All logical cores should be more saturated than not before bottlenecks appear.

It is common to avoid exposing shared memory to the developer, only using threads behind the scenes. An engine can update certain component lists in parallel when it knows they will not cause trouble. With double buffered state, it can process multiple frames at the same time. Normally sequential tasks like physics, logic and rendering can be pipelined. These strategies suffer from (primarily) limited scaleability, wasted memory, and input latency, respectively. 

But their use is understandable in established engines where large architectural changes are difficult. Features need to slot in gradually, and multi-core processors have only been around for - .. oh. Well, er, trying to leverage threads is hard enough in most systems languages, and even harder to present to the end-developer, in an environment originally designed to avoid the need for it. 

This engine's strategy is to use parallel algorithms as much as possible from the ground up. It likes to completely finish each task before starting the next. This does mean that the CPU and GPU tend to have downtime as they process exclusive loads, but there are ways to blur that line and increase utilisation without pipelining. We're not rendering a movie here, despite the industry suggesting otherwise.


###Pragmatic interface
Every effort is being made to provide a simple interface, but it's not for beginners. Developers will infrequently write code that shares memory, which requires following some simple rules. Not difficult, but not suited to teaching newcomers programming in D or game development unless it's combined with some dynamite tutorials and a crash-course on synchronisation primitives.


###Small
No bloat, no duplicated functionality, no built-in store with microtransactions (expardon me?), no unstripped symbols. Its release footprint with UPX compression will likely be under 500kb. In addition, it encourages creating assets from reduced data. A variety of tools will be available to generate and manipulate meshes, textures and audio.


###Fast
Much of this engine's advantage is not in what it does, but what it avoids doing, and how it avoids doing it. For instance, it avoids hash tables and linked lists. There are no tasks in a game engine for which they are the only viable solution, and they're inherently complex before you even start solving the problem at hand. 

Conditional optimisations are often ignored if most developers aren't even aware of them, much less able to ensure their criteria are met, leading to unexpected framerate drops. Temporal coherency is valued on a case-by-case basis. Always remember, O(n) is only wrong until it runs faster in practice.

Structures are generally flat and in contiguous arrays. Algorithms are written for correct meaning first, good (typically meaning cache-friendly) pattern choice second, and micro-optimisations last, with snarky self-deprecating comments to make them obvious. Allocations are currently through malloc, but the std.experimental.allocator system will be injected later to control memory layout and use appropriate allocation strategies without writing special-case code.


###Simple
Or, as complex as it needs to be, and no more. The codebase is flat and 95% of class names are a single plain english word or abbreviation. Different aspects of the engine (physics, audio, rendering, math etc) are in separate, well-partitioned libraries that can also be used on their own.
