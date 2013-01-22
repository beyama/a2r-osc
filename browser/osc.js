(function() {
  var exports,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  if (typeof module === "undefined") {
    window.a2r || (window.a2r = {});
    exports = window.a2r.osc = {};
  } else {
    exports = module.exports;
  }

  (function(exports) {
    var AbstractOscPacketGenerator, AbstractOscPacketParser, Bundle, Dictionary, Impulse, Message, NUMBERS, OSC_TYPES, OSC_TYPES_BY_NAME, OscArrayBufferPacketGenerator, OscArrayBufferPacketParser, SECONDS_FROM_1900_to_1970, code, desc, fromBuffer, fromNTP, name, nodeBuffer, oscPadding, oscSizeOf, oscSizeOfBlob, oscSizeOfBundle, oscSizeOfMessage, oscSizeOfString, oscTypeCodeOf, toInteger, toNTP, toNumber, type, _fn, _fn1, _fn2, _fn3;
    nodeBuffer = typeof Buffer === 'function';
    toNumber = function(val) {
      val = Number(val);
      if (val === NaN) {
        throw new Error("Value isn't a number");
      }
      return val;
    };
    toInteger = function(val) {
      val = toNumber(val);
      return Math.round(val);
    };
    SECONDS_FROM_1900_to_1970 = 2208988800;
    fromNTP = function(seconds, fraction) {
      var date, ms;
      if (seconds === 0 && fraction === 1) {
        return new Date;
      }
      ms = (seconds - SECONDS_FROM_1900_to_1970) * 1000;
      ms += Math.round(1000 * fraction / 0x100000000);
      date = new Date(ms);
      date.ntpSeconds = seconds;
      date.ntpFraction = fraction;
      return date;
    };
    toNTP = function(date) {
      var fraction, seconds, time;
      if (date === 1) {
        return [0, 1];
      }
      if (Array.isArray(date)) {
        return date;
      }
      time = date.getTime();
      seconds = Math.floor(time / 1000);
      fraction = Math.round(((time % 1000) * 0x100000000) / 1000);
      return [seconds + SECONDS_FROM_1900_to_1970, fraction];
    };
    OSC_TYPES = {
      i: {
        name: "integer",
        read: function(reader) {
          return reader.readInt32();
        },
        write: function(writer, value) {
          return writer.writeInt32(value);
        },
        cast: toInteger,
        sizeOf: function(value) {
          return 4;
        }
      },
      f: {
        name: "float",
        read: function(reader) {
          return reader.readFloat();
        },
        write: function(writer, value) {
          return writer.writeFloat(value);
        },
        cast: toNumber,
        sizeOf: function(value) {
          return 4;
        }
      },
      s: {
        name: "string",
        read: function(reader) {
          return reader.readString();
        },
        write: function(writer, value) {
          return writer.writeString(value);
        },
        cast: function(value) {
          return value.toString();
        },
        sizeOf: function(value) {
          return oscSizeOfString(value.toString());
        }
      },
      b: {
        name: "blob",
        read: function(reader) {
          return reader.readBlob();
        },
        write: function(writer, value) {
          return writer.writeBlob(value);
        },
        sizeOf: function(value) {
          return oscSizeOfBlob(value);
        }
      },
      d: {
        name: "double",
        read: function(reader) {
          return reader.readDouble();
        },
        write: function(writer, value) {
          return writer.writeDouble(value);
        },
        sizeOf: function(value) {
          return 8;
        }
      },
      c: {
        name: "char",
        read: function(reader) {
          return String.fromCharCode(reader.readInt32() & 0x7F);
        },
        write: function(writer, value) {
          return writer.writeInt32(value.charCodeAt(0));
        },
        cast: function(value) {
          return value.toString().charAt(0);
        },
        sizeOf: function(value) {
          return 4;
        }
      },
      r: {
        name: "color",
        read: function(reader) {
          return reader.readInt32();
        },
        write: function(writer, value) {
          return writer.writeInt32(value);
        },
        cast: toInteger,
        sizeOf: function(value) {
          return 4;
        }
      },
      t: {
        name: "time",
        read: function(reader) {
          return reader.readTimetag();
        },
        write: function(writer, value) {
          return writer.writeTimetag(value);
        },
        cast: function(value) {
          if (value instanceof Date) {
            return value;
          }
          return new Date(value);
        },
        sizeOf: function() {
          return 8;
        }
      },
      T: {
        name: "true",
        read: function() {
          return true;
        }
      },
      F: {
        name: "false",
        read: function() {
          return false;
        }
      },
      N: {
        name: "null",
        read: function() {
          return null;
        }
      },
      I: {
        name: "impulse",
        read: function() {
          return Impulse;
        }
      }
    };
    OSC_TYPES.S = OSC_TYPES.s;
    OSC_TYPES_BY_NAME = {};
    for (code in OSC_TYPES) {
      type = OSC_TYPES[code];
      if (code !== 'S') {
        type.code = code;
      }
      OSC_TYPES_BY_NAME[type.name] = type;
    }
    NUMBERS = {
      Int32: {
        dataViewReader: "getInt32",
        dataViewWriter: "setInt32",
        bufferReader: "readInt32BE",
        bufferWriter: "writeInt32BE",
        size: 4
      },
      UInt32: {
        dataViewReader: "getUint32",
        dataViewWriter: "setUint32",
        bufferReader: "readUInt32BE",
        bufferWriter: "writeUInt32BE",
        size: 4
      },
      Float: {
        dataViewReader: "getFloat32",
        dataViewWriter: "setFloat32",
        bufferReader: "readFloatBE",
        bufferWriter: "writeFloatBE",
        size: 4
      },
      Double: {
        dataViewReader: "getFloat64",
        dataViewWriter: "setFloat64",
        bufferReader: "readDoubleBE",
        bufferWriter: "writeDoubleBE",
        size: 8
      }
    };
    oscPadding = function(len) {
      return 4 - len % 4;
    };
    Impulse = new Object;
    oscTypeCodeOf = function(val) {
      switch (typeof val) {
        case 'string':
          return 's';
        case 'number':
          return 'f';
        case 'boolean':
          if (val) {
            return 'T';
          } else {
            return 'F';
          }
          break;
        case 'undefined':
          throw new Error("Value can't be undefined");
          break;
        case 'object':
          if (val === null) {
            return 'N';
          } else if (val instanceof Date) {
            return 't';
          } else if ((nodeBuffer && Buffer.isBuffer(val)) || val instanceof ArrayBuffer) {
            return 'b';
          } else if (val === Impulse) {
            return 'I';
          } else {
            throw new Error("Unsupported type `" + val + "`");
          }
          break;
        default:
          throw new Error("Unsupported type `" + val + "`");
      }
    };
    oscSizeOfString = function(str) {
      return str.length + oscPadding(str.length);
    };
    oscSizeOfBlob = function(buf) {
      var length, pad;
      if (buf instanceof ArrayBuffer) {
        length = 4 + buf.byteLength;
      } else {
        length = 4 + buf.length;
      }
      pad = oscPadding(length);
      if (pad < 4) {
        length += pad;
      }
      return length;
    };
    oscSizeOfBundle = function(bundle, dict) {
      var elem, size, _i, _len, _ref;
      size = 16;
      _ref = bundle.elements;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        elem = _ref[_i];
        size += 4 + oscSizeOfMessage(elem, dict);
      }
      return size;
    };
    oscSizeOfMessage = function(msg, dict) {
      var i, id, l, size, tl, typeCode, value;
      if (dict) {
        if (msg.isPattern()) {
          id = dict.getPatternId(msg.address);
        } else {
          id = dict.getAddressId(msg.address);
        }
      }
      if (id) {
        size = 8;
      } else {
        size = oscSizeOfString(msg.address);
      }
      if (id) {
        tl = msg.typeTag.length + 2;
      } else {
        tl = msg.typeTag.length + 1;
      }
      size += tl + oscPadding(tl);
      i = 0;
      l = msg.typeTag.length;
      while (i < l) {
        typeCode = msg.typeTag.charAt(i);
        value = msg["arguments"][i++];
        size += oscSizeOf(value, typeCode);
      }
      return size;
    };
    oscSizeOf = function(value, code) {
      if (code) {
        type = OSC_TYPES[code] || OSC_TYPES_BY_NAME[code];
        if (!type) {
          throw new Error("Type `" + code + "` isn't supported");
        }
        if (!type.sizeOf) {
          return 0;
        }
        return type.sizeOf(value);
      } else {
        code = oscTypeCodeOf(value);
        return oscSizeOf(value, code);
      }
    };
    Dictionary = (function() {

      function Dictionary(addressMap, patternMap) {
        var address, id, pattern;
        this.idToAddress = {};
        this.addressToId = {};
        this.idToPattern = {};
        this.patternToId = {};
        if (addressMap) {
          for (id in addressMap) {
            address = addressMap[id];
            this.addAddress(id, address);
          }
        }
        if (patternMap) {
          for (id in patternMap) {
            pattern = patternMap[id];
            this.addPattern(id, pattern);
          }
        }
      }

      Dictionary.prototype.addAddress = function(id, address) {
        this.idToAddress[id] = address;
        return this.addressToId[address] = Number(id);
      };

      Dictionary.prototype.getAddress = function(id) {
        return this.idToAddress[id];
      };

      Dictionary.prototype.getAddressId = function(addr) {
        return this.addressToId[addr];
      };

      Dictionary.prototype.removeAddress = function(idOrAddress) {
        var address, id;
        if (typeof idOrAddress === "number") {
          id = idOrAddress;
          address = this.idToAddress[id];
        } else {
          address = idOrAddress;
          id = this.addressToId[address];
        }
        delete this.idToAddress[id];
        return delete this.addressToId[address];
      };

      Dictionary.prototype.addPattern = function(id, pattern) {
        this.idToPattern[id] = pattern;
        return this.patternToId[pattern] = Number(id);
      };

      Dictionary.prototype.getPattern = function(id) {
        return this.idToPattern[id];
      };

      Dictionary.prototype.getPatternId = function(pattern) {
        return this.patternToId[pattern];
      };

      Dictionary.prototype.removePattern = function(idOrPattern) {
        var id, pattern;
        if (typeof idOrPattern === "number") {
          id = idOrPattern;
          pattern = this.idToPattern[id];
        } else {
          pattern = idOrPattern;
          id = this.patternToId[pattern];
        }
        delete this.idToPattern[id];
        return delete this.patternToId[pattern];
      };

      return Dictionary;

    })();
    Message = (function() {

      function Message(address, typeTag, args) {
        var arg, i, msg, value, _i, _j, _len, _len1;
        if (address instanceof Message) {
          msg = address;
          this.address = msg.address;
          this.typeTag = msg.typeTag;
          this["arguments"] = msg["arguments"].slice(0);
          return;
        }
        this.address = address;
        this["arguments"] = [];
        if (typeTag && !(args != null)) {
          args = typeTag;
          typeTag = null;
        }
        if (args === void 0) {
          return;
        }
        if (!Array.isArray(args)) {
          args = [args];
        }
        if (typeTag) {
          if (args.length !== typeTag.length) {
            throw new Error("Arguments length doesn't match typetag length");
          }
          for (i = _i = 0, _len = args.length; _i < _len; i = ++_i) {
            arg = args[i];
            this.add(typeTag.charAt(i), arg);
          }
        } else {
          for (_j = 0, _len1 = args.length; _j < _len1; _j++) {
            value = args[_j];
            code = null;
            if (typeof value === 'object' && ((value != null ? value.type : void 0) != null)) {
              code = value.type;
              type = OSC_TYPES[code] || OSC_TYPES_BY_NAME[code];
              if (!type) {
                throw new Error("Unsupported type `" + code + "`");
              }
              value = type.sizeOf ? value.value : type.read();
            }
            if (code) {
              this.add(code, value);
            } else {
              this.add(value);
            }
          }
        }
      }

      Message.prototype.clone = function() {
        return new Message(this);
      };

      Message.prototype.isPattern = function() {
        if (this._isPattern != null) {
          return this._isPattern;
        }
        return this._isPattern = /(?:\*|\?|\[|\{|\/\/)/.test(this.address);
      };

      Message.prototype.add = function(code, value) {
        if (value === void 0) {
          value = code;
          code = null;
        }
        if (code) {
          type = OSC_TYPES[code] || OSC_TYPES_BY_NAME[code];
          if (!type) {
            throw new Error("Unsupported type `" + code + "`");
          }
          if (type.cast) {
            value = type.cast(value);
          }
        } else {
          code = oscTypeCodeOf(value);
          type = OSC_TYPES[code];
        }
        this["arguments"].push(value);
        if (this.typeTag) {
          this.typeTag += code;
        } else {
          this.typeTag = code;
        }
        return this;
      };

      Message.prototype.toBuffer = function(dict) {
        if (nodeBuffer) {
          return new OscBufferPacketGenerator(this, dict).generate();
        } else {
          return new OscArrayBufferPacketGenerator(this, dict).generate();
        }
      };

      Message.prototype.equal = function(other) {
        var arg, i, _i, _len, _ref;
        if (!(other instanceof Message)) {
          return false;
        }
        if (other.address !== this.address) {
          return false;
        }
        if (other.typeTag !== this.typeTag) {
          return false;
        }
        if (other["arguments"].length !== this["arguments"].length) {
          return false;
        }
        _ref = this["arguments"];
        for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
          arg = _ref[i];
          if (other["arguments"][i] !== arg) {
            return false;
          }
        }
        return true;
      };

      return Message;

    })();
    Bundle = (function() {

      function Bundle(timetag, elements) {
        var bundle, elem, _i, _j, _len, _len1, _ref;
        if (timetag instanceof Bundle) {
          bundle = timetag;
          this.timetag = new Date(bundle.timetag.valueOf());
          this.elements = [];
          _ref = bundle.elements;
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            elem = _ref[_i];
            this.addElement(elem.clone());
          }
          return;
        }
        if (timetag instanceof Date) {
          this.timetag = timetag;
        } else if (timetag === 1) {
          this.timetag = new Date;
        } else {
          this.timetag = new Date;
          elements = timetag;
        }
        this.elements = [];
        if (elements) {
          if (Array.isArray(elements)) {
            for (_j = 0, _len1 = elements.length; _j < _len1; _j++) {
              elem = elements[_j];
              this.addElement(elem);
            }
          } else {
            this.addElement(elements);
          }
        }
      }

      Bundle.prototype.clone = function() {
        return new Bundle(this);
      };

      Bundle.prototype.addElement = function(address, typeTag, args) {
        var msg;
        if (address instanceof Message) {
          this.elements.push(address);
          return address;
        } else if (typeof address === "string") {
          msg = new Message(address, typeTag, args);
          this.elements.push(msg);
          return msg;
        } else {
          throw new Error("A bundle element must be an instance of Message");
        }
      };

      Bundle.prototype.add = function(address, typeTag, args) {
        this.addElement(address, typeTag, args);
        return this;
      };

      Bundle.prototype.toBuffer = function(dict) {
        if (nodeBuffer) {
          return new OscBufferPacketGenerator(this, dict).generate();
        } else {
          return new OscArrayBufferPacketGenerator(this, dict).generate();
        }
      };

      Bundle.prototype.equal = function(other) {
        var elem, i, _i, _len, _ref;
        if (!(other instanceof Bundle)) {
          return false;
        }
        if (other.timetag !== this.timetag) {
          return false;
        }
        if (other.elements.length !== this.elements.length) {
          return false;
        }
        _ref = this.elements;
        for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
          elem = _ref[i];
          if (!elem.equal(other.elements[i])) {
            return false;
          }
        }
        return true;
      };

      return Bundle;

    })();
    AbstractOscPacketGenerator = (function() {

      function AbstractOscPacketGenerator(messageOrBundle, dict) {
        this.dict = dict;
        if (messageOrBundle instanceof Bundle) {
          this.bundle = messageOrBundle;
          this.size = oscSizeOfBundle(this.bundle, this.dict);
        } else {
          this.message = messageOrBundle;
          this.size = oscSizeOfMessage(this.message, this.dict);
        }
      }

      AbstractOscPacketGenerator.prototype._generateMessage = function(msg) {
        var i, id, l, value, _results;
        if (this.dict) {
          id = msg.isPattern() ? this.dict.getPatternId(msg.address) : this.dict.getAddressId(msg.address);
        }
        if (id) {
          if (msg.isPattern()) {
            this.writeString("/?");
          } else {
            this.writeString("/");
          }
          this.writeString(",i" + msg.typeTag);
          this.writeInt32(toInteger(id));
        } else {
          this.writeString(msg.address);
          this.writeString("," + msg.typeTag);
        }
        i = 0;
        l = msg.typeTag.length;
        _results = [];
        while (i < l) {
          code = msg.typeTag.charAt(i);
          value = msg["arguments"][i++];
          type = OSC_TYPES[code];
          if (!type) {
            throw new Error("Type `" + code + "` isn't supported");
          }
          if (type.write) {
            _results.push(type.write(this, value));
          } else {
            _results.push(void 0);
          }
        }
        return _results;
      };

      AbstractOscPacketGenerator.prototype._generateBundle = function(bundle) {
        var elem, tag, _i, _len, _ref;
        this.writeString("#bundle");
        if (bundle.timetag <= new Date) {
          tag = [0, 1];
        } else {
          tag = toNTP(bundle.timetag);
        }
        this.writeTimetag(tag);
        _ref = bundle.elements;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          elem = _ref[_i];
          this.writeInt32(oscSizeOfMessage(elem, this.dict));
          this._generateMessage(elem);
        }
        return null;
      };

      AbstractOscPacketGenerator.prototype.writeTimetag = function(date) {
        var tag;
        tag = toNTP(date);
        this.writeUInt32(tag[0]);
        return this.writeUInt32(tag[1]);
      };

      AbstractOscPacketGenerator.prototype.generate = function() {
        if (this.bundle) {
          this._generateBundle(this.bundle);
        } else {
          this._generateMessage(this.message);
        }
        return this.buffer;
      };

      AbstractOscPacketGenerator.prototype.writeString = function(string, encoding) {
        if (encoding == null) {
          encoding = "ascii";
        }
        throw new Error("Abstract method `AbstractOscPacketGenerator::writeString` called");
      };

      return AbstractOscPacketGenerator;

    })();
    _fn = function(name) {
      name = "write" + name;
      return AbstractOscPacketGenerator.prototype[name] = function() {
        throw new Error("Abstract method `AbstractOscPacketGenerator::" + name + "` called");
      };
    };
    for (name in NUMBERS) {
      desc = NUMBERS[name];
      _fn(name);
    }
    OscArrayBufferPacketGenerator = (function(_super) {

      __extends(OscArrayBufferPacketGenerator, _super);

      function OscArrayBufferPacketGenerator(messageOrBundle, dict) {
        OscArrayBufferPacketGenerator.__super__.constructor.call(this, messageOrBundle, dict);
        this.buffer = new ArrayBuffer(this.size);
        this.view = new DataView(this.buffer);
        this.pos = 0;
      }

      OscArrayBufferPacketGenerator.prototype.writeString = function(string, encoding) {
        var char, i, l, pad, _results;
        if (encoding == null) {
          encoding = "ascii";
        }
        if (encoding !== "ascii") {
          throw new Error("OscBufferWriter::writeString only supports ASCII encoding for ArrayBuffer");
        }
        l = string.length;
        i = 0;
        while (i < l) {
          char = string.charCodeAt(i++);
          this.view.setInt8(this.pos++, char & 0x7F);
        }
        pad = oscPadding(l);
        i = 0;
        _results = [];
        while (i < pad) {
          this.view.setInt8(this.pos++, 0);
          _results.push(i++);
        }
        return _results;
      };

      OscArrayBufferPacketGenerator.prototype.writeBlob = function(buffer) {
        var array, i, l, pad;
        if (nodeBuffer && Buffer.isBuffer(buffer)) {
          l = buffer.length;
          this.writeInt32(l);
          i = 0;
          while (i < l) {
            this.view.setInt8(this.pos + i, buffer[i]);
            i++;
          }
          this.pos += l;
        } else {
          l = buffer.byteLength;
          array = new Int8Array(buffer);
          this.writeInt32(l);
          i = 0;
          while (i < l) {
            this.view.setInt8(this.pos + i, array[i]);
            i++;
          }
          this.pos += l;
        }
        pad = oscPadding(4 + l);
        if (pad && pad < 4) {
          i = 0;
          while (i < pad) {
            this.view.setInt8(this.pos + i, 0);
            i++;
          }
          return this.pos += pad;
        }
      };

      return OscArrayBufferPacketGenerator;

    })(AbstractOscPacketGenerator);
    _fn1 = function(type, desc) {
      return OscArrayBufferPacketGenerator.prototype["write" + type] = function(value) {
        value = this.view[desc.dataViewWriter](this.pos, value, false);
        this.pos += desc.size;
        return value;
      };
    };
    for (type in NUMBERS) {
      desc = NUMBERS[type];
      _fn1(type, desc);
    }
    AbstractOscPacketParser = (function() {

      function AbstractOscPacketParser(buffer, pos, dict) {
        if (pos == null) {
          pos = 0;
        }
        this.buffer = buffer;
        if (typeof pos === "object") {
          this.dict = pos;
          this.pos = 0;
        } else {
          this.dict = dict;
          this.pos = pos;
        }
      }

      AbstractOscPacketParser.prototype.parse = function() {
        var address;
        address = this.readString();
        if (address === "#bundle") {
          return this._parseBundle();
        } else {
          return this._parseMessage(address);
        }
      };

      AbstractOscPacketParser.prototype._parseMessage = function(address) {
        var args, id, isAddress, typeTag;
        if (address.charAt(0) !== '/') {
          throw new Error("An address must start with a '/'");
        }
        if (this.dict && ((isAddress = address === "/") || address === "/?")) {
          typeTag = this.readTypeTag();
          args = this.parseArguments(typeTag);
          if (typeTag.charAt(0) === "i") {
            id = args[0];
            address = isAddress ? this.dict.getAddress(id) : this.dict.getPattern(id);
            if (address) {
              typeTag = typeTag.slice(1, 1);
              args.shift();
            }
          }
        } else {
          typeTag = this.readTypeTag();
          args = this.parseArguments(typeTag);
        }
        return new Message(address, typeTag, args);
      };

      AbstractOscPacketParser.prototype._parseBundle = function() {
        var boundary, elements, size, timetag;
        timetag = this.readTimetag();
        elements = [];
        while (!this.isEnd()) {
          size = this.readInt32();
          boundary = this.pos + size;
          elements.push(this.parse());
        }
        return new Bundle(timetag, elements);
      };

      AbstractOscPacketParser.prototype.parseArguments = function(tag, boundary) {
        var i, values;
        i = 0;
        values = [];
        while (i < tag.length) {
          if (boundary && this.pos >= boundary) {
            throw new Error("Message boundary reached");
          }
          code = tag.charAt(i++);
          type = OSC_TYPES[code];
          if (!type) {
            throw new Error("Type `" + code + "` isn't supported");
          }
          values.push(type.read(this));
        }
        return values;
      };

      AbstractOscPacketParser.prototype.readTypeTag = function() {
        var tag;
        tag = this.readString();
        if (tag.charAt(0) === ',') {
          tag = tag.slice(1);
        } else {
          throw new Error("A type tag must start with a ','");
        }
        return tag;
      };

      AbstractOscPacketParser.prototype.readTimetag = function() {
        return fromNTP(this.readUInt32(), this.readUInt32());
      };

      AbstractOscPacketParser.prototype.readString = function(encoding, move) {
        throw new Error("Abstract method `AbstractOscPacketParser::writeString` called");
      };

      AbstractOscPacketParser.prototype.isEnd = function() {
        throw new Error("Abstract method `AbstractOscPacketParser::isEnd` called");
      };

      return AbstractOscPacketParser;

    })();
    _fn2 = function(name) {
      name = "read" + name;
      return AbstractOscPacketParser.prototype[name] = function() {
        throw new Error("Abstract method `AbstractOscPacketParser::" + name + "` called");
      };
    };
    for (name in NUMBERS) {
      desc = NUMBERS[name];
      _fn2(name);
    }
    OscArrayBufferPacketParser = (function(_super) {

      __extends(OscArrayBufferPacketParser, _super);

      function OscArrayBufferPacketParser(buffer, pos, dict) {
        OscArrayBufferPacketParser.__super__.constructor.apply(this, arguments);
        this.view = new DataView(this.buffer);
      }

      OscArrayBufferPacketParser.prototype.isEnd = function() {
        return this.buffer.byteLength === 0 || this.pos === this.buffer.byteLength;
      };

      OscArrayBufferPacketParser.prototype.toString = function(encoding, start, end) {
        var charCode, str;
        start = start != null ? start : 0;
        end = end != null ? end : this.buffer.byteLength;
        str = "";
        while (start < end) {
          charCode = this.view.getInt8(start++);
          str += String.fromCharCode(charCode & 0x7F);
        }
        return str;
      };

      OscArrayBufferPacketParser.prototype.readBlob = function(move) {
        var array, i, pad, size;
        if (move == null) {
          move = true;
        }
        size = this.readInt32();
        i = 0;
        array = new Int8Array(new ArrayBuffer(size));
        while (i < size) {
          array[i] = this.view.getInt8(this.pos + i);
          i++;
        }
        if (move) {
          pad = oscPadding(4 + size);
          if (pad < 4) {
            size += pad;
          }
          this.pos += size;
        }
        return array.buffer;
      };

      OscArrayBufferPacketParser.prototype.readString = function(encoding, move) {
        var length, nullSeen, pos, string, stringLength;
        if (encoding == null) {
          encoding = "ascii";
        }
        if (move == null) {
          move = true;
        }
        if (this.isEnd()) {
          throw new Error("No data left");
        }
        length = 4;
        nullSeen = false;
        while ((pos = this.pos + length - 1) < this.buffer.byteLength) {
          if (this.view.getInt8(pos) === 0) {
            nullSeen = true;
            break;
          }
          length += 4;
        }
        if (length === 0 || nullSeen === false) {
          throw new Error("No string data found");
        }
        stringLength = length - 4;
        while (stringLength < length) {
          if (this.view.getInt8(this.pos + stringLength) === 0) {
            break;
          }
          stringLength++;
        }
        string = this.toString(encoding, this.pos, this.pos + stringLength);
        if (move) {
          this.pos += length;
        }
        return string;
      };

      return OscArrayBufferPacketParser;

    })(AbstractOscPacketParser);
    _fn3 = function(type, desc) {
      return OscArrayBufferPacketParser.prototype["read" + type] = function(move) {
        var value;
        if (move == null) {
          move = true;
        }
        value = this.view[desc.dataViewReader](this.pos, false);
        if (move) {
          this.pos += desc.size;
        }
        return value;
      };
    };
    for (type in NUMBERS) {
      desc = NUMBERS[type];
      _fn3(type, desc);
    }
    fromBuffer = function(buffer, pos, dict) {
      if (nodeBuffer && Buffer.isBuffer(buffer)) {
        return new OscBufferPacketParser(buffer, pos, dict).parse();
      } else {
        return new OscArrayBufferPacketParser(buffer, pos, dict).parse();
      }
    };
    exports.NUMBERS = NUMBERS;
    exports.toNTP = toNTP;
    exports.Message = Message;
    exports.Bundle = Bundle;
    exports.Impulse = Impulse;
    exports.Dictionary = Dictionary;
    exports.AbstractOscPacketGenerator = AbstractOscPacketGenerator;
    exports.AbstractOscPacketParser = AbstractOscPacketParser;
    exports.OscArrayBufferPacketGenerator = OscArrayBufferPacketGenerator;
    exports.OscArrayBufferPacketParser = OscArrayBufferPacketParser;
    return exports.fromBuffer = fromBuffer;
  })(exports);

}).call(this);
