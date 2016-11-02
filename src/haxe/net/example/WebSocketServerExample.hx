package haxe.net.example;

import haxe.CallStack;
import haxe.Json;
import haxe.io.Bytes;
import haxe.net.WebSocket;
import haxe.net.WebSocketServer;

class WebSocketHandler {
	static var _nextId = 0;
	var _id = _nextId++;
	var _websocket:WebSocket;
	
	public function new(websocket:WebSocket) {
		_websocket = websocket;
		_websocket.onopen = onopen;
		_websocket.onclose = onclose;
		_websocket.onerror = onerror;
		_websocket.onmessageBytes = onmessageBytes;
		_websocket.onmessageString = onmessageString;
	}
	
	public function update():Bool {
		_websocket.process();
		return _websocket.readyState != Closed;
	}
	
    function onopen():Void {
		trace('$_id:open');
		_websocket.sendString('Hello from server');
    }

    function onerror(message:String):Void {
		trace('$_id:error: $message');
    }

    function onmessageString(message:String):Void {
		trace('$_id:message: $message');
		_websocket.sendString(message);
    }

    function onmessageBytes(message:Bytes):Void {
		trace('$_id:message bytes:' + message.toHex());
		_websocket.sendBytes(message);
    }

    function onclose():Void {
		trace('$_id:close');
    }
}

class WebSocketServerExample {
	
	static function main() {
		var port = 8000;
		var server = WebSocketServer.create('0.0.0.0', port, 1, true);
		var handlers = [];
		trace('listening on port $port');
		while (true) {
			try{
			
				var websocket = server.accept();
				if (websocket != null) {
					handlers.push(new WebSocketHandler(websocket));
				}
				
				var toRemove = [];
				for (handler in handlers) {
					if (!handler.update()) {
						toRemove.push(handler);
					}
				}
				
				while (toRemove.length > 0)
					handlers.remove(toRemove.pop());
					
				Sys.sleep(0.1);
			}
			catch (e:Dynamic) {
				trace('Error', e);
				trace(CallStack.exceptionStack());
			}
		}
	}
	
}