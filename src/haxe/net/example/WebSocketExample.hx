package haxe.net.example;

class WebSocketExample {
    static public function main() {
        trace('testing!');
        var ws = WebSocket.create("ws://127.0.0.1:8000/", ['echo-protocol'], false);
        ws.onopen = function() {
            trace('open!');
            ws.sendString('hello friend!');
        };
        ws.onmessageString = function(message) {
            trace('message from server!' + message);
        };

        #if sys
        while (true) {
            ws.process();
            Sys.sleep(0.1);
        }
        #end
    }
}
