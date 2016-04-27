package parser;

import haxe.ds.GenericStack.GenericCell;
import parser.Ast;
import parser.Token;

import parser.AstTools.*;

using parser.TokenTools;

class Parser {
	var lexer:Lexer;
	var next:GenericCell<Token>;

	function error(m:String)
		throw m;

	function unexpected(t:Token)
		error('Unexpected `${t.def}` at ${t.pos.src}:${t.pos.min}-${t.pos.max}');

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
		if (!cmd.def.match(TCommand("emph"))) unexpected(peek());
		var open = discard();
		if (!open.def.match(TBrOpen)) unexpected(peek());
		var helem = horizontal(false);
		var close = discard();
		if (!close.def.match(TBrClose)) unexpected(peek());
		return mk(Emphasis(helem), cmd.pos.span(close.pos));
	}

	function horizontal(?parmode=true)
	{
		while (peek().def.match(TLineComment(_) | TBlockComment(_)))
			discard();
		return switch peek() {
		case { def:TWord(s), pos:pos }:
			discard();
			mk(Word(s), pos);
		case { def:TMath(s), pos:pos }:
			discard();
			mk(Word(s), pos);  // FIXME
		case { def:TCommand("emph") }:
			emph();
		case { def:TCommand(s), pos:pos }:
			discard();
			mk(Word(s), pos);  // FIXME
		case { def:TWordSpace(s), pos:pos }:
			discard();
			mk(Wordspace, pos);
		case { def:tdef } if (tdef.match(TBreakSpace(_) | TEof)):
			null;
		case other:
			unexpected(other); null;
		}
	}

	function hlist()
	{
		var li = [];
		while (true) {
			var v = horizontal();
			if (v == null) break;
			li.push(v);
		}
		return mkList(HList(li));
	}

	function paragraph()
	{
		var text = hlist();
		if (text == null) return null;
		return mk(Paragraph(text), text.pos);
	}

	function vertical()
	{
		while (peek().def.match(TWordSpace(_) | TBreakSpace(_)))
			discard();
		return switch peek().def {
		case TEof: null;
		case TWord(_), TCommand(_): paragraph();
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

	public function file()
		return vlist();

	public function new(lexer:Lexer)
		this.lexer = lexer;
}

