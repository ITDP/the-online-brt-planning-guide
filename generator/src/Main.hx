import ANSI;
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

		println(ANSI.set(Green) + "=> Parsing" + ANSI.set(Off));
		var ast = Context.time("parsing", parser.Parser.parse.bind(p.toInputPath()));

		println(ANSI.set(Green) + "=> Structuring" + ANSI.set(Off));
		var doc = Context.time("structuring", transform.NewTransform.transform.bind(ast));

		println(ANSI.set(Green) + "=> Validating" + ANSI.set(Off));
		var tval = Sys.time();
		transform.Validator.validate(doc,
			function (errors) {
				if (errors != null) {
					var abort = false;
					for (err in errors) {
						if (err.fatal)
							abort = true;
						var hl = err.pos.highlight(80).renderHighlight(Context.hlmode).split("\n");
						println('${ANSI.set(Bold,Red)}ERROR: $err${ANSI.set(Off)}');
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

				println(ANSI.set(Green) + "=> Generating the document" + ANSI.set(Off));

				if (!FileSystem.exists(opath)) FileSystem.createDirectory(opath);
				if (!FileSystem.isDirectory(opath)) throw 'Not a directory: $opath';

				println(ANSI.set(Green) + " --> HTML generation" + ANSI.set(Off));
				Context.time("html generation", function () {
					var hgen = new html.Generator(Path.join([opath, "html"]), true);
					hgen.writeDocument(doc);
				});

				println(ANSI.set(Green) + " --> PDF preparation (TeX generation)" + ANSI.set(Off));
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
		print(ANSI.set(Bold) + BANNER + "\n\n" + ANSI.set(Off));

		Context.debug = Context.debug;
		Context.draft = Context.draft;
		if (Context.debug)
			println('ANSI escape codes are ${ANSI.available ? "enabled" : "disabled"}');
		if (ANSI.available)
			Context.hlmode = AnsiEscapes(ANSI.set(Bold,Red), ANSI.set(Off));

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
			print(ANSI.set(Bold,Red));
			if (Context.debug) print("Lexer ");
			var cpos = e.pos.toPosition();
			cpos.max = cpos.min + e.char.length;  // hxparse.UnexpectedChar generates 0 length positions
			var hl = cpos.highlight(80).renderHighlight(Context.hlmode).split("\n");
			println('ERROR: Unexpected character `${e.char}`');
			print(ANSI.set(Off));
			println('  at ${cpos.toString()}');
			println("    " + hl.join("\n    "));
			if (Context.debug) println(CallStack.toString(CallStack.exceptionStack()));
			exit(2);
		} catch (e:parser.ParserError) {
			print(ANSI.set(Bold,Red));
			if (Context.debug) print("Parser ");
			var hl = e.pos.highlight(80).renderHighlight(Context.hlmode).split("\n");
			println('ERROR: $e');
			print(ANSI.set(Off));
			println('  at ${e.pos.toString()}:');
			println("    " + hl.join("\n    "));
			if (Context.debug) println(CallStack.toString(CallStack.exceptionStack()));
			printTimers();
			exit(3);
		} catch (e:Dynamic) {
			print(ANSI.set(Bold,Red));
			if (Context.debug) print("Untyped ");
			println('ERROR: $e');
			print(ANSI.set(Off));
			if (Context.debug) println(CallStack.toString(CallStack.exceptionStack()));
			printTimers();
			exit(9);
		}
	}
}

