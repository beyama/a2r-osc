# Node.js or Browser?
nodeBuffer = typeof Buffer is 'function'

toNumber = (val)->
  val = Number(val)
  throw new Error("Value isn't a number") if val is NaN
  val

toInteger = (val)->
  val = toNumber(val)
  Math.round(val)

# Convert NTP Timestamp to Date and vice versa
# http://commons.apache.org/net/api-3.2/src-html/org/apache/commons/net/ntp/TimeStamp.html
SECONDS_FROM_1900_to_1970 = 2208988800

fromNTP = (seconds, fraction)->
  # immediately
  return new Date if seconds is 0 and fraction is 1

  ms =  (seconds - SECONDS_FROM_1900_to_1970) * 1000
  ms += Math.round(1000 * fraction / 0x100000000)
  date = new Date(ms)
  date.ntpSeconds  = seconds
  date.ntpFraction = fraction
  date

toNTP = (date)->
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
    cast:   toNTP
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

# Impules, singleton marker object
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
  addressId = dict?[msg.address]
  
  # sizeof address
  if addressId
    # 4 byte for '/' and 4 byte for addressId
    size = 8
  else
    # size of osc string
    size = oscSizeOfString(msg.address)
  # sizeof typeTag
  if addressId
    # typeTag + ';' and 'i' for addressId
    tl = msg.typeTag.length + 2
  else
    # typeTag + ';'
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

# Class for representing a message.
class Message
  constructor: (address, typeTag, args)->
    @address = address

    if typeTag and not args?
      args    = typeTag
      typeTag = null

    args = [args] unless Array.isArray(args)

    # if type tag is given
    if typeTag
      @typeTag = typeTag
      @arguments = args
    # else generate type tag
    else
      @typeTag = ""
      @arguments = for value in args
        if typeof value is 'object' and value?.type?
          code = value.type
          type = OSC_TYPES[code] || OSC_TYPES_BY_NAME[code]
          unless type
            throw new Error("Type `#{code}` isn't supported")

          @typeTag += type.code

          # Types without argument data have no sizeOf method
          # and return their values on read.
          if type.sizeOf then value.value else type.read()
        else
          @typeTag += oscTypeCodeOf(value)
          value

    # check for consistent lengths of arguments and type tag
    if @arguments.length isnt @typeTag.length
      throw new Error("Arguments doesn't match typetag")

  # Convenience method, creates an instance of OscPacketGenerator,
  # generates packet and returns the buffer.
  toBuffer: (dict)->
    new OscPacketGenerator(@, dict).generate()

# Class for representing a bundle.
class Bundle
  constructor: (timetag, elements)->
    @timetag = timetag
    if elements
      elements = [elements] unless Array.isArray(elements)
      @elements = elements
    else
      @elements = []

  # Add a message to elements list and return the message.
  addElement: (address, typeTag, args)->
    if address instanceof Message
      @elements.push address
      address
    else
      msg = new Message(address, typeTag, args)
      @elements.push msg
      msg

  # Add a message to elements list and returns self (for chaining).
  message: (address, typeTag, args)->
    @addElement(address, typeTag, args)
    @

  # Convenience method, creates an instance of OscPacketGenerator,
  # generates packet and returns the buffer.
  toBuffer: (dict)->
    new OscPacketGenerator(@, dict).generate()

# Buffer read-access layer
class OscBufferReader
  constructor: (buffer, pos=0)->
    @buffer = buffer
    if buffer instanceof ArrayBuffer
      @view = new DataView(@buffer)
    @pos = pos

  # bytes left?
  isEnd: ->
    if @view
      @buffer.byteLength is 0 or @pos is @buffer.byteLength
    else
      @buffer.length is 0 or @pos is @buffer.length

  # Is it a bundle?
  isBundle: ->
    @toString("ascii", @pos, @pos + 7) is "#bundle"

  # Has compressed address string
  isCompressed: ->
    # return true if we've a dict and the next 4 bytes are '/\0\0\0\0'
    @dict and @readInt32(@pos, false) is 0x2f000000

  toString: (encoding, start, end)->
    if @view
      start = start ? 0
      end = end ? @buffer.byteLength
      str = ""
      while start < end
        charCode = @view.getInt8(start++)
        str += String.fromCharCode(charCode & 0x7F)
      str
    else
      @buffer.toString.apply(@buffer, arguments)

  # Read a blob from the underlying buffer.
  readBlob: (move=true)->
    # get size of blob
    size = @readInt32()

    if @view
      i = 0
      view = new DataView(new ArrayBuffer(size))
      # copy buffer
      while i < size
        view.setInt8(i, @view.getInt8(@pos+i))
        i++
      buf = view.buffer
    else
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

    if @view
      string = ""

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
    else
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

  # read timetag and convert it to Date
  readTimetag: -> fromNTP(@readUInt32(), @readUInt32())

# Generate reader methods 
# for Int32, UInt32, Float, Double.
for type, desc of NUMBERS
  do(type, desc)->
    OscBufferReader::["read#{type}"] = (move=true)->
      if @view
        value = @view[desc.dataViewReader](@pos, false)
      else
        value = @buffer[desc.bufferReader](@pos)
      @pos += desc.size if move
      value

