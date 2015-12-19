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

		Assert.raises(parse.bind("/*"));
	}

	public function test_002_par()
	{
		Assert.same(make(VPar(HText("hello"))), parse("hello"));
		Assert.same(make(VPar(HText("hello"))), parse("hello\n\t "));
		Assert.same(make(VPar(HText("hello"))), parse("\t hello\t "));
		Assert.same(make(VList([ VPar(HText("hello")), @li(3)VPar(HText("world!")) ])), parse("hello\n\nworld!"));

		Assert.same(make(VPar(HList([ HText("hello, "), @li(2)HText("world!") ]))), parse("hello,\nworld!"));
	}

	public function test_003_heading()
	{
		Assert.same(make(VSection(HText("Title"), @li(3)VPar(HText("Hello, world!")), "title")), parse("# Title\n\nHello, world!"));
		Assert.same(make(VSection(HText("Title"), null, "title")), parse("# Title\n\n"));
		// Assert.same(make(VSection(HText("Title"), null, "title")), parse("# Title"));  // FIXME

		Assert.same(make(VSection(HText("Title"), null, "title")), parse("# Title".rpad("\n", 2048)));  // greedy regex bug
	}

	public function new() {}
}

