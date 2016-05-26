package parser;  // TODO move out of the package

import haxe.ds.GenericStack.GenericCell;
import parser.Ast;
import parser.Error;
import parser.Token;

import Assertion.assert;
import parser.AstTools.*;

using StringTools;
using parser.TokenTools;

typedef HOpts = {
	?stopBefore:TokenDef
}

typedef Path = String;
typedef FileCache = Map<Path,File>;

class Parser {
	static var horizontalCommands = ["emph", "highlight"];

	var lexer:Lexer;
	var cache:FileCache;
	var next:GenericCell<Token>;

	inline function unexpected(t:Token)
		throw new UnexpectedToken(t, lexer);

	inline function unclosed(name:String, p:Position)
		throw new Unclosed(name, p);

	inline function missingArg(cmd:Token, ?desc:String)
		throw new MissingArgument(cmd, desc);

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

	function discard()
	{
		var ret = peek();
		next = next.next;
		return ret;
	}

	function emphasis(cmd:Token)
	{
		var content = arg(hlist);
		return switch cmd.def {
		case TCommand("emph"): mk(Emphasis(content.val), cmd.pos.span(content.pos));
		case TCommand("highlight"): mk(Highlight(content.val), cmd.pos.span(content.pos));
		case _: unexpected(cmd); null;
		}
	}

	function mdEmph()
	{
		var open = discard();
		if (!open.def.match(TAsterisk)) unexpected(open);
		var li = hlist({ stopBefore:TAsterisk });
		var close = discard();
		if (!close.def.match(TAsterisk)) unclosed('(markdown) emphasis', open.pos);
		return mk(Emphasis(li), open.pos.span(close.pos));
	}

	function horizontal(opts:HOpts)
	{
		while (peek().def.match(TLineComment(_) | TBlockComment(_)))
			discard();
		return switch peek() {
		case { def:tdef } if (opts.stopBefore != null && Type.enumEq(tdef, opts.stopBefore)):
			null;
		case { def:TWord(s), pos:pos }:
			discard();
			mk(Word(s), pos);
		case { def:TMath(s), pos:pos }:
			discard();
			mk(Word(s), pos);  // FIXME
		case { def:TCommand(cmdName), pos:pos }:
			switch cmdName {
			case "emph", "highlight": emphasis(discard());
			case _: null;  // vertical commands end the current hlist; unknown commands will be handled later
			}
		case { def:TAsterisk }:
			mdEmph();
		case { def:TWordSpace(s), pos:pos }:
			discard();
			mk(Wordspace, pos);
		case { def:TColon(q), pos:pos } if (q != 3):
			discard();
			mk(Word("".rpad(":", q)), pos);
		case { def:tdef } if (tdef.match(TBreakSpace(_) | TEof)):
			null;
		case other:
			unexpected(other); null;
		}
	}

	function hlist(opts:HOpts)
	{
		var li = [];
		while (true) {
			var v = horizontal(opts);
			if (v == null) break;
			li.push(v);
		}
		return mkList(HList(li));
	}

	function rawHorizontal(opts:HOpts)
	{
		var buf = new StringBuf();
		while (true) {
			switch peek() {
			case { def:tdef } if (opts.stopBefore != null && Type.enumEq(tdef, opts.stopBefore)):
				break;
			case { def:TBreakSpace(_) } | { def:TEof }:
				break;
			case { def:TBlockComment(_) } | { def:TLineComment(_) }:  // not sure about this
				discard();
			case { def:def, pos:pos }:
				discard();
				buf.add(lexer.recover(pos.min, pos.max - pos.min));
			}
		}
		return buf.toString();
	}

	function arg<T>(internal:HOpts->T):{ val:T, pos:Position }
	{
		while (peek().def.match(TWordSpace(_)))
			discard();
		var open = discard();
		if (!open.def.match(TBrOpen)) unexpected(open);

		var li = internal({ stopBefore : TBrClose });

		var close = discard();
		if (close.def.match(TEof)) unclosed("argument", open.pos);
		if (!close.def.match(TBrClose)) unexpected(close);
		return { val:li, pos:open.pos.span(close.pos) };
	}

