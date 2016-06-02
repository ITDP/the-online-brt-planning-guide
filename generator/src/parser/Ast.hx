package parser;

import parser.Token;

typedef Elem<T> = { def : T, pos : Position };
typedef VElem = Elem<VDef>;
typedef HElem = Elem<HDef>;

enum HDef {
	Wordspace;
	Emphasis(el:HElem);
	Highlight(el:HElem);
	Word(w:String);
	HList(elem:Array<HElem>);
}

enum VDef {
	Volume(name:HElem);
	Chapter(name:HElem);
	Section(name:HElem);
	SubSection(name:HElem);
	SubSubSection(name:HElem);
	Figure(path:String, caption:HElem, copyright:HElem);  // TODO size?
	Quotation(text:HElem, by:HElem);
	List(items:Array<VElem>);
	MetaReset(name:String, val:Int);
	Paragraph(h:HElem);
	VList(elem:Array<VElem>);
}
// TODO labels?

typedef File = VElem;  // TODO rename, to avoid confusion with sys.io.File
typedef Ast = File;

