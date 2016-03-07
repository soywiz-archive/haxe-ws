package haxe.net;

// Available in all targets but javascript
import haxe.io.Bytes;

class Socket2 {
    private var host:String;
    private var port:Int;

    private function new(host:String, port:Int) {
        this.host = host;
        this.port = port;
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

    static public function create(ip:String, port:Int):Socket2 {
        #if flash
        return new haxe.net.impl.SocketFlash(ip, port);
        #elseif sys
        return new haxe.net.impl.SocketSys(ip, port);
        #else
        #error "Unsupported platform"
        #end
    }
}
