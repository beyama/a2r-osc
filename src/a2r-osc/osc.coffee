# a2r-osc 0.0.1
# http://github.com/beyama/a2r-osc
# (c) 2013 Alexander Jentz, beyama.de
# a2r-osc may be freely distributed under the MIT license.

# Export the a2r-osc functions and classes.
# If we're in the browser, add a2r.osc as a
# global object.
if typeof module is "undefined"
  window.a2r ||= {}
  exports = window.a2r.osc = {}
else
  exports = module.exports

do (exports)->
  # Do we have a Node.js Buffer or are we in a browser?
  nodeBuffer = typeof Buffer is 'function'
  
  # Convert a value to a number and throw an error if value
  # is Not-a-Number.
  toNumber = (val)->
    val = Number(val)
    throw new Error("Value isn't a number") if val is NaN
    val
  
  # Convert a value to a number and round the result.
  toInteger = (val)->
    val = toNumber(val)
    Math.round(val)
  
  # Convert NTP Timestamp to Date and vice versa
  #
  # http://commons.apache.org/net/api-3.2/src-html/org/apache/commons/net/ntp/TimeStamp.html
  SECONDS_FROM_1900_to_1970 = 2208988800
  
  # Get a Date object for seconds and fraction
  fromNTP = (seconds, fraction)->
    # immediately
    return new Date if seconds is 0 and fraction is 1
  
    ms =  (seconds - SECONDS_FROM_1900_to_1970) * 1000
    ms += Math.round(1000 * fraction / 0x100000000)
    date = new Date(ms)
    date.ntpSeconds  = seconds
    date.ntpFraction = fraction
    date
  
  # Get an array with seconds and fraction from JavaScript Date-object.
  toNTP = (date)->
    # special case in OSC, 1 means process immediately
    return [0, 1] if date is 1
    return date if Array.isArray(date)
  
    time     = date.getTime()
    seconds  = Math.floor(time / 1000)
    fraction = Math.round(((time % 1000) * 0x100000000) / 1000)
    [seconds + SECONDS_FROM_1900_to_1970, fraction]
  
  # Type handler
  OSC_TYPES =
    i:
      name:   "integer"
      read:   (reader)-> reader.readInt32()
      write:  (writer, value)-> writer.writeInt32(value)
      cast:   toInteger
      sizeOf: (value)-> 4
    f:
      name:   "float"
      read:   (reader)-> reader.readFloat()
      write:  (writer, value)-> writer.writeFloat(value)
      cast:   toNumber
      sizeOf: (value)-> 4
    s:
      name:   "string"
      read:   (reader)-> reader.readString()
      write:  (writer, value)-> writer.writeString(value)
      cast:   (value) -> value.toString()
      sizeOf: (value)-> oscSizeOfString(value.toString())
    b:
      name:   "blob"
      read:   (reader)-> reader.readBlob()
      write:  (writer, value) -> writer.writeBlob(value)
      sizeOf: (value)-> oscSizeOfBlob(value)
    d:
      name:   "double"
      read:   (reader)-> reader.readDouble()
      write:  (writer, value)-> writer.writeDouble(value)
      sizeOf: (value)-> 8
    c:
      name:   "char"
      read:   (reader)-> String.fromCharCode(reader.readInt32() & 0x7F)
      write:  (writer, value)-> writer.writeInt32(value.charCodeAt(0))
      cast:   (value)-> value.toString().charAt(0)
      sizeOf: (value)-> 4
    r:
      name:   "color"
      read:   (reader)-> reader.readInt32()
      write:  (writer, value)-> writer.writeInt32(value)
      cast:   toInteger
      sizeOf: (value)-> 4
    t:
      name:   "time"
      read:   (reader)-> reader.readTimetag()
      write:  (writer, value)-> writer.writeTimetag(value)
      cast:   (value)->
        return value if value instanceof Date
        new Date(value)
      sizeOf: -> 8
    T:
      name: "true"
      read: -> true
    F:
      name: "false"
      read: -> false
    N:
      name: "null"
      read: -> null
    I:
      name: "impulse"
      read: -> Impulse
  
  OSC_TYPES.S = OSC_TYPES.s
  
  OSC_TYPES_BY_NAME = {}
  
  for code, type of OSC_TYPES
    type.code = code if code isnt 'S'
    OSC_TYPES_BY_NAME[type.name] = type
  
  NUMBERS =
    Int32:
      dataViewReader: "getInt32"
      dataViewWriter: "setInt32"
      bufferReader: "readInt32BE"
      bufferWriter: "writeInt32BE"
      size: 4
    UInt32:
      dataViewReader: "getUint32"
      dataViewWriter: "setUint32"
      bufferReader: "readUInt32BE"
      bufferWriter: "writeUInt32BE"
      size: 4
    Float:
      dataViewReader: "getFloat32"
      dataViewWriter: "setFloat32"
      bufferReader: "readFloatBE"
      bufferWriter: "writeFloatBE"
      size: 4
    Double:
      dataViewReader: "getFloat64"
      dataViewWriter: "setFloat64"
      bufferReader: "readDoubleBE"
      bufferWriter: "writeDoubleBE"
      size: 8
  
  oscPadding = (len)-> (4 - len % 4)
  
  # Impulse, singleton marker object
  Impulse = new Object
  
  # Get type code for supported JavaScript types.
  oscTypeCodeOf = (val)->
    switch typeof val
      when 'string' then 's'
      when 'number' then 'f'
      when 'boolean'
        if val then 'T' else 'F'
      when 'undefined'
        throw new Error("Value can't be undefined")
      when 'object'
        if val is null then 'N'
        else if val instanceof Date then 't'
        else if (nodeBuffer and Buffer.isBuffer(val)) or val instanceof ArrayBuffer then 'b'
        else if val is Impulse then 'I'
        else throw new Error("Unsupported type `#{val}`")
      else throw new Error("Unsupported type `#{val}`")
  
  # Get string length plus padding.
  oscSizeOfString = (str)-> str.length + oscPadding(str.length)
  
  # Get size of buffer plus 4 bytes for length
  # and plus padding.
  oscSizeOfBlob = (buf)->
    if buf instanceof ArrayBuffer
      length = 4 + buf.byteLength
    else
      length = 4 + buf.length
    pad = oscPadding(length)
    length += pad if pad < 4
    length
  
  # Calculate size of bundle.
  oscSizeOfBundle = (bundle, dict)->
    # #bundle string + timetag
    size = 16
    # sizeof elements
    for elem in bundle.elements
      size += 4 + oscSizeOfMessage(elem, dict)
    size
  
  # Calculate size of message
  oscSizeOfMessage = (msg, dict)->
    if dict
      if msg.isPattern()
        id = dict.getPatternId(msg.address)
      else
        id = dict.getAddressId(msg.address)
    
    # sizeof address
    if id
      # 4 byte for '/' or '/?' and 4 byte for integer id
      size = 8
    else
      # size of osc string
      size = oscSizeOfString(msg.address)
    # sizeof typeTag
    if id
      # typeTag + ',' and 'i' for addressId
      tl = msg.typeTag.length + 2
    else
      # typeTag + ','
      tl = msg.typeTag.length + 1
    size += tl + oscPadding(tl)
  
    # sizeof arguments data
    i = 0
    l = msg.typeTag.length
    while i < l
      typeCode = msg.typeTag.charAt(i)
      value = msg.arguments[i++]
      size += oscSizeOf(value, typeCode)
    size
  
  # Get size of every supported type including
  # message and bundle.
  oscSizeOf = (value, code)->
    if code
      type = OSC_TYPES[code] || OSC_TYPES_BY_NAME[code]
      unless type
        throw new Error("Type `#{code}` isn't supported")
  
      return 0 unless type.sizeOf
  
      type.sizeOf(value)
    else
      code = oscTypeCodeOf(value)
      oscSizeOf(value, code)

  # A simple dictionary class to work with compressed
  # address- / pattern strings.
  class Dictionary
    # The constructor takes an optional
    # id-to-address map and/or an optional
    # id-to-pattern map.
    constructor: (addressMap, patternMap)->
      @idToAddress = {}
      @addressToId = {}
      @idToPattern = {}
      @patternToId = {}

      if addressMap
        for id, address of addressMap
          @addAddress(id, address)
      if patternMap
        for id, pattern of patternMap
          @addPattern(id, pattern)

    # Add an address to the dictionary
    addAddress: (id, address)->
      @idToAddress[id] = address
      @addressToId[address] = Number(id)

    # Get address by id
    getAddress: (id)-> @idToAddress[id]

    # Get id by address
    getAddressId: (addr)-> @addressToId[addr]

    # Remove an address mapping by
    # id or address string
    removeAddress: (idOrAddress)->
      if typeof idOrAddress is "number"
        id = idOrAddress
        address = @idToAddress[id]
      else
        address = idOrAddress
        id = @addressToId[address]

      delete @idToAddress[id]
      delete @addressToId[address]

    # Add an pattern to the dictionary
    addPattern: (id, pattern)->
      @idToPattern[id] = pattern
      @patternToId[pattern] = Number(id)

    # Get pattern by id
    getPattern: (id)-> @idToPattern[id]

    # Get id by pattern
    getPatternId: (pattern)-> @patternToId[pattern]

    # Remove a pattern mapping by
    # id or pattern
    removePattern: (idOrPattern)->
      if typeof idOrPattern is "number"
        id = idOrPattern
        pattern = @idToPattern[id]
      else
        pattern = idOrPattern
        id = @patternToId[pattern]

      delete @idToPattern[id]
      delete @patternToId[pattern]
  
  # Class for representing a message.
  class Message
    constructor: (address, typeTag, args)->
      # copy constructor
      if address instanceof Message
        msg = address
        @address   = msg.address
        @typeTag   = msg.typeTag
        @arguments = msg.arguments[..]
        return
      # else
      @address   = address
      @arguments = []
  
      if typeTag isnt undefined and args is undefined
        args    = typeTag
        typeTag = null
  
      return if args is undefined
  
      args = [args] unless Array.isArray(args)
  
      if typeTag
        # check for consistent lengths of arguments and type tag
        if args.length isnt typeTag.length
          throw new Error("Arguments length doesn't match typetag length")
  
        for arg, i in args
          @add(typeTag.charAt(i), arg)
      else
        for value in args
          code = null
  
          if typeof value is 'object' and value?.type?
            type = value.type
            type = OSC_TYPES[type] || OSC_TYPES_BY_NAME[type]
            code = type.code
            throw new Error("Unsupported type `#{code}`") unless type
  
            # Types without argument data have no sizeOf method
            # and return their values on read.
            value = if type.sizeOf then value.value else type.read()
  
          if code
            @add(code, value)
          else
            @add(value)

    # Clone this message
    clone: -> new Message(@)

    isPattern: ->
      return @_isPattern if @_isPattern?

      @_isPattern = /(?:\*|\?|\[|\{|\/\/)/.test(@address)
  
    # Add a value to the arguments list
    add: (code, value)->
      if value is undefined
        value = code
        code  = null
  
      if code
        type = OSC_TYPES[code] || OSC_TYPES_BY_NAME[code]
        throw new Error("Unsupported type `#{code}`") unless type
        value = type.cast(value) if type.cast
      else
        code = oscTypeCodeOf(value)
        type = OSC_TYPES[code]
  
      @arguments.push(value)
  
      if @typeTag
        @typeTag += code
      else
        @typeTag = code
      @
  
    # Convenience method, creates an OSC packet generator,
    # generates a packet and returns the buffer.
    toBuffer: (dict)->
      if nodeBuffer
        new OscBufferPacketGenerator(@, dict).generate()
      else
        new OscArrayBufferPacketGenerator(@, dict).generate()
  
    equal: (other)->
      return false unless other instanceof Message
      return false if other.address isnt @address
      return false if other.typeTag isnt @typeTag
      return false if other.arguments.length isnt @arguments.length
      for arg, i in @arguments when other.arguments[i] isnt arg
        return false
      true
  
  # Class for representing a bundle.
  class Bundle
    constructor: (timetag, elements)->
      # copy constructor
      if timetag instanceof Bundle
        bundle = timetag
        @timetag = new Date(bundle.timetag.valueOf())
        @elements = []
        for elem in bundle.elements
          @addElement(elem.clone())

        return
      # else
      if timetag instanceof Date
        @timetag = timetag
      else if timetag is 1
        @timetag = new Date
      else
        @timetag = new Date
        elements = timetag
  
      @elements = []
      if elements
        if Array.isArray(elements)
          @addElement(elem) for elem in elements
        else
          @addElement(elements)

    # Clone this bundle
    clone: -> new Bundle(@)
  
    # Add a message to elements list and return the message.
    addElement: (address, typeTag, args)->
      if address instanceof Message
        @elements.push address
        address
      else if typeof address is "string"
        msg = new Message(address, typeTag, args)
        @elements.push msg
        msg
      else
        throw new Error("A bundle element must be an instance of Message")
  
    # Add a message to elements list and returns self (for chaining).
    add: (address, typeTag, args)->
      @addElement(address, typeTag, args)
      @
  
    # Convenience method, creates an instance of OscPacketGenerator,
    # generates packet and returns the buffer.
    toBuffer: (dict)->
      if nodeBuffer
        new OscBufferPacketGenerator(@, dict).generate()
      else
        new OscArrayBufferPacketGenerator(@, dict).generate()
  
    # Returns true if this bundle is equal to another bundle otherwise returns false.
    equal: (other)->
      return false unless other instanceof Bundle
      return false if other.timetag isnt @timetag
      return false if other.elements.length isnt @elements.length
      for elem, i in @elements when not elem.equal(other.elements[i])
        return false
      true
  
  # The abstract OSC packet generator
  class AbstractOscPacketGenerator
    constructor: (messageOrBundle, dict)->
      @dict = dict
  
      if messageOrBundle instanceof Bundle
        @bundle = messageOrBundle
        @size = oscSizeOfBundle(@bundle, @dict)
      else
        @message = messageOrBundle
        @size = oscSizeOfMessage(@message, @dict)
  
    _generateMessage: (msg)->
      # compress if possible
      if @dict
        id = if msg.isPattern()
          @dict.getPatternId(msg.address)
        else
          @dict.getAddressId(msg.address)

      if id
        if msg.isPattern()
          @writeString("/?")
        else
          @writeString("/")

        @writeString(",i#{msg.typeTag}")
        @writeInt32(toInteger(id))
      else
        @writeString(msg.address)
        @writeString(",#{msg.typeTag}")
  
      i = 0
      l = msg.typeTag.length
      while i < l
        code  = msg.typeTag.charAt(i)
        value = msg.arguments[i++]
  
        # get type handler
        type = OSC_TYPES[code]
  
        unless type
          throw new Error("Type `#{code}` isn't supported")
  
        if type.write
          type.write(@, value)
  
    _generateBundle: (bundle)->
      # bundle-id
      @writeString("#bundle")
      # timetag
      if bundle.timetag <= new Date
        tag = [0, 1]
      else
        tag = toNTP(bundle.timetag)
      @writeTimetag(tag)
      # generate elements
      for elem in bundle.elements
        @writeInt32(oscSizeOfMessage(elem, @dict))
        @_generateMessage(elem)
      null
  
    # Write a timetag to the underlying buffer.
    writeTimetag: (date)->
      tag = toNTP(date)
      @writeUInt32(tag[0])
      @writeUInt32(tag[1])
  
    # Generate a package and return the buffer
    # object
    generate: ->
      if @bundle
        @_generateBundle(@bundle)
      else
        @_generateMessage(@message)
      @buffer
  
    writeString: (string, encoding="ascii")->
      throw new Error("Abstract method `AbstractOscPacketGenerator::writeString` called")
  
  for name, desc of NUMBERS
    do (name)->
      name = "write#{name}"
      AbstractOscPacketGenerator::[name] = ->
        throw new Error("Abstract method `AbstractOscPacketGenerator::#{name}` called")
  
  # OSC packet generator which generates ArrayBuffer
  class OscArrayBufferPacketGenerator extends AbstractOscPacketGenerator
    constructor: (messageOrBundle, dict)->
      super(messageOrBundle, dict)
      @buffer = new ArrayBuffer(@size)
      @view = new DataView(@buffer)
      @pos = 0
  
    # Write a string to the underlying buffer.
    writeString: (string, encoding="ascii")->
      if encoding isnt "ascii"
        throw new Error("OscBufferWriter::writeString only supports ASCII encoding for ArrayBuffer")
  
      # copy string content to ArrayBuffer
      l = string.length
      i = 0
      while i < l
        char = string.charCodeAt(i++)
        @view.setInt8(@pos++, char & 0x7F)
      pad = oscPadding(l)
  
      # append 0-padding
      i = 0
      while i < pad
        @view.setInt8(@pos++, 0)
        i++
  
    # Write a blob to the underlying ArrayBuffer.
    writeBlob: (buffer)->
      # if buffer is a node buffer
      if nodeBuffer and Buffer.isBuffer(buffer)
        l = buffer.length
        @writeInt32(l)
        i = 0
        while i < l
          @view.setInt8(@pos + i, buffer[i])
          i++
        @pos += l
      # it's an ArrayBuffer
      else
        l = buffer.byteLength
        array = new Int8Array(buffer)
        @writeInt32(l)
        i = 0
        while i < l
          @view.setInt8(@pos + i, array[i])
          i++
        @pos += l
  
      # add padding
      pad = oscPadding(4 + l)
      if pad and pad < 4
        i = 0
        while i < pad
          @view.setInt8(@pos + i, 0)
          i++
        @pos += pad
  
  # Generate writer methods 
  # for Int32, UInt32, Float, Double.
  for type, desc of NUMBERS
    do(type, desc)->
      OscArrayBufferPacketGenerator::["write#{type}"] = (value)->
        value = @view[desc.dataViewWriter](@pos, value, false)
        @pos += desc.size
        value
#only_node

  # OSC packet generator which generates node buffer
  class OscBufferPacketGenerator extends AbstractOscPacketGenerator
    constructor: (messageOrBundle, dict)->
      super(messageOrBundle, dict)
      @buffer = new Buffer(@size)
      @pos = 0
  
    # Write a string to the underlying buffer.
    writeString: (string, encoding="ascii")->
      length = Buffer.byteLength(string, encoding)
      @buffer.write(string, @pos, length, encoding)
      @pos += length
  
      pad = oscPadding(length)
      @buffer.fill(0, @pos, @pos + pad)
      @pos += pad
  
    # Write a blob to the underlying buffer.
    writeBlob: (buffer)->
      # copy content from an ArrayBuffer to the underlying buffer
      if buffer instanceof ArrayBuffer
        length = buffer.byteLength
        @writeInt32(length)
        array = new Int8Array(buffer)
        i = 0
        while i < length
          @buffer[@pos + i] = array[i]
          i++
      # copy content from a node buffer to the underlying buffer
      else
        length = buffer.length
        @writeInt32(length)
        buffer.copy(@buffer, @pos)
  
      pad = oscPadding(4 + length)
      @pos += length
      if pad and pad < 4
        @buffer.fill(0, @pos, @pos + pad)
        @pos += pad
  
  # Generate writer methods 
  # for Int32, UInt32, Float, Double.
  for type, desc of NUMBERS
    do(type, desc)->
      OscBufferPacketGenerator::["write#{type}"] = (value)->
        value = @buffer[desc.bufferWriter](value, @pos)
        @pos += desc.size
        value

#end_only_node
  
  # The abstract osc packet parser
  class AbstractOscPacketParser
    constructor: (buffer, pos=0, dict)->
      @buffer = buffer
      if typeof pos is "object"
        @dict = pos
        @pos = 0
      else
        @dict = dict
        @pos = pos
  
    parse: ->
      address = @readString()
      if address is "#bundle"
        @_parseBundle()
      else
        @_parseMessage(address)
  
    _parseMessage: (address)->
      if address.charAt(0) isnt '/'
        throw new Error("An address must start with a '/'")
       
      if @dict and ((isAddress = address is "/") or address is "/?") # compressed address
        typeTag = @readTypeTag()
        args = @parseArguments(typeTag)
        # check for integer as first type
        if typeTag.charAt(0) is "i"
          # resolve address or pattern string
          id = args[0]

          # resolve address or pattern
          address = if isAddress
            @dict.getAddress(id)
          else
            @dict.getPattern(id)

          if address
            # slice type tag
            typeTag = typeTag[1..0]
            # remove address id
            args.shift()
      else
        typeTag = @readTypeTag()
        args    = @parseArguments(typeTag)
  
      new Message(address, typeTag, args)
  
    _parseBundle: ->
      timetag  = @readTimetag()
      elements = []
  
      while not @isEnd()
        size     = @readInt32()
        # TODO: Do something useful with the boundary
        boundary = @pos + size
        elements.push(@parse())
  
      new Bundle(timetag, elements)
  
    # Read all values declared in `tag` from
    # the underlying buffer.
    #
    # tag: The type tag.
    # boundary: The boundary of the message, used for bundles.
    parseArguments: (tag, boundary)->
      i = 0
  
      values = []
  
      while i < tag.length
        if boundary and @pos >= boundary
          throw new Error("Message boundary reached")
  
        code = tag.charAt(i++)
  
        # get type handler
        type = OSC_TYPES[code]
  
        unless type
          throw new Error("Type `#{code}` isn't supported")
  
        # read value and add to values list
        values.push type.read(@)
  
      values
  
    readTypeTag: ->
      tag = @readString()
      if tag.charAt(0) is ','
        tag = tag[1..-1]
      else
        throw new Error("A type tag must start with a ','")
      tag
  
    # read timetag and convert it to Date
    readTimetag: -> fromNTP(@readUInt32(), @readUInt32())
  
    # Read a string from the underlying buffer.
    #
    # The implementing class must support ASCII encoding.
    readString: (encoding, move)->
      throw new Error("Abstract method `AbstractOscPacketParser::writeString` called")
  
    # data left?
    isEnd: ->
      throw new Error("Abstract method `AbstractOscPacketParser::isEnd` called")
  
  for name, desc of NUMBERS
    do (name)->
      name = "read#{name}"
      AbstractOscPacketParser::[name] = ->
        throw new Error("Abstract method `AbstractOscPacketParser::#{name}` called")
  
  # OSC packet parser which operates on ArrayBuffer.
  class OscArrayBufferPacketParser extends AbstractOscPacketParser
    constructor: (buffer, pos, dict)->
      super
      @view = new DataView(@buffer)
  
    # bytes left?
    isEnd: ->
      @buffer.byteLength is 0 or @pos is @buffer.byteLength
  
    toString: (encoding, start, end)->
      start = start ? 0
      end = end ? @buffer.byteLength
      str = ""
      while start < end
        charCode = @view.getInt8(start++)
        str += String.fromCharCode(charCode & 0x7F)
      str
  
    # Read a blob from the underlying buffer.
    readBlob: (move=true)->
      # get size of blob
      size = @readInt32()
  
      i = 0
      array = new Int8Array(new ArrayBuffer(size))
      # copy buffer
      while i < size
        array[i] = @view.getInt8(@pos+i)
        i++
  
      if move
        # total bits must be a multiple of 32bits
        pad = oscPadding(4 + size)
        size += pad if pad < 4
  
        @pos += size
      array.buffer
  
    # Read a string from the underlying buffer
    readString: (encoding="ascii", move=true)->
      throw new Error("No data left") if @isEnd()
  
      length = 4
      nullSeen = false
  
      while (pos = @pos + length - 1) < @buffer.byteLength
        if @view.getInt8(pos) is 0
          nullSeen = true
          break
        length += 4
  
      if length is 0 or nullSeen is false
        throw new Error("No string data found")
  
      # length of string without null-bytes
      stringLength = length - 4
      while stringLength < length
        if @view.getInt8(@pos + stringLength) is 0
          break
        stringLength++
  
      string = @toString(encoding, @pos, @pos + stringLength)
      @pos += length if move
      string
  
  # Generate reader methods 
  # for Int32, UInt32, Float, Double.
  for type, desc of NUMBERS
    do(type, desc)->
      OscArrayBufferPacketParser::["read#{type}"] = (move=true)->
        value = @view[desc.dataViewReader](@pos, false)
        @pos += desc.size if move
        value
  
#only_node

  # OSC packet parser which operates on node buffer.
  class OscBufferPacketParser extends AbstractOscPacketParser
    constructor: (buffer, pos, dict)->
      super
  
    # bytes left?
    isEnd: ->
      @buffer.length is 0 or @pos is @buffer.length
  
    toString: -> @buffer.toString.apply(@buffer, arguments)
  
    # Read a blob from the underlying buffer.
    readBlob: (move=true)->
      # get size of blob
      size = @readInt32()
  
      # create new buffer
      buf = new Buffer(size)
      # copy content to the new buffer
      @buffer.copy(buf, 0, @pos, @pos + size)
  
      if move
        # total bits must be a multiple of 32bits
        pad = oscPadding(4 + size)
        size += pad if pad < 4
  
        @pos += size
      buf
  
    # Read a string from the underlying buffer
    readString: (encoding="ascii", move=true)->
      throw new Error("No data left") if @isEnd()
  
      length = 4
      nullSeen = false
  
      while (pos = @pos + length - 1) < @buffer.length
        if @buffer[pos] is 0
          nullSeen = true
          break
        length += 4
  
      if length is 0 or nullSeen is false
        throw new Error("No string data found")
  
      # length of string without null-bytes
      stringLength = length - 4
      while stringLength < length
        if @buffer[@pos + stringLength] is 0
          break
        stringLength++
  
      string = @toString(encoding, @pos, @pos + stringLength)
      @pos += length if move
      string
  
  # Generate reader methods 
  # for Int32, UInt32, Float, Double.
  for type, desc of NUMBERS
    do(type, desc)->
      OscBufferPacketParser::["read#{type}"] = (move=true)->
        value = @buffer[desc.bufferReader](@pos)
        @pos += desc.size if move
        value

#end_only_node
  
  # Takes a Node.js Buffer- or an ArrayBuffer-object and returns either a osc.Message or oscBundle, 
  # or throws an Error if the buffer isn't well-formed.
  # 
  # The optional dictionary is for compressed address string support (see below).
  fromBuffer = (buffer, pos, dict)->
    if nodeBuffer and Buffer.isBuffer(buffer)
      new OscBufferPacketParser(buffer, pos, dict).parse()
    else
      new OscArrayBufferPacketParser(buffer, pos, dict).parse()
  
  exports.NUMBERS    = NUMBERS
  exports.toNTP      = toNTP
  exports.Message    = Message
  exports.Bundle     = Bundle
  exports.Impulse    = Impulse
  exports.Dictionary = Dictionary

  exports.AbstractOscPacketGenerator = AbstractOscPacketGenerator
  exports.AbstractOscPacketParser    = AbstractOscPacketParser
#only_node
  exports.OscBufferPacketGenerator = OscBufferPacketGenerator
  exports.OscBufferPacketParser    = OscBufferPacketParser
#end_only_node
  exports.OscArrayBufferPacketGenerator = OscArrayBufferPacketGenerator
  exports.OscArrayBufferPacketParser    = OscArrayBufferPacketParser
  exports.fromBuffer = fromBuffer