	function hierarchy(cmd:Token)
	{
		var name = arg(hlist);
		if (name.val == null) missingArg(cmd, "name");
		return switch cmd.def {
		case TCommand("volume"): mk(Volume(name.val), cmd.pos.span(name.pos));
		case TCommand("chapter"): mk(Chapter(name.val), cmd.pos.span(name.pos));
		case TCommand("section"): mk(Section(name.val), cmd.pos.span(name.pos));
		case TCommand("subsection"): mk(SubSection(name.val), cmd.pos.span(name.pos));
		case TCommand("subsubsection"): mk(SubSubSection(name.val), cmd.pos.span(name.pos));
		case _: unexpected(cmd); null;
		}
	}

	function mdHeading(hashes:Token)
	{
		while (peek().def.match(TWordSpace(_)))  // TODO maybe add this to hlist?
			discard();
		var name = hlist({});
		assert(name != null, "obvisouly empty header");  // FIXME maybe

		return switch hashes.def {
		case THashes(1): mk(Section(name), hashes.pos.span(name.pos));
		case THashes(2): mk(SubSection(name), hashes.pos.span(name.pos));
		case THashes(3): mk(SubSubSection(name), hashes.pos.span(name.pos));
		case _: unexpected(hashes); null;  // TODO informative error about wrong number of hashes
		}
	}

	function figure(cmd:Token)
	{
		assert(cmd.def.match(TCommand("figure")), cmd);
		var path = arg(rawHorizontal);
		var caption = arg(hlist);
		var copyright = arg(hlist);
		if (path.val == null) missingArg(cmd, "path");
		if (caption.val == null) missingArg(cmd, "caption");
		if (copyright.val == null) missingArg(cmd, "copyright");
		return mk(Figure(path.val, caption.val, copyright.val), cmd.pos.span(copyright.pos));
	}

	function quotation(cmd:Token)
	{
		assert(cmd.def.match(TCommand("quotation")), cmd);
		var text = arg(hlist);
		var author = arg(hlist);
		if (text.val == null) missingArg(cmd, "text");
		if (author.val == null) missingArg(cmd, "author");
		return mk(Quotation(text.val, author.val), cmd.pos.span(author.pos));
	}

	function mdQuotation(greaterThan:Token)
	{
		assert(greaterThan.def.match(TGreater), greaterThan);
		while (peek().def.match(TWordSpace(_)))  // TODO maybe add this to hlist?
			discard();
		var text = hlist({ stopBefore:TAt });
		var at = discard();
		if (!at.def.match(TAt)) unexpected(at);
		var author = hlist({});
		return mk(Quotation(text, author), greaterThan.pos.span(author.pos));
	}

	function paragraph()
	{
		var text = hlist({});
		if (text == null) return null;
		return mk(Paragraph(text), text.pos);
	}

	function vertical()
	{
		while (peek().def.match(TWordSpace(_) | TBreakSpace(_)))
			discard();
		return switch peek().def {
		case TEof:
			null;
		case TCommand(cmdName):
			switch cmdName {
			case "volume", "chapter", "section", "subsection", "subsubsection": hierarchy(discard());
			case "figure": figure(discard());
			case "quotation": quotation(discard());
			case name if (Lambda.has(horizontalCommands, name)): paragraph();
			case _: throw new UnknownCommand(cmdName, peek().pos);
			}
		case THashes(_) if (!peek(1).def.match(TWord("FIG") | TWord("EQ") | TWord("TAB"))):
			mdHeading(discard());
		case TGreater:
			mdQuotation(discard());
		case TWord(_), TAsterisk:
			paragraph();
		case TColon(q) if (q != 3):
			paragraph();
		case _:
			unexpected(peek()); null;
		}
	}

	function vlist()
	{
		var li = [];
		while (true) {
			var v = vertical();
			if (v == null) break;
			li.push(v);
		}
		return mkList(VList(li));
	}

	public function file():File
		return vlist();

	public function new(lexer:Lexer, ?cache:FileCache)
	{
		this.lexer = lexer;
		if (cache == null) cache = new FileCache();
		this.cache = cache;
	}

	public static function parse(path:String, ?cache:FileCache)
	{
		var lex = new Lexer(sys.io.File.getBytes(path), path);
		var parser = new Parser(lex, cache);
		return parser.file();
	}
}

