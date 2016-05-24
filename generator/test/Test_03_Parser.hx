import parser.Ast;
import parser.AstTools.*;
import parser.Error;
import utest.Assert;

class Test_03_Parser {
	static inline var SRC = "Test_03_Parser.hx";
	public function new() {}

	function parse(s:String)
	{
		var l = new parser.Lexer(haxe.io.Bytes.ofString(s), SRC);
		var p = new parser.Parser(l);
		return p.file();
	}

	public function test_001_test_example()
	{
		Assert.same(
			expand(Paragraph(@len(3)Word("foo"))),
			parse("foo"));
		Assert.same(
			expand(Paragraph(HList([@len(3)Word("foo"),@len(1)Wordspace,@len(3)Word("bar")]))),
			parse("foo bar"));
		Assert.same(
			expand(@skip(2)Paragraph(HList([@len(3)Word("foo"),@len(2)Wordspace,@len(3)Word("bar"),@len(2)Wordspace,@len(3)Word("red")]))),
			parse("  foo \tbar\n red"));
	}

	public function test_001_wordspace()
	{
		Assert.same(
			expand(Paragraph(HList([@len(1)Word("a"),@len(1)Wordspace,@len(1)Word("b")]))),
			parse("a b"));
		Assert.same(
			expand(Paragraph(HList([@len(1)Word("a"),@len(1)Wordspace,@len(1)Word("b")]))),
			parse("a\tb"));
		Assert.same(
			expand(Paragraph(HList([@len(1)Word("a"),@len(1)Wordspace,@len(1)Word("b")]))),
			parse("a\nb"));
		Assert.same(
			expand(Paragraph(HList([@len(1)Word("a"),@len(2)Wordspace,@len(1)Word("b")]))),
			parse("a\r\nb"));

		Assert.same(
			expand(Paragraph(HList([@len(1)Word("a"),@len(2)Wordspace,@len(1)Word("b")]))),
			parse("a  b"));
		Assert.same(
			expand(Paragraph(HList([@len(1)Word("a"),@len(2)Wordspace,@len(1)Word("b")]))),
			parse("a \tb"));
		Assert.same(
			expand(Paragraph(HList([@len(1)Word("a"),@len(2)Wordspace,@len(1)Word("b")]))),
			parse("a\n b"));
		Assert.same(
			expand(Paragraph(HList([@len(1)Word("a"),@len(3)Wordspace,@len(1)Word("b")]))),
			parse("a\t\r\nb"));

		Assert.same(
			expand(Paragraph(HList([@len(1)Word("a"),@len(3)Wordspace,@len(1)Word("b")]))),
			parse("a   b"));
	}

	public function test_002_paragraph_break()
	{
		Assert.same(
			expand(VList([Paragraph(@len(1)Word("a")),@skip(2)Paragraph(@len(1)Word("b"))])),
			parse("a\n\nb"));
		Assert.same(
			expand(@skip(1)VList([Paragraph(@len(1)Word("a")),@skip(3)Paragraph(@len(1)Word("b"))])),
			parse(" a\n\n b"));
		Assert.same(
			expand(VList([Paragraph(@len(1)Word("a")),@skip(4)Paragraph(@len(1)Word("b"))])),
			parse("a\n \t\nb"));
		Assert.same(
			expand(VList([Paragraph(@len(1)Word("a")),@skip(5)Paragraph(@len(1)Word("b"))])),
			parse("a \r\n\t\nb"));

		Assert.same(
			expand(VList([Paragraph(@len(1)Word("a")),@wrap(8,1)Volume(@len(1)Word("b"))])),
			parse("a\\volume{b}"));
		Assert.same(
			expand(VList([Paragraph(@len(1)Word("a")),@wrap(9,1)Chapter(@len(1)Word("b"))])),
			parse("a\\chapter{b}"));
		Assert.same(
			expand(VList([Paragraph(@len(1)Word("a")),@wrap(9,1)Section(@len(1)Word("b"))])),
			parse("a\\section{b}"));
	}

	public function test_003_emphasis()
	{
		Assert.same(
			expand(Paragraph(@wrap(6,1)Emphasis(@len(1)Word("a")))),
			parse("\\emph{a}"));
		Assert.same(
			expand(Paragraph(@wrap(6,1)Emphasis(HList([@len(1)Word("a"),@len(1)Wordspace,@len(1)Word("b")])))),
			parse("\\emph{a b}"));
		Assert.same(
			expand(Paragraph(@wrap(6,1)Emphasis(HList([@len(1)Word("a"),@len(1)Wordspace,@wrap(6,1)Emphasis(@len(1)Word("b"))])))),
			parse("\\emph{a \\emph{b}}"));

		Assert.same(
			expand(Paragraph(@wrap(1,1)Emphasis(@len(1)Word("a")))),
			parse("*a*"));
		Assert.same(
			expand(Paragraph(@wrap(1,1)Emphasis(HList([@len(1)Word("a"),@len(1)Wordspace,@len(1)Word("b")])))),
			parse("*a b*"));

		Assert.same(
			expand(Paragraph(HList([@len(2)Emphasis(null),@len(1)Word("a"),@len(2)Emphasis(null)]))),
			parse("**a**"));  // TODO generate some warning on empty emphasis (maybe later than the parser)
		Assert.same(
			expand(Paragraph(HList([@wrap(1,1)Emphasis(HList([@len(1)Word("a"),@len(1)Wordspace])),@wrap(1,1)Emphasis(@len(1)Word("b")),@wrap(1,1)Emphasis(HList([@len(1)Wordspace,@len(1)Word("c")]))]))),
			parse("*a **b** c*"));

		Assert.raises(parse.bind("\\emph{a}{}"), UnexpectedToken);
	}

