package format.tests;

import format.Document;
import haxe.PosInfos;
import utest.Assert;

import format.tests.MacroHelpers.*;

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

	public function test_000_garbage()
	{
		// beware, these are pseudo expressions that are made into real
		// ones by the `make` macro
		trace(genDoc(make(VList([
			VPar(HList([
				HText("Hello, "),
				HEmph(HText("World")),
				HText("! My name is "),
				HHighlight(HList([
					HText("BRT."),
					HText("Robrt")
				])),
				HText(".")
			])),
			VSection(HText("A chapter title"), VList([
				VPar(HText("lalala")),
				VSection(HText("A section title"), VList([
					VPar(HText("lalala")),
					VSection(HText("A subsection title"), VList([
						VPar(HText("lalala"))
					]), "sub-section-label") 
				]), "section-label")
			]), "chapter-label")
		]))));
		Assert.isTrue(true);
	}

	public function test_001_empty()
	{
		Assert.equals("", genDoc(make(null)));
	}

	public function new() {}
}

