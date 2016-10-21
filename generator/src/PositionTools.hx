import Assertion.*;

class PositionTools {
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

	/**
	Convert Position into LinePosition.

	This _slow_ operation counts lines and code points from Position.src to
	generate an appropriate LinePosition object.

	Note: this does not work correctly on inputs with CR-only line breaks.
	**/
	public static function toLinePosition(pos:Position):LinePosition
	{
		var input = sys.io.File.getBytes(pos.src);
		var lineMin = 0;
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
		lineMax = lineMin + 1;
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
			codes:{ min:charMin, max:charMax }
		};
	}

	public static function toPosition(p:hxparse.Position):Position
	{
		return {
			src : p.psource,
			min : p.pmin,
			max : p.pmax
		}
	}

	public static function toString(p:Position):String
	{
		var lpos = toLinePosition(p);
		if (lpos.lines.min != lpos.lines.max - 1)
			return '${p.src}, from (line=${lpos.lines.min+1}, column=${lpos.codes.min+1}) to (line=${lpos.lines.max}, column=${lpos.codes.max})';
		else if (lpos.codes.min < lpos.codes.max - 1)
			return '${p.src}, line=${lpos.lines.min+1}, columns=(${lpos.codes.min+1} to ${lpos.codes.max})';
		else
			return '${p.src}, line=${lpos.lines.min+1}, column=${lpos.codes.min+1}';
	}

	public static function getBytesAt(p:Position):haxe.io.Bytes
		return sys.io.File.getBytes(p.src).sub(p.min, p.max - p.min);

	public static function getTextAt(p:Position):String
		return getBytesAt(p).toString();

	public static function highlight(p:Position, ?lineLength:Null<Int>):{ line:String, start:Int, finish:Int }
	{
		var input = sys.io.File.getBytes(p.src);
		var pos = 0, lmin = 0;
		while (pos < p.min) {
			if (input.get(pos) == "\n".code)
				lmin = pos + 1;
			pos++;
		}
		var pos = p.max, lmax = input.length;
		while (pos < input.length && lmax == input.length) {
			if (input.get(pos) == "\n".code) {
				if (pos > 0 && input.get(pos - 1) == "\r".code)
					lmax = pos - 1;
				else
					lmax = pos;
			}
			pos++;
		}
		var elipsis = "";
		if (lineLength != null && lmax - lmin > lineLength && p.max - p.min < lmax - lmin) {
			elipsis = "...";
			var minLength = p.max - p.min + 2*elipsis.length + 1;  // 1 for rounding
			if (lineLength < minLength)
				lineLength = minLength;
			var excess = lmax - lmin - lineLength;
			var rem = Math.ceil(excess/2);
			lmin += rem - elipsis.length;
			lmax -= rem + elipsis.length;
		}
		return {
			line : elipsis + input.sub(lmin, lmax - lmin).toString() + elipsis,
			start : p.min - lmin + elipsis.length,
			finish : p.max - lmin + elipsis.length
		}
	}
}

