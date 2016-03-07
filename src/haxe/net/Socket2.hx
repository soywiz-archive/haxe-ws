package haxe.net;

// Available in all targets but javascript
import haxe.io.Bytes;

class Socket2 {
    private var host:String;
    private var port:Int;
    private var debug:Bool;

    private function new(host:String, port:Int, debug:Bool = false) {
        this.host = host;
        this.port = port;
        this.debug = debug;
    }

    public function close() {
    }

    public function process() {
    }

    public dynamic function onconnect() {
    }

    public dynamic function onclose() {
    }

    public dynamic function onerror() {
    }

    public dynamic function ondata(data:Bytes) {
    }

    public function send(data:Bytes) {
    }

    static public function create(host:String, port:Int, secure:Bool = false, debug:Bool = false):Socket2 {
        if (secure) throw 'Not supporting secure sockets';
        #if flash
        return new haxe.net.impl.SocketFlash(host, port);
        #elseif sys
        return new haxe.net.impl.SocketSys(host, port);
        #else
        #error "Unsupported platform"
        #end
    }
}
