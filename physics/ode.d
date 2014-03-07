///This module exposes the Open Dynamics Engine API.
module physics.ode;

import rm;
public import derelict.ode.ode;
import derelict.util.exception;

/* Note to whom it may concern.
 * While compiling ODE as a shared library with gcc, remember it needs the compiler flag -fno-exceptions.
 * Otherwise, on loading, the dll will try and fail to find __gxx_personality_v0.
 * (A global variable related to c++ exception handling, which ODE doesn't use anyway.) 
 * If you need c++ exception handling, link libstdc++ in, or compile with g++ (which does the same thing).*/

/* dInitODE and dCloseODE have to be called before and after using the library.
 * D provides a way to call stuff at the start and end of a program, through 
 * shared static this() and shared static ~this(). Since ODE is likely to be
 * used throughout the program's life, what better way to call them? */
shared static this()
{
	//Oh, and Derelict needs to actually load the ODE shared library here too.
	//Apparently I don't know how to build a dll with dPrintMatrix in it.
	//So this little snippet tells Derelict to ignore it. :I
	DerelictODE.missingSymbolCallback = function ShouldThrow(string symbolName)
	{
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

///Copy a RaiderMath mat3 into an ODE dMatrix3.
void convert(ref mat3 m, dMatrix3 d)
{
	//mat3 and dMatrix3 are the same thing, but have different storage layouts.
	//ODE 3x3 matrices are actually 3x4, with a padding 0 on each row for future compatability with SIMD.
	//RM 3x3 matrices don't have padding because they favor ease of use over performance.
	//Happily, both types are row-major, avoiding a major potential source of confusion.
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

///Copy an ODE dMatrix3 into a RaiderMath mat3. 
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