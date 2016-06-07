package parser;  // TODO move out of the package

import haxe.ds.GenericStack.GenericCell;
import parser.Ast;
import parser.Error;
import parser.Token;

import Assertion.*;
import parser.AstTools.*;

using StringTools;
using parser.TokenTools;

typedef Stop = {
	?before:TokenDef,
	?beforeAny:Array<TokenDef>  // could possibly replace before
}

typedef Path = String;
typedef FileCache = Map<Path,File>;

class Parser {
	static var verticalCommands = [
		"volume", "chapter", "section", "subsection", "subsubsection",
		"figure", "quotation", "item", "beginbox", "endbox", "include",
		"begintable", "row", "col", "endtable",
		"meta", "meta\\reset", "tex", "tex\\preamble", "html", "html\\apply"];
	static var horizontalCommands = ["emph", "highlight"];

	var location:Path;
	var lexer:Lexer;
	var cache:FileCache;
	var next:GenericCell<Token>;

	inline function unexpected(t:Token, ?desc)
		throw new UnexpectedToken(lexer, t, desc);

	inline function unclosed(t:Token)
		throw new UnclosedToken(lexer, t);

	inline function missingArg(p:Position, ?toToken:Token, ?desc:String)
		throw new MissingArgument(lexer, p, toToken, desc);

	inline function badValue(pos:Position, ?desc:String)
		throw new BadValue(lexer, pos, desc);

	inline function badArg(pos:Position, ?desc:String)
		throw new BadValue(lexer, pos.offset(1, -1), desc);

	inline function unknownCmd(cmd:Token)
	{
		// EXPERIMENTAL: use Levenshtein distances to generate command suggestions

		// Levenshtein distance penalties for the NeedlemanWunsh
		var df = function ( a, b ) return a==b ? 0 : 1;
		var sf = function ( a, b, c ) return 1;

		var name = switch cmd.def {
		case TCommand(n): n;
		case _: throw new UnknownCommand(lexer, cmd.pos); null;
		}
		name = name.toLowerCase();
		var cmds = verticalCommands.concat(horizontalCommands);
		var dist = cmds.map(function (x) return x.split(""))
			.map(NeedlemanWunsch.globalAlignment.bind(name.split(""), _, df, sf));
		var best = 0;
		for (i in 1...cmds.length) {
			if (dist[i].distance < dist[best].distance)
				best = i;
		}
		// trace(untyped [cmds[best], dist[best]]);
		throw new UnknownCommand(lexer, cmd.pos, cmds[best]);
	}

	function peek(offset=0):Token
	{
		if (next == null)
			next = new GenericCell(lexer.token(Lexer.tokens), null);
		var c = next;
		while (offset-- > 0) {
			if (c.next == null)
				c.next = new GenericCell(lexer.token(Lexer.tokens), null);
			c = c.next;
		}
		return c.elt;
	}

	function pop()
	{
		var ret = peek();
		next = next.next;
		return ret;
	}

	function discard(match:Token->Bool, permanent=true)
	{
		var next = 0;
		var count = 0;
		while (match(peek(next))) {
			count++;
			if (permanent)
				pop();
			else
				next = count;
		}
		return count;
	}

	function discardNoise(permanent=true):Int
		return discard(function (x) return x.def.match(TWordSpace(_)|TLineComment(_)|TBlockComment(_)));

	function discardVerticalNoise(permanent=true):Int
		return discard(function (x) return x.def.match(TWordSpace(_)|TLineComment(_)|TBlockComment(_)|TBreakSpace(_)));

	function arg<T>(internal:Stop->T, toToken:Null<Token>, ?desc:String):{ val:T, pos:Position }
	{
		discardNoise();
		var open = pop();
		if (!open.def.match(TBrOpen)) missingArg(open.pos, toToken, desc);

		var li = internal({ before : TBrClose });

		var close = pop();
		if (close.def.match(TEof)) unclosed(open);
		if (!close.def.match(TBrClose)) unexpected(close);
		return { val:li, pos:open.pos.span(close.pos) };
	}

