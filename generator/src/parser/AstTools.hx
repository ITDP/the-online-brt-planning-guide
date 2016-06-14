package parser;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context.*;
using haxe.macro.ExprTools;
using StringTools;
#else
import parser.Ast;
import parser.Token;
#end

/**
Tools for constructing, manupilating or testing ASTs.

Designed for the parsing ASTs, but they should also work on post-transform
ASTs.
**/
class AstTools {
#if macro
	static var cachedDefs:Array<String>;  // don't access directly, call getDefs() instead
	static function getDefs(?clear=false)
	{
		if (!clear && cachedDefs != null) return cachedDefs;
		var ret = [];
		var modules = [getModule("parser.Ast"), getModule("transform.Document")];
		for (m in modules) {
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

	static function transform(expr:Expr, src:String, pp:{ min:Int, max:Int }, ?wrap:{ before:Int, after:Int }) {
		// trace('${expr.toString()}: $pp');
		return switch expr.expr {
		case EMeta({ name:name, params:[v] }, sub):
			switch lastPart(name, ":") {
			case "src":
				type(name, macro ($v:String), v.pos);
				src = v.getValue();
			case "len":
				type(name, macro ($v:Int), v.pos);
				pp.max += v.getValue();
			case "skip":
				type(name, macro ($v:Int), v.pos);
				var skip = v.getValue();
				pp.min += skip;
				pp.max += skip;
			case _:
				warning('Unsupported @$name or wrong number of params, ignoring', expr.pos);
			}
			transform(sub, src, pp);
		case EMeta({ name:name, params:[before,after] }, sub) if (lastPart(name, ":") == "wrap"):
			type(name, macro ($before:Int), before.pos);
			type(name, macro ($after:Int), after.pos);
			var skip = before.getValue();
			pp.min += skip;
			pp.max += skip;
			transform(sub, src, pp, { before:skip, after:after.getValue() });
		case EMeta({ name:name }, sub):
			warning('Unsupported @$name or wrong number of params, ignoring', expr.pos);
			transform(sub, src, pp);
		case ECall({ expr:EConst(CIdent(lastPart(_, ".") => c)) }, params)
		if (Lambda.has(getDefs(), c)):
			var min = pp.min;
			params = params.map(transform.bind(_, src, pp));
			if (wrap != null) {
				min -= wrap.before;
				pp.max += wrap.after;
			}
			pp.min = pp.max;
			// trace('AFTER CALL ${expr.toString()}: $pp');
			var edef = { expr:ECall({ expr:EConst(CIdent(c)), pos:expr.pos }, params), pos:expr.pos };
			macro { def:$edef, pos:{ src:$v{src}, min:$v{min}, max:$v{pp.max} } };
		case EConst(CIdent(lastPart(_, ".") => c)) if (Lambda.has(getDefs(), c)):
			var min = pp.min;
			if (wrap != null) {
				min -= wrap.before;
				pp.max += wrap.after;
			}
			pp.min = pp.max;
			// trace('AFTER IDENT ${expr.toString()}: $pp');
			macro { def:$expr, pos:{ src:$v{src}, min:$v{min}, max:$v{pp.max} } };
		case _:
			expr.map(transform.bind(_, src, pp));
		}
	}
#else
	/*
	Build a complete element from `def` and `pos`.

	Saves a few characters when doing that a lot.
	*/
	public static function mk<T>(def:T, pos:Position):Elem<T>
		return { def:def, pos:pos };
#end
	/*
	Build a VList/HList full element from `def`.

	If the list has 1 or none elements, simplify the structure to a single element or `null`.
	*/
	public static macro function mkList(def:Expr)
	{
		switch def.expr {
		case ECall({ expr:EConst(CIdent(c)) }, [li]) if (Lambda.has(getDefs(), c) && c.endsWith("List")):
			return macro {
				($li:Array<Dynamic>);
				if ($li.length < 2)
					$li[0];
				else
					parser.AstTools.mk($def, parser.TokenTools.span($li[0].pos, $li[$li.length - 1].pos));
			}
		case _:
			return error('Unexpected argument for mkList: ${def.toString}', def.pos);
		}
	}

	/*
	Generate real Document ASTs from pseudo ASTs with only VDefs and HDefs.
	*/
	public static macro function expand(pseudo:Expr):Expr
		return transform(pseudo, getLocalModule()+".hx", { min:0, max:0 });
}

