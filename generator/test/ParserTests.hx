import utest.Assert;
import parser.Lexer;
import parser.Parser;
import parser.Ast;

using Lambda;
class ParserTests {
	public function new() {}

	function parse(s:String)
	{
		var l = new Lexer(byte.ByteData.ofString(s), "test");
		var p = new Parser(l);
		return p.file();
	}
	
	public function test_000_basic()
	{
		Assert.isTrue(true);
		trace(parse("foo bar"));
	}
	
	public function test_001_words()
	{

	}
}

