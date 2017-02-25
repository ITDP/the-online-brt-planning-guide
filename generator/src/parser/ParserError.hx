package parser;

import parser.Token;
import transform.ValidationError;

enum ParserErrorValue {
	InvalidUtf8;
	UnexpectedToken(def:TokenDef, ?desc:String);
	MissingArgument(?parent:TokenDef, ?desc:String);
	UnclosedToken(def:TokenDef);
	BadValue(?details:String);
	UnexpectedCommand(name:String);
	UnknownCommand(name:String, ?suggestion:String);
	Invalid(verror:ValidationErrorValue);
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

	override public function toString()
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
			case TComment(_):
				'Unexpected comment';
			case TMath(_):
				'Unexpected math';
			case TWord(_):
				'Unexpected word';
			case TCode(_), TCodeBlock(_):
				'Unexpected code excerpt ($def)';
			case TCommand(name):
				'Unexpected command \'\\${name}\'';
			case TBrOpen, TBrClose:
				'Unexpected argument delimiter ($def)';
			case TBrkOpen, TBrkClose:
				'Unexpected optional argument delimiter ($def)';
			case TAsterisk:
				'Unexpected emphasis mark \'*\' (tip: to escape it, use \'\\*\')';
			case TEof:
				"Unexpected end of file";
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
			case other:
				msg.add(" to token ");
				msg.add(other);
			}
			return msg.toString();
		case UnclosedToken(def):
			return switch def {
			case TBrOpen: "Unclosed argument (tip: to escape the opening brace, use '\\{')";
			case TBrkOpen: "Unclosed optional argument (tip: to escape the opening bracket, use '\\[')";
			case TAsterisk: "Unclosed emphasis (tip: to escape the opening asterisk, use '\\*')";
			case TCommand("begintable"): "Table never ends (tip: use '\\endtable' to terminate the table)";
			case TCommand("beginbox"): "Box never ends (tip: use '\\endbox' to terminate the box)";
			case TCodeBlock(_): "Code excerpt never ends (tip: use an identical '\\codeblock[text]' to terminate the fence)";
			case TCode(_): "Inline code exceprt never ends (tip: use an identical '\\code<character>' to terminate the fence)";
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
		case Invalid(verror):
			var err = new ValidationError(pos, verror);
			return err.toString();
		}
	}
}

