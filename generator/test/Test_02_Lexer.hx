import parser.*;
import parser.Token;
import utest.Assert;

class Test_02_Lexer {
	public function new() {}

	static function lex(s:String)
	{
		var tokens = [];
		var data = byte.ByteData.ofString(s);
		var lexer = new Lexer(data, "test");
		do {
			var tok = lexer.token(Lexer.tokens);
			tokens.push(tok);
			if (tok.def.match(TEof))
				break;
		} while (true);
		return tokens;
	}

	static function defs(s:String)
		return lex(s).map(function (t) return t.def);

	static function positions(s:String)
		return lex(s).map(function (t) return { min:t.pos.min, max:t.pos.max });

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
		// line comments
		Assert.same([TLineComment(" foo"),TEof], defs("// foo"));
		Assert.same([TWord("foo"),TWordSpace("  "),TLineComment(" bar"),TBreakSpace("\n\n"),TEof], defs("foo  // bar\n\n"));
		Assert.same([TLineComment("foo"),TWordSpace("\n"),TWord("bar"),TEof], defs("//foo\nbar"));

		// block comments
		Assert.same([TBlockComment(" foo "),TEof], defs("/* foo */"));
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
	
	public function test_004_fancies()
	{
		Assert.same([THashes(1), TWord("foo"), THashes(1), TEof], defs("#foo#"));
		
		Assert.same([THashes(1), TEof], defs("#"));
		Assert.same([THashes(3), TEof], defs("###"));
		
		Assert.same([THashes(3), TWordSpace(" "), TWord("Foo"), TEof], defs("### Foo"));
		Assert.same([THashes(3), TWord("Foo"), TEof], defs("###Foo"));
		Assert.same([THashes(1), TWord("Foo"), TEof], defs("#Foo"));
		Assert.same([TWord("Foo"),THashes(1), TEof], defs("Foo#"));
	}
	
	public function test_005_otherchars()
	{
		Assert.same([TAsterisk, TEof], defs("*"));
		Assert.same([TColon(1), TEof], defs(":"));
		Assert.same([TAt(1), TEof], defs("@"));
		
		Assert.same([TAsterisk, TWord("foo"), TAsterisk, TEof], defs("*foo*"));
		Assert.same([TAsterisk, TAsterisk, TWord("foo"), TAsterisk, TAsterisk, TAsterisk, TAsterisk, TAsterisk, TEof], defs("**foo*****"));
		Assert.same([TWord("foo"), TAsterisk, TWord("*"), TEof], defs("foo*\\*"));
		
		Assert.same([TGreater, TEof], defs(">"));
		Assert.same([TGreater, TWord("foo"), TAt(1), TWord("Bar"), TEof], defs(">foo@Bar"));
		
	}
	
	public function test_006_math()
	{
		Assert.same([TMath("bla"), TEof], defs("$bla$"));
		Assert.same([TMath("bla"), TEof], defs("$$$bla"));
		Assert.same([TMath("bla\n\n"), TEof], defs("$bla\n\n$"));
		
		Assert.same([TMath("bla\\$\n\n"), TEof], defs("$bla\\$\n\n$"));
	}
	
	public function test_007_escapes()
	{
		Assert.same([TWord("\\\\"), TWord("foo"), TEof], defs("\\\\foo"));
		
		Assert.raises(defs.bind("foo\\"));
		
		Assert.same([TWord("#"), TWord("foo"), TEof], defs("\\#foo"));
		Assert.same([TWord("foo"), TWord("#"),  TEof], defs("foo\\#"));
		
		Assert.same([TWord("@"), TEof], defs("\\@"));
		Assert.same([TWord("@"), TWord("@"), TEof], defs("\\@\\@"));
		
		Assert.same([TWord("foo"), TWord("@"), TEof], defs("foo\\@"));
		
		//Just in case
		Assert.same([TWord("\\\\"), TCommand("foo"), TEof], defs("\\\\\\foo"));
		Assert.same([TWord("#"), THashes(1), TWord("foo"), THashes(1), TEof], defs("\\##foo#"));
		
	}

	public function test_999_position()
	{
		Assert.same({ min:0, max:0 }, positions("")[0]);
		Assert.same({ min:0, max:1 }, positions(" ")[0]);
		Assert.same({ min:0, max:2 }, positions(" \t")[0]);
		Assert.same({ min:1, max:3 }, positions("a\n\n")[1]);
		Assert.same({ min:1, max:7 }, positions(" // foo\n")[1]);
		Assert.same({ min:0, max:9 }, positions("/* foo */")[0]);
	}
}

