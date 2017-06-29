package parser;  // TODO move out of the package

import haxe.ds.GenericStack.GenericCell;
import haxe.ds.Option;
import haxe.io.Path;
import parser.Ast;
import parser.ParserError;
import parser.Token;
import sys.FileSystem;
import transform.ValidationError;
import transform.Validator;

import Assertion.*;
import parser.AstTools.*;

using StringTools;
using PositionTools;

typedef Stop = {
	?before:TokenDef,
	?beforeAny:Array<TokenDef>  // could possibly replace before
}

typedef FileCache = Map<String,{ parent:Position, ast:Option<File> }>;

class Parser {
	public static var defaultFigureSize = MarginWidth;
	public static var defaultTableSize = TextWidth;

	// command name fixing suggestions
	static var verticalCommands = [
		"volume", "chapter", "section", "subsection", "subsubsection", "title",
		"figure", "quotation", "item", "number", "beginbox", "endbox", "include",
		"begintable", "header", "row", "col", "endtable",
		"meta", "reset", "tex", "preamble", "export", "html", "store", "head"];
	static var horizontalCommands = ["sup", "sub", "emph", "highlight", "url"];
	static var hardSuggestions = [  // some things can't be infered automatically
		"quote" => "quotation",
		"display" => "highlight"
	];

	var parent:Position;
	var location:String;
	var lexer:Lexer;
	var cache:FileCache;
	var next:GenericCell<Token>;

	inline function unexpected(tok:Token, ?desc):Dynamic
		throw new ParserError(tok.pos, UnexpectedToken(tok.def, desc));

	inline function unclosed(tok:Token):Dynamic
		throw new ParserError(tok.pos, UnclosedToken(tok.def));

	inline function missingArg(pos:Position, ?parent:Token, ?desc:String):Dynamic
		throw new ParserError(pos, MissingArgument(parent.def, desc));

	inline function badValue(pos:Position, ?desc:String):Dynamic
		throw new ParserError(pos, BadValue(desc));

	inline function badArg(pos:Position, ?desc:String):Dynamic
		throw new ParserError(pos.offset(1, -1), BadValue(desc));

	inline function invalid(pos:Position, verror:ValidationErrorValue):Dynamic
		throw new ParserError(pos, Invalid(verror));

