package tests;

import parser.Ast;
import parser.AstTools.*;
import parser.ParserError;
import parser.Token;
import utest.Assert;

class Test_03_Parser {
	static inline var TMP = "/tmp/";
	static inline var SRC = "tests.Test_03_Parser.hx";
	public function new() {}

	function parse(s:String)
	{
		var l = new parser.Lexer(haxe.io.Bytes.ofString(s), SRC);
		var p = new parser.Parser(SRC, l);
		return p.file();
	}

	function fails(text:String, ?expected:ParserErrorValue, ?textPattern:EReg, ?epos:Position, ?p:haxe.PosInfos)
	{
		Assert.raises(parse.bind(text), ParserError, p);
		if (expected != null || textPattern != null || epos != null) {
			try {
				parse(text);
			} catch (err:ParserError) {
				if (expected != null)
					Assert.same(expected, err.err, p);
				if (textPattern != null)
					Assert.match(textPattern, err.toString(), p);
				if (epos != null)
					Assert.same(epos, err.pos, p);
			}
		}
	}

	function mkPos(min, max):Position
		return { src:SRC, min:min, max:max };

	public function test_001_test_example()
	{
		Assert.same(
			expand(Paragraph(@len(3)Word("foo"))),
			parse("foo"));
		Assert.same(
			expand(Paragraph(HElemList([@len(3)Word("foo"),@len(1)Wordspace,@len(3)Word("bar")]))),
			parse("foo bar"));
		Assert.same(
			expand(@skip(2)Paragraph(HElemList([@len(3)Word("foo"),@len(2)Wordspace,@len(3)Word("bar"),@len(2)Wordspace,@len(3)Word("red")]))),
			parse("  foo \tbar\n red"));
	}

	public function test_001_wordspace()
	{
		Assert.same(
			expand(Paragraph(HElemList([@len(1)Word("a"),@len(1)Wordspace,@len(1)Word("b")]))),
			parse("a b"));
		Assert.same(
			expand(Paragraph(HElemList([@len(1)Word("a"),@len(1)Wordspace,@len(1)Word("b")]))),
			parse("a\tb"));
		Assert.same(
			expand(Paragraph(HElemList([@len(1)Word("a"),@len(1)Wordspace,@len(1)Word("b")]))),
			parse("a\nb"));
		Assert.same(
			expand(Paragraph(HElemList([@len(1)Word("a"),@len(2)Wordspace,@len(1)Word("b")]))),
			parse("a\r\nb"));

		Assert.same(
			expand(Paragraph(HElemList([@len(1)Word("a"),@len(2)Wordspace,@len(1)Word("b")]))),
			parse("a  b"));
		Assert.same(
			expand(Paragraph(HElemList([@len(1)Word("a"),@len(2)Wordspace,@len(1)Word("b")]))),
			parse("a \tb"));
		Assert.same(
			expand(Paragraph(HElemList([@len(1)Word("a"),@len(2)Wordspace,@len(1)Word("b")]))),
			parse("a\n b"));
		Assert.same(
			expand(Paragraph(HElemList([@len(1)Word("a"),@len(3)Wordspace,@len(1)Word("b")]))),
			parse("a\t\r\nb"));

		Assert.same(
			expand(Paragraph(HElemList([@len(1)Word("a"),@len(3)Wordspace,@len(1)Word("b")]))),
			parse("a   b"));
	}

	public function test_002_paragraph_break()
	{
		Assert.same(
			expand(VElemList([Paragraph(@len(1)Word("a")),@skip(2)Paragraph(@len(1)Word("b"))])),
			parse("a\n\nb"));
		Assert.same(
			expand(@skip(1)VElemList([Paragraph(@len(1)Word("a")),@skip(3)Paragraph(@len(1)Word("b"))])),
			parse(" a\n\n b"));
		Assert.same(
			expand(VElemList([Paragraph(@len(1)Word("a")),@skip(4)Paragraph(@len(1)Word("b"))])),
			parse("a\n \t\nb"));
		Assert.same(
			expand(VElemList([Paragraph(@len(1)Word("a")),@skip(5)Paragraph(@len(1)Word("b"))])),
			parse("a \r\n\t\nb"));

		Assert.same(
			expand(VElemList([Paragraph(@len(1)Word("a")),@wrap(8,1)Volume(@len(1)Word("b"))])),
			parse("a\\volume{b}"));
		Assert.same(
			expand(VElemList([Paragraph(@len(1)Word("a")),@wrap(9,1)Chapter(@len(1)Word("b"))])),
			parse("a\\chapter{b}"));
		Assert.same(
			expand(VElemList([Paragraph(@len(1)Word("a")),@wrap(9,1)Section(@len(1)Word("b"))])),
			parse("a\\section{b}"));
		Assert.same(
			expand(VElemList([Paragraph(@len(1)Word("a")),List(false,[@wrap(6,0)Paragraph(@len(1)Word("b"))])])),
			parse("a\\item b"));
	}

