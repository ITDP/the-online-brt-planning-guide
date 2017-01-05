package tools;

import Ansi;
import js.Node;
import js.node.*;
import js.node.http.*;
import sys.FileSystem;

import Assertion.*;  // FIXME not really usefull in this server contex; we would need separate connection id's for each call; also, asserts on async code are useless
import Sys.*;
using Literals;
using StringTools;

private class AssetServerClient {
	var port:Int;
	var hostname:String;

	public function new(port, hostname)
	{
		this.port = port;
		this.hostname = hostname;
	}

	function send(dir:String, buf:StringBuf)
	{
		var response = buf.toString();
		var want:Array<String> = haxe.Json.parse(response);  // TODO validate

		if (want.length == 0) {
			println(Ansi.set(Green) + '=> Done, server does not need (or want) any files' + Ansi.set(Off));
			return;
		}

		var simultaneous = 5;
		println(Ansi.set(Green) + '=> PUTing assets (${want.length})' + Ansi.set(Off));
		println(Ansi.set(Green) + ' --> Maximum number of simultaneous requests: $simultaneous' + Ansi.set(Off));
		function put() {
			if (want.length == 0) {
				if (--simultaneous == 0)
					println(Ansi.set(Green) + ' --> Ok!' + Ansi.set(Off));
				return;
			}

			var h = want.shift();  // TODO properly validate h
			var path = haxe.io.Path.join([dir, h]);
			assert(FileSystem.exists(path), dir, h);
			show(path);

			var req = Http.request({
				host : hostname,
				port : port,
				method : "PUT",
				path : '/store/$h',
				headers : { "Content-Type": "application/octet-stream" } });
			function onResponse(res:IncomingMessage) {
				assert(res != null);
				assert(res.statusCode == 200 || res.statusCode == 201, res.statusCode);
				weakAssert(res.statusCode == 201);
				res.resume();
				res.on("end", put);
			}
			req.on("response", onResponse);
			req.on("error", function (err) assert(false, err));
			var stream = Fs.createReadStream(path);
			stream.pipe(req);
			stream.on("end", function () req.end());
		}
		for (i in 0...simultaneous)
			put();
	}

	function offer(dir)
	{
		assert(FileSystem.exists(dir) && FileSystem.isDirectory(dir));
		var files = FileSystem.readDirectory(dir);
		println(Ansi.set(Green) + '=> Offering hashes (${files.length})' + Ansi.set(Off));

		var req = Http.request({
			host : hostname,
			port : port,
			method : "POST",
			path : "/offer",
			headers : { "Content-Type" : "application/json" } });
		function onResponse(res:IncomingMessage) {
			assert(res != null);
			switch res.statusCode {
			case 200:
				println(Ansi.set(Green) + ' --> Ok!' + Ansi.set(Off));
			case other:
				println(Ansi.set(Red) + ' --> FAILED, server responded with status = $other' + Ansi.set(Off));
			}
			var buf = new StringBuf();
			res.on("data", function (chunk) buf.add(chunk));
			res.on("end", send.bind(dir, buf));
		}
		req.on("response", onResponse);
		req.on("error", function (err) assert(false, err));
		req.write(haxe.Json.stringify(files));
		req.end();
	}

	public function store(path)
	{
		offer(path);
	}
}

class AssetServer {
	var dir:String;
	var server:js.node.http.Server;

	function fail(res:ServerResponse, status, ?msg)
	{
		res.statusCode = status;
		if (msg != null) {
			res.setHeader("Content-Type", "text/plain");
			res.write(msg);
		}
		res.end();
	}

