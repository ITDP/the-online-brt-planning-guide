package tools;

import js.Node;
import js.node.*;
import js.node.http.*;
import sys.FileSystem;

import Assertion.*;
import Sys.*;
using Literals;

class AssetServer {
	var host:String;
	var dir:String;
	var server:js.node.http.Server;

	function handle(req:IncomingMessage, res:ServerResponse)
	{
		show(req);
	}

	function listen(port:Int)
		server.listen(port);

	function new(host, dir)
	{
		this.host = host;
		this.dir = dir;
		this.server = Http.createServer(handle);
	}

	static var USAGE = "
		Usage:
		  manu asset-server start <host> <port> <data-folder>
		  manu asset-server --help".doctrim();

	public static function run(args:Array<String>)
	{
		switch args {
		case ["--help"]:
			println(USAGE);
		case ["start", host, port, dir]:
			assert(~/^\d+$/.match(port));
			if (!FileSystem.exists(dir))
				FileSystem.createDirectory(dir);
			var port = Std.parseInt(port);

			assert(1 <= port && port < 65355);
			assert(FileSystem.isDirectory(dir));

			new AssetServer(host, dir).listen(port);
		case _:
			println(USAGE);
			exit(1);
		}
	}
}

