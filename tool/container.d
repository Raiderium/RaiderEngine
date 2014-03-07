module tool.container;

import tool.memory;

import core.stdc.stdlib;

//Next largest or equal power of two. 0 is considered a power of two for behavioural purposes.
size_t nlpo2(size_t x)
{
	size_t p;
	
	if(x == 0) return 0;

	p = 1;
	while(p < x) p <<= 1;
	return p;
}

bool ispo2(size_t x)
{
	return x && ((x & (~x + 1)) == x); //'complement and compare' method
}


/**
 * Array template stores items in contiguous memory.
 *
 * The template uses memmove and memcpy to unceremoniously shove items around.
 * For efficiency, the data is not registered with the GC, and items stored in
 * the array are not capable of ensuring GC allocated objects remain valid.
 * 
 * New items are initialised to T.init. Neither constructor nor destructor are used.
 * 
 * References to items in the array are valid until the next method call.
 * Item order is maintained during mutations unless otherwise noted.
 * No exceptions are thrown, no bounds are checked.
 */
struct Array(T)
{private:
	T* _data;
	size_t _size;	///Number of items stored
	bool _snug;		///size == allocatedSize

	this()
	{
		_data = null;
		_size = 0;
		_snug = false;
	}

	void dispose()
	{
		if(_data) free(_data);
		_data = null;
		_size = 0;
		_snug = false;
	}

	@property void share(ref Array!T other)
	{
		//TODO Implement sharing.
		//It should be impossible to modify or mutate a shared array.
	}

	@property void size(size_t value)
	{
		resize(value);
	}

	@property size_t size()
	{
		return _size;
	}

	alias size length;

	@property size_t allocatedSize()
	{
		return _snug ? _size : nlpo2(_size);
	}

	/**
	 * Resize the array.
	 * 
	 * New items are initialised to T.init, lost items disappear into the void.
	 */
	void resize(size_t newSize)
	{
		if(newSize == _size) return;

		size_t newAllocatedSize = nlpo2(newSize);

		if(newSize > _size)
		{
			if(newAllocatedSize > allocatedSize)
			{
				//Move items into a new array
				T* newData = malloc(T.sizeof * newAllocatedSize);
				newData[0.._size] = _data[0.._size]; //memcpy(newData, _data, T.sizeof*_size);
				free(_data);
				_data = newData;
			}

			//Init new items
			_data[_size..newSize] = T.init; //for(size_t x = _size; x < newSize; x++) _data[x] = T.init;
			_size = newSize;
			_snug = false;
		}
		else
		{
			//Move items into a new array, dropping items off the end
			if(newAllocatedSize < allocatedSize)
			{
				T* newData = malloc(T.sizeof * newAllocatedSize);
				newData[0..newSize] = _data[0..newSize]; //memcpy(newData, _data, T.sizeof * newSize);
				free(_data);
				_data = newData;
			}
			
			_size = newSize;
			_snug = false;
		}
	}

	/**
	 * Remove array margin to reduce memory consumption.
	 */
	void snuggle()
	{
		if (!_snug)
		{
			T* newData = malloc(T.sizeof * _size);
			newData[0.._size] = _data[0.._size]; //memcpy(newData, _data, T.sizeof * _size);
			free(_data);
			
			_data = newData;
			_snug = true;
		}
	}

	ref T opIndex(const size_t i)
	{
		return _data[i];
	}

	T[] opSlice()
	{
		return _data[];
	}
	
	T[] opSlice(size_t x, size_t y)
	{
		return _data[x..y];
	}
	
	void opSliceAssign(T[] t)
	{
		_data[] = t[];
	}
	
	void opSliceAssign(T[] t, size_t x, size_t y)
	{
		_data[x..y] = t[];
	}

	@property T* ptr()
	{
		return _data;
	}

	/**
	 * Append item.
	 */
	void add(const T item)
	{
		resize(_size+1);
		_data[_size-1] = item;
	}

	/**
	 * Insert item at the specified index.
	 *
	 * Maintains item order. Shifts the item at the specified index and all 
	 * items after it to the right. Index may equal size.
	 */
	void add(size_t index, const T item)
	{
		size_t newAllocatedSize = nlpo2(_size+1);

		if(newAllocatedSize > allocatedSize)
		{
			T* newData = malloc(T.sizeof * newAllocatedSize);
			newData[0..index] = _data[0..index];
			newData[index+1 .. _size+1] = _data[index.._size];
			free(_data);
			_data = newData;
		}
		else
		{
			//D can't move memory that overlaps itself.
			memmove(_data+index+1, _data+index, _size-index); //_data[index+1.._size+1] = _data[index.._size]
		}

		_data[index] = item;
		_size++;
		_snug = false;
	}

	/**
	 * Insert item in sorted order.
	 * 
	 * Array must be in sorted state. Item must be comparable.
	 */
	void addSorted(const T item)
	{
		//TODO implement Array.addSorted
		//Use binary search to find where to insert
	}

	/**
	 * Remove the last item in the array and return it.
	 */
	T pop()
	{
		assert(_size);
		T item = _data[_size-1];
		resize(_size-1);
		return item;
	}

