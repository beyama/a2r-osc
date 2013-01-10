osc = require "../"
should = require "should"

describe "OscBufferWriter", ->
  buffer = null
  writer = null

  beforeEach ->
    writer = new osc.OscBufferWriter(24)
    buffer = writer.buffer
    buffer.fill(20)

  numberWriter =
    writeInt32:
      name: "int32"
      size: 4
      value: -24
      test: "readInt32BE"
    writeUInt32:
      name: "uint32"
      size: 4
      value: 24
      test: "readUInt32BE"
    writeFloat:
      name: "float"
      size: 4
      value: 1.234
      test: "readFloatBE"
    writeDouble:
      name: "double"
      size: 8
      value: 1.234
      test: "readDoubleBE"

  for method, d of numberWriter
    describe ".#{method}", ->
      it "should write a(n) #{d.name} value", ->
        writer[method](d.value)
        buffer[d.test](0).should.be.equal d.value
        writer.pos.should.be.equal d.size

      it "should start writing from pos", ->
        writer.pos = 4
        writer[method](d.value)
        buffer[d.test](4).should.be.equal d.value
        writer.pos.should.be.equal d.size + 4

  describe ".writeString", ->
    it "should write a sequence of non-null UTF-8 characters followed by a null", ->
      str = "osc"
      writer.writeString(str)
      buffer.toString("utf8", 0, 3).should.be.equal str
      buffer[3].should.be.equal 0
      writer.pos.should.be.equal 4

    it "should add 0-3 additional null characters to make the total number of bits a multiple of 32", ->
      str = "bang"
      writer.writeString(str)
      buffer.toString("utf8", 0, 4).should.be.equal str
      i = 4
      while i < 8
        buffer[i++].should.be.equal 0
      writer.pos.should.be.equal 8

    it "should start writing from pos", ->
      writer.pos = 4
      str = "bang"
      writer.writeString(str)
      buffer.toString("utf8", 4, 8).should.be.equal str

    it "should handle utf8 string length correct", ->
      str = '\u00bd + \u00bc = \u00be'
      writer.writeString(str)
      writer.pos.should.be.equal 16

  describe ".writeBlob", ->
    it "should write an int32 size count, followed by that many 8-bit bytes of arbitrary binary data", ->
      blob = new Buffer("bang")
      writer.writeBlob(blob)
      buffer.readInt32BE(0).should.be.equal 4
      i = 0
      while i < blob.length
        buffer[i+4].should.be.equal blob[i]
        i++
      writer.pos.should.be.equal 8

    it "should add 0-3 additional zero bytes to make the total number of bits a multiple of 32", ->
      blob = new Buffer("osc")
      writer.writeBlob(blob)
      buffer[7].should.be.equal 0
      writer.pos.should.be.equal 8

describe "OscBufferReader", ->
  buffer = null
  reader = null

  beforeEach ->
    buffer = new Buffer(24)
    buffer.fill(20)
    reader = new osc.OscBufferReader(buffer)

  numberReader =
    readInt32:
      name: "int32"
      size: 4
      value: -24
      test: "writeInt32BE"
    readUInt32:
      name: "uint32"
      size: 4
      value: 24
      test: "writeUInt32BE"
    readFloat:
      name: "float"
      size: 4
      value: 1.234
      test: "writeFloatBE"
    readDouble:
      name: "double"
      size: 8
      value: 1.234
      test: "writeDoubleBE"

  for method, d of numberReader
    describe ".#{method}", ->
      it "should read a(n) #{d.name} value", ->
        buffer[d.test](d.value, 0)
        reader[method]().should.be.equal d.value
        reader.pos.should.be.equal d.size

      it "should start reading from pos", ->
        buffer[d.test](d.value, 4)
        reader.pos = 4
        reader[method]().should.be.equal d.value

  describe ".readString", ->
    beforeEach -> buffer.fill 0

    it "should throw an error if no data left", ->
      reader.pos = buffer.length
      (-> reader.readString() ).should.throw()

    it "should throw an error if no null found", ->
      buffer.fill 97
      (-> reader.readString() ).should.throw()

    it "should read a sequence of non-null UTF-8 characters", ->
      str = "osc"
      buffer.write(str)
      reader.readString().should.be.equal str
      reader.pos.should.be.equal 4

    it "should set pos to position behind additional 0 characters", ->
      str = "bang"
      buffer.write(str)
      reader.readString().should.be.equal str
      reader.pos.should.be.equal 8

    it "should start reading from pos", ->
      str = "bang"
      buffer.write(str, 4)
      reader.pos = 4
      reader.readString().should.be.equal str

  describe ".readBlob", ->
    it "should read a blob", ->
      buffer.fill(0)
      buffer.writeInt32BE(15, 0)
      buf = new Buffer("Addicted2Random")
      buf.copy(buffer, 4)
      buf2 = reader.readBlob()
      buf2.should.be.an.instanceof Buffer
      buf.length.should.be.equal buf2.length

      i = 0
      while i < buf2.length
        buf[i].should.be.equal buf2[i]
        i++
      reader.pos.should.be.equal 20

  describe ".readTimetag", ->
    it "should read a 64bit NTP time from buffer and convert it to a Date object", ->
      # 14236589681638796952 is equal to the 14th Jan 2005 at 17:58:59 and 12 milliseconds UTC
      hi = 3314714339
      lo = 51539608

      buffer.writeUInt32BE(hi, 0)
      buffer.writeUInt32BE(lo, 4)
      date = reader.readTimetag()
      date.ntpSeconds.should.be.equal hi
      date.ntpFraction.should.be.equal lo
      date.getUTCDate().should.be.equal 14
      date.getUTCMonth().should.be.equal 0
      date.getUTCFullYear().should.be.equal 2005
      date.getUTCHours().should.be.equal 17
      date.getUTCMinutes().should.be.equal 58
      date.getUTCSeconds().should.be.equal 59
      date.getMilliseconds().should.be.equal 12