	function handle(req:IncomingMessage, res:ServerResponse)
	{
		var hashPat = ~/^([a-f0-9]+)(\.([a-z0-9]+))?$/i, hashLen = 160 >> 2;
		switch [(req.method:String).toLowerCase()].concat(req.url.split("/").slice(1)) {  // TODO report necessity of req.method:String to HF
		case ["post", "offer"]:  // POST /offer with Json serialization [<hash name>, <hash name>, ...] payload
			var buf = new StringBuf();
			req.setEncoding("utf-8");
			req.on("data", function (chunk) buf.add(chunk));
			req.on("end", function () {
				show(buf.toString());
				var payload = buf.toString();
				var hashes:Array<String> = try {
					var json = haxe.Json.parse(payload);
					if (!Std.is(json, Array))
						throw "expected array";
					json;
				} catch (e:Dynamic) {
					show("bad json", payload);
					return fail(res, 400, "could not parse the payload as json");
				}
				var want = [];
				var have = [ for (f in FileSystem.readDirectory(dir)) f => true ];  // TODO make this into a more general cache
				for (h in hashes) {
					if (!Std.is(h, String) || !hashPat.match(h)) {
						show("bad name", h);
						return fail(res, 400, "bad asset name");
					}
					if (hashPat.matched(1).length != hashLen) {
						show("bad name", h, hashPat.matched(1), hashPat.matched(2), hashLen);
						return fail(res, 400, "bad asset name");
					}
					var path = haxe.io.Path.join([dir, h]);
					if (!have.exists(h))
						want.push(h);
				}
				show(hashes.length, want.length);
				res.statusCode = 200;
				res.setHeader("Content-Type", "application/json");
				res.write(haxe.Json.stringify(want));
				res.end();
			});
		case ["put", "store", h]:  // PUT /store/<hash name>
			if (!hashPat.match(h)) {
				show("bad name", h);
				return fail(res, 400, "bad asset name");
			}
			if (!hashPat.match(h) || hashPat.matched(1).length != hashLen) {
				show("bad name", h, hashPat.matched(1), hashPat.matched(2), hashLen);
				return fail(res, 400, "bad asset name");
			}
			var path = haxe.io.Path.join([dir, h]);
			if (FileSystem.exists(path)) {
				res.statusCode = 200;  // ok
				res.end();
				return;
			}
			var buf = new haxe.io.BytesBuffer();
			req.on("data", function (chunk:Buffer) buf.add(chunk.hxToBytes()));
			req.on("end", function () {
				var data = buf.getBytes();
				var comp = Crypto.createHash("sha1").update(Buffer.hxFromBytes(data)).digest("hex");
				if (comp.toLowerCase() != hashPat.matched(1).toLowerCase()) {
					show("bad content", comp, h, data.length);
					return fail(res, 400, "asset content doesn't match hash");
				}
				show(path);
				sys.io.File.saveBytes(path, data);
				res.statusCode = 201;  // created
				res.end();
			});
		case ["post", "push"]:  // POST /push with yet unspecified payload
			show("TODO (efficient PUT)");
			fail(res, 500, "batch puts not yet implemented");
		case ["get", "store", obj]:  // GET /store/<hash name>
			show("TODO (autonomous asset retrieval)");
			fail(res, 500, "asset serving has not yet been implemented; you can serve the files directly with your webserver\n");
		case other:
			show(false, "unknown route", req.method, req.url, other);
			fail(res, 404);
		}
	}

	function listen(port:Int, hostname:String)
	{
		server.listen(port, hostname);
		server.once("listening", function () show("listening", server.address()));
	}

	function new(dir)
	{
		this.dir = dir;
		this.server = Http.createServer(handle);
	}

	static var USAGE = "
		Usage:
		  manu asset-server start <hostname> <port> <data folder>
		  manu asset-server store <hostname> <port> <local directory>
		  manu asset-server --help
		
		Don't forget about setting DEBUG=1 for more information.".doctrim();

	public static function run(args:Array<String>)
	{
		switch args {
		case ["--help"]:
			println(USAGE);
		case ["start", hostname, port, dir]:
			assert(~/^\d+$/.match(port));
			if (!FileSystem.exists(dir))
				FileSystem.createDirectory(dir);
			var port = Std.parseInt(port);

			assert(1 <= port && port < 65355);
			assert(FileSystem.isDirectory(dir));

			new AssetServer(dir).listen(port, hostname);
		case ["store", hostname, port, path]:
			assert(~/^\d+$/.match(port));
			var port = Std.parseInt(port);

			assert(1 <= port && port < 65355);

			new AssetServerClient(port, hostname).store(path);
		case _:
			println(USAGE);
			exit(1);
		}
	}
}

