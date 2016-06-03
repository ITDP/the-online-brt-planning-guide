package parser;

import parser.Token;
import Assertion.assert;
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
		"[*/]" => {
			buf.add(lexer.current);
			lexer.token(comment);
		},
		"[^*/]+" => {
			buf.add(lexer.current);
			lexer.token(comment);
		}
	];

	static var math = @:rule
	[
		"$" => checkExpr(),
		"\\\\$" => {
			buf.add(lexer.current);
			lexer.token(math);
		},
		"[^$\\\\]+" =>
		{
			buf.add(lexer.current);
			lexer.token(math);
		}
	];

	//Count how many chars has in a string s
	static function countmark(s : String, char : String)
	{
		var n = 0;
		for (i in 0...s.length)
			if (s.charAt(i) == char)
				n++;
		return n;
	}

	static function checkExpr() : TokenDef
	{
		//TODO: Check expr on TeX
		return TMath(buf.toString());
	}

	public static var tokens = @:rule [
		"" => {
			// TODO remove hack to fix eof min position
			var pos = mkPos(lexer.curPos());
			pos.min = pos.max;
			mk(lexer, TEof, pos);
		},
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


		"$" => {
			buf = new StringBuf();
			var min = lexer.curPos().pmin;
			var def = lexer.token(math);
			var pos = mkPos(lexer.curPos());
			pos.min = min;
			mk(lexer, def, pos);
		},
		"$$$[^\n]*" => mk(lexer, TMath(lexer.current.substr(3))),

		"\\\\\\\\" => mk(lexer, TWord("\\\\")),



		"(\\\\[a-z][a-z0-9]*)" => mk(lexer, TCommand(lexer.current.substr(1))),

		"{" => mk(lexer, TBrOpen),
		"}" => mk(lexer, TBrClose),
		"\\[" => mk(lexer, TBrkOpen),
		"\\]" => mk(lexer, TBrkClose),

		"\\*" => mk(lexer, TAsterisk),
		":+" => mk(lexer, TColon(countmark(lexer.current, ":"))),
		"@" => mk(lexer, TAt),
		"#+" => mk(lexer, THashes(countmark(lexer.current, "#"))),
		">" => mk(lexer, TGreater),

		// treat -- as en-dash and as --- and em-dash
		"---" => mk(lexer, TWord("—")),
		"--" => mk(lexer, TWord("–")),
		"-" => mk(lexer, TWord(lexer.current)),

		// separate hyphen-dashes, en-dashes and em-dashes from regular words;
		// em-dashes have special meaning in markdown-like quotations;
		// however, compact figure dashes into en-dashes and horizontal bars into em-dashes
		"–|‒" => mk(lexer, TWord("–")),  // u2013,u2012 -> u2013
		"—|―" => mk(lexer, TWord("—")),  // u2014,u2015 -> u2014

		"\\\\[\\*@:#>$/]" => mk(lexer, TWord(lexer.current.substr(1))),

		// note: 0xE2 is used to exclude en- and em- dashes from being matched;
		// other utf-8 chars begginning with 0xE2 are restored by the two inclusive patterns
		// that follow inital exclusion one
		"([^ \t\r\n/*{}\\[\\]\\\\#>@\\*:$\\-\\xe2]|(\\xE2[^\\x80])|(\\xE2\\x80[^\\x92-\\x95]))+" => mk(lexer, TWord(lexer.current))
	];

	var bytes:haxe.io.Bytes;  // TODO change to a public source abstraction that already has a safe `recover` method

	public function recover(pos, len)
	{
		if (len == 0) return "";
		assert(pos >= 0 && len > 0 && pos + len <= bytes.length, pos, len, bytes.length, "out of bounds");
		return bytes.sub(pos, len).toString();
	}

	@:access(byte.ByteData)
	public function new(bytes, sourceName)
	{
		this.bytes = bytes;
		super(new byte.ByteData(bytes), sourceName);
	}
}