	public function test_003_emphasis()
	{
		Assert.same(
			expand(Paragraph(@wrap(6,1)Emphasis(@len(1)Word("a")))),
			parse("\\emph{a}"));
		Assert.same(
			expand(Paragraph(@wrap(6,1)Emphasis(HElemList([@len(1)Word("a"),@len(1)Wordspace,@len(1)Word("b")])))),
			parse("\\emph{a b}"));
		Assert.same(
			expand(Paragraph(@wrap(6,1)Emphasis(HElemList([@len(1)Word("a"),@len(1)Wordspace,@wrap(6,1)Emphasis(@len(1)Word("b"))])))),
			parse("\\emph{a \\emph{b}}"));

		Assert.same(
			expand(Paragraph(@wrap(1,1)Emphasis(@len(1)Word("a")))),
			parse("*a*"));
		Assert.same(
			expand(Paragraph(@wrap(1,1)Emphasis(HElemList([@len(1)Word("a"),@len(1)Wordspace,@len(1)Word("b")])))),
			parse("*a b*"));

		// there's only one level of markdown emphasis
		Assert.same(
			expand(Paragraph(HElemList([@wrap(1,1)Emphasis(HEmpty),@len(1)Word("a"),@wrap(1,1)Emphasis(HEmpty)]))),
			parse("**a**"));
		Assert.same(
			expand(Paragraph(HElemList([@wrap(1,1)Emphasis(HElemList([@len(1)Word("a"),@len(1)Wordspace])),@wrap(1,1)Emphasis(@len(1)Word("b")),@wrap(1,1)Emphasis(HElemList([@len(1)Wordspace,@len(1)Word("c")]))]))),
			parse("*a **b** c*"));
  // {\}}
		fails("\\emph", MissingArgument(TCommand("emph")), mkPos(5, 5));
		fails("\\emph a", MissingArgument(TCommand("emph")), mkPos(6,7));
		fails("\\emph{a}{}", UnexpectedToken(TBrOpen), mkPos(8,9));
	}

	public function test_004_highlight()
	{
		Assert.same(
			expand(Paragraph(@wrap(11,1)Highlight(@len(1)Word("a")))),
			parse("\\highlight{a}"));
		Assert.same(
			expand(Paragraph(@wrap(11,1)Highlight(HElemList([@len(1)Word("a"),@len(1)Wordspace,@len(1)Word("b")])))),
			parse("\\highlight{a b}"));
		Assert.same(
			expand(Paragraph(@wrap(11,1)Highlight(HElemList([@len(1)Word("a"),@len(1)Wordspace,@wrap(11,1)Highlight(@len(1)Word("b"))])))),
			parse("\\highlight{a \\highlight{b}}"));

		fails("\\highlight", MissingArgument(TCommand("highlight")), mkPos(10, 10));
		fails("\\highlight a", MissingArgument(TCommand("highlight")), mkPos(11, 12));
		fails("\\highlight{a}{}", UnexpectedToken(TBrOpen), mkPos(13, 14));
	}

	/*
	Good error reporting for unknown commands.

	Not only does this test that the error has been correctly specified as
	a unknown command, but also that the suggestion system is working
	correctly (at least for most of the time).
	*/
	public function test_005_bad_command_name()
	{
		// typos
		fails("\\emp", UnknownCommand("emp", "emph"), mkPos(0,4));
		fails("\\highligth", UnknownCommand("highligth", "highlight"));
		fails("\\volme", UnknownCommand("volme", "volume"));
		fails("\\chpter", UnknownCommand("chpter", "chapter"));
		fails("\\subection", UnknownCommand("subection", "subsection"));
		fails("\\subsubection", UnknownCommand("subsubection", "subsubsection"));
		fails("\\metaa\\reset", UnknownCommand("metaa", "meta"));
		fails("\\meta\\rest", UnknownCommand("rest", "reset"));
		fails("\\text\\preamble", UnknownCommand("text", "tex"));
		fails("\\tex\\preambl", UnknownCommand("preambl", "preamble"));

		// non existant aliases
		fails("\\emphasis", UnknownCommand("emphasis", "emph"));
		fails("\\display", UnknownCommand("display", "highlight"));
		fails("\\quote", UnknownCommand("quote", "quotation"));

		// TOOD figures, tables, lists, boxes
	}

	public function test_006_known_dificulties_from_poc()
	{
		// if whitespace is not properly handled spontaneous par breaks can happen bellow
		Assert.same(
			expand(Paragraph(HElemList([@wrap(1,1)Emphasis(@len(1)Word("a")),@len(1)Wordspace,@len(1)Word("b")]))),
			parse("*a*\nb"));
	}

