package haxe.net.impl;

import haxe.io.Bytes;
import haxe.net.WebSocket;

#if (haxe_ver >= 4.2)
import Std.isOfType;
#else
import Std.is as isOfType;
#end


class WebSocketJs extends WebSocket {
    private var impl:js.html.WebSocket;

    public function new(url:String, protocols:Array<String> = null) {
        super();

        if (protocols != null) {
            impl = new js.html.WebSocket(url, protocols);
        } else {
            impl = new js.html.WebSocket(url);
        }
        impl.onopen = function(e:js.html.Event) {
            this.onopen();
        };
        impl.onclose = function(e:js.html.Event) {
            this.onclose();
        };
        impl.onerror = function(e:js.html.Event) {
            this.onerror('error');
        };
        impl.onmessage = function(e:js.html.MessageEvent) {
            var m = e.data;
            if (isOfType(m, String)) {
                this.onmessageString(m);
            } else if (isOfType(m, js.html.ArrayBuffer)) {
                //haxe.io.Int8Array
                //js.html.ArrayBuffer
                trace('Unhandled websocket onmessage ' + m);
            } else if (isOfType(m, js.html.Blob)) {
				var arrayBuffer : js.html.ArrayBuffer;
				var fileReader = new js.html.FileReader();
				fileReader.onload = function() {
					arrayBuffer = fileReader.result;
					this.onmessageBytes(Bytes.ofData(arrayBuffer));
				}
				fileReader.readAsArrayBuffer(cast (m, js.html.Blob));
            } else {
                //ArrayBuffer
                trace('Unhandled websocket onmessage ' + m);
            }
        };
    }

    override public function sendString(message:String) {
        this.impl.send(message);
    }

    override public function sendBytes(message:Bytes) {
//	Separate message data, because 'message.getData().length' not equal 'message.length'
	message = message.sub(0, message.length);
        this.impl.send(message.getData());
    }
	
	override public function close() {
		this.impl.close();
	}
	
	override function get_readyState():ReadyState {
		return switch(this.impl.readyState) {
    		case js.html.WebSocket.OPEN: ReadyState.Open;
			case js.html.WebSocket.CLOSED: ReadyState.Closed;
			case js.html.WebSocket.CLOSING: ReadyState.Closing;
			case js.html.WebSocket.CONNECTING: ReadyState.Connecting;
			default: throw 'Unexpected websocket state';
		}
	}
}
