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
	static function mk<T>(def:T, pos:Position):Elem<T>
		return { def:def, pos:pos };

	public static function compat(d:DElem, id:String):TElem
	{
		assert(d != null);
		assert(d.def != null);
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
		case DBox(no, name, children):
			var sid = id + (id != "" ? "." : "") + "box." + d.id.sure();
			TBox(name, compat(children, sid), no, sid);  // FIXME ids
		case DFigure(no, size, path, caption, copyright):
			var sid = id + (id != "" ? "." : "") + "figure." + d.id.sure();
			TFigure(size, path, caption, copyright, no, sid);  // FIXME ids
		case DTable(no, size, caption, header, rows):
			var sid = id + (id != "" ? "." : "") + "table." + d.id.sure();
			TTable(size, caption, header.map(compat.bind(_, sid)), rows.map(function (r) return r.map(compat.bind(_, sid))), no, sid);  // FIXME ids
		case DList(numbered, li): TList(numbered, [ for (i in li) compat(i, id) ]);
		case DCodeBlock(cte): TCodeBlock(cte);
		case DQuotation(text, by): TQuotation(text, by);
		case DParagraph(text): TParagraph(text);
		case DElemList(li): TElemList([ for (i in li) compat(i, id) ]);
		case DEmpty: null;
		}
		return mk(def, d.pos);
	}

	public static function transform(parsed:parser.Ast) : TElem
	{
		var idc = new IdCtx();
		var noc = new NoCtx();
		return compat(newClean(newVertical(parsed, [], idc, noc)), "");
	}
}

