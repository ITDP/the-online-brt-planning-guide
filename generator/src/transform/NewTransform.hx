package transform;

import parser.Ast;
import transform.Context;
import transform.NewDocument;  // TODO remove

import Assertion.*;
import parser.AstTools.*;

using PositionTools;
using StringTools;

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
		case Superscript(i):
			h = mk(Superscript(htrim(i, ctx)), h.pos);
		case Subscript(i):
			h = mk(Subscript(htrim(i, ctx)), h.pos);
		case Emphasis(i):
			h = mk(Emphasis(htrim(i, ctx)), h.pos);
		case Highlight(i):
			h = mk(Highlight(htrim(i, ctx)), h.pos);
		case Word(_), InlineCode(_), Math(_), Url(_):
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
		case Wordspace, Word(_), InlineCode(_), Math(_), Url(_), HEmpty:
			h.def;
		case Superscript(i):
			i = hclean(i);
			!i.def.match(HEmpty) ? Superscript(i) : HEmpty;
		case Subscript(i):
			i = hclean(i);
			!i.def.match(HEmpty) ? Subscript(i) : HEmpty;
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

	static function horizontal(h:HElem):HElem
	{
		h = htrim(h, { prevSpace:true, reverse:false });
		h = htrim(h, { prevSpace:true, reverse:true });
		h = hclean(h);
		return h;
	}

	// end of horizontal stuff

	static function mkd(def, pos, ?id):DElem
		return { id:id, def:def, pos:pos };

	// TODO test id generation (it took me two tries to get this right)
	static function genId(h:HElem):String
	{
		var buf = new StringBuf();
		switch h.def {
		case Wordspace:
			buf.add("-");
		case Superscript(i), Subscript(i), Emphasis(i), Highlight(i):
			buf.add(genId(i));
		case Word(cte), InlineCode(cte), Math(cte), Url(cte):
			buf.add(~/[^a-z0-9\-]/ig.replace(cte, "").toLowerCase());
		case HElemList(li):
			for (i in li)
				buf.add(genId(i));
		case HEmpty:
			// NOOP
		}
		return buf.toString();
	}

	static function consume(parent:VElem, mainPool:Array<VElem>, idc:IdCtx, noc:NoCtx):DElem
	{
		var li = [];

		// keep the `mainPool` (shared with `vertical`) and the `subPool`s separate;
		// the `subPool` is only used to recurse into `VElemLists` to test their
		// first element
		function eatTillBoundary(subPool:Array<VElem>):Bool {
			switch [parent.def, subPool[0].def] {
			case [Volume(_), Volume(_)]: return true;
			case [Chapter(_), Chapter(_)|Volume(_)]: return true;
			case [Section(_), Section(_)|Chapter(_)|Volume(_)]: return true;
			case [SubSection(_), SubSection(_)|Section(_)|Chapter(_)|Volume(_)]: return true;
			case [SubSubSection(_), SubSubSection(_)|SubSection(_)|Section(_)|Chapter(_)|Volume(_)]: return true;
			case [_, VElemList([])]:
				subPool.shift();
				return false;
			case [_, VElemList(more)]:
				return eatTillBoundary(more);
			case _:
				var v = subPool.shift();
				li.push(vertical(v, mainPool, idc, noc));
				return false;
			}
		}

		while (mainPool.length > 0 && !eatTillBoundary(mainPool)) {}
		return switch li {
		case []: mkd(DEmpty, parent.pos.offset(parent.pos.max - parent.pos.min, 0));
		case [single]: single;
		case _: mkd(DElemList(li), li[0].pos.span(li[li.length -1 ].pos));
		}
	}

	static function vertical(v:VElem, siblings:Array<VElem>, idc:IdCtx, noc:NoCtx):DElem  // MAYBE rename idc/noc to id/no
	{
		// the parser should not output any nulls
		assert(v != null);
		assert(v.def != null);
		switch v.def {
		case HtmlStore(path):
			return mkd(DHtmlStore(path), v.pos);
		case HtmlToHead(template):
			return mkd(DHtmlToHead(template), v.pos);
		case LaTeXPreamble(path):
			return mkd(DLaTeXPreamble(path), v.pos);
		case LaTeXExport(src, dst):
			return mkd(DLaTeXExport(src, dst), v.pos);
		case MetaReset(name, val):
			switch name.toLowerCase().trim() {
			case "volume": noc.lastVolume = val;
			case "chapter": noc.lastChapter = val;
			case other: throw other;
			}
			return mkd(DEmpty, v.pos);
		case Volume(horizontal(_) => name):
			var id = idc.volume = genId(name);
			var no = noc.volume = noc.lastVolume + 1;
			var children = consume(v, siblings, idc, noc);
			return mkd(DVolume(no, name, children), v.pos.span(children.pos), id);
		case Chapter(horizontal(_) => name):
			var id = idc.chapter = genId(name);
			var no = noc.chapter = noc.lastChapter + 1;
			var children = consume(v, siblings, idc, noc);
			return mkd(DChapter(no, name, children), v.pos.span(children.pos), id);
		case Section(horizontal(_) => name):
			var id = idc.section = genId(name);
			var no = ++noc.section;
			var children = consume(v, siblings, idc, noc);
			return mkd(DSection(no, name, children), v.pos.span(children.pos), id);
		case SubSection(horizontal(_) => name):
			var id = idc.subSection = genId(name);
			var no = ++noc.subSection;
			var children = consume(v, siblings, idc, noc);
			return mkd(DSubSection(no, name, children), v.pos.span(children.pos), id);
		case SubSubSection(horizontal(_) => name):
			var id = idc.subSubSection = genId(name);
			var no = ++noc.subSubSection;
			var children = consume(v, siblings, idc, noc);
			return mkd(DSubSubSection(no, name, children), v.pos.span(children.pos), id);
		case Box(name, contents):
			var id = idc.box = genId(name);
			var no = ++noc.box;
			return mkd(DBox(no, name, vertical(contents, [], idc, noc)), v.pos, id);  // TODO assert that restricted vertical mode has been respected
		case Title(name):
			return mkd(DTitle(name), v.pos);
		case Figure(size, path, horizontal(_) => caption, horizontal(_) => copyright):
			// prefer path for id generation, but fallback to caption if a generic file name is recognized
			var fname = new haxe.io.Path(path.internal()).file;
			var id = idc.figure = genId(~/^(image|figure)/i.match(fname) ? caption : mk(Word(fname), path.pos));
			var no = ++noc.figure;
			return mkd(DFigure(no, size, path, caption, copyright), v.pos, id);
		case Table(size, horizontal(_) => caption, header, rows):
			var id = idc.table = genId(caption);
			var no = ++noc.table;
			// TODO assert that restricted vertical mode has been respected
			var dheader = header.map(vertical.bind(_, [], idc, noc));
			var drows = rows.map(function (r) return r.map(vertical.bind(_, [], idc, noc)));
			return mkd(DTable(no, size, caption, dheader, drows), v.pos, id);
		case ImgTable(size, horizontal(_) => caption, path):
			var id = idc.table = genId(caption);
			var no = ++noc.table;
			return mkd(DImgTable(no, size, caption, path), v.pos, id);
		case List(numbered, li):
			return mkd(DList(numbered, [ for (i in li) vertical(i, siblings, idc, noc) ]), v.pos);
		case CodeBlock(cte):
			return mkd(DCodeBlock(cte), v.pos);
		case Quotation(text, by):
			return mkd(DQuotation(horizontal(text), horizontal(by)), v.pos);
		case Paragraph(text):
			return mkd(DParagraph(horizontal(text)), v.pos);
		case VElemList(li):
			// `siblings`: shared stack of remaining neighbors from depth-first searches;
			// we first clone `li` since it gets modified by us and by `consume`
			var li = li.copy();
			siblings.unshift(mk(VElemList(li), v.pos));
			var li = [ while (li.length > 0) vertical(li.shift(), siblings, idc, noc) ];
			return mkd(DElemList(li), v.pos.span(li[li.length -1 ].pos));
		case VEmpty:
			return mkd(DEmpty, v.pos);
		}
	}

	/*
	Remove DEmpty elements.
	*/
	static function clean(d:DElem)
	{
		// we shouldn't generate nulls either
		assert(d != null);
		assert(d.def != null);
		var def = switch d.def {
		case DHtmlStore(_), DHtmlToHead(_), DLaTeXPreamble(_), DLaTeXExport(_),
				DTitle(_), DFigure(_), DImgTable(_), DCodeBlock(_), DQuotation(_), DEmpty:
			d.def;
		case DVolume(no, name, children):
			DVolume(no, name, clean(children));
		case DChapter(no, name, children):
			DChapter(no, name, clean(children));
		case DSection(no, name, children):
			DSection(no, name, clean(children));
		case DSubSection(no, name, children):
			DSubSection(no, name, clean(children));
		case DSubSubSection(no, name, children):
			DSubSubSection(no, name, clean(children));
		case DBox(no, name, children):
			DBox(no, name, clean(children));
		case DTable(no, size, caption, header, rows):
			DTable(no, size, caption, header.map(clean), rows.map(function (r) return r.map(clean)));
		case DList(numbered, li):
			DList(numbered, [ for (i in li) clean(i) ]);
		case DParagraph(text):
			!text.def.match(HEmpty) ? d.def : DEmpty;
		case DElemList(li):
			var cli = [];
			for (i in li) {
				i = clean(i);
				if (!i.def.match(DEmpty)) {
					cli.push(i);
					weakAssert(cli.length < 2 || !i.def.match(DList(_)) || !cli[cli.length - 2].def.match(DList(_)),
							"possible split list", i.pos.toString());
				}
			}
			switch cli {
			case []: DEmpty;
			case [one]: return one;
			case _: DElemList(cli);
			}
		}
		return mkd(def, d.pos, d.id);
	}

	public static function transform(ast:Ast):NewDocument
		return clean(vertical(ast, [], new IdCtx(), new NoCtx()));
}

