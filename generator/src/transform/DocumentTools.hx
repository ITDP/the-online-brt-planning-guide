package transform;

import transform.NewDocument;

class DocumentTools {
	public static function iter(v:DElem, f:DElem->Void)
	{
		switch v.def {
		case null:
		case DVolume(_,_,i), DChapter(_,_,i), DSection(_,_,i),
			DSubSection(_,_,i), DSubSubSection(_,_,i), DBox(_,_,i):
			f(i);
		case DTable(_, _, _, header, rows):
			for (v in header)
				f(v);
			for (r in rows) {
				for (c in r)
					f(c);
			}
		case DElemList(items), DList(_, items):
			for (i in items)
				f(i);
		case DLaTeXPreamble(_), DLaTeXExport(_), DHtmlApply(_), DFigure(_), DImgTable(_), DQuotation(_), DCodeBlock(_), DParagraph(_), DEmpty:
		}
	}

	public static function map(v:DElem, f:DElem->DElem)
	{
		return { pos:v.pos, id:v.id, def:
			switch v.def {
			case null: null;
			case DVolume(no, name, children):
				DVolume(no, name, f(children));
			case DChapter(no, name, children):
				DChapter(no, name, f(children));
			case DSection(no, name, children):
				DSection(no, name, f(children));
			case DSubSection(no, name, children):
				DSubSection(no, name, f(children));
			case DSubSubSection(no, name, children):
				DSubSubSection(no, name, f(children));
			case DElemList(elem):
				DElemList([for (i in elem) f(i)]);
			case DTable(no, size, caption, header, rows):
				var _header = [for (v in header) f(v)];
				var _rows = [for (r in rows) [for (c in r) f(c)]];
				DTable(no, size, caption, _header, _rows);
			case DBox(no, name, contents):
				DBox(no, name, f(contents));
			case DList(numbered, items):
				DList(numbered, [for (i in items) f(i)]);
			case DLaTeXPreamble(_), DLaTeXExport(_), DHtmlApply(_), DFigure(_), DImgTable(_), DQuotation(_), DCodeBlock(_), DParagraph(_), DEmpty:
				v.def;
			}
		}
	}
}
