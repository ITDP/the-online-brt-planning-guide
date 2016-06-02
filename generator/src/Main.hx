import Sys.*;
import haxe.CallStack;
import haxe.io.Path;
import sys.FileSystem;

class Main {
	public static var debug(default,null) = false;

	static inline var BANNER = "The Online BRT Planning Guide Tool\n\n";
	static inline var USAGE = "Usage: obrt generate <input file>\n";

	static function generate(path)
	{
		if (debug) println('The current working dir is: `${Sys.getCwd()}`');
		if (!FileSystem.exists(path)) throw 'File does not exist: $path';
		if (FileSystem.isDirectory(path)) throw 'Not a file: $path';

		var ast = parser.Parser.parse(path);

		var doc = transform.Transform.transform(ast);

		var hgen = new generator.HtmlGen(path + ".html");
		hgen.generate(doc);

		trace("TODO generate tex");
	}

	static function main()
	{
		print(BANNER);
		debug = Sys.getEnv("DEBUG") == "1";

		try {
			var args = Sys.args();
			if (debug) println('Arguments are: `${args.join("`, `")}`');
			switch args {
			case [cmd, path] if (StringTools.startsWith("generate", cmd)):
				generate(path);
			case _:
				print(USAGE);
				exit(1);
			}
		} catch (e:Dynamic) {
			println('Error: $e');
			if (debug) println(CallStack.toString(CallStack.exceptionStack()));
			exit(2);
		}
	}
}

