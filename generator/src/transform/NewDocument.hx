package transform;

import parser.Ast;

// expose the reused definitions from parser.Ast so that downstream users don't
// need to import both types
// TODO uncomment
// typedef HElem = parser.HElem;
// typedef Position = parser.Token.Position;
// typedef BlobSize = parser.BlobSize;

/*
A document level definition.
*/
enum DDef {
	DHtmlApply(path:String);
	DLaTeXPreamble(path:String);
	DLaTeXExport(src:String, dest:String);

	DVolume(no:Int, name:HElem, children:DElem);
	DChapter(no:Int, name:HElem, children:DElem);
	DSection(no:Int, name:HElem, children:DElem);
	DSubSection(no:Int, name:HElem, children:DElem);
	DSubSubSection(no:Int, name:HElem, children:DElem);
	DBox(no:Int, name:HElem, children:DElem);
	DFigure(no:Int, size:BlobSize, path:String, caption:HElem, copyright:HElem);
	DTable(no:Int, size:BlobSize, caption:HElem, header:Array<DElem>, rows:Array<Array<DElem>>);
	DList(numbered:Bool, li:Array<DElem>);
	DCodeBlock(cte:String);
	DQuotation(text:HElem, by:HElem);
	DParagraph(text:HElem);

	DElemList(li:Array<DElem>);  // TODO rename avoiding confusion with (un)numbered lists
	DEmpty;
}

/*
A document level element.

All document level elements can have (nullable) identifiers.

Identifiers are unique within their scope, that is defined by their tree
structure of the NewDocument tree.  A global unique identifier can be composed
by concatenating all parent types and parent ids to any given element and
element id.
*/
typedef DElem = {
	> Elem<DDef>,
	id:Nullable<String>
}

/*
A document.
*/
typedef NewDocument = DElem;

