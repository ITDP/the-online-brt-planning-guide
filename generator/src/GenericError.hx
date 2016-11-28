class GenericError {
	public var pos(default,null):Position;

	public var atEof(get,null):Bool;
		inline function get_atEof()
			return pos.min != pos.max;

	public function toString()
		return "Unknown error";

	public function new(pos)
	{
		this.pos = pos;
	}
}

