package parser;

import parser.Token;
import Assertion.assert;

class TokenTools {
	public static function span(left:Position, right:Position)
	{
		if (left.src != right.src) return left;
		assert(left.min <= right.min, "inverted positions", left, right);
		return { src:left.src, min:left.min, max:right.max };
	}

	public static function offset(pos:Position, left:Int, right:Int)
	{
		assert(pos.min + left <= pos.max + right, "positions will become inverted", pos);
		return { src:pos.src, min:pos.min + left, max:pos.max + right };
	}
}

