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
        socketData = new BytesRW();
        socket.onconnect = function() {
            _debug('socket connected');
            writeBytes(prepareClientHandshake(path, host, port, key, origin));
            //this.onopen();
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
    private var mask:Int;
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
                        mask = socketData.readUnsignedInt();
                    }
                    state = State.Body;
                case State.Body:
                    if (socketData.available < length) return;
                    payload.writeBytes(socketData.readBytes(length));

                    switch (opcode) {
                        case Opcode.Binary | Opcode.Text | Opcode.Continuation:
                            _debug("Received message, " + "Type: " + opcode);
                            if (isFinal) {
                                if (frameIsBinary) {
                                    this.onmessageBytes(payload.readAllAvailableBytes());
                                } else {
                                    this.onmessageString(payload.readAllAvailableBytes().toString());
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

    private function prepareFrame(data:Bytes, type:Opcode, isFinal:Bool):Bytes {
        var out = new BytesRW();
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

class BytesRW {
    public var available(default, null):Int = 0;
    private var currentOffset:Int = 0;
    private var currentData: Bytes = null;
    private var chunks:Array<Bytes> = [];

    public function writeByte(v:Int) {
        var b = Bytes.alloc(1);
        b.set(0, v);
        writeBytes(b);
    }

    public function writeShort(v:Int) {
        var b = Bytes.alloc(2);
        b.set(0, (v >> 8) & 0xFF);
        b.set(1, (v >> 0) & 0xFF);
        writeBytes(b);
    }

    public function writeInt(v:Int) {
        var b = Bytes.alloc(4);
        b.set(0, (v >> 24) & 0xFF);
        b.set(1, (v >> 16) & 0xFF);
        b.set(2, (v >> 8) & 0xFF);
        b.set(3, (v >> 0) & 0xFF);
        writeBytes(b);
    }

    public function writeBytes(data:Bytes) {
        chunks.push(data);
        available += data.length;
    }

    public function readAllAvailableBytes():Bytes {
        return readBytes(available);
    }

    public function readBytes(count:Int):Bytes {
        var count2 = Std.int(Math.min(count, available));
        var out = Bytes.alloc(count2);
        for (n in 0 ... count2) out.set(n, readByte());
        return out;
    }

    public function readUnsignedShort():UInt {
        var h = readByte();
        var l = readByte();
        return (h << 8) | (l << 0);
    }

    public function readUnsignedInt():UInt {
        var v3 = readByte();
        var v2 = readByte();
        var v1 = readByte();
        var v0 = readByte();
        return (v3 << 24) | (v2 << 16) | (v1 << 8) | (v0 << 0);
    }

    public function readByte():Int {
        if (available <= 0) throw 'Not bytes available';
        while (currentData == null || currentOffset >= currentData.length) {
            currentOffset = 0;
            currentData = chunks.shift();
        }
        available--;
        return currentData.get(currentOffset++);
    }
}