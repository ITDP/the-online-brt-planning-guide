package parser;

enum TokenDef {
	TEof;

	// Horizonal whitespace
	TWordSpace(s:String);

	// Horizontal element terminator: a visibily empty line(s)
	// this terminates paragraph contents and other horizontal lists
	TBreakSpace(s:String);

	// (Block) comments: begin at \' and end at '\
	TComment(s:String);

	TMath(s : String);

	// Unformated text
	TWord(s:String);

	// Code and/or preformated text (inline)
	TCode(s:String);

	// Code and/or preformated text (block)
	TCodeBlock(s:String);

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

#if !cpp
typedef Token = {
	def : TokenDef,
	pos : Position,
	src : String
}
#else
@:structInit
class Token {
	public var def:TokenDef;
	public var pos:Position;
	public var src:String;
}
#end

