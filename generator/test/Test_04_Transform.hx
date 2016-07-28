import haxe.io.Bytes;
import parser.Lexer;
import parser.Parser;
import transform.Document;
import transform.NewDocument;
import transform.NewTransform;
import utest.Assert;

import parser.AstTools.*;
import transform.Transform.transform in rawTransform;

class Test_04_Transform {
	static inline var SRC = "Test_04_Transform.hx";

	public function new() {}

	function transform(str : String)
	{
		var l = new Lexer(Bytes.ofString(str), SRC);
		var p = new Parser(SRC, l).file();
		return rawTransform(p);
	}

	public function test_001_example()
	{
		Assert.same({def : TElemList([
			{ def : TVolume(
				{
					def : Word("a"),
					pos : {min : 8, max : 9, src : SRC}
				},
				1,
				"volume.a",
				{
					def : TParagraph(
						{
							def : Word("b"),
							pos : {min : 10, max : 11, src : SRC}
						}),
					pos : {min : 10, max : 11, src : SRC}

				})
				,
			pos : {min : 0, max : 11, src : SRC}
			},
			{ def : TVolume(
				{
					def : Word("c"),
					pos : {min : 19, max : 20, src : SRC}
				},
				2,
				"volume.c",
				{
					def : TParagraph(
						{
							def : Word("d"),
							pos : {min : 21, max : 22, src : SRC}
						}),
					pos : {min : 21, max : 22, src : SRC}
				})
				,
			pos : {min : 11, max : 22, src : SRC}
			}
		]),
		pos : {min : 0, max : 22, src : SRC}
		}, transform("\\volume{a}b\\volume{c}d"));
	}

