package haxe.net.example;

import haxe.CallStack;
import haxe.Json;
import haxe.io.Bytes;
import haxe.net.WebSocketServer;

class WebSocketServerExample {
	
	static function main() {
		var port = 8000;
		var server = WebSocketServer.create('0.0.0.0', port, 1, true);
		while (true) {
			try{
				trace('listening on port $port');
			
				var websocket = server.accept();
				
				websocket.onmessageString = function(message:String) {
					trace('Recieved message: $message');
					websocket.sendString('Your message was: $message');
				}
				
				websocket.onmessageBytes = function(message:Bytes) {
					trace('Recieved bytes message: $message');
					websocket.sendBytes(message);
				}
				
				websocket.onclose = function() {
					trace('websocket closed');
					websocket = null;
				}
				
				websocket.sendString('hello from server');
				
				var n = 0;
				while (websocket != null) {
					websocket.process();
					Sys.sleep(0.5);
				}
			}
			catch (e:Dynamic) {
				trace('Error', e);
				trace(CallStack.exceptionStack());
			}
		}
	}
	
}