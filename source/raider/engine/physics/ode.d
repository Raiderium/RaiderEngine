///Provides the Open Dynamics Engine API
module raider.engine.physics.ode;

import raider.math.all;
public import derelict.ode.ode;
import derelict.util.exception;

/* Note to whom it may concern.
 * While compiling ODE as a shared library with gcc, remember it needs the compiler flag -fno-exceptions.
 * Otherwise, on loading, the dll will try and fail to find __gxx_personality_v0.
 * (A global variable related to c++ exception handling, which ODE doesn't care about.) 
 * If you need c++ exception handling, link libstdc++ in, or compile with g++ (which does the same thing).
 */

/* dInitODE and dCloseODE have to be called before and after using the library.
 * D provides a way to call stuff at the start and end of a program, through 
 * shared static this() and shared static ~this(). Since ODE is likely to be
 * used throughout the program's life, what better way to call them?
 */

shared static this()
{
	//Oh, and Derelict loads the ODE shared library here too.

	DerelictODE.missingSymbolCallback = function ShouldThrow(string symbolName)
	{
		//dPrintMatrix hates me. I can't seem to build an ode.dll without it running away.
		if(symbolName == "dPrintMatrix") return ShouldThrow.No;
		return ShouldThrow.Yes;
	};
	DerelictODE.load();
	dInitODE();
}

shared static ~this()
{
	dCloseODE();

	//Derelict automaticaly unloads the ODE shared library
}

///Copy a mat3 into a dMatrix3.
void convert(ref mat3 m, dMatrix3 d)
{
	//mat3 and dMatrix3 are the same thing, but have different storage layouts.
	//ODE 3x3 matrices are actually 3x4, with a padding 0 on each row for future compatability with SIMD.
	//RM 3x3 matrices don't have padding because they favor ease of use and memory over performance.
	//Happily, both types are row-major, avoiding a source of confusion.
    d[0] = m[0][0];
    d[1] = m[0][1];
    d[2] = m[0][2];
    d[4] = m[1][0];
	d[5] = m[1][1];
	d[6] = m[1][2];
	d[8] = m[2][0];
	d[9] = m[2][1];
	d[10]= m[2][2];
}

///Copy a dMatrix3 into a mat3. 
void convert(const dMatrix3 d, ref mat3 m)
{
	m[0][0] = d[0];
	m[0][1] = d[1];
	m[0][2] = d[2];
	m[1][0] = d[4];
	m[1][1] = d[5];
	m[1][2] = d[6];
	m[2][0] = d[8];
	m[2][1] = d[9];
	m[2][2] = d[10];
}