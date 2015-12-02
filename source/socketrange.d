/**
 * Input/Output range wrapper for Socket.
 */
module socketrange;

import std.range;
import std.socket;

/**
 * Input range of T
 */
struct SocketInputRange(T) {
	/// ditto
	this(Socket socket) {
		_socket = socket;
	}
	
	private T[1024]  _buf = void;
	private ptrdiff_t _left = -1;
	private ptrdiff_t _right = -1;
	private auto _first = true;
	
	/// Get wrapped socket
	@property Socket socket() {
		return _socket;
	}
	/// ditto
	alias socket this;	
	private Socket _socket;
	
	private auto _empty = false;
	/// Input range
	@property bool empty() const {
		return _empty;
	}
	
	/// ditto
	T front() {
		if (_first) {
			popFront();
			_first = false;
		}
		return _buf[_left];
	}
	
	/// ditto
	void popFront() {
		_left++;
		if (_left >= _right) {
			_right = _socket.receive(_buf);
			assert(_right % T.sizeof == 0);
			_right /= T.sizeof;
			if (_right > 0) {
				_left = 0;
			} else {
				_empty = true;
			}
		}
	}
}
///
unittest {
	static assert(isInputRange!(SocketInputRange!ubyte));
	static assert(is(ElementType!(SocketInputRange!char) == char));

	auto pair = socketPair();
	auto sender = pair[0];
	auto receiver = pair[1];
	
	sender.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"seconds"(10));
	receiver.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"seconds"(10));
	
	sender.send("foo bar"w);
	sender.close();
	
	auto range = SocketInputRange!wchar(receiver);
	
	import std.algorithm;
	assert(equal(range, "foo bar"w));
	
	range.close();
}

/**
 * Output range wrapper
 */
struct SocketOutputRange {
	/// ditto
	this(Socket socket) {
		_socket = socket;
	}
	
	/// Wrapped socket
	@property Socket socket() {
		return _socket;
	}
	/// ditto
	alias socket this;
	private Socket _socket;
	
	/// Output range
	ptrdiff_t put(T)(T data) {
		import std.traits;
		
		static if (isArray!T) {
			return _socket.send(data);
		} else static if (isInputRange!T) {
			return put(data.array);
		} else {
			return put([data]);
		}
	}
}
///
unittest {
	static assert(isOutputRange!(SocketOutputRange, int));
	static assert(isOutputRange!(SocketOutputRange, char));
	
	auto pair = socketPair();
	auto sender = pair[0];
	auto receiver = pair[1];
	
	sender.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"seconds"(10));
	receiver.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"seconds"(10));
	
	auto range = SocketOutputRange(sender);
	
	put(range, 1);
	put(range, 2);
	put(range, 3);
	
	range.close();
	
	import std.algorithm;
	assert(equal(SocketInputRange!int(receiver), [1, 2, 3]));
}

/**
 * Input/Output range of In
 */
struct SocketRange(In, Out = In) {
	import std.traits;
	
	/// ditto
	this(Socket socket) {
		_socket = socket;
		_inputRange = SocketInputRange!In(socket);
		_outputRange = SocketOutputRange(socket);
	}
	
	/// Wrapped socket
	@property auto socket() {
		return _socket;
	}
	private Socket _socket;
	
	/// ditto
	alias socket this;

	/// Input range
	@property auto inputRange() {
		return _inputRange;
	}
	private SocketInputRange!In _inputRange;

	/// ditto
	@property bool empty() const {
		return _inputRange.empty;
	}
	/// ditto
	@property In front() {
		return _inputRange.front;
	}
	/// ditto
	void popFront() {
		_inputRange.popFront();
	}
	
	/// Output range
	@property auto outputRange() {
		return _outputRange;
	}
	private SocketOutputRange _outputRange;
	
	static if (is(Out == void)) {
		/// ditto
		auto put(T...)(T args) {
			return outputRange.put(args);
		}
	} else {
		/// ditto
		auto put(Out value) {
			return outputRange.put(value);
		}
		/// ditto
		auto put(R)(R range) if (!isSomeString!R && isInputRange!R && is(ElementType!R == Out)) {
			return outputRange.put(range);
		}
		/// ditto
		auto put(S)(S str) if (isSomeChar!Out && isSomeString!S) {
			import std.conv;
			return outputRange.put(str.to!(Out[]));
		}
	}
}
///
unittest {
	import std.algorithm;
	
	static assert(isInputRange!(SocketRange!char));
	static assert(isOutputRange!(SocketRange!char, char));
	
	auto pair = socketPair();
	pair[0].setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"seconds"(10));
	pair[1].setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"seconds"(10));
	
	auto range = [
		SocketRange!char(pair[0]),
		SocketRange!char(pair[1]),
		];
	
	range[0].put("foo");
	range[0].close();
	assert(equal(range[1], "foo"));
	
	range[1].put("bar");
	range[1].close();
}