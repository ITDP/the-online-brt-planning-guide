package transform;  // TODO move out of the package

import Assertion.*;
import parser.Ast;
import parser.Token;
import transform.Document;

using parser.TokenTools;

private typedef Rest = Array<VElem>;

class Transform {

	static inline var VOL = 0;
	static inline var CHA = 1;
	static inline var SEC = 2;
	static inline var SUB = 3;
	static inline var SUBSUB = 4;
	//Figs,tbls,etc
	static inline var OTH = 5;

	static function mk<T>(def:T, pos:Position):Elem<T>
		return { def:def, pos:pos };


	static function hierarchy(cur : VElem, rest : Rest, pos : Position, count : Array<Int>, names : Array<String>) : TElem
	{
		var type = null;
		var _name = null;
		switch(cur.def)
		{
			case Volume(name):
				type = VOL;
				_name = name;
			case Chapter(name):
				type = CHA;
				_name = name;
			case Section(name):
				type = SEC;
				_name = name;
			case SubSection(name):
				type = SUB;
				_name = name;
			case SubSubSection(name):
				type = SUBSUB;
				_name = name;
			default:
				throw "Invalid " + cur.def;
		}

		count[type] = ++count[type];
		var c = count[type];  // save the count to make sure that \meta\reset only applies to the _next_ element

		var t = type+1;

		//Reset Sec/Sub/SubSub when sec changes OR when chapter changes everything goes to waste (Reset all BUT VOL AND Chapter)
		while ((type >= SEC && t < OTH) || (type == CHA && t < count.length))
		{
			count[t] = 0;
			t++;
		}

		names[type] = horizontal(_name);
		var tf = consume(rest, type, count, names);
		var id = idGen(names, type);

		return switch(type)
		{
			case VOL:
				mk(TVolume(_name, c, id, tf), pos.span(tf.pos));
			case CHA:
				mk(TChapter(_name, c, id, tf), pos.span(tf.pos));
			case SEC:
				mk(TSection(_name, c, id, tf), pos.span(tf.pos));
			case SUB:
				mk(TSubSection(_name, c, id, tf), pos.span(tf.pos));
			case SUBSUB:
				mk(TSubSubSection(_name, c, id, tf), pos.span(tf.pos));
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
				case Volume(_): VOL;
				case Chapter(_): CHA;
				case Section(_) : SEC;
				case SubSection(_) : SUB;
				case SubSubSection(_) : SUBSUB;
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
		switch v.def {
		case VList(li):
			var tf = [];
			while (li.length > 0) {
				var v = vertical(li.shift(), li, count, names);
				if (v != null)
					tf.push(v);
			}
			return mk(TVList(tf), v.pos);  // FIXME v.pos.span(???)
		case Volume(name), Chapter(name), Section(name), SubSection(name), SubSubSection(name):
			return hierarchy(v, rest, v.pos, count, names);
		case Figure(path, caption, cp):
			count[OTH] = ++count[OTH];
			names[OTH] = count[CHA] + " " + count[OTH];
			var name = idGen(names, OTH);
			return mk(TFigure(path, caption, cp, count[OTH], name), v.pos);
		case Box(contents):
			return mk(TBox(vertical(contents, rest, count, names)), v.pos);
		case Quotation(text, by):
			return mk(TQuotation(text, by), v.pos);
		case List(items):
			var tf = [];
			for (i in items) {
				var v = vertical(i, rest, count, names);
				if (v != null)
					tf.push(v);
			}
			return mk(TList(tf), v.pos);
		case Paragraph(h):
			return mk(TParagraph(h), v.pos);
		case MetaReset(name, val):
			switch name {
			case "volume": count[VOL] = val;
			case "chapter": count[CHA] = val;
			case _: throw 'Unexpected counter name: $name';
			}
			return null;
		case LaTeXPreamble(path):
			return mk(TLaTeXPreamble(path), v.pos);
		case HtmlApply(path):
			return mk(THtmlApply(path), v.pos);
		case Table(size, caption, header, rows):
			count[OTH] = ++count[OTH];
			names[OTH] = count[CHA] + " " + count[OTH];
			var name = idGen(names, OTH);
			
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
			return mk(TTable(size, caption, rvalues[0], rvalues.slice(1), count[OTH], name), v.pos);
			
		}
	}

	static function horizontal(elem : HElem)
	{
		return switch(elem.def)
		{
			case Wordspace: " ";
			case Emphasis(t), Highlight(t): horizontal(t);
			case Word(w) : w;
			case HList(li):
				var buf = new StringBuf();
				for (l in li)
				{
					buf.add(horizontal(l));
				}
				buf.toString();

		}
	}
	public static function transform(parsed:parser.Ast) : TElem
	{
		var tf = vertical(parsed, [], [0,0,0,0,0,0],['','','','','','']);

		//return parsed;
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
				case VOL:
					"volume.";
				case CHA:
					"chapter.";
				case SEC:
					"section.";
				case SUB:
					"subsection.";
				case SUBSUB:
					"subsubsection.";
				case OTH:
					"other.";
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

