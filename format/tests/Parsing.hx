package format.tests;

import format.Document;
import utest.Assert;

import format.tests.MacroHelpers.make;

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

		Assert.same(make(VPar( HList([HText("hello, "), @li(2)HText("world!")]) )), parse("hello,\nworld!"));
	}

	public function new() {}
}

