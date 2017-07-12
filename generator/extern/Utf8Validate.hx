#if nodejs
@:jsRequire("utf-8-validate")
#else
#error "utf-8-validate requires Node.js.  Compile with `-lib hxnodejs`."
#end
extern class Utf8Validate {
	@:selfCall
	static function isValidUTF8(buf:js.node.Buffer):Bool;
}

