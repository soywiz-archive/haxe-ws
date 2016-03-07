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
    private var state = State.Handshake;
    public var debug:Bool = true;

    public function new(uri:String, origin:String = "http://127.0.0.1/", key:String = "wskey", debug:Bool = true) {
        this.origin = origin;
        this.key = key;
        this.debug = debug;
        var reg = ~/^(\w+?):\/\/([\w\.]+)(:(\d+))?(\/.*)?$/;
        //var reg = ~/^(\w+?):/;
        if (!reg.match(uri)) throw 'Uri not matching websocket uri "${uri}"';
        scheme = reg.matched(1);
        switch (scheme) {
            case "ws": secure = false;
            case "wss:": secure = true; throw 'Not supporting secure websockets';
            default: throw 'Scheme "${host}" is not a valid websocket scheme';
        }
        host = reg.matched(2);
        port = (reg.matched(4) != null) ? Std.parseInt(reg.matched(4)) : 80;
        path = reg.matched(5);
        //trace('$scheme, $host, $port, $path');

        socket = Socket2.create();
        state = State.Handshake;
        socket.onconnect = function() {
            _debug('socket connected');
            writeBytes(prepareClientHandshake(path, host, port, key, origin));
            this.onopen();
        };
        socket.onclose = function() {
            _debug('socket closed');
            this.onclose();
        };
        socket.onerror = function() {
            _debug('ioerror: ');
            this.onerror('error');
        };
        socket.ondata = function(data:Bytes) {
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

    private var isFinal:Bool;
    private var isMasked:Bool;
    private var opcode:Opcode;
    private var frameIsBinary:Bool;
    private var partialLength:Int;
    private var length:Int;
    private var mask:Int;
    private var httpHeader:String = "";
    private var lastPong:Date = null;
    private var payload:Bytes = null;

    private function handleData() {
        while (true) {
            if (payload == null) {
                payload = new ByteArray();
                payload.endian = Endian.BIG_ENDIAN;
            }
            switch (state) {
                case State.Handshake:
                    var found = false;
                    while (socket.bytesAvailable > 0) {
                        httpHeader += String.fromCharCode(socket.readByte());
                        //trace(httpHeader.substr( -4));
                        if (httpHeader.substr(-4) == "\r\n\r\n") {
                            found = true;
                            break;
                        }
                    }
                    if (!found) return;

                    onOpen.dispatch();

                    state = State.Head;
                case State.Head:
                    if (socket.bytesAvailable < 2) return;
                    var b0 = socket.readByte();
                    var b1 = socket.readByte();

                    isFinal = ((b0 >> 7) & 1) != 0;
                    opcode = cast(((b0 >> 0) & 0xF), Opcode);
                    frameIsBinary = if (opcode == Opcode.Text) false; else if (opcode == Opcode.Binary) true; else frameIsBinary;
                    partialLength = ((b1 >> 0) & 0x7F);
                    isMasked = ((b1 >> 7) & 1) != 0;

                    state = State.HeadExtraLength;
                case State.HeadExtraLength:
                    if (partialLength == 126) {
                        if (socket.bytesAvailable < 2) return;
                        length = socket.readUnsignedShort();
                    } else if (partialLength == 127) {
                        if (socket.bytesAvailable < 4) return;
                        length = socket.readUnsignedInt();
                    } else {
                        length = partialLength;
                    }
                    state = State.HeadExtraMask;
                case State.HeadExtraMask:
                    if (isMasked) {
                        if (socket.bytesAvailable < 4) return;
                        mask = socket.readUnsignedInt();
                    }
                    state = State.Body;
                case State.Body:
                    if (socket.bytesAvailable < length) return;
                    socket.readBytes(payload);

                    switch (opcode) {
                        case Opcode.Binary | Opcode.Text | Opcode.Continuation:
                            _debug("Received message, " + "Type: " + opcode);
                            if (isFinal) {
                                if (frameIsBinary) {
                                    this.onmessageBytes(payload);
                                } else {
                                    this.onmessageString(payload.toString());
                                }
                                payload = null;
                            }
                        case Opcode.Ping:
                            _debug("Received Ping");
                            //onPing.dispatch(null);
                            sendFrame(payload, Opcode.Pong);
                        case Opcode.Pong:
                            _debug("Received Pong");
                            //onPong.dispatch(null);
                            lastPong = Date.now();
                        case Opcode.Close:
                            _debug("Socket Closed");
                        //onClose.dispatch(null);
                        //socket.close();
                    }
                    state = State.Head;
                default:
                    return;
            }
        }

        //trace('data!' + socket.bytesAvailable);
        //trace(socket.readUTFBytes(socket.bytesAvailable));
    }

    private function ping() {
        sendFrame(Bytes.alloc(0), Opcode.Ping);
    }

    private function prepareClientHandshake(url:String, host:String, port:Int, key:String, origin:String):Bytes {
        var lines = [
            'GET ${url} HTTP/1.1',
            'Host: ${host}:${port}',
            'Pragma:no-cache',
            'Cache-Control:no-cache',
            'Upgrade: websocket',
            'Sec-WebSocket-Version: 13',
            'Connection: Upgrade',
            "Sec-WebSocket-Key: " + Base64.encode(Bytes.ofString(key)),
            'Origin: ${origin}',
            'User-Agent:Mozilla/5.0'
        ];

        return Bytes.ofString(lines.join("\r\n") + "\r\n\r\n");
    }

    public function sendText(data:String) {
        sendFrame(Bytes.ofString(data), Opcode.Text);
    }

    public function sendBinary(data:Bytes) {
        sendFrame(data, Opcode.Binary);
    }

    public function close() {
        sendFrame(Bytes.alloc(0), Opcode.Close);
        socket.close();
    }

    private function sendFrame(data:Bytes, type:Opcode) {
        writeBytes(prepareFrame(data, type, true));
    }

    private function prepareFrame(data:Bytes, type:Opcode, isFinal:Bool) {
        var out:ByteArray = new ByteArray();
        out.endian = Endian.BIG_ENDIAN;
        var isMasked = false;
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

        out.writeBytes(data);
        return out;
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