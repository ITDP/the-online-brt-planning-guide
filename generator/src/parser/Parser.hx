package parser;  // TODO move out of the package

import haxe.ds.GenericStack.GenericCell;
import parser.Ast;
import parser.Error;
import parser.Token;

import Assertion.assert;
import parser.AstTools.*;

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

	function unexpected(t:Token)
		throw new UnexpectedToken(t, lexer);

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

	function emph(cmd:Token)
	{
		assert(cmd.def.match(TCommand("emph")), cmd);
		var content = harg();
		return mk(Emphasis(content.hlist), cmd.pos.span(content.pos));
	}

	function highlight(cmd:Token)
	{
		assert(cmd.def.match(TCommand("highlight")), cmd);
		var content = harg();
		return mk(Highlight(content.hlist), cmd.pos.span(content.pos));
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
			case "emph": emph(discard());
			case "highlight": highlight(discard());
			case _: null;  // vertical commands end the current hlist; unknown commands will be handled later
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

	function harg()
	{
		var open = discard();
		if (!open.def.match(TBrOpen)) unexpected(open);

		var li = hlist({ stopBefore : TBrClose });

		var close = discard();
		if (close.def.match(TEof)) unclosed("argument", open.pos);
		if (!close.def.match(TBrClose)) unexpected(close);
		return { hlist:li, pos:open.pos.span(close.pos) };
	}

	function heading(cmd:Token)
	{
		var name = harg();
		if (name.hlist == null) missingArg(cmd, "name");
		return switch cmd.def {
		case TCommand("volume"): mk(Volume(name.hlist), cmd.pos.span(name.pos));
		case TCommand("chapter"): mk(Chapter(name.hlist), cmd.pos.span(name.pos));
		case TCommand("section"): mk(Section(name.hlist), cmd.pos.span(name.pos));
		case TCommand("subsection"): mk(SubSection(name.hlist), cmd.pos.span(name.pos));
		case TCommand("subsubsection"): mk(SubSubSection(name.hlist), cmd.pos.span(name.pos));
		case _: unexpected(cmd); null;
		}
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
			case "volume", "chapter", "section": heading(discard());
			case name if (Lambda.has(horizontalCommands, name)): paragraph();
			case _: throw new UnknownCommand(cmdName, peek().pos);
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
		var lex = new Lexer(sys.io.File.getBytes(path), path);
		var parser = new Parser(lex, cache);
		return parser.file();
	}
}

