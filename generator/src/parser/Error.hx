package parser;

import parser.Token;

class GenericError {
	var lexer:Lexer;
	public var pos(default,null):Position;

	public function atEof()
		return pos.min != pos.max;

	public function getTextAt()
		return atEof() ? lexer.recover(pos.min, pos.max - pos.min) : "";

	public function getPrettyPosAt()
		return {
			src:pos.src,
			lines:{ min:0, max:0 },  // FIXME
			chars:{ min:pos.min, max:pos.max }  // FIXME
		};

	public function toString()
		return "Unknown error";

	public function toPrettyString()
	{
		var p = getPrettyPosAt();
		if (p.lines.min != p.lines.max)
			return '${p.src}: lines ${p.lines.min}-${p.lines.max}: ${toString()}';
		else
			return '${p.src}: ${p.lines.min}: chars ${p.chars.min}-${p.chars.max}: ${toString()}';
	}

	public function new(lexer, pos)
	{
		this.lexer = lexer;
		this.pos = pos;
	}
}

class UnexpectedToken extends GenericError {
	var unexpected:Token;
	var expected:Null<String>;

	public function new(lexer, unexpected, ?expected)
	{
		this.unexpected = unexpected;
		this.expected = expected;
		super(lexer, unexpected.pos);
	}

	override public function toString()
	{
		var msg = switch unexpected.def {
		case TWordSpace(s):
			'Unexpected interword space (hex: ${hex(s)})';
		case TBreakSpace(s):
			'Unexpected vertical space (hex: ${hex(s)})';
		case TEof:
			"Unexpected end of file";
		case _:
			'Unexpected `${getTextAt()}`';
		}
		if (expected != null)
			msg += '; expected $expected';
		return msg;
	}

	function hex(s:String)
		return haxe.io.Bytes.ofString(s).toHex();
}

class Unclosed extends GenericError {}
class UnknownCommand extends GenericError {}
class MissingArgument extends GenericError {}
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
