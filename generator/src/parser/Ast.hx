package parser;

import parser.Token;

typedef Elem<T> = { def : T, pos : Position };

enum HDef {
	Wordspace(src:String);
	Word(w:String);
	HList(elem:Array<Elem<HDef>>);
}

enum VDef {
	Paragraph(h:Elem<HDef>);
	VList(elem:Array<Elem<VDef>>);
}

typedef File = Elem<VDef>;

