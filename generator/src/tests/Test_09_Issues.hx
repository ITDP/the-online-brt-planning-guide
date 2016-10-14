package tests;

import haxe.io.Bytes;
import html.Generator in HtmlGen;
import parser.Ast;
import parser.Lexer;
import parser.Parser;
import tex.Generator in TexGen;
import transform.Context;
import transform.NewDocument;
import transform.NewTransform;
import utest.Assert;

import Assertion.*;
import parser.AstTools.*;

class Test_09_Issues {
	static inline var SRC = "Test_09_Issues.hx";

	function parse(str:String)
	{
		var l = new Lexer(Bytes.ofString(str), SRC);
		return new Parser(SRC, l).file();
	}

	function transform(ast:Ast)
	{
		return NewTransform.transform(ast);
	}

	// function generate(dast:NewDocument, htmlDir:String, texDir:String)
	// {
	// 	new HtmlGen(htmlDir).writeDocument(dast);
	// 	new TexGen(texDir).writeDocument(dast);
	// }

	public function test_issue_0001()
	{
		var a = parse("\\subsection{a}\\subsection{b}");
		var b = transform(a);
		// generate(b);  // TODO
		Assert.pass();
	}

	public function test_issue_0008()
	{
		var g = new TexGen("/a/b/c/d");
		Assert.equals("\\}\\}", g.gent("}}"));
	}

	public function test_possible_issue_with_unexpected_hashes()
	{
		Assert.raises(parse.bind("a#b"));
		Assert.raises(parse.bind("a # b"));
	}

	public function test_issue_43()
	{
		Assert.raises(parse.bind("a@b"));
	}

	public function test_issue_44()
	{
		parse("\\item [a\n\nb]");
		Assert.pass();
	}

	public function new() {}
}

