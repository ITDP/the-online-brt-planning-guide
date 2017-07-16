package parser;

import parser.ParserError;
import parser.Token;

import Assertion.*;
import PositionTools.toPosition in mkPos;
using StringTools;

class Lexer extends hxparse.Lexer implements hxparse.RuleBuilder {
	static var buf:StringBuf;

	static function mk(lex:hxparse.Lexer, tokDef:TokenDef, ?pos:Position):Token
	{
		if (pos == null)
			pos = mkPos(lex.curPos());
		return {
			def : tokDef,
			pos : pos,
			src : lex.input.readString(pos.min, pos.max - pos.min)
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
		throw new ParserError(token.pos, UnclosedToken(token.def));
	}

	public static var tokens = @:rule [
		"\\xC2\\xA0" => {
			var hex = haxe.io.Bytes.ofString(lexer.current).toHex();
			throw new hxparse.UnexpectedChar('non-breaking space (0x$hex)', lexer.curPos());
		},
		"[\\x7F\\x00\\x01-\\x08\\x0B-\\x1F]|(\\xC2[\\x80-\\x9F])|(\\xE2\\x80[\\xA8\\xA9])" => {
			var hex = haxe.io.Bytes.ofString(lexer.current).toHex();
			throw new hxparse.UnexpectedChar('control character (0x$hex)', lexer.curPos());
		},
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

		"(\\\\[a-zA-Z][a-zA-Z0-9]*)" => mk(lexer, TCommand(lexer.current.substr(1))),

		"{" => mk(lexer, TBrOpen),
		"}" => mk(lexer, TBrClose),
		"\\[" => mk(lexer, TBrkOpen),
		"\\]" => mk(lexer, TBrkClose),

		"\\*" => mk(lexer, TAsterisk),

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

		// basic escape sequences
		"\\\\\\\\" => mk(lexer, TEscaped("\\")),
		"\\\\([{}\\[\\]\\*`\\-]|‒|―|‐|‑)" => mk(lexer, TEscaped(lexer.current.substr(1))),
		// more/special escaping
		"\\\\^" => mk(lexer, TEscaped("'")),  // a way to specically type an ascii apostrophe
		"\\\\$$" => mk(lexer, TEscaped("$$")),  // a way to escape a math delimiter
		// note: it's important to correctly differentate between
		// TEscaped and special TWord cases, since they are handled
		// differently in Parser.rawHorizontal

		// not really an escape, but a special case no less
		"$" => mk(lexer, TWord(lexer.current)),

		// utf-8 BOM: if mid file, silently ignore it; this seems ok,
		// since in unicode this can either mean a BOM or a zero width
		// no-break space
		"\\xEF\\xBB\\xBF" => lexer.token(tokens),

		// note 1:
		// > 0xE2 is used to exclude en- and em- dashes from being
		// > matched; other utf-8 chars beginning with 0xE2 are
		// > restored later
		// note 2:
		// > 0xEF is used to exclude the BOM; other utf-8 chars
		// > beginning with 0xEF are restored later
		// note 3/control or forbidden characters:
		// > non-breaking space U+A0 (0xC2A0)
		// 	 delete U+7F
		// 	 unicode line/paragraph separators U+2028/U+2029 (0xE280A8, 0xE280A9)
		// > C0 controls U+00–U+1F (that already include \t, \r and \n)
		// > C1 controls U+80–U+9F (0xC280–0xC29F)
		// note 4:
		// 	 \\x00-\\x1F is not working because of some unknown bug
		// 	 the workaround is to match \\x00 separately from the rest of the range
		"([^ {}\\[\\]\\\\\\*$\\-`'\\xE2\\xEF\\xC2\\x7F\\x00\\x01-\\x1F]|(\\xE2[^\\x80])|(\\xE2\\x80[^\\x90-\\x95\\xA8\\xA9])|(\\xEF[^\\xBB])|(\\xEF\\xBB[^\\xBF])|(\\xC2[^\\xA0\\x80-\\x9F]))+" => mk(lexer, TWord(lexer.current))
	];

	public function new(bytes:haxe.io.Bytes, sourceName)
	{
		if (!Utf8Validate.isValidUTF8(js.node.Buffer.hxFromBytes(bytes))) throw new ParserError({ src:sourceName, min:0, max:bytes.length }, InvalidUtf8);
		super(byte.ByteData.ofBytes(bytes), sourceName);
	}
}

