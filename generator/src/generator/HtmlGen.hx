package generator;  // TODO move out of the package

import haxe.io.Path;
import parser.Ast.HElem;
import sys.FileSystem;
import sys.io.File;
import transform.Document;

import Assertion.*;
import haxe.io.Path.join in joinPaths;

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
	var curBuff : StringBuf;
	
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
		case Word(w): w;
		case HList(li):
			var buf = new StringBuf();
			for (i in li)
				buf.add(horizontal(i));
			buf.toString();
		}
	}
	
	function vertical(v:TElem, counts : Array<Int>, curNav : Null<Nav>)
	{
		switch v.def {
		case TVolume(name, count, id, children), TChapter(name, count, id, children),
		TSection(name, count, id, children), TSubSection(name, count, id, children),
		TSubSubSection(name, count, id, children):
			hierarchy(v, counts, curNav);
		case TFigure(path, caption, copyright, count,id):
			var caption = horizontal(caption);
			var copyright = horizontal(copyright);
			//navs.push({name : '', id : id,type : OTH, chd : null});
			//TODO: Make FIG SIZE param
			curBuff.add('<section class="md img-block id="${id}"><img src="${path}"/><p><strong>Fig ${count}</strong>${caption} <em>${caption}</em></p>');
		case TBox(contents):
			curBuff.add('<section class="box">\n');
			vertical(contents, counts, curNav);
			curBuff.add('</section>\n');
		case TQuotation(t,a):
			curBuff.add('<blockquote class="md"><q>${horizontal(t)}</q><span>${horizontal(a)}</span></blockquote>');
		case TParagraph(h):
			curBuff.add('<p>${horizontal(h)}</p>\n');
		case TList(li):
			var buf = new StringBuf();
			buf.add("<ul>\n");
			for (i in li) {
				buf.add("<li>");
				switch i.def {
				case TParagraph(h):
					buf.add(horizontal(h));
				case _:
					vertical(i, counts, curNav);
				}
				buf.add("</li>\n");
			}
			buf.add("</ul>\n");
			curBuff.add(buf.toString());
		case TVList(li):
			//var buf = new StringBuf();
			for (i in li)
				vertical(i, counts, curNav);
		case THtmlApply(path):
			css.push(saveAsset(path));
		case TLaTeXPreamble(_):
			null;  // ignore
		case TTable(caption, header, chd, count, id):
			counts[OTH] = count;
			curBuff.add("<section class='lg'>");
			curBuff.add('<h4 id="${id}">Table ${counts[CHA] +"." + counts[OTH]} : ${horizontal(caption)}</h4>'); //TODO:
			curBuff.add("<table>");
			processTable([header], true);
			processTable(chd);
			curBuff.add("</table></section>");
			
		}
	}
	
	//isColumnMode and isHeadMode are optional because I'll call then inside the function
	//E.G: This function assumes that row0 is always a header, isColumn mode starts with false or null
	//because it assumes an object is of type TR[TD[Val]] (same as HTML table standard).
	function processTable(body : Array<Array<TElem>>, ?isHeadMode : Bool)
	{
		if (isHeadMode)
			curBuff.add("<thead>");
		else
			curBuff.add("<tbody>");
			
		for (row in body)
		{
			curBuff.add("<tr>");
			for (col in row)
			{
				if (isHeadMode)
					curBuff.add("<th>");
				else
					curBuff.add("<td>");
					
				switch(col.def)
				{
					case TParagraph(h):
						curBuff.add(horizontal(h));
					default:
						throw "NI";
				}
				
				if (isHeadMode)
					curBuff.add("</th>");
				else
					curBuff.add("</td>");
			}
			curBuff.add("</tr>");
		}
		
		if (isHeadMode)
			curBuff.add("</thead>");
		else
			curBuff.add("</tbody>");
	}
	
	function hierarchy(cur : TElem, counts : Array<Int>, curNav : Nav)
	{
		var buff = new StringBuf();
		var _children = null;
		var _name  = "";
		var _id = "";
		var type : Int = null;

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
		
		
		
		//Vol. and Chapter doesnt add anything
		if(type > 1)
			curBuff.add('<section><h${(type+1)} id="${_id}">${count} ${_name}</h${(type + 1)}>');
		
		vertical(_children, counts, curNav);
		
		if(type > 1)
			curBuff.add("</section>");
		
		//Section already processed, clear buff , continue program execution
		if (type == 2 && curBuff.length > 0)
		{			
			fileGen(curBuff.toString(), curNav);
			curBuff = new StringBuf();
		}
		
		
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
				var cha = '<a> ${n.name} </a><ul style="margin-left:46px;" class=\"item hide\">';
				
				for(c in n.chd)
				{
					var cha_name = c.id.split(".")[3];
					
					cha += '<li id="${c.id}"><a href="../${cha_name}/${cha_name}.html">${c.name}</a></li>';
					
					if (c.chd != null && c.chd.length > 0)
					{
						var sec = '<a>${c.name}</a><ul style="margin-left:258px;" class=\"item hide\">';
						
							for (se in c.chd)
							{
								var se_params = se.id.split('.');
								
								var sec_name = se_params[5];
								
								sec += '<li><a href="../${cha_name}/${sec_name}.html">${se.name}</a></li>';
								
								if (curSec != null && curSec == se)
								{
									for (su in se.chd)
									{
										leftBuff.add('<li><a href="#${su.id}">${su.name}</li>');
										if (se.chd != null && se.chd.length > 0)
										{
											leftBuff.add('<li><ul>');
											for (ss in su.chd)
											{
												leftBuff.add('<li><a href="#${ss.id}">${ss.name}</a></li>');
											}
											leftBuff.add('</ul></li>');
										}
									}
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
		
		//topBuff.add();
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
					
					while (((v.type)) < ((menu.children("li").length)/2))
					{
						menu.children("li").last().remove();
					}
					
					menu.append("<li>" + v.list + "</li>");
					menu.append("<li>/<li>");
					
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
			var fullid = $(".col-text").children("section").first().children("h3").attr("id").split(".");
			var vol_id = fullid.slice(0, 2).join("\\\\.");
			$("#" + vol_id).trigger("click");
			$("#" + fullid.slice(0, 4).join("\\\\.")).trigger("click");
			$("#" + fullid.slice(0, 6).join("\\\\.")).trigger("click");
		}\n');
		buff.add("$(document).ready(function(){init();onClick();hover();post();});");

		return buff.toString();
	}
	
	//TODO: add custom params...later
	function headGen(jsFile : String)
	{
		var staticres = '<head>
			<meta charset="utf-8">
			<title></title>
			<!-- Custom CSSs -->
			${css.map(function (p) return '<link href="../${p}" rel="stylesheet" type="text/css">').join("\n")}
			<!-- Jquery -->
			<script src = "https://ajax.googleapis.com/ajax/libs/jquery/2.1.0/jquery.min.js" ></script>
			<script src="${jsFile}"></script>
			<!-- MathJax -->
			<script src = "https://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML" ></script>
			
			<!-- Google Fonts -->
			<link href="https://fonts.googleapis.com/css?family=PT+Serif:400,400italic,700italic,700|PT+Sans:400,400italic,700,700italic" rel="stylesheet" type="text/css">
			<!-- Normalize -->
			<link href="https://cdnjs.cloudflare.com/ajax/libs/normalize/4.0.0/normalize.min.css" rel="stylesheet" type="text/css">
			</head> ';
			
		return staticres;
	}
	
	function fileGen(content : String, nav : Nav)
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
		buff.add(headGen("../" + JSName));
		
		buff.add('<body><div class="container"><div class="col-text">');
		buff.add(content);
		buff.add('</div>');
		buff.add(processNav(nav).sections);
		buff.add('</div>');
		buff.add("<header><ul class='menu'><li><a> BRTPG</a><ul class='item hide volumes'></ul></li><li>/</li></ul></header>");
		
		File.saveContent(joinPaths([path, sec + ".html"]), buff.toString());
		
		
	}
		
	function document(doc:Document)
	{
		css = new Array<String>();
		navs = new Array<Nav>();
		curBuff = new StringBuf();
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

