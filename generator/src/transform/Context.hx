package transform;

import haxe.macro.Expr;
import haxe.macro.Context.*;

@:allow(transform.NewTransform)  // allow NewTransform meta handling to change lastVolume/lastChapter
private class DocumentContext<T> {
	var zero:T;
	public var lastVolume(default,null):T;
	public var lastChapter(default,null):T;
	public var box:T;
	public var figure:T;
	public var table:T;

	public var volume(default,set):T;
		function set_volume(v)
		{
			var lc = chapter;
			chapter = zero;
			if (lc != null)  // requires chapter:Null<T>
				lastChapter = lc;
			return lastVolume = volume = v;
		}
	public var chapter(default,set):Null<T>;
		function set_chapter(v)
		{
			box = figure = table = section = zero;
			return lastChapter = chapter = v;
		}
	public var section(default,set):T;
		function set_section(v)
		{
			subSection = zero;
			return section = v;
		}
	public var subSection(default,set):T;
		function set_subSection(v)
		{
			subSubSection = zero;
			return subSection = v;
		}
	public var subSubSection(default,set):T;
		function set_subSubSection(v)
			return subSubSection = v;

	public macro function join(ethis:Expr, prefix:Bool, separator:String, fields:Array<Expr>)
	{
		var comp = [];
		for (f in fields) {
			switch f.expr {
			case EConst(CIdent(name)):
				if (prefix)
					comp.push(macro $v{name});
				comp.push(macro $ethis.$name);
			case _:
				error('Unsupported field expression (expected EConst(CIdent(_))): $f', f.pos);
			}
		}
		return macro $a{comp}.join($v{separator});
	}

	function new(zero:T) {
		this.zero = zero;
		volume = zero;
	}
}

class IdCtx extends DocumentContext<String> {
	public function new()
		super("");
}

class NoCtx extends DocumentContext<Int> {
	public function new()
	{
		lastChapter = 0;
		super(0);
	}
}

