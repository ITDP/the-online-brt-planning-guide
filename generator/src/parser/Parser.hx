package parser;

import haxe.ds.GenericStack.GenericCell;
import parser.Ast;
import parser.Token;

import parser.AstTools.*;

using parser.TokenTools;

typedef HOpts = {
	?stopBefore:TokenDef
}

class Parser {
	var lexer:Lexer;
	var next:GenericCell<Token>;

	function error(m:String, p:Position)
		throw '${p.src}:${p.min}-${p.max}: $m';

	function unexpected(t:Token)
		error('Unexpected `${t.def}`', t.pos);

	function unclosed(name:String, p:Position)
		error('Unclosed $name', p);

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
		if (!close.def.match(TBrClose)) unclosed("argument", open.pos);
		return mk(Emphasis(li), cmd.pos.span(close.pos));
	}

	function mdEmph()
	{
		var open = discard();
		if (!open.def.match(TAsterisk(_))) unexpected(open);
		var li = hlist({ stopBefore:open.def });
		var close = discard();
		if (!Type.enumEq(close.def, open.def)) unclosed('(markdown) emphasis', open.pos);
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
		case { def:TAsterisk(q) } if (q > 0 && q <= 2):
			mdEmph();
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
		case TWord(_), TCommand(_), TAsterisk(_): paragraph();
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

