package tests;

import haxe.io.Bytes;
import parser.Lexer;
import parser.Parser;
import transform.Context;
import transform.NewDocument;
import transform.NewTransform;
import utest.Assert;

import Assertion.*;
import parser.AstTools.*;
import transform.NewTransform.transform;

class Test_05_Transform {
	static inline var SRC = "Test_05_Transform.hx";

	public function new() {}

	function parse(str : String)
	{
		var l = new Lexer(Bytes.ofString(str), SRC);
		var p = new Parser(SRC, l).file();
		return transform(p);
	}

	public function test_001_transform_context_internals()
	{
		var id = new IdCtx();
		Assert.equals("", id.volume);

		id.volume = "vl1";
		Assert.equals("vl1", id.volume);
		id.chapter = "ch1";
		Assert.equals("ch1", id.chapter);
		id.section = "se1";
		Assert.equals("se1", id.section);
		id.subSection = "sse1";
		Assert.equals("sse1", id.subSection);
		id.subSubSection = "ssse1";
		Assert.equals("ssse1", id.subSubSection);

		id.subSection = "sse2";
		Assert.equals("sse2", id.subSection);
		Assert.equals("", id.subSubSection);
		id.subSubSection = "ssse1"; id.subSection = "sse2"; id.section = "se2";
		Assert.equals("se2", id.section);
		Assert.equals("", id.subSection);
		Assert.equals("", id.subSubSection);
		id.subSubSection = "ssse1"; id.subSection = "sse2"; id.section = "se2"; id.chapter = "ch2";
		Assert.equals("ch2", id.chapter);
		Assert.equals("", id.section);
		Assert.equals("", id.subSection);
		Assert.equals("", id.subSubSection);
		id.subSubSection = "ssse1"; id.subSection = "sse2"; id.section = "se2"; id.chapter = "ch2"; id.volume = "vl2";
		Assert.equals("vl2", id.volume);
		Assert.equals("", id.chapter);
		Assert.equals("", id.section);
		Assert.equals("", id.subSection);
		Assert.equals("", id.subSubSection);

		var no = new NoCtx();
		Assert.equals(0, no.volume);
		Assert.equals(0, no.lastChapter);

		no.volume = 1;
		Assert.equals(1, no.volume);
		no.chapter = 1;
		Assert.equals(1, no.chapter);
		no.section = 1;
		Assert.equals(1, no.section);
		no.subSection = 1;
		Assert.equals(1, no.subSection);
		no.subSubSection = 1;
		Assert.equals(1, no.subSubSection);

		no.subSection = 2;
		Assert.equals(2, no.subSection);
		Assert.equals(0, no.subSubSection);
		no.subSubSection = 2; no.subSection = 2; no.section = 2;
		Assert.equals(2, no.section);
		Assert.equals(0, no.subSection);
		Assert.equals(0, no.subSubSection);
		no.subSubSection = 2; no.subSection = 2; no.section = 2; no.chapter = 2;
		Assert.equals(2, no.chapter);
		Assert.equals(2, no.lastChapter);
		Assert.equals(0, no.section);
		Assert.equals(0, no.subSection);
		Assert.equals(0, no.subSubSection);
		no.subSubSection = 2; no.subSection = 2; no.section = 2; no.chapter = 2; no.volume = 2;
		Assert.equals(2, no.volume);
		Assert.equals(0, no.chapter);
		Assert.equals(2, no.lastChapter);
		Assert.equals(0, no.section);
		Assert.equals(0, no.subSection);
		Assert.equals(0, no.subSubSection);
		no.chapter = no.lastChapter + 1;
		Assert.equals(3, no.chapter);
		Assert.equals(3, no.lastChapter);
		no.chapter = no.lastChapter + 1;
		Assert.equals(4, no.chapter);
		Assert.equals(4, no.lastChapter);

		// allow lastChapter to manually reset
		no.chapter = 0;
		Assert.equals(0, no.chapter);
		Assert.equals(0, no.lastChapter);
	}
}

