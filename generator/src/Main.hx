import Sys.*;
import sys.FileSystem;

class Main {
	static inline var BANNER = "The Online BRT Planning Guide Tool\n\n";
	static inline var USAGE = "Usage: obrt generate <input file>\n";

	static function generate(path)
	{
		if (!FileSystem.exists(path)) throw 'File does not exist: $path';
		if (FileSystem.isDirectory(path)) throw 'Not a file: $path';
		var ast = parser.Parser.parse(path);
		trace(ast);
		trace("TODO transform");
		trace("TODO generate html");
		trace("TODO generate tex");
	}

	static function main()
	{
		print(BANNER);

		try {
			switch Sys.args() {
			case [cmd, path] if (StringTools.startsWith("generate", cmd)):
				generate(path);
			case _:
				print(USAGE);
				exit(1);
			}
		} catch (e:Dynamic) {
			println('Error: $e');
			// TODO print the call stack
			exit(2);
		}
	}
}

