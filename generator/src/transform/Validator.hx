package transform;

import haxe.io.Path;
import sys.FileSystem;
import transform.NewDocument;
import transform.ValidationError;

import Assertion.*;
using PositionTools;
using StringTools;

@:enum abstract FileType(String) to String {
	public var Directory = "Directory";
	public var File = "Generic file";
	public var Jpeg = "JPEG/JPG image file";
	public var Png = "PNG image file";
	public var Gif = "GIF image file";
	public var Ico = "ICO icon file";
	public var Js = "Javascript source file";
	public var Css = "Cascading style sheet (CSS) file";
	public var Tex = "TeX source file";
	public var Manu = "Manuscript Markup Language";  // TODO use the 'manu' name

	public function validExtensions()
		return switch this {
		case Jpeg: ["jpeg", "jpg"];
		case Png: ["png"];
		case Ico: ["ico"];
		case Js: ["js"];
		case Css: ["css"];
		case Tex: ["tex"];
		case Manu: ["manu", "src", "txt"];
		case Directory|File|_: [];
		}
}

class Validator {
	var errors:Array<ValidationError> = [];
	var wait = 0;
	var final = false;
	var cback:Null<Array<ValidationError>>->Void;

	function push(e:Null<ValidationError>)
	{
		if (e == null) return;
		errors.push(e);
	}

	function tick()
	{
		if (final && wait == 0)
			cback(errors.length > 0 ? errors : null);
	}

#if nodejs
	/*
	Initialize and configure MathJax, but only once.
	*/
	dynamic function initMathJax()
	{
		mathjax.Single.config({
			displayMessages : false,
			displayErrors : false,
			undefinedCharError : true
		});
		this.initMathJax = function () {};
	}

	/*
	Validate TeX math.
	*/
	function validateMath(tex:String, pos:Position)
	{
		if (Context.noMathValidation) return;

		wait++;
		initMathJax();
		mathjax.Single.typeset({
			math:tex,
			format:mathjax.Single.SingleTypesetFormat.TEX,
			mml:true
		}, function (res) {
			if (res.errors != null)
				errors.push(new ValidationError(pos, BadMath(tex, res.errors)));
			wait--;
			tick();
		});
	}
#else
	/*
	Skip TeX math validation unavailable in this platform.
	*/
	static dynamic function validateMath(tex:String, pos:Position)
	{
		show("WARNING will skip all math validation, no tex implementation available");
		validateMath = function (t, p) {};
	}
#end

	public static function validateSrcPath(path:PElem, types:Array<FileType>)
	{
		var computed = path.toInputPath();
		var exists = FileSystem.exists(computed);
		if (!exists)
			return new ValidationError(path.pos, FileNotFound(computed));
		var isDirectory = FileSystem.isDirectory(computed);
		var ext = Path.extension(computed);
		for (t in types) {
			switch [isDirectory, t, Lambda.has(t.validExtensions(), ext.toLowerCase())] {
			case [true, Directory, _]:
			case [false, File, _]:
			case [false, Jpeg, true]:
			case [false, Png, true]:
			case [false, Js, true]:
			case [false, Css, true]:
			case [false, Tex, true]:
			case [false, Manu, true]:
			case _:
				// keep going; skip the following `return null`
				continue;
			}
			return null;
		}
		if (isDirectory)
			return new ValidationError(path.pos, FileIsDirectory(computed));
		else
			return new ValidationError(path.pos, WrongFileType(types, computed));
	}

	/*
	Validate horizontal elements.

	Performs possible checks on the fly, and queues the rest.
	*/
	function hiter(h:HElem)
	{
		switch h.def {
		case Math(tex):
			validateMath(tex, h.pos);
		case Superscript(i), Subscript(i), Emphasis(i), Highlight(i):
			hiter(i);
		case HElemList(li):
			for (i in li)
				hiter(i);
		case Wordspace, Word(_), InlineCode(_), Url(_), HEmpty:
			// nothing to do
		}
	}

