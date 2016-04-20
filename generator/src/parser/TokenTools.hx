package parser;

import parser.Token;

class TokenTools {
	public static function span(left:Position, right:Position)
	{
		if (left.src != right.src) throw "Assert failed: cannot span between different files";
		if (left.min > right.min) throw "Assert failed: inverted positions";
		return { src:left.src, min:left.min, max:right.max };
	}
}

