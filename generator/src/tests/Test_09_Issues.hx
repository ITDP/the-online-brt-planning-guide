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
	var h = new AssetHasher();

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
		var g = new TexGen(h, "/a/b/c/d");
		Assert.equals("\\}\\}", g.gent("}}"));
	}

	public function test_possible_issue_with_unexpected_hashes()
	{
		parse("a#b");
		parse("a # b");
		Assert.pass();
	}

	public function test_issue_0043()
	{
		parse("a@b");
		Assert.pass();
	}

	public function test_issue_0044()
	{
		parse("\\item [a\n\nb]");
		Assert.pass();
	}

	public function test_issue_0186()
	{
		var exp = transform(expand(
				VElemList([
					Chapter(Word("cte")),
					VElemList([
						Section(Word("foo")),
						SubSection(Word("bar"))
					])
				])));
		var got = transform(expand(
				VElemList([
					Chapter(Word("cte")),
					VElemList([
						Section(Word("foo"))
					]),
					VElemList([
						SubSection(Word("bar"))
					])
				])));
		Assert.same(exp, got);
	}

	public function test_internal_0001()
		Assert.raises(parse.bind("\\beginbox{foo}\\section{bar}\\endbox"));

	public function test_internal_0002()
	{
		var g = new HtmlGen(h, "/a/b/c/d", false);
		Assert.equals("<a class=\"url\" href=\"http://foo/bar\">http://foo/bar</a>",
				@:privateAccess g.genh(expand(Url("http://foo/bar"))));
	}

	public function new() {}
}