	public function test_007_comment_surroundings()
	{
		Assert.same(
			expand(Paragraph(HElemList([@len(1)Word("a"),@skip(5)@len(1)Wordspace,@len(1)Word("b")]))),
			parse("a\\'x'\\\nb"));
		Assert.same(
			expand(Paragraph(HElemList([@len(1)Word("a"),@len(1)Wordspace,@skip(5)@len(1)Wordspace,@len(1)Word("b")]))),
			parse("a\t\\'x'\\ b"));

		Assert.same(
			expand(VElemList([Paragraph(@len(1)Word("a")),@skip(7)Paragraph(@len(1)Word("b"))])),
			parse("a\\'x'\\\n\nb"));

		Assert.same(
			expand(@len(9)VEmpty),
			parse("\\' foo '\\"));
	}

	public function test_008_hierarchy_commands()
	{
		Assert.same(
			expand(@wrap(8,1)Volume(HElemList([@len(1)Word("a"),@len(1)Wordspace,@len(1)Word("b")]))),
			parse("\\volume{a b}"));
		Assert.same(
			expand(VElemList([Paragraph(@len(1)Word("a")),@skip(2)@wrap(8,1)Volume(@len(1)Word("b")),@skip(2)Paragraph(@len(1)Word("c"))])),
			parse("a\n\n\\volume{b}\n\nc"));

		Assert.same(
			expand(@wrap(9,1)Chapter(HElemList([@len(1)Word("a"),@len(1)Wordspace,@len(1)Word("b")]))),
			parse("\\chapter{a b}"));
		Assert.same(
			expand(VElemList([Paragraph(@len(1)Word("a")),@skip(2)@wrap(9,1)Chapter(@len(1)Word("b")),@skip(2)Paragraph(@len(1)Word("c"))])),
			parse("a\n\n\\chapter{b}\n\nc"));

		Assert.same(
			expand(@wrap(9,1)Section(HElemList([@len(1)Word("a"),@len(1)Wordspace,@len(1)Word("b")]))),
			parse("\\section{a b}"));
		Assert.same(
			expand(VElemList([Paragraph(@len(1)Word("a")),@skip(2)@wrap(9,1)Section(@len(1)Word("b")),@skip(2)Paragraph(@len(1)Word("c"))])),
			parse("a\n\n\\section{b}\n\nc"));

		Assert.same(
			expand(@wrap(12,1)SubSection(HElemList([@len(1)Word("a"),@len(1)Wordspace,@len(1)Word("b")]))),
			parse("\\subsection{a b}"));
		Assert.same(
			expand(VElemList([Paragraph(@len(1)Word("a")),@skip(2)@wrap(12,1)SubSection(@len(1)Word("b")),@skip(2)Paragraph(@len(1)Word("c"))])),
			parse("a\n\n\\subsection{b}\n\nc"));

		Assert.same(
			expand(@wrap(15,1)SubSubSection(HElemList([@len(1)Word("a"),@len(1)Wordspace,@len(1)Word("b")]))),
			parse("\\subsubsection{a b}"));
		Assert.same(
			expand(VElemList([Paragraph(@len(1)Word("a")),@skip(2)@wrap(15,1)SubSubSection(@len(1)Word("b")),@skip(2)Paragraph(@len(1)Word("c"))])),
			parse("a\n\n\\subsubsection{b}\n\nc"));

		fails("\\volume", MissingArgument(TCommand("volume"), "name"), mkPos(7, 7));
		fails("\\volume a", MissingArgument(TCommand("volume"), "name"), mkPos(8, 9));
		fails("\\volume{a}{}", UnexpectedToken(TBrOpen), mkPos(10, 11));
		fails("\\section{\\volume{a}}", UnexpectedToken(TCommand("volume")), mkPos(9, 16));
		fails("\\section{a\\volume{b}}", UnexpectedToken(TCommand("volume")), mkPos(10, 17));
	}

	public function test_009_argument_parsing_errors()
	{
		fails("\\section{", UnclosedToken(TBrOpen), mkPos(8,9));
	}

	public function test_011_quotations()
	{
		Assert.same(
			expand(@wrap(11,1)Quotation(@len(1)Word("a"),@skip(2)@len(1)Word("b"))),  // FIXME @skip
			parse("\\quotation{a}{b}"));
		Assert.same(
			expand(@wrap(12,1)Quotation(@len(1)Word("a"),@skip(3)@len(1)Word("b"))),  // FIXME @skip
			parse("\\quotation\n{a}\n{b}"));

		fails("\\quotation", MissingArgument(TCommand("quotation"), "text"), mkPos(10, 10));
		fails("\\quotation a", MissingArgument(TCommand("quotation"), "text"), mkPos(11, 12));
		fails("\\quotation{a}", MissingArgument(TCommand("quotation"), "author"), mkPos(13, 13));
		fails("\\quotation{a} b", MissingArgument(TCommand("quotation"), "author"), mkPos(14, 15));
		fails("\\quotation{a}{b}{}", UnexpectedToken(TBrOpen), mkPos(16, 17));
	}

