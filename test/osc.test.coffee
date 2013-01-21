if typeof require is "function"
  osc    = require "../"
  expect = require "expect.js"
else
  osc = window.a2r.osc
  expect = window.expect

Message = osc.Message
Bundle  = osc.Bundle

length = (b)->
  if b instanceof ArrayBuffer then b.byteLength else b.length

nodeBuffer = typeof Buffer is 'function'

TEST_MESSAGES = [
  {
    msg: new osc.Message("/osc/documentation", "/node/x/y")
    length: 36
  },
  {
    msg: new osc.Message("/node/x/y", "is", [12, "foo"])
    length: 24
  },
  {
    msg: new osc.Message("/node/x/y", osc.Impulse)
    length: 16
  },
  {
    msg: new osc.Message("/node/color", "r", Number("0xffaabb"))
    length: 20
  },
  {
    msg: new osc.Message("/node/char", "c", "a")
    length: 20
  },
  {
    msg: new osc.Message("/node/x", "d", 25.444)
    length: 20
  },
  {
    msg: new osc.Message("/node/setDate", new Date)
    length: 28
  },
  {
    msg: new osc.Message("/node/noPayload", [null, false, true, osc.Impulse])
    length: 24
  }
]

arrayBuffer = new ArrayBuffer(10)
int8array   = new Int8Array(arrayBuffer)
for i in [0..9]
  int8array[i] = Math.round(Math.random() * 255)

TEST_MESSAGES.push(msg: new osc.Message("/foo/data", arrayBuffer), length: 32)

createInt8Array = (buffer)->
  if nodeBuffer and Buffer.isBuffer(buffer)
    array = new Int8Array(new ArrayBuffer(buffer.length))
    i = 0
    while i < buffer.length
      array[i] = buffer[i]
      i++
    array
  else
    new Int8Array(buffer)

bufferEqual = (b1, b2)->
  a1 = createInt8Array(b1)
  a2 = createInt8Array(b2)

  expect(a1.byteLength).to.be a2.byteLength

  i = 0
  while i < a1.length
    expect(a1[i]).to.be a2[i]
    i++

isBuffer = (o)->
  if nodeBuffer and Buffer.isBuffer(o)
    return true
  if o instanceof ArrayBuffer
    return true
  false

messageEqual = (msg1, msg2)->
  expect(msg1.address).to.be msg2.address
  expect(msg1.typeTag).to.be msg2.typeTag
  expect(msg1.arguments).to.have.length msg2.arguments.length
  for arg, i in msg1.arguments
    if isBuffer(arg)
      bufferEqual(arg, msg2.arguments[i])
    else if arg instanceof Date
      expect(arg.valueOf()).to.be msg2.arguments[i].valueOf()
    else if arg
      expect(arg).to.be msg2.arguments[i]
    else
      expect(arg is msg2.arguments[i]).to.be.ok()
  null

# OSC packet generator mock
class MockOscPacketGenerator extends osc.AbstractOscPacketGenerator
  constructor: (messageOrBundle, dict)->
    super
    @buffer = []

  writeString: (string, encoding="ascii")-> @buffer.push(string)

for name, desc of osc.NUMBERS
  do (name)->
    MockOscPacketGenerator::["write#{name}"] = (value)-> @buffer.push(value)

# OSC packet parser mock
class MockOscPacketParser extends osc.AbstractOscPacketParser
  readString: (encoding, move=true)->
    value = @buffer[@pos]
    @pos++ if move
    value

  isEnd: -> @buffer.length <= @pos

for name, desc of osc.NUMBERS
  do (name)->
    MockOscPacketParser::["read#{name}"] = (move=true)->
      value = @buffer[@pos]
      @pos++ if move
      value

