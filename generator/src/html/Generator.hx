package html;

import haxe.io.Bytes;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import transform.Context;
import transform.NewDocument;
import util.sys.FsUtil;

import Assertion.*;
import generator.tex.*;

using Literals;
using StringTools;
using parser.TokenTools;

enum NavItem {
	NDocument(children:Array<NavItem>);
	NVolume(no:Int, nameHtml:String, url:String, children:Array<NavItem>);
	NChapter(no:Int, nameHtml:String, url:String, children:Array<NavItem>);
	NSection(no:Int, nameHtml:String, url:String, children:Array<NavItem>);
	NSubSection(no:Int, nameHtml:String, url:String, children:Array<NavItem>);
	NSubSubSection(no:Int, nameHtml:String, url:String);
}

class Generator {
	static inline var ASSET_SUBDIR = "assets";
	@:template static var FILE_BANNER;

	var destDir:String;
	var godOn:Bool;
	var bufs:Map<String,StringBuf>;
	var stylesheets:Array<String>;
	var srcCache:Map<String,Int>;
	var lastSrcId:Int;
	static var assetCache = new Map<String,String>();

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
		case Emphasis(h), Highlight(h):
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

	function saveAsset(src:String, ?content:Bytes)
	{
		if (assetCache.exists(src))
			return assetCache[src];

		var dir = ASSET_SUBDIR;
		var ldir = Path.join([destDir, ASSET_SUBDIR]);
		if (!FileSystem.exists(ldir))
			FileSystem.createDirectory(ldir);

		var ext = Path.extension(src).toLowerCase();
		assert(ext != "", src);
		var data = content != null ? content : File.getBytes(src);
		var hash = haxe.crypto.Sha1.make(data).toHex();

		var name = hash + "." + ext;
		var dst = Path.join([dir, name]);
		var lpath = Path.join([ldir, name]);
		File.saveBytes(lpath, data);
		assetCache[src] = dst;
		return dst;
	}

