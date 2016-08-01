package transform;

import parser.Ast;

typedef Document = TElem;

typedef TElem = Elem<TDef>;

enum TDef {
	TLaTeXPreamble(path:String);
	TLaTeXExport(src:String, dest:String);
	THtmlApply(path:String);

	TVolume(name : HElem, count : Int, id : String, children : TElem);
	TChapter(name : HElem, count : Int, id : String, children : TElem);
	TSection(name : HElem, count : Int, id : String, children : TElem);
	TSubSection(name : HElem, count : Int, id : String, children : TElem);
	TSubSubSection(name : HElem, count : Int, id : String, children : TElem);

	TElemList(elem:Array<TElem>);

	TFigure(size:BlobSize, path:String, caption:HElem, copyright:HElem, count : Int, id : String);  // TODO size?
	TTable(size:BlobSize, caption:HElem, header:Array<TElem>, body:Array<Array<TElem>>, count:Int, id:String);
	TBox(name:HElem, contents:TElem, count:Int, id:String);
	TQuotation(text:HElem, by:HElem);
	TList(numered:Bool, items:Array<TElem>);
	TCodeBlock(c:String);
	TParagraph(h:HElem);
}

