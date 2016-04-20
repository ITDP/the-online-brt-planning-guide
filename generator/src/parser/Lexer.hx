package parser;

import parser.Token;
using StringTools;
class Lexer extends hxparse.Lexer implements hxparse.RuleBuilder {
	static var buf:StringBuf;

	static function mkPos(p:hxparse.Position):Position
	{
		return {
			src : p.psource,
			min : p.pmin,
			max : p.pmax
		}
	}

	static function mk(lex:hxparse.Lexer, tokDef:TokenDef, ?pos:Position)
	{
		return {
			def : tokDef,
			pos : pos != null ? pos : mkPos(lex.curPos())
		}
	}
	
	static function countNewlines(s:String)
	{
		var n = 0;
		for (i in 0...s.length)
			if (s.charAt(i) == "\n")
				n++;
		return n;
	}

	static var comment = @:rule [
		"\\*/" => TBlockComment(buf.toString()),
		"\\*" => {
			buf.add(lexer.current);
			lexer.token(comment);
		},
		"[^*/]" => {
			buf.add(lexer.current);
			lexer.token(comment);
		}
	];
	
	static function hashes(s : String)
	{
		var n = 0;
		for (i in 0...s.length)
			if (s.charAt(i) == "#")
				n++;
		return n;
	}

	public static var tokens = @:rule [
		"" => mk(lexer, TEof),
		"([ \t\n]|(\r\n))+" => {
			if (countNewlines(lexer.current) <= 1)
				mk(lexer, TWordSpace(lexer.current));
			else
				mk(lexer, TBreakSpace(lexer.current));
		},
		"//[^\r\n]*" => mk(lexer, TLineComment(lexer.current.substr(2))),
		"/\\*" => {
			buf = new StringBuf();
			var min = lexer.curPos().pmin;
			var def = lexer.token(comment);
			var pos = mkPos(lexer.curPos());
			pos.min = min;
			mk(lexer, def, pos);
		},
		"\\\\\\\\" => mk(lexer, TWord("\\\\")),
		"\\\\" => mk(lexer, TWord("\\")),
		"(\\\\[a-zA-Z0-9]+)" => mk( lexer, TCommand(lexer.current.substr(1))),
		
		"{" => mk(lexer, TBrOpen),
		"}" => mk(lexer, TBrClose),
		"\\[" => mk(lexer, TBrkOpen),
		"\\]" => mk(lexer, TBrkClose),
		
		"\\\\#" => mk(lexer, TWord(lexer.current.replace("\\", ""))),
		
		"#+" => mk(lexer, THashes(hashes(lexer.current))),
		
		"[^ \t\r\n/*{}\\[\\]\\\\#]+" => mk(lexer, TWord(lexer.current))
	];
}

