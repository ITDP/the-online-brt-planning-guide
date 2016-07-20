package transform;

import transform.Document;

class DocumentTools {
	public static function iter(v:TElem, f:TElem->Void)
	{
		switch v.def {
		case null:
		case TVolume(_,_,_,i), TChapter(_,_,_,i), TSection(_,_,_,i),
			TSubSection(_,_,_,i), TSubSubSection(_,_,_,i), TBox(_,i,_):
			f(i);
		case TTable(_, _, header, rows, _):
			for (v in header)
				f(v);
			for (r in rows) {
				for (c in r)
					f(c);
			}
		case TVList(items), TList(_, items):
			for (i in items)
				f(i);
		case TLaTeXPreamble(_), TLaTeXExport(_), THtmlApply(_), TFigure(_), TQuotation(_), TCodeBlock(_), TParagraph(_):
		}
	}
	public static function map(v:TElem, f:TElem->TElem)
	{
		return { pos:v.pos, def:
			switch v.def {
			case null: null;
			case TVolume(name, count, id, children):
				TVolume(name, count, id, f(children));
			case TChapter(name, count, id, children):
				TChapter(name, count, id, f(children));
			case TSection(name, count, id, children):
				TSection(name, count, id, f(children));
			case TSubSection(name, count, id, children):
				TSubSection(name, count, id, f(children));
			case TSubSubSection(name, count, id, children):
				TSubSubSection(name, count, id, f(children));
			case TVList(elem):
				TVList([for (i in elem) f(i)]);
			case TTable(size, caption, header, rows, count, id):
				var _header = [for (v in header) f(v)];
				var _rows = [for (r in rows) [for (c in r) f(c)]];
				TTable(size, caption, _header, _rows, count, id);
			case TBox(name, contents, count, id):
				TBox(name, f(contents), count, id);
			case TList(numbered, items):
				TList(numbered, [for (i in items) f(i)]);
			case TLaTeXPreamble(_), TLaTeXExport(_), THtmlApply(_), TFigure(_), TQuotation(_), TCodeBlock(_), TParagraph(_):
				v.def;
			}
		}
	}
}
