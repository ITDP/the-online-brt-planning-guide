package parser;

import parser.Token;
import Assertion.assert;

class TokenTools {
	public static function span(left:Position, right:Position)
	{
		assert(left.src == right.src);  // TODO restore 'cannot span between different files' msg
		assert(left.min <= right.min);  // TODO restore 'inverted positions' msg
		return { src:left.src, min:left.min, max:right.max };
	}
}

