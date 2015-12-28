package format;

class Main {
	static function main()
	{
		var err = Sys.stderr();
		haxe.Log.trace = function (msg:Dynamic, ?pos:haxe.PosInfos) {
			var msg = StringTools.replace(Std.string(msg), "\n", "\n... ");
			if (pos.customParams != null)
				msg += StringTools.replace(pos.customParams.join("\n"), "\n", "\n... ");
			err.writeString('${pos.className.split(".").pop().toUpperCase()}  $msg  @${pos.fileName}:${pos.lineNumber}\n');
		}

		var p = new format.Parser();
		var doc = p.parseStream(Sys.stdin(), Sys.getCwd());

		var buf = new StringBuf();
		var api = {
			saveContent : function (path, content) {
				buf.add('<!-- file $path -->\n');
				buf.add(content);
				buf.add("\n\n");
			}
		}
		var hgen = new format.HtmlGenerator(api);
		hgen.generateDocument(doc);
		Sys.println(buf.toString());
	}
}

