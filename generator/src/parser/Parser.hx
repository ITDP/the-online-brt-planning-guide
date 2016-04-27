package parser;

import haxe.ds.GenericStack.GenericCell;
import parser.Ast;
import parser.Token;

import parser.AstTools.*;

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

	function horizontal()
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
		case { def:TCommand(s), pos:pos }:
			discard();
			mk(Word(s), pos);  // FIXME
		case { def:TWordSpace(s), pos:pos }:
			discard();
			mk(Wordspace, pos);
		case { def:TBreakSpace(s) }:
			null;
		case { def:TEof }:
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
		case TWord(_): paragraph();
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