describe "Message", ->
  describe "constructor", ->

    it "should construct message from address and one argument", ->
      msg = new Message("/test", 12)
      expect(msg.address).to.be "/test"
      expect(msg.typeTag).to.be "f"
      expect(msg.arguments).to.have.length 1
      expect(msg.arguments).to.contain 12

    it "should construct message from address and array of arguments", ->
      msg = new Message("/test", ["a2r", 12])
      expect(msg.address).to.be "/test"
      expect(msg.typeTag).to.be "sf"
      expect(msg.arguments).to.have.length 2
      expect(msg.arguments[0]).to.be "a2r"
      expect(msg.arguments[1]).to.be 12

    it "should construct message from address, typetag and array", ->
      msg = new Message("/test", "si", ["a2r", 12.4])
      expect(msg.address).to.be "/test"
      expect(msg.typeTag).to.be "si"
      expect(msg.arguments).to.have.length 2
      expect(msg.arguments[0]).to.be "a2r"
      expect(msg.arguments[1]).to.be 12

    it "should construct message from address and object", ->
      msg = new Message("/test", { type: "i", value: 23 })
      expect(msg.address).to.be "/test"
      expect(msg.typeTag).to.be "i"
      expect(msg.arguments).to.have.length 1
      expect(msg.arguments).to.contain 23

    it "should throw an error if a type isn't supported", ->
       expect(-> new Message("/test", { type: "y", value: 23 })).to.throwError()
       expect(-> new Message("/test", "y", 23)).to.throwError()

  describe ".add", ->
    msg = null

    beforeEach -> msg = new Message("/test")

    it "should return itself", ->
      expect(msg.add("foo")).to.be msg

    describe "without type code", ->

      it "should determine typecode for Boolean true", ->
        msg.add(true)
        expect(msg.typeTag).to.be "T"

      it "should determine typecode for Boolean false", ->
        msg.add(false)
        expect(msg.typeTag).to.be "F"

      it "should determine typecode for null", ->
        msg.add(null)
        expect(msg.typeTag).to.be "N"

      it "should determine typecode for Number", ->
        msg.add(12)
        expect(msg.typeTag).to.be "f"

      it "should determine typecode for Date", ->
        msg.add(new Date)
        expect(msg.typeTag).to.be "t"

      it "should determine typecode for Impulse", ->
        msg.add(osc.Impulse)
        expect(msg.typeTag).to.be "I"

      it "should determine typecode for ArrayBuffer", ->
        msg.add(new ArrayBuffer(4))
        expect(msg.typeTag).to.be "b"

      if nodeBuffer
        it "should determine typecode for Buffer", ->
          msg.add(new Buffer(4))
          expect(msg.typeTag).to.be "b"

      it "should throw an error for unsupported types", ->
        expect(-> msg.add({})).to.throwError()

    describe "with type code", ->

      it "should cast value", ->
        msg.add("i", 12.4)
        expect(msg.arguments).to.contain 12

describe "AbstractOscPacketGenerator", ->

  describe "generate a message", ->
    it "should write address, type tag and arguments", ->
      message = new osc.Message("/foo/bar", "i", 12)
      mock = new MockOscPacketGenerator(message)
      array = mock.generate()
      expect(array[0]).to.be message.address
      expect(array[1]).to.be ",i"
      expect(array[2]).to.be 12

    it "should cast values", ->
      message = new osc.Message("/foo/bar", "isfc", [12.3, 5, "15.5", "foo"])
      mock = new MockOscPacketGenerator(message)
      array = mock.generate()
      expect(array[2]).to.be 12
      expect(array[3]).to.be "5"
      expect(array[4]).to.be 15.5
      expect(array[5]).to.be "f".charCodeAt(0)

  describe "generate a bundle", ->
    it "should write '#bundle', timetag and messages", ->
      bundle = new osc.Bundle(new Date)
        .add("/foo", osc.Impulse)
        .add("/bar", osc.Impulse)

      mock = new MockOscPacketGenerator(bundle)
      array = mock.generate()
      expect(array[0]).to.be "#bundle"
      expect(array[1]).to.be 0
      expect(array[2]).to.be 1
      expect(array[3]).to.be 12 # size of first message
      expect(array[4]).to.be "/foo"
      expect(array[5]).to.be ",I"
      expect(array[6]).to.be 12 # size of second message
      expect(array[7]).to.be "/bar"
      expect(array[8]).to.be ",I"

    it "should convert timetag-date to a NTP date", ->
      date = new Date
      date.setTime(date.getTime() + 1000)
      ntp = osc.toNTP(date)
      bundle = new osc.Bundle(date)

      mock = new MockOscPacketGenerator(bundle)
      array = mock.generate()
      for i in [0..1]
        expect(array[i+1]).to.be ntp[i]