	public function test_002_hierarchy_content_binding()
	{
		// FIXME no lists with length == 1
		Assert.same(
			expand(TElemList([
				@wrap(8,0)TVolume(@len(1)Word("a"), 1, "volume.a", @skip(1)TParagraph(@len(1)Word("b")))])),
			transform("\\volume{a}b"));

		Assert.same(
			expand(TElemList([
				@wrap(8,0)TVolume(@len(1)Word("a"), 1,"volume.a", @skip(1)TParagraph(@len(1)Word("b"))),
				@wrap(8,0)TVolume(@len(1)Word("c"), 2,"volume.c", @skip(1)TParagraph(@len(1)Word("d")))])),
			transform("\\volume{a}b\\volume{c}d"));

		Assert.same(
			expand(TElemList([
				@wrap(8, 0) TVolume(@len(1) Word("a"), 1,"volume.a", @skip(1) TElemList([TParagraph(@len(1) Word("b")),
				@wrap(9,0) TChapter(@len(1) Word("c"),1,"volume.a.chapter.c",@skip(1)TParagraph(@len(1) Word("d")))
			]))])),
			transform('\\volume{a}b\\chapter{c}d'));

		Assert.same(
			expand(TElemList([
				@wrap(8, 0) TVolume(@len(1) Word("a"), 1,"volume.a", @skip(1) TElemList([TParagraph(@len(1) Word("b")),
				@wrap(9, 0) TChapter(@len(1) Word("c"), 1,"volume.a.chapter.c", @skip(1) TElemList([TParagraph(@len(1) Word("d")),
				@wrap(9, 0) TSection(@len(1) Word("e"), 1,"volume.a.chapter.c.section.e", @skip(1) TElemList([TParagraph(@len(1) Word("f")),
				@wrap(12, 0) TSubSection(@len(1) Word("g"), 1,"volume.a.chapter.c.section.e.subsection.g", @skip(1) TElemList([TParagraph(@len(1) Word("h")),
				@wrap(15, 0) TSubSubSection(@len(1) Word("i"), 1,"volume.a.chapter.c.section.e.subsection.g.subsubsection.i", @skip(1) TParagraph(@len(1) Word("j")))
				]))]))]))]))]))
			,
			transform("\\volume{a}b\\chapter{c}d\\section{e}f\\subsection{g}h\\subsubsection{i}j"));

		Assert.same(
			expand(TElemList([
				@wrap(8, 0) TVolume(@len(1) Word("a"), 1,"volume.a", @skip(1) TElemList([TParagraph(@len(1) Word("b")),
				@wrap(9, 0) TChapter(@len(1) Word("c"), 1,"volume.a.chapter.c", @skip(1) TParagraph(@len(1) Word("d"))),
				@wrap(9, 0) TChapter(@len(1) Word("e"), 2,"volume.a.chapter.e", @skip(1) TElemList([TParagraph(@len(1) Word("f")),
				@wrap(9, 0) TSection(@len(1) Word("g"), 1,"volume.a.chapter.e.section.g", @skip(1) TParagraph(@len(1) Word("h")))
				]))]))]))
			,
			transform("\\volume{a}b\\chapter{c}d\\chapter{e}f\\section{g}h"));


		Assert.same(
			expand(TElemList([
				@wrap(8, 0) TVolume(@len(1) Word("a"), 1,"volume.a", @skip(1) TElemList([TParagraph(@len(1) Word("b")),
					@wrap(9, 0) TChapter(@len(1) Word("c"), 1,"volume.a.chapter.c", @skip(1)TParagraph(@len(1) Word("d"))),

					@wrap(9, 0) TChapter(@len(1) Word("e"), 2,"volume.a.chapter.e", @skip(1) TElemList([TParagraph(@len(1) Word("f")),
						@wrap(9, 0) TSection(@len(1) Word("g"), 1,"volume.a.chapter.e.section.g", @skip(1) TParagraph(@len(1) Word("h")))])),

					@wrap(9, 0) TChapter(@len(1) Word("i"), 3,"volume.a.chapter.i", @skip(1) TElemList([TParagraph(@len(1) Word("j")),
						@wrap(9, 0) TSection(@len(1) Word("k"), 1,"volume.a.chapter.i.section.k", @skip(1) TParagraph(@len(1) Word("l")))]))])),

				@wrap(8, 0) TVolume(@len(1) Word("m"), 2,"volume.m", @skip(1) TElemList([TParagraph(@len(1) Word("n")),
					@wrap(9, 0) TChapter(@len(1) Word("o"), 4,"volume.m.chapter.o", @skip(1) TElemList([TParagraph(@len(1) Word("p")),
						@wrap(9,0) TSection(@len(1) Word("r"), 1,"volume.m.chapter.o.section.r", @skip(1) TParagraph(@len(1) Word("s")))]))]))
			])),
			transform("\\volume{a}b\\chapter{c}d\\chapter{e}f\\section{g}h\\chapter{i}j\\section{k}l\\volume{m}n\\chapter{o}p\\section{r}s"));

		// TODO test other hierarchy constructs
	}

