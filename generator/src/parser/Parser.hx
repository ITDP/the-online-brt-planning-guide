package parser;  // TODO move out of the package

import haxe.ds.GenericStack.GenericCell;
import parser.Ast;
import parser.Error;
import parser.Token;

import parser.AstTools.*;

using parser.TokenTools;

typedef HOpts = {
	?stopBefore:TokenDef
}

typedef Path = String;
typedef FileCache = Map<Path,File>;

class Parser {
	var lexer:Lexer;
	var cache:FileCache;
	var next:GenericCell<Token>;

	function unexpected(t:Token)
		throw new UnexpectedToken(t);

	function unclosed(name:String, p:Position)
		throw new Unclosed(name, p);

	function missingArg(cmd:Token, ?desc:String)
		throw new MissingArgument(cmd, desc);

	function peek()
	{
		if (next == null)
			next = new GenericCell(lexer.token(Lexer.tokens), null);
		return next.elt;
	}

	function discard()
	{
		var ret = peek();
		next = next.next;
		return ret;
	}

	function emph()
	{
		var cmd = discard();
		if (!cmd.def.match(TCommand("emph"))) unexpected(cmd);
		var open = discard();
		if (!open.def.match(TBrOpen)) unexpected(open);
		var li = hlist({ stopBefore:TBrClose });
		var close = discard();
		if (close.def.match(TEof)) unclosed("argument", open.pos);
		if (!close.def.match(TBrClose)) unexpected(close);
		return mk(Emphasis(li), cmd.pos.span(close.pos));
	}

	function highlight()
	{
		var cmd = discard();
		if (!cmd.def.match(TCommand("highlight"))) unexpected(cmd);
		var open = discard();
		if (!open.def.match(TBrOpen)) unexpected(open);
		var li = hlist({ stopBefore:TBrClose });
		var close = discard();
		if (close.def.match(TEof)) unclosed("argument", open.pos);
		if (!close.def.match(TBrClose)) unexpected(close);
		return mk(Highlight(li), cmd.pos.span(close.pos));
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
		case { def:TCommand("emph") }:
			emph();
		case { def:TCommand(cmdName), pos:pos }:
			switch cmdName {
			case "emph": emph();
			case "highlight": highlight();
			case "volume", "chapter", "section": null;  // vertical commands end the current par
			case _: throw new UnknownCommand(cmdName, pos); null;
			}
		case { def:TAsterisk }:
			mdEmph();
		case { def:TWordSpace(s), pos:pos }:
			discard();
			mk(Wordspace, pos);
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

	function volume()
	{
		var cmd = discard();
		if (!cmd.def.match(TCommand("volume"))) unexpected(cmd);
		var open = discard();
		if (!open.def.match(TBrOpen)) unexpected(open);
		var name = hlist({ stopBefore:TBrClose });
		var close = discard();
		if (close.def.match(TEof)) unclosed("argument", open.pos);
		if (!close.def.match(TBrClose)) unexpected(close);
		if (name == null) missingArg(cmd, "name");
		return mk(Volume(name), cmd.pos.span(close.pos));
	}

	function chapter()
	{
		var cmd = discard();
		if (!cmd.def.match(TCommand("chapter"))) unexpected(cmd);
		var open = discard();
		if (!open.def.match(TBrOpen)) unexpected(open);
		var name = hlist({ stopBefore:TBrClose });
		var close = discard();
		if (close.def.match(TEof)) unclosed("argument", open.pos);
		if (!close.def.match(TBrClose)) unexpected(close);
		if (name == null) missingArg(cmd, "name");
		return mk(Chapter(name), cmd.pos.span(close.pos));
	}

	function section()
	{
		var cmd = discard();
		if (!cmd.def.match(TCommand("section"))) unexpected(cmd);
		var open = discard();
		if (!open.def.match(TBrOpen)) unexpected(open);
		var name = hlist({ stopBefore:TBrClose });
		var close = discard();
		if (close.def.match(TEof)) unclosed("argument", open.pos);
		if (!close.def.match(TBrClose)) unexpected(close);
		if (name == null) missingArg(cmd, "name");
		return mk(Section(name), cmd.pos.span(close.pos));
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
		case TEof: null;
		case TCommand(cmdName):
			switch cmdName {
			case "volume": volume();
			case "chapter": chapter();
			case "section": section();
			case _: paragraph();
			}
		case TWord(_), TAsterisk: paragraph();
		case _: unexpected(peek()); null;
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
		var lex = new Lexer(byte.ByteData.ofString(sys.io.File.getContent(path)));
		var parser = new Parser(lex, cache);
		return parser.file();
	}
}

