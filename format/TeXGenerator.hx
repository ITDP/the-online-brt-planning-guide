package format;

import format.Document;
using StringTools;

private typedef OutputApi = {
	function saveContent(path:String, content:String):Void;
}

class TeXGenerator implements Generator {
	var texRoot:String;
	var api:OutputApi;

	function mkLabel(curLabel, prefix, label)
	{
		label = '$prefix:$label';
		return curLabel != "" ? '$curLabel..$label' : label;
	}

	static var escaped = [
		"\\".code => "\\textbackslash{}",
		"#".code => "\\#",
		"{".code => "\\{",
		"}".code => "\\}"
	];

	function texEscape(s:String)
	{
		var buf = null;
		for (i in 0...s.length) {
			var c = s.fastCodeAt(i);
			if (!escaped.exists(c))
				continue;
			buf = new StringBuf();
			break;
		}
		if (buf == null)
			return s;
		for (i in 0...s.length) {
			var c = s.fastCodeAt(i);
			if (escaped.exists(c))
				buf.add(escaped[c]);
			else
				buf.addChar(c);
		}
		return buf.toString();
	}

	function findVerbDelimiter(str:String)
	{
		var codes = [ for (i in 0...str.length) str.fastCodeAt(i) ];
		codes.sort(Reflect.compare);
		var cand = 33;
		for (c in codes) {
			if (c > cand)
				break;
			else if (c == cand)
				cand++;
			if (cand  > 126)
				throw 'Could not find suitable \\verb delimiter for string "$str"';
			else if (cand > 96)
				cand = 123;
			else if (cand > 64)
				cand = 91;
			else if (cand > 47)
				cand = 58;
		}
		return String.fromCharCode(cand);
	}

	function generateHorizontal(expr:Expr<HDef>)
	{
		if (expr == null)
			return "";
		return switch expr.expr {
		case HText(text):
			texEscape(text);
		case HCode(code):
			var delim = findVerbDelimiter(code);
			'\\hbox{\\verb$delim$code$delim}';
		case HEmph(expr):
			'\\emph{${generateHorizontal(expr)}}';
		case HHighlight(expr):
			'\\emph{${generateHorizontal(expr)}}';  // FIXME
		case HList(list):
			[ for (h in list) generateHorizontal(h) ].join("");
		}
	}

	function generateVertical(expr:Expr<VDef>, ?curDepth=0, ?curLabel="")
	{
		if (expr == null)
			return "";
		return switch expr.expr {
		case VPar(par, label):
			if (label != null) {
				var lab = mkLabel(curLabel, "section", label);
				'\\label{$lab}\n${generateHorizontal(par).trim()}\n';
			} else {
				'${generateHorizontal(par).trim()}\n';
			}
		case VSection(name, contents, label):
			var dep = curDepth + 1;
			var lab = mkLabel(curLabel, "section", label);
			var cl = dep == 1 ? "chapter" : "section";
			for (i in 2...dep)
				cl = "sub" + cl;
			'\\$cl{${generateHorizontal(name).trim()}}\n\\label{$lab}\n\n' +
			generateVertical(contents, dep, lab);
		case VList(list):
			[ for (v in list) generateVertical(v, curDepth, curLabel) ].join("\n");
		}
	}

	public function generateDocument(doc:Document)
		api.saveContent(texRoot, generateVertical(doc));

	public function new(texRoot:String, ?api:OutputApi) {
		if (api == null)
			api = sys.io.File;
		this.texRoot = texRoot;
		this.api = api;
	}
}

