package haxe.net.impl;

import haxe.io.Bytes;
import flash.external.ExternalInterface;
import haxe.extern.EitherType;

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
                ws.onmessage = function(e) { flashObj.websocketRecv(index, e.data); }
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
        ExternalInterface.addCallback('websocketRecv', function(index:Int, data:Dynamic) {
            if (debug) trace('js.websocketRecv[$index]: $data');
            WebSocket.defer(function() {
                sockets[index].onmessageString(data);
            });
        });
    }

    override public function sendBytes(message:Bytes) {
        _send(message);
    }

    override public function sendString(message:String) {
        _send(message);
    }

    private function _send(message:Dynamic) {
        WebSocket.defer(function() {
            var success = ExternalInterface.call("function(index, message) {
                try {
                    window.websocketjsList[index].send(message);
                    return true;
                } catch (e) {
                    return 'error:' + e;
                }
            }", this.index, message);
        });
    }

    override public function process() {
    }

    static public function available():Bool {
        return ExternalInterface.available && ExternalInterface.call('function() { return (typeof WebSocket) != "undefined"; }');
    }
}