	public function test_003_element_counting()
	{

		Assert.same(
			expand(TElemList([
				@wrap(8,0) TVolume(@len(1) Word("a"),1,"volume.a", @skip(1) TParagraph(@len(1) Word("b")))
			])),
			transform("\\volume{a}b"));

		Assert.same(
			expand(TElemList([
				@wrap(8, 0) TVolume(@len(1) Word("a"), 1, "volume.a",@skip(1) TParagraph(@len(1) Word("b"))),
				@wrap(8,0) TVolume(@len(1) Word("c"),2,"volume.c", @skip(1) TParagraph(@len(1) Word("d")))
			])),
			transform("\\volume{a}b\\volume{c}d"));
		//TODO: Rewrite this so I can test Sec+ Changes
		Assert.same(
			expand(TElemList([
				@wrap(8, 0) TVolume(@len(1) Word("a"), 1,"volume.a", @skip(1) TElemList([TParagraph(@len(1) Word("b")),
				@wrap(9, 0) TChapter(@len(1) Word("c"), 1,"volume.a.chapter.c", @skip(1) TParagraph(@len(1) Word("d")))])),
				@wrap(8, 0) TVolume(@len(1) Word("e"), 2, "volume.e", @skip(1) TElemList([TParagraph(@len(1) Word("f")),
				//VOL != Chapter so when I change the vol I cant change chapter#
				@wrap(9,0) TChapter(@len(1) Word("g") , 2,"volume.e.chapter.g", @skip(1) TParagraph(@len(1) Word("h")))]))
			])),
			transform("\\volume{a}b\\chapter{c}d\\volume{e}f\\chapter{g}h"));


		Assert.same(
			expand(TElemList([
				@wrap(8, 0) TVolume(@len(1) Word("a"), 1,"volume.a", @skip(1) TElemList([TParagraph(@len(1) Word("b")),
				@wrap(9, 0) TChapter(@len(1) Word("c"), 1,"volume.a.chapter.c", @skip(1) TParagraph(@len(1) Word("d"))),
				@wrap(9, 0) TChapter(@len(1) Word("e"), 2, "volume.a.chapter.e",@skip(1) TElemList([TParagraph(@len(1) Word("f")),
				@wrap(9, 0) TSection(@len(1) Word("g"), 1,"volume.a.chapter.e.section.g", @skip(1) TParagraph(@len(1) Word("h"))),
				@wrap(9, 0) TSection(@len(1) Word("i"), 2,"volume.a.chapter.e.section.i", @skip(1) TParagraph(@len(1) Word("j")))])),
				@wrap(9, 0) TChapter(@len(1) Word("k"), 3,"volume.a.chapter.k", @skip(1) TElemList([TParagraph(@len(1) Word("l")),
				@wrap(9, 0) TSection(@len(1) Word("m"), 1,"volume.a.chapter.k.section.m", @skip(1) TElemList([TParagraph(@len(1) Word("n")),
				@wrap(12, 0) TSubSection(@len(1) Word("o"), 1, "volume.a.chapter.k.section.m.subsection.o", @skip(1) TElemList([TParagraph(@len(1) Word("p")),
				@wrap(8, 1) TFigure(MarginWidth, "f", @skip(2 + 1)@len(1) Word("c"), @skip(2)@len(2) Word("cp"),1,"volume.a.chapter.k.section.m.subsection.o.figure.3-1")])), //3-1 -> Chapter 3, Fig 1
				@wrap(12,0) TSubSection(@len(1) Word("q"), 2,"volume.a.chapter.k.section.m.subsection.q", @skip(1) TParagraph(@len(1) Word("r")))]))]))]))
			])),
		transform("\\volume{a}b\\chapter{c}d\\chapter{e}f\\section{g}h\\section{i}j\\chapter{k}l\\section{m}n\\subsection{o}p\\figure{f}{c}{cp}\\subsection{q}r"));

	}

	public function test_004_reset_counters()
	{
		Assert.same(
			expand(TElemList([
				@skip(23)@wrap(8,0)TVolume(@len(1)Word("a"),42,"volume.a",@skip(1)TParagraph(@len(1)Word("b")))
			])),
			transform("\\meta\\reset{volume}{41}\\volume{a}b"));
		Assert.same(
			expand(TElemList([
				@wrap(8,0)TVolume(@len(1)Word("a"),1,"volume.a",@skip(1)TParagraph(@len(1)Word("b"))),
				@skip(22)@wrap(8,0)TVolume(@len(1)Word("c"),1,"volume.c",@skip(1)TParagraph(@len(1)Word("d")))
			])),
			transform("\\volume{a}b\\meta\\reset{volume}{0}\\volume{c}d"));
	}

