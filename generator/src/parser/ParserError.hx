package parser;

import parser.Token;

enum ParserErrorValue {
	InvalidUtf8;
	UnexpectedToken(def:TokenDef, ?desc:String);
	MissingArgument(?parent:TokenDef, ?desc:String);
	UnclosedToken(def:TokenDef);
	BadValue(?details:String);
	UnexpectedCommand(name:String);
	UnknownCommand(name:String, ?suggestion:String);
}

class ParserError extends GenericError {
	public var err(default,null):ParserErrorValue;

	public function new(pos, err)
	{
		super(pos);
		this.err= err;
	}

	function hex(s:String)
		return haxe.io.Bytes.ofString(s).toHex();

	override function get_text() 
	{
		switch err {
		case InvalidUtf8:
			return "Text in unsupported encoding or invalid UTF-8";
		case UnexpectedToken(def, desc):
			var msg = switch def {
			case TWordSpace(s):
				'Unexpected interword space (0x${hex(s)})';
			case TBreakSpace(s):
				'Unexpected vertical space (0x${hex(s)})';
			case TEof:
				"Unexpected end of file";
			case other:
				'Unexpected $other';
			}
			if (desc != null)
				msg += '; $desc';
			return msg;
		case MissingArgument(parent, desc):
			var msg = new StringBuf();
			msg.add("Missing ");
			msg.add(desc != null ? desc : "argument");
			switch parent {
			case null:  // NOOP
			case TCommand(name):
				msg.add(" to \\");
				msg.add(name);
			case TGreater:
				msg.add(" to quotation");
			case TWord(w) if (Lambda.has(["FIG", "EQ", "TAB"], w)):
				msg.add(" to #");
				msg.add(w);
				msg.add("#");
			case other:
				msg.add(" to token ");
				msg.add(other);
			}
			return msg.toString();
		case UnclosedToken(def):
			return switch def {
			case TBrOpen: "Unclosed braces '{'";
			case TBrkOpen: "Unclosed brackets '{'";
			case TCode(_): "Unclosed code excerpt";
			case other: "Unclosed token " + other;
			}
		case BadValue(details):
			if (details != null)
				return 'Bad value ($details)';
			else
				return 'Bad value';
		case UnexpectedCommand(name):
			return 'Unexpected command \\$name';
		case UnknownCommand(name, suggestion):
			var msg = 'Unknown command \\$name';
			if (suggestion != null)
				msg += '; did you perhaps mean \'\\$suggestion\'?  (sorry if the suggestion makes no sense)';
			return msg;
		}
	}
}

