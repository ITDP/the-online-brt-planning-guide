package transform;

import parser.Ast;

typedef Document = TElem;

typedef TElem = Elem<TDef>;

enum TDef {
	TVolume(name : HElem, count : Int, children : TElem);
	TChapter(name : HElem, count : Int, children : TElem);
	TSection(name : HElem, count : Int, children : TElem);
	TSubSection(name : HElem, count : Int, children : TElem);
	TSubSubSection(name : HElem, count : Int, children : TElem);
	
	//TODO: Box
	TVList(elem:Array<TElem>);
	
	TFigure(path:String, caption:HElem, copyright:HElem, count : Int);  // TODO size?
	TQuotation(text:HElem, by:HElem, count : Int);
	TParagraph(h:HElem);	
}

