package parser;

import haxe.macro.Context.*;
import haxe.macro.Expr;

using StringTools;
using haxe.macro.ExprTools;

class MacroTools {
	static var cachedDefs:Array<String>;  // don't access directly, call getDefs() instead

	static function getDefs(?clear=false)
	{
		if (!clear && cachedDefs != null) return cachedDefs;
		var ret = [];
		var m = getModule("parser.Ast");
		for (t in m) {
			switch t {
			case TEnum(_.get() => t, []):
				if (!t.name.endsWith("Def")) continue;
				for (cons in t.names) {
					if (Lambda.has(ret, cons))
						error("AST constructor name reuse not supported", currentPos());
					ret.push(cons);
				}
			case _:
			}
		}
		cachedDefs = ret;
		return ret;
	}

	static function lastPart(s:String, sep:String)
		return s.substr(s.lastIndexOf(sep) + 1);

	static function type(name:String, expr:Expr, pos)
		try
			typeof(expr)
		catch (e:Dynamic)
			error('Wrong argument type for @$name: ${e.split("\n")[0]}', pos);

	static function transform(expr:Expr, src:String, min:Int, ret:{ max:Int }) {
		return switch expr.expr {
		case EMeta({ name:name, params:[v] }, sub):
			switch lastPart(name, ":") {
			case "src":
				type(name, macro ($v:String), v.pos);
				transform(sub, v.getValue(), min, ret);
			case "len":
				type(name, macro ($v:Int), v.pos);
				ret.max += v.getValue();
				transform(sub, src, min, ret);
			case "skip":
				type(name, macro ($v:Int), v.pos);
				var sv = v.getValue();
				min += sv;
				ret.max += sv;
				transform(sub, src, min, ret);
			case _:
				warning('Unsupported @$name or wrong number of params, ignoring', expr.pos);
				transform(sub, src, min, ret);
			}
		case EMeta({ name:name }, sub):
			warning('Unsupported @$name or wrong number of params, ignoring', expr.pos);
			transform(sub, src, min, ret);
		case ECall({ expr:EConst(CIdent(lastPart(_, ".") => c)) }, params)
		if (Lambda.has(getDefs(), c)):
			params = params.map(transform.bind(_, src, min, ret));
			var edef = { expr:ECall({ expr:EConst(CIdent(c)), pos:expr.pos }, params), pos:expr.pos };
			macro { def:$edef, pos:{ src:$v{src}, min:$v{min}, max:$v{ret.max} } };
		case _:
			expr.map(transform.bind(_, src, min, ret));
		}
	}

	/*
	Generate real Document ASTs from pseudo ASTs with only VDefs and HDefs.
	*/
	public static macro function make(expr:Expr):Expr
		return transform(expr, getLocalModule()+".hx", 0, { max:0 });
}

