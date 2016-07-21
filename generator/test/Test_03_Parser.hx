import parser.Ast;
import parser.AstTools.*;
import parser.Error;
import parser.Token;
import utest.Assert;

class Test_03_Parser {
	static inline var SRC = "Test_03_Parser.hx";
	public function new() {}

	function parse(s:String)
	{
		var l = new parser.Lexer(haxe.io.Bytes.ofString(s), SRC);
		var p = new parser.Parser(SRC, l);
		return p.file();
	}

	function parsingError(text:String, ?etype:Class<GenericError>, ?etext:EReg, ?epos:Position, ?p:haxe.PosInfos)
	{
		Assert.raises(parse.bind(text), etype, p);
		if (etext != null || epos != null) {
			try {
				parse(text);
			} catch (err:GenericError) {
				if (etext != null)
					Assert.match(etext, err.text, p);
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
		Assert.same(
			expand(VList([Paragraph(@len(1)Word("a")),List(false,[@wrap(6,0)Paragraph(@len(1)Word("b"))])])),
			parse("a\\item b"));
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

		// there's only one level of markdown emphasis
		Assert.same(
			expand(Paragraph(HList([@len(2)Emphasis(null),@len(1)Word("a"),@len(2)Emphasis(null)]))),
			parse("**a**"));
		Assert.same(
			expand(Paragraph(HList([@wrap(1,1)Emphasis(HList([@len(1)Word("a"),@len(1)Wordspace])),@wrap(1,1)Emphasis(@len(1)Word("b")),@wrap(1,1)Emphasis(HList([@len(1)Wordspace,@len(1)Word("c")]))]))),
			parse("*a **b** c*"));

		parsingError("\\emph", MissingArgument, ~/argument.+\\emph/i, mkPos(5, 5));
		parsingError("\\emph a", MissingArgument, ~/argument.+\\emph/i, mkPos(6,7));
		parsingError("\\emph{a}{}", UnexpectedToken, ~/{/, mkPos(8,9));
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

		parsingError("\\highlight", MissingArgument, ~/argument.+\\highligh/i, mkPos(10, 10));
		parsingError("\\highlight a", MissingArgument, ~/argument.+\\highlight/i, mkPos(11, 12));
		parsingError("\\highlight{a}{}", UnexpectedToken, ~/{/, mkPos(13, 14));
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
		parsingError("\\emp", UnknownCommand, ~/\\emp.+\\emph/, mkPos(0,4));
		parsingError("\\highligth", UnknownCommand, ~/\\highligth.+\\highlight/);
		parsingError("\\volme", UnknownCommand, ~/\\volme.+\\volume/);
		parsingError("\\chpter", UnknownCommand, ~/\\chpter.+\\chapter/);
		parsingError("\\subection", UnknownCommand, ~/\\subection.+\\subsection/);
		parsingError("\\subsubection", UnknownCommand, ~/\\subsubection.+\\subsubsection/);
		parsingError("\\metaa\\reset", UnknownCommand, ~/\\metaa.+\\meta/);
		parsingError("\\meta\\rest", UnknownCommand, ~/\\rest.+\\reset/);
		parsingError("\\hml\\apply", UnknownCommand, ~/\\hml.+\\html/);
		parsingError("\\html\\appply", UnknownCommand, ~/\\appply.+\\apply/);
		parsingError("\\text\\preamble", UnknownCommand, ~/\\text.+\\tex/);
		parsingError("\\tex\\preambl", UnknownCommand, ~/\\preambl.+\\preamble/);

		// non existant aliases
		parsingError("\\emphasis", UnknownCommand, ~/\\emphasis.+\\emph/);
		parsingError("\\display", UnknownCommand);
		// parsingError("\\display", UnknownCommand, ~/\\display.+\\highlight/);  // FIXME
		parsingError("\\quote", UnknownCommand);
		// parsingError("\\quote", UnknownCommand, ~/\\quote.+\\quotation/);  // FIXME

		// TOOD figures, tables, lists, boxes
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
			expand(Paragraph(HList([@len(1)Word("a"),@skip(5)@len(1)Wordspace,@len(1)Word("b")]))),
			parse("a\\'x'\\\nb"));
		Assert.same(
			expand(Paragraph(HList([@len(1)Word("a"),@len(1)Wordspace,@skip(5)@len(1)Wordspace,@len(1)Word("b")]))),
			parse("a\t\\'x'\\ b"));

		Assert.same(
			expand(VList([Paragraph(@len(1)Word("a")),@skip(7)Paragraph(@len(1)Word("b"))])),
			parse("a\\'x'\\\n\nb"));

		Assert.same(
			expand(null),
			parse("\\' foo '\\"));
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

		parsingError("\\volume", MissingArgument, ~/name.+\\volume/i, mkPos(7, 7));
		parsingError("\\volume a", MissingArgument, ~/name.+\\volume/i, mkPos(8, 9));
		parsingError("\\volume{a}{}", UnexpectedToken, ~/{/, mkPos(10, 11));
		parsingError("\\section{\\volume{a}}", UnexpectedToken, ~/\\volume/, mkPos(9, 16));
		parsingError("\\section{a\\volume{b}}", UnexpectedToken, ~/\\volume/, mkPos(10, 17));

		parsingError("\\volume{}", BadValue, ~/name cannot be empty/i, mkPos(8, 8));
		parsingError("\\chapter{}", BadValue, ~/name cannot be empty/i, mkPos(9, 9));
		parsingError("\\section{}", BadValue, ~/name cannot be empty/i, mkPos(9, 9));
		parsingError("\\subsection{}", BadValue, ~/name cannot be empty/i, mkPos(12, 12));
		parsingError("\\subsubsection{}", BadValue, ~/name cannot be empty/i, mkPos(15, 15));
	}

	public function test_009_argument_parsing_errors()
	{
		parsingError("\\section{", UnclosedToken, ~/{/, mkPos(8,9));
	}

	public function test_010_md_headings()
	{
		Assert.same(
			expand(@wrap(1,0)Section(HList([@len(1)Word("a"),@len(1)Wordspace,@len(1)Word("b")]))),
			parse("#a b"));
		Assert.same(
			expand(VList([Paragraph(@len(1)Word("a")),@skip(2)@wrap(2,0)Section(@len(1)Word("b")),@skip(2)Paragraph(@len(1)Word("c"))])),
			parse("a\n\n# b\n\nc"));

		Assert.same(
			expand(@wrap(2,0)SubSection(HList([@len(1)Word("a"),@len(1)Wordspace,@len(1)Word("b")]))),
			parse("##a b"));
		Assert.same(
			expand(VList([Paragraph(@len(1)Word("a")),@skip(2)@wrap(3,0)SubSection(@len(1)Word("b")),@skip(2)Paragraph(@len(1)Word("c"))])),
			parse("a\n\n## b\n\nc"));

		Assert.same(
			expand(@wrap(3,0)SubSubSection(HList([@len(1)Word("a"),@len(1)Wordspace,@len(1)Word("b")]))),
			parse("###a b"));
		Assert.same(
			expand(VList([Paragraph(@len(1)Word("a")),@skip(2)@wrap(4,0)SubSubSection(@len(1)Word("b")),@skip(2)Paragraph(@len(1)Word("c"))])),
			parse("a\n\n### b\n\nc"));

		parsingError("####a b", UnexpectedToken, ~/####/, mkPos(0, 4));
	}

	public function test_011_quotations()
	{
		Assert.same(
			expand(@wrap(11,1)Quotation(@len(1)Word("a"),@skip(2)@len(1)Word("b"))),  // FIXME @skip
			parse("\\quotation{a}{b}"));
		Assert.same(
			expand(@wrap(12,1)Quotation(@len(1)Word("a"),@skip(3)@len(1)Word("b"))),  // FIXME @skip
			parse("\\quotation\n{a}\n{b}"));

		Assert.same(
			expand(@wrap(1,0)Quotation(@len(1)Word("a"),@skip(1)@len(1)Word("b"))),
			parse(">a@b"));
		Assert.same(
			expand(@wrap(2,0)Quotation(HList([@len(1)Word("a"),@len(1)Wordspace]),@skip(1)@len(1)Word("b"))),
			parse("> a\n@b"));

		parsingError("\\quotation", MissingArgument, ~/text.+\\quotation/i, mkPos(10, 10));
		parsingError("\\quotation a", MissingArgument, ~/text.+\\quotation/i, mkPos(11, 12));
		parsingError("\\quotation{a}", MissingArgument, ~/author.+\\quotation/i, mkPos(13, 13));
		parsingError("\\quotation{a} b", MissingArgument, ~/author.+\\quotation/i, mkPos(14, 15));
		parsingError("\\quotation{a}{b}{}", UnexpectedToken, ~/{/, mkPos(16, 17));
		parsingError(">a\n\nb", MissingArgument, ~/author.+quotation/);

		parsingError("\\quotation{a}{}", BadValue, ~/author cannot be empty/i, mkPos(14,14));
		parsingError("\\quotation{}{b}", BadValue, ~/text cannot be empty/i, mkPos(11, 11));
		parsingError(">a@\n\nb", BadValue, ~/author cannot be empty/i, mkPos(3, 3));
		parsingError(">@a\n\nb", BadValue, ~/text cannot be empty/i, mkPos(1, 1));
	}

	public function test_012_figures()
	{
		Assert.same(
			expand(@wrap(8,1)Figure(MarginWidth, "fig.png",@skip(2+7)@len(7)Word("caption"),@skip(2)@len(9)Word("copyright"))),  // FIXME no pos for path, @skip
			parse("\\figure{fig.png}{caption}{copyright}"));

		Assert.same(
			expand(@wrap(5,0)Figure(MarginWidth, "fig.png",@skip(2+7)@len(7)Word("caption"),@skip(1)@len(9)Word("copyright"))),  // FIXME no pos for path, @skip
			parse("#FIG#{fig.png}caption@copyright"));
		// TODO other/weird orderings of #FIG# details
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
			expand(VList([
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
			expand(VList([
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
			expand(VList([
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
			expand(VList([
				Paragraph(@len(1)Word("x")),@skip(2)
				List(true,[@wrap(8,1)Paragraph(@len(1)Word("a")),@wrap(8,1)Paragraph(@len(1)Word("b"))]),@skip(2)
				Paragraph(@len(1)Word("y"))
			])),
			parse("x\n\n\\number[a]\\number[b]\n\ny"));

		// lists in items
		// x in x
		Assert.same(
			expand(List(false,[
				@wrap(6,1)VList([
					Paragraph(@len(1)Word("a")),@skip(2)
					List(false,[@wrap(6,0)Paragraph(@len(1)Word("x")),@wrap(6,0)Paragraph(@len(1)Word("y"))])]),
				@wrap(6,1)Paragraph(@len(1)Word("b"))])),
			parse("\\item[a\n\n\\item x\\item y]\\item[b]"));
		Assert.same(
			expand(List(true,[
				@wrap(8,1)VList([
					Paragraph(@len(1)Word("a")),@skip(2)
					List(true,[@wrap(8,0)Paragraph(@len(1)Word("x")),@wrap(8,0)Paragraph(@len(1)Word("y"))])]),
				@wrap(8,1)Paragraph(@len(1)Word("b"))])),
			parse("\\number[a\n\n\\number x\\number y]\\number[b]"));
		// x in !x
		Assert.same(
			expand(List(false,[
				@wrap(6,1)VList([
					Paragraph(@len(1)Word("a")),@skip(2)
					List(true,[@wrap(8,0)Paragraph(@len(1)Word("x")),@wrap(8,0)Paragraph(@len(1)Word("y"))])]),
				@wrap(6,1)Paragraph(@len(1)Word("b"))])),
			parse("\\item[a\n\n\\number x\\number y]\\item[b]"));
		Assert.same(
			expand(List(true,[
				@wrap(8,1)VList([
					Paragraph(@len(1)Word("a")),@skip(2)
					List(false,[@wrap(6,0)Paragraph(@len(1)Word("x")),@wrap(6,0)Paragraph(@len(1)Word("y"))])]),
				@wrap(8,1)Paragraph(@len(1)Word("b"))])),
			parse("\\number[a\n\n\\item x\\item y]\\number[b]"));

		// lists end on breakspaces
		Assert.same(
			expand(VList([
				List(false,[@wrap(6,0)Paragraph(@len(1)Word("a")),@wrap(6,0)Paragraph(@len(1)Word("b"))]),@skip(2)
				List(false,[@wrap(6,0)Paragraph(@len(1)Word("x")),@wrap(6,0)Paragraph(@len(1)Word("y"))])
			])),
			parse("\\item a\\item b\n\n\\item x\\item y"));

		// numerated lists end on !numerated (and the opposite)
		Assert.same(
			expand(VList([
				List(false,[@wrap(6,0)Paragraph(@len(1)Word("a")),@wrap(6,0)Paragraph(@len(1)Word("b"))]),
				List(true,[@wrap(8,0)Paragraph(@len(1)Word("1"))]),
				List(false,[@wrap(6,0)Paragraph(@len(1)Word("x"))])
			])),
			parse("\\item a\\item b\\number 1\\item x"));
		Assert.same(
			expand(VList([
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

		// after argument opening braces
		Assert.same(
			expand(Paragraph(@wrap(6,1)Emphasis(@skip(7)@len(1)Word("a")))),
			parse("\\emph{\\'foo'\\a}"));
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

		parsingError("\\meta\\reset{section}{1}", BadValue);
		parsingError("\\meta\\reset{subsection}{1}", BadValue);
		parsingError("\\meta\\reset{subsubsection}{1}", BadValue);

		parsingError("\\meta\\reset{volume}{a}", BadValue);
		parsingError("\\meta\\reset{volume}{-1}", BadValue);
		parsingError("\\meta\\reset{volume}{1a}", BadValue);  // FIXME

		parsingError("\\meta\\reset{}{1}", BadValue);
		parsingError("\\meta\\reset{volume}{}", BadValue);

		parsingError("\\meta\\reset", MissingArgument, ~/name/);
		parsingError("\\meta\\reset{volume}", MissingArgument, ~/value/);

		parsingError("\\meta");  // FIXME specific error
		parsingError("\\meta\n\n\\reset{volume}{2}");  // FIXME specific error
	}

	public function test_016_break_spaces_in_arguments()
	{
		// Section name must be a hlist, hence to break spaces can happen
		parsingError("\\section{\n\nname}");

		// It's hard to decide whether raw arguments should accept
		// break spaces or not: on one hand, this is closer to what
		// "raw" is expected to mean; on the other, this allows for
		// uggly things like
		//     \meta\reset{
		//
		//                 volume}{0}
		// and this isn't something we want to encorage.
		// Since we still don't use them in places were break spaces
		// would be necessary, let's forbidd them for now.
		parsingError("\\meta\\reset{\n\nvolume}{0}");
	}

	public function test_017_boxes()
	{
		Assert.same(
			expand(@wrap(10,8)Box(@len(1)Word("a"),null)),
			parse("\\beginbox{a}\\endbox"));
		Assert.same(
			expand(@wrap(10,7)Box(@len(1)Word("a"),@skip(1)Paragraph(@len(1)Word("b")))),
			parse("\\beginbox{a}b\\endbox"));
		Assert.same(
			expand(@wrap(10,7)Box(@len(1)Word("a"),@skip(1)VList([Paragraph(@len(1)Word("b")),@skip(2)Paragraph(@len(1)Word("c"))]))),
			parse("\\beginbox{a}b\n\nc\\endbox"));

		parsingError("\\endbox", UnexpectedCommand, ~/\\endbox/);

		parsingError("\\beginbox", MissingArgument, ~/name.+\\beginbox/i, mkPos(9, 9));
		parsingError("\\beginbox a", MissingArgument, ~/name.+\\beginbox/i, mkPos(10, 11));
		parsingError("\\beginbox{a}{}", UnexpectedToken, ~/{/, mkPos(12, 13));

		parsingError("\\beginbox{}", BadValue, ~/name cannot be empty/i, mkPos(10, 10));
	}

	// FIXME
	// public function test_018_controled_nesting_of_vertical_elements()
	// {
	// 	parsingError("\\item[\\section{foo}]");
	// 	parsingError("\\beginbox\\section{foo}\\endbox");
	// 	parsingError("\\item[\\beginbox\\endbox]");
	// }

	// TODO
	// public function test_019_html_metas()
	// {
	// }

	public function test_020_tex_metas()
	{
		// TODO \tex\preamble

		// \tex\export
		Assert.same(expand(@len(17)LaTeXExport("a","b")), parse("\\tex\\export{a}{b}"));
		Assert.same(expand(@len(27)LaTeXExport("a","b")), parse("\\tex\\export{a}{c/d/../../b}"));
		parsingError("\\tex\\export{a}{/home}", BadValue, ~/absolute/);
		parsingError("\\tex\\export{a}{..}", BadValue, ~/escape/);
		parsingError("\\tex\\export{a}{b/../..}", BadValue, ~/escape/);
	}

	public function test_021_include()
	{
		sys.io.File.saveContent("b", "c");
		Assert.same(
			expand(@src("b")Paragraph(@len(1)Word("c"))),
			parse("\\include{b}"));

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

		parsingError("\\endtable", UnexpectedCommand, ~/\\endtable/);
	}

	public function test_023_escapes()
	{
		// automatically inactive; no need to escape
		Assert.same(expand(Paragraph(@len(1)Word(":"))), parse(":"));
		Assert.same(expand(Paragraph(@len(2)Word("::"))), parse("::"));
		Assert.same(expand(Paragraph(@len(4)Word("::::"))), parse("::::"));
		// double check
		Assert.same(expand(Paragraph(HList([@len(2)Word("::"),@len(2)Word(":")]))), parse("::\\:"));
	}
}