	public function test_012_figures()
	{
		Assert.same(
			expand(@wrap(8,1)Figure(MarginWidth,@elem@len(7)"fig.png",@skip(2)@len(7)Word("caption"),@skip(2)@len(9)Word("copyright"))),  // FIXME no pos for path, @skip
			parse("\\figure{fig.png}{caption}{copyright}"));
	}

	public function test_013_lists()
	{
		// simple lists
		// unnumbered
		Assert.same(
			expand(List(false,[@wrap(6,0)Paragraph(@len(1)Word("a"))])),
			parse("\\item a"));
		Assert.same(
			expand(List(false,[@wrap(6,0)Paragraph(@len(1)Word("a")),@wrap(6,0)Paragraph(@len(1)Word("b"))])),
			parse("\\item a\\item b"));
		Assert.same(
			expand(VElemList([
				Paragraph(@len(1)Word("x")),@skip(2)
				List(false,[@wrap(6,0)Paragraph(@len(1)Word("a")),@wrap(6,0)Paragraph(@len(1)Word("b"))]),@skip(2)
				Paragraph(@len(1)Word("y"))
			])),
			parse("x\n\n\\item a\\item b\n\ny"));
		// numerated
		Assert.same(
			expand(List(true,[@wrap(8,0)Paragraph(@len(1)Word("a"))])),
			parse("\\number a"));
		Assert.same(
			expand(List(true,[@wrap(8,0)Paragraph(@len(1)Word("a")),@wrap(8,0)Paragraph(@len(1)Word("b"))])),
			parse("\\number a\\number b"));
		Assert.same(
			expand(VElemList([
				Paragraph(@len(1)Word("x")),@skip(2)
				List(true,[@wrap(8,0)Paragraph(@len(1)Word("a")),@wrap(8,0)Paragraph(@len(1)Word("b"))]),@skip(2)
				Paragraph(@len(1)Word("y"))
			])),
			parse("x\n\n\\number a\\number b\n\ny"));

		// vlist items
		// unnumbered
		Assert.same(
			expand(List(false,[@wrap(6,1)Paragraph(@len(1)Word("a"))])),
			parse("\\item[a]"));
		Assert.same(
			expand(List(false,[@wrap(6,1)Paragraph(@len(1)Word("a")),@wrap(6,1)Paragraph(@len(1)Word("b"))])),
			parse("\\item[a]\\item[b]"));
		Assert.same(
			expand(VElemList([
				Paragraph(@len(1)Word("x")),@skip(2)
				List(false,[@wrap(6,1)Paragraph(@len(1)Word("a")),@wrap(6,1)Paragraph(@len(1)Word("b"))]),@skip(2)
				Paragraph(@len(1)Word("y"))
			])),
			parse("x\n\n\\item[a]\\item[b]\n\ny"));
		// numbered
		Assert.same(
			expand(List(true,[@wrap(8,1)Paragraph(@len(1)Word("a"))])),
			parse("\\number[a]"));
		Assert.same(
			expand(List(true,[@wrap(8,1)Paragraph(@len(1)Word("a")),@wrap(8,1)Paragraph(@len(1)Word("b"))])),
			parse("\\number[a]\\number[b]"));
		Assert.same(
			expand(VElemList([
				Paragraph(@len(1)Word("x")),@skip(2)
				List(true,[@wrap(8,1)Paragraph(@len(1)Word("a")),@wrap(8,1)Paragraph(@len(1)Word("b"))]),@skip(2)
				Paragraph(@len(1)Word("y"))
			])),
			parse("x\n\n\\number[a]\\number[b]\n\ny"));

		// lists in items
		// x in x
		Assert.same(
			expand(List(false,[
				@wrap(6,1)VElemList([
					Paragraph(@len(1)Word("a")),@skip(2)
					List(false,[@wrap(6,0)Paragraph(@len(1)Word("x")),@wrap(6,0)Paragraph(@len(1)Word("y"))])]),
				@wrap(6,1)Paragraph(@len(1)Word("b"))])),
			parse("\\item[a\n\n\\item x\\item y]\\item[b]"));
		Assert.same(
			expand(List(true,[
				@wrap(8,1)VElemList([
					Paragraph(@len(1)Word("a")),@skip(2)
					List(true,[@wrap(8,0)Paragraph(@len(1)Word("x")),@wrap(8,0)Paragraph(@len(1)Word("y"))])]),
				@wrap(8,1)Paragraph(@len(1)Word("b"))])),
			parse("\\number[a\n\n\\number x\\number y]\\number[b]"));
		// x in !x
		Assert.same(
			expand(List(false,[
				@wrap(6,1)VElemList([
					Paragraph(@len(1)Word("a")),@skip(2)
					List(true,[@wrap(8,0)Paragraph(@len(1)Word("x")),@wrap(8,0)Paragraph(@len(1)Word("y"))])]),
				@wrap(6,1)Paragraph(@len(1)Word("b"))])),
			parse("\\item[a\n\n\\number x\\number y]\\item[b]"));
		Assert.same(
			expand(List(true,[
				@wrap(8,1)VElemList([
					Paragraph(@len(1)Word("a")),@skip(2)
					List(false,[@wrap(6,0)Paragraph(@len(1)Word("x")),@wrap(6,0)Paragraph(@len(1)Word("y"))])]),
				@wrap(8,1)Paragraph(@len(1)Word("b"))])),
			parse("\\number[a\n\n\\item x\\item y]\\number[b]"));

		// lists end on breakspaces
		Assert.same(
			expand(VElemList([
				List(false,[@wrap(6,0)Paragraph(@len(1)Word("a")),@wrap(6,0)Paragraph(@len(1)Word("b"))]),@skip(2)
				List(false,[@wrap(6,0)Paragraph(@len(1)Word("x")),@wrap(6,0)Paragraph(@len(1)Word("y"))])
			])),
			parse("\\item a\\item b\n\n\\item x\\item y"));

		// numerated lists end on !numerated (and the opposite)
		Assert.same(
			expand(VElemList([
				List(false,[@wrap(6,0)Paragraph(@len(1)Word("a")),@wrap(6,0)Paragraph(@len(1)Word("b"))]),
				List(true,[@wrap(8,0)Paragraph(@len(1)Word("1"))]),
				List(false,[@wrap(6,0)Paragraph(@len(1)Word("x"))])
			])),
			parse("\\item a\\item b\\number 1\\item x"));
		Assert.same(
			expand(VElemList([
				List(true,[@wrap(8,0)Paragraph(@len(1)Word("1")),@wrap(8,0)Paragraph(@len(1)Word("2"))]),
				List(false,[@wrap(6,0)Paragraph(@len(1)Word("x"))]),
				List(true,[@wrap(8,0)Paragraph(@len(1)Word("a"))])
			])),
			parse("\\number 1\\number 2\\item x\\number a"));

		// TODO more error tests (invalid vlist items)
	}

