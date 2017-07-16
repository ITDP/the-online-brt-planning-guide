package tests;

import haxe.io.Bytes;
import parser.*;
import parser.Token;
import utest.Assert;

import Assertion.*;

class Test_02_Lexer {
	public function new() {}

	static function lex(?s:String, ?b:Bytes)
	{
		assert(s == null || b == null);
		var tokens = [];
		if (b == null)
			b = Bytes.ofString(s);
		var lexer = new Lexer(b, "test");
		do {
			var tok = lexer.token(Lexer.tokens);
			tokens.push(tok);
			if (tok.def.match(TEof))
				break;
		} while (true);
		return tokens;
	}

	static function defs(?s:String, ?b:Bytes)
		return lex(s, b).map(function (t) return t.def);

	static function positions(?s:String, ?b:Bytes)
		return lex(s, b).map(function (t) return { min:t.pos.min, max:t.pos.max });

	public function test_000_startup()
	{
		Assert.same([TWord("foo"),TEof], defs("foo"));
	}

	public function test_001_basicWhitespace()
	{
		Assert.same([TWordSpace(" "),TEof], defs(" "));
		Assert.same([TWordSpace(" \t"),TEof], defs(" \t"));
		Assert.same([TWordSpace(" \n"),TEof], defs(" \n"));
		Assert.same([TWordSpace(" \r\n"),TEof], defs(" \r\n"));

		Assert.same([TWord("foo"),TWordSpace(" \n"),TWord("bar"),TWordSpace("\t\r\n"),TEof], defs("foo \nbar\t\r\n"));
		Assert.same([TWord("foo"),TBreakSpace(" \t\r\n\n"),TWord("bar"),TEof], defs("foo \t\r\n\nbar"));
	}

	public function test_002_comments()
	{
		// block comments
		Assert.same([TComment(" foo "),TEof], defs("\\' foo '\\"));
		Assert.same([TWord("a"),TBreakSpace("\n\n"),TComment(" foo "),TEof], defs("a\n\n\\' foo '\\"));
		Assert.raises(defs.bind("\\'"));
		Assert.raises(defs.bind("'\\"));

		// block comments as line comments
		Assert.same([TComment(" foo "),TEof], defs("\\' foo '\\"));
	}

	public function test_003_commands()
	{
		Assert.same([TCommand("foo"), TEof], defs("\\foo"));

		Assert.same([TCommand("section"), TWordSpace("\n"), TEof], defs("\\section\n"));

		Assert.same([TCommand("title"), TBrOpen, TWord("foo") , TBrClose, TEof], defs("\\title{foo}"));
		//Considering one whitespace
		Assert.same([TCommand("title"), TWordSpace(" "), TBrOpen, TWord("foo") , TBrClose, TEof], defs("\\title {foo}"));

		Assert.same([TCommand("foo"), TBrOpen, TWord("bar"), TBrClose, TBrkOpen, TWord("opt"), TBrkClose, TEof], defs("\\foo{bar}[opt]"));
		//Consideting one whitespace again
		Assert.same([TCommand("foo"), TBrOpen, TWord("bar"), TBrClose,TWordSpace(" "), TBrkOpen,  TWord("opt"), TBrkClose, TEof], defs("\\foo{bar} [opt]"));
	}

	public function test_005_otherchars()
	{
		Assert.same([TAsterisk, TEof], defs("*"));

		Assert.same([TAsterisk, TWord("foo"), TAsterisk, TEof], defs("*foo*"));
		Assert.same([TAsterisk, TAsterisk, TWord("foo"), TAsterisk, TAsterisk, TAsterisk, TAsterisk, TAsterisk, TEof], defs("**foo*****"));
		Assert.same([TWord("foo"), TAsterisk, TEscaped("*"), TEof], defs("foo*\\*"));
	}

	public function test_006_math()
	{
		Assert.same([TMath("bla"), TEof], defs("$$bla$$"));
		Assert.same([TMath("bla\n\n"), TEof], defs("$$bla\n\n$$"));

		Assert.same([TMath("\\bla"), TEof], defs("$$\\bla$$"));
		Assert.same([TMath("\\$"), TEof], defs("$$\\$$$"));

		Assert.same([TWord("$"), TWord("foo"), TEof], defs("$foo"));
		Assert.same([TWord("foo"), TWord("$"), TWord("bar"), TEof], defs("foo$bar"));
	}