	function openBuffer(title:String, base="")
	{
		// TODO get normalize and google fonts with \html\apply or \html\link
		// TODO get jquery and mathjax with \html\run
		var buf = new StringBuf();
		show(FILE_BANNER);
		buf.add("<!DOCTYPE html>");
		buf.add(FILE_BANNER);
		buf.add('
			<html>
			<head>
			<meta charset="utf-8">
			<title>${gent(title)}</title>
			<base href="$base">
			<!-- Normalize -->
			<link href="https://cdnjs.cloudflare.com/ajax/libs/normalize/4.0.0/normalize.min.css" rel="stylesheet" type="text/css">
			<!-- Jquery -->
			<script src = "https://ajax.googleapis.com/ajax/libs/jquery/2.1.0/jquery.min.js" ></script>
			<!-- MathJax -->
			<script type="text/x-mathjax-config">
				MathJax.Hub.Config({
					tex2jax: {
						ignoreClass: ".+",
						processClass: "mathjax"
					}
				});
			</script>
			<script async src="https://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS_CHTML" ></script>
			<!-- Google Fonts -->
			<link href="https://fonts.googleapis.com/css?family=PT+Serif:400,400italic,700italic,700|PT+Sans:400,400italic,700,700italic" rel="stylesheet" type="text/css">
			<!-- Custom CSSs -->
		'.doctrim());
		for (p in stylesheets)
			buf.add('<link href="./${p}" rel="stylesheet" type="text/css">\n');
		buf.add('
			</head>
			<body>
			<div class="container">
			<div class="col-text">
		'.doctrim());
		return buf;
	}

	static inline var QUAD = '<span class="quad"></span>';
	static inline var DRAFT_IMG_PLACEHOLDER = "https://upload.wikimedia.org/wikipedia/commons/5/56/Sauroposeidon_Scale_Diagram_Steveoc86.svg";
	static inline var DRAFT_IMG_PLACEHOLDER_COPYRIGHT = "Placeholder image by Steveoc 86 (Own work) <a href='http://creativecommons.org/licenses/by-sa/3.0'>CC BY-SA 3.0</a> or <a href='http://www.gnu.org/copyleft/fdl.html'>GFDL</a>, via Wikimedia Commons";

	function genv(v:DElem, idc:IdCtx, noc:NoCtx, navParent:Array<NavItem>)
	{
		switch v.def {
		case DHtmlApply(path):
			stylesheets.push(saveAsset(path));
			return "";
		case DLaTeXPreamble(_), DLaTeXExport(_):
			return "";
		case DVolume(no, name, children):
			idc.volume = v.id.sure();
			noc.volume = no;
			var path = Path.join(["volume", idc.volume+"index.html"]);
			var title = 'Volume $no: ${genn(name)}';
			var buf = bufs[path] = openBuffer(title, "..");
			var links = [];
			buf.add('
				<section>
				<h1 id="heading" class="volume${noc.volume}">$no$QUAD${genh(name)}</h1>
				${genv(children, idc, noc, links)}
				</section>
			'.doctrim());
			buf.add("\n");
			navParent.push(NVolume(no, genh(name), path, links));
			return "";
		case DChapter(no, name, children):
			idc.chapter = v.id.sure();
			noc.chapter = no;
			var path = Path.join([idc.chapter, "index.html"]);
			var title = 'Chapter $no: ${genn(name)}';
			var buf = bufs[path] = openBuffer(title, "..");
			var links = [];
			buf.add('
				<section>
				<h2 id="heading" class="volume${noc.volume}">$no$QUAD${genh(name)}</h2>
				${genv(children, idc, noc, links)}
				</section>
			'.doctrim());
			buf.add("\n");
			navParent.push(NChapter(no, genh(name), path, links));
			return "";
		case DSection(no, name, children):
			idc.section = v.id.sure();
			noc.section = no;
			var lno = noc.join(false, ".", chapter, section);
			var path = Path.join([idc.chapter, idc.section+".html"]);
			var title = '$lno ${genn(name)}';  // TODO chapter name
			var buf = bufs[path] = openBuffer(title, "..");
			var links = [];
			buf.add('
				<section>
				<h3 id="heading" class="volume${noc.volume}">$lno$QUAD${genh(name)}</h3>
				${genv(children, idc, noc, links)}
				</section>
			'.doctrim());
			buf.add("\n");
			navParent.push(NSection(no, genh(name), path, links));
			return "";
		case DSubSection(no, name, children):
			idc.subSection = v.id.sure();
			noc.subSection = no;
			var no = noc.join(false, ".", chapter, section, subSection);
			var id = idc.join(true, ".", subSection);
			return '
				<section>
				<h4 id="$id" class="volume${noc.volume}">$no$QUAD${genh(name)}</h4>
				${genv(children, idc, noc, navParent)}
				</section>
			'.doctrim() + "\n";
		case DSubSubSection(no, name, children):
			idc.subSubSection = v.id.sure();
			noc.subSubSection = no;
			var no = noc.join(false, ".", chapter, section, subSection, subSubSection);
			var id = idc.join(true, ".", subSection, subSubSection);
			return '
				<section>
				<h5 id="$id" class="volume${noc.volume}">$no$QUAD${genh(name)}</h5>
				${genv(children, idc, noc, navParent)}
				</section>
			'.doctrim() + "\n";
		case DBox(no, name, children):
			idc.box = v.id.sure();
			noc.box = no;
			var no = noc.join(false, ".", chapter, box);
			var id = idc.join(true, ".", box);
			var size = "md";  // TODO auto figure out it's size
			return '
				<section class="box $size">
				<h1 id="$id" class="volume${noc.volume}">Box $no <em>${genh(name)}</em></h1>
				${genv(children, idc, noc, navParent)}
				</section>
			'.doctrim() + "\n";
		case DFigure(no, size, path, caption, cright):
			idc.figure = v.id.sure();
			noc.figure = no;
			var no = noc.join(false, ".", chapter, figure);
			var id = idc.join(true, ".", figure);
			var size = "md";  // FIXME
			if (Context.draft) {
				return '
					<section class="img-block $size">
					<img src="$DRAFT_IMG_PLACEHOLDER"/>
					<p id="$id"><strong>Fig. $no</strong>$QUAD${genh(caption)} <em>$DRAFT_IMG_PLACEHOLDER_COPYRIGHT</em></p>
					</section>
				'.doctrim() + "\n";
			} else {
				var p = saveAsset(path);
				return '
					<section class="img-block $size">
					<img src="$p"/>
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
					buf.add(genv(cell, idc, noc, navParent));
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
				<section class="$size">
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
					buf.add(genv(i, idc, noc, navParent));
				}
				buf.add("</li>\n");
			}
			buf.add('</$tag>\n');
			return buf.toString();
		case DCodeBlock(code):
			return '<pre><code>${gent(code)}</code></pre>\n';
		case DQuotation(text, by):
			return '<blockquote class="md"><q>${genh(text)}</q><span class="by">${genh(by)}</span></blockquote>\n';
		case DParagraph(h):
			return '<p${genp(v.pos)}>${genh(h)}</p>\n';
		case DElemList(li):
			var buf = new StringBuf();
			for (i in li)
				buf.add(genv(i, idc, noc, navParent));
			return buf.toString();
		case DEmpty:
			return "";
		}
	}

	public function writeDocument(doc:NewDocument)
	{
		FileSystem.createDirectory(destDir);

		bufs = new Map();
		stylesheets = [];
		srcCache = new Map();
		lastSrcId = 0;

		var idc = new IdCtx();
		var noc = new NoCtx();
		var navRoot = [];
		var contents = genv(doc, idc, noc, navRoot);

		var nav = new StringBuf();
		var s = new haxe.Serializer();
		s.useCache = true;
		s.useEnumIndex = true;
		s.serialize(NDocument(navRoot));
		var navPath = saveAsset("nav.haxedata", Bytes.ofString(s.toString()));

		var srcMap = [
			for (p in srcCache.keys())
				srcCache[p] => p  // TODO src line maps
		];
		var s = new haxe.Serializer();
		s.useCache = true;
		s.useEnumIndex = true;
		s.serialize(srcMap);
		var srcMapPath = saveAsset("src.haxedata", Bytes.ofString(s.toString()));

		var root = openBuffer("The Online BRT Planning Guide");  // FIXME get it elsewhere
		root.add(contents);
		bufs["index.html"] = root;

		for (p in bufs.keys()) {
			var b = bufs[p];
			b.add("</div>\n</div>\n");
			b.add('<div class="data-nav" data-href="$navPath"></div>\n');
			b.add('<div class="data-src-map" data-href="$srcMapPath"></div>\n');
			b.add("</body>\n</html>\n");

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

