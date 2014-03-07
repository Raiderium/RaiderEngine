/**
 * Provides a basic serialisation system, streamlined for use in games.
 * 
 * Serialisation, also known as marshalling, persisting, flattening, 
 * pickling and shelving, is referred to here as 'packing'.
 * 
 * To participate, a class, struct or union defines void describePack(PackTask),
 * which calls methods on the PackTask of the form describeX to 
 * describe the structure of the object. (It may also update the 'activity'
 * property for asynchronous feedback.)
 * 
 * describePack is called while writing and reading. It should involve minimal 
 * computation and code branching, being as close to a straight binary dump as possible.
 * For the sake of improving performance only, it is possible to check which way
 * data is flowing with the PackTask.packing and PackTask.unpacking properties.
 * 
 * describePack is called once while reading and twice while writing. The first call
 * while writing is a dry run used to predict the size of the written data.
 * 
 * describePack may throw, but it should leave the object in a valid state. 
 * Either catch and rethrow or use scope(failure) to react to exceptions
 * thrown by the task methods. Do not suppress them.
 */

module tool.packable;

import std.traits;
import std.parallelism;
import core.sync.mutex;
import core.thread;
import core.time;
import std.stdio;
public import tool.stream;

/**
 * Save packable to file.
 * 
 * Opens a file with the specified filename and packs the object into it.
 * If blocking, executes in current thread and throws exceptions.
 * If non-blocking, executes in worker thread and collects exceptions for later management.
 * 
 * Do not operate on the same object in multiple threads.
 */
PackTask save(T)(T packable, string filename, bool block = true)
{
	return execute(packable, new FileStream(filename, true), block);
}

/**
 * Load packable from file.
 * 
 * Opens a file with the specified filename and unpacks the object from it.
 * If blocking, executes in current thread and throws exceptions.
 * If non-blocking, executes in worker thread and collects exceptions for later management.
 * 
 * Do not operate on the same object in multiple threads.
 */
PackTask load(T)(T packable, string filename, bool block = true)
{
	return execute(packable, new FileStream(filename, false), block);
}

///Assistance function reduces code duplication in save, load, etc.
private PackTask execute(T)(T packable, Stream stream, bool block)
{
	PackTask task = new PackTask(&packable.describePack, stream);
	task.run(block);
	return block ? null : task;
}


/**
 * Unit of packing work.
 * 
 * Encapsulates a packable and a stream to operate on.
 */
final class PackTask
{
private:
	void delegate(PackTask) describePack;
	Stream stream;
	uint bytesTotal;
	uint bytesDescribed;
	bool _ready;
	Exception _exception;
	string _activity;

	/**
	 * Params:
	 * describePack = The object's describePack delegate.
	 * stream = The stream to write/read.
	 */
	this(void delegate(PackTask) describePack, Stream stream)
	{
		this.describePack = describePack;
		this.stream = stream;
		bytesTotal = 0;
		bytesDescribed = 0;
		_ready = false;
		_exception = null;
		_activity = "nothing";
	}

	/**
	 * Runs the packing task or dispatches it to taskPool.
	 */
	void run(bool block)
	{
		if(block)
		{
			packTask();
			if(_exception) throw _exception;
		}
		//TODO Replace taskPool with custom task system to avoid GC allocations
		else taskPool.put(task(&packTask));
	}

	void packTask()
	{
		try
		{
			if(stream.writing) calculateBytesTotal;
			else bytesTotal = uint.sizeof;

			//Describe size of pack
			describe(bytesTotal);
			if(stream.reading && bytesTotal > 1048576*100) throw new Exception("Pack size read as > 100mb. Probable data corruption. Excepting for safety.");

			//Describe pack
			describePack(this);
			if(bytesDescribed < bytesTotal) throw new Exception("Pack description fell short of predicted size. Possible data corruption.");

			_ready = true;
		}
		catch(Exception e)
		{
			_exception = e;
		}
		finally
		{
			//TODO If an archive format is necessary, make sure stream.bytesWrought == bytesTotal.
		}
	}

	void calculateBytesTotal()
	{
		//Remove stream to prevent modification
		Stream temp = stream;
		stream = null;
		
		describe(bytesTotal);
		describePack(this);
		
		//Get results and restore stream
		bytesTotal = bytesDescribed;
		bytesDescribed = 0;
		stream = temp;
		_activity = "working";
	}

public:
	@property bool packing() { return stream ? stream.writing : true; }
	@property bool unpacking() { return stream ? stream.reading : false; }
	@property bool ready() { return _ready; }
	@property bool error() { return cast(bool)_exception; }
	@property Exception exception() { return _exception; }
	@property double progress() { return bytesTotal ? cast(double)bytesDescribed / bytesTotal : 0.0; }
	@property string activity() { return stream ? _activity : "calculating size"; }
	@property void activity(string value) { _activity = value; }

