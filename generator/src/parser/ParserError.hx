package parser;

import parser.Token;

class ParserError extends GenericError {
	var lexer:Lexer;

	public var at(get,null):String;
		function get_at()
			return atEof ? lexer.recover(pos.min, pos.max - pos.min) : "";

	override function get_text()
		return "Unknown parsing error";

	public function new(lexer, pos)
	{
		this.lexer = lexer;
		super(pos);
	}
}

class UnexpectedToken extends ParserError {
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

class MissingArgument extends ParserError {
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

class UnclosedToken extends ParserError {
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
		case TCode(_): "Unclosed code excerpt";
		case other: "Unclosed token " + other;
		}
	}
}

class BadValue extends ParserError {
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

class UnexpectedCommand extends ParserError {
	var suggestion:Null<String>;

	override public function get_text()
		return 'Unexpected command $at';
}

class UnknownCommand extends ParserError {
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

