package haxe.net.impl;

import haxe.io.Bytes;
import sys.net.Host;
import sys.net.Socket;

class SocketSys extends Socket2 {
    private var impl:sys.net.Socket;
    private var sendConnect:Bool = false;
    private var sendError:Bool = false;

    public function new(host:String, port:Int, debug:Bool = false) {
        super(host, port, debug);
        this.impl = new sys.net.Socket();
        try {
            this.impl.connect(new Host(host), port);
            //this.impl.setFastSend(true);
            this.impl.setBlocking(false);
            //this.impl.setBlocking(true);
            this.sendConnect = true;
        } catch (e:Dynamic) {
            this.sendError = true;
        }

        //this.impl.output.writeByte(6);
    }

    override public function close() {
    }

    override public function process() {
        if (sendConnect) {
            sendConnect = false;
            onconnect();
        }

        if (sendError) {
            sendError = false;
            onerror();
        }

        var result = Socket.select([this.impl], [this.impl], [this.impl], 0.4);

        if (result.read.length > 0) {
            var out = new BytesRW();
            try {
                while (true) {
                    var data = Bytes.alloc(1024);
                    var readed = this.impl.input.readBytes(data, 0, data.length);
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
        this.impl.output.write(data);
        this.impl.output.flush();
        //this.impl.write
    }
}
