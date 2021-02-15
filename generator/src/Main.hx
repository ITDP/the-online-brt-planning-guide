import ANSI;
import haxe.CallStack;
import haxe.io.Path;
import parser.Token;
import sys.FileSystem;

import ANSI.set in ansi;
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
		commit_timestamp : Version.getGitCommitTimestamp(),
		runtime : #if neko "Neko" #elseif js "JS" #elseif cpp "C++" #end,
		platform : Sys.systemName()
	}
	public static inline var LOGO = "╲ ╱╲╱╲ ╱╲ ╱╲╱ ╲╱";
	public static inline var LOGO_TEXT = "manuscript markup language processor";
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
		built from commit ${version.commit} and date ${Date.fromTime(version.commit_timestamp*1000)} with Haxe ${version.haxe}'.doctrim();

	static function generate(ipath, opath)
	{
		if (Context.debug) println('The current working dir is: `${Sys.getCwd()}`');

		var p:parser.Ast.PElem = { def:ipath, pos:{ src:"./", min:0, max:0 } };
		var pcheck = transform.Validator.validateSrcPath(p, [transform.Validator.FileType.Manu]);
		if (pcheck != null)
			throw pcheck.toString();

		println(ansi(Green) + "=> Parsing" + ansi(Off));
		var ast = Context.time("parsing", parser.Parser.parse.bind(p.toInputPath()));

		println(ansi(Green) + "=> Structuring" + ansi(Off));
		var doc = Context.time("structuring", transform.NewTransform.transform.bind(ast));

		println(ansi(Green) + "=> Validating" + ansi(Off));
		var tval = Sys.time();
		transform.Validator.validate(doc,
			function (errors) {
				if (errors != null) {
					var abort = false;
					for (err in errors) {
						if (err.fatal)
							abort = true;
						var hl = err.pos.highlight(80).renderHighlight(Context.hlmode).split("\n");
						print(ansi(Bold,Red));
						if (Context.debug) print("Validation ");
						println('ERROR: $err');
						print(ansi(Off));
						println('  at ${err.pos.toString()}:');
						println("    " + hl.join("\n    "));
					}
					if (abort) {
						println("Validation has failed, aborting");
						printTimers();
						exit(4);
					}
				}

				try {
					var tgen = Sys.time();
					Context.manualTime("validation", tgen - tval);

					println(ansi(Green) + "=> Generating the document" + ansi(Off));

					if (!FileSystem.exists(opath)) FileSystem.createDirectory(opath);
					if (!FileSystem.isDirectory(opath)) throw 'Not a directory: $opath';

					var hasher = new AssetHasher();

					println(ansi(Green) + " --> HTML generation" + ansi(Off));
					Context.time("html generation", function () {
						var hgen = new html.Generator(hasher, Path.join([opath, "html"]), true);
						hgen.writeDocument(doc);
					});

					println(ansi(Green) + " --> PDF preparation (TeX generation)" + ansi(Off));
					Context.time("tex generation", function () {
						var tgen = new tex.Generator(hasher, Path.join([opath, "pdf"]));
						tgen.writeDocument(doc);
					});

					printTimers();
				} catch (e:Dynamic) {
					print(ansi(Bold,Red));
					if (Context.debug) print("Generation ");
					println('ERROR: $e');
					print(ansi(Off));
					if (Context.debug) println(CallStack.toString(CallStack.exceptionStack()));
					printTimers();
					exit(8);
				}
			});
	}

	public static function printTimers()
	{
		println("\nTiming measurement results:");
		for (k in Context.timerOrder)
			println('  $k: ${Math.round(Context.timer[k]*1e3)} ms');
	}

	static function customTrace(msg, ?pos:haxe.PosInfos)
	{
		var buf = new StringBuf();
		buf.add(" --> ");
		buf.add(msg);
		if (pos.customParams != null) {
			buf.add(" {{ ");
			buf.add(pos.customParams.join(", "));
			buf.add(" }}");
		}
		buf.add("  // in ");
		buf.add(pos.methodName);
		buf.add(" (");
		buf.add(pos.fileName);
		buf.add(":");
		buf.add(pos.lineNumber);
		buf.add(")\n");
		js.Node.process.stderr.write(buf.toString());
	}

	static function main()
	{
		haxe.Log.trace = customTrace;
		print('\n${ansi(Blue)}$LOGO${ansi(Off,Bold)}   $LOGO_TEXT${ansi(Off)}   \n\n');

		Context.debug = Context.debug;
		Context.draft = Context.draft;
		if (Context.debug)
			println('ANSI escape codes are ${ANSI.available ? "enabled" : "disabled"}');
		if (ANSI.available)
			Context.hlmode = AnsiEscapes(ansi(Bold,Red), ansi(Off));

		Context.prepareSourceMaps();
		Assertion.enableShow = Context.debug;
		Assertion.enableWeakAssert = true;
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
			print(ansi(Bold,Red));
			if (Context.debug) print("Lexer ");
			var cpos = e.pos.toPosition();
			// hxparse generates errors with 0-length positions; we don't
			if (cpos.max == cpos.min)
				cpos.max = cpos.min + e.char.length;
			var hl = cpos.highlight(80).renderHighlight(Context.hlmode).split("\n");
			println('ERROR: Unexpected character `${e.char}`');
			print(ansi(Off));
			println('  at ${cpos.toString()}');
			println("    " + hl.join("\n    "));
			if (Context.debug) println(CallStack.toString(CallStack.exceptionStack()));
			printTimers();
			exit(2);
		} catch (e:parser.ParserError) {
			print(ansi(Bold,Red));
			if (Context.debug) print("Parser ");
			var hl = e.pos.highlight(80).renderHighlight(Context.hlmode).split("\n");
			println('ERROR: $e');
			print(ansi(Off));
			println('  at ${e.pos.toString()}:');
			println("    " + hl.join("\n    "));
			if (Context.debug) println(CallStack.toString(CallStack.exceptionStack()));
			printTimers();
			exit(3);
		} catch (e:Dynamic) {
			print(ansi(Bold,Red));
			if (Context.debug) print("Untyped ");
			println('ERROR: $e');
			print(ansi(Off));
			if (Context.debug) println(CallStack.toString(CallStack.exceptionStack()));
			printTimers();
			exit(9);
		}
	}
}

