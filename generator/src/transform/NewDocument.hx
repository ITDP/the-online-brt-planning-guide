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

	// TODO hierarchy
	// TODO box
	// TODO list
	// TODO figure
	// TODO table
	// TODO code block
	// TODO quotation
	// TODO paragraph

	DList(elem:Array<DElem>);
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

