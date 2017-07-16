package tests;

import haxe.io.Bytes;
import parser.Lexer;
import parser.Parser;
import transform.Context;
import transform.NewDocument;
import transform.NewTransform;
import utest.Assert;

import Assertion.*;
import parser.AstTools.*;
import transform.NewTransform.transform;

class Test_05_Transform {
	static inline var SRC = "tests.Test_05_Transform.hx";

	public function new() {}

	function parse(str : String)
	{
		var l = new Lexer(Bytes.ofString(str), SRC);
		var p = new Parser(SRC, l).file();
		return transform(p);
	}

	public function test_001_transform_context_internals()
	{
		var id = new IdCtx();
		Assert.equals("", id.volume);

		id.volume = "vl1";
		Assert.equals("vl1", id.volume);
		id.chapter = "ch1";
		Assert.equals("ch1", id.chapter);
		id.section = "se1";
		Assert.equals("se1", id.section);
		id.subSection = "sse1";
		Assert.equals("sse1", id.subSection);
		id.subSubSection = "ssse1";
		Assert.equals("ssse1", id.subSubSection);

		id.subSection = "sse2";
		Assert.equals("sse2", id.subSection);
		Assert.equals("", id.subSubSection);
		id.subSubSection = "ssse1"; id.subSection = "sse2"; id.section = "se2";
		Assert.equals("se2", id.section);
		Assert.equals("", id.subSection);
		Assert.equals("", id.subSubSection);
		id.subSubSection = "ssse1"; id.subSection = "sse2"; id.section = "se2"; id.chapter = "ch2";
		Assert.equals("ch2", id.chapter);
		Assert.equals("", id.section);
		Assert.equals("", id.subSection);
		Assert.equals("", id.subSubSection);
		id.subSubSection = "ssse1"; id.subSection = "sse2"; id.section = "se2"; id.chapter = "ch2"; id.volume = "vl2";
		Assert.equals("vl2", id.volume);
		Assert.equals("", id.chapter);
		Assert.equals("", id.section);
		Assert.equals("", id.subSection);
		Assert.equals("", id.subSubSection);

		var no = new NoCtx();
		Assert.equals(0, no.volume);
		Assert.equals(0, no.lastChapter);

		no.volume = 1;
		Assert.equals(1, no.volume);
		no.chapter = 1;
		Assert.equals(1, no.chapter);
		no.section = 1;
		Assert.equals(1, no.section);
		no.subSection = 1;
		Assert.equals(1, no.subSection);
		no.subSubSection = 1;
		Assert.equals(1, no.subSubSection);

		no.subSection = 2;
		Assert.equals(2, no.subSection);
		Assert.equals(0, no.subSubSection);
		no.subSubSection = 2; no.subSection = 2; no.section = 2;
		Assert.equals(2, no.section);
		Assert.equals(0, no.subSection);
		Assert.equals(0, no.subSubSection);
		no.subSubSection = 2; no.subSection = 2; no.section = 2; no.chapter = 2;
		Assert.equals(2, no.chapter);
		Assert.equals(2, no.lastChapter);
		Assert.equals(0, no.section);
		Assert.equals(0, no.subSection);
		Assert.equals(0, no.subSubSection);
		no.subSubSection = 2; no.subSection = 2; no.section = 2; no.chapter = 2; no.volume = 2;
		Assert.equals(2, no.volume);
		Assert.equals(0, no.chapter);
		Assert.equals(2, no.lastChapter);
		Assert.equals(0, no.section);
		Assert.equals(0, no.subSection);
		Assert.equals(0, no.subSubSection);
		no.chapter = no.lastChapter + 1;
		Assert.equals(3, no.chapter);
		Assert.equals(3, no.lastChapter);
		no.chapter = no.lastChapter + 1;
		Assert.equals(4, no.chapter);
		Assert.equals(4, no.lastChapter);

		// allow lastChapter to manually reset
		no.chapter = 0;
		Assert.equals(0, no.chapter);
		Assert.equals(0, no.lastChapter);

		// keep lastChapter if non-zero even after volume reset
		no.chapter = 1;
		@:privateAccess no.lastChapter = 2;
		no.volume = 2;
		Assert.equals(2, no.lastChapter);
	}

	public function test_old_001_example()
	{
		Assert.same({
			id : null,
			def : DElemList([
				{
					id : "a",
					def : DVolume(
						1,
						{
							def : Word("a"),
							pos : {min : 8, max : 9, src : SRC}
						},
						{
							id : null,
							def : DParagraph(
								{
									def : Word("b"),
									pos : {min : 10, max : 11, src : SRC}
								}),
							pos : {min : 10, max : 11, src : SRC}

						}),
					pos : {min : 0, max : 11, src : SRC}
				},
				{
					id : "c",
					def : DVolume(
						2,
						{
							def : Word("c"),
							pos : {min : 19, max : 20, src : SRC}
						},
						{
							id : null,
							def : DParagraph(
								{
									def : Word("d"),
									pos : {min : 21, max : 22, src : SRC}
								}),
							pos : {min : 21, max : 22, src : SRC}
						}),
					pos : {min : 11, max : 22, src : SRC}
				}
			]),
			pos : {min : 0, max : 22, src : SRC}
		}, parse("\\volume{a}b\\volume{c}d"));
	}

