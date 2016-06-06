package generator;

import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;
import transform.Document;

using StringTools;

class TexGen {
	var destDir:String;
	var preamble:StringBuf;
	var bufs:Map<String,StringBuf>;

	function gent(text:String)
	{
		text = ~/([%{}\$\/\\])/.replace(text, "\\$1");  // FIXME complete
		return text;
	}

	function genp(pos:Position)
	{
		return '% @ ${pos.src}:${pos.min + 1}-${pos.max}\n';
	}

	function genh(h:HElem)
	{
		switch h.def {
		case HList(li):
			var buf = new StringBuf();
			for (i in li)
				buf.add(genh(i));
			return buf.toString();
		case Word(word):
			return gent(word);
		case Wordspace:
			return " ";
		case Emphasis(h):
			return '\\emphasis{${genh(h)}}';
		case Highlight(h):
			return '\\highlight{${genh(h)}}';
		}
	}

	function genv(v:TElem)
	{
		switch v.def {
		case TVList(li):
			var buf = new StringBuf();
			for (i in li)
				buf.add(genv(i));
			return buf.toString();
		case TParagraph(h):
			return '${genh(h)}\\par\n${genp(v.pos)}\n';
		case TVolume(name, count, id, children):
			return '\\volume{${genh(name)}}\n\\label{$id}\n${genp(v.pos)}\n${genv(children)}';
		case TChapter(name, count, id, children):
			return '\\chapter{${genh(name)}}\n\\label{$id}\n${genp(v.pos)}\n${genv(children)}';
		case TSection(name, count, id, children):
			return '\\section{${genh(name)}}\n\\label{$id}\n${genp(v.pos)}\n${genv(children)}';
		case TSubSection(name, count, id, children):
			return '\\subsection{${genh(name)}}\n\\label{$id}\n${genp(v.pos)}\n${genv(children)}';
		case TSubSubSection(name, count, id, children):
			return '\\subsubsection{${genh(name)}}\n\\label{$id}\n${genp(v.pos)}\n${genv(children)}';
		case TFigure(_):
			trace("TODO figure");
			return "";
		case TQuotation(text, by):
			return '\\quotation{${genh(text)}}{${genh(by)}}\n${genp(v.pos)}\n';
		case TList(li):
			var buf = new StringBuf();
			buf.add("\\begin{itemize}\n");
			for (i in li)
				switch i.def {
				case TParagraph(h):
					buf.add('\\item ${genh(h)}${genp(i.pos)}');
				case _:
					buf.add('\\item {${genv(i)}}\n');
				}
			buf.add("\\end{itemize}\n");
			buf.add(genp(v.pos));
			buf.add("\n");
			return buf.toString();
		case TLaTeXPreamble(path):
			// TODO validate path (or has Transform done so?)
			preamble.add('% included from `$path`\n');
			preamble.add(genp(v.pos));
			preamble.add(File.getContent(path).trim());
			preamble.add("\n\n");
			return "";
		}
	}

	public function generate(doc:Document)
	{
		preamble = new StringBuf();
		preamble.add("% This file has been generated; do not edit manually!\n\n");

		var contents = genv(doc);

		var root = new StringBuf();
		root.add(preamble.toString());
		root.add("\\begin{document}\n\n");
		root.add(contents);
		root.add("\\end{document}\n");
		bufs["root.tex"] = root;

		if (!FileSystem.exists(destDir))
			FileSystem.createDirectory(destDir);
		for (p in bufs.keys()) {
			var path = Path.join([destDir, p]);
			File.saveContent(path, bufs[p].toString());
		}
	}

	public function new(destDir)
	{
		// TODO validate destDir
		this.destDir = destDir;
		bufs = new Map();
	}
}

