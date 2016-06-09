package transform;

import parser.Ast;

typedef Document = TElem;

typedef TElem = Elem<TDef>;

enum TDef {
	TLaTeXPreamble(path:String);
	THtmlApply(path:String);

	TVolume(name : HElem, count : Int, id : String, children : TElem);
	TChapter(name : HElem, count : Int, id : String, children : TElem);
	TSection(name : HElem, count : Int, id : String, children : TElem);
	TSubSection(name : HElem, count : Int, id : String, children : TElem);
	TSubSubSection(name : HElem, count : Int, id : String, children : TElem);

	//TODO: Box
	TVList(elem:Array<TElem>);

	TFigure(path:String, caption:HElem, copyright:HElem, count : Int, id : String);  // TODO size?
	TTable(caption:HElem, header:Array<TElem>, body:Array<Array<TElem>>, count:Int, id:String);
	TBox(contents:TElem);
	TQuotation(text:HElem, by:HElem);
	TList(items:Array<TElem>);
	TParagraph(h:HElem);
}

typedef HElem = parser.HElem;
typedef Position = parser.Token.Position;

enum HTokenDef
{
	TWord(a : String);
	Space;
	Emph;
	High;
	LiStart;
	LiEnd;
}

typedef HToken = Elem<HTokenDef>;