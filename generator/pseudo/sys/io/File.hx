package sys.io;

import haxe.io.Bytes;

enum FileHandle {}

class File {
	static var store = new Map<String,Bytes>();

	public static function saveBytes(p:String, b:Bytes)
		store[p] = b;

	public static function getBytes(p:String):Bytes
	{
		if (!store.exists(p)) throw 'Pseudo FS: $p does not exist';
		return store[p];
	}

	public static function saveContent(p:String, c:String)
		saveBytes(p, Bytes.ofString(c));

	public static function getContent(p:String)
		return getBytes(p).toString();
}

