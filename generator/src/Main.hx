import Sys.*;
import haxe.CallStack;
import haxe.io.Path;
import sys.FileSystem;
using Literals;

class Main {
	public static var debug(default,null) = false;
	public static var version(default,null) = {
		commit : Version.getGitCommitHash().substr(0,7),
		fullCommit : Version.getGitCommitHash(),
		haxe : Version.getHaxeCompilerVersion()
	}

	static inline var BANNER = "The Online BRT Planning Guide Tool";
	static var USAGE = "
		Usage:
		  obrt generate <input file> <output dir>
		  obrt --version
		  obrt --help".doctrim();
	static var BUILD_INFO = 'Built from commit ${version.commit} with Haxe ${version.haxe}';

	static function generate(ipath, opath)
	{
		if (debug) println('The current working dir is: `${Sys.getCwd()}`');
		if (!FileSystem.exists(ipath)) throw 'File does not exist: $ipath';
		if (FileSystem.isDirectory(ipath)) throw 'Not a file: $ipath';

		var ast = parser.Parser.parse(ipath);

		var doc = transform.Transform.transform(ast);

		if (!FileSystem.exists(opath)) FileSystem.createDirectory(opath);
		if (!FileSystem.isDirectory(opath)) throw 'Not a directory: $opath';

		var hgen = new generator.HtmlGen(Path.join([opath, "html"]));
		hgen.generate(doc);

		var tgen = new generator.TexGen(Path.join([opath, "pdf"]));
		tgen.writeDocument(doc);
	}

	static function main()
	{
		print(BANNER + "\n\n");
		debug = Sys.getEnv("DEBUG") == "1";

		try {
			var args = Sys.args();
			if (debug) println('Arguments are: `${args.join("`, `")}`');
			switch args {
			case [cmd, ipath, opath] if (StringTools.startsWith("generate", cmd)):
				generate(ipath, opath);
			case ["--version"]:
				println(BUILD_INFO);
			case ["--help"]:
				println(USAGE);
			case _:
				println(USAGE);
				exit(1);
			}
		} catch (e:hxparse.UnexpectedChar) {
			println('${e.pos}: $e');
			if (debug) println(CallStack.toString(CallStack.exceptionStack()));
			exit(2);
		} catch (e:parser.Error.GenericError) {
			var linpos = e.lpos;
			if (linpos.lines.min != linpos.lines.max)
				println('Error in file ${e.pos.src} from line ${linpos.lines.min+1} col ${linpos.codes.min+1} to line ${linpos.lines.max} col ${linpos.codes.max} ');
			else if (linpos.codes.min != linpos.codes.max)
				println('Error in file ${e.pos.src} line ${linpos.lines.min+1} from col ${linpos.codes.min+1} to col ${linpos.codes.max} ');
			else 
				println('Error in file ${e.pos.src} line ${linpos.lines.min+1} at col ${linpos.codes.min+1}');
			println(' --> ${e.text}');
			if (debug) println(CallStack.toString(CallStack.exceptionStack()));
			exit(3);
		} catch (e:Dynamic) {
			println('Error: $e');
			if (debug) println(CallStack.toString(CallStack.exceptionStack()));
			exit(9);
		}
	}
}

