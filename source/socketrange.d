/**
 * Input/Output range wrapper for Socket.
 */
module socketrange;

import std.range;
import std.socket;
import std.traits;

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
	private Socket _socket;
	
	/// Close socket
	void close() {
		_socket.close();
	}
	
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
	import std.datetime : dur;

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
struct SocketOutputRange(E = void) {
	/// ditto
	this(Socket socket) {
		_socket = socket;
	}
	
	/// Wrapped socket
	@property Socket socket() {
		return _socket;
	}
	private Socket _socket;
	
	/// Close socket
	void close() {
		_socket.close();
	}
	
    static if (is(E == void)) {
        /// Output range
        ptrdiff_t put(T)(T data) {
            static if (isArray!T) {
                return _socket.send(data);
            } else static if (isInputRange!T) {
                return put(data.array);
            } else {
                return put([data]);
            }
        }
    } else {
        /// Output range
        ptrdiff_t put(E e) {
            return put([e]);
        }
        /// ditto
        ptrdiff_t put(R)(R range) if (isInputRange!R && !isArray!R && is(ElementType!R == E)) {
            return put(range.array);
        }
        /// ditto
        ptrdiff_t put(E[] a) {
            return _socket.send(a);
        }

        static if (isSomeChar!E && !is(E == dchar)) {
            import std.utf;
            
            static if (is(typeof(byUTF!E(only(E.init))))) {
                /// Send encoded string
                ptrdiff_t put(dchar c) {
                    E[4 / E.sizeof] buf;
                    auto len = encode(buf, c);
                    return put(buf[0 .. len]);
                }
                /// ditto
                ptrdiff_t put(S)(S range) if (isInputRange!S && is(ElementType!S == dchar)) {
                    return put(range.byUTF!E);
                }
            } else {
                pragma(msg, "[WARNING]: std.utf.byUTF is required to use encoded string sender of SocketOutputRange");  
            }
        }
    }
}
///
unittest {
	import std.datetime : dur;

	static assert(isOutputRange!(SocketOutputRange!void, int));
	static assert(isOutputRange!(SocketOutputRange!char, char));
	
	auto pair = socketPair();
	auto sender = pair[0];
	auto receiver = pair[1];
	
	sender.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"seconds"(10));
	receiver.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"seconds"(10));
	
	auto range = SocketOutputRange!int(sender);
	
	put(range, 1);
	put(range, 2);
	put(range, 3);
	
	range.close();
	
	import std.algorithm;
	assert(equal(SocketInputRange!int(receiver), [1, 2, 3]));
}
///
unittest {
	import std.datetime : dur;
    import std.utf;

    static if (is(typeof(byUTF!char(""d)))) {
        auto pair = socketPair();
        auto sender = pair[0];
        auto receiver = pair[1];

        sender.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"seconds"(10));
        receiver.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"seconds"(10));

        auto range = SocketOutputRange!wchar(sender);

        auto data = only("foo", "bar").join(" ");
        static assert(is(ElementType!(typeof(data)) == dchar));

        range.put(data);
        range.close();

        assert(SocketInputRange!wchar(receiver).array == "foo bar"w);
    } else {
        pragma(msg, "[WARNING]: std.utf.byUTF is required to use encoded string sender of SocketOutputRange");
    }
}

/**
 * Input/Output range of In
 */
struct SocketRange(In, Out = In) {
	/// ditto
	this(Socket socket) {
		_socket = socket;
		_inputRange = SocketInputRange!In(socket);
		_outputRange = SocketOutputRange!Out(socket);
	}
	
	/// Wrapped socket
	@property auto socket() {
		return _socket;
	}
	private Socket _socket;
	
	/// Close socket
	void close() {
		_socket.close();
	}

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
	private SocketOutputRange!Out _outputRange;
	
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
	import std.datetime : dur;
	
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