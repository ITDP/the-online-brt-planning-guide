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
	Code(c:String);
	HList(elem:Array<HElem>);
}

typedef TableCell = VElem;
typedef TableRow = Array<TableCell>;

enum BlobSize {
	MarginWidth;
	TextWidth;
	FullWidth;
}

enum VDef {
	MetaReset(name:String, val:Int);  // could we make it a hdef?
	HtmlApply(path:String);
	LaTeXPreamble(path:String);
	LaTeXExport(src:String, dest:String);

	Volume(name:HElem);
	Chapter(name:HElem);
	Section(name:HElem);
	SubSection(name:HElem);
	SubSubSection(name:HElem);
	Figure(size:BlobSize, path:String, caption:HElem, copyright:HElem);  // TODO size?
	Table(size:BlobSize, caption:HElem, header:TableRow, rows:Array<TableRow>);  // copyright/source?
	Quotation(text:HElem, by:HElem);
	List(numered:Bool, items:Array<VElem>);
	Box(name:HElem, contents:VElem);
	Paragraph(h:HElem);
	VList(elem:Array<VElem>);
}
// TODO labels?

typedef File = VElem;  // TODO rename, to avoid confusion with sys.io.File
typedef Ast = File;

