// TODO remove this entire module

package transform;  // TODO move out of the package

import transform.Context;
import transform.NewDocument;
import transform.NewTransform.clean in newClean;
import transform.NewTransform.horizontal in newHorizontal;
import transform.NewTransform.vertical in newVertical;

import parser.Ast;
import parser.Token;
import transform.Document;

import Assertion.*;
using parser.TokenTools;

private typedef Rest = Array<VElem>;

class Transform {
	static inline var CNT_VOLUME = 0;
	static inline var CNT_CHAPTER = 1;
	static inline var CNT_SECTION = 2;
	static inline var CNT_2SECTION = 3;
	static inline var CNT_3SECTION = 4;
	static inline var CNT_BOX = 5;
	static inline var CNT_FIGURE = 6;
	static inline var CNT_TABLE = 7;
	static inline var CNT_FIRST_LINEAR = CNT_BOX;

	static function mk<T>(def:T, pos:Position):Elem<T>
		return { def:def, pos:pos };

	static function compat(d:DElem, id:String):TElem
	{
		var def = switch d.def {
		case DHtmlApply(p): THtmlApply(p);
		case DLaTeXPreamble(p): TLaTeXPreamble(p);
		case DLaTeXExport(src, dst): TLaTeXExport(src, dst);
		case DVolume(no, name, children):
			var sid = id + (id != "" ? "." : "") + "volume." + d.id.sure();
			TVolume(name, no, sid, compat(children, sid));
		case DChapter(no, name, children):
			var sid = id + (id != "" ? "." : "") + "chapter." + d.id.sure();
			TChapter(name, no, sid, compat(children, sid));
		case DSection(no, name, children):
			var sid = id + (id != "" ? "." : "") + "section." + d.id.sure();
			TSection(name, no, sid, compat(children, sid));
		case DSubSection(no, name, children):
			var sid = id + (id != "" ? "." : "") + "subsection." + d.id.sure();
			TSubSection(name, no, sid, compat(children, sid));
		case DSubSubSection(no, name, children):
			var sid = id + (id != "" ? "." : "") + "subsubsection." + d.id.sure();
			TSubSubSection(name, no, sid, compat(children, sid));
		case DList(numbered, li): TList(numbered, [ for (i in li) compat(i, id) ]);
		case DCodeBlock(cte): TCodeBlock(cte);
		case DQuotation(text, by): TQuotation(text, by);
		case DParagraph(text): TParagraph(text);
		case DElemList(li): TElemList([ for (i in li) compat(i, id) ]);
		case DEmpty: null;
		}
		return mk(def, d.pos);
	}

	static function vertical(v:VElem, rest:Rest, count : Array<Int>, names : Array<String>):TElem
	{
		assert(v != null);
		switch v.def {
		case Figure(size, path, caption, cp):
			count[CNT_FIGURE] = ++count[CNT_FIGURE];
			names[CNT_FIGURE] = count[CNT_CHAPTER] + " " + count[CNT_FIGURE];
			var name = idGen(names, CNT_FIGURE);
			var _caption = newHorizontal(caption);
			var _cp = newHorizontal(cp);
			return mk(TFigure(size, path, _caption, _cp, count[CNT_FIGURE], name), v.pos);
		case Box(name, contents):
			count[CNT_BOX] = ++count[CNT_BOX];
			names[CNT_BOX] = count[CNT_CHAPTER] + " " + count[CNT_BOX];
			var id = idGen(names, CNT_BOX);
			return mk(TBox(newHorizontal(name), vertical(contents, rest, count, names), count[CNT_BOX], id), v.pos);
		case LaTeXPreamble(path):
			return mk(TLaTeXPreamble(path), v.pos);
		case LaTeXExport(src, dest):
			return mk(TLaTeXExport(src, dest), v.pos);
		case HtmlApply(path):
			return mk(THtmlApply(path), v.pos);
		case Table(size, caption, header, rows):
			count[CNT_TABLE] = ++count[CNT_TABLE];
			names[CNT_TABLE] = count[CNT_CHAPTER] + " " + count[CNT_TABLE];
			var name = idGen(names, CNT_TABLE);
			var _caption = newHorizontal(caption);
			var rvalues = [];
			for (r in [header].concat(rows))  // POG
			{
				var cellvalues = [];
				for (value in r)
					cellvalues.push(vertical(value, rest, count, names));
					//TODO: v.pos.span(?) --> Should I Add its length?
				rvalues.push(cellvalues);
			}
			//TODO: v.pos.span(?) --> Should I Add its length?
			return mk(TTable(size, _caption, rvalues[0], rvalues.slice(1), count[CNT_TABLE], name), v.pos);
		case _:
			var idc = new IdCtx();
			var noc = new NoCtx();
			return compat(newClean(newVertical(v, rest, idc, noc)), "");
		}
	}

	public static function transform(parsed:parser.Ast) : TElem
	{
		var baseCounters = [for (i in CNT_VOLUME...(CNT_TABLE+1)) 0];
		var baseNames = [for (i in CNT_VOLUME...(CNT_TABLE+1)) ""];

		var tf = vertical(parsed, [], baseCounters, baseNames);
		return tf;
	}

	static function idGen(names : Array<String>, elem : Int)
	{
		var i = 0;
		var str = new StringBuf();

		while (i <= elem)
		{
			var before = switch(i)
			{
				case CNT_VOLUME:
					"volume.";
				case CNT_CHAPTER:
					"chapter.";
				case CNT_SECTION:
					"section.";
				case CNT_2SECTION:
					"subsection.";
				case CNT_3SECTION:
					"subsubsection.";
				case CNT_BOX:
					"box.";
				case CNT_FIGURE:
					"figure.";
				case CNT_TABLE:
					"table.";
				default:
					null;
			}

			var clearstr = names[i];


			clearstr = StringTools.replace(clearstr," ", "-");

			var reg = ~/[^a-zA-Z0-9-]+/g;

			if(clearstr.length == 0)
			{
				i++;
				continue;
			}

			clearstr = reg.replace(clearstr, "").toLowerCase();

			if(i != elem)
				str.add(before + clearstr + ".");
			else
				str.add(before + clearstr);

			i++;
		}

		return str.toString();
	}
}

