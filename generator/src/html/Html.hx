package html;

abstract Html(String) to String {
	public inline function new(raw)
		this = raw;

	@:from public inline static function fromString(unsafe:String):Html
		return new Html(StringTools.htmlEscape(unsafe));
}