	public function test_014_discardable_tokens()
	{
		// before arguments
		Assert.same(
			expand(Paragraph(@wrap(6,1)Emphasis(@skip(1)@len(1)Word("a")))),
			parse("\\emph {a}"));
		Assert.same(
			expand(Paragraph(@wrap(6,1)Emphasis(@skip(1)@len(1)Word("a")))),
			parse("\\emph\n{a}"));
		Assert.same(
			expand(Paragraph(@wrap(6,1)Emphasis(@skip(7)@len(1)Word("a")))),
			parse("\\emph\\'foo'\\{a}"));
		Assert.same(
			expand(List(false,[@wrap(6,1)Paragraph(@skip(1)@len(1)Word("a"))])),
			parse("\\item [a]"));
		Assert.same(
			expand(List(false,[@wrap(6,1)Paragraph(@skip(1)@len(1)Word("a"))])),
			parse("\\item\n[a]"));
		Assert.same(
			expand(List(false,[@wrap(6,1)Paragraph(@skip(7)@len(1)Word("a"))])),
			parse("\\item\\'foo'\\[a]"));

		// after argument opening braces
		Assert.same(
			expand(Paragraph(@wrap(6,1)Emphasis(@skip(7)@len(1)Word("a")))),
			parse("\\emph{\\'foo'\\a}"));

		// in between list items
		Assert.same(
			expand(List(false,[@wrap(6,1)Paragraph(@len(1)Word("a")),@skip(7)@wrap(6,1)Paragraph(@len(1)Word("b"))])),
			parse("\\item[a]\\'foo'\\\\item[b]"));
	}

