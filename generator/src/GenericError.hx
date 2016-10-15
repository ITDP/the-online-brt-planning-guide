class GenericError {
	public var pos(default,null):Position;

	public var text(get,null):String;
		function get_text()
			return "Unknown error";
	public var atEof(get,null):Bool;
		function get_atEof()
			return pos.min != pos.max;
	public var lpos(get,never):LinePosition;  // TODO cache it automatically
		function get_lpos()
			return PositionTools.toLinePosition(pos);
	public function toString()
		return '${pos.src}: ${pos.min}-${pos.max}: $text';

	public function new(pos)
	{
		this.pos = pos;
	}
}

