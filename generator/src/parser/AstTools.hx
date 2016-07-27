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
	Build a compatible list of `ind` individual processing calls.

	This is suitable to automagically make HLists and VLists.  According to
	the number of found elements, this macro will either result in an empty
	element, a single (unwraped) element, or a list of elements.
	*/
	public static macro function mkList(ind:Expr, stop:Expr)
	{
		switch ind.expr {
		case EConst(CIdent(c)):
			var compat = false;
			var c = switch typeof(ind) {  // TODO strict type check, but also support Elem<?Def>
			case TFun(_,TType(_.get()=>{name:"Null"},[TType(_.get()=>{name:name},[])])) if (name.endsWith("Elem")):
				compat = true;
				name.charAt(0);
			case TFun(_,TAbstract(_.get()=>{name:"Nullable"},[TType(_.get()=>{name:name},[])])) if (name.endsWith("Elem")):
				name.charAt(0);
			case other:
				error('Unexpected type for mkList argument: $other', ind.pos);
			}
			var list = macro $i{c + "List"};
			var empty = macro $i{c + "Empty"};
			var nullCheck = compat ? (macro i == null) : (macro i.isNull());
			var valAccess = compat ? (macro i) : (macro i.sure());
			return macro {
				var start = peek().pos;
				var li = [];
				while (true) {
					var i = $ind($stop);
					if ($nullCheck) break;
					li.push($valAccess);
				}
				switch (li) {
				case []:
					var at = peek().pos;
					// hack to get the usual empty <=> length == 0 (when possible);
					// don't eliminate the implicit copy with .offset, since we'll be changing the
					// position of a token used elsewhere
					at = at.offset(0, at.min - at.max);
					start = start.offset(0, start.min - start.max);
					parser.AstTools.mk($empty, parser.TokenTools.span(start, at));
				case [single]:
					single;
				case _:
					parser.AstTools.mk($list(li), parser.TokenTools.span(li[0].pos, li[li.length - 1].pos));
				}
			}
		case _:
			return error('Unexpected argument for mkList: ${ind.toString}', ind.pos);
		}
	}

	/*
	Generate real Document ASTs from pseudo ASTs with only VDefs and HDefs.
	*/
	public static macro function expand(pseudo:Expr):Expr
		return transform(pseudo, getLocalModule()+".hx", { min:0, max:0 });
}