	public function test_007_escapes()
	{
		Assert.raises(defs.bind("\\"));

		Assert.same([TEscaped("\\"), TEof], defs("\\\\"));
		Assert.same([TEscaped("{"), TEof], defs("\\{"));
		Assert.same([TEscaped("}"), TEof], defs("\\}"));
		Assert.same([TEscaped("["), TEof], defs("\\["));
		Assert.same([TEscaped("]"), TEof], defs("\\]"));
		Assert.same([TEscaped("*"), TEof], defs("\\*"));
		Assert.same([TEscaped("`"), TEof], defs("\\`"));
		Assert.same([TEscaped("-"), TEof], defs("\\-"));
		Assert.same([TEscaped("‒"), TEof], defs("\\‒"));
		Assert.same([TEscaped("―"), TEof], defs("\\―"));
		Assert.same([TEscaped("‐"), TEof], defs("\\‐"));
		Assert.same([TEscaped("‑"), TEof], defs("\\‑"));

		// special cases
		Assert.same([TWord("’"), TEof], defs("'"));  // this is usually enough
		Assert.same([TEscaped("'"), TEof], defs('\\^'));  // should only be needed for paths: joe's => joe\^s
		Assert.same([TEscaped("$$"), TEof], defs("\\$$"));

		// just in case
		Assert.same([TEscaped("\\"), TCommand("foo"), TEof], defs("\\\\\\foo"));
		Assert.same([TEscaped("\\"), TWord("’"), TEof], defs("\\\\'"));
		Assert.same([TEscaped("\\"), TWord("code!"), TEof], defs("\\\\code!"));
		Assert.same([TEscaped("\\"), TWord("codeblock!"), TWordSpace("\n"), TWord("foo"), TWordSpace("\n"), TWord("!"), TWordSpace("\n"), TEof], defs("\\\\codeblock!\nfoo\n!\n"));
		Assert.same([TEscaped("$$"), TEof], defs("\\$$"));
		Assert.raises(defs.bind("\\$"));
		Assert.raises(defs.bind("$\\$"));
	}

	public function test_008_dash_treatment()
	{
		// -- and --- aliases
		Assert.same([TWord("–"), TEof], defs("--"));
		Assert.same([TWord("—"), TEof], defs("---"));
		Assert.same([TWord("-"), TEof], defs("-"));  // but leave it unspecified

		// figure dash and horizontal bar compactation into en- and em-dashes
		Assert.same([TWord("–"), TEof], defs("‒"));
		Assert.same([TWord("—"), TEof], defs("―"));

		// simplification of U+2010 (unicode hyphen) and U+2011 (non breaking hyphen)
		Assert.same([TWord("-"), TEof], defs("‐"));
		Assert.same([TWord("-"), TEof], defs("‑"));

		// dashes isolated from the environment
		Assert.same([TWord("a"), TWord("-"), TWord("b"), TEof], defs("a‐b"));
		Assert.same([TWord("a"), TWord("-"), TWord("b"), TEof], defs("a‑b"));
		Assert.same([TWord("a"), TWord("–"), TWord("b"), TEof], defs("a‒b"));
		Assert.same([TWord("a"), TWord("–"), TWord("b"), TEof], defs("a–b"));
		Assert.same([TWord("a"), TWord("—"), TWord("b"), TEof], defs("a—b"));
		Assert.same([TWord("a"), TWord("—"), TWord("b"), TEof], defs("a―b"));
	}

	public function test_009_utf8_text()
	{
		// byte counts: 1, 2, 3 and 4
		Assert.same([TWord("!"), TEof], defs("!"));
		Assert.same([TWord("¡"), TEof], defs("¡"));
		Assert.same([TWord("ࠀ"), TEof], defs("ࠀ"));
		Assert.same([TWord("𐀀"), TEof], defs("𐀀"));

		// special cases
		Assert.same([TWord("“"), TEof], defs("“"));
		Assert.same([TWord("”"), TEof], defs("”"));
	}

