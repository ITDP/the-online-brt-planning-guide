import utest.Assert;
import parser.Ast;
import parser.AstTools.*;

class Test_01_Tools {
	static inline var SRC = "Test_01_Tools.hx";

	public function new() {}

	public function test_001_expand_macro_basic()
	{
		Assert.same(
			{ def:Paragraph(
				{ def:Word("foo"), pos:{ min:0, max:3, src:SRC } }),
				pos:{ min:0, max:3, src:SRC } },
			expand(Paragraph(@len(3)Word("foo"))));
		Assert.same(
			{ def:Paragraph(
				{ def:Word("foo"), pos:{ min:1, max:4, src:SRC } }),
				pos:{ min:0, max:4, src:SRC } },
			expand(Paragraph(@skip(1)@len(3)Word("foo"))));
		Assert.same(
			{ def:Paragraph(
				{ def:HList([
					{ def:Word("foo"), pos:{ min:1, max:4, src:SRC } },
					{ def:Word("bar"), pos:{ min:5, max:8, src:SRC } } ]),
					pos:{ min:1, max:8, src:SRC } }),
				pos:{ min:0, max:8, src:SRC } },
			expand(Paragraph(@skip(1)HList([@len(3)Word("foo"),@skip(1)@len(3)Word("bar")]))));
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
			expand(VList([
				Paragraph(@skip(1)HList([@len(3)Word("foo"),@skip(1)@len(3)Word("bar")])),
				@skip(3)Paragraph(HList([@skip(1)@len(3)Word("foo"),@len(3)Word("bar")]))])));
	}

	public function test_002_expand_macro_wrap()
	{
		Assert.same(
			{ def:Paragraph(
				{ def:Emphasis(
					{ def:Word("foo"), pos:{ min:6, max:9, src:SRC } }),
					pos:{ min:0, max:10, src:SRC } }),
				pos:{ min:0, max:10, src:SRC } },
			expand(Paragraph(@wrap(6,1)Emphasis(@len(3)Word("foo")))));
		Assert.same(
			{ def:Paragraph(
				{ def:HList([
					{ def:Emphasis(
						{ def:Word("foo"), pos:{ min:1, max:4, src:SRC } } ),
						pos:{ min:0, max:5, src:SRC } },
					{ def:Word("bar"), pos:{ min:5, max:8, src:SRC } } ]),
					pos:{ min:0, max:8, src:SRC } }),
				pos:{ min:0, max:8, src:SRC } },
			expand(Paragraph(HList([@wrap(1,1)Emphasis(@len(3)Word("foo")),@len(3)Word("bar")]))));
	}
}

