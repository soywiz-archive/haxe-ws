package haxe.net.example;

import haxe.io.Bytes;
class WebSocketExample {
    static public function main() {

        trace('testing!');
        var ws = WebSocket.create("ws://127.0.0.1:8000/test", ['echo-protocol'], false);
        ws.onopen = function() {
            trace('open!');
            ws.sendString('hello friend!');
        };
        ws.onmessageString = function(message) {
            trace('message from server!' + message);
        };


        //while (true) {
        //    ws.process();
        //    Sys.sleep(0.1);
        //}


        //var socket = Socket2.create('127.0.0.1', 8000);
//
        //socket.onconnect = function() {
        //    trace('connected!');
        //    socket.send(Bytes.ofString("gogogogog!"));
        //};
//
        //socket.ondata = function(data) {
        //    trace('data: ' + data);
        //};
//
        //while (true) {
        //    socket.process();
        //    Sys.sleep(0.1);
        //}
    }
}
