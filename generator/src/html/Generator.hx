package html;

import haxe.io.Bytes;
import haxe.io.Path;
import html.script.Const;
import sys.FileSystem;
import sys.io.File;
import tink.template.Html;
import transform.Context;
import transform.NewDocument;

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

/*
Generate a static website

Assumes that the server will:

 - serve `<foo>.html` to a `<foo>` request if it doesn't already match an
   existing file
 - serve `<foo>/index.html` to a `<foo>/` request

(e.g. Nginx configured to `try_files $uri $uri/ $uri.html 404`)
*/
@:hasTemplates
class Generator {
	static inline var ASSET_SUBDIR = "assets";
	@:template static var FILE_BANNER;
	static inline var ROOT_URL = "./";
	static inline var TOC_URL = "table-of-contents";

	var assets:Map<String,String>;
	var hasher:AssetHasher;
	var destDir:String;
	var godOn:Bool;
	var bufs:Map<String,StringBuf>;
	var customHead:Array<Html>;
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
		case Url(address):
			return '<a class="url" href="${gent(address)}">${gent(address)}</a>';
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
		case Word(cte), InlineCode(cte), Math(cte), Url(cte):
			return gent(cte);
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
		if (assets.exists(src))
			return assets[src];

		var dir = ASSET_SUBDIR;
		var ldir = Path.join([destDir, ASSET_SUBDIR]);
		if (!FileSystem.exists(ldir))
			FileSystem.createDirectory(ldir);

		var ext = Path.extension(src).toLowerCase();
		weakAssert(ext != "", src, "web server might expect an extension for automatic content-type headers");
		var data = content != null ? content : File.getBytes(src);
		var hash = hasher.hash(src, data, content == null);  // don't use a cache if content doesn't depend on src

		var name = ext != "" ? hash + "." + ext : hash;
		var dst = Path.join([dir, name]);
		var lpath = Path.join([ldir, name]);
		File.saveBytes(lpath, data);