	public function test_015_meta_reset()
	{
		Assert.same(
			expand(@len(22)MetaReset("volume", 2)),
			parse("\\meta\\reset{volume}{2}"));
		Assert.same(
			expand(@len(23)MetaReset("chapter", 8)),
			parse("\\meta\\reset{chapter}{8}"));

		Assert.same(
			expand(@len(25)MetaReset("volume", 2)),
			parse("\\meta \t\n\\reset{volume}{2}"));
		Assert.same(
			expand(@len(27)MetaReset("volume", 2)),
			parse("\\meta\\'a'\\\\reset{volume}{2}"));

		var badCounter = "counter name should be 'volume' or 'chapter'";
		var badValue = "reset value must be strictly greater or equal to zero";
		fails("\\meta\\reset{section}{1}", BadValue(badCounter));
		fails("\\meta\\reset{subsection}{1}", BadValue(badCounter));
		fails("\\meta\\reset{subsubsection}{1}", BadValue(badCounter));

		fails("\\meta\\reset{volume}{a}", BadValue(badValue));
		fails("\\meta\\reset{volume}{-1}", BadValue(badValue));
		fails("\\meta\\reset{volume}{1a}", BadValue(badValue));  // FIXME

		fails("\\meta\\reset{}{1}", BadValue(badCounter));
		fails("\\meta\\reset{volume}{}", BadValue(badValue));

		fails("\\meta\\reset", MissingArgument(TCommand("reset"), "counter name"));
		fails("\\meta\\reset{volume}", MissingArgument(TCommand("reset"), "reset value"));

		fails("\\meta");  // FIXME specific error
		fails("\\meta\n\n\\reset{volume}{2}");  // FIXME specific error
	}

	public function test_016_break_spaces_in_arguments()
	{
		// Section name must be a hlist, hence no break spaces can happen
		fails("\\section{\n\nname}");

		// It's hard to decide whether raw arguments should accept
		// break spaces or not: on one hand, this is closer to what
		// "raw" is expected to mean; on the other, this allows for
		// uggly things like
		//     \meta\reset{
		//
		//                 volume}{0}
		// and this isn't something we want to encorage.
		// However, we need to allow this for proper path parsing;
		// otherwise, it would be necesarry to allow newline escaping,
		// and that could cause tons of problems elsewhere.
		Assert.same(expand(@len(24)MetaReset("volume",0)), parse("\\meta\\reset{\n\nvolume}{0}"));
		Assert.same(expand(@wrap(12,1)HtmlStore(@elem@len(6)"a \n\n b")), parse("\\html\\store{a \n\n b}"));
	}

	public function test_017_boxes()
	{
		Assert.same(
			expand(@wrap(10,7)Box(@len(1)Word("a"),@skip(1)VEmpty)),
			parse("\\beginbox{a}\\endbox"));
		Assert.same(
			expand(@wrap(10,7)Box(@len(1)Word("a"),@skip(1)Paragraph(@len(1)Word("b")))),
			parse("\\beginbox{a}b\\endbox"));
		Assert.same(
			expand(@wrap(10,7)Box(@len(1)Word("a"),@skip(1)VElemList([Paragraph(@len(1)Word("b")),@skip(2)Paragraph(@len(1)Word("c"))]))),
			parse("\\beginbox{a}b\n\nc\\endbox"));

		fails("\\endbox", UnexpectedToken(TCommand("endbox"), "no beginning"));

		fails("\\beginbox", MissingArgument(TCommand("beginbox"), "name"), mkPos(9, 9));
		fails("\\beginbox a", MissingArgument(TCommand("beginbox"), "name"), mkPos(10, 11));
		fails("\\beginbox{a}{}", UnexpectedToken(TBrOpen), mkPos(12, 13));
	}

	public function test_018_controled_nesting_of_vertical_elements()
	{
		fails("\\item[\\section{foo}]", UnexpectedToken(TCommand("section"), "headings not allowed here"));
		fails("\\beginbox{foo}\\section{bar}\\endbox", UnexpectedToken(TCommand("section"), "headings not allowed here"));
		fails("\\item[\\beginbox{foo}\\endbox]", UnexpectedToken(TCommand("beginbox"), "boxes not allowed here"));
	}

	// TODO
	// public function test_019_html_metas()
	// {
	// }

	public function test_020_tex_metas()
	{
		// TODO \tex\preamble

		// \tex\export
		Assert.same(expand(@wrap(12,1)LaTeXExport(@elem@len(1)"a",@skip(2)@elem@len(1)"b")), parse("\\tex\\export{a}{b}"));
		Assert.same(expand(@wrap(12,1)LaTeXExport(@elem@len(1)"a",@skip(2)@elem@len(11)"c/d/../../b")), parse("\\tex\\export{a}{c/d/../../b}"));
		Assert.equals("b", ( expand(@elem"c/d/../../b"):PElem ).toOutputPath(""));
	}

	public function test_021_include()
	{
		sys.io.File.saveContent(".testfile.manu", "c");
		Assert.same(expand(@src(".testfile.manu")Paragraph(@len(1)Word("c"))), parse("\\include{.testfile.manu}"));
		// fails("\\include{.nonexistant}", Invalid(FileNotExists(".noexistant")));
		// TODO test "not a file" error
		sys.FileSystem.deleteFile(".testfile.manu");
	}

