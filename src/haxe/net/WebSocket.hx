package haxe.net;

// Available in all targets including javascript
import haxe.io.Bytes;
class WebSocket {
    private function new() {
    }

    static public function create(url:String, protocols:Array<String> = null):WebSocket {
        #if js
        return new haxe.net.impl.WebSocketJs(url, protocols);
        #else
        return new haxe.net.impl.WebSocketGeneric(url, protocols);
        #end
    }

    public function process() {
    }

    public function sendString(message:String) {
    }

    public function sendBytes(message:Bytes) {
    }

    public dynamic function onopen():Void {
    }

    public dynamic function onerror(message:String):Void {
    }

    public dynamic function onmessageString(message:String):Void {
    }

    public dynamic function onmessageBytes(message:Bytes):Void {
    }

    public dynamic function onclose():Void {
    }
}
