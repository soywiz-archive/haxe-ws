package haxe.net;
import haxe.io.Error;
import haxe.net.impl.SocketSys;
import haxe.net.impl.WebSocketGeneric;
import sys.net.Host;
import sys.ssl.Socket;
import sys.ssl.Certificate;
import sys.ssl.Key;

class WebSocketServer { 

	var _isDebug:Bool;
	var _isSecure:Bool;
	var _listenSocket:sys.net.Socket;
	#if neko
	var keepalive:Dynamic;
	#end
	function new(host:String, port:Int, maxConnections:Int, isSecure:Dynamic = null, isDebug:Bool = false) {
		_isDebug = isDebug;
		_isSecure = isSecure != null;
		_listenSocket = _isSecure ? new sys.ssl.Socket() : new sys.net.Socket() ;
		
		if(_isSecure){
			cast(_listenSocket, sys.ssl.Socket).setCA( Certificate.loadFile(Reflect.field(isSecure, "CA")) );
        	cast(_listenSocket, sys.ssl.Socket).setCertificate( Certificate.loadFile(Reflect.field(isSecure, "Certificate")), Key.readPEM(sys.io.File.getContent(Reflect.field(isSecure, "Key")), false) );
			cast(_listenSocket, sys.ssl.Socket).verifyCert = false;
		}
		trace("aaaa");
		_listenSocket.bind(new Host(host), port);
		_listenSocket.setBlocking(false);
		_listenSocket.listen(maxConnections);
		
		#if neko
		keepalive = neko.Lib.load("std", "socket_set_keepalive",4);
		#end
	}
	
	public static function create(host:String, port:Int, maxConnections:Int, isSecure:Bool, isDebug:Bool) {
		return new WebSocketServer(host, port, maxConnections, isSecure, isDebug);
	}
	
	public function accept():WebSocket {
		try {
			var socket:Dynamic = null;
			 if(_isSecure){
				var sslsocket:sys.ssl.Socket = cast(_listenSocket, sys.ssl.Socket).accept();
				while(true){
					try{
						#if neko
							keepalive( @:privateAccess sslsocket.__s, true, 60, 5 );
						#end
						sslsocket.waitForRead();
						sslsocket.handshake();
						break;
					}catch(e:Dynamic){ 
						switch (Std.string(e)) {
							case "Blocked": continue;
							case "SSL - No client certification received from the client, but required by the authentication mode": sslsocket.output.flush(); continue; //fix for chrome
							case "X509 - Certificate verification failed, e.g. CRL, CA or signature check failed": break;
							default:
								if(_isDebug){
									trace("Closing -> " + sslsocket.peer());
									trace(Date.now() + " " + e);
								}
								sslsocket.close();
								
								break;
						}
					}
				}
				sslsocket.output.flush();
				socket = sslsocket;
			}else{
				socket = _listenSocket.accept();
			}
			return WebSocket.createFromAcceptedSocket(Socket2.createFromExistingSocket(socket, _isDebug), '', _isDebug);
		}
		catch (e:Dynamic) {
			
			return null;
		}
	}
	
}