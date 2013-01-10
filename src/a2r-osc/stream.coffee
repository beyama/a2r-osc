stream = require "stream"
osc = require "./osc"

class UnpackStream extends stream.Stream
  constructor: (dict)->
    super()
    @dict = dict
    @writable = true

  # Parse buffer with OSC data and emit "message"
  # with parsed OSC message/bundle object.
  #
  # emits "error" with error object on parsing errors
  write: (buffer, encoding)->
    # start parsing if buffer is a Buffer
    if Buffer.isBuffer(buffer)
      try
        msg = osc.fromBuffer(buffer, @dict)
        @emit "message", msg
      catch e
        @emit "error", e
    # otherwise convert to a buffer
    else
      @write(new Buffer(buffer, encoding))
    true

  end: (buffer, encoding)->
    @write(buffer, encoding) if buffer
    @emit("close")

class PackStream extends stream.Stream
  constructor: (dict)->
    super()
    @dict = dict
    @writable = false
    @readable = true

  send: (message)->
    try
      buffer = message.toBuffer(@dict)
      @emit("data", buffer)
    catch e
      @emit("error", e)
      return false
    true

module.exports.UnpackStream = UnpackStream
module.exports.PackStream = PackStream
