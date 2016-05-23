package parser;

import parser.Token;
import Assertion.assert;

class TokenTools {
	public static function span(left:Position, right:Position)
	{
		assert(left.src == right.src, "cannot span between different files");
		assert(left.min <= right.min, "inverted positions");
		return { src:left.src, min:left.min, max:right.max };
	}
}

