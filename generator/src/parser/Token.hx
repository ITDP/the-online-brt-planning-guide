package parser;

typedef Position = {
	src : String,
	min : Int,
	max : Int
}

typedef LinePosition = {
	src : String,
	lines : { min:Int, max:Int },
	codes : { min:Int, max:Int }  // unicode code points
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

	TMath(s : String);

	// Unformated text
	TWord(s:String);

	// Code and/or preformated text
	TCode(s:String);

	// Commands : Usually they follow this syntax \command {param} [opt]
	TCommand(s : String);

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
	// This token is used for all fancy commands
	// e.g:
	// Fancy syntax for Section: \section {desc} => ### desc;
	// Subsection \subsection {desc} => ## desc
	// \figure => #FIG# == THashes(1) + TWord(FIG) + THashes(1)
	THashes(q : Int);


	TColon(q : Int);
	TAsterisk;
	TAt;
	//Used for Quotes
	TGreater;
}

typedef Token = {
	def : TokenDef,
	pos : Position
}

