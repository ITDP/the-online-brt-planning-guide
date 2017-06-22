package tools;

import parser.Lexer;
import parser.Token;
import sys.FileSystem;
import sys.io.File;

import Sys.*;
using Literals;
using PositionTools;

class Stats {
	static var USAGE = "
		Usage:
		  manu statistics tokens <input file> [...]
		  manu statistics --help".doctrim();

	static function tokenStats(paths:Array<String>)
	{
		var stats = new Map();
		var total = 0;

		function count(name:String) {
			total++;
			if (stats.exists(name))
				stats[name]++;
			else
				stats[name] = 1;
		}

		for (p in paths) {
			if (!FileSystem.exists(p)) throw 'File does not exist: $p';
			if (FileSystem.isDirectory(p)) throw 'Not a file: $p';
			var lexer = new Lexer(File.getBytes(p), p);
			do {
				var tok = lexer.token(Lexer.tokens);
				switch tok.def {
				case TEof: break;
				case TWordSpace(_), TBreakSpace(_), TComment(_), TMath(_), TWord(_), TCode(_), TCodeBlock(_): count(Type.enumConstructor(tok.def));
				case _: count(Std.string(tok.def));
				}
			} while (true);
		}

		var res = [ for (n in stats.keys()) { name:n, count:stats[n], share:Math.round(stats[n]/total*1000)/10 } ];
		res.push({ name:"Total", count:total, share:100 });
		res.sort(function (a,b) return Reflect.compare(a.count, b.count));
		println([for (r in res) '${r.name}: ${r.count} (${r.share}%)'].join("\n"));
	}

	public static function run(args:Array<String>)
	{
		switch args {
		case ["--help"]:
			println(USAGE);
		case _[0] => cmd if (cmd != null && StringTools.startsWith("tokens", cmd)):
			tokenStats(args.slice(1));
		case _:
			println(USAGE);
			exit(1);
		}
	}
}