	public function test_002_survivability_of_simple_velems()
	{
		Assert.same(expand( DTitle(Word("foo")) ), transform(expand( Title(Word("foo")) )));
		// TODO
	}

	public function test_old_002_hierarchy_content_binding()
	{
		Assert.same(
			expand(
				@id("a")@wrap(8,0)DVolume(1,@len(1)Word("a"),@skip(1)DParagraph(@len(1)Word("b")))),
			parse("\\volume{a}b"));

		Assert.same(
			expand(DElemList([
				@id("a")@wrap(8,0)DVolume(1,@len(1)Word("a"),@skip(1)DParagraph(@len(1)Word("b"))),
				@id("c")@wrap(8,0)DVolume(2,@len(1)Word("c"),@skip(1)DParagraph(@len(1)Word("d")))])),
			parse("\\volume{a}b\\volume{c}d"));

		Assert.same(
			expand(
				@id("a")@wrap(8,0)DVolume(1,@len(1)Word("a"),@skip(1)DElemList([DParagraph(@len(1)Word("b")),
				@id("c")@wrap(9,0)DChapter(1,@len(1)Word("c"),@skip(1)DParagraph(@len(1)Word("d")))
			]))),
			parse('\\volume{a}b\\chapter{c}d'));

		Assert.same(
			expand(
				@id("a")@wrap(8,0)DVolume(1,@len(1)Word("a"),@skip(1)DElemList([DParagraph(@len(1)Word("b")),
				@id("c")@wrap(9,0)DChapter(1,@len(1)Word("c"),@skip(1)DElemList([DParagraph(@len(1)Word("d")),
				@id("e")@wrap(9,0)DSection(1,@len(1)Word("e"),@skip(1)DElemList([DParagraph(@len(1)Word("f")),
				@id("g")@wrap(12,0)DSubSection(1,@len(1)Word("g"),@skip(1)DElemList([DParagraph(@len(1)Word("h")),
				@id("i")@wrap(15,0)DSubSubSection(1,@len(1)Word("i"),@skip(1)DParagraph(@len(1)Word("j")))
				]))]))]))])))
			,
			parse("\\volume{a}b\\chapter{c}d\\section{e}f\\subsection{g}h\\subsubsection{i}j"));

		Assert.same(
			expand(
				@id("a")@wrap(8,0)DVolume(1,@len(1)Word("a"),@skip(1)DElemList([DParagraph(@len(1)Word("b")),
				@id("c")@wrap(9,0)DChapter(1,@len(1)Word("c"),@skip(1)DParagraph(@len(1)Word("d"))),
				@id("e")@wrap(9,0)DChapter(2,@len(1)Word("e"),@skip(1)DElemList([DParagraph(@len(1)Word("f")),
				@id("g")@wrap(9,0)DSection(1,@len(1)Word("g"),@skip(1)DParagraph(@len(1)Word("h")))
				]))])))
			,
			parse("\\volume{a}b\\chapter{c}d\\chapter{e}f\\section{g}h"));

		Assert.same(
			expand(DElemList([
				@id("a")@wrap(8,0)DVolume(1,@len(1)Word("a"),@skip(1)DElemList([DParagraph(@len(1)Word("b")),
					@id("c")@wrap(9,0)DChapter(1,@len(1)Word("c"),@skip(1)DParagraph(@len(1)Word("d"))),

					@id("e")@wrap(9,0)DChapter(2,@len(1)Word("e"),@skip(1)DElemList([DParagraph(@len(1)Word("f")),
						@id("g")@wrap(9,0)DSection(1,@len(1)Word("g"),@skip(1)DParagraph(@len(1)Word("h")))])),

					@id("i")@wrap(9,0)DChapter(3,@len(1)Word("i"),@skip(1)DElemList([DParagraph(@len(1)Word("j")),
						@id("k")@wrap(9,0)DSection(1,@len(1)Word("k"),@skip(1)DParagraph(@len(1)Word("l")))]))])),

				@id("m")@wrap(8,0)DVolume(2,@len(1)Word("m"),@skip(1)DElemList([DParagraph(@len(1)Word("n")),
					@id("o")@wrap(9,0)DChapter(4,@len(1)Word("o"),@skip(1)DElemList([DParagraph(@len(1)Word("p")),
						@id("r")@wrap(9,0)DSection(1,@len(1)Word("r"),@skip(1)DParagraph(@len(1)Word("s")))]))]))
			])),
			parse("\\volume{a}b\\chapter{c}d\\chapter{e}f\\section{g}h\\chapter{i}j\\section{k}l\\volume{m}n\\chapter{o}p\\section{r}s"));

		// DODO test other hierarchy constructs
	}

