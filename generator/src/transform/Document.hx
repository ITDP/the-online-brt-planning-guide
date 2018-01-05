/*
A structured document

A tree of what we want to generate.
*/

package transform;

import parser.Ast;

/*
Expose reused parser.Ast types, users shouldn't need to import both modules
*/
typedef Elem<T> = parser.Elem<T>;
typedef PElem = parser.PElem;
typedef HElem = parser.HElem;
typedef BlobSize = parser.BlobSize;
typedef RefType = parser.RefType;

/**
A structured document
**/
typedef Document = DElem;

/**
A document level element
**/
typedef DElem = Elem<DDef>;

/**
A document level definition
**/
enum DDef {
	/*
	Special purpose definitions
	*/
	DHtmlStore(path:PElem);
	DHtmlToHead(template:String);
	DLaTeXPreamble(path:PElem);
	DLaTeXExport(src:PElem, dest:PElem);

	/*
	Definitions that correspond to elements with ids and numbers
	*/
	DVolume(id:String, no:String, name:HElem, children:DElem);
	DChapter(id:String, no:String, name:HElem, children:DElem);
	DSection(id:String, no:String, name:HElem, children:DElem);
	DSubSection(id:String, no:String, name:HElem, children:DElem);
	DSubSubSection(id:String, no:String, name:HElem, children:DElem);
	DBox(id:String, no:String, name:HElem, children:DElem);
	DFigure(id:String, no:String, size:BlobSize, path:PElem, caption:HElem, copyright:HElem);
	DTable(id:String, no:String, size:BlobSize, caption:HElem, header:Row, rows:Array<Row>);
	DImgTable(id:String, no:String, size:BlobSize, caption:HElem, path:PElem);

	/*
	Other definitions
	*/
	DTitle(name:HElem);  // differently than a (sub)*section, titles have no contents
	DList(numbered:Bool, li:Array<DElem>);
	DCodeBlock(cte:String);
	DQuotation(text:HElem, by:HElem);
	DParagraph(text:HElem);

	/*
	Structural definitions
	*/
	DElemList(li:Array<DElem>);
	DEmpty;
}

private typedef Row = Array<DElem>;

