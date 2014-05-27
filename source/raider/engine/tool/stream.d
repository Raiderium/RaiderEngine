module raider.engine.tool.stream;

import derelict.physfs.physfs;
import raider.engine.tool.reference;

/**
 * Takes data from somewhere, and puts it elsewhere.
 */
abstract class Stream
{public:
	enum Mode
	{
		Write,
		Read,
		Duplex
	}

protected:
	void writeBytes(const(ubyte)[] bytes);
	void readBytes(ref ubyte[] bytes);

private:
	string source;
	private Mode _mode;
	private uint _bytesWritten;
	private uint _bytesRead;

public:
	this(string source, Mode mode)
	{
		this.source = source;
		_mode = mode;
		_bytes = 0;
	}

	final void write(T)(const(T)[] objects)
	{
		assert(writable);
		_bytesWritten += T.sizeof * objects.length;
		writeBytes((cast(const(ubyte)*)objects.ptr)[0..objects.length*T.sizeof]);
	}

	final void read(T)(ref T[] objects)
	{
		assert(readable);
		_bytesRead += T.sizeof * objects.length;
		ubyte[] bytes = (cast(ubyte*)objects.ptr)[0..objects.length*T.sizeof];
		readBytes(bytes);
	}

	@property uint bytesWritten() { return _bytesWritten; }
	@property uint bytesRead() { return _bytesRead; }
	@property bool writable() { return _mode == Write || _mode == Duplex; }
	@property bool readable() { return _mode == Read || _mode == Duplex; }
}

final class FileStream : Stream
{private:
	PHYSFS_File file;
	string filename;

public:
	this(string filename, Mode mode)
	{
		assert(mode != Mode.Duplex);
		super(filename, mode);
		this.filename = filename;

		file = writable ? PHYSFS_openWrite(filename) : PHYSFS_openRead(filename);
		
		if(file == null) throw new StreamException(
			"Couldn't open file '" + filename + "' for " + mode ? "writing" : "reading");
	}

	~this()
	{
		if(PHYSFS_close(file) == -1)
			throw new StreamException("Failed to close '" + filename + "'. Probably a buffered write failure.");
	}

	override void writeBytes(const(ubyte)[] bytes)
	{
		if(PHYSFS_write(file, cast(const(void)*)bytes.ptr, bytes.length, 1) != 1)
			throw new StreamException("Error writing to '" + filename + "'");
	}

	override void readBytes(ref ubyte[] bytes)
	{
		if(PHYSFS_read(file, cast(void*)bytes.ptr, bytes.length, 1) != 1)
			throw new StreamException("Error reading from '" + filename + "'");
		if(PHYSFS_eof(file))
			throw new StreamException("EOF reading from '" + filename + "'");
	}
}

final class SingularityStream : Stream
{
	this()
	{
		super("A black hole", Mode.Write);
	}

	override void writeBytes(const(ubyte)[] bytes)
	{

	}

	override void readBytes(ref ubyte[] bytes)
	{

	}
}

final class StreamException : Exception
{
	this(string msg)
	{
		super(msg);
	}
}