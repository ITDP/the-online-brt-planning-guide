package parser;  // TODO move out of the package

import haxe.ds.GenericStack.GenericCell;
import haxe.ds.Option;
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
	public static var defaultFigureSize = MarginWidth;
	public static var defaultTableSize = TextWidth;

	static var verticalCommands = [
		"volume", "chapter", "section", "subsection", "subsubsection",
		"figure", "quotation", "item", "number", "beginbox", "endbox", "include",
		"begintable", "header", "row", "col", "endtable",
		"meta", "reset", "tex", "preamble", "export", "html", "apply"];
	static var horizontalCommands = ["emph", "highlight"];

	var location:Path;
	var lexer:Lexer;
	var cache:FileCache;
	var next:GenericCell<Token>;

	inline function unexpected(t:Token, ?desc):Dynamic
		throw new UnexpectedToken(lexer, t, desc);

	inline function unclosed(t:Token):Dynamic
		throw new UnclosedToken(lexer, t);

	inline function missingArg(p:Position, ?toToken:Token, ?desc:String):Dynamic
		throw new MissingArgument(lexer, p, toToken, desc);

	inline function badValue(pos:Position, ?desc:String):Dynamic
		throw new BadValue(lexer, pos, desc);

	inline function badArg(pos:Position, ?desc:String):Dynamic
		throw new BadValue(lexer, pos.offset(1, -1), desc);

	inline function unexpectedCmd(cmd:Token):Dynamic
	{
		// EXPERIMENTAL: use Levenshtein distances to generate command suggestions

		// Levenshtein distance penalties for the NeedlemanWunsh
		var df = function ( a, b ) return a==b ? 0 : 1;
		var sf = function ( a, b, c ) return 1;

		var name = switch cmd.def {
		case TCommand(n): n;
		case _: throw new UnexpectedToken(lexer, cmd);
		}
		name = name.toLowerCase();
		var cmds = verticalCommands.concat(horizontalCommands);
		if (Lambda.has(cmds, name))
			throw new UnexpectedCommand(lexer, cmd.pos);
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
		assert(c.elt != null);
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
		return discard(function (x) return x.def.match(TWordSpace(_)|TComment(_)));

	function discardVerticalNoise(permanent=true):Int
		return discard(function (x) return x.def.match(TWordSpace(_)|TComment(_)|TBreakSpace(_)));

	function arg<T>(internal:Stop->T, ?toToken:Token, ?desc:String):{ val:T, pos:Position }
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

	function optArg<T>(internal:Stop->T, ?toToken:Token, ?desc:String):Nullable<{ val:T, pos:Position }>
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
		case _: unexpected(cmd);
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

	function horizontal(stop:Stop):Nullable<HElem>
	{
		while (peek().def.match(TComment(_)))
			pop();
		return switch peek() {
		case { def:tdef } if (stop.before != null && Type.enumEq(tdef, stop.before)):
			null;
		case { def:tdef } if (stop.beforeAny != null && Lambda.exists(stop.beforeAny,Type.enumEq.bind(tdef))):
			null;
		case { def:TWord(s), pos:pos }:
			pop();
			mk(Word(s), pos);
		case { def:TMath(tex), pos:pos }:
			pop();
			mk(Math(tex), pos);  // FIXME
		case { def:TCode(s), pos:pos }:
			pop();
			mk(InlineCode(s), pos);
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
			unexpected(other);
		}
	}

	function hlist(stop:Stop)
		return mkList(horizontal, stop);

	// FIXME document slash behavior
	// FIXME document automagically converted chars (TeX ligatures)
	// FIXME document chars that need to be escaped (including the ones used in the above TeX ligatures)
	function rawHorizontal(stop:Stop):String
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
			case { def:TComment(_) }:  // not sure about this
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
		if (name.val.def.match(HEmpty)) badArg(name.pos, "name cannot be empty");
		return switch cmd.def {
		case TCommand("volume"): mk(Volume(name.val), cmd.pos.span(name.pos));
		case TCommand("chapter"): mk(Chapter(name.val), cmd.pos.span(name.pos));
		case TCommand("section"): mk(Section(name.val), cmd.pos.span(name.pos));
		case TCommand("subsection"): mk(SubSection(name.val), cmd.pos.span(name.pos));
		case TCommand("subsubsection"): mk(SubSubSection(name.val), cmd.pos.span(name.pos));
		case _: unexpected(cmd);
		}
	}

	function mdHeading(hashes:Token, stop:Stop)
	{
		discardNoise();
		var name = hlist(stop);
		assert(!name.def.match(HEmpty), "obvisouly empty header");  // FIXME proper error? if so, needs to be tested

		return switch hashes.def {
		case THashes(1): mk(Section(name), hashes.pos.span(name.pos));
		case THashes(2): mk(SubSection(name), hashes.pos.span(name.pos));
		case THashes(3): mk(SubSubSection(name), hashes.pos.span(name.pos));
		case _: unexpected(hashes, 'only sections (#), subsections (##) and subsubsections (###) allowed');
		}
	}

	function figure(cmd:Token)
	{
		assert(cmd.def.match(TCommand("figure")), cmd);
		var size = blobSize(optArg(rawHorizontal, cmd, "size"), defaultFigureSize);
		var path = arg(rawHorizontal, cmd, "path");
		var caption = arg(hlist, cmd, "caption");
		var copyright = arg(hlist, cmd, "copyright");
		if (caption.val.def.match(HEmpty)) badArg(caption.pos, "caption cannot be empty");  // TODO test
		if (copyright.val.def.match(HEmpty)) badArg(copyright.pos, "copyright cannot be empty");  // TODO test
		return mk(Figure(size, mkPath(path.val, path.pos), caption.val, copyright.val), cmd.pos.span(copyright.pos));
	}

	/*
	After having already read a `#FIG#` tag, parse the reaming of the
	vertical block as a combination of a of path (delimited by `{}`),
	copyright (after a `@` marker) and caption (everything before the `@`
	and that isn't part of the path).
	*/
	function mdFigure(tag:Array<Token>, stop)
	{
		assert(tag[0].def.match(THashes(1)), tag[0]);
		// assert(tag[1].def.match(TWord("FIG") | TWord("FIG:small") | TWord("FIG:medium") | TWord("FIG:large")), tag[1]);
		assert(tag[2].def.match(THashes(1)), tag[2]);

		var spat = ~/^FIG(:(small|medium|large))?$/;
		var size = switch tag[1].def {
		case TWord(n) if (spat.match(n)):
			var s = spat.matched(2);
			blobSize(s != null ? { val:s, pos:tag[1].pos } : null, defaultFigureSize);
		case _:
			unexpected(tag[1]);
		}

		var captionParts = [];
		var path = null;
		var copyright = null;
		var lastPos = null;
		while (true) {
			var h = hlist({ beforeAny:[TBrOpen,TAt] });  // FIXME consider current stop
			if (!h.def.match(HEmpty)) {
				captionParts.push(h);
				lastPos = h.pos;
				continue;
			}
			switch peek().def {
			case TBrOpen:
				if (path != null) unexpected(peek(), "path already given");
				var p = arg(rawHorizontal, tag[1], "path");
				lastPos = p.pos;
				path = mkPath(p.val, p.pos);
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
		if (copyright == null || copyright.def.match(HEmpty)) missingArg(lastPos, tag[1], "copyright");  // TODO test
		var caption = if (captionParts.length == 1)
				captionParts[0]
			else
				mk(HElemList(captionParts), captionParts[0].pos.span(captionParts[captionParts.length - 1].pos));
		return mk(Figure(size, path, caption, copyright), tag[0].pos.span(lastPos));
	}

	function tableCell(cmd:Token)
	{
		assert(cmd.def.match(TCommand("col")), cmd);
		// TODO handle empty cells
		return vlist({ beforeAny:[TCommand("col"), TCommand("row"), TCommand("endtable")] });
	}

	function tableRow(cmd:Token)
	{
		assert(cmd.def.match(TCommand("row") | TCommand("header")), cmd);
		// TODO handle empty rows
		var cells = [];
		while (true) {
			discardVerticalNoise();
			if (!peek().def.match(TCommand("col"))) break;
			cells.push(tableCell(pop()));
		}
		return cells;
	}

	function blobSize(spec:Nullable<{ val:String, pos:Position }>, def:BlobSize):BlobSize
	{
		var spec = spec.extractOr(return def);
		return switch spec.val.toLowerCase().trim() {
		case "small": MarginWidth;
		case "medium": TextWidth;
		case "large": FullWidth;
		case _: badValue(spec.pos, "only sizes 'small', 'medium', and 'large' are valid");
		}
	}

	function table(begin:Token)
	{
		assert(begin.def.match(TCommand("begintable")), begin);
		var size = blobSize(optArg(rawHorizontal, begin, "size"), defaultTableSize);
		var caption = arg(hlist, begin, "caption");
		if (caption.val.def.match(HEmpty)) badArg(caption.pos, "caption cannot be empty");  // TODO test
		var rows = [];
		discardVerticalNoise();
		if (!peek().def.match(TCommand("header"))) missingArg(peek().pos, begin, "\\header line");
		var header = tableRow(pop());
		while (true) {
			discardVerticalNoise();
			if (!peek().def.match(TCommand("row"))) break;
			var row = tableRow(pop());
			rows.push(row);
			assert(row.length == header.length, row.length, header.length, rows.length, begin.pos);
		}
		var end = pop();  // should have already discarted any vnoise before
		if (end.def.match(TEof)) unclosed(begin);
		if (!end.def.match(TCommand("endtable"))) unexpected(end);
		return mk(Table(size, caption.val, header, rows), begin.pos.span(end.pos));
	}

	function quotation(cmd:Token)
	{
		assert(cmd.def.match(TCommand("quotation")), cmd);
		var text = arg(hlist, cmd, "text");
		var author = arg(hlist, cmd, "author");
		if (text.val.def.match(HEmpty)) badArg(text.pos, "text cannot be empty");
		if (author.val.def.match(HEmpty)) badArg(author.pos, "author cannot be empty");
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
		if (text.def.match(HEmpty)) badValue(greaterThan.pos.span(at.pos).offset(1, -1), "text cannot be empty");
		if (author.def.match(HEmpty)) badValue(at.pos.offset(1,0), "author cannot be empty");
		return mk(Quotation(text, author), greaterThan.pos.span(author.pos));
	}

	// TODO docs
	function listItem(mark:Token, stop:Stop)
	{
		assert(mark.def.match(TCommand("item" | "number")), mark);
		var item:VElem = switch optArg(vlist, mark, "item content").cases() {
		case Some(vlist):
			vlist.val.pos = vlist.pos;
			vlist.val;
		case None:
			var st = peek().pos;
			vertical(stop).extractOr({
				// FIXME duplicated from mkList and delicate
				var at = peek().pos;
				at = at.offset(0, at.min - at.max);
				st = st.offset(0, st.min - st.max);
				mk(VEmpty, st.span(at));
			});
		}
		// TODO validation and error handling
		item.pos = mark.pos.span(item.pos);
		return item;
	}

	// see /generator/docs/list-design.md
	function list(mark:Token, stop:Stop)
	{
		assert(mark.def.match(TCommand("item" | "number")), mark);
		var li = [];
		while (Type.enumEq(peek().def, mark.def))
			li.push(listItem(pop(), stop));
		assert(li.length > 0, li);  // we're sure that li.length > 0 since we started with \item
		var def = switch mark.def {
		case TCommand("item"): List(false, li);
		case TCommand("number"): List(true, li);
		case _: unexpectedCmd(mark);
		}
		return mk(def, mark.pos.span(li[li.length - 1].pos));
	}

	function box(begin:Token)
	{
		assert(begin.def.match(TCommand("beginbox")), begin);
		var name = arg(hlist, begin, "name");
		if (name.val.def.match(HEmpty)) badArg(name.pos, "name cannot be empty");
		var li = vlist({ beforeAny:[TCommand("endbox")] });
		discardVerticalNoise();
		var end = pop();
		if (end.def.match(TEof)) unclosed(begin);
		if (!end.def.match(TCommand("endbox"))) unexpected(end);
		return mk(Box(name.val, li), begin.pos.span(end.pos));
	}

	function mkPath(rel:String, pos:Position, allowEmpty=false)
	{
		// TODO don't allow absolute paths (they mean nothing in a collaborative repository)
		// TODO maybe return absolute paths?
		assert(rel != null);
		if (rel == "") {
			if (allowEmpty)
				return rel;
			badArg(pos, "path cannot be empty");
		}
		var path = haxe.io.Path.join([haxe.io.Path.directory(pos.src), rel]);
		return haxe.io.Path.normalize(path);
	}

	function include(cmd:Token)
	{
		assert(cmd.def.match(TCommand("include")), cmd);
		var p = arg(rawHorizontal, cmd);
		var path = mkPath(p.val, p.pos);
		// TODO normalize the (absolute) path
		// TODO use the cache
		return parse(path, cache);
	}

	function paragraph(stop:Stop)
	{
		var text = hlist(stop);
		if (text.def.match(HEmpty)) return mk(VEmpty, text.pos);  // TODO test
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
		var p = arg(rawHorizontal, cmd, "source path");
		var path = mkPath(p.val, p.pos);
		return switch cmd.def {
		case TCommand("html\\apply"): mk(HtmlApply(path), cmd.pos.span(p.pos));
		case TCommand("tex\\preamble"): mk(LaTeXPreamble(path), cmd.pos.span(p.pos));
		case _: unexpected(cmd);
		}
	}

	function texExport(cmd:Token)
	{
		assert(cmd.def.match(TCommand("tex\\export")), cmd);
		var s = arg(rawHorizontal, cmd, "source path");
		var d = arg(rawHorizontal, cmd, "destination path");
		var src = mkPath(s.val, s.pos);
		var dest = haxe.io.Path.normalize(d.val);
		if (haxe.io.Path.isAbsolute(dest)) badArg(d.pos, "destination path cannot be absolute");
		if (dest.startsWith("..")) badArg(d.pos, "destination path cannot escape the destination directory");
		return mk(LaTeXExport(src, dest), cmd.pos.span(d.pos));
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
		case [TCommand("tex"), TCommand("export")]: texExport({ def:TCommand("tex\\export"), pos:pos });
		case _: unexpectedCmd(exec);
		}
	}

	function vertical(stop:Stop):Nullable<VElem>
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
			case "item", "number": list(peek(), stop);
			case "meta", "tex", "html": meta(pop());
			case "beginbox", "boxstart": box(pop());
			case "include": include(pop());
			case name if (Lambda.has(horizontalCommands, name)): paragraph(stop);
			case _: unexpectedCmd(peek()); null;
			}
		case THashes(1) if (peek(1).def.match(TWord("FIG")) && peek(2).def.match(THashes(1))):
			mdFigure([pop(), pop(), pop()], stop);
		case THashes(_) if (!peek(1).def.match(TWord("EQ") | TWord("TAB"))):  // TODO remove EQ/TAB when possible
			mdHeading(pop(), stop);
		case TGreater:
			mdQuotation(pop(), stop);
		case TCodeBlock(c):
			mk(CodeBlock(c), pop().pos);
		case TWord(_), TAsterisk:
			paragraph(stop);
		case TColon(q) if (q != 3):
			paragraph(stop);
		case _:
			unexpected(peek());
		}
	}

	function vlist(stop:Stop)
		return mkList(vertical, stop);

	public function file():File
		return vlist({});  // TODO update the cache

	public function new(location:String, lexer:Lexer, ?cache:FileCache)
	{
		this.location = location;
		this.lexer = lexer;
		if (cache == null) cache = new FileCache();
		this.cache = cache;
	}

	public static function parse(path:String, ?cache:FileCache):File
	{
		var lex = new Lexer(sys.io.File.getBytes(path), path);
		var parser = new Parser(path, lex, cache);
		return parser.file();
	}
}

