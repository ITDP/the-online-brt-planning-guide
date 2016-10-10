package transform;

import transform.NewDocument;
import sys.FileSystem;
import haxe.io.Path;

import Assertion.*;
using parser.TokenTools;

enum FileType {
	Directory;
	File;
	Jpeg;
	Png;
	Js;
	Css;
	Tex;
}

class Validator {
	var wait = 0;
	var final = false;
	var cback:Bool->Null<ValidationError>->Void;

	function error(err)
		cback(final && wait == 0, err);

	/*
	Validate TeX math.
	*/
#if nodejs
	function validateMath(tex:String, pos:Position)
	{
		// FIXME this completly ignores that the return is async ; )
		wait++;
		mathjax.Single.typeset({
			math:tex,
			format:mathjax.Single.SingleTypesetFormat.TEX,
			mml:true
		}, function (res) {
			wait--;
			var err = if (res.errors != null)
				{
					fatal : true,
					msg : 'Bad math: $$$$$tex$$$$',
					details : res.errors,
					pos : pos
				}
			else
				null;
			cback(final && wait == 0, err);
		});
	}
#else
	dynamic function validateMath(tex:String, pos:Position)
	{
		show("skipping math validation, no tex implementation available on this platform");
		this.validateMath = function (t, p) {};
	}
#end

	function validateSrcPath(pos, src, types:Array<FileType>)
	{
		var exists = FileSystem.exists(src);
		if (!exists) {
			error({ fatal:true, msg:"File not found or not accessible (tip: paths are relative and case sensitive)", details:{ src:src }, pos:pos });
			return;
		}
		var isDirectory = FileSystem.isDirectory(src);
		var ext = Path.extension(src);
		for (t in types) {
			switch [isDirectory, t, ext.toLowerCase()] {
			case [true, Directory, _]: return;
			case [false, File, _]: return;
			case [false, Jpeg, "jpeg"|"jpg"]: return;
			case [false, Png, "png"]: return;
			case [false, Js, "js"]: return;
			case [false, Css, "css"]: return;
			case [false, Tex, "tex"]: return;
			case _: // keep going
			}
		}
		if (isDirectory)
			error({ fatal:true, msg:"Expected file, not directory", details:{ src:src }, pos:pos });
		else
			error({ fatal:true, msg:"File does not match expected types", details:{ src:src, types:types }, pos:pos });
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
		case Wordspace, Word(_), InlineCode(_), HEmpty:
			// nothing to do
		}
	}

	/*
	Validate document elements.

	Performs possible checks on the fly, and queues the rest.
	*/
	function diter(d:DElem)
	{
		switch d.def {
		case DVolume(_, name, children), DChapter(_, name, children), DSection(_, name, children), DSubSection(_, name, children), DSubSubSection(_, name, children), DBox(_, name, children):
			hiter(name);
			diter(children);
		case DElemList(items), DList(_, items):
			for (i in items)
				diter(i);
		case DTable(_, _, caption, header, rows):
			hiter(caption);
			for (c in header)
				diter(c);
			for (columns in rows) {
				for (c in columns)
					diter(c);
			}
		case DFigure(_, _, path, caption, copyright):
			validateSrcPath(d.pos, path, [Jpeg, Png]);
			hiter(caption);
			hiter(copyright);
		case DImgTable(_, _, caption, path):
			validateSrcPath(d.pos, path, [Jpeg, Png]);
			hiter(caption);
		case DQuotation(text, by):
			hiter(text);
			hiter(by);
		case DParagraph(text):
			hiter(text);
		case DLaTeXPreamble(path):
			validateSrcPath(d.pos, path, [Tex]);
		case DLaTeXExport(src, dest):
			validateSrcPath(d.pos, src, [Directory, File]);
			// TODO dest
		case DHtmlApply(path):
			validateSrcPath(d.pos, path, [Css]);
		case DCodeBlock(_), DEmpty:
			// nothing to do
		}
	}

	function complete()
	{
		final = true;
		if (wait == 0)
			cback(true, null);
	}

	function new(cback)
	{
		this.cback = cback;
	}

	/*
	Validate the document.

	Runs `cback(final, err)` for every error found, or once if no errors
	are found.  Check the `find` argument to find out whether or not the
	callback will be executed again.
	*/
	public static function validate(doc, cback)
	{
		var d = new Validator(cback);
		d.diter(doc);
		d.final = true;
		d.complete();
	}
}

