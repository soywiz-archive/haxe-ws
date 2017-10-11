package haxe.net.impl;

import flash.net.SecureSocket;
import haxe.io.Bytes;
import flash.utils.ByteArray;
import flash.events.ProgressEvent;
import flash.events.IOErrorEvent;
import flash.events.SecurityErrorEvent;
import flash.events.Event;
import flash.utils.Endian;
import flash.net.Socket;

class SocketFlash extends Socket2 {
    private var impl: Socket;

    public function new(host:String, port:Int, secure:Bool, debug:Bool = false) {
        super(host, port, debug);

        //debug = true;

        this.debug = debug;

        this.impl = secure ? new SecureSocket() : new Socket();
        this.impl.endian = Endian.BIG_ENDIAN;
        this.impl.addEventListener(flash.events.Event.CONNECT, function(e:Event) {
            if (debug) trace('SocketFlash.connect');
            this.onconnect();
        });
        this.impl.addEventListener(flash.events.Event.CLOSE, function(e:Event) {
            if (debug) trace('SocketFlash.close');
            this.onclose();
        });
        this.impl.addEventListener(flash.events.IOErrorEvent.IO_ERROR, function(e:IOErrorEvent) {
            if (debug) trace('SocketFlash.io_error');
            this.onerror();
        });
        this.impl.addEventListener(flash.events.SecurityErrorEvent.SECURITY_ERROR, function(e:SecurityErrorEvent) {
            if (debug) trace('SocketFlash.securityError');
            this.onerror();
        });
        this.impl.addEventListener(flash.events.ProgressEvent.SOCKET_DATA, function(e:ProgressEvent) {
            var out = new ByteArray();
            impl.readBytes(out, 0, impl.bytesAvailable);
            out.position = 0;
            if (debug) trace('SocketFlash.socket_data:' + out.toString());
            this.ondata(Bytes.ofData(out));
        });

        this.impl.connect(host, port);
    }

    override public function close() {
        impl.close();
    }

    override public function send(data:Bytes) {
        var ba:ByteArray = data.getData();
        if (debug) {
            trace('SocketFlash.send($ba) : ${ba.position} : ${ba.length}');
        }
        impl.writeBytes(ba);
        impl.flush();
    }
}
