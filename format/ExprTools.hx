package format;

import format.Document;

class HDefExprTools {
	public static function map(expr:Expr<HDef>, f:Expr<HDef>->Expr<HDef>):Expr<HDef>
	{
		return { pos : expr.pos, expr : switch expr.expr {
		case HText(_), HCode(_): expr.expr;
		case HEmph(e): HEmph(f(e));
		case HHighlight(e): HHighlight(f(e));
		case HList(list): HList(list.map(f));
		} }
	}

	public static function toText(expr:Expr<HDef>):String
	{
		return switch expr.expr {
		case HText(t), HCode(t): t;
		case HEmph(e), HHighlight(e): toText(e);
		case HList(list): [ for (e in list) toText(e) ].join("");
		}
	}

	public static function toLabel(expr:Expr<HDef>):String
	{
		var t = toText(expr).toLowerCase();
		t = ~/[^a-z0-9 \t\n]+/g.replace(t, "");
		t = ~/[ \t\n]+/g.replace(t, "-");
		return t;
	}
}