describe "OscPacketParser", ->
  it "should be able to parse messages generated by OscPacketGenerator", ->
    codeToValue =
      i: 1
      d: 100000000000.1111
      s: "foo"
      c: 'a'
      r: Number("0xffaabb")
      T: true
      F: false
      I: osc.Impulse
      t: new Date

    for code, value of codeToValue
      buffer = new osc.Message("/test", code, value).toBuffer()
      msg = osc.fromBuffer(buffer)
      msg.should.be.instanceof osc.Message
      msg.typeTag.should.be.equal code
      msg.arguments[0].should.be.equal value

  it "should be able to parse bundle generated by OscPacketGenerator", ->
    orig = new osc.Bundle([0, 1]).
      message("/foo1", 1).
      message("/foo2", 2)
    buffer = orig.toBuffer()

    bundle = osc.fromBuffer(buffer)
    bundle.should.be.instanceof osc.Bundle
    bundle.elements.should.have.length(2)

    for elem, i in bundle.elements
      elem.address.should.be.equal orig.elements[i].address
      elem.typeTag.should.be.equal orig.elements[i].typeTag
      elem.arguments[0].should.be.equal orig.elements[i].arguments[0]

describe "OscPacketGenerator", ->
  it "should cast values before writing them to buffer", ->
    data =
      i: { b: 1.1, a: 1 }
      s: { b: 2, a: "2" }
    for c, ba of data
      buffer = new osc.Message("/test", c, ba.b).toBuffer()
      msg = osc.fromBuffer(buffer)
      msg.arguments[0].should.be.equal ba.a

  it "should generate valid bundles", ->
    bundle = new osc.Bundle(1).
      message("/foo1", 1).
      message("/foo2", 2)

    buffer = bundle.toBuffer()
    # #bundle + "\0"
    buffer.toString("utf8", 0, 7).should.be.equal "#bundle"
    buffer[7].should.be.equal 0
    # timetag
    buffer.readUInt32BE(8).should.be.equal 0
    buffer.readUInt32BE(12).should.be.equal 1
    # size of first element
    element = bundle.elements[0]
    buffer.readInt32BE(16).should.be.equal element.toBuffer().length
    # path
    buffer.toString("utf8", 20, 25).should.be.equal "/foo1"
    # ...

  it "should determine type code of buid-in types", ->
    buffer = new osc.Message("/",
      ["foo", new Buffer("foo"), 1.1, true, false, null, osc.Impulse]).toBuffer()
    msg = osc.fromBuffer(buffer)
    msg.typeTag.should.be.equal "sbfTFNI"

describe "Message", ->
  describe "argument normalisation", ->
    it "should build typeTag from typenames", ->
      msg = new osc.Message("/foo", [
        { type: "string", value: "osc" },
        { type: "integer", value: 5 }
      ])
      msg.typeTag.should.be.equal "si"
      msg.arguments[0].should.be.equal "osc"
      msg.arguments[1].should.be.equal 5

    it "should automaticaly determinate type code from value", ->
      msg = new osc.Message("/foo", ["osc", 5])
      msg.typeTag.should.be.equal "sf"
      msg.arguments[0].should.be.equal "osc"
      msg.arguments[1].should.be.equal 5

    it "should check consitent length of type tag and arguments", ->
      (-> new osc.Message("/foo", "si", ["osc"]) ).should.throw()

describe "compressed addresses", ->
  dict = { 1: "/foo", 2: "/bar" }
  dict[v] = k for k, v of dict

  buffer = null

  beforeEach ->
    buffer = new osc.Message("/foo", 2.2).toBuffer(dict)
    
  it "should generate message with compressed address", ->
    # unpack message without dict to check
    msg = osc.fromBuffer(buffer)
    msg.address.should.be.equal "/"
    msg.typeTag.should.be.equal "if"
    msg.arguments[0].should.be.equal Number(dict["/foo"])

  it "should unpack message with compressed address", ->
    msg = osc.fromBuffer(buffer, dict)
    msg.address.should.be.equal "/foo"
    msg.typeTag.should.be.equal "f"
    msg.arguments.should.have.length 1

  it "should throw an error if the address id not foung", ->
    buffer.writeInt32BE(3, 8) # overwrite id with 3
    (-> osc.fromBuffer(buffer, dict) ).should.throw()
