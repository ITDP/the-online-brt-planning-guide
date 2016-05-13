package generator;  // TODO move out of the package

import sys.FileSystem;
import transform.Document;

// temporary
import parser.Ast;

import haxe.io.Path.join in joinPaths;

typedef Path = String;

class HtmlGen {
	var dest:Path;

	function horizontal(h:HElem)
	{
		return switch h.def {
		case Wordspace: " ";
		case Emphasis(i): '<span class="brt-emph">${horizontal(i)}</span>';
		case Highlight(i): '<span class="brt-highligh">${horizontal(i)}</span>';
		case Word(w): w;
		case HList(li):
			var buf = new StringBuf();
			for (i in li)
				buf.add(horizontal(i));
			buf.toString();
		}
	}

	function vertical(v:VElem)
	{
		switch v.def {
		case Volume(h):
			return '<h2>${horizontal(h)}</h2>\n';
		case Chapter(h):
			return '<h3>${horizontal(h)}</h3>\n';
		case Paragraph(h):
			return '<p>${horizontal(h)}</p>\n';
		case VList(li):
			var buf = new StringBuf();
			for (i in li)
				buf.add(i);
			return buf.toString();
		}
	}

	function document(doc:Document)
	{
		var buf = new StringBuf();
		buf.add('<html><head><title>TODO</title></head><body>\n');
		buf.add(vertical(doc));
		buf.add('</body>');
		sys.io.File.saveContent(joinPaths([dest,"index.html"]), buf.toString());
	}

	public function generate(doc:Document)
	{
		if (!FileSystem.exists(dest))
			FileSystem.createDirectory(dest);
		else if (!FileSystem.isDirectory(dest))
			throw 'Not a directory: $dest';

		document(doc);
	}

	public function new(dest:Path)
		this.dest = dest;
}

