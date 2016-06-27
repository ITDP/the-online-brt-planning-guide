package generator.tex;

import transform.Document;

import Assertion.*;

using Literals;
using parser.TokenTools;

class LargeTable {
	// internal commands; for now, no real expectation of tunning them at runtime
	static inline var CHAR_COST = 1;
	static inline var SPACE_COST = 1;
	static inline var LINE_BREAK_COST = 5;
	static inline var BULLET_COST = 1;
	static inline var FIG_MARK_COST = 20;
	static inline var TBL_MARK_COST = 20;
	static inline var BAD_COST = 1000;
	static inline var QUOTE_COST = 1;
	static inline var EM_DASH_COST = 2;

	// external parameters
	// TODO make metas commands to change them
	static inline var NO_MODULES = 30;
	static inline var NO_MODULES_LARGE = 46;
	static inline var MIN_COLUMN = 5;
	static inline var SEPAR_SIZE = 1;

	static function pseudoHTypeset(h:HElem)
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

	static function pseudoTypeset(v:TElem)
	{
		return switch v.def {
		case TLaTeXPreamble(_), THtmlApply(_): 0;
		case TVolume(_), TChapter(_), TSection(_), TSubSection(_), TSubSubSection(_): BAD_COST; // not allowed in tables
		case TVList(li):
			var cnt = 0.;
			for (i in li)
				cnt += pseudoTypeset(i);
			cnt/li.length;
		case TFigure(_, _, caption, cright, _): TBL_MARK_COST + pseudoHTypeset(caption) + SPACE_COST + pseudoHTypeset(cright);
		case TTable(_), TBox(_): BAD_COST; // not allowed (for now?)
		case TQuotation(text, by): QUOTE_COST + pseudoHTypeset(text) + QUOTE_COST + LINE_BREAK_COST + EM_DASH_COST + pseudoHTypeset(by);
		case TList(li):
			var cnt = 0.;
			for (i in li)
				cnt += BULLET_COST + SPACE_COST + pseudoTypeset(i);
			cnt/li.length;
		case TParagraph(h): pseudoHTypeset(h);
		}
	}

	// TODO document the objective and the implementation
	static function computeTableWidths(noModules, header, rows:Array<Array<TElem>>)
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
		var available = noModules - (width - 1)*SEPAR_SIZE;
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
		weakAssert(check == 0 && Lambda.foreach(icost, function (x) return x >= MIN_COLUMN), check, width, ncost, icost, priori, itCnt);
		return icost;
	}

	public static function gen(v:TElem, gen:TexGen, genAt:String)
	{
		assert(v.def.match(TTable(_)), v);
		switch v.def {
		case TTable(size, caption, header, rows, count, id):
			var buf = new StringBuf();
			buf.add('\\tabletitle{$count}{${gen.genh(caption)}}\n\n');
			var width = header.length;

			switch size {
			case MarginWidth:
				buf.add("\\halign {%\n\t");
				for (i in 0...width) {
					if (i > 0)
						buf.add('\\hbox to ${SEPAR_SIZE*.5}\\tablemodule{}&\n\t\\hbox to ${SEPAR_SIZE*.5}\\tablemodule{}');
					buf.add("\\sffamily\\footnotesize\\noindent#");
				}
			case _:
				var large = size.match(FullWidth);
				var noModules = large ? NO_MODULES_LARGE : NO_MODULES;
				var colWidths = computeTableWidths(noModules, header, rows);
				if (Main.debug) {
					trace(v.pos.toLinePosition());
					trace(colWidths);
				}
				buf.add('\\halign to ${noModules}\\tablemodule{%');
				if (large) {
					buf.add('
						% requires the ifoddpage package
						\\relax\\checkoddpage\\ifoddpage\\else%
							\\kern ${NO_MODULES-noModules}\\tablemodule%
						\\fi%'.doctrim());
				}
				buf.add("\n\t");
				for (i in 0...width) {
					if (i > 0)
						buf.add('\\hbox to ${SEPAR_SIZE*.5}\\tablemodule{}&\n\t\\hbox to ${SEPAR_SIZE*.5}\\tablemodule{}');
					var size = colWidths[i];
					buf.add('\\vtop{\\sffamily\\footnotesize\\noindent\\hsize=${size}\\tablemodule#}');
				}
			}

			buf.add("\\cr\n\t");
			function genCell(i:TElem) {
				return switch i.def {
				case TParagraph(h): gen.genh(h);
				case _: gen.genv(i, genAt);
				}
			}
			buf.add("\\color{gray75}\\bfseries ");
			buf.add(header.map(genCell).join("& \\color{gray75}\\bfseries "));
			buf.add(" \\cr\n\t\\noalign{\\vskip 1mm} \\hline \\noalign{\\vskip 2mm} \n");
			for (r in rows) {
				weakAssert(r.length == width, header.length, r.length);
				buf.add("\t\\color{gray50}");
				if (r.length != width)
					buf.add("% ");  // FIXME
				buf.add(r.map(genCell).join("&\n").split("\n").join("\n\t\\color{gray50}"));
				buf.add("\\cr\n\t\\noalign{\\vskip 2mm \n}");
			}
			buf.add('}\n${gen.genp(v.pos)}\n');
			return buf.toString();
		case _:
			// should never happen
			return "";
		}
	}
}

