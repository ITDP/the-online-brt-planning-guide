package parser;

typedef Position = {
	src : String,
	min : Int,
	max : Int
}

enum TokenDef {
	TEof;

	// Horizonal whitespace
	TWordSpace(s:String);

	// Horizontal element terminator: a visibily empty line(s)
	// this terminates paragraph contents and other horizontal lists
	TBreakSpace(s:String);

	// Line comments: begin at // and end at the first newline
	TLineComment(s:String);

	// Block comments: begin at /* and at */
	TBlockComment(s:String);

	// Unformated text
	TWord(s:String);
	
	// Commands : Usually they follow this syntax \command {param} [opt]
	TCommand(s : String);
	
	// Fancy Commands : A markdown-like approach to the command - 
	// Usually they're easier to read than commands, but they're somewhat simplified
	TFancy(s : String);
	
	// Braces - Important for the command syntax - 
	// They define the obligatory params, e.g:
	// \title {My Great Title!}
	TBrOpen;
	TBrClose;
	
	// Brackets - They define optional parameters, e.g:
	// \figure {path|subtitle} [author|copyright]
	TBrkOpen;
	TBrkClose;
	
	// Hashes(int qty): Quantity of hashes - 
	// This token is a fancy syntax for section (###)
	// and subsection (##)
	THashes(q : Int);
	
}

typedef Token = {
	def : TokenDef,
	pos : Position
}

