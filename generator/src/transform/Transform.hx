package transform;  // TODO move out of the package

import parser.Token;
import parser.Ast;
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
	
		
	static function hierarchy(cur : VElem, rest : Rest, pos : Position, count : Array<Int>) : TElem
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
		 
		var t = type+1;
		
		//Reset Sec/Sub/SubSub when sec changes OR when chapter changes everything goes to waste (Reset all BUT VOL AND Chapter)
		while ((type >= SEC && t < OTH) || (type == CHA && t < count.length))
		{
			count[t] = 0;
			t++;
		}
		
		var tf = consume(rest, type, count);
		
		return switch(type)
		{
			case VOL:
				mk(TVolume(_name, count[VOL], tf), pos.span(tf.pos));
			case CHA:
				mk(TChapter(_name, count[CHA], tf), pos.span(tf.pos));
			case SEC:
				mk(TSection(_name, count[SEC], tf), pos.span(tf.pos));
			case SUB:
				mk(TSubSection(_name, count[SUB], tf), pos.span(tf.pos));
			case SUBSUB:
				mk(TSubSubSection(_name, count[SUBSUB], tf), pos.span(tf.pos));
			default:
				throw "Invalid type " + type; //TODO: FIX
		}
	}
	
	static function consume(rest:Rest, stopBefore: Int, count : Array<Int>):TElem
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
			
			if (stopBefore != null && type <= stopBefore) {
				rest.unshift(v);
				break;
			}
			
			tf.push(vertical(v, rest, count));
		}
		
		if(tf.length > 1)
			return mk(TVList(tf), tf[0].pos.span(tf[tf.length - 1].pos));
		else if(tf.length == 1)
			return tf[0];
		else //TODO: THROW
			return null;
	}
	
	static function vertical(v:VElem, rest:Rest, count : Array<Int>):TElem
	{
		switch v.def {
		case VList(li):
			var tf = [];
			while (li.length > 0)
				tf.push(vertical(li.shift(), li, count));
			return mk(TVList(tf), v.pos);  // FIXME v.pos.span(???)
		case Volume(name), Chapter(name), Section(name), SubSection(name), SubSubSection(name):
			return hierarchy(v, rest, v.pos, count);
		case Figure(path, caption, cp):
			count[OTH] = ++count[OTH];
			return mk(TFigure(path, caption, cp, count[OTH]), v.pos);
		case Quotation(text, by):
			return mk(TQuotation(text, by), v.pos);
		case Paragraph(h):
			return mk(TParagraph(h), v.pos);
		case _:
			return mk(null, v.pos);
		}
	}
	
	public static function transform(parsed:parser.Ast) : TElem
	{
		var tf = vertical(parsed, [], [0,0,0,0,0,0]);
		
		//return parsed;
		return tf;
	}

}

