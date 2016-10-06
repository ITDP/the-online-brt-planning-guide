package transform;

import transform.NewDocument;

import Assertion.*;
using parser.TokenTools;

class Validator {
	var final = false;
	var mathQueue = 0;
	var onError:ValidationError->Void;
	var onDone:Void->Void;

	/*
	Validate TeX math.
	*/
	function validateMath(tex:String, pos:Position)
	{
		// FIXME this completly ignores that the return is async ; )
		mathQueue++;
		mathjax.Single.typeset({
			math:tex,
			format:mathjax.Single.SingleTypesetFormat.TEX,
			mml:true
		}, function (res) {
			mathQueue--;
			if (res.errors != null) {
				onError({
					msg : 'Bad math: $$$$$tex$$$$',
					details : res.errors,
					pos : pos
				});
			} else if (final && mathQueue == 0) {
				onDone();
			}
		});
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
			// TODO path
			hiter(caption);
			hiter(copyright);
		case DImgTable(_, _, caption, path):
			// TODO path
			hiter(caption);
		case DQuotation(text, by):
			hiter(text);
			hiter(by);
		case DParagraph(text):
			hiter(text);
		case DLaTeXPreamble(_), DLaTeXExport(_), DHtmlApply(_), DCodeBlock(_), DEmpty:
			// TODO paths
			// nothing to do
		}
	}

	function complete()
	{
		final = true;
		if (mathQueue == 0)
			onDone;
	}

	function new(onError, onDone)
	{
		this.onError = onError;
		this.onDone = onDone;
	}
	
	public static function validate(doc, onError, onDone)
	{
		var d = new Validator(onError, onDone);
		d.diter(doc);
		d.complete();
	}
}

