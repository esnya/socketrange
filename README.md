# socketrange [![Build Status](https://travis-ci.org/ukatama/socketrange.svg)](https://travis-ci.org/ukatama/socketrange)
Minimal range wrapper of socket for D.

## Usage
```d
import std.algorithm : equal;
import std.socket : socketPair;
import socketrange;

void main() {
  auto pair = socketPair();
  
  /// Wrap as OutputRange
  auto writer = SocketOutputRange(pair[0]);
  
  /// Wrap as InputRange of char
  auto reader = SocketInputRange!char(pair[1]);
  
  write.put("foobar");
  writer.close();
  
  assert(equal(reader, "foobar"));
}
```

### `struct SocketOutputRange`
Wrap socket as OutputRange.

### `struct SocketInputRange(T)`
Wrap socket as InputRange of T.

### `struct SocketRange(In, Out = In)`
Wrap socket as Output/InputRange of In.
`Out` can be `void` to put any types.
