package tests;

import utest.Assert;
import parser.Ast;
import parser.AstTools.*;
using parser.TokenTools;

class Test_01_Tools {
	static inline var TMP = "/tmp/";
	static inline var SRC = "tests.Test_01_Tools.hx";

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
				{ def:HElemList([
					{ def:Word("foo"), pos:{ min:1, max:4, src:SRC } },
					{ def:Word("bar"), pos:{ min:5, max:8, src:SRC } } ]),
					pos:{ min:1, max:8, src:SRC } }),
				pos:{ min:0, max:8, src:SRC } },
			expand(Paragraph(@skip(1)HElemList([@len(3)Word("foo"),@skip(1)@len(3)Word("bar")]))));
		Assert.same(
			{ def:VElemList([
				{ def:Paragraph(
					{ def:HElemList([
						{ def:Word("foo"), pos:{ min:1, max:4, src:SRC } },
						{ def:Word("bar"), pos:{ min:5, max:8, src:SRC } } ]),
						pos:{ min:1, max:8, src:SRC } }),
					pos:{ min:0, max:8, src:SRC } },
				{ def:Paragraph(
					{ def:HElemList([
						{ def:Word("foo"), pos:{ min:12, max:15, src:SRC } },
						{ def:Word("bar"), pos:{ min:15, max:18, src:SRC } } ]),
						pos:{ min:11, max:18, src:SRC } }),
					pos:{ min:11, max:18, src:SRC } } ])
				, pos:{ min:0, max:18, src:SRC } },
			expand(VElemList([
				Paragraph(@skip(1)HElemList([@len(3)Word("foo"),@skip(1)@len(3)Word("bar")])),
				@skip(3)Paragraph(HElemList([@skip(1)@len(3)Word("foo"),@len(3)Word("bar")]))])));
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
				{ def:HElemList([
					{ def:Emphasis(
						{ def:Word("foo"), pos:{ min:1, max:4, src:SRC } } ),
						pos:{ min:0, max:5, src:SRC } },
					{ def:Word("bar"), pos:{ min:5, max:8, src:SRC } } ]),
					pos:{ min:0, max:8, src:SRC } }),
				pos:{ min:0, max:8, src:SRC } },
			expand(Paragraph(HElemList([@wrap(1,1)Emphasis(@len(3)Word("foo")),@len(3)Word("bar")]))));

		Assert.same(
			{ def:Paragraph(
				{ def:Emphasis(
					{ def:Word("foo"), pos:{ min:6, max:9, src:"a" } }),
					pos:{ min:0, max:10, src:"a" } }),
				pos:{ min:0, max:10, src:SRC } },
			expand(Paragraph(@src("a")@wrap(6,1)Emphasis(@len(3)Word("foo")))));
		Assert.same(
			{ def:Paragraph(
				{ def:Emphasis(
					{ def:Word("foo"), pos:{ min:6, max:9, src:"a" } }),
					pos:{ min:0, max:10, src:"a" } }),
				pos:{ min:0, max:10, src:SRC } },
			expand(Paragraph(@wrap(6,1)@src("a")Emphasis(@len(3)Word("foo")))));
	}

	public function test_003_line_positions()
	{
		var a = '$TMP/a';
		sys.io.File.saveContent(a, "0\n2\r\n5\r7");
		Assert.same({ src:a, lines:{ min:0, max:1 }, codes:{ min:0, max:1 } }, { src:a, min:0, max:1 }.toLinePosition());
		Assert.same({ src:a, lines:{ min:1, max:2 }, codes:{ min:0, max:1 } }, { src:a, min:2, max:3 }.toLinePosition());
		Assert.same({ src:a, lines:{ min:2, max:3 }, codes:{ min:0, max:1 } }, { src:a, min:5, max:6 }.toLinePosition());

		var b = '$TMP/b';
		sys.io.File.saveContent(b, "01\n34\n67");
		Assert.same({ src:b, lines:{ min:0, max:3 }, codes:{ min:1, max:2 } }, { src:b, min:1, max:8 }.toLinePosition());
		Assert.same({ src:b, lines:{ min:1, max:3 }, codes:{ min:0, max:2 } }, { src:b, min:3, max:8 }.toLinePosition());
	}
}