	inline function unexpectedCmd(cmd:Token):Dynamic
	{
		// EXPERIMENTAL: use Levenshtein distances to generate command suggestions
		// also consider some hard coded suggestions, when necessary

		// Levenshtein distance penalties for the NeedlemanWunsh
		var df = function ( a, b ) return a==b ? 0 : 1;
		var sf = function ( a, b, c ) return 1;

		var name = switch cmd.def {
		case TCommand(n): n;
		case _: unexpected(cmd);
		}
		name = name.toLowerCase();
		var cmds = verticalCommands.concat(horizontalCommands);
		if (Lambda.has(cmds, name))
			throw new ParserError(cmd.pos, UnexpectedCommand(name));
		if (hardSuggestions.exists(name))
			throw new ParserError(cmd.pos, UnknownCommand(name, hardSuggestions[name]));
		var dist = cmds.map(function (x) return x.split(""))
			.map(NeedlemanWunsch.globalAlignment.bind(name.split(""), _, df, sf));
		var best = 0;
		for (i in 1...cmds.length) {
			if (dist[i].distance < dist[best].distance)
				best = i;
		}
		// trace(untyped [cmds[best], dist[best]]);
		throw new ParserError(cmd.pos, UnknownCommand(name, cmds[best]));
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
		return discard(function (x) return x.def.match(TWordSpace(_)|TComment(_)), permanent);

	function discardVerticalNoise(permanent=true):Int
		return discard(function (x) return x.def.match(TWordSpace(_)|TComment(_)|TBreakSpace(_)), permanent);

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

		while (i-- > 0) pop();
		var open = pop();
		if (!open.def.match(TBrkOpen)) missingArg(open.pos, toToken, desc);

		var li = internal({ before : TBrkClose });

		var close = pop();
		if (close.def.match(TEof)) unclosed(open);
		if (!close.def.match(TBrkClose)) unexpected(close);
		return { val:li, pos:open.pos.span(close.pos) };
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
		case { def:TWord(s)|TEscaped(s), pos:pos }:
			pop();
			mk(Word(s), pos);
		case { def:TMath(tex), pos:pos }:
			pop();
			mk(Math(tex), pos);  // FIXME
		case { def:TCode(s), pos:pos }:
			pop();
			mk(InlineCode(s), pos);
		case { def:TCommand("url"), pos:pos }:
			var cmd = pop();
			var address = arg(rawHorizontal, cmd);
			mk(Url(address.val.trim()), cmd.pos.span(address.pos));
		case { def:TCommand(cname), pos:pos } if (Lambda.has(horizontalCommands, cname)):
			var cmd = pop();
			var content = arg(hlist, cmd);
			switch cname {
			case "sup":
				mk(Superscript(content.val), cmd.pos.span(content.pos));
			case "sub":
				mk(Subscript(content.val), cmd.pos.span(content.pos));
			case "emph":
				mk(Emphasis(content.val), cmd.pos.span(content.pos));
			case "highlight":
				mk(Highlight(content.val), cmd.pos.span(content.pos));
			case _:
				unexpected(cmd);
			}
		case { def:TCommand(_) }:
			// vertical commands end the current hlist; unknown commands will be handled later
			null;
		case { def:TAsterisk }:
			mdEmph();
		case { def:TWordSpace(s), pos:pos }:
			pop();
			mk(Wordspace, pos);
		case { def:tdef } if (tdef.match(TBreakSpace(_) | TEof)):
			null;
		case other:
			unexpected(other);
		}
	}

	function hlist(stop:Stop)
		return mkList(horizontal(stop));

	/*
	Read in raw mode

	In this mode, tokens are converted back to their original inputs, with
	the exceptions bellow:
	 - escapes are processed and, thus, retained their interpreted value
	 - comments are discarded
	 - commands are not allowed (the backslash should be escaped)
	
	Note: `\windows` used to be valid in raw mode; however, this caused non
	uniform behavior, since `\03-windows` would fail during lexing.
	*/
	function rawHorizontal(stop:Stop):String
	{
		var buf = new StringBuf();
		while (true) {
			switch peek() {
			case { def:tdef } if (stop.before != null && Type.enumEq(tdef, stop.before)):
				break;
			case { def:tdef } if (stop.beforeAny != null && Lambda.exists(stop.beforeAny,Type.enumEq.bind(tdef))):
				break;
			case { def:TEof }:
				break;
			case { def:TCommand(_) }:
				unexpected(peek());
			case { def:TComment(_) }:
				pop();
			case { def:TEscaped(w) }:
				pop();
				buf.add(w);
			case { src:src, pos:pos }:
				pop();
				buf.add(src);
			}
		}
		return buf.toString();
	}

	function hierarchy(cmd:Token)
	{
		var name = arg(hlist, cmd, "name");
		return switch cmd.def {
		case TCommand("volume"): mk(Volume(name.val), cmd.pos.span(name.pos));
		case TCommand("chapter"): mk(Chapter(name.val), cmd.pos.span(name.pos));
		case TCommand("section"): mk(Section(name.val), cmd.pos.span(name.pos));
		case TCommand("subsection"): mk(SubSection(name.val), cmd.pos.span(name.pos));
		case TCommand("subsubsection"): mk(SubSubSection(name.val), cmd.pos.span(name.pos));
		case TCommand("title"): mk(Title(name.val), cmd.pos.span(name.pos));
		case _: unexpected(cmd);
		}
	}

	function figure(cmd:Token)
	{
		assert(cmd.def.match(TCommand("figure")), cmd);
		var size = blobSize(optArg(rawHorizontal, cmd, "size"), defaultFigureSize);
		var path = arg(rawHorizontal, cmd, "path");
		var caption = arg(hlist, cmd, "caption");
		var copyright = arg(hlist, cmd, "copyright");
		return mk(Figure(size, mk(path.val, path.pos.offset(1,-1)), caption.val, copyright.val), cmd.pos.span(copyright.pos));
	}

	function tableCell(cmd:Token)
	{
		assert(cmd.def.match(TCommand("col")), cmd);
		// TODO handle empty cells
		return vlist({ beforeAny:[TCommand("col"), TCommand("row"), TCommand("endtable")] }, true);
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
		var rows = [];
		discardVerticalNoise();
		if (peek().def.match(TCommand("useimage"))) {
			var path = arg(rawHorizontal, pop(), "path");
			discardVerticalNoise();
			var end = pop();  // should have already discarted any vnoise before
			if (end.def.match(TEof)) unclosed(begin);
			if (!end.def.match(TCommand("endtable"))) unexpected(end);
			return mk(ImgTable(size, caption.val, mk(path.val, path.pos.offset(1,-1))), begin.pos.span(end.pos));
		} else if (peek().def.match(TCommand("header"))) {
			var header = tableRow(pop());
			while (true) {
				discardVerticalNoise();
				if (!peek().def.match(TCommand("row"))) break;
				var beginRow = pop();
				var row = tableRow(beginRow);
				rows.push(row);
				assert(row.length == header.length, row.length, header.length, beginRow.pos.toString());
			}
			var end = pop();  // should have already discarted any vnoise before
			if (end.def.match(TEof)) unclosed(begin);
			if (!end.def.match(TCommand("endtable"))) unexpected(end);
			return mk(Table(size, caption.val, header, rows), begin.pos.span(end.pos));
		} else {
			missingArg(peek().pos, begin, "\\header line");
		}
	}

	function quotation(cmd:Token)
	{
		assert(cmd.def.match(TCommand("quotation")), cmd);
		var text = arg(hlist, cmd, "text");
		var author = arg(hlist, cmd, "author");
		return mk(Quotation(text.val, author.val), cmd.pos.span(author.pos));
	}

	// TODO docs
	function listItem(mark:Token, stop:Stop)
	{
		assert(mark.def.match(TCommand("item" | "number")), mark);
		var item:VElem = switch optArg(vlist.bind(_, true), mark, "item content").cases() {
		case Some(vlist):
			vlist.val.pos = vlist.pos;
			vlist.val;
		case None:
			var st = peek().pos;
			vertical(stop, true).extractOr({
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
		while (peek().def.equals(mark.def)) {
			li.push(listItem(pop(), stop));
			discardNoise();
		}
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
		var li = vlist({ beforeAny:[TCommand("endbox")] }, true);
		discardVerticalNoise();
		var end = pop();
		if (end.def.match(TEof)) unclosed(begin);
		if (!end.def.match(TCommand("endbox"))) unexpected(end);
		return mk(Box(name.val, li), begin.pos.span(end.pos));
	}

	function mkPath(rel:String, pos:Position, allowEmpty=false)
	{
		assert(rel != null);
		if (rel == "") {
			if (allowEmpty)
				return rel;
			badArg(pos, "path cannot be empty");
		}
		if (Path.isAbsolute(rel)) badArg(pos, "path cannot be absolute");
		var path = Path.join([Path.directory(pos.src), rel]);
		return Path.normalize(path);
	}

	function include(cmd:Token)
	{
		assert(cmd.def.match(TCommand("include")), cmd);
		var p = arg(rawHorizontal, cmd);
		var path:PElem = mk(p.val, p.pos);
		var pcheck = Validator.validateSrcPath(path, [Manu]);
		if (pcheck != null)
			return invalid(p.pos, pcheck.err);
		return parse(path.toInputPath(), p.pos, cache);
	}

	function paragraph(stop:Stop)
	{
		var text = hlist(stop);
		if (text.def.match(HEmpty)) return mk(VEmpty, text.pos);  // TODO test
		return mk(Paragraph(text), text.pos);
	}

	function metaReset(cmd:Token)
	{
		assert(cmd.def.match(TCommand("reset")), cmd);
		var name = arg(rawHorizontal, cmd, "counter name");
		var val = arg(rawHorizontal, cmd, "reset value");
		var reg = name.val.trim();
		var no = ~/^[ \t\r\n]*[0-9][0-9]*[ \t\r\n]*$/.match(val.val) ? Std.parseInt(val.val.trim()) : null;
		if (!Lambda.has(["volume","chapter"], reg)) badArg(name.pos, "counter name should be 'volume' or 'chapter'");
		if (no == null || no < 0) badArg(val.pos, "reset value must be strictly greater or equal to zero");
		return mk(MetaReset(reg, no), cmd.pos.span(val.pos));
	}

	function targetInclude(cmd:Token)
	{
		var p = arg(rawHorizontal, cmd, "source path");
		var path = mk(p.val, p.pos.offset(1, -1));
		return switch cmd.def {
		case TCommand("store"): mk(HtmlStore(path), cmd.pos.span(p.pos));
		case TCommand("preamble"): mk(LaTeXPreamble(path), cmd.pos.span(p.pos));
		case _: unexpected(cmd);
		}
	}

	function htmlEmbed(cmd:Token)
	{
		assert(cmd.def.match(TCommand("head")), cmd);
		var p = arg(rawHorizontal, cmd, "html");
		return mk(HtmlToHead(p.val), cmd.pos.span(p.pos));
	}

	function texExport(cmd:Token)
	{
		assert(cmd.def.match(TCommand("export")), cmd);
		var s = arg(rawHorizontal, cmd, "source path");
		var d = arg(rawHorizontal, cmd, "destination path");
		return mk(LaTeXExport(mk(s.val, s.pos.offset(1,-1)), mk(d.val, d.pos.offset(1,-1))), cmd.pos.span(d.pos));
	}

	function meta(meta:Token)
	{
		discardNoise();
		var exec = pop();
		exec.pos = meta.pos.span(exec.pos);
		return switch [meta.def, exec.def] {
		case [TCommand("meta"), TCommand("reset")]: 
			metaReset(exec);
		case [TCommand("html"), TCommand("store")], [TCommand("tex"), TCommand("preamble")]:
			targetInclude(exec);
		case [TCommand("html"), TCommand("head")]:
			htmlEmbed(exec);
		case [TCommand("tex"), TCommand("export")]:
			texExport(exec);
		case _:
			unexpectedCmd(exec);
		}
	}

	function vertical(stop:Stop, restricted:Bool):Nullable<VElem>
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
			case "volume", "chapter", "section", "subsection", "subsubsection", "title":
				if (!restricted || cmdName == "title")
					hierarchy(pop());
				else
					unexpected(pop(), "headings not allowed here");
			case "figure": figure(pop());
			case "begintable": table(pop());
			case "quotation": quotation(pop());
			case "item", "number": list(peek(), stop);
			case "meta", "tex", "html": meta(pop());
			case "beginbox":
				if (!restricted)
					box(pop());
				else
					unexpected(pop(), "boxes not allowed here");
			case "include": include(pop());
			case name if (Lambda.has(horizontalCommands, name)): paragraph(stop);
			case "endbox", "endtable": unexpected(pop(), "no beginning");
			case _: unexpectedCmd(peek()); null;
			}
		case TCodeBlock(c):
			mk(CodeBlock(c), pop().pos);
		case TWord(_), TEscaped(_), TAsterisk, TCode(_), TMath(_):
			paragraph(stop);
		case _:
			unexpected(peek());
		}
	}

	function vlist(stop:Stop, restricted:Bool)
		return mkList(vertical(stop, restricted));

	public function file():File
	{
		switch cache[location] {
		case null:
			var entry = cache[location] = { parent:parent, ast:None };
			var ast = vlist({}, false);
			entry.ast = Some(ast);
			return ast;
		case { parent:original, ast:None }:
			return throw 'Cyclic path: $location already accessed from ${original.toString()}\n  at ${parent.toString()}';
		case { ast:Some(ast) }:
			return ast;
		}
	}

	public function new(location:String, lexer:Lexer, ?parent:Position, ?cache:FileCache)
	{
		this.location = location;
		this.lexer = lexer;
		assert(location == Path.normalize(location), location);
		if (parent == null) parent = { min:0, max:0, src:location };
		this.parent = parent;
		if (cache == null) cache = new FileCache();
		this.cache = cache;
	}

	public static function parse(path:String, ?parent:Position, ?cache:FileCache):File
	{
		// only assert; `\include` performs proper validation, and the
		// entry point is checked on Main.generate
		var p:PElem = mk(path, { src:"./", min:0, max:0 });
		var pcheck = Validator.validateSrcPath(p, [Manu]);
		assert(pcheck == null, pcheck);

		var lex = new Lexer(sys.io.File.getBytes(path), path);
		var parser = new Parser(path, lex, parent, cache);
		return parser.file();
	}
}

