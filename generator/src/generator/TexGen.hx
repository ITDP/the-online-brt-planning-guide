package generator;

import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;
import transform.Document;

class TexGen {
	var destDir:String;
	var buf:Map<String,StringBuf>;
	var root:StringBuf;

	function wv(v:TElem)
	{
		switch v.def {
		case TVList(li):
			for (i in li)
				wv(i);
		case TLaTeXPreamble(path):
			// TODO validate path (or has Transform done so?)
			root.add('% included from $path\n');
			root.add(File.getContent(path));
			root.add("\n\n");
		case _:
			trace("TODO");
		}
	}

	public function generate(doc:Document)
	{
		root = new StringBuf();
		buf["root.tex"] = root;
		root.add("% This file has been generated; do not edit manually!\n\n");
		wv(doc);

		if (!FileSystem.exists(destDir))
			FileSystem.createDirectory(destDir);
		for (p in buf.keys()) {
			var path = Path.join([destDir, p]);
			File.saveContent(path, buf[p].toString());
		}
	}

	public function new(destDir)
	{
		// TODO validate destDir
		this.destDir = destDir;
		buf = new Map();
	}
}

