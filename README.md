# socketrange [![Build Status](https://img.shields.io/travis/ukatama/socketrange/master.svg?style=flat-square)](https://travis-ci.org/ukatama/socketrange)
Simple range wrapper of socket for D.

## Usage
```d
import std.algorithm : equal;
import std.socket : socketPair;
import socketrange;

void main() {
  auto pair = socketPair();
  
  /// Wrap as OutputRange
  auto writer = SocketOutputRange!char(pair[0]);
  
  /// Wrap as InputRange of char
  auto reader = SocketInputRange!char(pair[1]);
  
  write.put("foobar");
  writer.close();
  
  assert(equal(reader, "foobar"));
}
```

### `struct SocketOutputRange(E)`
Wrap socket as OutputRange of `E`.
`E` can be `void` to put any types.

### `struct SocketInputRange(T)`
Wrap socket as InputRange of `T`.

### `struct SocketRange(In, Out = In)`
Wrap socket as Output/InputRange of In.
`Out` can be `void` to put any types.
