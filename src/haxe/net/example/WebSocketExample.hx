package haxe.net.example;

class WebSocketExample {
    static public function main() {
        trace('testing!');
        var ws = WebSocket.create("ws://127.0.0.1:8000/", ['echo-protocol'], false);
        ws.onopen = function() {
            trace('open!');
            ws.sendString('hello friend!');
            ws.sendString('hello my dearest friend! this is a longer message! which is longer than 126 bytes, so it sends a short instead of just a single byte. And yeah, it should be longer thant that by now!');
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
