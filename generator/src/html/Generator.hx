package html;

import haxe.io.Bytes;
import haxe.io.Path;
import html.script.Const;
import sys.FileSystem;
import sys.io.File;
import transform.Context;
import transform.NewDocument;

import Assertion.*;
import generator.tex.*;

using Literals;
using StringTools;
using PositionTools;
using transform.DocumentTools;

/*
Generate a static website

Assumes that the server will:

 - serve `<foo>.html` to a `<foo>` request if it doesn't already match an
   existing file
 - serve `<foo>/index.html` to a `<foo>/` request

(e.g. Nginx configured to `try_files $uri $uri/ $uri.html 404`)
*/
class Generator {
	static inline var ASSET_SUBDIR = "assets";
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
	var index:Map<String,DElem>;

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

	function resolveRef(type:RefType, id:Elem<String>)
	{
		var targetElem = index[id.def];
		assert(targetElem != null, "could not resolve reference", id.def, id.pos.toString());
		var infos = getFirstPassInfos(targetElem);
		var prefix = null;
		var text = switch [type, targetElem.def] {
		case [_, DTitle(_)|DList(_)|DCodeBlock(_)|DQuotation(_)|DParagraph(_)|DElemList(_)|DEmpty|
				DHtmlStore(_)|DHtmlToHead(_)|DLaTeXPreamble(_)|DLaTeXExport(_)]:
			assert(false, "unsupported target", Type.enumConstructor(targetElem.def), id.pos.toString()); null;
		case [RTAuto|RTItemName, DVolume(no,name,_)|DChapter(no,name,_)]:
			'${gent(Std.string(no))} (${genh(name)})';
		case [RTItemName, DSection(no,name,_)|DSubSection(no,name,_)|DSubSubSection(no,name,_)|
				DBox(no,name,_)|DFigure(no,_,_,name,_)|DTable(no,_,name,_,_)|DImgTable(no,_,name,_)]:
			'${gent(infos.no)} (${genh(name)})';
		case [RTAuto|RTItemNumber, _]:
			gent('${infos.no}');
		case [RTPageNumber, _]:
			assert(infos.page != null, "missing parent/page DElem", id.pos.toString());
			var pdelem = infos.page;
			switch pdelem.def {
			case DVolume(_, name, _), DChapter(_, name, _), DSection(_, name, _):
				prefix = "";
				genh(name);
			case other:
				assert(false, "unsupported parent/page element", Type.enumConstructor(other), id.pos.toString()); null;
			}
		}
		if (prefix == null)
		 prefix = gent(Type.enumConstructor(targetElem.def).substr(1).replace("SubS", "Sub-S").replace("Img", "")) + " ";
		return { targetElem:targetElem, infos:infos, text:text, prefix:prefix };
	}

	function compareCounters(a:String, b:String):Int
	{
		var a = a.split(".");
		var b = b.split(".");
		assert(a.length == b.length && a.length <= 3, a.length, b.length);
		for (i in 0...a.length) {
			if (a[i] != b[i])
				return (Std.parseInt(a[i]) - Std.parseInt(b[i])) << 10*(a.length - i - 1);
		}
		return 0;
	}

