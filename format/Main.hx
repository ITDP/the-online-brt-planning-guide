package format;

class Main {
	static var version = "v0.0.0-alpha-0";
	static var usage = DocOpt.doctrim("
	The Digital BRT Planning Guide Generator.

	Usage:
	  generate [options] <document-root>
	  generate --version
	  generate --help

	Options:
	  --no-html                 Disable HTML generation
	  --html-root <path>        Change HTML output root from index.html to <path>
	  --html-separate-chapters  Generate chapters in separate HTML files
	  --no-tex                  Disable TeX generation
	  --tex-root <path>         Change TeX output root from book.tex to <path>
	  --tex-separate-chapters   Generate chapters in separate TeX files
	  --version                 Print the version of the generator and exit
	  --help                    Print this usage message and exit
	");

	static function parseArgs()  // TODO replace by docopt
	{
		try {
			var opts = new Map<String,Dynamic>();
			var args = Sys.args().copy();
			while (args.length > 0) {
				var arg = args.shift();
				switch arg {
				case "--no-html", "--html-separate-chapters", "--no-tex", "--tex-separate-chapters", "--version", "--help":
					var opt = arg;
					if (opts.exists(opt))
						throw 'Cannot set $opt twice or more';
					opts[opt] = true;
				case "--html-root", "--tex-root":
					var opt = arg;
					if (opts.exists(opt))
						throw 'Cannot set $opt twice or more';
					if (args.length == 0)
						throw 'Missing value for option $opt';
					opts[opt] = args.shift();
				case opt if (StringTools.startsWith(opt, "--")):
					throw 'Unrecognized option: $opt';
				case _:
					if (opts.exists(arg))
						throw 'Too many arguments: ${args.join(" ")}';
					opts["document-root"] = arg;
				}
			}
			if (opts["--version"]) {
				Sys.println('Version: $version');
				Sys.exit(0);
			}
			if (opts["--help"]) {
				Sys.println(usage);
				Sys.exit(0);
			}
			if (!opts.exists("document-root"))
				throw 'Argument required: <document-root>';
			return opts;
		} catch (e:Dynamic) {
			Sys.println(e + "\n");
			Sys.println(usage);
			Sys.exit(1);
			return null;
		}
	}

	static function main()
	{
		var err = Sys.stderr();
		haxe.Log.trace = function (msg:Dynamic, ?pos:haxe.PosInfos) {
			var msg = StringTools.replace(Std.string(msg), "\n", "\n... ");
			if (pos.customParams != null)
				msg += StringTools.replace(pos.customParams.join("\n"), "\n", "\n... ");
			err.writeString('${pos.className.split(".").pop().toUpperCase()}  $msg  @${pos.fileName}:${pos.lineNumber}\n');
		}

		var args = parseArgs();
		trace(args);

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

