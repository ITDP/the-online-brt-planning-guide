package format.tests;

import format.Document;
import haxe.PosInfos;
import utest.Assert;

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

	function mk<Def>(expr:Def, ?pos:Pos)
	{
		if (pos == null)
			pos = { fileName : "answer", lineNumber : 42 };
		return { expr : expr, pos : pos };
	}

	public function test_000_garbage()
	{
		trace(genDoc([
			mk(VPar([
				mk(HText("Hello, ")),
				mk(HEmph([
					mk(HText("World"))
				])),
				mk(HText("!  My name is ")),
				mk(HHighlight([
					mk(HText("BRT.")),
					mk(HText("Robrt"))
				])),
				mk(HText("."))
			])),
			mk(VSection("chapter", [ mk(HText("A chapter")) ], [
				mk(VPar([ mk(HText("lalala")) ])),
				mk(VSection("section", [ mk(HText("A section")) ], [
					mk(VPar([ mk(HText("lalala")) ])),
					mk(VSection("sub-section", [ mk(HText("A subsection")) ], [
						mk(VPar([ mk(HText("lalala")) ])),
					]))
				]))
			]))
		]));
	}

	public function test_001_empty()
	{
		Assert.equals("", genDoc([]));
	}

	public function new() {}
}

