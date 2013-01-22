osc = require "../"
expect = require "expect.js"

describe "OSC UnpackStream", ->

  describe ".write", ->
    it "should emit message if write is called with an OSC buffer", (done)->
      stream = new osc.UnpackStream

      stream.on "message", (msg)->
        expect(msg.address).to.be "/a2r"
        expect(msg.arguments[0]).to.be 5
        done()

      stream.write new osc.Message("/a2r", "i", 5).toBuffer()

    it "should emit an error if write is called with invalid data", (done)->
      stream = new osc.UnpackStream

      stream.on "error", (err)->
        expect(err).to.be.an Error
        done()

      stream.write "..."

    it "should pass the optional dictionary to the parser", (done)->
      dict = new osc.Dictionary(1: "/a2r")
      stream = new osc.UnpackStream(dict)

      stream.on "message", (msg)->
        expect(msg.address).to.be "/a2r"
        expect(msg.typeTag).to.be "f"
        expect(msg.arguments).to.have.length 1
        done()

      stream.write new osc.Message("/")
        .add("i", 1)
        .add(12.5)
        .toBuffer()

  describe ".end", ->
    stream = null

    beforeEach -> stream = new osc.UnpackStream()

    it "should emit `close`", (done)->
      stream.on("close", done)
      stream.end()

    it "should write data before calling end if called with data", (done)->
      called = false

      stream.on "close", ->
        expect(called).to.be true
        done()

      stream.on "message", -> called = true

      stream.end new osc.Message("/test", osc.Impulse).toBuffer()

describe "OSC PackStream", ->

  describe ".send", ->

    it "should emit `data` with buffer of packed message", (done)->
      stream = new osc.PackStream

      stream.on "data", (data)->
        msg = osc.fromBuffer(data)
        expect(msg.equal(message)).to.be true
        done()

      message = new osc.Message("/test", osc.Impulse)
      stream.send message

    it "should emit `error` with error if something went wrong", (done)->
      stream = new osc.PackStream

      stream.on "error", (error)->
        expect(error).to.be.an Error
        done()

      stream.send "foo bar"

    it "should pass the dictionary to the Message::toBuffer method", (done)->
      dict = new osc.Dictionary(1: "/a2r")
      stream = new osc.PackStream(dict)

      stream.on "data", (data)->
        msg = osc.fromBuffer(data)
        expect(msg.address).to.be "/"
        expect(msg.arguments).to.have.length 2
        expect(msg.arguments[0]).to.be 1
        done()

      stream.send new osc.Message("/a2r", 56)

describe "pipe messages from pack stream to unpack stream", ->

  it "should pass the message through the pipe", (done)->
    from = new osc.PackStream
    to   = new osc.UnpackStream

    to.on "message", (msg)->
      expect(msg.equal(message)).to.be true
      done()

    from.pipe(to)

    message = new osc.Message("/test", [54, "hello"])
    from.send(message)
