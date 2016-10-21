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

	function passes(str:String, ?timeout:Null<Int>, ?assertPos:PosInfos)
	{
		var done = Assert.createAsync();
		validate(str, function (errors) {
			Assert.isNull(errors, assertPos);
			done();
		});
	}

	function fails(str, fatal, ?cl:Class<ValidationError>, ?pattern, ?timeout:Null<Int>, ?assertPos:PosInfos)
	{
		var done = Assert.createAsync(timeout);
		validate(str, function (errors) {
			Assert.notNull(errors, assertPos);
			if (errors != null) {
				assert(errors.length == 1);
				var err = errors[0];
				Assert.equals(err.fatal, fatal, assertPos);
				if (cl != null)
					Assert.equals(Type.getClassName(cl), Type.getClassName(Type.getClass(err)));
				if (pattern != null)
					Assert.match(pattern, err.toString(), assertPos);
			}
			done();
		});
	}

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

	public function test_002_math()
	{
		// mathjax needs a timeout longer than utest's 250 ms default
		// initializaion and queueing are yet to explain this
		var timeout = 10000;

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
		fails("$$a\\neb$$", true, BadMath, timeout);
		fails("$$a_{ij$$", true, BadMath, timeout);
#elseif js
#error "no JS platforms expected other than Node.js"
#end
	}

	public function test_003_src_paths()
	{
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

		fails('\\tex\\export{$file.noexists}{nothing}', true, FileNotFound, ~/file not found/i);
		fails('\\tex\\export{$dir.noexists}{nothing}', true, FileNotFound);
		fails('\\tex\\preamble{$dir}', true, FileIsDirectory, ~/expected file, not directory/i);
		fails('\\html\\apply{$png}', true, WrongFileType, ~/file does not match expected types/i);
		fails('\\figure{$css}{foo}{bar}', true, WrongFileType);
		fails('\\begintable{foo}\\useimage{$tex}\\endtable', true, WrongFileType);

		fails('\\tex\\export{$jpg}{/home}', true, AbsolutePath, ~/path cannot be absolute/i);
		fails('\\tex\\export{$png}{..}', true, EscapingPath, ~/path cannot escape/);
		fails('\\tex\\export{$tex}{b/../..}', true, EscapingPath, ~/path cannot escape/);
	}

	public function test_004_empty_arguments()
	{
		var png = saveContent("testpng.png", "todo");

		fails("\\volume{}", true, BlankValue, ~/name cannot be blank/i);
		fails("\\chapter{}", true, BlankValue);
		fails("\\section{}", true, BlankValue);
		fails("# ", true, BlankValue);
		fails("\\subsection{}", true, BlankValue);
		fails("## ", true, BlankValue);
		fails("\\subsubsection{}", true, BlankValue);
		fails("### ", true, BlankValue);
		fails("\\beginbox{}\\endbox", true, BlankValue);
		fails("\\begintable{}\\header\\col a\\col b\\row\\col 1\\col b\\endtable", true, BlankValue, ~/caption cannot be blank/i);
		fails('\\begintable{}\\useimage{$png}\\endtable', true, BlankValue, ~/caption cannot be blank/i);
		fails('\\figure{$png}{}{copyright}', true, BlankValue, ~/caption cannot be blank/i);
		fails('\\figure{$png}{caption}{}', true, BlankValue, ~/copyright cannot be blank/i);
		fails("\\quotation{a}{}", true, BlankValue, ~/author cannot be blank/i);
		fails("\\quotation{}{b}", true, BlankValue, ~/text cannot be blank/i);
		fails(">a@\n\nb", true, BlankValue, ~/author cannot be blank/i);
		fails(">@a\n\nb", true, BlankValue, ~/text cannot be blank/i);

		// TODO test empty path errors
	}

	public function new() {}
}

