package format.tests;

import format.Document;
import format.tests.MacroHelpers.make;
import utest.Assert;

using StringTools;

class Parsing {
	function parse(s:String):Document
	{
		var p = new Parser();
		return p.parseStream(new haxe.io.StringInput(s));
	}

	public function test_001_empty()
	{
		Assert.same(null, parse(""));
		Assert.same(null, parse("\n\t "));

		Assert.same(null, parse("// comment"));
		Assert.same(null, parse("\n\t // comment\n\t "));
		Assert.same(null, parse("/* comment */"));
		Assert.same(null, parse("\n\t /* comment */\n\t "));

		// Assert.raises(parse.bind("/*"));  // utest exception type fail
	}

	public function test_002_par()
	{
		Assert.same(make(VPar(HText("hello"))), parse("hello"));
		// generates: Assert.same({ expr : VPar({ expr:HText("hello"),pos:{...} }), pos : {...} }, parse("hello"));

		Assert.same(make(VPar(HText("hello"))), parse("hello\n\t "));
		Assert.same(make(VPar(HText("hello"))), parse("\t hello\t "));
		Assert.same(make(VList([ VPar(HText("hello")), @li(3)VPar(HText("world!")) ])), parse("hello\n\nworld!"));

		Assert.same(make(VPar(HList([ HText("hello, "), @li(2)HText("world!") ]))), parse("hello,\nworld!"));
	}

	public function test_003_heading()
	{
		Assert.same(make(VSection(HText("Title"), @li(3)VPar(HText("Hello, world!")), "title")), parse("# Title\n\nHello, world!"));
		Assert.same(make(VSection(HText("Title"), null, "title")), parse("# Title\n\n"));
		// Assert.same(make(VSection(HText("Title"), null, "title")), parse("# Title"));  // FIXME[priority=low]

		Assert.same(make(VSection(HText("Title"), null, "title")), parse("# Title".rpad("\n", 2048)));  // greedy regex bug
	}

	public function test_004_hexpr()
	{
		Assert.same(make(VPar(HEmph(HText("hello")))), parse("*hello*"));
		Assert.same(make(VPar(HEmph(HText("hello")))), parse("**hello**"));
		Assert.same(make(VPar(HList([ HText("hello, "), HEmph(HText("world")), HText("!") ]))), parse("hello, *world*!"));
		Assert.same(make(VPar(HList([ HText("hello, "), HEmph(HText("world")), HText("!") ]))), parse("hello, **world**!"));
		Assert.same(make(VPar(HList([ HText("hello, wall"), HEmph(HText("-e")), HText("!") ]))), parse("hello, wall*-e*!"));
		Assert.same(make(VPar(HList([ HText("hello, wall"), HEmph(HText("-e")), HText("!") ]))), parse("hello, wall**-e**!"));
		// Assert.same(make(VPar(HEmph(HList([ HText("hello, "), HEmph(HText("world")), HText("!") ])))), parse("*hello, **world**!*"));
		// Assert.same(make(VPar(HEmph(HList([ HText("hello, "), HEmph(HText("world")), HText("!") ])))), parse("**hello, *world*!**"));

		// Assert.same(make(VPar(HList([ HText("hello, "), HHighlight(HText("world")), HText("!") ]))), parse("hello, \\highlight{world}!"));

		Assert.same(make(VPar(HList([ HText("hello, "), HCode("world"), HText("!") ]))), parse("hello, `world`!"));

		// prevent spontaneous par break if what's left starts with \n
		// Assert.same(make(VPar(HList([ HCode("hello, "), @ln(2)HText("world!") ]))), parse("`hello, `\nworld!"));  // FIXME
		// Assert.same(make(VPar(HList([ HEmph(HText("hello, ")), @ln(2)HText("world!") ]))), parse("*hello, *\nworld!"));  // FIXME
	}

	public function test_005_comment()
	{
		Assert.same(make(VPar(HText("hello, world!") )), parse("hello, /* comment */world!"));
		Assert.same(make(VPar(HEmph(HText("hello")))), parse("*hello// comment\n*"));
		Assert.same(make(VPar(HEmph(HText("hello")))), parse("**hello/* comment */**"));
	}

	// public function test_005_escaped()
	// {
	// 	Assert.same(make(VPar(HText("\\"))), parse("\\\\"));
	// 	Assert.same(make(VPar(HText("/"))), parse("\\/"));
	// 	Assert.same(make(VPar(HText("//"))), parse("\\//"));
	// 	Assert.same(make(VPar(HText("//"))), parse("/\\/"));
	// 	Assert.same(make(VPar(HText("#"))), parse("\\#"));
	// 	Assert.same(make(VPar(HText("`"))), parse("\\`"));
	// 	Assert.same(make(VPar(HText("*"))), parse("\\*"));
	// }

	public function new() {}
}

