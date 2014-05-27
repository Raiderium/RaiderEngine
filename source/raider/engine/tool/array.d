module raider.engine.tool.array;

import raider.engine.tool.reference;
import raider.math.tools : nhpo2;
import core.stdc.stdlib;
import core.memory;
import core.stdc.string : memcpy, memmove;
import std.traits;
import std.algorithm : swap, initializeAll, sort;
import std.bitmanip;

/**
 * Array template stores items in contiguous memory.
 * 
 * Items must not be sensitive to being shoved around
 * in memory without consultation.
 * 
 * Items will be registered with the GC if they contain aliasing.
 * The Array struct itself contains no aliasing (at least, none 
 * the GC needs to know about).
 * 
 * References into the array are valid until the next mutating method call.
 * Item order is maintained during mutations unless otherwise noted.
 */
struct Array(T) //TODO Array unittests
{private:
	size_t _data = 0; ///Probably nothing of interest
	@property T* data() { return cast(T*)_data; }
	@property void data(T* value) { _data = cast(size_t)value; }

	size_t _size = 0; ///Number of items stored

	mixin(bitfields!(
		bool, "_snug", 1, //size == capacity
		bool, "_sorted", 1, //data[x] <= data[x+1]
		uint, "_minimumCapacity", 30));

public:
	@property size_t size() { return _size; }
	@property void size(size_t value) { resize(value); }
	@property bool snug() { return _snug; }
	@property bool sorted() { return _sorted; }

	this(this)
	{
		T* that_data = data;
		size_t that_size = size;
		
		data = null;
		size = 0;
		_snug = false;
		_sorted = false;
		_minimumCapacity = 0;
		
		resize(that_size);
		data[0.._size] = that_data[0..that_size]; //Don't memcpy, it skips opAssign
	}
	
	~this()
	{
		clear;
	}
	
	void opAssign(Array!T that)
	{
		swap(this, that);
	}
	
	alias size length;
	
	private size_t capacityStrategy(size_t size)
	{
		return size ? nhpo2(size) : 0;
	}
	
	@property size_t capacity()
	{
		return _snug ? _size : capacityStrategy(_size);
	}

	///Capacity will never fall below minimumCapacity. Defaults to 0.
	@property void minimumCapacity(size_t value)
	{
		//assert(value < _minimumCapacity.max); eh. how do.
		//TODO Implement minimumCapacity.
	}
	
	/**
	 * Resize the array.
	 * 
	 * New items are initialised to T.init, lost items are destroyed.
	 */
	void resize(size_t newSize)
	{
		if(newSize == _size) return;
		
		if(newSize > _size) upsize(_size, newSize - _size);
		else downsize(newSize, _size - newSize); // *sighs*
	}
	
	/**
	 * Insert and initialise a range of items
	 * 
	 * Index may equal _size
	 */
	void upsize(size_t index, size_t amount)
	{
		assert(index <= _size);
		
		if(amount == 0) return;
		
		size_t newCapacity = capacityStrategy(_size+amount);
		
		if(newCapacity > capacity)
		{
			T* newData = cast(T*)malloc(T.sizeof * newCapacity);
			//TODO Profile (with LDC). A normal copy will be better below a certain critical size.
			memcpy(newData, data, T.sizeof * index);
			memcpy(newData+index+amount, data+index, T.sizeof * (_size - index));
			if(hasAliasing!T)
			{
				GC.addRange(cast(void*)newData, T.sizeof * newCapacity);
				GC.removeRange(cast(void*)_data);
			}
			free(data);
			data = newData;
		}
		else memmove(data+index+amount, data+index, T.sizeof * (_size-index));
		
		initializeAll(data[index..index+amount]);
		_size += amount;
		_snug = false;
		_sorted = false;
	}
	
	/**
	 * Destroy and remove a range of items
	 */
	void downsize(size_t index, size_t amount)
	{
		assert(index < _size && (index + amount) <= _size);
		
		if(amount == 0) return;
		
		static if(is(T == struct))
			foreach(ref item; data[index..index+amount])
				typeid(T).destroy(&item);
		
		size_t newCapacity = capacityStrategy(_size-amount);
		
		if(newCapacity < capacity)
		{
			T* newData = cast(T*)malloc(T.sizeof * newCapacity);
			memcpy(newData, data, T.sizeof * index);
			memcpy(newData+index, data+index+amount, T.sizeof * (_size-(index+amount)));
			if(hasAliasing!T)
			{
				GC.addRange(cast(void*)newData, T.sizeof * newCapacity);
				GC.removeRange(cast(void*)data);
			}
			free(data);
			data = newData;
		}
		else memmove(data+index, data+index+amount, T.sizeof * (_size-(index+amount)));
		
		_size -= amount;
		_snug = false;
	}
	
	/**
	 * Remove array margin to reduce memory consumption.
	 * 
	 * Lasts until the next mutation.
	 */
	void snuggle()
	{
		if (!_snug)
		{
			T* newData = cast(T*)malloc(T.sizeof * _size);
			memcpy(newData, data, T.sizeof * _size);
			if(hasAliasing!T)
			{
				GC.addRange(cast(void*)newData, T.sizeof * _size);
				GC.removeRange(cast(void*)data);
			}
			free(data);
			data = newData;
			_snug = true;
		}
	}