	function makeBytes(hex:String):Bytes
	{
		hex = hex.toLowerCase();
		if (hex.indexOf("0x") == 0)
			hex = hex.substr(2);
		var base16 = new haxe.crypto.BaseCode(Bytes.ofString("0123456789abcdef"));
		return base16.decodeBytes(Bytes.ofString(hex.toLowerCase()));
	}

	public function test_010_strict_utf8()
	{
		var ascii = Bytes.ofString("a");
		var latin1 = Bytes.ofString("ç");
		var utf8 = Bytes.ofString("–");
		var utf8bom = Bytes.alloc(3 + utf8.length);
			utf8bom.blit(0, makeBytes("0xefbbbf"), 0, 3);
			utf8bom.blit(3, utf8, 0, utf8.length);
		var utf8notbom1 = Bytes.ofString("ﺰ");
		var utf8notbom2 = Bytes.ofString("ﻒ");

		Assert.same([TWord("a"), TEof], defs(ascii));
		Assert.same([TWord("ç"), TEof], defs(latin1));
		Assert.same([TWord("–"), TEof], defs(utf8));
		Assert.same([TWord("–"), TEof], defs(utf8bom));
		Assert.same([TWord("ﺰ"), TEof], defs(utf8notbom1));
		Assert.same([TWord("ﻒ"), TEof], defs(utf8notbom2));

		var brokenutf8 = utf8.sub(0, 1);
		var win1252 = makeBytes("0x92");
		Assert.raises(defs.bind(null, brokenutf8));
		Assert.raises(defs.bind(null, win1252));
	}

	/*
	Removed vertical markdown syntax in v2
	*/
	public function test_011_removed_markdown_tokens()
	{
		// new lexing rules
		Assert.same([TWord("#foo#"), TEof], defs("#foo#"));
		Assert.same([TWord(">foo@Bar"), TEof], defs(">foo@Bar"));
		Assert.same([TWord(":"), TEof], defs(":"));

		// characters that shouldn't be escaped anymore
		Assert.raises(defs.bind("\\:"));
		Assert.raises(defs.bind("\\@"));
		Assert.raises(defs.bind("\\#"));
		Assert.raises(defs.bind("\\>"));
	}

	public function test_012_disallowed_input()
	{
		// non-breaking spaces
		Assert.raises(defs.bind(" "));
		// delete
		Assert.raises(defs.bind(null, makeBytes("0x7f")));
		// unicode line/paragraph separators
		Assert.raises(defs.bind(null, makeBytes("0xe280a8")));
		Assert.raises(defs.bind(null, makeBytes("0xe280a9")));
		// C0 control codes
		Assert.raises(defs.bind(null, makeBytes("0x00")));
		Assert.raises(defs.bind(null, makeBytes("0x0c")));
		Assert.raises(defs.bind("\r"));  // isolated \r are forbidden as well
		// C1 control codes
		Assert.raises(defs.bind(null, makeBytes("0xc282")));
	}

	public function test_991_position()
	{
		Assert.same({ min:0, max:0 }, positions("")[0]);
		Assert.same({ min:0, max:1 }, positions(" ")[0]);
		Assert.same({ min:0, max:2 }, positions(" \t")[0]);
		Assert.same({ min:1, max:3 }, positions("a\n\n")[1]);
		Assert.same({ min:1, max:10 }, positions(" \\' foo '\\\n")[1]);
		Assert.same({ min:0, max:9 }, positions("\\' foo '\\")[0]);

		Assert.same(({ def:TEof, pos:{ min:1, max:1, src:"test" }, src:"" }:Token), lex(" ")[1]);
	}

	public function test_992_source()
	{
		Assert.same(" \n \n ", lex("foo \n \n bar")[1].src);
		Assert.same("\\foo", lex(" \\foo\t")[1].src);
		Assert.same("\\' bumblebee' \\ '\\", lex("foo\\' bumblebee' \\ '\\bar")[1].src);
		Assert.same("$$ a = b \\$ $$", lex(">$$ a = b \\$ $$@")[1].src);
	}
}