	public function test_005_tables()
	{
		Assert.same(
			expand(@wrap(12,9) TTable(TextWidth, @len(1) Word("a"), @wrap(7,0) [@wrap(4,0) @skip(2)TParagraph(@len(1) Word("b"))], [@wrap(9,0)[TParagraph(@len(1)Word("d"))]], 1, "table.0-1")),
			transform("\\begintable{a}\\header\\col b\\row\\col d\\endtable"));
		Assert.same(
			expand(@wrap(12, 9) TTable(TextWidth, @len(1) Word("a"),
				@wrap(7, 0)[@wrap(4, 0) @skip(3) TParagraph(@len(1) Word("b")), @wrap(4, 0) @skip(1) TParagraph(@len(1) Word("c")), @wrap(4, 0) @skip(1) TParagraph(@len(1) Word("d"))],
				[@wrap(9, 0)[TParagraph(@len(1) Word("e")), @skip(5) TParagraph(@len(1) Word("f")), @skip(5) TParagraph(@len(1)Word("g"))],
				@wrap(9,0)[TParagraph(@len(1) Word("h")), @skip(5)TParagraph(@len(1)Word("i")), @skip(5)TParagraph(@len(1)Word("j"))]], 1,"table.0-1"
			)),
			transform("\\begintable{a}\\header \\col b\\col c\\col d\\row\\col e\\col f\\col g\\row\\col h\\col i\\col j\\endtable")
		);
	}

	public function test_006_htrim()
	{
		Assert.same(
			expand(TParagraph(HElemList([Word("b"),Wordspace,Word("a"),Wordspace,Word("c"),Wordspace,Word("d")]))),
			rawTransform(expand(Paragraph(HElemList([Word("b"),Wordspace,Word("a"),Wordspace,Word("c"),Wordspace,Word("d")]))))
		);

		//[a, ,b] == trim([ ,a, ,b, ])
		Assert.same(
			expand(TParagraph(HElemList([Word("a"), Wordspace, Word("b")]))),
			rawTransform(expand(Paragraph(HElemList([Wordspace,Word("a"),Wordspace,Word("b"),Wordspace]))))
		);

		//[ ,Emph([ ,a])]
		Assert.same(
			expand(TParagraph(HElemList([Emphasis(HElemList([Word("a")]))]))),
			rawTransform(expand(Paragraph(HElemList([Wordspace,Emphasis(HElemList([Wordspace,Word("a")]))]))))
		);

		//[ , Emph(" a "), ,b]
		Assert.same(
			expand(TParagraph(HElemList([Emphasis(HElemList([Word("a"),Wordspace])),Word("b")]))),
			rawTransform(expand(Paragraph(HElemList([Wordspace,Emphasis(HElemList([Wordspace,Word("a"),Wordspace])),Wordspace,Word("b")]))))
		);

		//[a,emph("b "), ]
		Assert.same(
			expand(TParagraph(HElemList([Word("a"),Emphasis(HElemList([Word("b")]))]))),
			rawTransform(expand(Paragraph(HElemList([Word("a"),Emphasis(HElemList([Word("b"),Wordspace])),Wordspace]))))
		);


		//[ , emph([ , emph([ , a])]),b]
		Assert.same(
			expand(TParagraph(HElemList([Emphasis(HElemList([Emphasis(HElemList([Word("a")]))])),Word("b")]))),
			rawTransform(expand(Paragraph(HElemList([Wordspace,Emphasis(HElemList([Wordspace,Emphasis(HElemList([Wordspace,Word("a")]))])),Word("b")]))))
		);

		//[, emph([ , high([ ,a, ]), ]), ]
		Assert.same(
			expand(TParagraph(HElemList([Emphasis(HElemList([Highlight(HElemList([Word("a")]))]))]))),
			rawTransform(expand(Paragraph(HElemList([Wordspace,Emphasis(HElemList([Wordspace,Highlight(HElemList([Wordspace,Word("a"),Wordspace])),Wordspace])),Wordspace]))))
		);
	}

	public function test_007_vertical_element_survival()
	{
		Assert.same(     expand(TList(true, [TParagraph(Word("a")), TParagraph(Word("b"))])),
 		    rawTransform(expand(List(true, [Paragraph(Word("a")), Paragraph(Word("b"))]))));
		Assert.same(     expand(TCodeBlock("a")),
 		    rawTransform(expand(CodeBlock("a"))));
		Assert.same(     expand(TQuotation(Word("a"), Word("b"))),
 		    rawTransform(expand(Quotation(Word("a"), Word("b")))));
		Assert.same(     expand(TParagraph(HElemList([Word("a")]))),
 		    rawTransform(expand(Paragraph(HElemList([Word("a")])))));
		// TODO improve when expand begins to support DElems
	}
}