	/**
	 * Describes an item of data in the packable.
	 * 
	 * If the specified item defines describePack it is nested appropriately.
	 * If the item is a struct or union and does not define describePack, it is 
	 * treated as a built-in type (described as it appears in memory).
	 * 
	 * It is a compile-time error to pass a class of item that does not define describePack.
	 */
	final void describe(T)(ref T data)
	{
		T[] temp = (&data)[0..1];
		describeTuple(temp);
	}

	///ditto
	final void describeTuple(T)(T[] data)
	{
		static if(hasMember!(T, "describePack"))
		{
			foreach(ref T packable; data)
			{
				packable.describePack(this);
			}
		}
		else
		{
			static assert(!is(T == class));

			bytesDescribed += data.length * T.sizeof;
			
			if(stream)
			{
				if(bytesDescribed > bytesTotal) throw new Exception("Pack description exceeded predicted size. Possible data corruption.");
				ubyte[] temp = (cast(ubyte*)data.ptr)[0..data.length*T.sizeof];
				stream.work(temp);
			}
		}
	}

	///ditto
	final void describeArray(T)(ref T[] data)
	{
		uint length = data.length;
		describe(length);

		if(unpacking)
		{
			data.length = length;
			static if(is(T == class))
			{
				foreach(ref T packable; data) packable = new T();
			}
		}

		describeTuple(data);
	}
}

///Combines multiple asynchronous tasks into one.
final class Packer
{
	private PackTask[] tasks;

	///Adds a task. Ignores null values.
	void add(PackTask task)
	{
		if(task) tasks ~= task;
	}

	@property string activity()
	{
		//Find the first non-ready task with bytesTotal != 0. In practice, with a single worker thread, this finds the currently active task.
		foreach(ref PackTask task; tasks) if(!task.ready && task.bytesTotal != 0) return task.activity;
		return "nothing";
	}

	@property final double progress()
	{
		double totalProgress;
		foreach(ref PackTask task; tasks) totalProgress += task.progress;
		return tasks.length ? progress / tasks.length : 0.0;
	}

	@property final bool error()
	{
		foreach(ref PackTask task; tasks) if(task.error) return true;
		return false;
	}

	@property Exception exception()
	{
		foreach(ref PackTask task; tasks) if(task.exception) return task.exception;
		return null;
	}

	@property final bool ready()
	{
		foreach(ref PackTask task; tasks) if(!task.ready) return false;
		return true;
	}
}

shared static this()
{
	defaultPoolThreads = 1;
}


//TODO Bug prevents compilation of UnittestB (depends on A) inside the unit test.
//http://d.puremagic.com/issues/show_bug.cgi?id=852
final class UnittestA
{
	int[] array;
	int[3] tuple;
	double single;
	
	this()
	{
		array = [1,2,3,4,5];
		tuple = [6,7,8];
		single = 12.345678;
	}
	
	void zero()
	{
		array = [];
		tuple = [0,0,0];
		single = 0.0;
	}
	
	void describePack(PackTask task)
	{
		task.describeArray(array);
		task.describeTuple(tuple);
		task.describe(single);
	}
}

final class UnittestB
{
	UnittestA[] array;
	
	this()
	{
		array = [new UnittestA, new UnittestA, new UnittestA];
		array[0].single = 0.0;
		array[0].array = [0,0];
		array[1].single = 1.1;
		array[1].array = [1,1];
		array[2].single = 2.2;
		array[2].array = [2,2];
	}
	
	void zero()
	{
		array = [];
	}
	
	void describePack(PackTask task)
	{
		task.describeArray(array);
	}
}

unittest
{
	UnittestA a = new UnittestA();
	save(a, "TestPackableA");
	a.zero;
	load(a, "TestPackableA");

	assert(a.array == [1,2,3,4,5]);
	assert(a.tuple == [6,7,8]);
	assert(a.single == 12.345678);


	UnittestB b = new UnittestB();
	save(b, "TestPackableB");
	b.zero;
	load(b, "TestPackableB");

	assert(b.array[1].single == 1.1);
	assert(b.array[1].array == [1,1]);
	assert(b.array.length == 3);
}

/* Old task thread implementation */
/*
class PackThread : Thread
{public:
	void stop()
	{
		running = false;
	}

private:

	Mutex mutex;
	PackTask[] tasks;
	bool running;
	
	this()
	{
		super(&run);
		mutex = new Mutex();
		running = true;
	}

	void run()
	{
		while(running)
		{
			PackTask task;
			synchronized(mutex)
			{
				if(tasks.length)
				{
					task = tasks.first;
				}
			}

			task.doTask();

			synchronized(mutex)
			{
				assert(tasks.remove(packable));
			}

			sleep(msecs(20));
		}
	}

	void addTask(PackTask task)
	{
		synchronized(mutex)
		{
			assert(!hasTask(task.packable));
			tasks[task.packable] = task;
		}
	}

	PackTask getTask(IPackable packable)
	{
		synchronized(mutex)
		{
			foreach(ref PackTask task; tasks)
			{
				if(task.packable == packable) return task;
			}
		}
		return null;
	}
}*/
