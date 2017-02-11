package html;

import haxe.io.Bytes;
import haxe.io.Path;
import html.script.Const;
import sys.FileSystem;
import sys.io.File;
import tink.template.Html;
import transform.Context;
import transform.NewDocument;
import util.sys.FsUtil;

import Assertion.*;
import generator.tex.*;

using Literals;
using StringTools;
using PositionTools;
using transform.DocumentTools;

typedef BreadcrumbItem = {
	no:Int,
	name:Html,
	url:String
}

typedef Breadcrumbs = {
	?volume:BreadcrumbItem,
	?chapter:BreadcrumbItem,
	?section:BreadcrumbItem
}

@:hasTemplates
class Generator {
	static var assetCache = new Map<String,String>();
	static inline var ASSET_SUBDIR = "assets";
	@:template static var FILE_BANNER;
	
	var destDir:String;
	var godOn:Bool;
	var bufs:Map<String,StringBuf>;
	var stylesheets:Array<String>;
	var srcCache:Map<String,Int>;
	var lastSrcId:Int;
	var toc:StringBuf;

	function gent(text:String)
		return text.htmlEscape();

	function saveSource(src:String)
	{
		var id = srcCache[src];
		if (id == null)
			id = srcCache[src] = lastSrcId++;
		return id;
	}

	function exportPos(pos:Position)
		return [saveSource(pos.src), pos.min, pos.max].join(":");

	@:template function genp(pos:Position);

	function genh(h:HElem)
	{
		switch h.def {
		case Wordspace:
			return " ";
		case Superscript(h):
			return '<sup${genp(h.pos)}>${genh(h)}</sup>';
		case Subscript(h):
			return '<sub${genp(h.pos)}>${genh(h)}</sub>';
		case Emphasis(h):
			return '<em${genp(h.pos)}>${genh(h)}</em>';
		case Highlight(h):
			return '<strong${genp(h.pos)}>${genh(h)}</strong>';
		case Word(word):
			return gent(word);
		case InlineCode(code):
			return '<code${genp(h.pos)}>${gent(code)}</code>';
		case Math(tex):
			return '<span class="mathjax"${genp(h.pos)}>\\(${gent(tex)}\\)</span>';
		case HElemList(li):
			var buf = new StringBuf();
			if (godOn)
				buf.add('<span${genp(h.pos)}>');
			for (i in li)
				buf.add(genh(i));
			if (godOn)
				buf.add('</span>');
			return buf.toString();
		case HEmpty:
			return "";
		}
	}

	function genn(h:HElem)  // genN for plaiN
	{
		switch h.def {
		case Wordspace:
			return " ";
		case Superscript(h), Subscript(h), Emphasis(h), Highlight(h):
			return genn(h);
		case Word(cte), InlineCode(cte), Math(cte):
			return cte;
		case HElemList(li):
			var buf = new StringBuf();
			for (i in li)
				buf.add(genn(i));
			return buf.toString();
		case HEmpty:
			return "";
		}
	}

	function _saveAsset(src:String, ?content:Bytes)
	{
		if (assetCache.exists(src))
			return assetCache[src];

		var dir = ASSET_SUBDIR;
		var ldir = Path.join([destDir, ASSET_SUBDIR]);
		if (!FileSystem.exists(ldir))
			FileSystem.createDirectory(ldir);

		var ext = Path.extension(src).toLowerCase();
		weakAssert(ext != "", src, "web server might expect an extension for automatic content-type headers");
		var data = content != null ? content : File.getBytes(src);
#if nodejs
		var hash = js.node.Crypto.createHash("sha1").update(js.node.buffer.Buffer.hxFromBytes(data)).digest("hex");
#else
		var hash = haxe.crypto.Sha1.make(data).toHex();
#end

		var name = ext != "" ? hash + "." + ext : hash;
		var dst = Path.join([dir, name]);
		var lpath = Path.join([ldir, name]);
		File.saveBytes(lpath, data);
		assetCache[src] = dst;
		return dst;
	}

	function saveAsset(src, ?content)
		return Context.time("html generation (saveAsset)", _saveAsset.bind(src, content));

	@:template function renderHead(title:String, base:String, relPath:String);
	@:template function renderBreadcrumbs(bcs:Breadcrumbs);  // FIXME

	function openBuffer(title:String, base:String, bcs:Breadcrumbs, url:String)
	{
		// TODO get normalize and google fonts with \html\apply or \html\link
		// TODO get jquery and mathjax with \html\run
		var buf = new StringBuf();
		buf.add("<!DOCTYPE html>");
		buf.add(FILE_BANNER);
		buf.add("<html>\n");
		buf.add(renderHead(title, base, url));
		buf.add("<body>\n");
		buf.add(renderBreadcrumbs(bcs));  // FIXME
		buf.add('<div class="container"><nav><span id="toc-loading">Loading the table of contents...</span><a id="toc-menu" class="disabled" href="">Table of Contents</a></nav>\n<div class="col-text">\n');
		return buf;
	}

