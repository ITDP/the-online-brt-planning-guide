package parser;

import Assertion.*;
import haxe.ds.Option;
import haxe.io.Path;
import parser.Token;
typedef IdCtx = transform.Context.IdCtx;

typedef Elem<T> = { def : T, pos : Position };
typedef VElem = Elem<VDef>;
typedef HElem = Elem<HDef>;

/*
A path element.

Stores the path as it was on the source file and allows lazy checking and resolution of it.
*/
@:forward(pos)
abstract PElem(Elem<String>) from Elem<String> {
	/*
	Computes a path to read from.

	Considers the raw value as a relative path using as basis the directory
	inside which the source file with that value lived.
	*/
	public function toInputPath():String
	{
		assert(this.def != null && this.def != "", this.def);
		var path = Path.join([Path.directory(this.pos.src), this.def]);
		return Path.normalize(path);
	}

	/*
	Computes a path to read from.

	Takes an optional base directory (default: `./`).
	*/
	public function toOutputPath(?base="./"):String
	{
		assert(this.def != null && this.def != "", this.def);
		var path = Path.join([base, this.def]);
		return Path.normalize(path);
	}

	/*
	Expose the raw value (explicitly).
	*/
	public function internal():String
		return this.def;
}

enum RefTarget {
	RVolume;
	RChapter;
	RSection;
	RSubSection;
	RSubSubSection;
	RBox;
	RFigure;
	RTable;
}

enum RefOutput {
	AutoRef;
	NumRef;
	NameRef;
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
	Ref(target:Elem<RefTarget>, output:Elem<RefOutput>, id:Elem<IdCtx>);
	RangeRef(target:Elem<RefTarget>, output:Elem<RefOutput>, id1:Elem<IdCtx>, id2:Elem<IdCtx>);

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

	Id(val:Elem<String>, elem:VElem);
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

