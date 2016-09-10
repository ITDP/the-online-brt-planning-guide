package parser;

import parser.Error;
import parser.Token;

import Assertion.*;
import parser.TokenTools.toPosition in mkPos;
using StringTools;

class Lexer extends hxparse.Lexer implements hxparse.RuleBuilder {
	static var buf:StringBuf;

	static function mk(lex:hxparse.Lexer, tokDef:TokenDef, ?pos:Position):Token
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
		"'\\\\" => TComment(buf.toString()),
		"['\\\\]" => {
			buf.add(lexer.current);
			lexer.token(comment);
		},
		"([^']|('[^'\\\\]))+" => {  // optimized for stack size from [^`\\\\]+ (or simply [^`]+)
			buf.add(lexer.current);
			lexer.token(comment);
		}
	];

	static var math = @:rule
	[
		"$$" => checkExpr(),
		"((\\\\($?))|[^$\\\\])+" =>  // TODO revise the stack growth
		{
			buf.add(lexer.current);
			lexer.token(math);
		}
	];

	static var code = @:rule
	[
		"" => "",  // FIXME is this hack really necessary?
		"." => lexer.current
	];

	static var codeBlock = @:rule
	[
		"" => "",  // FIXME is this hack really necessary?
		"((\n)|(\r\n))|([^\r\n]*)" => lexer.current
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

	static function unclosedToken(lexer:hxparse.Lexer, partialDef:TokenDef, partialPos:hxparse.Position)
	{
		var token = mk(lexer, partialDef, mkPos(partialPos));
		var lexer = Std.instance(lexer, Lexer);
		throw new UnclosedToken(lexer, token);
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
		"\\\\'" => {
			buf = new StringBuf();
			var min = lexer.curPos().pmin;
			// FIXME good Eof error reporting
			var def = lexer.token(comment);
			var pos = mkPos(lexer.curPos());
			pos.min = min;
			mk(lexer, def, pos);
		},

		"$$" => {
			buf = new StringBuf();
			var min = lexer.curPos().pmin;
			// FIXME good Eof error reporting
			var def = lexer.token(math);
			var pos = mkPos(lexer.curPos());
			pos.min = min;
			mk(lexer, def, pos);
		},

		"\\\\code." => {
			var bang = lexer.current.substr(5);
			var start = lexer.curPos();
			var buf = new StringBuf();
			while (true) {
				var char = lexer.token(code);  // FIXME is this hack really necessary?
				if (char == "") unclosedToken(lexer, TCode("?"), start);
				if (char == bang) break;
				buf.add(char);
			}
			var pos = mkPos(lexer.curPos());
			pos.min = start.pmin;
			mk(lexer, TCode(buf.toString()), pos);
		},

		"\\\\codeblock[^\r\n]*" => {
			var bang = lexer.current.substr(10);
			var start = lexer.curPos();
			var buf = new StringBuf();
			while (true) {
				var next = lexer.token(codeBlock);  // FIXME is this hack really necessary?
				switch next {
				case "":
					unclosedToken(lexer, TCodeBlock("?"), start);  // FIXME Eof should (attempt to) close
				case "\n", "\r\n":
					if (buf.length != 0)
						buf.add("\n");
				case line if (line == bang):
					break;
				case line:
					buf.add(line);
				}
			}
			var pos = mkPos(lexer.curPos());
			pos.min = start.pmin;
			var code = buf.toString();
			code = code.substr(0, code.length - 1);
			mk(lexer, TCodeBlock(code), pos);
		},

		"\\\\\\\\" => mk(lexer, TWord("\\")),

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

		// tex-style ligatures or typing conventions
		// use `' and ``'' for proper quotes
		"`" => mk(lexer, TWord("‘")),
		"``" => mk(lexer, TWord("“")),
		"'" => mk(lexer, TWord("’")),
		"''" => mk(lexer, TWord("”")),
		// treat -- as en-dash and as --- and em-dash
		"---" => mk(lexer, TWord("—")),
		"--" => mk(lexer, TWord("–")),
		"-" => mk(lexer, TWord(lexer.current)),

		// separate hyphen-dashes, en-dashes and em-dashes from regular words;
		// compact figure dashes into en-dashes and horizontal bars into em-dashes
		"–|‒" => mk(lexer, TWord("–")),  // u2013,u2012 -> u2013
		"—|―" => mk(lexer, TWord("—")),  // u2014,u2015 -> u2014
		// treat unicode (non breaking) hyphens as simple ascii dashes
		"‐" => mk(lexer, TWord("-")),  // u2010 -> u002d
		"‑" => mk(lexer, TWord("-")),  // u2011 -> u002d

		"\\\\([{}\\[\\]\\*:@#>`\\-]|‒|―|‐|‑)" => mk(lexer, TWord(lexer.current.substr(1))),
		// more (special) escpaes
		"\\\\^" => mk(lexer, TWord("'")),  // a way to specically type an ascii apostrophe
		// not really an escape, but a special case no less
		"$" => mk(lexer, TWord(lexer.current)),

		// note: 0xE2 is used to exclude en- and em- dashes from being matched;
		// other utf-8 chars begginning with 0xE2 are restored by the two inclusive patterns
		// that follow inital exclusion one
		"([^ \t\r\n*{}\\[\\]\\\\#>@\\*:$\\-`'\\xe2]|(\\xE2[^\\x80])|(\\xE2\\x80[^\\x90-\\x95]))+" => mk(lexer, TWord(lexer.current))
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

