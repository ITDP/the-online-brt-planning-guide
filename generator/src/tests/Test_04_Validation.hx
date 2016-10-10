package tests;

import haxe.PosInfos;
import transform.ValidationError;
import utest.Assert;

import Assertion.*;

using Literals;

class Test_04_Validation {
	static inline var SRC = "Test_04_Validation.hx";

	function validate(str:String, cback:Null<Array<ValidationError>>->Void)
	{
		var l = new parser.Lexer(haxe.io.Bytes.ofString(str), SRC);
		var ast = new parser.Parser(SRC, l).file();
		var doc = transform.NewTransform.transform(ast);
		transform.Validator.validate(doc, cback);
	}

	function passes(str:String, ?timeout:Null<Int>, ?pos:PosInfos)
	{
		var done = Assert.createAsync();
		validate(str, function (errors) {
			Assert.isNull(errors, pos);
			done();
		});
	}

	function fails(str, fatal, ?msgPat, ?timeout:Null<Int>, ?pos:PosInfos)
	{
		var done = Assert.createAsync(timeout);
		validate(str, function (errors) {
			Assert.notNull(errors, pos);
			Assert.equals(1, errors.length, pos);
			var err = errors[0];
			Assert.equals(err.fatal, fatal, pos);
			if (msgPat != null) Assert.match(msgPat, err.msg, pos);
			done();
		});
	}

	public function test_002_math()
	{
		// mathjax needs a timeout longer than utest's 250 ms default
		var timeout = 1000;

		// this is rossmos's formula, missing the definitions for \\phi_{ij};
		// fun fact, it can be applied to certain transportation data
		passes("$$p_{i,j} = k \\sum_{n=1}^{(\\mathrm{total\\;points})} \\left [
				\\underbrace{
					\\frac{\\phi_{ij}}{
						(|X_i-x_n| + |Y_j-y_n|)^f
					}
				}_{ 1^{\\mathrm{st}}\\mathrm{\\;term} }
				+
				\\underbrace{
					\\frac{(1-\\phi_{ij})(B^{g-f})}{
						(2B - \\mid X_i - x_n \\mid - \\mid Y_j-y_n \\mid)^g
					}
				}_{ 2^{\\mathrm{nd}}\\mathrm{\\;term} }
				\\right]$$".doctrim(), timeout);

		passes("$$a\\ne b$$", timeout);
		passes("$$a_{ij}$$", timeout);

#if nodejs
		fails("$$a\\neb$$", true, ~/bad math/i, timeout);
		fails("$$a_{ij$$", true, ~/bad math/i, timeout);
#elseif js
#error "no JS platforms expected other than Node.js"
#end
	}

	public function test_003_src_paths()
	{
		function saveContent(base, content)
		{
			var path = haxe.io.Path.join([Const.UNIT_TEMP_DIR, base]);
			sys.FileSystem.createDirectory(haxe.io.Path.directory(path));
			sys.io.File.saveContent(path, content);
			return path;
		}

		function openDir(base)
		{
			var path = haxe.io.Path.join([Const.UNIT_TEMP_DIR, base]);
			sys.FileSystem.createDirectory(path);
			return path;
		}

		var file = saveContent("testfile.txt", "hello");
		var dir = openDir("testdir");
		var css = saveContent("testcss.css", "body { width: 600px; }");
		var tex = saveContent("testtex.tex", "\\documentclass{minimal}\\begin{document}\\end{document}");
		var jpeg = saveContent("testjpeg.jpeg", "todo");
		var jpg = saveContent("testjpeg.jpg", "todo");
		var png = saveContent("testpng.png", "todo");

		passes('\\tex\\export{$file}{nothing}');
		passes('\\tex\\export{$dir}{nothing}');
		passes('\\html\\apply{$css}');
		passes('\\tex\\preamble{$tex}');
		passes('\\figure{$jpeg}{foo}{bar}');
		passes('\\figure{$jpg}{foo}{bar}');
		passes('\\figure{$png}{foo}{bar}');
		passes('\\begintable{foo}\\useimage{$jpeg}\\endtable');
		passes('\\begintable{foo}\\useimage{$jpg}\\endtable');
		passes('\\begintable{foo}\\useimage{$png}\\endtable');

		fails('\\tex\\export{$file.noexists}{nothing}', true, ~/file not found/i);
		fails('\\tex\\export{$dir.noexists}{nothing}', true, ~/file not found/i);
		fails('\\html\\apply{$png}', true, ~/file does not match expected types/i);
		fails('\\tex\\preamble{$dir}', true, ~/expected file, not directory/i);
		fails('\\figure{$css}{foo}{bar}', true, ~/file does not match expected types/i);
		fails('\\begintable{foo}\\useimage{$tex}\\endtable', true, ~/file does not match expected types/i);
	}

	public function new() {}
}

