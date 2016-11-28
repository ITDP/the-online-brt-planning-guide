package tests;

import utest.Assert;
import parser.Ast;

import Assertion.*;
import parser.AstTools.*;
using Literals;
using PositionTools;

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
		var a = ".testfile_a";
		sys.io.File.saveContent(a, "0\n2\r\n5\r7");
		Assert.same({ src:a, lines:{ min:0, max:1 }, codes:{ min:0, max:1 } }, { src:a, min:0, max:1 }.toLinePosition());
		Assert.same({ src:a, lines:{ min:1, max:2 }, codes:{ min:0, max:1 } }, { src:a, min:2, max:3 }.toLinePosition());
		Assert.same({ src:a, lines:{ min:2, max:3 }, codes:{ min:0, max:1 } }, { src:a, min:5, max:6 }.toLinePosition());

		var b = ".testfile_b";
		sys.io.File.saveContent(b, "01\n34\n67");
		Assert.same({ src:b, lines:{ min:0, max:3 }, codes:{ min:1, max:2 } }, { src:b, min:1, max:8 }.toLinePosition());
		Assert.same({ src:b, lines:{ min:1, max:3 }, codes:{ min:0, max:2 } }, { src:b, min:3, max:8 }.toLinePosition());

		for (f in [a,b])
			sys.FileSystem.deleteFile(f);
	}

	public function test_004_position_highlight()
	{
		var a = ".testfile_a";
		var hls = "[1;32m", hlf = "[0m";
		function hl(src, min, max, ?width)
			return { src:src, min:min, max:max }.highlight(width).renderHighlight(AnsiEscapes(hls, hlf));

		sys.io.File.saveContent(a, "
			Lorem ipsum dolor sit amet, consectetur adipiscing elit. In egestas, magna et
			lacinia mattis, purus ipsum volutpat leo, eget vehicula elit leo eu arcu. Nunc
			at mattis nulla, id varius odio. Duis consequat urna nec erat sagittis
			tincidunt. Cras et commodo mi. Nullam ipsum sapien, congue sit amet laoreet eu,
			porttitor et magna. Aliquam erat volutpat. Integer non nulla id leo tempor
			sollicitudin tincidunt ornare est. Praesent vel elementum ante, sed feugiat
			enim. Duis iaculis leo vel ligula sodales maximus. Ut a neque vitae erat dictum
			pulvinar ac sed tortor. Sed non pharetra ipsum, facilisis vehicula ante. Aenean
			sit amet gravida dolor. Vestibulum non tortor aliquet, aliquet felis eu,
			sagittis dolor. Curabitur imperdiet non purus a vehicula.".doctrim());

		Assert.equals('${hls}Lorem${hlf} ipsum dolor sit amet, consectetur adipiscing elit. In egestas, magna et', hl(a, 0, 5));
		Assert.equals('Lorem ipsum dolor sit amet, ${hls}consectetur${hlf} adipiscing elit. In egestas, magna et', hl(a, 28, 39));
		Assert.equals('Lorem ipsum dolor sit amet, consectetur adipiscing elit. In egestas, ${hls}magna${hlf} et', hl(a, 69, 74));

		Assert.equals('${hls}Lorem${hlf} ipsum dolor sit amet, consectetur adipiscing elit. In egestas, magna et', hl(a, 0, 5, 80));
		Assert.equals('Lorem ipsum dolor sit amet, ${hls}consectetur${hlf} adipiscing elit. In egestas, magna et', hl(a, 28, 39, 80));
		Assert.equals('Lorem ipsum dolor sit amet, consectetur adipiscing elit. In egestas, ${hls}magna${hlf} et', hl(a, 69, 74, 80));

		Assert.equals('${hls}Lorem${hlf} ipsum dolor sit amet, consectetur ', hl(a, 0, 5, 40));
		Assert.equals('lor sit amet, ${hls}consectetur${hlf} adipiscing eli', hl(a, 28, 39, 40));
		Assert.equals('ur adipiscing elit. In egestas, ${hls}magna${hlf} et', hl(a, 69, 74, 40));

		sys.FileSystem.deleteFile(a);
	}

	public function test_005_expand_other_elems()
	{
		Assert.same(
			{ def:"foo.css", pos:{ min:0, max:7, src:"a" } },
			expand(@src("a")@elem@len(7)"foo.css"));
	}
}

