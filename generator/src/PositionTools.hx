import haxe.Utf8;
import haxe.io.Bytes;

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
		var charMin = Utf8.length(str);

		while (cur < pos.max) {
			if (input.get(cur) == "\n".code) {
				lineMax++;
				posLineMax = cur + 1;
			}
			cur++;
		}

		var str = input.getString(posLineMax, pos.max - posLineMax);
		str = StringTools.replace(str,"\r","");
		var charMax = Utf8.length(str);

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

	public static function getBytesAt(p:Position):Bytes
		return sys.io.File.getBytes(p.src).sub(p.min, p.max - p.min);

	public static function getTextAt(p:Position):String
		return getBytesAt(p).toString();

	public static function highlight(p:Position, ?lineLength:Null<Int>):{ line:String, start:Int, finish:Int }
	{
		// find the line where the highlight is
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

		// get the line and check that it is utf-8 encoded
		var line = input.sub(lmin, lmax - lmin).toString();
		if (!Utf8.validate(line)) {
			return {
				line : "[invalid UTF-8]",
				start : 0,
				finish : 0
			}
		}

		function chars(b:Bytes) {
			var buf = [];
			Utf8.iter(b.toString(), function (c) buf.push(c));
			return buf;
		}
		var before = chars(input.sub(lmin, p.min - lmin));
		var hl = chars(input.sub(p.min, p.max - p.min));
		var after = chars(input.sub(p.max, lmax - p.max));

		var b = 0, h = hl.length, a = 0;
		if (lineLength != null && before.length + hl.length + after.length > lineLength) {
			if (h >= lineLength) {
				h = lineLength;
			} else {
				while (b + h + a < lineLength) {
					if (a < after.length)
						a++;
					if (b < before.length && b + h + a < lineLength)
						b++;
				}
			}
		}
		
		function text(c:Array<Int>) {
			if (c.length == 0)
				return "";
			var buf = new Utf8(c.length);
			for (i in c)
				buf.addChar(i);
			return buf.toString();
		}
		var before = text(before.slice(-b));
		var hl = text(hl.slice(0, h));
		var after = text(after.slice(0, a));

		return {
			line : before + hl + after,
			start : before.length,
			finish : before.length + hl.length
		}
	}
}

