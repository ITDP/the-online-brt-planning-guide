package parser;

import parser.Token;

typedef Elem<T> = { def : T, pos : Position };

enum HDef {
	Wordspace;
	Emphasis(el:Elem<HDef>);
	Highlight(el:Elem<HDef>);
	Word(w:String);
	HList(elem:Array<Elem<HDef>>);
}

enum VDef {
	Paragraph(h:Elem<HDef>);
	VList(elem:Array<Elem<VDef>>);
}

typedef VElem = Elem<VDef>;
typedef HElem = Elem<HDef>;

typedef File = VElem;

