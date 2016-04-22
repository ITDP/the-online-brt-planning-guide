import utest.Assert;
import parser.Ast;
import parser.MacroTools.*;

class ParserTests {
	static inline var SRC = "ParserTests.hx";
	public function new() {}

	function parse(s:String)
	{
		var l = new parser.Lexer(byte.ByteData.ofString(s), SRC);
		var p = new parser.Parser(l);
		return p.file();
	}
	
	/*
	Test the `make` macro, used to create AST elements from a simplified *Def only pseudo-structure.
	**/
	public function test_000_make()
	{
		Assert.same(
			{ def:Paragraph(
				{ def:Word("foo"), pos:{ min:0, max:3, src:SRC } }),
				pos:{ min:0, max:3, src:SRC } },
			make(Paragraph(@len(3)Word("foo"))));
		Assert.same(
			{ def:Paragraph(
				{ def:Word("foo"), pos:{ min:1, max:4, src:SRC } }),
				pos:{ min:0, max:4, src:SRC } },
			make(Paragraph(@skip(1)@len(3)Word("foo"))));
		Assert.same(
			{ def:Paragraph(
				{ def:HList([
					{ def:Word("foo"), pos:{ min:1, max:4, src:SRC } },
					{ def:Word("bar"), pos:{ min:5, max:8, src:SRC } } ]),
					pos:{ min:1, max:8, src:SRC } }),
				pos:{ min:0, max:8, src:SRC } },
			make(Paragraph(@skip(1)HList([@len(3)Word("foo"),@skip(1)@len(3)Word("bar")]))));
	}

	public function test_001_simple()
	{
		Assert.isTrue(true);  // TODO
	}
}

