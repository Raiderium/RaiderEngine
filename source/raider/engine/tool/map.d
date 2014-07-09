module raider.engine.tool.map;

import std.algorithm : swap, cmp;
import std.exception;
import raider.engine.tool.array;

/**
 * Associative array.
 * 
 * Unlike builtin associative arrays, this does not
 * mishandle struct destruction, and cooperates with
 * tool.reference.
 */
struct Map(K, V)
{
	struct Pair
	{
		K key;
		V value;

		//Allow to find a pair by its key
		bool opEquals(const Pair that) const
		{
			return key == that.key;
		}

		//Allow to sort by key (allows binary search)
		int opCmp(const Pair that) const
		{
			//Use lexicographical case-aware comparison for strings
			static if(is(K == string)) return cmp(key, that.key); 
			else return key.opCmp(that.key); 
		}
	}

	Array!Pair pairs;

	void opAssign(Map!(K, V) that)
	{
		swap(this.pairs, that.pairs);
	}

	void opIndexAssign(V value, const K key)
	{
		size_t index;

		Pair pair = Pair(key, value);

		if(pairs.find(pair, index))
			//Overwrite existing value
			pairs[index].value = value;
		else
			//Add new value
			pairs.addSorted(pair);
	}

	ref V opIndex(const K key)
	{
		size_t index;
		Pair pair = Pair(key, V.init);

		if(pairs.find(pair, index))
			return pairs[index].value;
		else
			throw new MapException("'" ~ key ~ "' not in map");
	}
}

final class MapException : Exception
{ this(string msg) { super(msg); } }

unittest
{
	Map!(string, int) m1;
	m1["i1"] = 3;
	m1["i2"] = 4;
	assert(m1["i1"] == 3);
	assert(m1["i2"] == 4);
	m1["i1"] = 2;
	assert(m1["i1"] == 2);

	assertThrown!MapException(m1["rubbish"]);
}