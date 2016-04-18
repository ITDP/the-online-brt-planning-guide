package format;

typedef Options = {
	?noHtml : Bool,
	?htmlRoot : String,
	?htmlSeparateChapters : Bool,
	?noTex : Bool,
	?texRoot : String,
	?texSeparateChapters : Bool,
	?version : Bool,
	?help : Bool,
	documentRoot : String
}

/**
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
**/
@:rtti
class Main {
	static var VERSION = "0.0.1-alpha-1";

	static function parseArgs()  // TODO replace by docopt
	{
		var usage = DocOpt.doctrim(haxe.rtti.Rtti.getRtti(Main).doc);
		try {
			var opts:Options = cast {};
			var args = Sys.args().copy();
			function optToField(opt:String) {
				var comp = opt.substr(2).split("-");
				var buf = new StringBuf();
				buf.add(comp.shift());
				for (c in comp) {
					buf.add(c.charAt(0).toUpperCase());
					buf.add(c.substr(1));
				}
				return buf.toString();
			}
			while (args.length > 0) {
				var arg = args.shift();
				switch arg {
				case "--no-html", "--html-separate-chapters", "--no-tex", "--tex-separate-chapters", "--version", "--help":
					var f = optToField(arg);
					if (Reflect.hasField(opts, f))
						throw 'Cannot set $arg twice or more';
					Reflect.setField(opts, f, true);
				case "--html-root", "--tex-root":
					var f = optToField(arg);
					if (Reflect.hasField(opts, f))
						throw 'Cannot set $arg twice or more';
					if (args.length == 0)
						throw 'Missing value for option $arg';
					Reflect.setField(opts, f, args.shift());
				case opt if (StringTools.startsWith(opt, "--")):
					throw 'Unrecognized option: $opt';
				case _:
					if (Reflect.hasField(opts, "documentRoot"))
						throw 'Too many arguments: ${args.join(" ")}';
					opts.documentRoot = arg;
				}
			}
			if (opts.version) {
				Sys.println('Version: $VERSION');
				Sys.exit(0);
			}
			if (opts.help) {
				Sys.println(usage);
				Sys.exit(0);
			}
			if (opts.documentRoot == null)
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

		var opts = parseArgs();
		trace(opts);

		var p = new format.Parser();
		var doc = p.parseFile(opts.documentRoot);

		if (!opts.noHtml) {
			if (opts.htmlSeparateChapters)
				trace("Separate chapter generation still not implemented, falling back to single output mode");

			var htmlIndex = opts.htmlRoot != null ? opts.htmlRoot : "index.html";
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
			sys.io.File.saveContent(htmlIndex, buf.toString());
		}

		if (!opts.noTex) {
			if (opts.htmlSeparateChapters)
				trace("Separate chapter generation still not implemented, falling back to single output mode");
			var texRoot = opts.texRoot != null ? opts.texRoot : "book_contents.tex";
			var tgen = new format.TeXGenerator(texRoot, sys.io.File);
			tgen.generateDocument(doc);
		}
	}
}

