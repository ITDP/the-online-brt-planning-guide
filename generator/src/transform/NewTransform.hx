package transform;

import parser.Ast;
import transform.Document;
import transform.NewDocument;  // TODO remove

import parser.AstTools.*;

// TODO split in transform/vertical/horizontal classes (or even modules)
class NewTransform {
	/*
	Trim redundant wordspace.

	This 1:1 transformation changes redundant wordspace elements to HEmpty.
	*/
	static function htrim(h:HElem, ctx:{ prevSpace:Bool, reverse:Bool })
	{
		switch h.def {
		case Wordspace:
			if (ctx.prevSpace)
				h = mk(HEmpty, h.pos);
			ctx.prevSpace = true;
		case Emphasis(i):
			h = mk(Emphasis(htrim(i, ctx)), h.pos);
		case Highlight(i):
			h = mk(Highlight(htrim(i, ctx)), h.pos);
		case Word(_), InlineCode(_), Math(_):
			ctx.prevSpace = false;
		case HElemList(li):
			if (ctx.reverse) {
				li = li.copy();
				li.reverse();
			}
			li = [ for (i in li) htrim(i, ctx) ];
			if (ctx.reverse)
				li.reverse();
			h = mk(HElemList(li), h.pos);
		case HEmpty:
			// NOOP
		}
		return h;
	}

	/*
	Remove HEmpty elements.
	*/
	static function hclean(h:HElem)
	{
		var def = switch h.def {
		case Wordspace, Word(_), InlineCode(_), Math(_), HEmpty:
			h.def;
		case Emphasis(i):
			i = hclean(i);
			!i.def.match(HEmpty) ? Emphasis(i) : HEmpty;
		case Highlight(i):
			i = hclean(i);
			!i.def.match(HEmpty) ? Highlight(i) : HEmpty;
		case HElemList(li):
			var cli = [];
			for (i in li) {
				i = hclean(i);
				if (!i.def.match(HEmpty))
					cli.push(i);
			}
			// don't collapse one-element lists because that would
			// destroy position information that came from trimmed children
			cli.length != 0 ? HElemList(cli) : HEmpty;
		}
		return mk(def, h.pos);
	}

	@:allow(transform.Transform)  // TODO remove
	static function horizontal(h:HElem):HElem
	{
		h = htrim(h, { prevSpace:true, reverse:false });
		h = htrim(h, { prevSpace:true, reverse:true });
		h = hclean(h);
		return h;
	}

	// end of horizontal stuff

	static function mkd(def, pos, id=""):DElem
		return { id:id, def:def, pos:pos };

	@:allow(transform.Transform)  // TODO remove
	static function vertical(v:VElem):DElem
	{
		switch v.def {
		case List(numbered, li):
			return mkd(DList(numbered, [ for (i in li) vertical(i) ]), v.pos);
		case CodeBlock(cte):
			return mkd(DCodeBlock(cte), v.pos);
		case Quotation(text, by):
			return mkd(DQuotation(horizontal(text), horizontal(by)), v.pos);
		case Paragraph(text):
			return mkd(DParagraph(horizontal(text)), v.pos);
		case _:  // TODO remove
			return mkd(DEmpty, v.pos);
		}
	}

	public static function transform(ast:Ast):NewDocument
		return vertical(ast);
}

