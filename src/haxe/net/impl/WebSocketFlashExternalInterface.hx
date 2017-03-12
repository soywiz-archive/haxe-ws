package haxe.net.impl;

import flash.external.ExternalInterface;
import haxe.extern.EitherType;
import haxe.io.Bytes;
import haxe.io.BytesData;

class WebSocketFlashExternalInterface extends WebSocket {
    private var index:Int;
    static private var debug:Bool = false;

    static private var sockets = new Map<Int, WebSocketFlashExternalInterface>();

    public function new(url:String, protocols:Array<String> = null) {
        super();
        initializeOnce();

        this.index = ExternalInterface.call("function() {window.websocketjsList = window.websocketjsList || []; return window.websocketjsList.length; }");
        sockets[this.index] = this;

        var result:EitherType<Bool,String> = ExternalInterface.call("function(uri, protocols, index, objectID) {
            try {
                var flashObj = document.getElementById(objectID);
                var ws = (protocols != null) ? new WebSocket(uri, protocols) : new WebSocket(uri);
                ws.binaryType = 'arraybuffer';
                if (window.websocketjsList[index]) {
                    try {
                        window.websocketjsList[index].close();
                    } catch (e) {
                    }
                }
                window.websocketjsList[index] = ws;
                ws.onopen = function(e) { flashObj.websocketOpen(index); }
                ws.onclose = function(e) { flashObj.websocketClose(index); }
                ws.onerror = function(e) { flashObj.websocketError(index); }
                ws.onmessage = function(e) {
                    if (typeof e.data == 'string')
                        flashObj.websocketRecvString(index, e.data);
                    else
                        flashObj.websocketRecvBinary(index, Array.from(new Uint8Array(e.data)));
                }
                return true;
            } catch (e) {
                return 'error:' + e;
            }
        }", url, protocols, this.index, ExternalInterface.objectID);
        if(result != true) {
            throw result;
        }
    }

    static private var initializedOnce:Bool = false;
    static public function initializeOnce():Void {
        if (initializedOnce) return;
        if (debug) trace('Initializing websockets with javascript!');
        initializedOnce = true;
        ExternalInterface.addCallback('websocketOpen', function(index:Int) {
            if (debug) trace('js.websocketOpen[$index]');
            WebSocket.defer(function() {
                sockets[index].onopen();
            });
        });
        ExternalInterface.addCallback('websocketClose', function(index:Int) {
            if (debug) trace('js.websocketClose[$index]');
            WebSocket.defer(function() {
                sockets[index].onclose();
            });
        });
        ExternalInterface.addCallback('websocketError', function(index:Int) {
            if (debug) trace('js.websocketError[$index]');
            WebSocket.defer(function() {
                sockets[index].onerror('error');
            });
        });
        ExternalInterface.addCallback('websocketRecvString', function(index:Int, data:Dynamic) {
            if (debug) trace('js.websocketRecvString[$index]: $data');
            WebSocket.defer(function() {
                sockets[index].onmessageString(data);
            });
        });
        ExternalInterface.addCallback('websocketRecvBinary', function(index:Int, data:Dynamic) {
            if (debug) trace('js.websocketRecvBinary[$index]: $data');
            WebSocket.defer(function() {
                var bytes = new BytesData();
                for (index in 0...data.length)
                    bytes.writeByte(data[index]);
                sockets[index].onmessageBytes(Bytes.ofData(bytes));
            });
        });
    }

    override public function sendBytes(message:Bytes) {
        //_send(message.getData());
        
        var data = new Array<Int>();
        for (index in 0...message.length)
            data[index] = message.getInt32(index) & 0xFF;
        
        WebSocket.defer(function() {
            var result:EitherType<Bool,String> = ExternalInterface.call("function(index, data) {
                try {
                    window.websocketjsList[index].send(new Uint8Array(data).buffer);
                    return true;
                } catch (e) {
                    return 'error:' + e;
                }
            }", this.index, data);
            
            if(result != true) {
                throw result;
            }
        });
    }

    override public function sendString(message:String) {
        WebSocket.defer(function() {
            var result:EitherType<Bool,String> = ExternalInterface.call("function(index, message) {
                try {
                    window.websocketjsList[index].send(message);
                    return true;
                } catch (e) {
                    return 'error:' + e;
                }
            }", this.index, message);
            
            if(result != true) {
                throw result;
            }
        });
    }

    override public function process() {
    }

    static public function available():Bool {
        return ExternalInterface.available && ExternalInterface.call('function() { return (typeof WebSocket) != "undefined"; }');
    }
}
