package haxe.net;
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
		
		return WebSocketGeneric.createFromAcceptedSocket(SocketSys.createFromExistingSocket(socket, _isDebug), '', _isDebug);
	}
	
}