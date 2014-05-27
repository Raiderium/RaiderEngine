module raider.engine.animation.curve;

import raider.engine.tool.array;
import raider.math.all;

/**
 * Animated float.
 *
 * A curve animates a real number
 * using a sequence of time-value pairs.
 * 
 * Each point has two handles, in and out,
 * which are two-dimensional vectors.
 * 
 * Two successive points form a segment.
 * The first point's out handle and the
 * second point's in handle control the 
 * interpolation of the segment. They
 * are constrained to point 'inwards', 
 * that is, right and left respectively.
 * 
 * If a handle's length is zero,
 * it is a special case which changes
 * the interpolation method.
 * 
 * If both handles have nonzero length, 
 * the curve is a cubic bezier using the 
 * points and handles as control points.
 * 
 * If both have zero length, the curve is
 * a straight line between the points.
 * 
 * If one handle has nonzero length, the 
 * curve is linearly extrapolated along it,
 * stopping at the other point's time.
 * 
 * Extrapolation beyond the point sequence 
 * is linear, using the slope of the nearest 
 * handle or segment.
 * 
 * The curve can also loop.
 * Curve provides common timing and sorting 
 * behaviour which can then be encapsulated 
 * by other animation tools.
 */
class Curve
{
private:
	float t; 			///Time cursor
	size_t i; 			///Index before cursor
	bool loop;			///Time-loop flag TODO Implement.
	Array!Point points;

public:
	this()
	{
		t = 0.0;
		i = 0;
	}

	void add(Point point)
	{
		points.addSorted(point);
	}

	///The value of the curve at the current time.
	@property float value()
	{
		if(points.length == 0) return 0.0;
		if(points.length == 1)
		{
			Point p = points[0];
			if(t < p.t) return !p.hasIn ? p.v : p.v + (t - p.t)*p.slopeIn;
			if(t > p.t) return !p.hasOut ? p.v : p.v + (t - p.t)*p.slopeOut;
			return p.v;
		}

		//Get points defining segment
		Point a = points[i];
		Point b = points[i+1];

		float ab_time = b.t - a.t;
		float ab_value = b.v - a.v;
		float ab_slope = ab_time == 0.0 ? 0.0 : ab_value / ab_time;

		//Extrapolate left
		if(t < a.t)
		{
			//Linear extrapolation slope: First handle in, then handle out, then segment (if linear), then 0.
			float slope = 0.0;
			if(a.hasIn) slope = a.slopeIn;
			else if(a.hasOut) slope = a.slopeOut;
			else if(!b.hasIn) slope = ab_slope;

			return a.v + (t - a.t)*slope;
		}
		
		//Extrapolate right
		if(b.t < t)
		{
			float slope = 0.0;
			if(b.hasOut) slope = b.slopeOut;
			else if(b.hasIn) slope = b.slopeIn;
			else if(!a.hasOut) slope = ab_slope;
			
			return b.v + (t - b.t)*slope;
		}
		
		//Get normalized time
		float fac = (a.t == b.t) ? 0.0 : (t - a.t) / ab_time;

		//Linear interpolation
		if(!a.hasOut && !b.hasIn) return lerp(fac, a.v, b.v);

		//Linear from a
		if(!b.hasIn) return a.v + (t - a.t)*a.slopeOut;

		//Linear from b
		if(!a.hasOut) return b.v + (t - b.t)*b.slopeIn;

		//Bezier
		float x1 = a.handleOut[0] / ab_time;
		float x2 = (ab_time + b.handleIn[0]) / ab_time;

		float x_solve = solveMonotonicCubicBezier(fac, x1, x2);
		return bez(x_solve, a.v, a.v + a.handleOut[1], b.v + b.handleIn[1], b.v);
	}

	@property float time() { return t; } ///The current time cursor of the curve.
	@property void time(double value) { addTime(value - t); } ///ditto

	///Move the time cursor.
	void addTime(double dtime)
	{
		t += dtime;

		//Find the segment closest to the new time, and set i to the index of the leftmost point of the segment.
		if (dtime > 0.0) 
		{
			while(points[i+1].t < t)
			{
				if(i == points.length-1) break;
				i++;
			}
		}
		else
		{
			while(points[i].t > t) 
			{
				if(i == 0) break;
				i--;
			}
		}
	}

	///UUUUUUUUUUUUUHGHHGHHGHHHHGGGHGHGHGGGGGG.
	static double solveMonotonicCubicBezier(double x, double p1, double p2) //p0 and p3 are implicitly 0.0 and 1.0
	{
		assert(0.0 <= p1 && p1 <= p2 && p2 <= 1.0);
		assert(0.0 <= x && x <= 1.0);

		//Instead of working in a 0.0 .. 1.0 floating point space, this 
		//algorithm converts everything to an integer space 0 .. int.max.
		//This makes dividing by 2 (important to the algorithm) faster
		//without significantly affecting precision.
		//TODO Profile performance to see if this is actually true

		//Convert some basic elements
		immutable uint tolerance = 100;
		uint loopMax = 32;
		uint goal = cast(uint)(x*int.max); //Note that a 64-bit double happily represents 32-bit int.max during the conversion.
		uint error;
		uint t = int.max/2; //The time splitting the current binary search window in two
		uint s = int.max/4;	//The size of the next binary search window (the next smaller power of two)
		
		//Convert the bezier control points
		uint i0 = 0;
		uint i1 = cast(uint)(p1*int.max);	
		uint i2 = cast(uint)(p2*int.max);
		uint i3 = int.max;

		//And now, a binary search starring de Casteljau subdivision with a cast (badum-tish) of integers.
		do
		{
			uint q0 = i0 + i1; q0 /= 2;	//Here, we must add two signed ints. This is why the range goes to int.max, not uint.max.
			uint q1 = i1 + i2; q1 /= 2; //The receiving uint can represent the extreme case of int.max + int.max. 
			uint q2 = i2 + i3; q2 /= 2;
			
			uint r0 = q0 + q1; r0 /= 2; //Remember: write what we mean, not what we want the compiler to do (a logical right bitshift...)
			uint r1 = q1 + q2; r1 /= 2;
			
			uint result = r0 + r1; result /= 2;
			
			if(goal == result) break;
			
			//Subdivide
			if(goal < result)
			{
				i1 = q0;
				i2 = r0;
				i3 = result;
				t -= s;
				error = result - goal;
			}
			else
			{
				i0 = result;
				i1 = r1;
				i2 = q2;
				t += s;
				error = goal - result;
			}
			
			s /= 2;
			--loopMax;
		}
		while(error > tolerance && loopMax);
		return cast(double)t / int.max;
	}
}

struct Point
{
	float t, v;		//Time-value pair
	vec2f handleIn;
	vec2f handleOut;
	
	@property bool hasIn() { return handleIn[0] != 0.0 || handleIn[1] != 0.0; }
	@property bool hasOut() { return handleOut[0] != 0.0 || handleOut[1] != 0.0; }
	@property float slopeIn() { return handleIn[0] == 0.0 ? 0.0 : handleIn[1] / handleIn[0]; }
	@property float slopeOut() { return handleOut[0] == 0.0 ? 0.0 : handleOut[1] / handleOut[0]; }
	
	this(float time, float value, vec2f a, vec2f b)
	{
		t = time; v = value;
		this.handleIn = a; this.handleOut = b;
	}

	this(float time, float value)
	{
		t = time; v = value;
	}
	
	int opCmp(ref const Point p) const
	{
		if(t < p.t) return -1;
		if(t > p.t) return 1;
		return 0;
	}
}

unittest
{
	//TODO curve unittests
}