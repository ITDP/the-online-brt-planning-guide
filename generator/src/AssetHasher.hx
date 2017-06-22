import haxe.io.Bytes;

abstract AssetHasher(Map<String,{ len:Int, sha1:String }>) {
	public function new()
		this = new Map();

	public function hash(srcPath:String, data:Bytes, ?useCache=true)
	{
		var cached = this[srcPath];
		if (useCache && cached != null && cached.len == data.length)
			return cached.sha1;

#if nodejs
		var hash = js.node.Crypto.createHash("sha1").update(js.node.buffer.Buffer.hxFromBytes(data)).digest("hex");
#else
		var hash = haxe.crypto.Sha1.make(data).toHex();
#end
		if (useCache)
			this[srcPath] = { len:data.length, sha1:hash };
		return hash;
	}
}

