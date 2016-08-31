package haxe.net;
import haxe.crypto.Base64;
import haxe.crypto.Sha1;
import haxe.io.Bytes;
import haxe.net.impl.SocketSys;
import haxe.net.impl.WebSocketGeneric;
import sys.net.Host;
import sys.net.Socket;

class WebSocketServer { 

	var _isDebug:Bool;
	var _listenSocket:Socket;
	
	function new(host:String, port:Int, maxConnections:Int, isDebug:Bool) {
		_isDebug = isDebug;
		_listenSocket = new Socket();
		_listenSocket.bind(new Host(host), port);
		_listenSocket.listen(maxConnections);
	}
	
	public static function create(host:String, port:Int, maxConnections:Int, isDebug:Bool) {
		return new WebSocketServer(host, port, maxConnections, isDebug);
	}
	
	@:access(haxe.net.impl.WebSocketGeneric.createFromExistingSocket)
	@:access(haxe.net.impl.SocketSys.createFromExistingSocket)
	public function accept() {
		var socket = _listenSocket.accept();
		
		var requestLines:Array<String> = [];
		
		while(true) {
			var line = socket.input.readLine();
			if (line == '') break;
			requestLines.push(line);
		}
		
		if (_isDebug) trace('Recieved request: \n${requestLines.join("\n")}');
		
		{
			var request = requestLines.shift();
			var regexp = ~/^GET (.*) HTTP\/1.1$/;
			if (!regexp.match(request)) throw 'bad request';
			var url = regexp.matched(1);
			//TODO check url
		}
		
		var acceptKey:String = {
			var key:String = null;
			var version:String = null;
			var upgrade:String = null;
			var connection:String = null;
			var regexp = ~/^(.*): (.*)$/;
			for (header in requestLines) {
				if (!regexp.match(header)) throw 'bad request';
				var name = regexp.matched(1);
				var value = regexp.matched(2);
				switch(name) {
					case 'Sec-WebSocket-Key': key = value;
					case 'Sec-WebSocket-Version': version = value;
					case 'Upgrade': upgrade = value;
					case 'Connection': connection = value;
				}
			}
			
			if (
				version != '13' 
				|| upgrade != 'websocket' 
				|| connection.indexOf('Upgrade') < 0
				|| key == null
			) {
				throw 'bad request';
			}
			
			Base64.encode(Sha1.make(Bytes.ofString(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11')));
		}
		
		var responce = [
			'HTTP/1.1 101 Switching Protocols',
			'Upgrade: websocket',
			'Connection: Upgrade',
			'Sec-WebSocket-Accept: $acceptKey',
			'',	''
		];
		socket.output.writeString(responce.join('\r\n'));
		
		if (_isDebug) trace('Websocket succefully connected');
		
		return WebSocketGeneric.createFromExistingSocket(SocketSys.createFromExistingSocket(socket, _isDebug), _isDebug);
	}
	
}