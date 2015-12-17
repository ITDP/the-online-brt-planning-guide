package format;

class HtmlGeneration {
	public static function main()
	{
		trace("TODO something");
		Sys.exit(1);
	}
}

class Main {
	static function main()
	{
		var err = Sys.stderr();
		haxe.Log.trace = function (msg:Dynamic, ?pos:haxe.PosInfos) {
			var msg = StringTools.replace(msg, "\n", "\n... ");
			if (pos.customParams != null)
				msg += StringTools.replace(pos.customParams.join("\n"), "\n", "\n... ");
			err.writeString('${pos.fileName}:${pos.lineNumber}:  $msg\n');
		}

#if (cli == "generate-html")
		HtmlGeneration.main();
#elseif (cli == "generate-tex")
		throw("Not implemented here");
#else
		throw("Not implemented");
#end
	}
}

