package haxe.net.impl;

import haxe.io.Bytes;
import sys.net.Host;
import sys.net.Socket;

class SocketSys extends Socket2 {
    private var impl:sys.net.Socket;
    private var sendConnect:Bool = false;
    private var sendError:Bool = false;
    private var secure:Bool;

    public function new(host:String, port:Int, secure:Bool, debug:Bool = false) {
        super(host, port, debug);
        this.secure = secure;
        var impl:Dynamic = null;
        if (secure) {
            throw 'Not supporting secure sockets';
        } else {
            this.impl = new sys.net.Socket();
        }
        try {
            this.impl.connect(new Host(host), port);
            //this.impl.setFastSend(true);
            this.impl.setBlocking(false);
            //this.impl.setBlocking(true);
            this.sendConnect = true;
            if (debug) trace('socket.connected!');
        } catch (e:Dynamic) {
            this.sendError = true;
            if (debug) trace('socket.error! $e');
        }
    }

    override public function close() {
    }

    override public function process() {
        if (sendConnect) {
            if (debug) trace('socket.onconnect!');
            sendConnect = false;
            onconnect();
        }

        if (sendError) {
            if (debug) trace('socket.onerror!');
            sendError = false;
            onerror();
        }

        var result = sys.net.Socket.select([this.impl], [this.impl], [this.impl], 0.4);

        if (result.read.length > 0) {
            var out = new BytesRW();
            try {
                var input = this.impl.input;
                while (true) {
                    var data = Bytes.alloc(1024);
                    var readed = input.readBytes(data, 0, data.length);
                    if (readed <= 0) break;
                    out.writeBytes(data.sub(0, readed));
                }
            } catch (e:Dynamic) {

            }
            ondata(out.readAllAvailableBytes());
        }
    }

    override public dynamic function onconnect() {
    }

    override public dynamic function onclose() {
    }

    override public dynamic function onerror() {
    }

    override public dynamic function ondata(data:Bytes) {
    }

    override public function send(data:Bytes) {
        //trace('sending:$data');
        var output:haxe.io.Output = this.impl.output;
        output.write(data);
        output.flush();
        //this.impl.write
    }
}
