package transform;

import parser.Ast;
import transform.Document;
import transform.NewDocument;  // TODO remove

import parser.AstTools.*;

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
		case HList(li):
			if (ctx.reverse) {
				li = li.copy();
				li.reverse();
			}
			li = [ for (i in li) htrim(i, ctx) ];
			if (ctx.reverse)
				li.reverse();
			h = mk(HList(li), h.pos);
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
		case HList(li):
			var cli = [];
			for (i in li) {
				i = hclean(i);
				if (!i.def.match(HEmpty))
					cli.push(i);
			}
			// don't collapse one-element lists because that would
			// destroy position information that came from trimmed children
			cli.length != 0 ? HList(cli) : HEmpty;
		}
		return mk(def, h.pos);
	}

	@:allow(transform.Transform)  // TODO remove
	@:allow(Test_04_Transform)  // TODO remove
	static function horizontal(h:HElem):HElem
	{
		h = htrim(h, { prevSpace:true, reverse:false });
		h = htrim(h, { prevSpace:true, reverse:true });
		h = hclean(h);
		return h;
	}

	public static function transform(ast:Ast):NewDocument
	{
		// TODO
		return { id:"", def:DEmpty, pos:ast.pos };
	}
}

