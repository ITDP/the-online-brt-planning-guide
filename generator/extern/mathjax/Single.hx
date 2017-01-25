package mathjax;

@:enum abstract SingleTypesetFormat(String) {
	public var TEX = "TeX";
}

typedef SingleTypesetData = {
	math:String,
	format:SingleTypesetFormat,
	mml:Bool,
	svg:Bool
}

typedef SingleTypesetResult = {
	errors:Null<Array<String>>
}

/**
Externs for MathJax-node mj-single.js

Documentation taken from the original source.
**/
#if nodejs
@:jsRequire("mathjax-node/lib/mj-single.js")
#else
#error "MathJax-node requires Node.js.  Compile with `-lib hxnodejs`."
#end
extern class Single {
	/**
	The API call to typeset an equation.
	**/
	public static function typeset(data:Dynamic, cback:Dynamic->Void):Void;

	/**
	Configure MathJax and the API.

	You can pass additional configuration options to MathJax using the
	MathJax property, and can set displayErrors and displayMessages
	that control the display of error messages, and extensions to add
	additional MathJax extensions to the base or to sub-categories.

	E.g.
		mjAPI.config({
			MathJax: {SVG: {font: "STIX-Web"}},
			displayErrors: false,
			extensions: 'Safe,TeX/noUndefined'
		});
	**/
	public static function config(cfg:Dynamic):Void;

	/**
	Manually start MathJax (this is done automatically
	when the first typeset() call is made).
	**/
	public static function start():Void;
}