	static inline var QUAD = '<span class="quad"></span>';
	static inline var DRAFT_IMG_PLACEHOLDER = "https://upload.wikimedia.org/wikipedia/commons/5/56/Sauroposeidon_Scale_Diagram_Steveoc86.svg";
	static inline var DRAFT_IMG_PLACEHOLDER_COPYRIGHT = "Placeholder image by Steveoc 86 (Own work) <a href='http://creativecommons.org/licenses/by-sa/3.0'>CC BY-SA 3.0</a> or <a href='http://www.gnu.org/copyleft/fdl.html'>GFDL</a>, via Wikimedia Commons";

	static function sizeToClass(size:BlobSize):String
	{
		return switch size {
		case MarginWidth: "sm";
		case TextWidth: "md";
		case FullWidth: "lg";
		}
	}

	function genv(v:DElem, idc:IdCtx, noc:NoCtx, bcs:Breadcrumbs)
	{
		switch v.def {
		case DHtmlApply(_.toInputPath() => path):
			stylesheets.push(saveAsset(path));
			return "";
		case DLaTeXPreamble(_), DLaTeXExport(_):
			return "";
		case DVolume(no, name, children):
			idc.volume = v.id.sure();
			noc.volume = no;
			var path = Path.join(["volume", idc.volume, "index.html"]);
			var url = Path.normalize(Path.directory(path));
			bcs.volume = { no:no, name:new Html(genh(name)), url:url };  // FIXME raw html
			var title = 'Volume $no: ${genn(name)}';
			var buf = bufs[path] = openBuffer(title, "../..", bcs, url);
			toc.add('<li class="volume">\n${renderToc(no, Std.string(no), new Html(genh(name)), url)}\n<ul>\n');
			buf.add('
				<section>
				<h1 id="heading" class="volume${noc.volume}">$no$QUAD${genh(name)}</h1>
				${genv(children, idc, noc, bcs)}
				</section>
			'.doctrim());
			toc.add("</ul>\n</li>\n");
			bcs.volume = null;  // FIXME hack
			return "";
		case DChapter(no, name, children):
			idc.chapter = v.id.sure();
			noc.chapter = no;
			var path = Path.join([idc.chapter, "index.html"]);
			var url = Path.normalize(Path.directory(path));
			bcs.chapter = { no:no, name:new Html(genh(name)), url:url };  // FIXME raw html
			var title = 'Chapter $no: ${genn(name)}';
			var buf = bufs[path] = openBuffer(title, "..", bcs, url);
			toc.add('<li class="chapter">${renderToc(null, Std.string(noc.chapter), new Html(genh(name)), url)}<ul>\n');
			buf.add('
				<section>
				<h2 id="heading" class="volume${noc.volume}">$no$QUAD${genh(name)}</h2>
				${genv(children, idc, noc, bcs)}
				</section>
			'.doctrim());
			toc.add("</ul>\n</li>\n");
			buf.add("\n");
			bcs.chapter = null;  // FIXME hack
			return "";
		case DSection(no, name, children):
			idc.section = v.id.sure();
			noc.section = no;
			var lno = noc.join(false, ".", chapter, section);
			var path = Path.join([idc.chapter, idc.section, "index.html"]);
			var url = Path.normalize(Path.directory(path));
			bcs.section = { no:no, name:new Html(genh(name)), url:url };  // FIXME raw html
			var title = '$lno ${genn(name)}';  // TODO chapter name
			var buf = bufs[path] = openBuffer(title, "../..", bcs, url);
			toc.add('<li class="section">${renderToc(null, lno, new Html(genh(name)), url)}<ul>\n');
			buf.add('
				<section>
				<h3 id="heading" class="volume${noc.volume}">$lno$QUAD${genh(name)}</h3>
				${genv(children, idc, noc, bcs)}
				</section>
			'.doctrim());
			toc.add("</ul>\n</li>\n");
			buf.add("\n");
			bcs.section = null;  // FIXME hack
			return "";
		case DSubSection(no, name, children):
			idc.subSection = v.id.sure();
			noc.subSection = no;
			var lno = noc.join(false, ".", chapter, section, subSection);
			var id = idc.join(true, ".", subSection);
			toc.add('<li>${renderToc(null, lno, new Html(genh(name)), bcs.section.url+"#"+id)}<ul>\n');
			var html = '
				<section>
				<h4 id="$id" class="volume${noc.volume}">$lno$QUAD${genh(name)}</h4>
				${genv(children, idc, noc, bcs)}
				</section>
			'.doctrim() + "\n";
			toc.add("</ul>\n</li>\n");
			return html;
		case DSubSubSection(no, name, children):
			idc.subSubSection = v.id.sure();
			noc.subSubSection = no;
			var lno = noc.join(false, ".", chapter, section, subSection, subSubSection);
			var id = idc.join(true, ".", subSection, subSubSection);
			var html = '
				<section>
				<h5 id="$id" class="volume${noc.volume}">$lno$QUAD${genh(name)}</h5>
				${genv(children, idc, noc, bcs)}
				</section>
			'.doctrim() + "\n";
			toc.add('<li>${renderToc(null, lno, new Html(genh(name)), bcs.section.url+"#"+id)}</li>');
			return html;
		case DBox(no, name, children):
			idc.box = v.id.sure();
			noc.box = no;
			var no = noc.join(false, ".", chapter, box);
			var id = idc.join(true, ".", box);
			var sz = TextWidth;
			function autoSize(d:DElem) {
				if (d.def.match(DTable(_, FullWidth|MarginWidth, _) | DFigure(_, FullWidth|MarginWidth, _)))
					sz = FullWidth;
				d.iter(autoSize);
			}
			autoSize(v);
			var size = sizeToClass(sz);
			return '
				<section class="box $size">
				<h1 id="$id" class="volume${noc.volume}">Box $no <em>${genh(name)}</em></h1>
				${genv(children, idc, noc, bcs)}
				</section>
			'.doctrim() + "\n";
		case DFigure(no, size, _.toInputPath() => path, caption, cright):
			idc.figure = v.id.sure();
			noc.figure = no;
			var no = noc.join(false, ".", chapter, figure);
			var id = idc.join(true, ".", figure);
			if (Context.draft) {
				return '
					<section class="img-block ${sizeToClass(size)}">
					<a><img src="$DRAFT_IMG_PLACEHOLDER" class="overlay-trigger"/></a>
					<p id="$id"><strong>Fig. $no</strong>$QUAD${genh(caption)} <em>$DRAFT_IMG_PLACEHOLDER_COPYRIGHT</em></p>
					</section>
				'.doctrim() + "\n";
			} else {
				var p = saveAsset(path);
				return '
					<section class="img-block ${sizeToClass(size)}">
					<a><img src="$p" class="overlay-trigger"/></a>
					<p id="$id"><strong>Fig. $no</strong>$QUAD${genh(caption)} <em>${genh(cright)}</em></p>
					</section>
				'.doctrim() + "\n";
			}
		case DTable(no, size, caption, header, rows):
			idc.table = v.id.sure();
			noc.table = no;
			var no = noc.join(false, ".", chapter, table);
			var id = idc.join(true, ".", table);
			var buf = new StringBuf();
			function writeCell(cell:DElem, header:Bool)
			{
				var tag = header ? "th" : "td";
				buf.add('<$tag>');
				switch cell.def {
				case DParagraph(h):
					buf.add(genh(h));
				case _:
					buf.add(genv(cell, idc, noc, bcs));
				}
				buf.add('</$tag>');
			}
			function writeRow(row:Array<DElem>, header:Bool)
			{
				buf.add("<tr>");
				for (c in row)
					writeCell(c, header);
				buf.add("</tr>\n");
			}
			buf.add('
				<section class="${sizeToClass(size)}">
				<h5 id="$id">Table $no$QUAD${genh(caption)}</h5>
				<table>
			'.doctrim());
			buf.add("\n<thead>");
			writeRow(header, true);
			buf.add("</thead>\n");
			for (r in rows)
				writeRow(r, false);
			buf.add("</table>\n</section>\n");
			return buf.toString();
		case DImgTable(no, size, caption, _.toInputPath() => path):
			idc.table = v.id.sure();
			noc.table = no;
			var no = noc.join(false, ".", chapter, table);
			var id = idc.join(true, ".", table);
			if (Context.draft) {
				return '
					<section class="img-block ${sizeToClass(size)}">
					<h5 id="$id">Table $no$QUAD${genh(caption)} <em>$DRAFT_IMG_PLACEHOLDER_COPYRIGHT</em></h5>
					<a><img src="$DRAFT_IMG_PLACEHOLDER" class="overlay-trigger"/></a>
					</section>
				'.doctrim() + "\n";
			} else {
				var p = saveAsset(path);
				return '
					<section class="img-block ${sizeToClass(size)}">
					<h5 id="$id">Table $no$QUAD${genh(caption)}</h5>
					<a><img src="$p" class="overlay-trigger"/></a>
					</section>
				'.doctrim() + "\n";
			}
		case DList(numbered, li):
			var buf = new StringBuf();
			var tag = numbered ? "ol" : "ul";
			buf.add('<$tag>\n');
			for (i in li) {
				buf.add("<li>");
				switch i.def {
				case DParagraph(h):
					buf.add(genh(h));
				case _:
					buf.add(genv(i, idc, noc, bcs));
				}
				buf.add("</li>\n");
			}
			buf.add('</$tag>\n');
			return buf.toString();
		case DCodeBlock(code):
			return '<pre><code>${gent(code)}</code></pre>\n';
		case DQuotation(text, by):
			return '<blockquote class="md"><q>${genh(text)}</q><span class="by">${genh(by)}</span></blockquote>\n';
        case DParagraph({pos:p, def:Math(tex)}):
            return '<p${genp(v.pos)}><span class="mathjax"${genp(p)}>\\[${gent(tex)}\\]</span></p>\n';
		case DParagraph(h):
			return '<p${genp(v.pos)}>${genh(h)}</p>\n';
		case DElemList(li):
			var buf = new StringBuf();
			for (i in li)
				buf.add(genv(i, idc, noc, bcs));
			return buf.toString();
		case DEmpty:
			return "";
		}
	}

	@:template function renderToc(vno:Null<Int>, lno:String, name:Html, url:String);

	// save data as jsonp
	function saveData(global:String, data:Dynamic)
	{
		var path = 'data_$global.js';
		var contents = 'var $global = ${haxe.Json.stringify(data)};';
		return saveAsset(path, Bytes.ofString(contents));
	}

	public function writeDocument(doc:NewDocument)
	{
		// FIXME get the document name elsewhere

		bufs = new Map();
		stylesheets = [];  // FIXME unique stylesheet collection
		srcCache = new Map();  // TODO abstract
		lastSrcId = 0;
		toc = new StringBuf();
		toc.add('<ul><li class="volume">${renderToc(null, null, "BRT Planning Guide", Path.normalize(""))}</li>');

		var contents = genv(doc, new IdCtx(), new NoCtx(), {});  // TODO here for a hack
		var root = bufs["index.html"] = openBuffer("The Online BRT Planning Guide", ".", {}, Path.normalize("./"));
		root.add('<section>\n<h1 id="heading" class="brtcolor">${gent("The Online BRT Planning Guide")}</h1>\n');
		root.add(contents);
		root.add('</section>\n');
		// TODO tt, commit in downloads, chapter download
		toc.add('
			<li class="keep">
			<a href="#nav-options">More options</a>
			<ul class="target" id="nav-options">
			<li><a href="pdf/the-brt-planning-guide.pdf">Download the guide as PDF</a></li>
			<!--<li>Chapter: Corridor And Network Development</li>-->
			<li><a href="../">Server debug</a></li>
			</ul>
			</li>
		'.doctrim());
		toc.add("\n</ul>");

		var srcMap = [
			for (p in srcCache.keys())
				srcCache[p] => p  // TODO src line maps
		];
		var s = new haxe.Serializer();
		s.useCache = true;
		s.useEnumIndex = true;
		s.serialize(srcMap);

		var glId = Sys.getEnv("GL_ANALYTICS_UA_ID");

		var toc = saveData(TocData, toc.toString());
		var script = saveAsset("manu.js", haxe.Resource.getBytes("html.js"));
		var srcMapPath = saveAsset("src.haxedata", Bytes.ofString(s.toString()));

		for (p in bufs.keys()) {
			var b = bufs[p];
			if (p.endsWith(".html")) {
				b.add("</div>\n");
				b.add("</div>\n");
				b.add('<script src="$toc"></script>');
				b.add('<script src="$script"></script>');
				b.add('<div class="data-src-map" data-href="$srcMapPath"></div>\n');
				if (glId != null && glId != "") {
					b.add('
						<script>
							(function(i,s,o,g,r,a,m){i["GoogleAnalyticsObject"]=r;i[r]=i[r]||function(){
							(i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
							m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
							})(window,document,"script","https://www.google-analytics.com/analytics.js","ga");
							ga("create", "$glId", "auto");
							ga("send", "pageview");
						</script>
					'.doctrim());
					b.add("\n");
				}
				b.add("</body>\n</html>\n");
			}

			var path = Path.join([destDir, p]);
			FileSystem.createDirectory(Path.directory(path));
			File.saveContent(path, b.toString());
		}
	}

	public function new(destDir, godOn)
	{
		// TODO validate destDir
		this.destDir = destDir;
		this.godOn = godOn;
	}
}

