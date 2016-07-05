package transform;  // TODO move out of the package

import Assertion.*;
import parser.Ast;
import parser.Token;
import transform.Document;

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
		switch v.def {
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
			var _caption = htrim(caption);
			var _cp = htrim(cp);
			return mk(TFigure(size, path, _caption, _cp, count[CNT_FIGURE], name), v.pos);
		case Box(name, contents):
			count[CNT_BOX] = ++count[CNT_BOX];
			names[CNT_BOX] = count[CNT_CHAPTER] + " " + count[CNT_BOX];
			var id = idGen(names, CNT_BOX);
			return mk(TBox(htrim(name), vertical(contents, rest, count, names), count[CNT_BOX], id), v.pos);
		case Quotation(text, by):
			var _text = htrim(text);
			var _by = htrim(by);
			return mk(TQuotation(_text, _by), v.pos);
		case List(items):
			var tf = [];
			for (i in items) {
				var v = vertical(i, rest, count, names);
				if (v != null)
					tf.push(v);
			}
			return mk(TList(tf), v.pos);
		case Paragraph(h):
			var _h = htrim(h);
			return mk(TParagraph(_h), v.pos);
		case MetaReset(name, val):
			switch name {
			case "volume": count[CNT_VOLUME] = val;
			case "chapter": count[CNT_CHAPTER] = val;
			case _: throw 'Unexpected counter name: $name';
			}
			return null;
		case LaTeXPreamble(path):
			return mk(TLaTeXPreamble(path), v.pos);
		case LaTeXExport(path):
			return mk(TLaTeXExport(path), v.pos);
		case HtmlApply(path):
			return mk(THtmlApply(path), v.pos);
		case Table(size, caption, header, rows):
			count[CNT_TABLE] = ++count[CNT_TABLE];
			names[CNT_TABLE] = count[CNT_CHAPTER] + " " + count[CNT_TABLE];
			var name = idGen(names, CNT_TABLE);
			var _caption = htrim(caption);
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
		}
	}
	
	
	static var tarray : Array<HToken>;
	
	static function htrim(elem : HElem)
	{
		tarray = new Array<HToken>();
		tokenify(elem);
		ltrim();
		rtrim();
		elem = rebuild();
		return elem;
	}
	
	static function tokenify(elem : HElem)
	{
		switch(elem.def)
		{
			case Word(s):
				Assertion.weakAssert(!StringTools.endsWith(s, " "));
				tarray.push(mk(TWord(s), elem.pos));
			case Wordspace:
				tarray.push(mk(Space, elem.pos));
			case Emphasis(el):
				tarray.push(mk(Emph, elem.pos));
				tokenify(el);
			case Highlight(el):
				tarray.push(mk(High, elem.pos));
				tokenify(el);
			case HList(li):
				tarray.push(mk(LiStart, elem.pos));
				for(el in li)
					tokenify(el);
				tarray.push(mk(LiEnd, elem.pos));				
			case Code(c):
				tarray.push(mk(TCode(c), elem.pos));
		}
	}
	
	static function ltrim()
	{
		var cur : HToken = null;
		var i = 0;
		
		while (i < tarray.length)
		{
			if(!tarray[i].def.match(TWord(_) | TCode(_) | Space))  // FIXME what if TCode(_.length => size), size == 0?
			{
				i++;
				continue;
			}
			
			if(!checkBrothers(tarray[i], cur))
			{
				cur = tarray[i];
				i++;
			}
			else
				tarray.remove(tarray[i]);
		}
	}
	
	static function rtrim()
	{
		var cur : HToken = null;
		var i = 0;
		tarray.reverse();
		while(i < tarray.length)
		{
			if(!tarray[i].def.match(TWord(_) | TCode(_) | Space))  // FIXME what if TCode(_.length => size), size == 0?
			{
				i++;
				continue;
			}
			if(!checkBrothers(tarray[i], cur))
			{
				cur = tarray[i];
				i++;
			}
			else
				tarray.remove(tarray[i]);
		}
		tarray.reverse();
	}
	
	static function rebuild() : HElem
	{
		var c = tarray.shift();
		
		switch(c.def)
		{
			case TWord(h):
				return mk(Word(h), c.pos);
			case TCode(t):
				return mk(Code(t), c.pos);
			case Space:
				return mk(Wordspace, c.pos);
			case Emph:
				return mk(Emphasis(rebuild()), c.pos);
			case High:
				return mk(Highlight(rebuild()), c.pos);
			case LiStart:
				var list = [];
				while(!tarray[0].def.match(LiEnd))
				{
					list.push(rebuild());	
				}
				tarray.shift();
				return mk(HList(list), c.pos);
			default:
				throw "Unexpected token : " + c.def.getName() + " at line: " + c.pos.min + " with src: " + c.pos.src;
		}
	}
	
	static function checkBrothers(cur : HToken, oth : HToken)
	{
		if (oth == null) return cur.def == Space;
		else 			 return(cur.def == Space && oth.def == cur.def);
	}
	
	
	static function txtFromHorizontal(elem : HElem)
	{
		return switch(elem.def)
		{
			case Wordspace: " ";
			case Emphasis(t), Highlight(t): txtFromHorizontal(t);
			case Word(w), Code(w): w;
			case HList(li):
				var buf = new StringBuf();
				for (l in li)
				{
					buf.add(txtFromHorizontal(l));
				}
				buf.toString();
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