describe "AbstractOscPacketParser", ->
  it "should return a Bundle if the first string is '#bundle'", ->
    bundle = new MockOscPacketParser(["#bundle", 0, 1]).parse()
    expect(bundle).to.be.a osc.Bundle

  it "should read bundled messages", ->
    data = ["#bundle", 0, 1]

    msg1 = new osc.Message("/foo", 1)
    msg2 = new osc.Message("/bar", 2)

    messages = [msg1, msg2]

    for msg in messages
      data.push(16) # length
      data.push(msg.address)
      data.push("," + msg.typeTag)
      data.push.apply(data, msg.arguments)

    bundle = new MockOscPacketParser(data).parse()
    
    for elem, i in bundle.elements
      messageEqual(elem, messages[i])

  it "should return a Message if the first string is an address", ->
    message = new MockOscPacketParser(["/foo", ",i", 1]).parse()
    expect(message).to.be.a osc.Message

  describe ".readTimetag", ->
    it "should read a 64bit NTP time from buffer and convert it to a Date object", ->
      # 14236589681638796952 is equal to the 14th Jan 2005 at 17:58:59 and 12 milliseconds UTC
      hi = 3314714339
      lo = 51539608

      mock = new MockOscPacketParser([hi, lo])

      date = mock.readTimetag()
      expect(date.ntpSeconds).to.be hi
      expect(date.ntpFraction).to.be lo
      expect(date.getUTCDate()).to.be 14
      expect(date.getUTCMonth()).to.be 0
      expect(date.getUTCFullYear()).to.be 2005
      expect(date.getUTCHours()).to.be 17
      expect(date.getUTCMinutes()).to.be 58
      expect(date.getUTCSeconds()).to.be 59
      expect(date.getMilliseconds()).to.be 12

describe "OscArrayBufferPacketGenerator", ->
  it "should generate packets with correct size", ->
    for msg in TEST_MESSAGES
      packet = new osc.OscArrayBufferPacketGenerator(msg.msg).generate()
      expect(length(packet)).to.be msg.length

  it "should generate packets that are parseable by OscArrayBufferPacketParser", ->
    for msg in TEST_MESSAGES
      packet = new osc.OscArrayBufferPacketGenerator(msg.msg).generate()
      message = new osc.OscArrayBufferPacketParser(packet).parse()
      messageEqual(msg.msg, message)

if nodeBuffer
  describe "OscArrayBufferPacketGenerator", ->
    it "should generate packets with correct size", ->
      for msg in TEST_MESSAGES
        packet = new osc.OscBufferPacketGenerator(msg.msg).generate()
        expect(length(packet)).to.be msg.length

    it "should generate packets that are parseable by OscBufferPacketParser", ->
      for msg in TEST_MESSAGES
        packet = new osc.OscBufferPacketGenerator(msg.msg).generate()
        message = new osc.OscBufferPacketParser(packet).parse()
        messageEqual(msg.msg, message)

if nodeBuffer
  describe "OscBufferPacketGenerator", ->
    it "should terminate a string with 0", ->
      string = "/a"
      buffer = new osc.Message(string, osc.Impulse).toBuffer()
      for i in [0..1]
        expect(buffer[i]).to.be string.charCodeAt(i)
      for i in [2..3]
        expect(buffer[i]).to.be 0

    it "should add additional null characters to string to make the total number of bits a multiple of 32", ->
      string = "/foo"
      buffer = new osc.Message(string, osc.Impulse).toBuffer()
      for i in [0..3]
        expect(buffer[i]).to.be string.charCodeAt(i)
      for i in [4..7]
        expect(buffer[i]).to.be 0
