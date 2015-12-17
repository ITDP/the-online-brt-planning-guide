package format;

typedef Pos = {
	fileName : String,
	lineNumber : Int
}

typedef Expr<Def> = {
	expr : Def,
	pos : Pos
}

typedef HList = Array<Expr<HDef>>;

typedef VList = Array<Expr<VDef>>;

enum HDef {
	HText(text:String);
	HEmph(hlist:HList);
	HHighlight(hlist:HList);
	// HMath(tex:String);
}

// typedef Image = {
// 	path : String,
// 	size : ImageSize,
// 	placement : ImagePlacement
// }

// typedef Table = {
// 	header : Array<HList>,
// 	data : Array<Array<HList>>
// }

enum VDef {
	VPar(hlist:HList);
	VSection(label:String, name:HList, contents:VList);
	// VFig(label:String, caption:HList, copyright:HList, image:Image);
	// VTable(label:String, title:HList, table:Table);
}

typedef Document = VList;

