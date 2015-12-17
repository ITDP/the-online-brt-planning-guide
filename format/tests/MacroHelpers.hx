package format.tests;

import haxe.macro.Expr;

using haxe.macro.ExprTools;

class MacroHelpers {
	/*
		Generate real Document ASTs from pseudo ASTs with only VDefs and HDefs.

		Example:
			`VPar(HText("Hi"))`
		becomes
			`{ expr : VPar(
				{ expr : HText("hi"), pos : { fileName : "answer", lineNumber : 42 } }
			), pos : { fileName : "answer", lineNumber : 42 }`
	*/
	public static macro function make(expr:Expr):Expr
	{
		function transform(e:Expr) {
			return switch e.expr {
			case ECall({ expr : EConst(CIdent(c)) }, params) if (c.charAt(0) == "H" || c.charAt(0) == "V"):
				var edef = { expr : ECall({ expr : EConst(CIdent(c)), pos : expr.pos }, params.map(transform)), pos : expr.pos };
				// TODO support some metas for custom positions
				macro { expr : $edef, pos : { fileName : "answer", lineNumber : 42 } };
			case _:
				e.map(transform);
			}
		}
		return transform(expr);
	}
}

