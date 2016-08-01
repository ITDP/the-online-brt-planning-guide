package generator;  // TODO move out of the package

import haxe.io.Path;
import parser.Ast.HElem;
import sys.FileSystem;
import sys.io.File;
import transform.Document;

import Assertion.*;
import haxe.io.Path.join in joinPaths;

using Literals;
using parser.TokenTools;
using transform.DocumentTools;
using StringTools;

typedef Nav = {
	name : String,
	id : String,
	type : Int,
	chd : Null<Array<Nav>>
}

class HtmlGen {

	static inline var JSName =  "navscript.js";
	static inline var ASSET_SUBDIR = "assets";

	static inline var VOL = 0;
	static inline var CHA = 1;
	static inline var SEC = 2;
	static inline var SUB = 3;
	static inline var SUBSUB = 4;
	//Figs,tbls,etc
	static inline var OTH = 5;

	var navs : Array<Nav>;
	var navTop : String;
	var navLeft : String;

	var cur_chapter_name : String;

	var css : Array<String>;

	var dest:String;

	function saveAsset(path:String)
	{
		var dir = ASSET_SUBDIR;
		var ldir = Path.join([dest, ASSET_SUBDIR]);
		if (!FileSystem.exists(ldir))
			FileSystem.createDirectory(ldir);

		var ext = Path.extension(path).toLowerCase();
		assert(ext != "", path);
		var data = File.getBytes(path);
		var hash = haxe.crypto.Sha1.make(data).toHex();

		var name = hash + "." + ext;
		var path = Path.join([dir, name]);
		var lpath = Path.join([ldir, name]);
		File.saveBytes(lpath, data);
		return path;
	}

	function horizontal(h:HElem)
	{
		return switch h.def {
		case Wordspace: " ";
		case Emphasis(i): '<em>${horizontal(i)}</em>';
		case Highlight(i): '<strong>${horizontal(i)}</strong>';
		case Word(w): w.htmlEscape();
		case InlineCode(c): '<code>${c.htmlEscape()}</code>';
		case Math(tex): '<span class="mathjax">\\(${tex.htmlEscape()}\\)</span>';
		case HList(li):
			var buf = new StringBuf();
			for (i in li)
				buf.add(horizontal(i));
			buf.toString();
		case HEmpty: "";
		}
	}

	function sizeToClass(s:BlobSize)
	{
		return switch s {
		case MarginWidth: "sm";
		case TextWidth: "md";
		case FullWidth: "lg";
		}
	}

