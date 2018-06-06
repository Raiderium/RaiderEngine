# RaiderEngine

This is a 3D game engine. It tries to be small, fast, and as simple as possible, but not simpler. Source is open and MIT-licensed. 

Thanks for taking a look. It's not usable yet, but one day it will be. This repository is functionally a last-resort backup, rarely up to date with the working copy, so expect inconsistency.

## Features (required to reach 1.0)
- Support for low end hardware
- Near-physically-based HDR pipeline
- Baked and streamed radiosity with translucency and various probes
- Bezier f-curves, armatures, shape keys, IK and non-linear mixing
- Mesh booleans, mirroring, subdivision, surface nets, bevel, extrusion
- Mid spec antialiasing (SMAA?), variance/soft shadows (PCSS?)
- Accumulation-based 'true' soft shadows, motion blur, AA and DoF
- Singularity-resistant rigidbody and deformable mass-spring dynamics
- Discrete MPR collision with per-body measures against tunnelling
- 3D sound with dynamic envelopes, propagation delay and effect regions
- Object-oriented entity framework
- Stupidly fast binary formats, Blender asset exporters
- [Opus](http://opus-codec.org), [WEBP lossless](https://developers.google.com/speed/webp/docs/webp_lossless_bitstream_specification), [GFWX](http://www.gfwx.org) and PNG ports
- No static linkage (simple to build)
- Optional dynamic linkage to [VP9](https://en.wikipedia.org/wiki/VP9)
- Unified networking, file access and (de)serialisation mechanisms
- Strictly one thread per logical core, spare time task scheduling
- Cache-friendly with aggressive parallel execution strategies
- Fun?

## Platforms
- Windows, Linux, (Mac?)
- x86, x86-64, (armhf?)

## Rationale
RaiderEngine is strongly inspired by [Nulstein](https://software.intel.com/en-us/articles/nulstein-sample), particularly its observations on running game logic in [parallel](https://software.intel.com/en-us/blogs/2010/09/20/nulstein-v2-plog-parallelizing-at-the-outer-loop). It's not a new idea, but as quadcores become mainstream and products like Ryzen put 'silly' numbers of cores in the hands of the gaming public, developers will seek 'silly' horizontal scalability. Therefore, this engine aims to be 'silly', in the sense that the only excuse it accepts for dropping a frame is that the CPU has, in fact, melted.

### One language
It omits an embedded companion scripting language. D is friendly and compiles fast, limiting the advantages of incorporating a higher level language. Without scripts, we avoid their typical disadvantages: lost performance, a terrifying increase in background complexity, and difficulty keeping cores utilised.

By compiling directly against the engine source, it becomes easier to modify the engine for specific purposes. We lose the ability to interpret general-purpose code at runtime, but that feature is quite dangerous and rarely appropriate outside authoring tools. If necessity compels, there are domain-specific alternatives that are performant, safe, and friendlier to use. For everything else, there's ~master code. 

It should be possible to distribute the engine with a one-touch build environment for rapid iteration. It would package all required source with Digital Mars' reference D compiler, which is currently the fastest. For release builds, GDC and LDC offer better code generation.

### Multithreading strategy
The engine locks a thread to each logical core, then uses parallel foreach as the basis for all work distribution. It scales well for correctly adapted problems and is implemented in a few comparatively bug-proof lines of code. Not fancy, not flexible, but effective - a hammer in the toolbox of multithreading. 

Consequently, the main loop is a sequence of algorithms solving problems made to look as much like nails as possible. Every step makes a special effort to be embarassingly parallel, or at worst distressingly concurrent, without taking power from the developer or making unreasonable demands of them. Most developer code is thread-safe anyway, so we take advantage of that.

The engine likes to completely finish each task before starting the next. This does mean that the CPU and GPU have downtime as they process exclusive loads, but there are ways to blur that line and increase utilisation without pipelining. We're not rendering a movie here, despite the industry suggesting otherwise.

Besides, with new graphics APIs promising multicore rendering advantages, having the CPU conceptually dead while rendering isn't the worst architectural decision I can think of. And likewise, we know the GPU is (probably) idle while the CPU is working, available for GPGPU stuff.

### Parallel pragmatism
It is common to avoid exposing shared memory to the developer, only using threads behind the scenes. For example, an engine can update certain component lists in parallel when it knows they will not cause trouble. With double buffered state, it can process multiple frames simultaneously. Normally sequential tasks like physics, logic and rendering can be pipelined. These strategies suffer primarily from limited scaleability, wasted memory, and input latency respectively.

Their use is understandable when the developer can't be expected to manage the complexity that arises from having more than one thread of execution. Threads are _hard_. It's also hard for established engines (or new engines following established conventions) to make large architectural changes. Features need to slot in gradually, and desktop processors with enough cores to make the old ways ineffective haven't been around long. Dividing a game into separately threaded services is still viable for saturating a quadcore.

Besides, trying to leverage multiple threads is hard enough for the engine developer in most systems languages. Trying to present that task to the end-developer as a surmountable obstacle requires tact, a project with no money riding on it whatsoever, and preferably, a language so high-level it loiters somewhere outside Earth's atmosphere. It would still be all but impossible to justify in an environment designed for non-programmers, and truly impossible to justify in a C++ environment designed for human beings.

Therefore, this engine comes with a disclaimer: it's not for beginners. It's aimed at programmers willing to write multithreaded code (in a sane language). Every effort is being made to provide a simple, convenient interface, but it does not hide necessary complexity. Depending on what the developer wants to do, they will infrequently write code that must synchronise access to shared resources, which requires following some simple rules. It's not too difficult, but it's certainly not suited to teaching newcomers programming in D or game development unless it's combined with some dynamite tutorials and a crash-course on sync primitives (and how to avoid them). 

Then again, D has repeatedly demonstrated that it doesn't really care what I think is impossible. 

### Object oriented
All game logic is implemented by creating entities, which are classes that directly inherit Entity. Developers are expected to make effective use of static composition, interfaces and weak references to implement logic that might otherwise rely on components, messaging or event systems.

Note that entities are not 'super objects', capable of hosting only one of every type of asset. The systems they access have no concept of them, and see only a stream of instructions that might come from one or many sources. This means they could be replaced, if the developer wished to use a more specific framework like ECS. Decomposing a game into statically-typed entities is an artistic decision based on preference (see entity.d for more information).

The entity system is designed to support large populations with frequent creation and destruction. It has a dependency resolving feature (entity A requests that entity B step before it), and entities can be referenced weakly to gracefully allow and detect zombies.

### Small
No bloat, no duplicated functionality, no built-in store with microtransactions (expardon me?) and the executable with UPX compression will likely be under 1mb. Creating assets from reduced data is encouraged. A variety of tools will be available to generate and manipulate meshes, textures and sound.

Sound is stored and transmitted as [Opus](http://opus-codec.org), which can encode both high-quality music and low-latency speech. Images are stored as PNG for compatibility when required, and [WEBP lossless](https://developers.google.com/speed/webp/docs/webp_lossless_bitstream_specification) or [GFWX](http://www.gfwx.org) otherwise.

 An in-house format called RMESH is used to compress mesh data. The [VP9](https://www.webmproject.org/vp9) (and later, [AV1](https://aomediacodec.github.io/av1-spec)) codecs will be available if the appropriate shared objects (.dll or .so) are found, otherwise their footprint is considered excessive for porting, particularly as not all games require a video codec. Other common codecs (MP3, WAV, JPEG) might eventually be made available in the same way, though it is intended for the ported codecs to suffice for most purposes.

Unintuitively, the engine is not overly concerned with its total memory footprint. Modern systems have so much ram that running out is quite difficult, and tends to indicate a leak. However, fetching more memory takes longer, so in practice every object is as small as possible. Nothing is allocated without a degree of pomp and circumstance - a garbage collector is no excuse to create garbage. Structure layout is scrutinised to avoid poor alignment and wasted space. There is no float precision switch, because the engine makes use of float, double and fixed-point math depending on context.

### Fast
Structures are generally flat and stored in contiguous arrays. Algorithms are written for correct meaning first, cache-friendly access patterns second, and micro-optimisations last, with snarky self-deprecating comments to make them obvious. Allocations are currently through malloc, but a specialised allocator will be injected later. Allowances are being made for memory compaction (anyone who's written an allocator will be chortling heartily, but I swear I'm not bluffing).

Bandwidth to and from cache is considered the scarcest resource. Trading a few instructions to avoid a cache miss is usually a good idea on modern CPUs. Branch prediction is assumed to exist, and we don't shy away from depending on it. Indirection is always the last resort.

Priority is placed on avoiding spikes in frame timing. Templated reference counting supplants the tracing garbage collector for most allocations. Tasks normally removed to a separate thread (audio mixing, asset streaming, networking) are instead completed in slack time between frames, using the yielding semantics of D fibers to avoid heavy context switches. Must-complete tasks are run first, then others are scheduled by timing small chunks and stopping before overrun occurs. Textures are uploaded incrementally, and compressed formats (video, image, sound) have implementations that can be suspended and resumed.

Conditional optimisations are ignored if developers aren't expected to be aware of them, much less able to ensure their criteria are met. Temporal coherency is valued on a case-by-case basis. Always remember, O(n) is only wrong until it runs faster in the worst case and prevents unexpected framerate drops. The engine is designed to keep chugging along at a stable frequency, consuming reasonable amounts of memory, even if the game is throwing ridiculous scenarios at it.

Physics updates are taken adaptively to account for local complexity. A constraint under low stress will take fewer cycles, even if it's connected to a large island.

### Simple
Or, as complex as it needs to be, and no more. The codebase is flat and most class names are a single plain english word. Different aspects of the engine (physics, audio, rendering, math etc) are in separate libraries that can be used on their own. Sesquipedalian verbiage is avoided.

Okay, that last bit is a filthy lie.
 
## Code sample
The following is an empty entity definition, to demonstrate the API design principles. It is not a mockup - this is working code.

```d
module car_entity;
import raider.engine;

mixin Export!Car;

@RC class Car : Entity
{ mixin Stuff;
	//override void meta() { }
	//override void look() { }
	//override void step() { }
	//override void draw(Artist artist, double nt) { }
	//void ctor() { }
	//override void dtor() { }
}

@RC class CarFactory : Factory
{ mixin Stuff;
	//this() { }
}
```

A quick rundown follows, for the terminally curious.

```d
import raider.engine;
```

This import brings the entire engine into scope. It should normally be the only import. It includes all common code - maths, audio, physics, containers, and so on.

```d
mixin Export!Car;
```

This adds the entity Car (and its factory, which conforms to the naming convention XXXFactory) to the register. The same register is available to all games created within the executable. A single module can export any number of entities.

```d
@RC class Car : Entity
```

@RC is an attribute used to indicate this class will participate in reference counting. All entities are reference-counted, and have the base class Entity.

```d
mixin Stuff;
```

Pure boilerplate, doing super-secret stuff. The same mixin is used by entities and factories because it can determine where it is through reflection. D's metaprogramming facilities are _dope_.

```d
//void ctor() { }
//override void dtor() { }
//override void meta() { }
//override void look() { }
//override void step() { }
//override void draw(Artist artist, double nt) { }
```

These are the methods developers may choose to implement. Meta, look, step and draw are distinct 'phases' within the main loop. In practice, they cannot all be missing; at least one must be present for the entity to do anything meaningful, so the boilerplate will flag this as an invalid definition. But this isn't a tutorial, so we'll stop there.