package parser;

import Assertion.*;
import haxe.ds.Option;
import parser.Token;

typedef Elem<T> = { def : T, pos : Position };
typedef VElem = Elem<VDef>;
typedef HElem = Elem<HDef>;

/*
A path element.

Stores the path as it was on the source file and allows lazy checking and resolution of it.
*/
@:forward(pos)
abstract PElem(Elem<String>) from Elem<String> {
	public function get(?base:Null<String>):String
	{
		if (base == null)
			base = this.pos.src;
		var path = haxe.io.Path.join([haxe.io.Path.directory(base), this.def]);
		return haxe.io.Path.normalize(path);
	}
}

/*
A horizontal element.
*/
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

/*
A vertical element.
*/
enum VDef {
	MetaReset(name:String, val:Int);
	HtmlApply(path:PElem);
	LaTeXPreamble(path:PElem);
	LaTeXExport(src:PElem, dest:PElem);

	Volume(name:HElem);
	Chapter(name:HElem);
	Section(name:HElem);
	SubSection(name:HElem);
	SubSubSection(name:HElem);
	Figure(size:BlobSize, path:PElem, caption:HElem, copyright:HElem);
	Table(size:BlobSize, caption:HElem, header:TableRow, rows:Array<TableRow>);  // copyright/source?
	ImgTable(size:BlobSize, caption:HElem, path:PElem);  // copyright/source?
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