	// TODO
	public function test_022_tables()
	{
		Assert.same(
			expand(@wrap(12,9)Table(TextWidth,@len(1)Word("a"),@skip(1)
				[@skip(12)Paragraph(@len(1)Word("x")),@skip(5)Paragraph(@len(1)Word("y"))], [
				[@skip( 9)Paragraph(@len(1)Word("1")),@skip(5)Paragraph(@len(1)Word("2"))],
				[@skip( 9)Paragraph(@len(1)Word("3")),@skip(5)Paragraph(@len(1)Word("4"))] ])),
			parse("\\begintable{a}\\header\\col x\\col y\\row\\col 1\\col 2\\row\\col 3\\col 4\\endtable"));

		Assert.same(
			expand(@wrap(12,9)Table(TextWidth,@len(1)Word("a"),@skip(1)
				[@skip(12)Paragraph(@len(1)Word("x")),@skip(5)Paragraph(@len(1)Word("y"))], [
				[@skip(9)Paragraph(@len(4)Word("list")),@skip(5)List(false,[
					@wrap(6,0)Paragraph(@len(1)Word("1")),
					@wrap(6,0)Paragraph(@len(1)Word("2")) ])] ])),
			parse("\\begintable{a}\\header\\col x\\col y\\row\\col list\\col \\item 1\\item 2\\endtable"));

		Assert.same(
			expand(@wrap(12,10)ImgTable(TextWidth,@len(1)Word("a"),@skip(11)@elem@len(5)"x.svg")),
			parse("\\begintable{a}\\useimage{x.svg}\\endtable"));

		fails("\\endtable", UnexpectedToken(TCommand("endtable"), "no beginning"));
	}

	public function test_024_paragraph_beginning()
	{
		Assert.same(expand(Paragraph(@len(1)Word("a"))), parse("a"));
		Assert.same(expand(Paragraph(@len(1)Word(":"))), parse(":"));
		Assert.same(expand(Paragraph(@wrap(1,1)Emphasis(@len(1)Word("a")))), parse("*a*"));
		Assert.same(expand(Paragraph(@wrap(6,1)Emphasis(@len(1)Word("a")))), parse("\\emph{a}"));
		Assert.same(expand(Paragraph(@wrap(11,1)Highlight(@len(1)Word("a")))), parse("\\highlight{a}"));
		Assert.same(expand(Paragraph(@len(10)InlineCode("x_z"))), parse("\\code!x_z!"));
		Assert.same(expand(Paragraph(@len(7)Math("x_z"))), parse("$$x_z$$"));
	}

	public function test_025_math()
	{
		Assert.same(
			expand(Paragraph(HElemList([@len(1)Word("a"),@len(1)Wordspace,@len(7)Math("x_z"),@len(1)Wordspace,@len(1)Word("b")]))),
			parse("a $$x_z$$ b"));
		Assert.same(
			expand(Paragraph(HElemList([@len(1)Word("a"),@len(1)Wordspace,@len(16)Math("\\text{speed}"),@len(1)Wordspace,@len(1)Word("b")]))),
			parse("a $$\\text{speed}$$ b"));
	}

	public function test_026_super_sub_scripts()
	{
		Assert.same(
			expand(Paragraph(HElemList([@len(1)Word("a"),@wrap(5,1)Superscript(@len(1)Word("b"))]))),
			parse("a\\sup{b}"));
		Assert.same(
			expand(Paragraph(HElemList([@len(1)Word("a"),@wrap(5,1)Superscript(HElemList([@len(1)Word("b"),@len(1)Wordspace,@len(1)Word("c")]))]))),
			parse("a\\sup{b c}"));
		Assert.same(
			expand(Paragraph(HElemList([@len(1)Word("a"),@wrap(5,1)Superscript(HElemList([@len(1)Word("b"),@wrap(5,1)Superscript(@len(1)Word("c"))]))]))),
			parse("a\\sup{b\\sup{c}}"));

		Assert.same(
			expand(Paragraph(HElemList([@len(1)Word("a"),@wrap(5,1)Subscript(@len(1)Word("b"))]))),
			parse("a\\sub{b}"));
		Assert.same(
			expand(Paragraph(HElemList([@len(1)Word("a"),@wrap(5,1)Subscript(HElemList([@len(1)Word("b"),@len(1)Wordspace,@len(1)Word("c")]))]))),
			parse("a\\sub{b c}"));
		Assert.same(
			expand(Paragraph(HElemList([@len(1)Word("a"),@wrap(5,1)Subscript(HElemList([@len(1)Word("b"),@wrap(5,1)Subscript(@len(1)Word("c"))]))]))),
			parse("a\\sub{b\\sub{c}}"));

		Assert.same(
			expand(Paragraph(HElemList([@len(1)Word("a"),@wrap(5,1)Superscript(HElemList([@len(1)Word("b"),@wrap(5,1)Subscript(@len(1)Word("c"))]))]))),
			parse("a\\sup{b\\sub{c}}"));
		Assert.same(
			expand(Paragraph(HElemList([@len(1)Word("a"),@wrap(5,1)Subscript(HElemList([@len(1)Word("b"),@wrap(5,1)Superscript(@len(1)Word("c"))]))]))),
			parse("a\\sub{b\\sup{c}}"));

		fails("\\sup", MissingArgument(TCommand("sup")), mkPos(4, 4));
		fails("\\sup a", MissingArgument(TCommand("sup")), mkPos(5, 6));
		fails("\\sup{a}{}", UnexpectedToken(TBrOpen), mkPos(7, 8));

		fails("\\sub", MissingArgument(TCommand("sub")), mkPos(4, 4));
		fails("\\sub a", MissingArgument(TCommand("sub")), mkPos(5, 6));
		fails("\\sub{a}{}", UnexpectedToken(TBrOpen), mkPos(7, 8));
	}

