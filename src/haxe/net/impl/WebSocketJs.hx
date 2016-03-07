package haxe.net.impl;

import haxe.net.WebSocket;

class WebSocketJs extends WebSocket {
    private var impl:js.html.WebSocket;

    public function new(url:String, protocols:Array<String> = null) {
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
            this.onerror();
        };
        impl.onmessage = function(e:js.html.MessageEvent) {
            var m = e.data;
            if (Std.is(m, String)) {
                this.onmessageString(m);
            } else (Std.is(m, ArrayBuffer)) {
                //haxe.io.Int8Array
                //js.html.ArrayBuffer
                trace('Unhandled websocket onmessage ' + m);
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
        this.impl.send(message);
    }
}
