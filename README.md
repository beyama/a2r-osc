# Addicted2Random OSC

A2R OSC is an Open Sound Control implementation for Node.js and the browser.
It implements the OSC 1.1 specification and supports compressed address strings [(smc2011)](http://www.acoustics.hut.fi/publications/papers/smc2011-osc/)

This project was created as part of the [Addicted2Random](http://www.addicted2random.eu/) project.

## Example

``` coffee
sock = udp.createSocket "udp4", (data, rinfo) ->
  try
    message = osc.fromBuffer(data)
    doSomethingUseful message, (err, reply)->
      if err
        res = new osc.Message("/error", message.address, err.message)
      else
        res = new osc.Message("/reply", message.address, reply)

      buffer = res.toBuffer()
      sock.send(buffer, 0, buffer.length, outport, rinfo.address)
  catch error
    console.log "error parsing data"
    console.log error.stack

sock.bind 5000
```

## Supported OSC data types

The following types are supported by A2R-OSC:

* i: 32Bit integer, given floats will be rounded
* f: 32Bit float, the default assumption for JavaScript numbers
* s: An ASCII string, the default assumption for JavaScript strings
* b: A blob, must be either an ArrayBuffer or a Node Buffer
* d: A 64Bit double, represented as a JavaScript number
* c: An ASCII character, packed as 32Bit integer, represented as a string with a length of 1
* r: RGB color, packed as 32Bit integer, represented as JavaScript number
* t: A NTP timetag, packed as 64Bit NTP timetag, represented as JavaScript date
* T: A boolean true
* F: A boolean false
* N: A null
* I: An Impulse or bang, represented as osc.Impulse (a singleton marker object)

## API

### osc.Message class

Represents an OSC message.

#### Properties:

* address: The OSC address string
* typetag: The OSC type tag without leading ','-character
* arguments: Array of arguments

#### constructor(address, [typeTag], [arguments])

Takes an OSC address, an optional type tag and an optional (array of) argument(s).

##### Examples

``` coffee
new osc.Message("/a2r/mima/1/xy", "ii", [123, 456])
new osc.Message("/a2r/mima/1/metro", osc.Impulse)
new osc.Message("/a2r/mima/1/adsr", [50, 12, 8, 4])
new osc.Message("/a2r/mima/1/adsr", [{ type: "i", value: 50 }, ...])
```

#### clone()

This returns a copy of the message without cloning each argument.

#### add(code, [value])

Add a value to the arguments list. If called with two arguments, the first
argument will be treated as type code.

Returns itself for chaining.

##### Examples

``` coffee
new Message("/a2r/mima")
  .add("foo")
  .add("i", 45)
  .add("integer", 83)
```

#### toBuffer([dictionary])

Generates and returns a Buffer on Node.js or an ArrayBuffer in the browser.

The optional dictionary is for compressed address string support (see below).

#### equal(other)

Compare this message to another message. Returns true if equal otherwise returns false.

### osc.Bundle class

Represents an OSC bundle.

#### Properties:

* timetag: The timetag either 1 for immediately or a JavaScript data object
* elements: Array of messages

#### constructor(date, [elements])

Takes a date object and an optional list of bundle elements.

##### Example

``` coffee
new osc.Bundle(new Date, [new osc.Message("/a2r/endpoint", osc.Impulse)])
```

#### clone()

This returns a copy of the bundle and a clone of each message in the elements list.

#### addElement(address, [typeTag], [args])

Adds a message to the elements list. Takes either an instance of osc.Message or arguments
to create an instance of osc.Message (see Message constructor).

Returns the message added to the elements list.

##### Example

``` coffee
bundle.addElement("/a2r/endpoint", osc.Impulse)
```

#### add(address, [typeTag], [args])

Same as Bundle::addElement but returns itself for chaining.

``` coffee
new osc.Bundle(new Date)
  .add("/a2r/mima/1/a", 23)
  .add("/a2r/mima/2/b", 78.9)
```

#### toBuffer([dictionary])

Generates and returns a Buffer on Node.js or an ArrayBuffer in the browser.

The optional dictionary is for compressed address string support (see below).

#### equal(other)

Compare this bundle to another bundle. Returns true if equal otherwise returns false.

### osc.fromBuffer(buffer, [dictionary]) 

Takes a Node.js Buffer- or an ArrayBuffer-object and returns either an osc.Message or osc.Bundle, 
or throws an error if the buffer isn't well-formed.

The optional dictionary is for compressed address string support (see below).

### osc.UnpackStream and osc.PackStream (only for Node.js)

The class osc.UnpackStream implements Nodes writable stream interface,
osc.PackStream implements the readable stream interface.

Both stream classes take an optional dictionary as first argument to handle
compressed address strings (see below).

#### Example

A TCP OSC server utilizing (node-a2r-slip)[http://github.com/beyama/node-a2r-slip].

``` coffee
server = net.createServer (socket)->
  # Create stream for incoming data.
  #
  # incoming package -> SLIP decoder -> OSC unpack stream
  #
  # create OSC unpack stream
  oscUnpackStream = new osc.UnpackStream()
  # handle message event of unpack stream
  oscUnpackStream.on("message", (message)-> doSomethingUseful(message))
  # create SLIP decoder to decode incoming data
  slipDecoder = new slip.SlipDecoder()
  # pipe encoded data to unpack stream
  slipDecoder.pipe(oscUnpackStream)
  # pipe socket to SLIP decoder
  socket.pipe(slipDecoder)

  # Create stream for outgoing data.
  #
  # message -> OSC pack stream -> SLIP encoder
  #
  # create SLIP encoder to encode outgoing data
  slipEncoder = new slip.SlipEncoder()
  # pipe SLIP encoded data to socket
  slipEncoder.pipe(socket)
  # create OSC pack stream
  oscPackStream = new osc.PackStream()
  # pipe packed data to SLIP endoder
  oscPackStream.pipe(slipEncoder)

  oscPackStream.send(new osc.Message("/osc/hello", osc.Impulse))

server.listen(5000)
```

### osc.Dictionary class

A simple dictionary class to map ids to addresses and patterns and vice versa. This is used for compressed address
string support (see below).

#### constructors([idToAddressMap], [idToPatternMap])

Takes an optional id-to-address and/or id-to-pattern object.

##### Example

``` coffee
new osc.Dictionary(1: "/asr", 2: "/a2r/osc")
```

#### addAddress(id, address) and addPattern(id, pattern)

Add an id-to-address respectively an id-to-pattern mapping to the dictionary.

### getAddress(id) and getPattern(id)

Get an address respectively a pattern by id from the dictionary.

If you like to provide your own implementation of a dictionary than you have to implement these methods. 

### getAddressId(address) and getPatternId(pattern)

Get an id by address respectively pattern from the dictionary.

If you like to provide your own implementation of a dictionary than you have to implement these methods. 

### removeAddress(idOrAddress) and removePattern(idOrPattern)

Remove an address respectively an pattern by id or string from the dictionary.

## Packed address strings

Compressed address strings are a way to improve the efficiency of the OSC communication protocol.

Basically, both sides of a communication have to know a (sub-) set of accessible OSC endpoints of the counter
side and each endpoint has to have a known unique integer id. Instead of sending a whole OSC address or pattern again and again,
the sender uses the special address '/' for addresses or '/?' for patterns and the integer id of the endpoint or
the id of the pattern as first argument of the message.

For example: a message with an address like "/session/instrument/adsr" (24 bytes + 4 bytes padding) will be sent
with address "/" (1 byte + 3 bytes padding) and the integer id (4 bytes) as first argument.

A2R-OSC can handle this internally by providing a dictionary (see above) to its 'toBuffer' and 'fromBuffer' methods
or to the constructors of the both stream classes.

## How to contribute

If you find what looks like a bug:

Check the GitHub issue tracker to see if anyone else has reported an issue.

If you don't see anything, create an issue with information about how to reproduce it.

If you want to contribute an enhancement or a fix:

Fork the project on github.

Make your changes with tests.

Commit the changes without making changes to any files that aren’t related to your enhancement or fix.

Send a pull request.

## License

Created by [Alexander Jentz](http://beyama.de), Germany.

MIT License. See the included LICENSE file.