	function elemDesc(d:DElem)
	{
		return switch d.def {
		case DVolume(_): "volume";
		case DChapter(_): "chapter";
		case DSection(_): "section";
		case DSubSection(_): "sub-section";
		case DSubSubSection(_): "sub-sub-section";
		case DBox(_): "box";
		case DTitle(_): "title";
		case DList(_): "list";
		case DTable(_), DImgTable(_): "table";
		case DFigure(_): "figure";
		case DQuotation(_): "quotation";
		case DParagraph(_): "paragraph";
		case DCodeBlock(_): "code block";
		case DEmpty: "[nothing]";
		case DElemList(_): "[list of elements]";
		case DLaTeXPreamble(_): "LaTeX preamble configuration";
		case DLaTeXExport(_): "LaTeX export call";
		case DHtmlStore(_): "Asset inclusion";
		case DHtmlToHead(_): "Append to <head>";
		}
	}
	
	function notHEmpty(h:HElem, parent:DElem, name:String)
	{
		if (h.def.match(HEmpty)) {
			errors.push(new ValidationError(h.pos, BlankValue(elemDesc(parent), name)));
			return false;
		}
		return true;
	}

	/*
	Validate document elements.

	Performs possible checks on the fly, and queues the rest.
	*/
	function diter(d:DElem)
	{
		switch d.def {
		case DVolume(_, name, children), DChapter(_, name, children), DSection(_, name, children), DSubSection(_, name, children), DSubSubSection(_, name, children), DBox(_, name, children):
			if (notHEmpty(name, d, "name"))
				hiter(name);
			diter(children);
		case DTitle(name):
			if (notHEmpty(name, d, "name"))
				hiter(name);
		case DElemList(items), DList(_, items):
			for (i in items)
				diter(i);
		case DTable(_, _, caption, header, rows):
			if (notHEmpty(caption, d, "caption"))
				hiter(caption);
			for (c in header)
				diter(c);
			for (columns in rows) {
				for (c in columns)
					diter(c);
			}
		case DFigure(_, _, path, caption, copyright):
			push(validateSrcPath(path, [Jpeg, Png]));
			if (notHEmpty(caption, d, "caption"))
				hiter(caption);
			if (notHEmpty(copyright, d, "copyright"))
				hiter(copyright);
		case DImgTable(_, _, caption, path):
			if (notHEmpty(caption, d, "caption"))
				hiter(caption);
			push(validateSrcPath(path, [Jpeg, Png]));
		case DQuotation(text, by):
			if (notHEmpty(text, d, "text"))
				hiter(text);
			if (notHEmpty(by, d, "author"))
				hiter(by);
		case DParagraph(text):
			hiter(text);
		case DLaTeXPreamble(path):
			push(validateSrcPath(path, [Tex]));
		case DLaTeXExport(src, _.internal() => dest):
			push(validateSrcPath(src, [Directory, File]));
			if (Path.isAbsolute(dest))
				errors.push(new ValidationError(d.pos, AbsoluteOutputPath(dest)));
			var ndest = Path.normalize(dest);
			if (ndest.startsWith(".."))
				errors.push(new ValidationError(d.pos, EscapingOutputPath(dest)));
		case DHtmlStore(path):
			push(validateSrcPath(path, [File]));
		case DHtmlToHead(_), DCodeBlock(_), DEmpty:
			// nothing to do
		}
	}

	function complete()
	{
		final = true;
		tick();
	}

	function new(cback)
	{
		this.cback = cback;
	}

	/*
	Validate the document.

	Runs asynchronously and, when done, calls `cback` with either `null` or
	an array with all discovered errors.
	*/
	public static function validate(doc, cback)
	{
		var d = new Validator(cback);
		Context.time("validation (sync)", d.diter.bind(doc));
		d.final = true;
		d.complete();
	}
}

