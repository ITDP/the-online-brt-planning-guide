import ANSI;
import Contents;
import haxe.CallStack;
import haxe.io.Path;
import sys.FileSystem in Fs;
import sys.io.File;

class Main {
	static function main()
	{
		try {
			run();
		} catch (e:Dynamic) {
			var stack = StringTools.trim(CallStack.toString(CallStack.exceptionStack()));
			var out = js.Node.process.stderr;
			out.write(stack);
			out.write("\n" + ANSI.set(Red,Bold) + 'ERROR: $e' + ANSI.set(Off) + "\n");
			Sys.exit(1);
		}
	}

	static function run()
	{
		var tocPath = null, dataDir = null, outputDir = null;
		switch Sys.args() {
		case [t, d, o]:
			tocPath = t;
			dataDir = d;
			outputDir = o;
		case other:
			assert(false, other, "Usage: cover-generator <path-to-html-toc> <data-dir> <output-dir>");
		}

		assert(Fs.exists(tocPath) && !Fs.isDirectory(tocPath), tocPath);
		assert(Fs.exists(dataDir) && Fs.isDirectory(dataDir), dataDir);
		assert(!Fs.exists(outputDir) || Fs.isDirectory(outputDir), outputDir);

		var toc = readToc(tocPath);
		var ctx = new Context(dataDir);

		generateHtml(toc, ctx, outputDir);
	}

	static function readToc(path):Contents
	{
		show("TODO actually parse and use the TOC");
		return [
			{
				name:"Project Preparation",
				url:"volume/project-preparation",
				chapters:[
					{ name:"Project Initiation", url:"projection-initiation" }
				]
			}
		];
	}

	static function generateHtml(toc, ctx, outputDir)
	{
		Fs.createDirectory(outputDir);
		File.saveContent(Path.join([outputDir, "index.html"]), html.Index.render(toc, ctx));

		var htmlStatics = Path.join([ctx.dataDir, "statics", "html"]);
		if (Fs.exists(htmlStatics)) {
			assert(Fs.isDirectory(htmlStatics), htmlStatics);
			function push(src, dst)
			{
				if (Fs.isDirectory(src)) {
					Fs.createDirectory(dst);
					for (i in Fs.readDirectory(src))
						push(Path.join([src, i]), Path.join([dst, i]));
				} else {
					File.saveBytes(dst, File.getBytes(src));
				}
			}
			push(htmlStatics, outputDir);
		}
	}
}

