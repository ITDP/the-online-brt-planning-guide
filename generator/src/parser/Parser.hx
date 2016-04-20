package parser;

import parser.Token;
import parser.Ast;
import haxe.ds.GenericStack.GenericCell;

using parser.TokenTools;

class Parser {
	var lexer:Lexer;
	var next:GenericCell<Token>;

	function error(m:String)
		return throw m;

	function unexpected(t:Token)
		return error('Unexpected `${t}`');

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

	function mk<T>(def:T, pos:Position):Elem<T>
		return { def:def, pos:pos };
	
	function paragraph()
	{
		var buff = new StringBuf();
		var hlist = [];
		
		while (!peek().def.match(TBreakSpace(_) | TEof))
		{
			var elem : Elem<HDef> = {def : null, pos : null};
			switch(peek().def)
			{
				case TWord(_):
					buff.add(peek().def.getParameters()[0]);
				case TWordSpace(_):
					elem = {def : Word(buff.toString()), pos : peek().pos};
					hlist.push(elem);
					buff = new StringBuf();
				default:
					unexpected(peek());
			}			
			next = next.next;			
		}
		
		if (buff.length > 0)
		{
			var elem = {def : Word(buff.toString()), pos : peek().pos};
			hlist.push(elem);
		}
		
		var helem : Elem<HDef> = {def : HList(hlist), pos : hlist[hlist.length - 1].pos};
		
		return mk(Paragraph(helem), hlist[hlist.length - 1].pos);
	}

	function vertical()
	{
		while (peek().def.match(TWordSpace(_) | TBreakSpace(_)))
			discard();
		return switch peek().def {
		case TEof: null;
		case TWord(_): paragraph();
		case _: unexpected(peek());
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
		if (li.length < 2)
			return li[0];
		else
			return mk(VList(li), li[0].pos.span(li[li.length - 1].pos));
	}

	public function file()
		return vertical();

	public function new(lexer:Lexer)
		this.lexer = lexer;
}

