package haxe.net;

// Available in all targets including javascript
import haxe.io.Bytes;

enum ReadyState {
	Connecting;
	Open;
	Closing;
	Closed;
}

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
	
	#if sys
	/**
	 * create server websocket from socket returned by accept()
	 * wait for onopen() to be called before using websocket
	 * @param	socket - accepted socket 
	 * @param	alredyRecieved - data already read from socket, it should be no more then full http header
	 * @param	debug - debug messages?
	 */
	static public function createFromAcceptedSocket(socket:Socket2, alreadyRecieved:String = '', debug:Bool = false):WebSocket {
		return haxe.net.impl.WebSocketGeneric.createFromAcceptedSocket(socket, alreadyRecieved, debug);
	}
	#end

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
	
	public function close() {
	}
	
	public var readyState(get, never):ReadyState;
	function get_readyState():ReadyState throw 'Not implemented';

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