# Buffer write-access layer
class OscBufferWriter
  constructor: (buffer, pos=0)->
    @buffer = buffer
    if buffer instanceof ArrayBuffer
      @view = new DataView(buffer)
    @pos = pos

  # Write a string to the underlying buffer.
  writeString: (string, encoding="ascii")->
    if @view
      if encoding isnt "ascii"
        throw new Error("OscBufferWriter::writeString only supports ASCII encoding for ArrayBuffer")

      l = string.length
      i = 0
      while i < l
        char = string.charCodeAt(i++)
        @view.setInt8(@pos++, char & 0x7F)
      pad = oscPadding(l)
      i = 0
      while i < pad
        @view.setInt8(@pos++, 0)
        i++
    else
      length = Buffer.byteLength(string, encoding)
      @buffer.write(string, @pos, length)
      @pos += length

      pad = oscPadding(length)
      @buffer.fill(0, @pos, @pos + pad)
      @pos += pad

  # Write a blob to the underlying buffer.
  writeBlob: (buffer)->
    if @view
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
        view = new DataView(buffer)
        @writeInt32(l)
        i = 0
        while i < l
          @view.setInt8(@pos + i, view.getInt8(i))
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
    else
      @writeInt32(buffer.length)
      buffer.copy(@buffer, @pos)

      pad = oscPadding(4 + buffer.length)
      @pos += buffer.length
      if pad and pad < 4
        @buffer.fill(0, @pos, @pos + pad)
        @pos += pad

  # Write a timetag to the underlying buffer.
  writeTimetag: (tag)->
    @writeUInt32(tag[0])
    @writeUInt32(tag[1])

# Generate writer methods 
# for Int32, UInt32, Float, Double.
for type, desc of NUMBERS
  do(type, desc)->
    OscBufferWriter::["write#{type}"] = (value)->
      if @view
        value = @view[desc.dataViewWriter](@pos, value, false)
      else
        value = @buffer[desc.bufferWriter](value, @pos)
      @pos += desc.size
      value

# The OSC packet parser.
class OscPacketParser extends OscBufferReader
  constructor: (buffer, pos, dict)->
    if typeof pos is "object"
      @dict = pos
      pos = undefined
    else
      @dict = dict
    super(buffer, pos)

  parse: ->
    if @isBundle()
      @pos += 8
      @parseBundle()
    else
      @parseMessage()

  parseMessage: ->
    if @isCompressed()
      # skip address
      @readInt32()
      typeTag = @readTypeTag()
      args = @parseArguments(typeTag)
      # check for int32 as first type
      if typeTag.charAt(0) isnt 'i'
        throw new Error("Messages with compressed addresses must have an integer as first arguments type")
      # slice type tag
      typeTag = typeTag[1..0]
      # get address id
      addressId = args.shift()
      # resolve address
      address = @dict[addressId]
      unless address
        throw new Error("No address with id `#{addressId}` found")
    else
      address = @readAddress()
      typeTag = @readTypeTag()
      args    = @parseArguments(typeTag)

    new Message(address, typeTag, args)

  parseBundle: ->
    timetag  = @readTimetag()
    elements = []

    while true
      size     = @readInt32()
      boundary = @pos + size
      address  = @readAddress()
      typeTag  = @readTypeTag()
      args     = @parseArguments(typeTag, boundary)

      elements.push new Message(address, typeTag, args)
      break if @isEnd()

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

  # Reads the address string and checks the format.
  readAddress: ->
    address = @readString()
    if address.charAt(0) isnt '/'
      throw new Error("A address must start with a '/'")
    address

  readTypeTag: ->
    tag = @readString()
    if tag.charAt(0) is ','
      tag = tag[1..-1]
    else
      throw new Error("A type tag must start with a ','")
    tag

class OscPacketGenerator extends OscBufferWriter
  constructor: (messageOrBundle, dict)->
    @dict = dict

    if messageOrBundle instanceof Bundle
      @bundle = messageOrBundle
      size = oscSizeOfBundle(@bundle, @dict)
    else
      @message = messageOrBundle
      size = oscSizeOfMessage(@message, @dict)

    if nodeBuffer
      buffer = new Buffer(size)
    else
      buffer= new DataView(new ArrayBuffer(size))

    super(buffer)

  generateMessage: (msg)->
    # compress if possible
    if @dict and (addressId = @dict[msg.address])
      @writeUInt32(0x2f000000)
      @writeString(",i#{msg.typeTag}")
      @writeInt32(toInteger(addressId))
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
        value = type.cast(value) if type.cast
        type.write(@, value)

  generateBundle: (bundle)->
    # bundle-id
    @writeString("#bundle")
    # timetag
    tag = toNTP(bundle.timetag)
    @writeTimetag(tag)
    # generate elements
    for elem in bundle.elements
      @writeInt32(oscSizeOfMessage(elem, @dict))
      @generateMessage(elem)
    null

  generate: ->
    if @bundle
      @generateBundle(@bundle)
    else
      @generateMessage(@message)
    @buffer

# Parse OSC message/bundle from buffer
fromBuffer = (buffer, pos, dict)->
  new OscPacketParser(buffer, pos, dict).parse()

exports = module.exports
exports.Message = Message
exports.Bundle  = Bundle
exports.Impulse = Impulse
exports.OscBufferReader = OscBufferReader
exports.OscBufferWriter = OscBufferWriter
exports.OscPacketGenerator = OscPacketGenerator
exports.OscPacketParser = OscPacketParser
exports.fromBuffer = fromBuffer