	function genh(h:HElem)
	{
		switch h.def {
		case Wordspace:
			return " ";
		case Superscript(h):
			return '<sup${Render.posAttr(h.pos)}>${genh(h)}</sup>';
		case Subscript(h):
			return '<sub${Render.posAttr(h.pos)}>${genh(h)}</sub>';
		case Emphasis(h):
			return '<em${Render.posAttr(h.pos)}>${genh(h)}</em>';
		case Highlight(h):
			return '<strong${Render.posAttr(h.pos)}>${genh(h)}</strong>';
		case Word(word):
			return gent(word);
		case InlineCode(code):
			return '<code${Render.posAttr(h.pos)}>${gent(code)}</code>';
		case Math(tex):
			return '<span class="mathjax"${Render.posAttr(h.pos)}>\\(${gent(tex)}\\)</span>';
		case Url(address):
			return '<a class="url" href="${gent(address)}">${gent(address)}</a>';
		case Ref(type, target):
			var ref = resolveRef(type, target);
			return '<a href="${ref.infos.url}">${ref.prefix}${ref.text}</a>';
		case RangeRef(type, firstTarget, lastTarget):
			/*
			Be user friendly: handle first == last, check if targets match in type
			and fix order if first > last.  Additionally, customize the interval word
			if last = first + 1.
			*/
			var first = resolveRef(type, firstTarget);
			var last = resolveRef(type, lastTarget);
			assert(first.targetElem.def.getIndex() == last.targetElem.def.getIndex(),
					"trying to reference a range of different elements",
					first.targetElem.def.getName(), last.targetElem.def.getName(), h.pos.toString());
			assert(first.prefix == last.prefix);
			if (first.text == last.text)  // infos.url theoretically better, but text practically more relevant
				return genh({ def:Ref(type, firstTarget), pos:h.pos });
			var dif = compareCounters(last.infos.no, first.infos.no);
			if (dif < 0) {
				var tmp = first;
				first = last;
				last = tmp;
				dif = - dif;
			}
			var interval = dif == 1 ? " and " : " to ";
			var prefix = first.prefix;
			if (prefix != "")
				prefix = prefix.rtrim() + "s ";
			return '${prefix}<a href="${first.infos.url}">${first.text}</a>$interval<a href="${last.infos.url}">${last.text}</a>';
		case HElemList(li):
			var buf = new StringBuf();
			if (godOn)
				buf.add('<span${Render.posAttr(h.pos)}>');
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
		case Ref(type, target):
			return gent('<broken reference>');  // FIXME
		case RangeRef(type, firstTarget, lastTarget):
			return gent('<broken range>');  // FIXME
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
		var v = Main.version;
		buf.add(Render.fileBanner({ commit:v.commit, haxe:v.haxe, runtime:v.runtime, platform:v.platform },
				{ art:Main.LOGO, text:Main.LOGO_TEXT }));
		buf.add("<html>\n");
		buf.add(Render.head(title, computedBase, url, customHead));
		buf.add("<body>\n");
		buf.add(Render.breadcrumbs(bcs, ROOT_URL, url));
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

	static function normalizeId(ctx:IdCtx, id:String):String
	{
		var ctx:IdCtx = Reflect.copy(ctx);
		var segs = id.split(":");
		assert(segs.length > 0 && segs.length % 2 == 0, segs.length, id);
		var parts = [ for (i in 0...(segs.length >> 1)) { name:segs[i*2], value:segs[i*2 + 1] } ];
		// TODO check parts
		// TODO sort parts
		for (p in parts)
			Reflect.setProperty(ctx, p.name, p.value);
		return
				switch parts[parts.length - 1].name {
				case "volume": ctx.join(true, ":", volume);
				case "chapter": ctx.join(true, ":", chapter);
				case "section": ctx.join(true, ":", chapter, section);
				case "subSection": ctx.join(true, ":", chapter, section, subSection);
				case "subSubSection": ctx.join(true, ":", chapter, section, subSection, subSubSection);
				case "box": ctx.join(true, ":", chapter, box);
				case "figure": ctx.join(true, ":", chapter, figure);
				case "table": ctx.join(true, ":", chapter, table);
				case other: assert(false, other); null;
				}
	}

	static function normalizeRefs(ctx:IdCtx, h:HElem)
	{
		switch h.def {
		case Ref(type, target):
			h.def = parser.Ast.HDef.Ref(type, { def:normalizeId(ctx, target.def), pos:target.pos });
		case RangeRef(type, firstTarget, lastTarget):
			h.def = parser.Ast.HDef.RangeRef(type, { def:normalizeId(ctx, firstTarget.def), pos:firstTarget.pos },
					{ def:normalizeId(ctx, lastTarget.def), pos:lastTarget.pos });
		case HElemList(li):
			for (i in li)
				normalizeRefs(ctx, i);
		case _:
			// noop
		}
	}

	/**
	First pass: prepare for generation.

	Compute ids, counters and urls, and normalize all ref/rangeref targets.

	Builds an index for ref/rangeref resolution, and stores useful data in the
	DElem (adding a _first field with Reflection).
	**/
	function firstPass(v:DElem, idc:IdCtx, noc:NoCtx, page:DElem)
	{
		var infos:{ id:String, htmlId:String, no:String, volumeNo:Int, url:String, page:DElem } = null;
		switch v.def {
		case DVolume(no, name, children):
			idc.volume = v.id.sure();
			noc.volume = no;
			infos = {
				id : idc.join(true, ":", volume),
				htmlId : "heading",
				no : noc.join(false, ".", volume),
				volumeNo : noc.volume,
				url : Path.join(["volume", idc.volume]),
				page : v
			};
			normalizeRefs(idc, name);
			firstPass(children, idc, noc, v);
		case DChapter(no, name, children):
			idc.chapter = v.id.sure();
			noc.chapter = no;
			infos = {
				id : idc.join(true, ":", chapter),
				htmlId : "heading",
				no : noc.join(false, ".", chapter),
				volumeNo : noc.volume,
				url : Path.addTrailingSlash(idc.chapter),
				page : v
			};
			normalizeRefs(idc, name);
			firstPass(children, idc, noc, v);
		case DSection(no, name, children):
			idc.section = v.id.sure();
			noc.section = no;
			infos = {
				id : idc.join(true, ":", chapter, section),
				htmlId : "heading",
				no : noc.join(false, ".", chapter, section),
				volumeNo : noc.volume,
				url : Path.join([idc.chapter, idc.section]),
				page : v
			};
			normalizeRefs(idc, name);
			firstPass(children, idc, noc, v);
		case DSubSection(no, name, children):
			idc.subSection = v.id.sure();
			noc.subSection = no;
			var htmlId = idc.join(false, "/", subSection);
			infos = {
				id : idc.join(true, ":", chapter, section, subSection),
				htmlId : htmlId,
				no : noc.join(false, ".", chapter, section, subSection),
				volumeNo : noc.volume,
				url : Path.join([idc.chapter, idc.section + "#" + htmlId]),
				page : page
			};
			normalizeRefs(idc, name);
			firstPass(children, idc, noc, page);
		case DSubSubSection(no, name, children):
			idc.subSubSection = v.id.sure();
			noc.subSubSection = no;
			var htmlId = idc.join(false, "/", subSection, subSubSection);
			infos = {
				id : idc.join(true, ":", chapter, section, subSection, subSubSection),
				htmlId : htmlId,
				no : noc.join(false, ".", chapter, section, subSection, subSubSection),
				volumeNo : noc.volume,
				url : Path.join([idc.chapter, idc.section + "#" + htmlId]),
				page : page
			};
			normalizeRefs(idc, name);
			firstPass(children, idc, noc, page);
		case DBox(no, name, children):
			idc.box = v.id.sure();
			noc.box = no;
			var htmlId = idc.join(true, ":", box);
			infos = {
				id : idc.join(true, ":", chapter, box),
				htmlId : htmlId,
				no : noc.join(false, ".", chapter, box),
				volumeNo : noc.volume,
				url : Path.join([idc.chapter, idc.section + "#" + htmlId]),
				page : page
			};
			normalizeRefs(idc, name);
			firstPass(children, idc, noc, page);
		case DFigure(no, _, _, caption, cright):
			idc.figure = v.id.sure();
			noc.figure = no;
			var htmlId = idc.join(true, ":", figure);
			infos = {
				id : idc.join(true, ":", chapter, figure),
				htmlId : htmlId,
				no : noc.join(false, ".", chapter, figure),
				volumeNo : noc.volume,
				url : Path.join([idc.chapter, idc.section + "#" + htmlId]),
				page : page
			};
			normalizeRefs(idc, caption);
			normalizeRefs(idc, cright);
		case DTable(no, _, title, header, rows):
			idc.table = v.id.sure();
			noc.table = no;
			var htmlId = idc.join(true, ":", table);
			infos = {
				id : idc.join(true, ":", chapter, table),
				htmlId : htmlId,
				no : noc.join(false, ".", chapter, table),
				volumeNo : noc.volume,
				url : Path.join([idc.chapter, idc.section + "#" + htmlId]),
				page : page
			};
			normalizeRefs(idc, title);
			for (i in header)
				firstPass(i, idc, noc, page);
			for (row in rows) {
				for (i in row)
					firstPass(i, idc, noc, page);
			}
		case DImgTable(no, _, title, _):
			idc.table = v.id.sure();
			noc.table = no;
			var htmlId = idc.join(true, ":", table);
			infos = {
				id : idc.join(true, ":", chapter, table),
				htmlId : htmlId,
				no : noc.join(false, ".", chapter, table),
				volumeNo : noc.volume,
				url : Path.join([idc.chapter, idc.section + "#" + htmlId]),
				page : page
			};
			normalizeRefs(idc, title);
		case DElemList(li), DList(_, li):
			for (i in li)
				firstPass(i, idc, noc, page);
			return;
		case DParagraph(content):
			normalizeRefs(idc, content);
			return;
		case DQuotation(content, author):
			normalizeRefs(idc, content);
			normalizeRefs(idc, author);
			return;
		case DTitle(title):
			normalizeRefs(idc, title);
			return;
		case DEmpty, DCodeBlock(_), DHtmlStore(_), DHtmlToHead(_), DLaTeXExport(_), DLaTeXPreamble(_):
			return;
		}
		assert(infos != null, v.pos.toString());
		weakAssert(!index.exists(infos.id), "global id conflict", infos.id, v.pos.toString());  // FIXME switch to assert
		index[infos.id] = v;
		Reflect.setField(v, "_first", infos);
	}

	function getFirstPassInfos(v:DElem)
	{
		var infos:{ id:String, htmlId:String, no:String, volumeNo:Int, url:String, page:DElem } =
				Reflect.field(v, "_first");
		assert(infos != null, v.pos.toString());
		return infos;
	}

	function secondPass(v:DElem, bcs:Breadcrumbs)
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
			var infos = getFirstPassInfos(v);
			bcs.volume = { no:no, name:new Html(genh(name)), url:infos.url };
			var title = 'Volume $no: ${genn(name)}';
			var buf = openBuffer(title, bcs, infos.url);
			toc.add('<li class="volume">\n${Render.tocItem(no, "Volume " + no, new Html(genh(name)), infos.url)}\n<ul>\n');
			buf.add('
				<section>
				<div class="volumehead v$no"><h1 id="heading" class="volume$no">$no$QUAD${genh(name)}</h1></div>
				${secondPass(children, bcs)}
				</section>
			'.doctrim());
			toc.add("</ul>\n</li>\n");
			bcs.volume = null;  // FIXME hack
			return "";
		case DChapter(no, name, children):
			var infos = getFirstPassInfos(v);
			bcs.chapter = { no:no, name:new Html(genh(name)), url:infos.url };
			var title = 'Chapter $no: ${genn(name)}';
			var buf = openBuffer(title, bcs, infos.url);
			toc.add('<li class="chapter">${Render.tocItem(null, "Chapter " + no, new Html(genh(name)), infos.url)}<ul>\n');
			buf.add('
				<section>
				<h1 id="heading" class="volume${infos.volumeNo}">$no$QUAD${genh(name)}</h1>
				${secondPass(children, bcs)}
				</section>
			'.doctrim());
			toc.add("</ul>\n</li>\n");
			buf.add("\n");
			bcs.chapter = null;  // FIXME hack
			return "";
		case DSection(no, name, children):
			var infos = getFirstPassInfos(v);
			bcs.section = { no:no, name:new Html(genh(name)), url:infos.url };
			var title = '${infos.no} ${genn(name)}';
			var buf = openBuffer(title, bcs, infos.url);
			toc.add('<li class="section">${Render.tocItem(null, infos.no, new Html(genh(name)), infos.url)}<ul>\n');
			buf.add('
				<section>
				<h1 id="heading" class="volume${infos.volumeNo}">${infos.no}$QUAD${genh(name)}</h1>
				${secondPass(children, bcs)}
				</section>
			'.doctrim());
			toc.add("</ul>\n</li>\n");
			buf.add("\n");
			bcs.section = null;  // FIXME hack
			return "";
		case DSubSection(no, name, children):
			var infos = getFirstPassInfos(v);
			toc.add('<li>${Render.tocItem(null, infos.no, new Html(genh(name)), infos.url)}<ul>\n');
			var html = '
				<section>
				<h2 id="${infos.htmlId}" class="volume${infos.volumeNo} share">${infos.no}$QUAD${genh(name)}</h2>
				${secondPass(children, bcs)}
				</section>
			'.doctrim() + "\n";
			toc.add("</ul>\n</li>\n");
			return html;
		case DSubSubSection(no, name, children):
			var infos = getFirstPassInfos(v);
			var html = '
				<section>
				<h3 id="${infos.htmlId}" class="volume${infos.volumeNo} share">${infos.no}$QUAD${genh(name)}</h3>
				${secondPass(children, bcs)}
				</section>
			'.doctrim() + "\n";
			toc.add('<li>${Render.tocItem(null, infos.no, new Html(genh(name)), infos.url)}</li>');
			return html;
		case DBox(no, name, children):
			var infos = getFirstPassInfos(v);
			var sz = TextWidth;
			function autoSize(d:DElem) {
				if (d.def.match(DTable(_, FullWidth|MarginWidth, _) | DFigure(_, FullWidth|MarginWidth, _)))
					sz = FullWidth;
				d.iter(autoSize);
			}
			autoSize(v);
			var size = sizeToClass(sz);
			return '
			<section class="box $size" id="${infos.htmlId}">
			<h3 class="volume${infos.volumeNo} share">Box ${infos.no} <em>${genh(name)}</em></h3>
				${secondPass(children, bcs)}
				</section>
			'.doctrim() + "\n";
		case DTitle(name):
			return '<h3>${genh(name)}</h3>';
		case DFigure(no, size, _.toInputPath() => path, caption, cright):
			var infos = getFirstPassInfos(v);
			var p = saveAsset(path);
			return '
				<figure class="img-block ${sizeToClass(size)}" id="${infos.htmlId}">
				<a><img src="$p" class="overlay-trigger" alt="Figure ${infos.no} ${genn(caption)}"/></a>
				<figcaption class="share"><strong>Figure ${infos.no}</strong>$QUAD${genh(caption)} <em>${genh(cright)}</em></figcaption>
				</figure>
			'.doctrim() + "\n";
		case DTable(no, size, caption, header, rows):
			var infos = getFirstPassInfos(v);
			var buf = new StringBuf();
			function writeCell(cell:DElem, header:Bool)
			{
				var tag = header ? "th" : "td";
				buf.add('<$tag>');
				switch cell.def {
				case DParagraph(h):
					buf.add(genh(h));
				case _:
					buf.add(secondPass(cell, bcs));
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
				<h3 id="${infos.htmlId}" class="share">Table ${infos.no}$QUAD${genh(caption)}</h3>
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
			var infos = getFirstPassInfos(v);
			var p = saveAsset(path);
			return '
				<figure class="img-block ${sizeToClass(size)}">
				<h3 id="${infos.htmlId}" class="share">Table ${infos.no}$QUAD${genh(caption)}</h3>
				<a><img src="$p" class="overlay-trigger" alt="Table ${infos.no} ${genn(caption)}"/></a>
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
					buf.add(secondPass(i, bcs));
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
			return '<p${Render.posAttr(v.pos)}><span class="mathjax equation"${Render.posAttr(p)}>\\[${gent(tex)}\\]</span></p>\n';
		case DParagraph(h):
			return '<p${Render.posAttr(v.pos)}>${genh(h)}</p>\n';
		case DElemList(li):
			var buf = new StringBuf();
			for (i in li)
				buf.add(secondPass(i, bcs));
			return buf.toString();
		case DEmpty:
			return "";
		}
	}

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
		index = new Map();

		for (keyword in ["assets", "volume"])
			reserveBuffer(keyword);
		reserveBuffer(ROOT_URL);  // temporary due to ordering constraints
		reserveBuffer(TOC_URL);  // temporary due to ordering constraints

		// `toc.add` and `secondPass` ordering is relevant
		// it's necessary to process all `\html\head` before actually opening buffers and writing heads
		toc = new StringBuf();
		toc.add(
				'<div id="toc" class="tocfull">
					<ul><li class="index">${Render.tocItem(null, null, "BRT Planning Guide", ROOT_URL)}</li>
				'.doctrim());
		firstPass(doc, new IdCtx(), new NoCtx(), null);  // FIXME need a pseudo (or real) root page
		var contents = secondPass(doc, {});

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