	function optArg<T>(internal:Stop->T, toToken:Null<Token>, ?desc:String):Null<{ val:T, pos:Position }>
	{
		var i = discardNoise(false);
		if (!peek(i).def.match(TBrkOpen))
			return null;

		while (--i > 0) pop();
		var open = pop();
		if (!open.def.match(TBrkOpen)) missingArg(open.pos, toToken, desc);

		var li = internal({ before : TBrkClose });

		var close = pop();
		if (close.def.match(TEof)) unclosed(open);
		if (!close.def.match(TBrkClose)) unexpected(close);
		return { val:li, pos:open.pos.span(close.pos) };
	}

	function emphasis(cmd:Token)
	{
		var content = arg(hlist, cmd);
		return switch cmd.def {
		case TCommand("emph"): mk(Emphasis(content.val), cmd.pos.span(content.pos));
		case TCommand("highlight"): mk(Highlight(content.val), cmd.pos.span(content.pos));
		case _: unexpected(cmd); null;
		}
	}

	function mdEmph()
	{
		var open = pop();
		if (!open.def.match(TAsterisk)) unexpected(open);
		var li = hlist({ before:TAsterisk });
		var close = pop();
		if (!close.def.match(TAsterisk)) unclosed(open);
		return mk(Emphasis(li), open.pos.span(close.pos));
	}

	function horizontal(stop:Stop):HElem
	{
		while (peek().def.match(TLineComment(_) | TBlockComment(_)))
			pop();
		return switch peek() {
		case { def:tdef } if (stop.before != null && Type.enumEq(tdef, stop.before)):
			null;
		case { def:tdef } if (stop.beforeAny != null && Lambda.exists(stop.beforeAny,Type.enumEq.bind(tdef))):
			null;
		case { def:TWord(s), pos:pos }:
			pop();
			mk(Word(s), pos);
		case { def:TMath(s), pos:pos }:
			pop();
			mk(Word(s), pos);  // FIXME
		case { def:TCommand(cmdName), pos:pos }:
			switch cmdName {
			case "emph", "highlight": emphasis(pop());
			case _: null;  // vertical commands end the current hlist; unknown commands will be handled later
			}
		case { def:TAsterisk }:
			mdEmph();
		case { def:TWordSpace(s), pos:pos }:
			pop();
			mk(Wordspace, pos);
		case { def:TColon(q), pos:pos } if (q != 3):
			pop();
			mk(Word("".rpad(":", q)), pos);
		case { def:tdef } if (tdef.match(TBreakSpace(_) | TEof)):
			null;
		case other:
			unexpected(other); null;
		}
	}

	function hlist(stop:Stop)
	{
		var li = [];
		while (true) {
			var v = horizontal(stop);
			if (v == null) break;
			li.push(v);
		}
		return mkList(HList(li));
	}

	// FIXME try to avoid escaping the /, extremely common in paths
	// FIXME handle dash conversion, or document it accordingly
	function rawHorizontal(stop:Stop)
	{
		var buf = new StringBuf();
		while (true) {
			switch peek() {
			case { def:tdef } if (stop.before != null && Type.enumEq(tdef, stop.before)):
				break;
			case { def:tdef } if (stop.beforeAny != null && Lambda.exists(stop.beforeAny,Type.enumEq.bind(tdef))):
				break;
			case { def:TBreakSpace(_) } | { def:TEof }:
				break;
			case { def:TBlockComment(_) } | { def:TLineComment(_) }:  // not sure about this
				pop();
			case { def:TWord(w) }:
				pop();
				buf.add(w);
			case { def:def, pos:pos }:
				pop();
				buf.add(lexer.recover(pos.min, pos.max - pos.min));
			}
		}
		return buf.toString();
	}

	function hierarchy(cmd:Token)
	{
		var name = arg(hlist, cmd, "name");
		if (name.val == null) badArg(name.pos, "name cannot be empty");
		return switch cmd.def {
		case TCommand("volume"): mk(Volume(name.val), cmd.pos.span(name.pos));
		case TCommand("chapter"): mk(Chapter(name.val), cmd.pos.span(name.pos));
		case TCommand("section"): mk(Section(name.val), cmd.pos.span(name.pos));
		case TCommand("subsection"): mk(SubSection(name.val), cmd.pos.span(name.pos));
		case TCommand("subsubsection"): mk(SubSubSection(name.val), cmd.pos.span(name.pos));
		case _: unexpected(cmd); null;
		}
	}

