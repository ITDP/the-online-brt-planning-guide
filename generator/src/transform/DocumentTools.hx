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
		case DLaTeXPreamble(_), DLaTeXExport(_), DHtmlStore(_), DHtmlToHead(_),
				DTitle(_), DFigure(_), DImgTable(_), DQuotation(_), DCodeBlock(_),
				DParagraph(_), DEmpty:
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
			case DLaTeXPreamble(_), DLaTeXExport(_), DHtmlStore(_), DHtmlToHead(_),
					DTitle(_), DFigure(_), DImgTable(_), DQuotation(_), DCodeBlock(_),
					DParagraph(_), DEmpty:
				v.def;
			}
		}
	}

	/*
	Generate a hierarchy tree of the current DElem
	*/
	public static function hierarchyTree(v:DElem, complete=false)
	{
		var buf = new StringBuf();
		function f(offset:Int, v:DElem) {
			var sectioning = v.def.match(DVolume(_)|DChapter(_)|DSection(_)|DSubSection(_)|DSubSubSection(_));
			if (complete || sectioning) {
				if (offset > 0) {
					for (i in 1...offset)
						buf.add("│ ");
					buf.add("├ ");
				}

				if (!sectioning)
					buf.add("*");
				buf.add(Type.enumConstructor(v.def));

				if (v.id != null) {
					buf.add(": ");
					buf.add(v.id);
				}

				buf.add("\n");
				iter(v, f.bind(offset+1));
			} else {
				iter(v, f.bind(offset));
			}
		}
		f(0, v);
		return buf.toString();
	}
}
