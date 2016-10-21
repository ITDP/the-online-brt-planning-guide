package tests;

import haxe.PosInfos;
import transform.ValidationError;
import transform.Validator;
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

	function fails(str, fatal, ?val:ValidationErrorValue, ?pattern, ?timeout:Null<Int>, ?pos:PosInfos)
	{
		var done = Assert.createAsync(timeout);
		validate(str, function (errors) {
			Assert.notNull(errors, pos);
			if (errors != null) {
				assert(errors.length == 1);
				var err = errors[0];
				Assert.equals(err.fatal, fatal, pos);
				if (val != null)
					Assert.same(val, err.err, pos);
				if (pattern != null)
					Assert.match(pattern, err.toString(), pos);
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
		fails("$$a\\neb$$", true, BadMath("a\\neb"), timeout);
		fails("$$a_{ij$$", true, BadMath("a_{ij"), timeout);
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

		fails('\\tex\\export{$file.noexists}{nothing}', true, FileNotFound('$file.noexists'), ~/file not found or not accessible/i);
		fails('\\tex\\export{$dir.noexists}{nothing}', true, FileNotFound('$dir.noexists'));
		fails('\\tex\\preamble{$dir}', true, FileIsDirectory(dir), ~/expected file, not directory/i);
		fails('\\html\\apply{$png}', true, WrongFileType([Css], png), ~/file does not match expected types.+expected.+css/i);
		fails('\\figure{$css}{foo}{bar}', true, WrongFileType([Jpeg, Png], css));
		fails('\\begintable{foo}\\useimage{$tex}\\endtable', true, WrongFileType([Jpeg, Png], tex));

		fails('\\tex\\export{$jpg}{/home}', true, AbsolutePath("/home"), ~/path cannot be absolute/i);
		fails('\\tex\\export{$png}{..}', true, EscapingPath("the destination directory", ".."), ~/path cannot escape the destination directory/i);
		fails('\\tex\\export{$tex}{b/../..}', true, EscapingPath("the destination directory", ".."));  // FIXME show original path
	}

	public function test_004_empty_arguments()
	{
		var png = saveContent("testpng.png", "todo");

		// empty arguments
		fails("\\volume{}", true, BlankValue("volume", "name"));
		fails("\\chapter{}", true, BlankValue("chapter", "name"));
		fails("\\section{}", true, BlankValue("section", "name"));
		fails("# ", true, BlankValue("section", "name"));
		fails("\\subsection{}", true, BlankValue("sub-section", "name"));
		fails("## ", true, BlankValue("sub-section", "name"));
		fails("\\subsubsection{}", true, BlankValue("sub-sub-section", "name"));
		fails("### ", true, BlankValue("sub-sub-section", "name"));
		fails("\\beginbox{}\\endbox", true, BlankValue("box", "name"));
		fails("\\begintable{}\\header\\col a\\col b\\row\\col 1\\col b\\endtable", true, BlankValue("table", "caption"));
		fails('\\begintable{}\\useimage{$png}\\endtable', true, BlankValue("table", "caption"));
		fails('\\figure{$png}{}{copyright}', true, BlankValue("figure", "caption"));
		fails('\\figure{$png}{caption}{}', true, BlankValue("figure", "copyright"));
		fails("\\quotation{a}{}", true, BlankValue("quotation", "author"));
		fails("\\quotation{}{b}", true, BlankValue("quotation", "text"));
		fails(">a@\n\nb", true, BlankValue("quotation", "author"));
		fails(">@a\n\nb", true, BlankValue("quotation", "text"));

		// TODO test empty path errors

		// error text
		fails("\\subsubsection{}", true, BlankValue("sub-sub-section", "name"), ~/sub-sub-section name cannot be blank/i);
	}

	public function new() {}
}