	function mdHeading(hashes:Token, stop:Stop)
	{
		discardNoise();
		var name = hlist(stop);
		assert(name != null, "obvisouly empty header");  // FIXME maybe

		return switch hashes.def {
		case THashes(1): mk(Section(name), hashes.pos.span(name.pos));
		case THashes(2): mk(SubSection(name), hashes.pos.span(name.pos));
		case THashes(3): mk(SubSubSection(name), hashes.pos.span(name.pos));
		case _: unexpected(hashes, 'only sections (#), subsections (##) and subsubsections (###) allowed'); null;
		}
	}

	function figure(cmd:Token)
	{
		assert(cmd.def.match(TCommand("figure")), cmd);
		var path = arg(rawHorizontal, cmd, "path");
		var caption = arg(hlist, cmd, "caption");
		var copyright = arg(hlist, cmd, "copyright");
		if (path.val == null) badArg(path.pos, "path cannot be empty");
		if (caption.val == null) badArg(caption.pos, "caption cannot be empty");
		if (copyright.val == null) badArg(copyright.pos, "copyright cannot be empty");
		return mk(Figure(path.val, caption.val, copyright.val), cmd.pos.span(copyright.pos));
	}

	/**
	After having already read a `#FIG#` tag, parse the reaming of the
	vertical block as a combination of a of path (delimited by `{}`),
	copyright (after a `@` marker) and caption (everything before the `@`
	and that isn't part of the path).
	**/
	function mdFigure(tag:Array<Token>, stop)
	{
		assert(tag[0].def.match(THashes(1)), tag[0]);
		assert(tag[1].def.match(TWord("FIG")), tag[1]);
		assert(tag[2].def.match(THashes(1)), tag[2]);

		var captionParts = [];
		var path = null;
		var copyright = null;
		var lastPos = null;
		while (true) {
			var h = hlist({ beforeAny:[TBrOpen,TAt] });  // FIXME consider current stop
			if (h != null) {
				captionParts.push(h);
				lastPos = h.pos;
				continue;
			}
			switch peek().def {
			case TBrOpen:
				if (path != null) unexpected(peek(), "path already given");
				var p = arg(rawHorizontal, tag[1], "path");
				lastPos = p.pos;
				path = p.val;
			case TAt:
				if (copyright != null) unexpected(peek(), "copyright already given");
				pop();
				copyright = hlist({ before:TBrOpen });  // FIXME consider current stop
				lastPos = copyright.pos;
			case TBreakSpace(_), TEof:
				break;
			case _:
				unexpected(peek());
			}
		}
		assert(lastPos != null);
		if (captionParts.length == 0) badValue(lastPos, "caption cannot be empty");
		if (path == null) missingArg(lastPos, tag[1], "path");
		if (copyright == null) missingArg(lastPos, tag[1], "copyright");

		var caption = if (captionParts.length == 1)
				captionParts[0]
			else
				mk(HList(captionParts), captionParts[0].pos.span(captionParts[captionParts.length - 1].pos));
		return mk(Figure(path, caption, copyright), tag[0].pos.span(lastPos));
	}

	function tableCell(cmd:Token)
	{
		assert(cmd.def.match(TCommand("col")), cmd);
		// TODO handle empty cells
		return vlist({ beforeAny:[TCommand("col"), TCommand("row"), TCommand("endtable")] });
	}

	function tableRow(cmd:Token)
	{
		assert(cmd.def.match(TCommand("row")), cmd);
		// TODO handle empty rows
		var cells = [];
		while (true) {
			discardVerticalNoise();
			if (!peek().def.match(TCommand("col"))) break;
			cells.push(tableCell(pop()));
		}
		return cells;
	}

