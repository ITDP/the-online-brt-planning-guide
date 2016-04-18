package format;

import format.Document;

using format.ExprTools;
using StringTools;

typedef Input = {
	fname:String,
	bpath:String,
	buf:String,
	pos:Int,
	lino:Int
}

class Parser {
	var input:Input;

	var label:Null<String>;

	function mkPos():Pos
		return { fileName : input.fname, lineNumber : input.lino };

	function mkExpr<Def>(expr:Def, ?pos:Pos)
		return { expr : expr, pos : pos != null ? pos : mkPos() };

	function mkErr(msg:String, ?pos:Pos)
		return { msg : msg, pos : pos != null ? pos : mkPos() };

	function peek(?offset=0, ?len=1)
	{
		var i = input.pos + offset;
		if (i + len > input.buf.length)
			return null;
		return input.buf.substr(i, len);
	}

	function parseFancyLabel()
	{
		if (peek(0, 3) != ":::")
			return null;
		var pos = mkPos();
		input.pos += 3;
		while (peek().isSpace(0))
			input.pos++;
		var buf = new StringBuf();
		while (true) {
			switch (peek()) {
			case null:
				break;
			case c if (~/[a-z0-9-]/.match(c)):
				input.pos++;
				buf.add(c);
			case c if (c.isSpace(0)):
				break;
			case inv:
				throw mkErr('Invalid char for label: $inv', pos);
			}
		}
		return buf.toString();
	}

	// inline code isn't parsed at all
	function parseInlineCode():Expr<HDef>
	{
		if (peek() != "`")
			return null;
		input.pos++;
		var pos = mkPos();
		var buf = new StringBuf();
		while (true) {
			switch peek() {
			case null:
				throw mkErr("Unclosed inline code expression", pos);
			case "\n":
				if (StringTools.trim(buf.toString()) == "")
					throw mkErr("Paragraph breaks are not allowed in inline code expression", pos);
				input.pos++;
				input.lino++;
				buf.add(" ");
			case "`":
				input.pos++;
				break;
			case c:
				input.pos++;
				buf.add(c);
			}
		}
		return mkExpr(HCode(buf.toString()));
	}

	function parseHorizontal(delimiter:Null<String>, ltrim=false):Expr<HDef>
	{
		var pos = mkPos();
		var buf = new StringBuf();
		function readChar(c) {
			ltrim = false;
			input.pos++;
			buf.add(c);
		}
		function readUntil(end) {
			var i = input.buf.indexOf(end, input.pos);
			var ret = i > -1 ? input.buf.substring(input.pos, i + end.length) : input.buf.substring(input.pos);
			input.pos += ret.length;
			return ret;
		}
		while (true) {
			switch peek() {
			case null:
				break;
			case "/" if (peek(1) == "/"):
				readUntil("\n");
			case "/" if (peek(1) == "*"):
				var p = mkPos();
				readUntil("*/");
				if (input.buf.substr(input.pos - 2, 2) != "*/")
					throw mkErr("Unclosed comment", p);
			case "\r":
				input.pos++;
			case " ", "\t":
				input.pos++;
				if (!ltrim && peek(0) != null && !peek(0).isSpace(0))
					buf.add(" ");
			case "\n":
				input.pos++;
				input.lino++;
				if (StringTools.trim(buf.toString()) == "")
					return null;
				if (peek(0) != null && !peek(0).isSpace(0))
					buf.add(" ");
				break;
			case ":" if (peek(1, 2) == "::"):
				var pos = mkPos();
				var lb = parseFancyLabel();
				if (lb == null) {
					readChar(":");
					break;
				}
				if (label != null)
					throw mkErr("Cannot set more than one label to the same vertical element", pos);
				label = lb;
			case "`":
				if (buf.toString().length > 0)
					break;  // finish the current expr
				return parseInlineCode();
			case _ if (delimiter != null && peek(0, delimiter.length) == delimiter):
				input.pos += delimiter.length;
				delimiter = null;
				break;
			case "*":
				if (buf.toString().length > 0)
					break;  // finish the current expr
				delimiter = peek(1) == "*" ? "**" : "*";
				input.pos += delimiter.length;
				return mkExpr(HEmph(parseHorizontal(delimiter, ltrim)), pos);
			case c:
				readChar(c);
			}
		}
		var text = buf.toString();
		return text.length != 0 ? mkExpr(HText(buf.toString()), pos) : null;
	}

