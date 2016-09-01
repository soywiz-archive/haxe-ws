package haxe.net.impl;

import haxe.crypto.Base64;
import haxe.io.Bytes;
class WebSocketGeneric extends WebSocket {
    private var socket:Socket2;
    private var origin = "http://127.0.0.1/";
    private var scheme = "ws";
    private var key = "wskey";
    private var host = "127.0.0.1";
    private var port = 80;
    private var path = "/";
    private var secure = false;
    private var protocols = [];
    private var state = State.Handshake;
	public var isClosed:Bool = false;
    public var debug:Bool = true;

    public function new(uri:String, protocols:Array<String> = null, origin:String = null, key:String = "wskey", debug:Bool = true) {
        super();
        if (origin == null) origin = "http://127.0.0.1/";
        this.protocols = protocols;
        this.origin = origin;
        this.key = key;
        this.debug = debug;
        var reg = ~/^(\w+?):\/\/([\w\.-]+)(:(\d+))?(\/.*)?$/;
        //var reg = ~/^(\w+?):/;
        if (!reg.match(uri)) throw 'Uri not matching websocket uri "${uri}"';
        scheme = reg.matched(1);
        switch (scheme) {
            case "ws": secure = false;
            case "wss": secure = true;
            default: throw 'Scheme "${scheme}" is not a valid websocket scheme';
        }
        host = reg.matched(2);
        port = (reg.matched(4) != null) ? Std.parseInt(reg.matched(4)) : (secure ? 443 : 80);
        path = reg.matched(5);
		if (path == null) path = '/';
        //trace('$scheme, $host, $port, $path');

        socket = Socket2.create(host, port, secure, debug);
        state = State.Handshake;
        socketData = new BytesRW();
        socket.onconnect = function() {
            _debug('socket connected');
            writeBytes(prepareClientHandshake(path, host, port, key, origin));
            //this.onopen();
        };
        socket.onclose = function() {
            _debug('socket closed');
            setClosed();
        };
        socket.onerror = function() {
            _debug('ioerror: ');
            this.onerror('error');
        };
        socket.ondata = function(data:Bytes) {
            socketData.writeBytes(data);
            handleData();
        };


    }

    override public function process() {
        socket.process();
    }

    private function _debug(msg:String, ?p:PosInfos):Void {
        if (!debug) return;
        haxe.Log.trace(msg, p);
    }

    private function writeBytes(data:Bytes) {
        //if (socket == null || !socket.connected) return;
        try {
            socket.send(data);
        } catch (e:Dynamic) {
            trace(e);
        }
    }

    private var socketData:BytesRW;
    private var isFinal:Bool;
    private var isMasked:Bool;
    private var opcode:Opcode;
    private var frameIsBinary:Bool;
    private var partialLength:Int;
    private var length:Int;
    private var mask:Bytes;
    private var httpHeader:String = "";
    private var lastPong:Date = null;
    private var payload:BytesRW = null;

    private function handleData() {
        while (true) {
            if (payload == null) payload = new BytesRW();

            switch (state) {
                case State.Handshake:
                    var found = false;
                    while (socketData.available > 0) {
                        httpHeader += String.fromCharCode(socketData.readByte());
                        //trace(httpHeader.substr( -4));
                        if (httpHeader.substr(-4) == "\r\n\r\n") {
                            found = true;
                            break;
                        }
                    }
                    if (!found) return;

                    this.onopen();

                    state = State.Head;
                case State.Head:
                    if (socketData.available < 2) return;
                    var b0 = socketData.readByte();
                    var b1 = socketData.readByte();

                    isFinal = ((b0 >> 7) & 1) != 0;
                    opcode = cast(((b0 >> 0) & 0xF), Opcode);
                    frameIsBinary = if (opcode == Opcode.Text) false; else if (opcode == Opcode.Binary) true; else frameIsBinary;
                    partialLength = ((b1 >> 0) & 0x7F);
                    isMasked = ((b1 >> 7) & 1) != 0;

                    state = State.HeadExtraLength;
                case State.HeadExtraLength:
                    if (partialLength == 126) {
                        if (socketData.available < 2) return;
                        length = socketData.readUnsignedShort();
                    } else if (partialLength == 127) {
                        if (socketData.available < 4) return;
                        length = socketData.readUnsignedInt();
                    } else {
                        length = partialLength;
                    }
                    state = State.HeadExtraMask;
                case State.HeadExtraMask:
                    if (isMasked) {
                        if (socketData.available < 4) return;
                        mask = socketData.readBytes(4);
                    }
                    state = State.Body;
                case State.Body:
                    if (socketData.available < length) return;
                    payload.writeBytes(socketData.readBytes(length));

                    switch (opcode) {
                        case Opcode.Binary | Opcode.Text | Opcode.Continuation:
                            _debug("Received message, " + "Type: " + opcode);
                            if (isFinal) {
                                var messageData = payload.readAllAvailableBytes();
                                var unmakedMessageData = (isMasked) ? applyMask(messageData, mask) : messageData;
                                if (frameIsBinary) {
                                    this.onmessageBytes(unmakedMessageData);
                                } else {
                                    this.onmessageString(Utf8Encoder.decode(unmakedMessageData));
                                }
                                payload = null;
                            }
                        case Opcode.Ping:
                            _debug("Received Ping");
                            //onPing.dispatch(null);
                            sendFrame(payload.readAllAvailableBytes(), Opcode.Pong);
                        case Opcode.Pong:
                            _debug("Received Pong");
                            //onPong.dispatch(null);
                            lastPong = Date.now();
                        case Opcode.Close:
                            _debug("Socket Closed");
							setClosed();
							socket.close();
                    }
                    state = State.Head;
                default:
                    return;
            }
        }

        //trace('data!' + socket.bytesAvailable);
        //trace(socket.readUTFBytes(socket.bytesAvailable));
    }
	
