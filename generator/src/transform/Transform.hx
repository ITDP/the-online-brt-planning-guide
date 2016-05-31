package transform;  // TODO move out of the package

import parser.Token;
import parser.Ast;
import transform.Document;

using parser.TokenTools;

private typedef Rest = Array<VElem>;

class Transform {
	
	static function mk<T>(def:T, pos:Position):Elem<T>
		return { def:def, pos:pos };
	
	static function volume(name:HElem, rest:Rest, pos:Position):TElem
	{
		var tf = consume(rest, Volume(null));
		return mk(TVolume(name, 0, tf), pos.span(tf.pos));
	}
	
	static function consume(rest:Rest, stopBefore:Null<VDef>):TElem
	{
		var tf = [];
		while (rest.length > 0) {
			var v = rest.shift();
			if (stopBefore != null && Type.enumIndex(stopBefore) == Type.enumIndex(v.def)) {
				rest.unshift(v);
				break;
			}
			tf.push(vertical(v, rest));
		}
		return mk(TVList(tf), tf[0].pos.span(tf[tf.length - 1].pos));
	}
	
	static function vertical(v:VElem, rest:Rest):TElem
	{
		switch v.def {
		case VList(li):
			var tf = [];
			while (li.length > 0)
				tf.push(vertical(li.shift(), li));
			return mk(TVList(tf), v.pos);  // FIXME v.pos.span(???)
		case Volume(name):
			return volume(name, rest, v.pos);
		case _:
			return mk(null, v.pos);
		}
	}
	
	public static function transform(parsed:parser.Ast) : File
	{
		var tf = vertical(parsed, []);
		trace(tf);
		trace(haxe.Json.stringify(tf));
		return parsed;
	}

}

