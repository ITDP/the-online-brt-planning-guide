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

	static inline var CHAR_COST = 1;
	static inline var SPACE_COST = 1;
	static inline var PAR_BREAK_COST = 10;
	static inline var LINE_BREAK_COST = 10;
	static inline var BULLET_COST = 1;
	static inline var FIG_MARK_COST = 10;
	static inline var TBL_MARK_COST = 10;
	static inline var BAD_COST = 1000;
	static inline var QUOTE_COST = 1;
	static inline var EM_DASH_COST = 2;
	static inline var NO_MODULES = 30;
	static inline var MIN_COLUMN = 4;
	static inline var SEPAR_SIZE = 1;

	function pseudoHTypeset(h:HElem)
	{
		return switch h.def {
		case Wordspace: SPACE_COST;
		case Emphasis(i), Highlight(i): pseudoHTypeset(i);
		case Word(w): w.length;
		case HList(li):
			var cnt = 0;
			for (i in li)
				cnt += pseudoHTypeset(i);
			cnt;
		}
	}

	function pseudoTypeset(v:TElem)
	{
		return switch v.def {
		case TLaTeXPreamble(_), THtmlApply(_): 0;
		case TVolume(_), TChapter(_), TSection(_), TSubSection(_), TSubSubSection(_): BAD_COST; // not allowed in tables
		case TVList(li):
			var cnt = 0;
			for (i in li) {
				cnt += pseudoTypeset(i);
				if (cnt > 0)
					cnt += PAR_BREAK_COST;
			}
			cnt;
		case TFigure(_, caption, cright, _): TBL_MARK_COST + pseudoHTypeset(caption) + SPACE_COST + pseudoHTypeset(cright);
		case TTable(_), TBox(_): BAD_COST; // not allowed (for now?)
		case TQuotation(text, by): QUOTE_COST + pseudoHTypeset(text) + QUOTE_COST + LINE_BREAK_COST + EM_DASH_COST + pseudoHTypeset(by);
		case TList(li):
			var cnt = 0;
			for (i in li) {
				cnt += BULLET_COST + SPACE_COST + pseudoTypeset(i);
				if (cnt > 0)
					cnt += LINE_BREAK_COST;
			}
			cnt;
		case TParagraph(h): pseudoHTypeset(h);
		}
	}

	// TODO document the objective and the implementation
	function computeTableWidths(header, rows:Array<Array<TElem>>)
	{
		var width = header.length;
		var cost = header.map(pseudoTypeset);
		for (i in 0...rows.length) {
			var r = rows[i];
			if (r.length != width) continue;  // FIXME
			for (j in 0...width) {
				var c = r[j];
				cost[j] += pseudoTypeset(c);
			}
		}
		var tcost = Lambda.fold(cost, function (p,x) return p+x, 0);
		var available = NO_MODULES - (width - 1)*SEPAR_SIZE;
		var ncost = cost.map(function (x) return available/tcost*x);
		for (i in 0...width) {
			if (ncost[i] < MIN_COLUMN)
				ncost[i] = MIN_COLUMN;
		}
		var icost = ncost.map(Math.round);
		var miss = available - Lambda.fold(icost, function (p,x) return p+x, 0);
		var priori = [for (i in 0...width) i];
		var diff = [for (i in 0...width) Math.abs(ncost[i] - icost[i])];
		priori.sort(function (a,b) return Reflect.compare(diff[b], diff[a]));
		var itCnt = 0;
		while (miss != 0 && itCnt++ < 4) {
			for (p in 0...width) {
				var i = priori[p];
				if (diff[i] == 0) continue;
				if (miss > 0) {
					icost[i]++;
					miss--;
				} else if (miss < 0) {
					if (icost[i] - 1 < MIN_COLUMN) continue;
					icost[i]--;
					miss++;
				} else {
					break;
				}
			}
		}
		var check = available - Lambda.fold(icost, function (p,x) return p+x, 0);
		assert(check == 0 && Lambda.foreach(icost, function (x) return x >= MIN_COLUMN), check, width, ncost, icost, priori, itCnt);
		return icost;
	}

	function genTable(genAt, pos, caption, header:Array<TElem>, rows:Array<Array<TElem>>, count, id)
	{
		var colWidths = computeTableWidths(header, rows);
		var buf = new StringBuf();
		buf.add('% FIXME\nTable ${genh(caption)}:\n\n');
		var width = header.length;
		buf.add("\\halign to 154mm{\\kern -49mm\n\t\\hfill");
		var t = 154/105*1.75;
		for (i in 0...width) {
			if (i > 0)
				buf.add('\\hbox to ${t}mm{}&\\hbox to ${t}mm{}');
			var size = colWidths[i]*154/105*3.5;
			buf.add('\\vtop{\\sffamily\\footnotesize\\noindent\\hsize=${size}mm#}');
		}
		buf.add("\\cr\n\t");
		function genCell(i:TElem) {
			return switch i.def {
			case TParagraph(h): genh(h);
			case _: genv(i, genAt);
			}
		}
		buf.add(header.map(genCell).join("&"));
		buf.add("\\cr\n");
		for (r in rows) {
			weakAssert(r.length == width, header.length, r.length);
			buf.add("\t");
			if (r.length != width)
				buf.add("% ");  // FIXME
			buf.add(r.map(genCell).join("&"));
			buf.add("\\cr\n");
		}
		buf.add('}\n${genp(pos)}\n');
		return buf.toString();
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
			return genTable(at, v.pos, caption, header, chd, count, id);
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