	function parseFancyHeading(curDepth:Int)
	{
		var rewind = {
			pos : input.pos,
			lino : input.lino
		};

		var pat = ~/^(#+)(\*)?([^#]|(\\#))*?\n/;  // FIXME what it the input ends without a trailing newline?
		if (!pat.match(input.buf.substr(input.pos)))
			return null;
		var pos = mkPos();

		var depth = pat.matched(1).length;
		if (depth > 6)
			throw mkErr("Heading level must be in the range from 1 to 6", pos);

		// don't advance the input or finish parsing if we would need to rewind to close some sections
		if (depth <= curDepth)
			return { depth : depth, label : null, name : null, pos : pos };

		input.pos += depth;

		if (pat.matched(2) == "*") {
			trace("TODO unnumbered section; don't know what to do with this yet");
			input.pos++;
		}

		var name = [];
		label = null;
		while (true) {
			var h = parseHorizontal(null, true);
			if (h == null)
				break;
			name.push(h);
		}
		var nameExpr = switch name.length {
		case 0: throw mkErr("A heading requires a title", pos);
		case 1: name[0];
		case _: mkExpr(HList(name), name[0].pos);
		}

		if (label == null)
			label = nameExpr.toLabel();

		return { depth : depth, label : label, name : nameExpr, pos: pos };
	}

	function parseVertical(depth:Int):Expr<VDef>
	{
		var list = [];
		while (true) {
			switch peek() {
			case null:
				break;
			case "\n":
				input.pos++;
				input.lino++;
			case "#": // fancy
				var heading = parseFancyHeading(depth);
				if (heading != null) {
					if (heading.depth <= depth) {
						// must close the previous section first
						break;
					} else if (heading.depth == depth + 1) {
						list.push(mkExpr(VSection(heading.name, parseVertical(heading.depth), heading.label), heading.pos));
					} else {
						throw mkErr('Cannot increment hierarchy depth from $depth to ${heading.depth}; step larger than 1', heading.pos);
					}
				} else {
					trace('TODO handle other fancy features at ${mkPos()}');
					input.pos++;
				}
			case _:
				label = null;
				var par = [];
				var h = parseHorizontal(null, true);
				while (h != null) {
					par.push(h);
					h = parseHorizontal(null);
				}
				if (par.length == 0)
					continue;
				var text = switch par.length {
				case 1: par[0];
				case _: mkExpr(HList(par), par[0].pos);
				}
				list.push(mkExpr(VPar(text, label), text.pos));
			}
		}
		return switch list.length {
		case 0: null;
		case 1: list[0];
		case _: mkExpr(VList(list), list[0].pos);
		}
	}

	function parseDocument():Document
		return parseVertical(0);

	public function parseStream(stream:haxe.io.Input, ?basePath=".")
	{
		var _input = input;

		input = {
			fname : "stdin",
			bpath : basePath,
			buf : stream.readAll().toString(),
			pos : 0,
			lino : 1
		};
		trace("reading from the standard input");
		var ast = parseDocument();

		input = _input;
		return ast;
	}

	public function parseFile(path:String)
	{
		var _input = input;

		input = {
			fname : path,
			bpath : path,
			buf : sys.io.File.getContent(path),
			pos : 0,
			lino : 1
		};
		trace('Reading from $path');
		var ast = parseDocument();

		input = _input;
		return ast;
	}

	public function new() {}
}