	/**
	 * Remove the item at the specified index.
	 * 
	 * Maintains item order.
	 */
	void remove(size_t index)
	{
		size_t newAllocatedSize = nlpo2(_size-1);
		
		if(newAllocatedSize < allocatedSize)
		{
			T* newData = malloc(T.sizeof * newAllocatedSize);
			newData[0..index] = _data[0..index]; //memcpy(newData, _data, T.sizeof * newSize);
			newData[index.._size-1] = _data[index+1.._size];
			free(_data);
			_data = newData;
		}
		else
		{
			memmove(_data+index, _data+index+1, (_size-index)-1); //_data[index.._size-1] = _data[index+1.._size]
		}
		
		_size--;
		_snug = false;
	}

	/**
	 * Remove the item at the specified index.
	 * 
	 * Disrupts item order.
	 */
	void removeFast(size_t index)
	{
		if(index != _size-1) _data[index] = _data[_size-1];
		resize(_size-1);
	}
	
	/**
	 * Find the index of an item by value.
	 * 
	 * Returns true if the item was found, and puts the index in foundIndex.
	 */
	bool findItem(const T item, ref size_t foundIndex)
	{
		for(size_t x = 0; x < _size; x++)
		{
			if (_data[x] == item)
			{
				index = x;
				return true;
			}
		}
		return false;
	}

	/**
	 * Find the index of an item by value, in a sorted array.
	 * 
	 * Returns true if the item was found, and puts the index in foundIndex.
	 * Uses a binary search.
	 */
	 bool findItemFast(const T item, ref size_t foundIndex)
	{
		//TODO Implement findItemFast
	}
	
	///Remove all items.
	void clear()
	{
		resize(0);
	}

	@property bool empty() { return _size == 0; }
}

///Singly-linked list stores
template SListItem(string list)
{
	const char* SListItem = "typeof(this) "~list~"Next;";
}

template SList(string type, string list)
{
	const char* SList = type~" "~list~"Head;";
}

/**
 * Add an item to the start of the list.
 * O(1) complexity. Undefined behaviour if called twice for the same item.
 */
template SListAdd(string owner, string list, string item)
{
	const char* SListAdd = "
	assert("~item~");
	"~item~"."~list~"Next = "~owner~"."~list~"Head;
	"~owner~"."~list~"Head = "~item~";";
}

/**
 * Add an item to the list in sorted position.
 * O(n) complexity.
 */
template SListAddSorted(string owner, string list, string item)
{
	const char* SListAddSorted = "
	assert("~item~");
	alias "~owner~"."~list~"Head _head;
	alias "~item~" _item;
	alias "~item~"."~list~"Next _itemnext;
	typeof(_head) _x = _head;
	alias _x."~list~"Next _xnext;
	
	if(_head && _head < _item)
	{
		//Advance x until item is sorted between x and xnext
		while(_x)
		{
			if(!_xnext) //Reached the end; insert at end
			{
				_xnext = _item;
				_itemnext = null;
				break;
			}
			
			if(_item < _xnext) //Sorted between x and xnext; insert there
			{
				_itemnext = _xnext;
				_xnext = _item;
				break;
			}
		}
	}
	else //The list is empty or item is sorted before head; insert at head
	{
		_itemnext = _head;
		_head = _item;
	}
	";
}

/**
 * Remove an item.
 * O(n) complexity. Unless onNotFound is specified, it will assert if the item is not found.
 * Be careful mixing this in from a method on the item - you might delete yourself.
 */
template SListRemove(string owner, string list, string item, string onRemove = "", string onNotFound = "assert(0);")
{
	const char* SListRemoveSingle = "
	assert("~item~");
	alias "~owner~"."~list~"Head _head;
	alias "~item~" _item;
	typeof(_head) _x = _head;
	typeof(_head) _prev = null;
	alias _x."~list~"Next _xnext;
	
	//This algorithm has a similar task to SListAddSorted but is implemented in a different way for the sake of curiosity
	while(_x)
	{
		if(_x == _item)
		{
			if(_prev) _prev."~list~"Next = _xnext;
			else _head = _xnext;
			"~onRemove~";
			break;
		}
		_prev = _x;
		_x = _xnext;
	}
	if(!_x) "~onNotFound~";";
}

/**
 * Empty the list of items.
 * O(1) complexity.
 */
template SListClear(string owner, string list)
{
	const char* SListClear = owner~"."~list~"Head = null;";
}

/**
 * Evaluate an expression for each item in the list.
 */
template SListForEach(string item, string owner, string list, string expr)
{
	const char* SListFor = "
	alias "~owner~"."~list~"Head _head;
	typeof(_head) "~item~" = _head;
	alias "~item~" _item;
	alias "~item~"."~list~"Next _itemnext;
	
	while(_item)
	{
		"~expr~";
		_item = _itemnext;
	}";
}

/**
 * Evaluate a filter for each item and remove the item if it evaluates false.
 * onRemove is called for each removed item. It is free to modify or delete the item.
 */
template SListFilter(string item, string owner, string list, string filter, string onRemove = "")
{
	const char* SListRemove = "
	alias "~owner~"."~list~"Head _head;
	typeof(_head) _prev = null;
	typeof(_head) "~item~" = _head;
	alias "~item~" _item;
	alias "~item~"."~list~"Next _itemnext;
	
	while(_item)
	{
		if("~filter~")
		{
			_prev = _item;
			_item = _itemnext;
		}
		else
		{
			typeof(_head) _temp = _itemnext;
			if(_prev) _prev."~list~"Next = _temp;
			else _head = _temp;
			"~onRemove~"; //temp of itemnext is necessary so onRemove is free to delete the item
			_item = _temp;
		}
	}";
}