	function vertical(v:TElem, counts : Array<Int>, curNav : Null<Nav>) : String
	{
		switch v.def {
		case TVolume(name, count, id, children), TChapter(name, count, id, children),
		TSection(name, count, id, children), TSubSection(name, count, id, children),
		TSubSubSection(name, count, id, children):
			return hierarchy(v, counts, curNav);
		case TFigure(size, path, caption, copyright, count,id):
			var caption = horizontal(caption);
			var copyright = horizontal(copyright);
			var _path = saveAsset(path);
			//TODO: Make FIG SIZE param
			return ('
			<section class="${sizeToClass(size)} img-block id="${id}">
				<img src="../${_path}"/>
				<p><strong>Fig. ${counts[CHA]}.${count}</strong><span class="quad"></span>${caption} <em>${copyright}</em></p>
			</section>\n'.doctrim());
		case TBox(name, contents, count, id):
			var isLarge = false;
			function findSize(v:TElem) {
				if (v == null) return;
				if (v.def.match(TFigure(MarginWidth|FullWidth, _) | TTable(MarginWidth|FullWidth, _)))
					isLarge = true;
				v.iter(findSize);
			}
			findSize(contents);
			var b = new StringBuf();
			b.add('<section class="box ${isLarge ? "lg" : "md"}">\n');
			b.add('<h1>Box ${counts[CHA]}.${count}<span class="quad"></span><em>${horizontal(name)}</em></h1>\n');
			b.add(vertical(contents, counts, curNav));
			b.add('</section>\n');
			return b.toString();
		case TQuotation(t, a):
			return ('<blockquote class="md"><q>${horizontal(t)}</q><span>${horizontal(a)}</span></blockquote>\n');
		case TCodeBlock(c):
			return '<pre><code>$c</code></pre>\n';
		case TParagraph(h):
			return ('<p>${horizontal(h)}</p>\n');
		case TList(numbered, li):
			var buf = new StringBuf();
			buf.add(numbered ? "<ol>\n" : "<ul>\n");
			for (i in li) {
				buf.add("<li>");
				switch i.def {
				case TParagraph(h):
					buf.add(horizontal(h));
				case _:
					buf.add(vertical(i, counts, curNav));
				}
				buf.add("</li>\n");
			}
			buf.add(numbered ? "</ol>\n" : "</ul>\n");
			return (buf.toString());
		case TVList(li):
			var buf = new StringBuf();
			for (i in li)
				buf.add(vertical(i, counts, curNav));
			return buf.toString();
		case THtmlApply(path):
			css.push(saveAsset(path));
			return null;
		case TLaTeXPreamble(_) | TLaTeXExport(_):
			return null;  // ignore
		case TTable(size, caption, header, chd, count, id):
			var buff = new StringBuf();
			counts[OTH] = count;
			buff.add('<section class="${sizeToClass(size)}"><h5 id="${id}">Table ${counts[CHA] + "." + counts[OTH]}. ${horizontal(caption)}</h5>'); //TODO:
			buff.add("<table>");
			buff.add(processTable([header], true));
			buff.add(processTable(chd));
			buff.add("</table></section>\n");
			return buff.toString();
		}
	}

	function processTable(body : Array<Array<TElem>>, ?isHeadMode : Bool)
	{
		var buff = new StringBuf();
		buff.add(addTblHeader(isHeadMode, false));

		for (row in body)
		{
			buff.add("<tr>");
			for (col in row)
			{
				buff.add(addColumn(isHeadMode, false));

				buff.add(processTableElem(col));

				buff.add(addColumn(isHeadMode, true));
			}
			buff.add("</tr>");
		}

		buff.add(addTblHeader(isHeadMode, true));
		return buff.toString();
	}

	function processTableElem(elem : TElem)
	{
		if (elem == null)
			return "";
		var b = new StringBuf();
		switch(elem.def)
		{
			case TParagraph(h):
				b.add(horizontal(h));
			case TList(numbered, li):
				b.add(vertical(elem, null, null));  // FIXME
			default:
				throw "Invalid table element: " + elem.def.getName() + " pos : " + elem.pos.min + " at " + elem.pos.src;
		}

		return b.toString();
	}

	function addColumn(isHeadMode : Bool, isEnd : Bool)
	{
		if (isHeadMode)
		{
			if (!isEnd)
				return ("<th>");
			else
				return ("</th>");
		}
		else
		{
			if (!isEnd)
				return ("<td>");
			else
				return ("</td>");
		}
	}

	function addTblHeader(isHead : Bool, isEnd : Bool)
	{
		if (isHead)
		{
			if (!isEnd)
				return ("<thead>");
			else
				return ("</thead>");
		}
		else
		{
			if (!isEnd)
				return ("<tbody>");
			else
				return ("</tbody>");
		}
	}

	function hierarchy(cur : TElem, counts : Array<Int>, curNav : Nav)
	{

		var buff = new StringBuf();
		var _children = null;
		var _name  = "";
		var _id = "";
		var type : Null<Int> = null;

		switch(cur.def)
		{
			case TVolume(name, count, id, children):
				_name = horizontal(name);
				_id = id;
				counts[VOL] = count;
				_children = children;
				type = VOL;
			case TChapter(name, count,id, children):
				_name = horizontal(name);
				_id = id;
				counts[CHA] = count;
				_children = children;
				type = CHA;
				cur_chapter_name = _name;
			case TSection(name, count,id, children):
				_name = horizontal(name);
				_id = id;
				counts[SEC] = count;
				type = SEC;
				_children = children;
			case TSubSection(name, count,id, children):
				_name = horizontal(name);
				_id = id;
				counts[SUB] = count;
				_children = children;
				type = SUB;
			case TSubSubSection(name, count,id, children):
				_name = horizontal(name);
				_id = id;
				counts[SUBSUB] = count;
				_children = children;
				type = SUBSUB;
			default:
				throw "Invalid element " + cur.def;
		}

		var _nav = {id : _id , name : _name, type : type, chd : []};

		if(curNav != null)
			curNav.chd.push(_nav);
		else
			navs.push(_nav);

		curNav = _nav;

		var count = counts.slice(1, type + 1).join(".");



		if(type > 0)
			buff.add('<section><h${(type+1)} id="${_id}">${count}<span class="quad"></span>${_name}</h${(type + 1)}>\n');

		buff.add(vertical(_children, counts, curNav));

		if(type > 0)
			buff.add("</section>\n");

		//Section already processed, clear buff , continue program execution
		if (type == SEC || type == CHA)
		{
			var title = (type == SEC) ?
			'${counts.slice(1, 3).join(".")} ${_name} [${cur_chapter_name}]' : '${counts[1]} $_name';

			if(type == SEC)
				fileGen(buff.toString(), curNav, title);
			else
				fileGen(buff.toString(), curNav, title, "index");

			return "";
		}

		return buff.toString();
	}

	function processNav(curSec : Null<Nav>) : { sections : String, topNavJs : String}
	{
		var topBuff = new StringBuf();
		var leftBuff = new StringBuf();

		//Nav options (will gen a JS);
		var optBuff = new Map<String, {list : String, type : Int}>();

		leftBuff.add("<nav><ul>");

		//Should be volumes
		for (n in navs)
		{
			topBuff.add('<li id="${n.id}"><a href="#">${n.name}</a></li>');
			if (n.chd != null && n.chd.length > 0)
			{
				var cha = '<a>${n.name}</a><ul style="margin-left:114px;" class=\"item hide\">';

				for(c in n.chd)
				{
					var cha_name = c.id.split(".")[3];
					//var first_sec_name = c.chd[0].id.split(".")[5];
					cha += '<li id="${c.id}"><a href="../${cha_name}/index.html">${c.name}</a></li>';

					if (c.chd != null && c.chd.length > 0)
					{
						var sec = '<a>${c.name}</a><ul style="margin-left:317px;" class=\"item hide\">';

							for (se in c.chd)
							{
								var se_params = se.id.split('.');

								var sec_name = se_params[5];

								sec += '<li><a href="../${cha_name}/${sec_name}.html">${se.name}</a></li>';

								if (curSec != null && curSec == se)
								{
									leftBuff.add('<li><a href="#${se.id}">${se.name}</li>');

									for (su in se.chd)
									{
										leftBuff.add('<li><a href="#${su.id}">${su.name}</li>');
									}
									//leftBuff.add("</ul></li>");
								}
							}
						sec += '</ul>';
						optBuff.set(c.id, {list : sec, type : SEC});
					}
				}

				cha += "</ul>";
				optBuff.set(n.id, {list : cha, type : CHA});
			}


		}

		leftBuff.add('</ul></nav>');

		return {sections : leftBuff.toString(), topNavJs : genNavJs(optBuff, topBuff.toString())};
	}


	function genNavJs(values : Map<String,{list : String, type : Int}>, volumesList : String) : String
	{
		var buff = new StringBuf();

		buff.add('function init()
		{
			$(".volumes").append(\'${volumesList}\');
		}');

		buff.add("function hover()
		{
			$('header li ul').off('hover');

			$('header li ul').hide().removeClass('hide');
			$('header li').hover(
			  function () {
				$('ul', this).stop().slideDown(100);
			  },
			  function () {
				$('ul', this).stop().slideUp(100);
			  }
			);
		}");

		buff.add('\nfunction onClick(){');
		for (key in values.keys())
		{
			var id = key.split(".").join("\\\\.");
			//TODO: Optimize:
			buff.add('
				$("#${id}").off("click"); \n
				$("#${id}").click(function()
				{
					var v = {type : ${values.get(key).type}, list : \'${values.get(key).list}\'};
					var menu = $(".menu");
					//console.log(v.type);
					//console.log(menu.children("li").length);
					while (((v.type)) < ((menu.children("li").length)/2))
					{
						//console.log("removed");
						menu.children("li").last().remove();
					}
					//console.log(v.list);
					if(!(menu.children("li").last().html() == "<a>/</a>"))
						menu.append("<li><a>/</a></li>");
					menu.append("<li>" + v.list + "</li>");

					//Bind evt again (TODO: Rewrite)
					hover();
					onClick();

				});'
			);

			buff.add("\n");
		}
		buff.add("}\n");
		buff.add('function post()
		{
			var fullid = $(".col-text").children("section").first().children("h3,h2").attr("id").split(".");
			var vol_id = fullid.slice(0, 2).join("\\\\.");
			$("#" + vol_id).trigger("click");
			$("#" + fullid.slice(0, 4).join("\\\\.")).trigger("click");
			$("#" + fullid.slice(0, 6).join("\\\\.")).trigger("click");
		}\n');
		buff.add("$(document).ready(function(){init();onClick();hover();post();});");

		return buff.toString();
	}

	//TODO: add custom params...later
	function headGen(jsFile : String, title : String)
	{
		var staticres = '<head>
			<meta charset="utf-8">
			<title>${title}</title>
			<!-- Normalize -->
			<link href="https://cdnjs.cloudflare.com/ajax/libs/normalize/4.0.0/normalize.min.css" rel="stylesheet" type="text/css">
			<!-- Jquery -->
			<script src = "https://ajax.googleapis.com/ajax/libs/jquery/2.1.0/jquery.min.js" ></script>
			<script src="${jsFile}"></script>
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
			${css.map(function (p) return '<link href="../${p}" rel="stylesheet" type="text/css">').join("\n")}
			</head> ';

		return staticres;
	}

	function fileGen(content : String, nav : Nav, title : String, ?filename : String)
	{
		if (nav == null)
			throw "Invalid access";

		var params = nav.id.split(".");

		var chap = params[3];
		var sec = params[5];
		var path = dest + "/" + chap;
		if (!FileSystem.exists(path))
			FileSystem.createDirectory(path);

		var buff = new StringBuf();
		buff.add(headGen("../" + JSName, title));

		buff.add('<body><div class="container"><div class="col-text">');
		buff.add(content);
		buff.add('</div>');
		buff.add(processNav(nav).sections);
		buff.add('</div>');
		buff.add("<header><ul class='menu'><li><a><strong>BRT Planning Guide</strong></a><ul class='item hide volumes'></ul></li></ul></header>");

		File.saveContent(joinPaths([path,  ((filename != null) ? filename : sec) + ".html"]), buff.toString());
	}

	function document(doc:Document)
	{
		css = new Array<String>();
		navs = new Array<Nav>();
		vertical(doc,[0,0,0,0,0,0], null);

		//JS name
		File.saveContent(joinPaths([dest, JSName]), processNav(null).topNavJs);

	}

	public function generate(doc:Document)
	{
		if (!FileSystem.exists(dest))
			FileSystem.createDirectory(dest);
		else if (!FileSystem.isDirectory(dest))
			throw 'Not a directory: $dest';

		document(doc);
	}

	public function new(dest:String)
		this.dest = dest;
}

