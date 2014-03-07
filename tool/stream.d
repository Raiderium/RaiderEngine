module tool.stream;

import std.stdio;

/**
 * One-way data stream.
 * 
 * TODO Switch to D-style documentation
 */
abstract class Stream
{
	string source;
	private bool _mode;
	private uint _bytes;

	/**
	 * @param source Stream source URL or other description
	 * @param mode If true, stream is for writing. If false, reading.
	 */
	this(string source, bool mode)
	{
		this.source = source;
		_mode = mode;
		_bytes = 0;
	}

	/**
	 * @brief Read or write an array of data, depending on the stream mode.
	 */
	final void work(ref ubyte[] data)
	{
		if(_mode) write(data);
		else
		{
			read(data);
		}
		_bytes += ubyte.sizeof*data.length;
	}

	@property uint bytesWrought() { return _bytes; }
	@property uint bytesWritten() { return _mode ? _bytes : 0; }
	@property uint bytesRead() { return !_mode ? _bytes : 0; }
	@property bool writing() { return _mode; }
	@property bool reading() { return !_mode; }

protected:
	void write(ref ubyte[] data);
	void read(ref ubyte[] data);
}

/**
 * @brief Accesses a file.
 */
final class FileStream : Stream
{
	private File file; //TODO Replace with PhysicsFS for security, compression and archives.
	
	this(string filename, bool mode)
	{
		super(filename, mode);
		file = File(filename, mode ? "wb" : "rb");
	}
	override void write(ref ubyte[] data) { file.rawWrite(data); }
	override void read(ref ubyte[] data) { file.rawRead(data); if(file.eof) throw new Exception("EOF reached."); }
}