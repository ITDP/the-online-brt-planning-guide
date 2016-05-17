package parser;

import parser.Token;

private class Error {
	var msg:String;
	var pos:Position;

	public function new(msg, pos)
	{
		this.msg = msg;
		this.pos = pos;
	}

	public function toString()
		return '${pos.src}:bytes ${pos.min + 1}-${pos.max}: $msg';
}

class UnexpectedToken extends Error {
	var tok:Token;

	public function new(tok)
	{
		this.tok = tok;
		super('Unexpected `${tok.def}`', tok.pos);
	}
}

class Unclosed extends Error {
	public function new(name, pos)
		super('Unclosed $name', pos);
}

class UnknownCommand extends Error {
	public function new(name, pos)
		super('Unknown command \\$name', pos);
}

class MissingArgument extends Error {
	public function new(cmd:Token, ?desc:String)
	{
		if (desc == null) desc = "argument";
		switch cmd.def {
		case TCommand(name):
			super('Missing $desc to \\$name', cmd.pos);
		case other:
			trace('Assert failed: $other should be TCommand');
			super('Missing $desc', cmd.pos);
		}
	}
}

