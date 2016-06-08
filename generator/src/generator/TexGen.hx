package generator;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import transform.Document;

import Assertion.*;

using Literals;
using StringTools;

class TexGen {
	static var FILE_BANNER = "
	% The Online BRT Planning Guide
	% This file has been generated; do not edit manually!
	".doctrim();

	var destDir:String;
	var preamble:StringBuf;
	var bufs:Map<String,StringBuf>;

	function gent(text:String)
	{
		text = ~/([%{}%#\$\/\\])/.replace(text, "\\$1");  // FIXME complete
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

	function genv(v:TElem, at:String)
	{
		assert(!at.endsWith(".tex"), at, "should not but a directory");
		switch v.def {
		case TVList(li):
			var buf = new StringBuf();
			for (i in li)
				buf.add(genv(i, at));
			return buf.toString();
		case TParagraph(h):
			return '${genh(h)}\\par\n${genp(v.pos)}\n';
		case TVolume(name, count, id, children):
			var path = Path.join([at, id.split(".")[1]+".tex"]);
			var dir = Path.join([at, id.split(".")[1]]);
			var buf = new StringBuf();
			bufs[path] = buf;
			buf.add(FILE_BANNER);
			buf.add('\n\n\\volume{${genh(name)}}\n\\label{$id}\n${genp(v.pos)}\n${genv(children, dir)}');
			return '\\input{$path}\n\n';
		case TChapter(name, count, id, children):
			var path = Path.join([at, id.split(".")[3]+".tex"]);
			var buf = new StringBuf();
			bufs[path] = buf;
			buf.add('\\chapter{${genh(name)}}\n\\label{$id}\n${genp(v.pos)}\n${genv(children, at)}');
			return '\\input{$path}\n\n';
		case TSection(name, count, id, children):
			return '\\section{${genh(name)}}\n\\label{$id}\n${genp(v.pos)}\n${genv(children, at)}';
		case TSubSection(name, count, id, children):
			return '\\subsection{${genh(name)}}\n\\label{$id}\n${genp(v.pos)}\n${genv(children, at)}';
		case TSubSubSection(name, count, id, children):
			return '\\subsubsection{${genh(name)}}\n\\label{$id}\n${genp(v.pos)}\n${genv(children, at)}';
		case TFigure(_):
			trace("TODO figure");
			return "";
		case TBox(contents):
			return '\\beginbox\n\n${genv(contents, at)}\\endbox\n${genp(v.pos)}\n';
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
					buf.add('\\item {${genv(i, at)}}\n');
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
		case THtmlApply(_):
			return "";
		case TTable(caption, header, chd, count, id):
			var buf = new StringBuf();
			buf.add('% FIXME\nTable ${genh(caption)}:\n\n');
			var width = header.length;
			buf.add("\\halign{\n\t\\beforefirstcell");
			for (i in 1...width)
				buf.add("#\\aftercell&\\beforecell");
			buf.add("#\\afterlastcell\\cr\n\t");
			function genCell(i:TElem) {
				return switch i.def {
				case TParagraph(h): genh(h);
				case _: genv(i, at);
				}
			}
			buf.add(header.map(genCell).join("&"));
			buf.add("\\cr\n");
			for (r in chd) {
				assert(r.length == width, header.length, r.length);
				buf.add("\t");
				buf.add(r.map(genCell).join("&"));
				buf.add("\\cr\n");
			}
			buf.add('}\n${genp(v.pos)}\n');
			return buf.toString();
		}
	}

	public function generate(doc:Document)
	{
		preamble = new StringBuf();
		preamble.add(FILE_BANNER);
		preamble.add("\n\n");

		var contents = genv(doc, "./");

		var root = new StringBuf();
		root.add(preamble.toString());
		root.add("\\begin{document}\n\n");
		root.add(contents);
		root.add("\\end{document}\n");
		bufs["book.tex"] = root;

		for (p in bufs.keys()) {
			var path = Path.join([destDir, p]);
			FileSystem.createDirectory(Path.directory(path));
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

