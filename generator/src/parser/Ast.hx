package parser;

import parser.Token;

typedef Elem<T> = { def : T, pos : Position };
typedef VElem = Elem<VDef>;
typedef HElem = Elem<HDef>;

enum HDef {
	Wordspace;
	Superscript(el:HElem);
	Subscript(el:HElem);
	Emphasis(el:HElem);
	Highlight(el:HElem);
	Word(w:String);
	InlineCode(c:String);
	Math(tex:String);

	HElemList(elem:Array<HElem>);
	HEmpty;
}

typedef TableCell = VElem;
typedef TableRow = Array<TableCell>;

enum BlobSize {
	MarginWidth;
	TextWidth;
	FullWidth;
}

enum VDef {
	MetaReset(name:String, val:Int);
	HtmlApply(path:String);
	LaTeXPreamble(path:String);
	LaTeXExport(src:String, dest:String);

	Volume(name:HElem);
	Chapter(name:HElem);
	Section(name:HElem);
	SubSection(name:HElem);
	SubSubSection(name:HElem);
	Figure(size:BlobSize, path:String, caption:HElem, copyright:HElem);
	Table(size:BlobSize, caption:HElem, header:TableRow, rows:Array<TableRow>);  // copyright/source?
	ImgTable(size:BlobSize, caption:HElem, path:String);  // copyright/source?
	Quotation(text:HElem, by:HElem);
	List(numered:Bool, items:Array<VElem>);
	Box(name:HElem, contents:VElem);
	CodeBlock(c:String);
	Paragraph(h:HElem);

	VElemList(elem:Array<VElem>);
	VEmpty;
}
// TODO labels?

typedef File = VElem;  // TODO rename, to avoid confusion with sys.io.File
typedef Ast = File;