	public function test_003_element_counting()
	{
		Assert.same(
			expand(
				@id("a")@wrap(8,0)DVolume(1,@len(1)Word("a"),@skip(1)DParagraph(@len(1)Word("b")))
			),
			parse("\\volume{a}b"));

		Assert.same(
			expand(DElemList([
				@id("a")@wrap(8,0)DVolume(1,@len(1)Word("a"),@skip(1)DParagraph(@len(1)Word("b"))),
				@id("c")@wrap(8,0)DVolume(2,@len(1)Word("c"),@skip(1)DParagraph(@len(1)Word("d")))
			])),
			parse("\\volume{a}b\\volume{c}d"));
		//DODO: Rewrite this so I can test Sec+ Changes
		Assert.same(
			expand(DElemList([
				@id("a")@wrap(8,0)DVolume(1,@len(1)Word("a"),@skip(1)DElemList([DParagraph(@len(1)Word("b")),
				@id("c")@wrap(9,0)DChapter(1,@len(1)Word("c"),@skip(1)DParagraph(@len(1)Word("d")))])),
				@id("e")@wrap(8,0)DVolume(2,@len(1)Word("e"),@skip(1)DElemList([DParagraph(@len(1)Word("f")),
				//VOL!=ChaptersowhenIchangethevolIcantchangechapter#
				@id("g")@wrap(9,0)DChapter(2,@len(1)Word("g"),@skip(1)DParagraph(@len(1)Word("h")))]))
			])),
			parse("\\volume{a}b\\chapter{c}d\\volume{e}f\\chapter{g}h"));

		Assert.same(
			expand(
				@id("a")@wrap(8,0)DVolume(1,@len(1)Word("a"),@skip(1)DElemList([DParagraph(@len(1)Word("b")),
				@id("c")@wrap(9,0)DChapter(1,@len(1)Word("c"),@skip(1)DParagraph(@len(1)Word("d"))),
				@id("e")@wrap(9,0)DChapter(2,@len(1)Word("e"),@skip(1)DElemList([DParagraph(@len(1)Word("f")),
				@id("g")@wrap(9,0)DSection(1,@len(1)Word("g"),@skip(1)DParagraph(@len(1)Word("h"))),
				@id("i")@wrap(9,0)DSection(2,@len(1)Word("i"),@skip(1)DParagraph(@len(1)Word("j")))])),
				@id("k")@wrap(9,0)DChapter(3,@len(1)Word("k"),@skip(1)DElemList([DParagraph(@len(1)Word("l")),
				@id("m")@wrap(9,0)DSection(1,@len(1)Word("m"),@skip(1)DElemList([DParagraph(@len(1)Word("n")),
				@id("o")@wrap(12,0)DSubSection(1,@len(1)Word("o"),@skip(1)DElemList([DParagraph(@len(1)Word("p")),
				@id("f")@wrap(8,1)DFigure(1,MarginWidth,@elem@len(1)"f",@skip(2)@len(1)Word("c"),@skip(2)@len(2)Word("cp"))])),  // 3-1 -> Chapter3,Fig1
				@id("q")@wrap(12,0) DSubSection(2,@len(1) Word("q"),@skip(1) DParagraph(@len(1) Word("r")))]))]))]))
			),
		parse("\\volume{a}b\\chapter{c}d\\chapter{e}f\\section{g}h\\section{i}j\\chapter{k}l\\section{m}n\\subsection{o}p\\figure{f}{c}{cp}\\subsection{q}r"));
	}

	public function test_old_004_reset_counters()
	{
		Assert.same(
			expand(
				@skip(23)@id("a")@wrap(8,0)DVolume(42,@len(1)Word("a"),@skip(1)DParagraph(@len(1)Word("b")))
			),
			parse("\\meta\\reset{volume}{41}\\volume{a}b"));
		Assert.same(
			expand(DElemList([
				@id("a")@wrap(8,22)DVolume(1, @len(1)Word("a"),@skip(1)DParagraph(@len(1)Word("b"))),
				@id("c")@wrap(8,0)DVolume(1, @len(1)Word("c"),@skip(1)DParagraph(@len(1)Word("d")))
			])),
			parse("\\volume{a}b\\meta\\reset{volume}{0}\\volume{c}d"));
	}

