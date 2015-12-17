package format;

import StringTools.htmlEscape;
import StringTools.urlEncode;
import format.Document;

typedef OutputApi = {
	function saveContent(path:String, content:String):Void;
}

class HtmlGenerator implements Generator {
	var api:OutputApi;

	function posAttrs(pos:Pos)
		return 'x-src-file="${htmlEscape(pos.fileName)}" x-src-line=${pos.lineNumber}';

	function iterHorizontal(list:HList)
		return [ for (h in list) generateHorizontal(h) ].join("");

	function generateHorizontal(expr:Expr<HDef>)
	{
		return switch expr.expr {
		case HText(text):
			'<span ${posAttrs(expr.pos)}>${htmlEscape(text)}</span>';
		case HEmph(hlist):
			var inner = [ for (h in hlist) generateHorizontal(h) ].join("");
			'<em ${posAttrs(expr.pos)}>${iterHorizontal(hlist)}</em>';
		case HHighlight(hlist):
			var inner = [ for (h in hlist) generateHorizontal(h) ].join("");
			'<strong ${posAttrs(expr.pos)}>${iterHorizontal(hlist)}</strong>';
		}
	}

	function iterVertical(list:VList, ?depth=0, ?label="")
		return [ for (v in list) generateVertical(v, depth, label) ].join("\n");

	function indent(depth:Int)
		return depth > 0 ? StringTools.rpad("", "\t", depth) : "";

	function generateVertical(expr:Expr<VDef>, ?curDepth=0, ?curLabel="")
	{
		return switch expr.expr {
		case VPar(hlist):
			'<p ${posAttrs(expr.pos)}>${iterHorizontal(hlist)}</p>';
		case VSection(label, name, contents):
			var dep = curDepth + 1;
			var lab = curLabel != "" ? '$curLabel.$label' : label;
			var cl = dep == 1 ? "chapter" : "section";
			'<article class="$cl" id="${urlEncode(lab)}" ${posAttrs(expr.pos)}>\n' +
			'<h$dep ${posAttrs(expr.pos)}>${iterHorizontal(name)}</h$dep>\n' +
			iterVertical(contents, dep, lab) + "\n</article>";
		}
	}

	public function generateDocument(doc:Document)
		api.saveContent("index.html", iterVertical(doc));

	public function new(?api:OutputApi) {
		if (api == null)
			api = sys.io.File;
		this.api = api;
	}
}

