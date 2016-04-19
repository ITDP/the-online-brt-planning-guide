package parser;

import parser.Token;
import parser.Ast;

class Parser {
	var lexer:Lexer;

	public function new(lexer:Lexer)
	{
		this.lexer = lexer;
	}
}

