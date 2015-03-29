#RaiderEngine


A 3D game engine. Incomplete.

##Graphics
- OpenGL 1.1 and up
- Graceful fallback to fixed function
- Pixel and vertex shaders
- Closest light detection and sorting
- Bezier animation curves
- Armatures with IK and nonlinear mixing
- Shape keys
- Deformation controlled by programmer
- True motion blur / depth of field
- Full support for total ignorance of OpenGL

##Mechanics
- Soft-constraint rigidbody physics
- 3D sound with HDR ducking, travel delay, effect regions
- Object-oriented entity framework
- (A)synchronous (de)serialisation system
- Blender content exporters
- Multiplatform
- Tiny


##Rationale

This is a minimal engine written from scratch. Its goal is to push skillful artifice in software rather than brute force in hardware. The API is kept as simple, shallow and intuitive as possible. Tasks are often performed in software to improve flexibility, not for lack of available hardware. 

The engine omits a scripting language. D compiles very quickly and adheres to standards, making client-side compilation feasible. If all engine objects are rolled into one linkable, and a subset of the toolchain is bundled, a portable and rapid build cycle may be possible, allowing script-like features without a crippling performance loss and terrifying complexity gain.

Not counting the GPU, all processor cores should be more saturated than not before bottlenecks appear. The main loop makes a special effort to be pleasingly parallel, or at least agreeably concurrent, without taking power from the developer or making excessive demands on their skills with regards to shared memory.

This has implications for the API. Every effort is being made to provide a simple interface, but it is still mid-level, and the dev will at times need to follow rules not enforced by the language. The code they write will share memory, which involves some simple (but easily forgotten) rules. Not for beginners.

The engine optimises on the assumption that every scene will be as demanding as it could possibly be at all times, and the lowest framerate encountered is the only framerate that matters. Conditional optimisations are often ignored, since most developers aren't even aware of them, much less able to ensure their criteria are met. They disguise the true complexity ceiling, leading to a final product with unexpected framerate drops. Temporal coherency is valued on a case-by-case basis.

The physics broadphase demonstrates - it assumes objects are always in motion. It sees no theoretical difference between a thousand balls at rest and a thousand balls bouncing around at great speed. This assumption results in a rather naive-looking architecture that greatly reduces performance in the former case, but slightly improves it in the latter case. Some people might not appreciate this design philosophy, and that's fine. It only benefits a certain flavour of game.

(Note that rigidbody sleepers are considered a viable optimisation since the average developer can reason about and guarantee their presence. However, they are implemented outside the broadphase algorithm.)