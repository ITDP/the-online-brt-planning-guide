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
		var p = new parser.Parser(l);
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
			expand(VList([Paragraph(@len(1)Word("a")),List([@wrap(6,0)Paragraph(@len(1)Word("b"))])])),
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

		Assert.same(
			expand(Paragraph(HList([@len(2)Emphasis(null),@len(1)Word("a"),@len(2)Emphasis(null)]))),
			parse("**a**"));  // TODO generate some warning on empty emphasis (maybe later than the parser)
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

	public function test_005_bad_command_name()
	{
		// typos
		parsingError("\\emp", UnknownCommand, ~/\\emp/, mkPos(0,4));
		parsingError("\\highligth", UnknownCommand);

		// non existant aliases
		parsingError("\\emphasis", UnknownCommand);
		parsingError("\\display", UnknownCommand);
		parsingError("\\quote", UnknownCommand);
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

		Assert.same(
			expand(null),
			parse("/* foo */"));
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
		// TODO maybe require hashes on the beginning of the line?
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
		parsingError(">a\n\nb");  // TODO add MissingPart exception

		parsingError("\\quotation{a}{}", BadValue, ~/author cannot be empty/i, mkPos(14,14));
		parsingError("\\quotation{}{b}", BadValue, ~/text cannot be empty/i, mkPos(11, 11));
		parsingError(">a@\n\nb", BadValue, ~/author cannot be empty/i, mkPos(3, 3));
		parsingError(">@a\n\nb", BadValue, ~/text cannot be empty/i, mkPos(1, 1));
	}

	public function test_012_figures()
	{
		Assert.same(
			expand(@wrap(8,1)Figure("fig.png",@skip(2+7)@len(7)Word("caption"),@skip(2)@len(9)Word("copyright"))),  // FIXME no pos for path, @skip
			parse("\\figure{fig.png}{caption}{copyright}"));

		Assert.same(
			expand(@wrap(5,0)Figure("fig.png",@skip(2+7)@len(7)Word("caption"),@skip(1)@len(9)Word("copyright"))),  // FIXME no pos for path, @skip
			parse("#FIG#{fig.png}caption@copyright"));
		// TODO other/weird orderings of #FIG# details
	}

	public function test_013_lists()
	{
		// simple lists
		Assert.same(
			expand(List([@wrap(6,0)Paragraph(@len(1)Word("a"))])),
			parse("\\item a"));
		Assert.same(
			expand(List([@wrap(6,0)Paragraph(@len(1)Word("a")),@wrap(6,0)Paragraph(@len(1)Word("b"))])),
			parse("\\item a\\item b"));
		Assert.same(
			expand(VList([
				Paragraph(@len(1)Word("x")),@skip(2)
				List([@wrap(6,0)Paragraph(@len(1)Word("a")),@wrap(6,0)Paragraph(@len(1)Word("b"))]),@skip(2)
				Paragraph(@len(1)Word("y"))
			])),
			parse("x\n\n\\item a\\item b\n\ny"));

		// vertical lists in items
		Assert.same(
			expand(List([@wrap(6,1)Paragraph(@len(1)Word("a"))])),
			parse("\\item[a]"));
		Assert.same(
			expand(List([@wrap(6,1)Paragraph(@len(1)Word("a")),@wrap(6,1)Paragraph(@len(1)Word("b"))])),
			parse("\\item[a]\\item[b]"));
		Assert.same(
			expand(VList([
				Paragraph(@len(1)Word("x")),@skip(2)
				List([@wrap(6,1)Paragraph(@len(1)Word("a")),@wrap(6,1)Paragraph(@len(1)Word("b"))]),@skip(2)
				Paragraph(@len(1)Word("y"))
			])),
			parse("x\n\n\\item[a]\\item[b]\n\ny"));
		Assert.same(
			expand(List([
				@wrap(6,1)VList([
					Paragraph(@len(1)Word("a")),@skip(2)
					List([@wrap(6,0)Paragraph(@len(1)Word("x")),@wrap(6,0)Paragraph(@len(1)Word("y"))])]),
				@wrap(6,1)Paragraph(@len(1)Word("b"))])),
			parse("\\item[a\n\n\\item x\\item y]\\item[b]"));

		// TODO more tests
		// TODO more error tests
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
			expand(Paragraph(@wrap(6,1)Emphasis(@skip(6)@len(1)Word("a")))),
			parse("\\emph//foo\n{a}"));
		Assert.same(
			expand(Paragraph(@wrap(6,1)Emphasis(@skip(7)@len(1)Word("a")))),
			parse("\\emph/*foo*/{a}"));

		// after argument opening braces
		Assert.same(
			expand(Paragraph(@wrap(6,1)Emphasis(@skip(5)HList([@len(1)Wordspace,@len(1)Word("a")])))),
			parse("\\emph{//foo\na}"));  // the HList is needed so that `a//b\nc` doesn't become `ac`
		Assert.same(
			expand(Paragraph(@wrap(6,1)Emphasis(@skip(7)@len(1)Word("a")))),
			parse("\\emph{/*foo*/a}"));
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
			parse("\\meta/*a*/\\reset{volume}{2}"));

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
}