	function table(begin:Token)
	{
		assert(begin.def.match(TCommand("begintable")), begin);
		var caption = arg(hlist, begin, "caption");
		if (caption.val == null) badArg(caption.pos, "caption cannot be empty");
		var rows = [];
		while (true) {
			discardVerticalNoise();
			if (!peek().def.match(TCommand("row"))) break;
			rows.push(tableRow(pop()));
		}
		var end = pop();  // should have already discarted any vnoise before
		if (end.def.match(TEof)) unclosed(begin);
		if (!end.def.match(TCommand("endtable"))) unexpected(end);
		return mk(Table(rows, caption.val), begin.pos.span(end.pos));
	}

	function quotation(cmd:Token)
	{
		assert(cmd.def.match(TCommand("quotation")), cmd);
		var text = arg(hlist, cmd, "text");
		var author = arg(hlist, cmd, "author");
		if (text.val == null) badArg(text.pos, "text cannot be empty");
		if (author.val == null) badArg(author.pos, "author cannot be empty");
		return mk(Quotation(text.val, author.val), cmd.pos.span(author.pos));
	}

	function mdQuotation(greaterThan:Token, stop:Stop)
	{
		assert(greaterThan.def.match(TGreater), greaterThan);
		discardNoise();
		var text = hlist({ before:TAt });
		var at = pop();
		if (!at.def.match(TAt)) missingArg(at.pos, greaterThan, "author (prefixed with @)");
		discardNoise();
		var author = hlist(stop);
		if (text == null) badValue(greaterThan.pos.span(at.pos).offset(1, -1), "text cannot be empty");
		if (author == null) badValue(at.pos.offset(1,0), "author cannot be empty");
		return mk(Quotation(text, author), greaterThan.pos.span(author.pos));
	}

	// TODO docs
	function listItem(mark:Token, stop:Stop)
	{
		assert(mark.def.match(TCommand("item")), mark);
		var item = optArg(vlist, mark, "item content");
		if (item == null) {
			var i = vertical(stop);
			item = { val:i, pos:i.pos };
		}
		// TODO validation and error handling
		item.val.pos = mark.pos.span(item.pos);
		return item.val;
	}

	// see /generator/docs/list-design.md
	function list(at:Position, stop:Stop)
	{
		var li = [];
		while (peek().def.match(TCommand("item")))
			li.push(listItem(pop(), stop));
		assert(li.length > 0, li);  // we're sure that li.length > 0 since we started with \item
		return mk(List(li), at.span(li[li.length - 1].pos));
	}

	function box(begin:Token)
	{
		// FIXME remove compat with \boxstart,\boxend
		assert(begin.def.match(TCommand("beginbox") | TCommand("boxstart")), begin);
		weakAssert(begin.def.match(TCommand("beginbox")), "\\boxstart deprecated; use \\beginbox,\\endbox", begin.pos);
		var li = vlist({ beforeAny:[TCommand("endbox"), TCommand("boxend")] });
		discardVerticalNoise();
		var end = pop();
		if (end.def.match(TEof)) unclosed(begin);
		if (!end.def.match(TCommand("endbox") | TCommand("boxend"))) unexpected(end);
		return mk(Box(li), begin.pos.span(end.pos));
	}

	function include(cmd:Token)
	{
#if (sys || hxnodejs)
		assert(cmd.def.match(TCommand("include")), cmd);
		var p = arg(rawHorizontal, cmd);
		var path = p.val != null ? StringTools.trim(p.val) : "";
		if (path == "") badArg(p.pos, "path cannot be empty");
		// TODO don't allow absolute paths (they mean nothing in a collaborative repository)
		path = haxe.io.Path.join([haxe.io.Path.directory(location), path]);
		// TODO normalize the (absolute) path
		// TODO use the cache
		return parse(path, cache);
#else
		unexpected(cmd, "\\include not available in non-sys targets (or Node.js)");
		return null;
#end
	}

	function paragraph(stop:Stop)
	{
		var text = hlist(stop);
		if (text == null) return null;
		return mk(Paragraph(text), text.pos);
	}

