import utest.Assert;
import parser.Ast;
import parser.MacroTools.*;

class ParserTests {
	public function new() {}

	function parse(s:String)
	{
		var l = new parser.Lexer(byte.ByteData.ofString(s), "test");
		var p = new parser.Parser(l);
		return p.file();
	}
	
	public function test_000_basic()
	{
		trace(make(@skip(1)VList([@skip(2)@src("a.test")VList([@len(3)@skip(1)Paragraph(null)])])));
		Assert.isTrue(true);  // FIXME
	}
}