	/*
	const(T) opIndex(const size_t i)
	{
		assert(i < _size);
		return data[i];
	}*/

	ref T opIndex(const size_t i)
	{
		assert(i < _size);
		return data[i];
	}
	
	T[] opSlice()
	{
		return data[0.._size];
	}
	
	T[] opSlice(size_t x, size_t y)
	{
		assert(y <= _size && x <= y);
		return data[x..y];
	}
	
	void opSliceAssign(T[] t)
	{
		data[0.._size] = t[];
	}
	
	void opSliceAssign(T[] t, size_t x, size_t y)
	{
		assert(y <= _size && x <= y);
		data[x..y] = t[];
	}
	
	/**
	 * Sorts the array.
	 * 
	 * Sorting algorithm is Introsort (std.algorithm.sort with SwapStrategy.unstable)
	 * It does not allocate.
	 */
	void sort()
	{
		std.algorithm.sort!("a < b", std.algorithm.SwapStrategy.unstable)(data[0.._size]);
		_sorted = true;
	}
	
	/**
	 * Add item to array.
	 * 
	 * If an insertion index is not specified, it defaults to _size (appending).
	 * 
	 * Maintains item order. Shifts the item at the specified index (if any) and all 
	 * items after it (if any) to the right.
	 * 
	 * This swaps the item into the array, replacing the supplied item with T.init.
	 */
	void add(ref T item, size_t index = _size)
	{
		upsize(index, 1);
		swap(data[index-1], item);
		_sorted = false;
	}

	/**
	 * Add copy of item to array.
	 */
	void add(const T item, size_t index = _size)
	{
		upsize(index, 1);
		data[index-1] = item;
		_sorted = false;
	}
	
	/**
	 * Insert item in sorted order.
	 * 
	 * This sorts the array if it is not already sorted, 
	 * and uses binary search to find the insert index.
	 * 
	 * This swaps the item into the array, replacing the supplied item with T.init.
	 */
	void addSorted(ref T item)
	{
		if(_sorted && _size)
		{
			import core.bitop : bsr; //bit scan reverse, finds number of leading 0's 
			
			//b = highest set bit of _size-1
			size_t b = (_size == 1) ? 0 : 1 << ((size_t.sizeof << 3 - 1) - bsr(_size-1));
			size_t i = 0;
			
			//Count down bits from highest to lowest
			for(; b; b >>= 1)
			{
				//Set bits in i (increasing it) while data[i] <= item.
				//Skip bits that push i beyond the array size.
				size_t j = i|b;
				if(_size <= j) continue; 
				if(data[j] <= item) i = j; 
				else
				{
					//If data[i] becomes greater than item, remove the bounds check, it's pointless now.
					//Set bits while data[i] <= item. 
					//Skip bits that make data[i] larger than item.
					b >>= 1;
					for(; b; b >>= 1) if(data[i|b] <= item) i |= b;
					break;
				}
				b >>= 1;
			}
			//i now contains the index of the last item that is <= item.
			//(Or 0 if item is less than everything.)
			if(i) add(item, i+1); //insert the item after it.
			else
			{
				if(item < data[0]) add(item, 0);
				else add(item, 1);
			}
			_sorted = true;
		}
		else
		{
			add(item, _size);
			sort;
		}
	}
	
	/**
	 * Remove the item at the specified index and return it.
	 */
	T remove(size_t index)
	{
		assert(index < _size);
		
		T item;
		swap(item, data[index]);
		downsize(index, 1);
		return item;
	}
	
	/**
	 * Remove the last item in the array and return it.
	 */
	T pop()
	{
		assert(_size);
		
		T item;
		swap(item, data[_size-1]);
		downsize(_size-1, 1);
		return item;
	}
	
	/**
	 * Remove the item at the specified index and return it, potentially disrupting item order.
	 */
	T removeFast(size_t index)
	{
		assert(index < _size);
		
		T item;
		swap(item, data[index]);
		if(index != _size-1)
		{
			swap(data[_size-1], data[index]);
			_sorted = false;
		}
		downsize(_size-1, 1);
		return item;
	}
	
	/**
	 * Find and remove an item.
	 * 
	 * Returns true on success, false if the item was not found.
	 */
	bool removeItem(const T item)
	{
		size_t index;
		if(find(item, index))
		{
			remove(index);
			return true;
		}
		return false;
	}
	
	/**
	 * Find the index of an item.
	 * 
	 * Returns true if found, and puts the index in foundIndex.
	 */
	bool find(const T item, out size_t foundIndex)
	{
		//TODO Binary search if _sorted. Also, predicate mixin search.
		foreach(x; 0.._size)
		{
			if(data[x] == item)
			{
				foundIndex = x;
				return true;
			}
		}
		return false;
	}
	
	/**
	 * Check if the array contains an item.
	 */
	bool contains(const T item)
	{
		size_t dat_index_tho;
		return find(item, dat_index_tho);
	}
	
	///Remove all items.
	void clear()
	{
		resize(0);
	}
	
	@property bool empty() { return _size == 0; }
}