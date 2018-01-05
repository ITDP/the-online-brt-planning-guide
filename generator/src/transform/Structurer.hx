package transform;

import parser.Ast;
import transform.Context;
import transform.Document;

import Assertion.*;
import parser.AstTools.*;

using PositionTools;
using StringTools;

class Structurer {
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
		case Word(_), InlineCode(_), Math(_), Url(_), Ref(_), RangeRef(_):
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
		case Wordspace, Word(_), InlineCode(_), Math(_), Url(_), Ref(_), RangeRef(_), HEmpty:
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

	static function checkManualId(id:Elem<String>)
	{
	}

	// TODO test id generation (it took me two tries to get this right)
	static function genId(h:HElem, mid:Null<Elem<String>>):String
	{
		if (mid != null)
			h = mk(Word(mid.def), mid.pos);
		var buf = new StringBuf();
		switch h.def {
		case Wordspace:
			buf.add("-");
		case Superscript(i), Subscript(i), Emphasis(i), Highlight(i):
			buf.add(genId(i));
		case Word(cte), InlineCode(cte), Math(cte), Url(cte), Ref(_, _.def => cte):
			buf.add(~/[^a-z0-9\-]/ig.replace(cte, "").toLowerCase());
		case RangeRef(_, _.def => cte1, _.def => cte2):
			buf.add(~/[^a-z0-9\-]/ig.replace(cte1, "").toLowerCase());
			buf.add("-to-");
			buf.add(~/[^a-z0-9\-]/ig.replace(cte2, "").toLowerCase());
		case HElemList(li):
			for (i in li)
				buf.add(genId(i));
		case HEmpty:
			// NOOP
		}
		var id = buf.toString();
		assert(mid == false || mid.def == id, mid.def, "invalid", mid.pos.toString());
		return id;
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
		case []: mk(DEmpty, parent.pos.offset(parent.pos.max - parent.pos.min, 0));
		case [single]: single;
		case _: mk(DElemList(li), li[0].pos.span(li[li.length -1 ].pos));
		}
	}

	static function vertical(v:VElem, siblings:Array<VElem>, idc:IdCtx, noc:NoCtx, ?manualId:Elem<String>):DElem  // MAYBE rename idc/noc to id/no
	{
		// the parser should not output any nulls
		assert(v != null);
		assert(v.def != null);
		switch v.def {
		case HtmlStore(path):
			return mk(DHtmlStore(path), v.pos);
		case HtmlToHead(template):
			return mk(DHtmlToHead(template), v.pos);
		case LaTeXPreamble(path):
			return mk(DLaTeXPreamble(path), v.pos);
		case LaTeXExport(src, dst):
			return mk(DLaTeXExport(src, dst), v.pos);
		case MetaReset(name, val):
			switch name.toLowerCase().trim() {
			case "volume": noc.lastVolume = val;
			case "chapter": noc.lastChapter = val;
			case other: throw other;
			}
			return mk(DEmpty, v.pos);
		case Volume(horizontal(_) => name):
			var id = (idc.volume = genId(name, manualId)).stamp(volume);
			var no = (noc.volume = noc.lastVolume + 1).stamp(volume);
			var children = consume(v, siblings, idc, noc);
			return mk(DVolume(id, no, name, children), v.pos.span(children.pos));
		case Chapter(horizontal(_) => name):
			var id = (idc.chapter = genId(name, manualId)).stamp(chapter);
			var no = (noc.chapter = noc.lastChapter + 1).stamp(chapter);
			var children = consume(v, siblings, idc, noc);
			return mk(DChapter(id, no, name, children), v.pos.span(children.pos));
		case Section(horizontal(_) => name):
			var id = (idc.section = genId(name, manualId)).stamp(chapter, section);
			var no = (++noc.section).stamp(chapter, section);
			var children = consume(v, siblings, idc, noc);
			return mk(DSection(id, no, name, children), v.pos.span(children.pos));
		case SubSection(horizontal(_) => name):
			var id = (idc.subSection = genId(name, manualId)).stamp(chapter, section, subSection);
			var no = (++noc.subSection).stamp(chapter, section, subSection);
			var children = consume(v, siblings, idc, noc);
			return mk(DSubSection(id, no, name, children), v.pos.span(children.pos));
		case SubSubSection(horizontal(_) => name):
			var id = (idc.subSubSection = genId(name, manualId)).stamp(chapter, section, subSection, subSubSection);
			var no = (++noc.subSubSection).stamp(chapter, section, subSection, subSubSection);
			var children = consume(v, siblings, idc, noc);
			return mk(DSubSubSection(id, no, name, children), v.pos.span(children.pos));
		case Box(name, contents):
			var id = (idc.box = genId(name, manualId)).stamp(chapter, box);
			var no = (++noc.box).stamp(chapter, box);
			// TODO assert that restricted vertical mode has been respected
			return mk(DBox(id, no, name, vertical(contents, [], idc, noc)), v.pos);
		case Figure(size, path, horizontal(_) => caption, horizontal(_) => copyright):
			var fname = new haxe.io.Path(path.internal()).file;
			// weakAssert(~/^(image|figure)/i.match(fname), "filename looks generic; this is discouraged and not guaranteed to work", path.pos);  // FIXME enable
			var id = (idc.figure = genId(mk(Word(fname), path.pos), manualId)).stamp(chapter, figure);
			var no = (++noc.figure).stamp(chapter, figure);
			return mk(DFigure(id, no, size, path, caption, copyright), v.pos);
		case Table(size, horizontal(_) => caption, header, rows):
			var id = (idc.table = genId(caption, manualId)).stamp(chapter, table);
			var no = (++noc.table).stamp(chapter, table);
			// TODO assert that restricted vertical mode has been respected
			var dheader = header.map(vertical.bind(_, [], idc, noc));
			var drows = rows.map(function (r) return r.map(vertical.bind(_, [], idc, noc)));
			return mk(DTable(id, no, size, caption, dheader, drows), v.pos);
		case ImgTable(size, horizontal(_) => caption, path):
			var fname = new haxe.io.Path(path.internal()).file;
			// weakAssert(~/^(image|figure)/i.match(fname), "filename looks generic; this is discouraged and not guaranteed to work", path.pos);  // FIXME enable
			var id = (idc.table = genId(mk(Word(fname), path.pos), manualId)).stamp(chapter, table);
			var no = (++noc.table).stamp(chapter, table);
			return mk(DImgTable(id, no, size, caption, path), v.pos);
		case Title(name):
			return mk(DTitle(name), v.pos);
		case List(numbered, li):
			return mk(DList(numbered, [ for (i in li) vertical(i, siblings, idc, noc) ]), v.pos);
		case CodeBlock(cte):
			return mk(DCodeBlock(cte), v.pos);
		case Quotation(text, by):
			return mk(DQuotation(horizontal(text), horizontal(by)), v.pos);
		case Paragraph(text):
			return mk(DParagraph(horizontal(text)), v.pos);
		case Id(id, on):
			// TODO assert if id is valid (at least until we add this to the validator)
			return vertical(on, siblings, idc, noc, id);
		case VElemList(li):
			// `siblings`: shared stack of remaining neighbors from depth-first searches;
			// we first clone `li` since it gets modified by us and by `consume`
			var li = li.copy();
			siblings.unshift(mk(VElemList(li), v.pos));
			var li = [ while (li.length > 0) vertical(li.shift(), siblings, idc, noc) ];
			return mk(DElemList(li), v.pos.span(li[li.length -1 ].pos));
		case VEmpty:
			return mk(DEmpty, v.pos);
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
		case DVolume(id, no, name, children):
			DVolume(id, no, name, clean(children));
		case DChapter(id, no, name, children):
			DChapter(id, no, name, clean(children));
		case DSection(id, no, name, children):
			DSection(id, no, name, clean(children));
		case DSubSection(id, no, name, children):
			DSubSection(id, no, name, clean(children));
		case DSubSubSection(id, no, name, children):
			DSubSubSection(id, no, name, clean(children));
		case DBox(id, no, name, children):
			DBox(id, no, name, clean(children));
		case DTable(id, no, size, caption, header, rows):
			DTable(id, no, size, caption, header.map(clean), rows.map(function (r) return r.map(clean)));
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
		return mk(def, d.pos);
	}

	public static function transform(ast:Ast):Document
		return clean(vertical(ast, [], new IdCtx(), new NoCtx()));
}

