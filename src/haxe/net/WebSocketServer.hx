package haxe.net;
import haxe.io.Error;
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
		_listenSocket.setBlocking(false);
		_listenSocket.bind(new Host(host), port);
		_listenSocket.listen(maxConnections);
	}
	
	public static function create(host:String, port:Int, maxConnections:Int, isDebug:Bool) {
		return new WebSocketServer(host, port, maxConnections, isDebug);
	}
	
	public function accept():WebSocket {
		try {
			var socket = _listenSocket.accept();
			return WebSocket.createFromAcceptedSocket(Socket2.createFromExistingSocket(socket, _isDebug), '', _isDebug);
		}
		catch (e:Dynamic) {
			if (e == 'Blocking' || e == Error.Blocked) {
				return null;
			}
			else {
				throw(e);
			}
		}
	}
	
}