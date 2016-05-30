package parser;

import parser.Token;

typedef LinePosition = {
	src : String,
	lines : { min:Int, max:Int },
	chars : { min:Int, max:Int }
}

class GenericError {
	var lexer:Lexer;
	public var pos(default,null):Position;

	public var text(get,null):String;
		function get_text()
			return "Unknown error";
	public var atEof(get,null):Bool;
		function get_atEof()
			return pos.min != pos.max;
	public var at(get,null):String;
		function get_at()
			return atEof ? lexer.recover(pos.min, pos.max - pos.min) : "";
	public var lpos(get,never):LinePosition;
		function get_lpos()
			return {
				src:pos.src,
				lines:{ min:0, max:0 },  // FIXME
				chars:{ min:pos.min, max:pos.max }  // FIXME
			};

	public function toString()
		return '${pos.src}: ${pos.min}-${pos.max}: $text';

	public function new(lexer, pos)
	{
		this.lexer = lexer;
		this.pos = pos;
	}
}

class UnexpectedToken extends GenericError {
	var def:TokenDef;
	var expDesc:Null<String>;

	public function new(lexer, def, ?expDesc)
	{
		this.def = def.def;
		this.expDesc = expDesc;
		super(lexer, def.pos);
	}

	override public function get_text()
	{
		var msg = switch def {
		case TWordSpace(s):
			'Unexpected interword space (hex: ${hex(s)})';
		case TBreakSpace(s):
			'Unexpected vertical space (hex: ${hex(s)})';
		case TEof:
			"Unexpected end of file";
		case _:
			'Unexpected `$at`';
		}
		if (expDesc != null)
			msg += '; expected $expDesc';
		return msg;
	}

	function hex(s:String)
		return haxe.io.Bytes.ofString(s).toHex();
}

class MissingArgument extends GenericError {
	var toToken:Null<Token>;
	var argDesc:Null<String>;

	public function new(lexer, pos, ?toToken, ?argDesc)
	{
		this.toToken = toToken;
		this.argDesc = argDesc;
		super(lexer, pos);
	}

	override public function get_text()
	{
		var msg = new StringBuf();
		msg.add("Missing ");
		msg.add(argDesc != null ? argDesc : "argument");
		switch toToken {
		case null:  // NOOP
		case { def:TCommand(name) }:
			msg.add(" to \\");
			msg.add(name);
		case { def:TWord(w) } if (Lambda.has(["FIG", "EQ", "TAB"], w)):
			msg.add(" to #");
			msg.add(w);
			msg.add("#");
		case other:
			msg.add(" to token ");
			msg.add(other);
		}
		return msg.toString();
	}
}

class Unclosed extends GenericError {}
class UnknownCommand extends GenericError {}
class InvalidValue extends GenericError {}

// class Unclosed extends Error {
// 	public function new(name:String, pos:Position)
// 		super('Unclosed $name', pos);
// }
//
// class UnknownCommand extends Error {
// 	public function new(name:String, pos:Position)
// 		super('Unknown command `\\$name`', pos);
// }
//
// class MissingArgument extends Error {
// 	public function new(?cmd:Token, ?desc:String)
// 	{
//
// 		if (desc == null) desc = "argument";
// 		switch cmd {
// 		case null:
// 			super('Missing $desc');
// 		case { def:TCommand(name) }:
// 			super('Missing $desc for `\\$name`', cmd.pos);
// 		case other:
// 			trace('Wrong token for a missing argument error: $other should be TCommand');
// 			super('Missing $desc', cmd.pos);
// 		}
// 	}
// }
//
// class InvalidValue extends Error {
// 	public function new(pos:Position, ?desc:String)
// 	{
// 		if (desc == null) desc = "argument";
// 		super('Invalid value for $desc', pos);
// 	}
// }
//
