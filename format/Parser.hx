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

	function makePos():Pos
		return { fileName : input.fname, lineNumber : input.lino };

	function makeExpr<Def>(expr:Def, ?pos:Pos)
		return { expr : expr, pos : pos != null ? pos : makePos() };

	function peek(?offset=0, ?len=1)
	{
		var i = input.pos + offset;
		if (i + len > input.buf.length)
			return null;
		return input.buf.substr(i, len);
	}

	function parseHorizontal(ltrim=false):Expr<HDef>
	{
		var pos = makePos();
		var buf = new StringBuf();
		while (true) {
			switch peek() {
			case null:
				return null;
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
			case c:
				ltrim = false;
				input.pos++;
				buf.add(c);
			}
		}
		return makeExpr(HText(buf.toString()), pos);
	}

	function readFancyLabel()
	{
		if (peek(0, 3) != ":::")
			return null;
		var pos = makePos();
		input.pos += 3;
		while (peek().isSpace(0))
			input.pos++;
		var buf = new StringBuf();
		while (true) {
			switch (peek()) {
			case c if (~/[a-z0-9-]/.match(c)):
				input.pos++;
				buf.add(c);
			case c if (c.isSpace(0)):
				input.pos++;
				break;
			case inv:
				throw { msg : 'Invalid char for label: $inv', pos : pos };
			}
		}
		return buf.toString();
	}

	function parseFancyHeading(curDepth:Int)
	{
		var rewind = {
			pos : input.pos,
			lino : input.lino
		};

		var pat = ~/^(#+)(\*)?([^#]|(\\#))*\n/;
		if (!pat.match(input.buf.substr(input.pos)))
			return null;
		var pos = makePos();

		var depth = pat.matched(1).length;
		if (depth > 6)
			throw { msg : "Hierachy depth must be between 1 (chapter) and 6", pos : pos };

		// don't advance the input or finish parsing if we would need to rewind to close some sections
		if (depth <= curDepth)
			return { depth : depth, label : null, name : null, pos : pos };

		input.pos += depth;

		if (pat.matched(2) == "*") {
			trace("TODO unnumbered section; don't know what to do with this yet");
			input.pos++;
		}

		var name = [];
		var label = null;
		while (true) {
			var h = parseHorizontal(true);
			if (h == null)
				break;
			name.push(h);
			var lb = readFancyLabel();
			if (lb != null) {
				if (label != null)
					throw { msg : "Multiple labels for a single vertical element aren't allowed", pos : pos };
				label = lb;
			}
		}
		var nameExpr = switch name.length {
		case 0: throw { msg : "A section must have a name", pos : pos };
		case 1: name[0];
		case _: makeExpr(HList(name), name[0].pos);
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
						trace(heading.label);
						list.push(makeExpr(VSection(heading.label, heading.name, parseVertical(heading.depth)), heading.pos));
					} else {
						throw { msg : 'Jumping from hierachy depth $depth to ${heading.depth} is not allowed', pos : heading.pos };
					}
				} else {
					trace(makePos());
					input.pos++;
				}
			case _:
				var par = [];
				while (true) {
					var h = parseHorizontal(true);
					if (h == null)
						break;
					par.push(h);
				}
				if (par.length == 0)
					continue;
				var text = switch par.length {
				case 1: par[0];
				case _: makeExpr(HList(par), par[0].pos);
				}
				list.push(makeExpr(VPar(text), text.pos));
			}
		}
		return switch list.length {
		case 0: null;
		case 1: list[0];
		case _: makeExpr(VList(list), list[0].pos);
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