	private function setClosed() {
		if (!isClosed) {
			isClosed = true;
			onclose();
		}
	}

    private function ping() {
        sendFrame(Bytes.alloc(0), Opcode.Ping);
    }

    private function prepareClientHandshake(url:String, host:String, port:Int, key:String, origin:String):Bytes {
        var lines = [];
        lines.push('GET ${url} HTTP/1.1');
        lines.push('Host: ${host}:${port}');
        lines.push('Pragma: no-cache');
        lines.push('Cache-Control: no-cache');
        lines.push('Upgrade: websocket');
        if (this.protocols != null) {
            lines.push('Sec-WebSocket-Protocol: ' + this.protocols.join(', '));
        }
        lines.push('Sec-WebSocket-Version: 13');
        lines.push('Connection: Upgrade');
        lines.push("Sec-WebSocket-Key: " + Base64.encode(Utf8Encoder.encode(key)));
        lines.push('Origin: ${origin}');
        lines.push('User-Agent: Mozilla/5.0');

        return Utf8Encoder.encode(lines.join("\r\n") + "\r\n\r\n");
    }

    override public function close() {
        sendFrame(Bytes.alloc(0), Opcode.Close);
        socket.close();
		setClosed();
    }

    private function sendFrame(data:Bytes, type:Opcode) {
        writeBytes(prepareFrame(data, type, true));
    }

    override public function sendString(message:String) {
        sendFrame(Utf8Encoder.encode(message), Opcode.Text);
    }

    override public function sendBytes(message:Bytes) {
        sendFrame(message, Opcode.Binary);
    }

    static private function generateMask() {
        var maskData = Bytes.alloc(4);
        maskData.set(0, Std.random(256));
        maskData.set(1, Std.random(256));
        maskData.set(2, Std.random(256));
        maskData.set(3, Std.random(256));
        return maskData;
    }

    static private function applyMask(payload:Bytes, mask:Bytes) {
        var maskedPayload = Bytes.alloc(payload.length);
        for (n in 0 ... payload.length) maskedPayload.set(n, payload.get(n) ^ mask.get(n % mask.length));
        return maskedPayload;
    }

    private function prepareFrame(data:Bytes, type:Opcode, isFinal:Bool):Bytes {
        var out = new BytesRW();
        var isMasked = true; // All clientes messages must be masked: http://tools.ietf.org/html/rfc6455#section-5.1
        var mask = generateMask();
        var sizeMask = (isMasked ? 0x80 : 0x00);

        out.writeByte(type.toInt() | (isFinal ? 0x80 : 0x00));

        if (data.length < 126) {
            out.writeByte(data.length | sizeMask);
        } else if (data.length < 65536) {
            out.writeByte(126 | sizeMask);
            out.writeShort(data.length);
        } else {
            out.writeByte(127 | sizeMask);
            out.writeInt(data.length);
        }

        if (isMasked) out.writeBytes(mask);

        out.writeBytes(isMasked ? applyMask(data, mask) : data);
        return out.readAllAvailableBytes();
    }
}

enum State {
    Handshake;
    Head;
    HeadExtraLength;
    HeadExtraMask;
    Body;
}

@:enum abstract WebSocketCloseCode(Int) {
    var Normal = 1000;
    var Shutdown = 1001;
    var ProtocolError = 1002;
    var DataError = 1003;
    var Reserved1 = 1004;
    var NoStatus = 1005;
    var CloseError = 1006;
    var UTF8Error = 1007;
    var PolicyError = 1008;
    var TooLargeMessage = 1009;
    var ClientExtensionError = 1010;
    var ServerRequestError = 1011;
    var TLSError = 1015;
}

@:enum abstract Opcode(Int) {
    var Continuation = 0x00;
    var Text = 0x01;
    var Binary = 0x02;
    var Close = 0x08;
    var Ping = 0x09;
    var Pong = 0x0A;

    @:to public function toInt() {
        return this;
    }
}

class Utf8Encoder {
    static public function encode(str:String):Bytes {
        // @TODO: Proper utf8 encoding!
        return Bytes.ofString(str);
    }

    static public function decode(data:Bytes):String {
        // @TODO: Proper utf8 decoding!
        return data.toString();
    }
}