	public function test_old_005_tables()
	{
		Assert.same(
			expand(@id("a") @wrap(12,9) DTable(1, TextWidth, @len(1) Word("a"), @wrap(7,0) [@wrap(4,0) @skip(2)DParagraph(@len(1) Word("b"))], [@wrap(9,0)[DParagraph(@len(1)Word("d"))]])),
			parse("\\begintable{a}\\header\\col b\\row\\col d\\endtable"));
		Assert.same(
			expand(@id("a") @wrap(12, 9) DTable(1, TextWidth, @len(1) Word("a"),
				@wrap(7, 0)[@wrap(4, 0) @skip(3) DParagraph(@len(1) Word("b")), @wrap(4, 0) @skip(1) DParagraph(@len(1) Word("c")), @wrap(4, 0) @skip(1) DParagraph(@len(1) Word("d"))],
				[@wrap(9, 0)[DParagraph(@len(1) Word("e")), @skip(5) DParagraph(@len(1) Word("f")), @skip(5) DParagraph(@len(1)Word("g"))],
				@wrap(9,0)[DParagraph(@len(1) Word("h")), @skip(5)DParagraph(@len(1)Word("i")), @skip(5)DParagraph(@len(1)Word("j"))]])),
			parse("\\begintable{a}\\header \\col b\\col c\\col d\\row\\col e\\col f\\col g\\row\\col h\\col i\\col j\\endtable")
		);
	}

	public function test_old_006_htrim()
	{
		Assert.same(
			expand(DParagraph(HElemList([Word("b"),Wordspace,Word("a"),Wordspace,Word("c"),Wordspace,Word("d")]))),
			transform(expand(Paragraph(HElemList([Word("b"),Wordspace,Word("a"),Wordspace,Word("c"),Wordspace,Word("d")]))))
		);

		//[a, ,b] == trim([ ,a, ,b, ])
		Assert.same(
			expand(DParagraph(HElemList([Word("a"), Wordspace, Word("b")]))),
			transform(expand(Paragraph(HElemList([Wordspace,Word("a"),Wordspace,Word("b"),Wordspace]))))
		);

		//[ ,Emph([ ,a])]
		Assert.same(
			expand(DParagraph(HElemList([Emphasis(HElemList([Word("a")]))]))),
			transform(expand(Paragraph(HElemList([Wordspace,Emphasis(HElemList([Wordspace,Word("a")]))]))))
		);

		//[ , Emph(" a "), ,b]
		Assert.same(
			expand(DParagraph(HElemList([Emphasis(HElemList([Word("a"),Wordspace])),Word("b")]))),
			transform(expand(Paragraph(HElemList([Wordspace,Emphasis(HElemList([Wordspace,Word("a"),Wordspace])),Wordspace,Word("b")]))))
		);

		//[a,emph("b "), ]
		Assert.same(
			expand(DParagraph(HElemList([Word("a"),Emphasis(HElemList([Word("b")]))]))),
			transform(expand(Paragraph(HElemList([Word("a"),Emphasis(HElemList([Word("b"),Wordspace])),Wordspace]))))
		);


		//[ , emph([ , emph([ , a])]),b]
		Assert.same(
			expand(DParagraph(HElemList([Emphasis(HElemList([Emphasis(HElemList([Word("a")]))])),Word("b")]))),
			transform(expand(Paragraph(HElemList([Wordspace,Emphasis(HElemList([Wordspace,Emphasis(HElemList([Wordspace,Word("a")]))])),Word("b")]))))
		);

		//[, emph([ , high([ ,a, ]), ]), ]
		Assert.same(
			expand(DParagraph(HElemList([Emphasis(HElemList([Highlight(HElemList([Word("a")]))]))]))),
			transform(expand(Paragraph(HElemList([Wordspace,Emphasis(HElemList([Wordspace,Highlight(HElemList([Wordspace,Word("a"),Wordspace])),Wordspace])),Wordspace]))))
		);
	}

	public function test_old_007_vertical_element_survival()
	{
		Assert.same(expand(DList(true, [DParagraph(Word("a")), DElemList([DParagraph(Word("b")),DParagraph(Word("c"))])])),
			transform(expand(List(true, [Paragraph(Word("a")), VElemList([Paragraph(Word("b")),Paragraph(Word("c"))])]))));
		Assert.same(expand(DList(true, [DParagraph(Word("a")), DParagraph(Word("b"))])),
			transform(expand(List(true, [Paragraph(Word("a")), Paragraph(Word("b"))]))));
		Assert.same(expand(DCodeBlock("a")),
			transform(expand(CodeBlock("a"))));
		Assert.same(expand(DQuotation(Word("a"), Word("b"))),
			transform(expand(Quotation(Word("a"), Word("b")))));
		Assert.same(expand(DParagraph(HElemList([Word("a")]))),
			transform(expand(Paragraph(HElemList([Word("a")])))));
		// TODO improve when expand begins to support DElems
	}
}

