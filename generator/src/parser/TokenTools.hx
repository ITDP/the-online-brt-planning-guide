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

	public static function toLinePosition(pos:Position):LinePosition
	{
		var input = sys.io.File.getBytes(pos.src);
		var lineMin = 1;
		var lineMax = 1;
		var posLineMin = 0;
		var posLineMax = 0;
		var cur = 0;
		while (cur < pos.min) {
			if (input.get(cur) == "\n".code) {
				lineMin++;
				posLineMin = cur + 1;
			}
			cur++;
		}
		lineMax = lineMin;
		posLineMax = posLineMin;

		var str = input.getString(posLineMin, pos.min - posLineMin);
		str = StringTools.replace(str,"\r","");
		var charMin = haxe.Utf8.length(str);

		while (cur < pos.max) {
			if (input.get(cur) == "\n".code) {
				lineMax++;
				posLineMax = cur + 1;
			}
			cur++;
		}

		var str = input.getString(posLineMax, pos.max - posLineMax);
		str = StringTools.replace(str,"\r","");
		var charMax = haxe.Utf8.length(str);

		return {
			src:pos.src,
			lines:{ min:lineMin, max:lineMax },  
			chars:{ min:charMin, max:charMax }  
		};
	}
}