	public function test_027_paths()
	{
		Assert.same(expand(@wrap(12,1)HtmlStore(@elem@len(1)"a")), parse("\\html\\store{a}"));

		// whitespace in paths is maintained
		Assert.same(expand(@wrap(12,1)HtmlStore(@elem@len(3)" a ")), parse("\\html\\store{ a }"));
		Assert.same(expand(@wrap(12,1)HtmlStore(@elem@len(6)"a \n\n b")), parse("\\html\\store{a \n\n b}"));

		// escapes and tex ligatures work the same (use the former to disable the latter)
		Assert.same(expand(@wrap(12,1)HtmlStore(@elem@len(2)"\\")), parse("\\html\\store{\\\\}"));
		Assert.same(expand(@wrap(12,1)HtmlStore(@elem@len(2)"}")), parse("\\html\\store{\\}}"));
		Assert.same(expand(@wrap(12,1)HtmlStore(@elem@len(3)"--")), parse("\\html\\store{-\\-}"));

		fails("\\html\\store{foo\\bar}", UnexpectedToken(TCommand("bar")));
	}

	public function test_028_blob_sizes()
	{
		Assert.same(
			expand(@wrap(12+7,10)ImgTable(MarginWidth,@len(1)Word("a"),@skip(11)@elem@len(5)"x.svg")),
			parse("\\begintable[small]{a}\\useimage{x.svg}\\endtable"));
		Assert.same(
			expand(@wrap(12+8,10)ImgTable(TextWidth,@len(1)Word("a"),@skip(11)@elem@len(5)"x.svg")),
			parse("\\begintable[medium]{a}\\useimage{x.svg}\\endtable"));
		Assert.same(
			expand(@wrap(12+7,10)ImgTable(FullWidth,@len(1)Word("a"),@skip(11)@elem@len(5)"x.svg")),
			parse("\\begintable[large]{a}\\useimage{x.svg}\\endtable"));

		Assert.same(
			expand(@wrap(12+9,10)ImgTable(MarginWidth,@len(1)Word("a"),@skip(11)@elem@len(5)"x.svg")),
			parse("\\begintable[ small ]{a}\\useimage{x.svg}\\endtable"));
		Assert.same(
			expand(@wrap(12+9,10)ImgTable(MarginWidth,@len(1)Word("a"),@skip(11)@elem@len(5)"x.svg")),
			parse("\\begintable[\nsmall\n]{a}\\useimage{x.svg}\\endtable"));
	}

	public function test_029_test_url()
	{
		Assert.same(expand(Paragraph(@wrap(5,1)Url(@len(3)"foo"))), parse("\\url{foo}"));
		Assert.same(expand(Paragraph(@wrap(5,1)Url(@len(5)"foo"))), parse("\\url{ foo }"));  // unstable: triming
		fails("\\url", MissingArgument(TCommand("url")), mkPos(4, 4));
		fails("\\url a", MissingArgument(TCommand("url")), mkPos(5, 6));
		fails("\\url{a}{}", UnexpectedToken(TBrOpen), mkPos(7, 8));
	}

	public function test_030_test_title()
	{
		Assert.same(expand(@wrap(7,1)Title(Word(@len(3)"foo"))), parse("\\title{foo}"));
		fails("\\title", MissingArgument(TCommand("title"), "name"), mkPos(6, 6));  // unstable: arg description
		fails("\\title a", MissingArgument(TCommand("title"), "name"), mkPos(7, 8));  // unstable: arg description
		fails("\\title{a}{}", UnexpectedToken(TBrOpen), mkPos(9, 10));
	}
}