		var prefix = Context.assetUrlPrefix;
		if (prefix != null)
			dst = prefix + dst;
		assets[src] = dst;
		return dst;
	}

	function saveAsset(src, ?content)
		return Context.time("html generation (saveAsset)", _saveAsset.bind(src, content));

	@:template function renderHead(title:String, base:String, relPath:String);
	@:template function renderBreadcrumbs(bcs:Breadcrumbs, relPath:String);  // FIXME

	var reserved = new StringBuf();

	function urlToPath(url:String)
	{
		assert(Path.removeTrailingSlashes(url) == Path.normalize(url) || url == ROOT_URL, url);
		return Path.normalize(url.endsWith("/") ? Path.join([url, "index.html"]) : Path.withExtension(url, "html"));
	}

	function reserveBuffer(url:String)
	{
		var path = urlToPath(url);
		assert(!bufs.exists(path) || bufs[path] == reserved, bufs[path].toString());
		bufs[path] = reserved;
	}

	function unreserveBuffer(url:String)
	{
		var path = urlToPath(url);
		assert(bufs[path] == reserved, bufs[path].toString());
		assert(bufs[path].toString().length == 0, bufs[path].toString());
		bufs.remove(path);
	}

	function openBuffer(title:String, bcs:Breadcrumbs, url:String)
	{
		var path = urlToPath(url);
		var depth = path.split("/").length - 1;
		var computedBase = depth > 0 ? [ for (i in 0...depth) ".." ].join("/") : ".";
		// TODO get normalize and google fonts with \html\head
		// TODO get jquery and mathjax with \html\run
		var buf = new StringBuf();
		buf.add("<!DOCTYPE html>");
		buf.add(FILE_BANNER);
		buf.add("<html>\n");
		buf.add(renderHead(title, computedBase, url));
		buf.add("<body>\n");
		buf.add(renderBreadcrumbs(bcs, url));  // FIXME
		buf.add('<div class="container">\n');
		buf.add('<nav id="action:navigate"><span id="toc-loading">Loading the table of contents...</span></nav>\n');
		buf.add('<div class="search"><input type="text" placeholder="Search..." name="search" id="input-search"></div>\n');
		buf.add('<script type="text/javascript"> $(document).ready(function() { $("#input-search").keyup(function (e) { var kc = e.keyCode || e.which; if (kc == 13) { $("#input-search").addClass("button-search"); window.location.href = "/search?search=" + this.value; } }); });</script>\n');
		buf.add('<div class="col-text">\n');
		assert(!bufs.exists(path), path, "reserved or already used path");
		bufs[path] = buf;
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
		case DHtmlStore(_.toInputPath() => path):
			saveAsset(path);
			return "";
		case DHtmlToHead(template):
			var t = new haxe.Template(template);
			var err = null;
			var tmacros = {
				assetPath : function (resolve, src)
				{
					// treat the `src` path as if it was a PEelem
					var path = ({ def:src, pos:v.pos }:PElem);
					err = transform.Validator.validateSrcPath(path, [File]);
					return assets[path.toInputPath()];
				}
			};
			var html = t.execute({}, tmacros);
			assert(err == null, err, v.pos.toString());
			customHead.push(new Html(html));
			return "";
		case DLaTeXPreamble(_), DLaTeXExport(_):
			return "";
		case DVolume(no, name, children):
			idc.volume = v.id.sure();
			noc.volume = no;
			var url = Path.join(["volume", idc.volume]);
			bcs.volume = { no:no, name:new Html(genh(name)), url:url };  // FIXME raw html
			var title = 'Volume $no: ${genn(name)}';
			var buf = openBuffer(title, bcs, url);
			toc.add('<li class="volume">\n${renderToc(no, "Volume " + no, new Html(genh(name)), url)}\n<ul>\n');
			buf.add('
				<section>
				<div class="volumehead v${noc.volume}"><h1 id="heading" class="volume${noc.volume}">$no$QUAD${genh(name)}</h1></div>
				${genv(children, idc, noc, bcs)}
				</section>
			'.doctrim());
			toc.add("</ul>\n</li>\n");
			bcs.volume = null;  // FIXME hack
			return "";
		case DChapter(no, name, children):
			idc.chapter = v.id.sure();
			noc.chapter = no;
			var url = Path.addTrailingSlash(idc.chapter);
			bcs.chapter = { no:no, name:new Html(genh(name)), url:url };  // FIXME raw html
			var title = 'Chapter $no: ${genn(name)}';
			var buf = openBuffer(title, bcs, url);
			toc.add('<li class="chapter">${renderToc(null, "Chapter " + noc.chapter, new Html(genh(name)), url)}<ul>\n');
			buf.add('
				<section>
				<h1 id="heading" class="volume${noc.volume}">$no$QUAD${genh(name)}</h1>
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
			var url = Path.join([idc.chapter, idc.section]);
			bcs.section = { no:no, name:new Html(genh(name)), url:url };  // FIXME raw html
			var title = '$lno ${genn(name)}';  // TODO chapter name
			var buf = openBuffer(title, bcs, url);
			toc.add('<li class="section">${renderToc(null, lno, new Html(genh(name)), url)}<ul>\n');
			buf.add('
				<section>
				<h1 id="heading" class="volume${noc.volume}">$lno$QUAD${genh(name)}</h1>
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
			var id = idc.join(false, "/", subSection);
			toc.add('<li>${renderToc(null, lno, new Html(genh(name)), bcs.section.url+"#"+id)}<ul>\n');
			var html = '
				<section>
				<h2 id="$id" class="volume${noc.volume} share">$lno$QUAD${genh(name)}</h2>
				${genv(children, idc, noc, bcs)}
				</section>
			'.doctrim() + "\n";
			toc.add("</ul>\n</li>\n");
			return html;
		case DSubSubSection(no, name, children):
			idc.subSubSection = v.id.sure();
			noc.subSubSection = no;
			var lno = noc.join(false, ".", chapter, section, subSection, subSubSection);
			var id = idc.join(false, "/", subSection, subSubSection);
			var html = '
				<section>
				<h3 id="$id" class="volume${noc.volume} share">$lno$QUAD${genh(name)}</h3>
				${genv(children, idc, noc, bcs)}
				</section>
			'.doctrim() + "\n";
			toc.add('<li>${renderToc(null, lno, new Html(genh(name)), bcs.section.url+"#"+id)}</li>');
			return html;
		case DBox(no, name, children):
			idc.box = v.id.sure();
			noc.box = no;
			var no = noc.join(false, ".", chapter, box);
			var id = idc.join(true, ":", box);
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
				<h3 id="$id" class="volume${noc.volume} share">Box $no <em>${genh(name)}</em></h3>
				${genv(children, idc, noc, bcs)}
				</section>
			'.doctrim() + "\n";
		case DTitle(name):
			return '<h3>${genh(name)}</h3>';
		case DFigure(no, size, _.toInputPath() => path, caption, cright):
			idc.figure = v.id.sure();
			noc.figure = no;
			var no = noc.join(false, ".", chapter, figure);
			var id = idc.join(true, ":", figure);
			var p = saveAsset(path);
			return '
				<figure class="img-block ${sizeToClass(size)}" id="$id">
				<a><img src="$p" class="overlay-trigger" alt="Fig. $no ${genn(caption)}"/></a>
				<figcaption class="share"><strong>Fig. $no</strong>$QUAD${genh(caption)} <em>${genh(cright)}</em></figcaption>
				</figure>
			'.doctrim() + "\n";
		case DTable(no, size, caption, header, rows):
			idc.table = v.id.sure();
			noc.table = no;
			var no = noc.join(false, ".", chapter, table);
			var id = idc.join(true, ":", table);
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
				<h3 id="$id" class="share">Table $no$QUAD${genh(caption)}</h3>
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
			var id = idc.join(true, ":", table);
			var p = saveAsset(path);
			return '
				<figure class="img-block ${sizeToClass(size)}">
				<h3 id="$id" class="share">Table $no$QUAD${genh(caption)}</h3>
				<a><img src="$p" class="overlay-trigger" alt="Table $no ${genn(caption)}"/></a>
				</figure>
			'.doctrim() + "\n";
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
			return '<p${genp(v.pos)}><span class="mathjax equation"${genp(p)}>\\[${gent(tex)}\\]</span></p>\n';
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

		assets = new Map();
		bufs = new Map();
		customHead = [];  // FIXME unique stylesheet collection
		srcCache = new Map();  // TODO abstract
		lastSrcId = 0;


		for (keyword in ["assets", "volume"])
			reserveBuffer(keyword);
		reserveBuffer(ROOT_URL);  // temporary due to ordering constraints
		reserveBuffer(TOC_URL);  // temporary due to ordering constraints

		// `toc.add` and `genv` ordering is relevant
		// it's necessary to process all `\html\head` before actually opening buffers and writing heads
		toc = new StringBuf();
		toc.add(
				'<div id="toc" class="tocfull">
					<ul><li class="index">${renderToc(null, null, "BRT Planning Guide", ROOT_URL)}</li>
				'.doctrim());
		var contents = genv(doc, new IdCtx(), new NoCtx(), {});

		// remove temporary constraints
		for (url in [ROOT_URL, TOC_URL])
			unreserveBuffer(url);

		// now we're ready to open toc as a proper buffer
		var tmp = toc.toString();
		toc = openBuffer("Table of contents", {}, TOC_URL);
		toc.add(tmp);

		var root = openBuffer("The Online BRT Planning Guide", {}, ROOT_URL);
		root.add('<section>\n<h1 id="heading" class="brtcolor">${gent("The Online BRT Planning Guide")}</h1>\n');
		root.add(contents);
		root.add('</section>\n');
		// TODO tt, commit in downloads, chapter download
		toc.add('
			<a class="close" href="#">&#x2715;</a>
			<li class="nav toc-link"><a href="$TOC_URL">View all content</a></li>
			<li class="nav"><a href="pdf/the-brt-planning-guide.pdf">Download in PDF</a></li>
			<li class="nav"><a href="https://github.com/ITDP/the-online-brt-planning-guide" target="_blank">Contribute now</a></li>
			<li class="nav"><a href="../" target="_blank">Extra files</a></li>
			<li class="nav github">
				${DateTools.format(Date.fromTime(Main.version.commit_timestamp*1000), "%b %d %Y")} | <a href="https://github.com/ITDP/the-online-brt-planning-guide/commit/${Main.version.fullCommit}">#${Main.version.commit}</a>
			${(Context.branch != null && Context.branch.length > 0 && Context.gh_user != null && Context.branch != "master") ?
				'<br><a href="https://github.com/${Context.gh_user}/the-online-brt-planning-guide/tree/${Context.branch}">${Context.gh_user}:${Context.branch}</a>' : ''}
			${(Context.pullRequest != null && Context.pullRequest.length > 0 && Std.parseInt(Context.pullRequest) != null) ?
				'| <a href="https://github.com/ITDP/the-online-brt-planning-guide/pull/${Context.pullRequest}">#${Context.pullRequest}</a>' : ""}
			${(Context.tag != null && Context.tag.length > 0) ? 
				'| <a>${Context.tag}</a>' : ""}
			</li>
		'.doctrim());
		toc.add("\n</ul></div>");

		var srcMap = [
			for (p in srcCache.keys())
				srcCache[p] => p  // TODO src line maps
		];
		var s = new haxe.Serializer();
		s.useCache = true;
		s.useEnumIndex = true;
		s.serialize(srcMap);

		var glId = Context.googleAnalyticsId;

		var script = saveAsset("manu.js", haxe.Resource.getBytes("html.js"));
		var srcMapPath = saveAsset("src.haxedata", Bytes.ofString(s.toString()));

		for (p in bufs.keys()) {
			var b = bufs[p];
			if (b == reserved)
				continue;

			if (p.endsWith(".html")) {
				b.add("</div>\n</div>\n");  // div.col-text & div.container
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

	public function new(hasher, destDir, godOn)
	{
		this.hasher = hasher;
		// TODO validate destDir
		this.destDir = destDir;
		this.godOn = godOn;
	}
}

