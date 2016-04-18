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
}

typedef Token = {
	def : TokenDef,
	pos : Position
}

