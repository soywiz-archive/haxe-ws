package haxe.net;

// Available in all targets including javascript
import haxe.io.Bytes;
class WebSocket {
    private function new() {
    }

    dynamic static public function create(url:String, protocols:Array<String> = null, origin:String = null, debug:Bool = false):WebSocket {
        #if js
        return new haxe.net.impl.WebSocketJs(url, protocols);
        #else
            #if flash
                if (haxe.net.impl.WebSocketFlashExternalInterface.available()) {
                    return new haxe.net.impl.WebSocketFlashExternalInterface(url, protocols);
                }
            #end
            return haxe.net.impl.WebSocketGeneric.create(url, protocols, origin, "wskey", debug);
        #end
    }

    static dynamic public function defer(callback: Void -> Void) {
        #if (flash || js)
        haxe.Timer.delay(callback, 0);
        #else
        callback();
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
