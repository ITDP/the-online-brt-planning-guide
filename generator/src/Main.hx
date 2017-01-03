import Ansi;
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

	static inline var BANNER = "manu – manuscript markup language processor";
	static var USAGE = "
		Usage:
		  manu generate <input file> <output dir>
		  manu statistics ... (run `manu statistics --help` for more)
		  manu asset-server ... (run `manu asset-server --help` for more)
		  manu unit-tests
		  manu --version
		  manu --help".doctrim();
	static var BUILD_INFO = '
		manu for ${version.platform}/${version.runtime}
		built from commit ${version.commit} with Haxe ${version.haxe}'.doctrim();

	static function generate(ipath, opath)
	{
		if (Context.debug) println('The current working dir is: `${Sys.getCwd()}`');

		var p:parser.Ast.PElem = { def:ipath, pos:{ src:"./", min:0, max:0 } };
		var pcheck = transform.Validator.validateSrcPath(p, [transform.Validator.FileType.Manu]);
		if (pcheck != null)
			throw pcheck.toString();

		println(Ansi.set(Green) + "=> Parsing" + Ansi.set(Off));
		var ast = Context.time("parsing", parser.Parser.parse.bind(p.toInputPath()));

		println(Ansi.set(Green) + "=> Structuring" + Ansi.set(Off));
		var doc = Context.time("structuring", transform.NewTransform.transform.bind(ast));

		println(Ansi.set(Green) + "=> Validating" + Ansi.set(Off));
		var tval = Sys.time();
		transform.Validator.validate(doc,
			function (errors) {
				if (errors != null) {
					var abort = false;
					for (err in errors) {
						if (err.fatal)
							abort = true;
						var hl = err.pos.highlight(80).renderHighlight(Context.hlmode).split("\n");
						println('${Ansi.setm([Bold,Red])}ERROR: $err${Ansi.set(Off)}');
						println('  at ${err.pos.toString()}:');
						println("    " + hl.join("\n    "));
					}
					if (abort) {
						println("Validation has failed, aborting");
						exit(4);
					}
				}

				var tgen = Sys.time();
				Context.manualTime("validation", tgen - tval);

				println(Ansi.set(Green) + "=> Generating the document" + Ansi.set(Off));

				if (!FileSystem.exists(opath)) FileSystem.createDirectory(opath);
				if (!FileSystem.isDirectory(opath)) throw 'Not a directory: $opath';

				println(Ansi.set(Green) + " --> HTML generation" + Ansi.set(Off));
				Context.time("html generation", function () {
					var hgen = new html.Generator(Path.join([opath, "html"]), true);
					hgen.writeDocument(doc);
				});

				println(Ansi.set(Green) + " --> PDF preparation (TeX generation)" + Ansi.set(Off));
				Context.time("tex generation", function () {
					var tgen = new tex.Generator(Path.join([opath, "pdf"]));
					tgen.writeDocument(doc);
				});

				printTimers();
			});
	}

	public static function printTimers()
	{
		println("\nTiming measurement results:");
		for (k in Context.timerOrder)
			println('  $k: ${Math.round(Context.timer[k]*1e3)} ms');
	}

	static function main()
	{
		print(Ansi.setm([Bold]) + BANNER + "\n\n" + Ansi.set(Off));
		if (Context.debug) println('Ansi escape codes are ${Ansi.available ? "enabled" : "disabled"}');

		Context.debug = Sys.getEnv("DEBUG") == "1";
		Context.draft = Sys.getEnv("DRAFT") == "1";
		if (Ansi.available)
			Context.hlmode = AnsiEscapes(Ansi.setm([Bold,Red]), Ansi.set(Off));
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
			case _[0] => cmd if (cmd != null && StringTools.startsWith("asset-server", cmd)):
				tools.AssetServer.run(args.slice(1));
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
			print(Ansi.setm([Bold,Red]));
			if (Context.debug) print("Lexer ");
			println('ERROR: Unexpected character `${e.char}`');
			print(Ansi.set(Off));
			println('  at ${e.pos.toPosition().toString()}');
			if (Context.debug) println(CallStack.toString(CallStack.exceptionStack()));
			printTimers();
			exit(2);
		} catch (e:parser.ParserError) {
			print(Ansi.setm([Bold,Red]));
			if (Context.debug) print("Parser ");
			var hl = e.pos.highlight(80).renderHighlight(Context.hlmode).split("\n");
			println('ERROR: $e');
			print(Ansi.set(Off));
			println('  at ${e.pos.toString()}:');
			println("    " + hl.join("\n    "));
			if (Context.debug) println(CallStack.toString(CallStack.exceptionStack()));
			printTimers();
			exit(3);
		} catch (e:Dynamic) {
			print(Ansi.setm([Bold,Red]));
			if (Context.debug) print("Untyped ");
			println('ERROR: $e');
			print(Ansi.set(Off));
			if (Context.debug) println(CallStack.toString(CallStack.exceptionStack()));
			printTimers();
			exit(9);
		}
	}
}

