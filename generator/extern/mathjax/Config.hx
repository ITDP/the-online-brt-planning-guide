package mathjax;

typedef Config = {
	/*
	Log Message.Set() calls.  [default: false]
	*/
	?displayMessages:Bool,

	/*
	Show error messages on the console.  [default: true]
	*/
	?displayErrors:Bool,

	/*
	Save undefined characters in the error array.  [default: false]
	*/
	?undefinedCharError:Bool,

	/*
	Additional extensions.
	*/
	?extensions:String,

	/*
	Location for web fonts for CHTML.
	*/
	?fontURL:String,

	?MathJax:Dynamic
}

