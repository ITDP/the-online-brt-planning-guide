package transform;  // TODO move out of the package

import transform.NewDocument;
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

	// TODO remove
	static function compat(d:DElem):TElem
	{
		var def = switch d.def {
		case DHtmlApply(p): THtmlApply(p);
		case DLaTeXPreamble(p): TLaTeXPreamble(p);
		case DLaTeXExport(src, dst): TLaTeXExport(src, dst);
		case DCodeBlock(cte): TCodeBlock(cte);
		case DQuotation(text, by): TQuotation(text, by);
		case DParagraph(text): TParagraph(text);
		case DList(li): TVList([ for (i in li) compat(i) ]);
		case DEmpty: null;
		}
		return mk(def, d.pos);
	}

	static function hierarchy(type:Int, name:HElem, rest:Rest, pos:Position, count:Array<Int>, names:Array<String>):TElem
	{
		count[type] = ++count[type];
		var c = count[type];  // save the count to make sure that \meta\reset only applies to the _next_ element

		var t = type+1;

		// volume => reset all children but chapter
		// chapter => reset all children
		// sections => reset all hierarchy children, but no boxes, figures or tables
		var resetMin = type + (type == CNT_VOLUME ? 2 : 1);
		var resetMax = type <= CNT_CHAPTER ? count.length : CNT_FIRST_LINEAR;
		for (i in resetMin...resetMax)
			count[i] = 0;

		names[type] = txtFromHorizontal(name);
		var tf = consume(rest, type, count, names);
		var id = idGen(names, type);

		return switch(type)
		{
			case CNT_VOLUME:
				mk(TVolume(name, c, id, tf), pos.span(tf.pos));
			case CNT_CHAPTER:
				mk(TChapter(name, c, id, tf), pos.span(tf.pos));
			case CNT_SECTION:
				mk(TSection(name, c, id, tf), pos.span(tf.pos));
			case CNT_2SECTION:
				mk(TSubSection(name, c, id, tf), pos.span(tf.pos));
			case CNT_3SECTION:
				mk(TSubSubSection(name, c, id, tf), pos.span(tf.pos));
			default:
				throw "Invalid type " + type; //TODO: FIX
		}
	}

	static function consume(rest:Rest, stopBefore:Null<Int>, count : Array<Int>, names : Array<String>):TElem
	{
		var tf = [];
		while (rest.length > 0) {
			var v = rest.shift();
			var type = switch(v.def)
			{
				case Volume(_): CNT_VOLUME;
				case Chapter(_): CNT_CHAPTER;
				case Section(_) : CNT_SECTION;
				case SubSection(_) : CNT_2SECTION;
				case SubSubSection(_) : CNT_3SECTION;
				default : null;
			}

			if (stopBefore != null && type != null && type <= stopBefore) {
				rest.unshift(v);
				break;
			}

			var tv = vertical(v, rest, count, names);
			if (tv != null)
				tf.push(tv);
		}

		if(tf.length > 1)
			return mk(TVList(tf), tf[0].pos.span(tf[tf.length - 1].pos));
		else if(tf.length == 1)
			return tf[0];
		else //TODO: THROW
			return null;
	}

	static function vertical(v:VElem, rest:Rest, count : Array<Int>, names : Array<String>):TElem
	{
		assert(v != null);
		if (v == null)
			return null;
		switch v.def {
		case VEmpty:
			return null;
		case VList(li):
			var tf = [];
			while (li.length > 0) {
				var v = vertical(li.shift(), li, count, names);
				if (v != null)
					tf.push(v);
			}
			return mk(TVList(tf), v.pos);  // FIXME v.pos.span(???)
		case Volume(name):
			return hierarchy(CNT_VOLUME, name, rest, v.pos, count, names);
		case Chapter(name):
			return hierarchy(CNT_CHAPTER, name, rest, v.pos, count, names);
		case Section(name):
			return hierarchy(CNT_SECTION, name, rest, v.pos, count, names);
		case SubSection(name):
			return hierarchy(CNT_2SECTION, name, rest, v.pos, count, names);
		case SubSubSection(name):
			return hierarchy(CNT_3SECTION, name, rest, v.pos, count, names);
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
		case List(numbered, items):
			var tf = [];
			for (i in items) {
				var v = vertical(i, rest, count, names);
				if (v != null)
					tf.push(v);
			}
			return mk(TList(numbered, tf), v.pos);
		case MetaReset(name, val):
			switch name {
			case "volume": count[CNT_VOLUME] = val;
			case "chapter": count[CNT_CHAPTER] = val;
			case _: throw 'Unexpected counter name: $name';
			}
			return null;
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
			return compat(newVertical(v));
		}
	}

	static function txtFromHorizontal(elem : HElem)
	{
		return switch(elem.def)
		{
			case Wordspace: " ";
			case Emphasis(t), Highlight(t): txtFromHorizontal(t);
			case Word(w), InlineCode(w), Math(w): w;
			case HList(li):
				var buf = new StringBuf();
				for (l in li)
				{
					buf.add(txtFromHorizontal(l));
				}
				buf.toString();
			case HEmpty: "";
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

