package format.tests;

import haxe.macro.Context;
import haxe.macro.Expr;

using haxe.macro.ExprTools;

class MacroHelpers {
	/*
		Generate real Document ASTs from pseudo ASTs with only VDefs and HDefs.

		For example,

			make(VPar(HList([ HText("Hello,"), @li(2) HText("World!") ])))

		generates the expression

			{ expr : VPar(
				{ expr : HList([
					{ expr : HText("Hello,"), pos : { fileName : "stdin", lineNumber : 1 } },
					{ expr : HText("World!"), pos : { fileName : "stdin", lineNumber : 2 } }
				]), pos : { fileName : "stdin", lineNumber : 1 } }
			), pos : { fileName : "stdin", lineNumber : 1 } }

		Source position information – file name and line number –
		defaults to 'stdin' and 1, but can be customized with the `@li`
		and `@file` metadata.
	*/
	public static macro function make(expr:Expr):Expr
	{
		function transform(e:Expr, file:String, line:Int) {
			return switch e.expr {
			case EMeta({ name:name, params:[v] }, sub):
				var line = line;
				var file = file;
				try {
					switch (name) {
					case "li", ":li":
						Context.typeof(macro var x:Int = $v);
						line = v.getValue();
					case "file", ":file":
						Context.typeof(macro var x:String = $v);
						file = v.getValue();
					case _:  // NOOP
					}
				} catch (e:Dynamic) {
					Context.error('Wrong argument type for @$name: ${e.split("\n")[0]}', v.pos);
				}
				transform(sub, file, line);
			case ECall({ expr : EConst(CIdent(c)) }, params) if (c.charAt(0) == "H" || c.charAt(0) == "V"):
				var edef = { expr : ECall({ expr : EConst(CIdent(c)), pos : expr.pos }, params.map(transform.bind(_, file, line))), pos : expr.pos };
				macro { expr : $edef, pos : { fileName : $v{file}, lineNumber : $v{line} } };
			case _:
				e.map(transform.bind(_, file, line));
			}
		}
		return transform(expr, "stdin", 1);
	}
}

