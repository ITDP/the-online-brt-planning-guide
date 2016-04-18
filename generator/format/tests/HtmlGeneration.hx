package format.tests;

import format.Document;
import haxe.PosInfos;
import utest.Assert;

import format.tests.MacroHelpers.make;

class HtmlGeneration {
	@:access(format.HtmlGenerator.generateHorizontal)
	function genH(expr:Expr<HDef>)
		new HtmlGenerator().generateHorizontal(expr);

	@:access(format.HtmlGenerator.generateVertical)
	function genV(expr:Expr<VDef>)
		new HtmlGenerator().generateVertical(expr);

	function genDoc(doc:Document)
	{
		var buf = new StringBuf();
		var gen = new HtmlGenerator({ saveContent : function (p, c) buf.add(c) });
		gen.generateDocument(doc);
		return buf.toString();
	}

	public function test_001_empty()
	{
		Assert.equals("", genDoc(make(null)));
	}

	public function new() {}
}

