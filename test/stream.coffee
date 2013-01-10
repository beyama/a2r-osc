osc = require "../"
should = require "should"

describe "OSC UnpackStream", ->
  it "should emit message", (done)->
    stream = new osc.UnpackStream

    stream.on "message", (msg)->
      msg.address.should.be.equal "/a2r"
      msg.arguments[0].should.be.equal 5
      done()

    stream.write new osc.Message("/a2r", "i", 5).toBuffer()

  it "should emit error if write is called with invalid data", (done)->
    stream = new osc.UnpackStream

    stream.on "error", (err)->
      done()

    stream.write "..."

  it "should pass the optional dict to the parser", (done)->
    dict = { 1: "/a2r", "/a2r": 1 }
    stream = new osc.UnpackStream(dict)

    stream.on "message", (msg)->
      msg.address.should.be.equal "/a2r"
      done()

    stream.write new osc.Message("/a2r", 2.2).toBuffer(dict)
