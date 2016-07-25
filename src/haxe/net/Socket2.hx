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

    dynamic static public function create(host:String, port:Int, secure:Bool = false, debug:Bool = false):Socket2 {
        #if flash
        return new haxe.net.impl.SocketFlash(host, port, secure, debug);
        #elseif sys
        return new haxe.net.impl.SocketSys(host, port, secure, debug);
        #else
        #error "Unsupported platform"
        #end
    }
}