	function metaReset(cmd:Token)
	{
		assert(cmd.def.match(TCommand("meta\\reset")), cmd);
		var name = arg(rawHorizontal, cmd, "counter name");
		var val = arg(rawHorizontal, cmd, "reset value");
		var no = ~/^[ \t\r\n]*[0-9][0-9]*[ \t\r\n]*$/.match(val.val) ? Std.parseInt(StringTools.trim(val.val)) : null;
		if (!Lambda.has(["volume","chapter"], name.val)) badArg(name.pos, "counter name should be `volume` or `chapter`");
		if (no == null || no < 0) badArg(val.pos, "reset value must be strictly greater or equal to zero");
		return mk(MetaReset(name.val, no), cmd.pos.span(val.pos));
	}

	function targetInclude(cmd:Token)
	{
		var path = arg(rawHorizontal, cmd);
		if (path.val == null || StringTools.trim(path.val) == "") badArg(path.pos, "path cannot be empty");
		var tpath = haxe.io.Path.join([haxe.io.Path.directory(location), path.val]);
		return switch cmd.def {
		case TCommand("html\\apply"): mk(HtmlApply(tpath), cmd.pos.span(path.pos));
		case TCommand("tex\\preamble"): mk(LaTeXPreamble(tpath), cmd.pos.span(path.pos));
		case _: unexpected(cmd); null;
		}
	}

	function meta(meta:Token)
	{
		discardNoise();
		var exec = pop();
		var pos = meta.pos.span(exec.pos);
		return switch [meta.def, exec.def] {
		case [TCommand("meta"), TCommand("reset")]: metaReset({ def:TCommand("meta\\reset"), pos:pos });
		case [TCommand("html"), TCommand("apply")]: targetInclude({ def:TCommand("html\\apply"), pos:pos });
		case [TCommand("tex"), TCommand("preamble")]: targetInclude({ def:TCommand("tex\\preamble"), pos:pos });
		case _: unexpected(exec); null;  // FIXME specific error unknown meta command
		}
	}

	function vertical(stop:Stop):VElem
	{
		discardVerticalNoise();
		return switch peek().def {
		case tdef if (stop.before != null && Type.enumEq(tdef, stop.before)):
			null;
		case tdef if (stop.beforeAny != null && Lambda.exists(stop.beforeAny,Type.enumEq.bind(tdef))):
			null;
		case TEof:
			null;
		case TCommand(cmdName):
			switch cmdName {
			case "volume", "chapter", "section", "subsection", "subsubsection": hierarchy(pop());
			case "figure": figure(pop());
			case "begintable": table(pop());
			case "quotation": quotation(pop());
			case "item": list(peek().pos, stop);
			case "meta", "tex", "html": meta(pop());
			case "beginbox", "boxstart": box(pop());
			case "include": include(pop());
			case name if (Lambda.has(horizontalCommands, name)): paragraph(stop);
			case _: unknownCmd(peek()); null;
			}
		case THashes(1) if (peek(1).def.match(TWord("FIG")) && peek(2).def.match(THashes(1))):
			mdFigure([pop(), pop(), pop()], stop);
		case THashes(_) if (!peek(1).def.match(TWord("EQ") | TWord("TAB"))):  // TODO remove EQ/TAB when possible
			mdHeading(pop(), stop);
		case TGreater:
			mdQuotation(pop(), stop);
		case TWord(_), TAsterisk:
			paragraph(stop);
		case TColon(q) if (q != 3):
			paragraph(stop);
		case _:
			unexpected(peek()); null;
		}
	}

	function vlist(stop:Stop)
	{
		var li = [];
		while (true) {
			var v = vertical(stop);
			if (v == null) break;
			li.push(v);
		}
		return mkList(VList(li));
	}

	public function file():File
		return vlist({});  // TODO update the cache

	public function new(location:String, lexer:Lexer, ?cache:FileCache)
	{
		this.location = location;
		this.lexer = lexer;
		if (cache == null) cache = new FileCache();
		this.cache = cache;
	}

#if (sys || hxnodejs)
	public static function parse(path:String, ?cache:FileCache)
	{
		var lex = new Lexer(sys.io.File.getBytes(path), path);
		var parser = new Parser(path, lex, cache);
		return parser.file();
	}
#end
}

