package generator;  // TODO move out of the package

import generator.HtmlGen.Nav;
import sys.FileSystem;
import transform.Document;

// temporary
import parser.Ast;

import haxe.io.Path.join in joinPaths;

typedef Nav = {
	name : String,
	id : String,
	type : Int,
	chd : Null<Array<Nav>>
}

typedef Path = String;

class HtmlGen {

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
	
	var dest:Path;

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
			return hierarchy(v, counts, curNav);
		case TFigure(path, caption, copyright, count,id):
			var caption = horizontal(caption);
			var copyright = horizontal(copyright);
			//navs.push({name : '', id : id,type : OTH, chd : null});
			//TODO: Make FIG SIZE param
			return '<section class="md img-block id="${id}"><img src="${path}"/><p><strong>Fig ${count}</strong>${caption} <em>${caption}</em></p>';
		case TQuotation(t,a):
			return '<blockquote class="md"><q>${horizontal(t)}</q><span>${horizontal(a)}</span></blockquote>';
		case TParagraph(h):
			return '<p>${horizontal(h)}</p>\n';
		case TList(li):
			var buf = new StringBuf();
			buf.add("<ul>\n");
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
			buf.add("</ul>\n");
			return buf.toString();
		case TVList(li):
			var buf = new StringBuf();
			for (i in li)
				buf.add(vertical(i, counts, curNav));
			return buf.toString();
		}
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

		//Vol. doesnt add anything
		if(type > 0)
			buff.add('<section><h${(type+1)} id="${_id}">${count} ${_name}</h${(type + 1)}>');
		else
			buff.add('<section>');
		
		buff.add(vertical(_children, counts, curNav));
		
		buff.add("</section>");

		return buff.toString();
	}
	
	function processNav() : { volumes : String, sections : String, topNavJs : String}
	{
		var topBuff = new StringBuf();
		var leftBuff = new StringBuf();
		
		//Nav options (will gen a JS);
		var optBuff = new Map<String, {list : String, type : Int}>();
		
		topBuff.add("<header><ul class='menu'><li><a> BRTPG</a><ul class='item hide'>");
		
		leftBuff.add("<nav><ul>");
		
		//Should be volumes
		for (n in navs)
		{
			topBuff.add('<li id="${n.id}"><a href="#">${n.name}</a></li>');
			if (n.chd != null && n.chd.length > 0)
			{
				var cha = '<a> Chapters </a><ul class=\"item hide\">';
				
				for (c in n.chd)
				{
					cha += '<li id="${c.id}"><a href="#">${c.name}</a></li>';
					
					if (c.chd != null && c.chd.length > 0)
					{
						var sec = "<a>Sections</a><ul class=\"item hide\">";
						
							for (se in c.chd)
							{
								//TODO: Href the right HTML
								sec += '<li><a href="#">${se.name}"</a></li>';
								
								//I think I'll need a map instead(so I gen only the necessary sections
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
						sec += '</ul>';
						optBuff.set(c.id, {list : sec, type : SEC});
					}
				}
				
				cha += "</ul>";
				optBuff.set(n.id, {list : cha, type : CHA});
			}
			
			
		}
		
		topBuff.add("</li></ul></li><li>/</li></ul></header>");
		leftBuff.add('</ul></nav>');
		
		return {volumes : topBuff.toString(), sections : leftBuff.toString(), topNavJs : genNavJs(optBuff)};
	}
	
	
	function genNavJs(values : Map<String,{list : String, type : Int}>) : String
	{
		var buff = new StringBuf();
		buff.add('<script>');
		
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
			//TODO: Optimize
			buff.add('
				$("#${id}").off("click"); \n
				$("#${id}").click(function()
				{
					var v = {type : ${values.get(key).type}, list : \'${values.get(key).list}\'};
					var menu = $(".menu");
					
					while (((v.type)) < ((menu.children("li").length)/2))
					{
						console.log(v.type + 1);
						console.log(((menu.children("li").length - 1) / 2));
						menu.children("li").last().remove();
					}
					
					console.log("click!");
					
					menu.append("<li>" + v.list + "</li>");
					menu.append("<li>/<li>");
					console.log(menu.children().last().children("ul").attr("id"));
					
					//Bind evt again (TODO: Rewrite)
					hover();
					onClick();
					
				});'
			);
		
			buff.add("\n");
		}
		buff.add("}\n");
		
		buff.add("$(document).ready(function(){onClick();hover();});");
		buff.add("</script>");
		return buff.toString();
	}
	
		
	function document(doc:Document)
	{
		navs = new Array<Nav>();

		var buf = new StringBuf();
		buf.add('<meta charset="utf-8">
	<title></title>
	<!-- Google Fonts -->
	<link href="https://fonts.googleapis.com/css?family=PT+Serif:400,400italic,700italic,700|PT+Sans:400,400italic,700,700italic" rel="stylesheet" type="text/css">
	<!-- Normalize -->
	<link href="https://cdnjs.cloudflare.com/ajax/libs/normalize/4.0.0/normalize.min.css" rel="stylesheet" type="text/css">
	<!-- CSS -->
	<link href="style.css" rel="stylesheet" type="text/css">
	<!-- MathJax -->
	<script src="https://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML"></script>
	<!-- Jquery -->
	<script src="https://ajax.googleapis.com/ajax/libs/jquery/2.1.0/jquery.min.js"></script><body><div class="container"><div class="col-text"\n');
		buf.add(vertical(doc,[0,0,0,0,0,0], null));
		buf.add('</div>');
		var navElements = processNav();
		buf.add(navElements.sections);
		buf.add('</div>');
		buf.add(navElements.volumes);
		buf.add(navElements.topNavJs);
		buf.add('</body>');
		sys.io.File.saveContent(joinPaths([dest,"index.html"]), buf.toString());
	}

	public function generate(doc:Document)
	{
		if (!FileSystem.exists(dest))
			FileSystem.createDirectory(dest);
		else if (!FileSystem.isDirectory(dest))
			throw 'Not a directory: $dest';

		document(doc);
	}

	public function new(dest:Path)
		this.dest = dest;
}

