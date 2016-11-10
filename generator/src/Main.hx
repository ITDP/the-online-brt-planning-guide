import haxe.CallStack;
import haxe.io.Path;
import parser.Token;
import sys.FileSystem;

import Assertion.*;
import Sys.*;
using Literals;
using PositionTools;
using StringTools;

class Main {
	public static var version(default,null) = {
		commit : Version.getGitCommitHash().substr(0,7),
		fullCommit : Version.getGitCommitHash(),
		haxe : Version.getHaxeCompilerVersion(),
		runtime : #if neko "Neko" #elseif js "JS" #elseif cpp "C++" #end,
		platform : Sys.systemName()
	}

	static inline var BANNER = "The Online BRT Planning Guide Tool";
	static var USAGE = "
		Usage:
		  obrt generate <input file> <output dir>
		  obrt statistics ... (run `obrt statistics --help` for more)
		  obrt unit-tests
		  obrt --version
		  obrt --help".doctrim();
	static var BUILD_INFO = '
		OBRT tool for ${version.platform}/${version.runtime}
		Built from commit ${version.commit} with Haxe ${version.haxe}'.doctrim();

	static function generate(ipath, opath)
	{
		if (Context.debug) println('The current working dir is: `${Sys.getCwd()}`');
		if (!FileSystem.exists(ipath)) throw 'File does not exist: $ipath';
		if (FileSystem.isDirectory(ipath)) throw 'Not a file: $ipath';

		println("=> Parsing");
		var ast = parser.Parser.parse(ipath);

		println("=> Structuring");
		var doc = transform.NewTransform.transform(ast);

		println("=> Validating");
		transform.Validator.validate(doc,
			function (errors) {
				if (errors != null) {
					var abort = false;
					for (err in errors) {
						if (err.fatal)
							abort = true;
						var hl = err.pos.highlight(80).renderHighlight(AsciiUnderscore("^")).split("\n");
						println('ERROR: $err');
						println('  at ${err.pos.toString()}:');
						println('    ${hl[0]}');
						println('    ${hl[1]}');
					}
					if (abort) {
						println("Validation has failed, aborting");
						exit(4);
					}
				}

				if (!FileSystem.exists(opath)) FileSystem.createDirectory(opath);
				if (!FileSystem.isDirectory(opath)) throw 'Not a directory: $opath';

				println("=> Generating the document");
				println(" --> HTML generation");
				var hgen = new html.Generator(Path.join([opath, "html"]), true);
				hgen.writeDocument(doc);

				println(" --> PDF preparation (TeX generation)");
				var tgen = new tex.Generator(Path.join([opath, "pdf"]));
				tgen.writeDocument(doc);
			});
	}

	static function main()
	{
		print(BANNER + "\n\n");
		Context.debug = Sys.getEnv("DEBUG") == "1";
		Context.draft = Sys.getEnv("DRAFT") == "1";
		Context.prepareSourceMaps();
		Assertion.enableShow = Context.debug;
		Assertion.enableWeakAssert = Context.debug;
		Assertion.enableAssert = true;

		try {
			var args = Sys.args();
			if (Context.debug) println('Arguments are: `${args.join("`, `")}`');
			switch args {
			case [cmd, ipath, opath] if (StringTools.startsWith("generate", cmd)):
				generate(ipath, opath);
			case _[0] => cmd if (cmd != null && StringTools.startsWith("statistics", cmd)):
				tools.Stats.run(args.slice(1));
			case [cmd] if (StringTools.startsWith("unit-tests", cmd)):
				tests.RunAll.runAll();
			case ["--version"]:
				println(BUILD_INFO);
			case ["--help"]:
				println(USAGE);
			case _:
				println(USAGE);
				exit(1);
			}
		} catch (e:hxparse.UnexpectedChar) {
			if (Context.debug) print("Lexer ");
			println('ERROR: Unexpected character `${e.char}`');
			println('  at ${e.pos.toPosition().toString()}');
			if (Context.debug) println(CallStack.toString(CallStack.exceptionStack()));
			exit(2);
		} catch (e:parser.ParserError) {
			if (Context.debug) print("Parser ");
			var hl = e.pos.highlight(80).renderHighlight(AsciiUnderscore("^")).split("\n");
			println('ERROR: $e');
			println('  at ${e.pos.toString()}:');
			println('    ${hl[0]}');
			println('    ${hl[1]}');
			if (Context.debug) println(CallStack.toString(CallStack.exceptionStack()));
			exit(3);
		} catch (e:Dynamic) {
			if (Context.debug) print("Untyped ");
			println('ERROR: $e');
			if (Context.debug) println(CallStack.toString(CallStack.exceptionStack()));
			exit(9);
		}
	}
}

