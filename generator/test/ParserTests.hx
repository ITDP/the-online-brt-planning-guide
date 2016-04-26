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
		Assert.same(
			{ def:VList([
				{ def:Paragraph(
					{ def:HList([
						{ def:Word("foo"), pos:{ min:1, max:4, src:SRC } },
						{ def:Word("bar"), pos:{ min:5, max:8, src:SRC } } ]),
						pos:{ min:1, max:8, src:SRC } }),
					pos:{ min:0, max:8, src:SRC } },
				{ def:Paragraph(
					{ def:HList([
						{ def:Word("foo"), pos:{ min:12, max:15, src:SRC } },
						{ def:Word("bar"), pos:{ min:15, max:18, src:SRC } } ]),
						pos:{ min:11, max:18, src:SRC } }),
					pos:{ min:11, max:18, src:SRC } } ])
				, pos:{ min:0, max:18, src:SRC } },
			make(VList([
				Paragraph(@skip(1)HList([@len(3)Word("foo"),@skip(1)@len(3)Word("bar")])),
				@skip(3)Paragraph(HList([@skip(1)@len(3)Word("foo"),@len(3)Word("bar")]))])));
	}

	public function test_001_simple()
	{
		Assert.same(
			make(Paragraph(@len(3)Word("foo"))),
			parse("foo"));
		Assert.same(
			make(Paragraph(HList([@len(3)Word("foo"),@skip(1)@len(3)Word("bar")]))),
			parse("foo bar"));
		Assert.same(
			make(@skip(2)Paragraph(HList([@len(3)Word("foo"),@skip(1)@len(3)Word("bar")]))),
			parse("  foo bar"));
	}
}