	public function test_004_highlight()
	{
		Assert.same(
			expand(Paragraph(@wrap(11,1)Highlight(@len(1)Word("a")))),
			parse("\\highlight{a}"));
		Assert.same(
			expand(Paragraph(@wrap(11,1)Highlight(HList([@len(1)Word("a"),@len(1)Wordspace,@len(1)Word("b")])))),
			parse("\\highlight{a b}"));
		Assert.same(
			expand(Paragraph(@wrap(11,1)Highlight(HList([@len(1)Word("a"),@len(1)Wordspace,@wrap(11,1)Highlight(@len(1)Word("b"))])))),
			parse("\\highlight{a \\highlight{b}}"));
	}

	public function test_005_bad_command_name()
	{
		// typos
		Assert.raises(parse.bind("\\emp"), UnknownCommand);
		Assert.raises(parse.bind("\\highligth"), UnknownCommand);

		// non existant aliases
		Assert.raises(parse.bind("\\emphasis"), UnknownCommand);
		Assert.raises(parse.bind("\\display"), UnknownCommand);
	}

	public function test_006_known_dificulties_from_poc()
	{
		// if whitespace is not properly handled spontaneous par breaks can happen bellow
		Assert.same(
			expand(Paragraph(HList([@wrap(1,1)Emphasis(@len(1)Word("a")),@len(1)Wordspace,@len(1)Word("b")]))),
			parse("*a*\nb"));
	}

	public function test_007_comment_surroundings()
	{
		Assert.same(
			expand(Paragraph(HList([@len(1)Word("a"),@skip(3)@len(1)Wordspace,@len(1)Word("b")]))),
			parse("a//x\nb"));
		Assert.same(
			expand(Paragraph(HList([@len(1)Word("a"),@skip(5)@len(1)Wordspace,@len(1)Word("b")]))),
			parse("a/*x*/\nb"));
		Assert.same(
			expand(Paragraph(HList([@len(1)Word("a"),@len(1)Wordspace,@skip(5)@len(1)Wordspace,@len(1)Word("b")]))),
			parse("a\t/*x*/ b"));

		Assert.same(
			expand(VList([Paragraph(@len(1)Word("a")),@skip(5)Paragraph(@len(1)Word("b"))])),
			parse("a//x\n\nb"));
		Assert.same(
			expand(VList([Paragraph(@len(1)Word("a")),@skip(7)Paragraph(@len(1)Word("b"))])),
			parse("a/*x*/\n\nb"));
	}

	public function test_008_hierarchy_commands()
	{
		Assert.same(
			expand(@wrap(8,1)Volume(HList([@len(1)Word("a"),@len(1)Wordspace,@len(1)Word("b")]))),
			parse("\\volume{a b}"));
		Assert.same(
			expand(VList([Paragraph(@len(1)Word("a")),@skip(2)@wrap(8,1)Volume(@len(1)Word("b")),@skip(2)Paragraph(@len(1)Word("c"))])),
			parse("a\n\n\\volume{b}\n\nc"));

		Assert.same(
			expand(@wrap(9,1)Chapter(HList([@len(1)Word("a"),@len(1)Wordspace,@len(1)Word("b")]))),
			parse("\\chapter{a b}"));
		Assert.same(
			expand(VList([Paragraph(@len(1)Word("a")),@skip(2)@wrap(9,1)Chapter(@len(1)Word("b")),@skip(2)Paragraph(@len(1)Word("c"))])),
			parse("a\n\n\\chapter{b}\n\nc"));

		Assert.same(
			expand(@wrap(9,1)Section(HList([@len(1)Word("a"),@len(1)Wordspace,@len(1)Word("b")]))),
			parse("\\section{a b}"));
		Assert.same(
			expand(VList([Paragraph(@len(1)Word("a")),@skip(2)@wrap(9,1)Section(@len(1)Word("b")),@skip(2)Paragraph(@len(1)Word("c"))])),
			parse("a\n\n\\section{b}\n\nc"));

		Assert.same(
			expand(@wrap(12,1)SubSection(HList([@len(1)Word("a"),@len(1)Wordspace,@len(1)Word("b")]))),
			parse("\\subsection{a b}"));
		Assert.same(
			expand(VList([Paragraph(@len(1)Word("a")),@skip(2)@wrap(12,1)SubSection(@len(1)Word("b")),@skip(2)Paragraph(@len(1)Word("c"))])),
			parse("a\n\n\\subsection{b}\n\nc"));

		Assert.same(
			expand(@wrap(15,1)SubSubSection(HList([@len(1)Word("a"),@len(1)Wordspace,@len(1)Word("b")]))),
			parse("\\subsubsection{a b}"));
		Assert.same(
			expand(VList([Paragraph(@len(1)Word("a")),@skip(2)@wrap(15,1)SubSubSection(@len(1)Word("b")),@skip(2)Paragraph(@len(1)Word("c"))])),
			parse("a\n\n\\subsubsection{b}\n\nc"));

		Assert.raises(parse.bind("\\section{\\volume{a}}"), UnexpectedToken);
		Assert.raises(parse.bind("\\section{a\\volume{b}}"), UnexpectedToken);
	}

	public function test_009_command_parsing_errors()
	{
		Assert.raises(parse.bind("\\section"), UnexpectedToken);
		Assert.raises(parse.bind("\\section\\section"), UnexpectedToken);
		Assert.raises(parse.bind("\\section{"), Unclosed);
		Assert.raises(parse.bind("\\section{}"), MissingArgument);
	}
}

