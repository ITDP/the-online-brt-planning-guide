package parser;

import parser.Token;

private class Error {
	var msg:String;
	var pos:Position;

	public function new(msg, ?pos)
	{
		this.msg = msg;
		this.pos = pos;
	}

	public function toString()
	{
		if (pos != null)
			return '${pos.src}:bytes ${pos.min + 1}-${pos.max}: $msg';
		else
			return '$msg';
	}
}

class UnexpectedToken extends Error {
	public function new(tok:Token, lex:Lexer)
	{
		switch tok.def {
		case TWordSpace(s):
			super('Unexpected interword space (hex: ${haxe.io.Bytes.ofString(s).toHex()})', tok.pos);
		case TBreakSpace(s):
			super('Unexpected vertical space (hex: ${haxe.io.Bytes.ofString(s).toHex()})', tok.pos);
		case TEof:
			super("Unexpected end of file", tok.pos);
		case _:
			var str = lex.recover(tok.pos.min, tok.pos.max - tok.pos.min);
			super('Unexpected `$str`', tok.pos);
		}
	}
}

class Unclosed extends Error {
	public function new(name:String, pos:Position)
		super('Unclosed $name', pos);
}

class UnknownCommand extends Error {
	public function new(name:String, pos:Position)
		super('Unknown command `\\$name`', pos);
}

class MissingArgument extends Error {
	public function new(?cmd:Token, ?desc:String)
	{

		if (desc == null) desc = "argument";
		switch cmd {
		case null:
			super('Missing $desc');
		case { def:TCommand(name) }:
			super('Missing $desc for `\\$name`', cmd.pos);
		case other:
			trace('Wrong token for a missing argument error: $other should be TCommand');
			super('Missing $desc', cmd.pos);
		}
	}
}

class InvalidValue extends Error {
	public function new(pos:Position, ?desc:String)
	{
		if (desc == null) desc = "argument";
		super('Invalid value for $desc', pos);
	}
}

