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
		case { def:TGreater }:
			msg.add(" to quotation");
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

class UnclosedToken extends GenericError {
	var def:TokenDef;

	public function new(lexer, tok)
	{
		this.def = tok.def;
		super(lexer, tok.pos);
	}

	override public function get_text()
	{
		return switch def {
		case TBrOpen: "Unclosed braces `{`";
		case TBrkOpen: "Unclosed brackets `{`";
		case other: "Unclosed token " + other;
		}
	}
}

class BadValue extends GenericError {
	var details:Null<String>;

	public function new(lexer, pos, ?details)
	{
		this.details = details;
		super(lexer, pos);
	}

	override public function get_text()
	{
		if (details != null)
			return 'Bad value: `$at` ($details)';
		else
			return 'Bad value: `$at`';
	}
}

class UnexpectedCommand extends GenericError {
	var suggestion:Null<String>;

	override public function get_text()
		return 'Unexpected command $at';
}

class UnknownCommand extends GenericError {
	var suggestion:Null<String>;

	public function new(lexer, pos, ?suggestion)
	{
		this.suggestion = suggestion;
		super(lexer, pos);
	}

	override public function get_text()
	{
		var msg = 'Unknown command $at';
		if (suggestion != null)
			msg += '; did you perhaps mean `\\$suggestion`?  (sorry if the suggestion makes no sense)';
		return msg;
	}
}

