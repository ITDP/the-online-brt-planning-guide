package generator;  // TODO move out of the package

import generator.HtmlGen.Nav;
import sys.FileSystem;
import transform.Document;

// temporary
import parser.Ast;

import haxe.io.Path.join in joinPaths;

typedef Nav = {
	name : String,
	id : String
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
	
	//
	var navs : Array<Nav>;
	
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
	
	function vertical(v:TElem, counts : Array<Int>, names : Array<String>)
	{
		switch v.def {
		case TVolume(name, count, children), TChapter(name, count, children), 
		TSection(name, count, children), TSubSection(name, count, children),
		TSubSubSection(name, count, children):
			return hierarchy(v, counts, names);
		case TFigure(path, caption, copyright, count):
			var caption = horizontal(caption);
			var copyright = horizontal(copyright);
			names[OTH] = count + '';
			navs.push({name : '', id : idGen(names, OTH)});
			//TODO: Make FIG SIZE param
			return '<section class="md img-block id="${navs[navs.length-1].id}"><img src="${path}"/><p><strong>Fig ${count}</strong>${caption} <em>${caption}</em></p>'; 
		case TQuotation(t,a):
			return '<blockquote class="md"><q>${horizontal(t)}</q><span>${horizontal(a)}</span></blockquote>';
		case TParagraph(h):
			return '<p>${horizontal(h)}</p>\n';
		case TVList(li):
			var buf = new StringBuf();
			for (i in li)
				buf.add(vertical(i, counts, names));
			return buf.toString();
		}
	}
	
	function hierarchy(cur : TElem, counts : Array<Int>, names : Array<String>)
	{
		var buff = new StringBuf();
		var _children = null;
		var _name  = "";
		
		var type : Int = null;
		
		switch(cur.def)
		{
			case TVolume(name, count, children):
				_name = horizontal(name);
				counts[VOL] = count;
				_children = children;
				type = VOL;
			case TChapter(name, count, children):
				_name = horizontal(name);
				counts[CHA] = count;
				_children = children;
				type = CHA;
			case TSection(name, count, children):
				_name = horizontal(name);
				counts[SEC] = count;
				type = SEC;
				_children = children;
			case TSubSection(name, count, children):
				_name = horizontal(name);
				counts[SUB] = count;
				_children = children;
				type = SUB;
			case TSubSubSection(name, count, children):
				_name = horizontal(name);
				counts[SUBSUB] = count;
				_children = children;
				type = SUBSUB;
			default:
				throw "Invalid element " + cur.def;
		}
		
		var id = idGen(names, type);
		navs.push({id : id , name : _name});
		
		names[type] = _name;
		
		var count = countGen(counts, type, ".");
		
		//Vol. doesnt add anything
		if(type > 0)
			buff.add('<section id="${id}"><h${(type+1)}>${count} ${_name}</h${(type + 1)}>');
		else
			buff.add('<section id="${id}">');
		
		buff.add(vertical(_children, counts, names));
		
		buff.add("</section>");
		
		return buff.toString();
	}
	
	function processNav() : String
	{
		var leftTxt = new StringBuf();
		var topTxt = new StringBuf();
		topTxt.add("<ul class='menu'>");
		
		for (n in navs)
		{
			if (n.id.indexOf("other.") == -1)
			{
				var idpartials = n.id.split(".");
				//Assuming id ~= volume.Foo.chapter.bar.section.red.subsection.blue.subsub.grn
				if (idpartials.length <= 4)
				{
					//TODO: Point to the right FILE
					topTxt.add('<li><a href="#${n.id}">${n.name}</a></li>');
				}
				else
				{
					
				}
			}
		}
		
		//TODO:
		return "";
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
		buf.add(vertical(doc,[0,0,0,0,0,0], ['','','','','','']));
		buf.add('</div></div></body>');
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
		
		
	function countGen(counts : Array<Int>, elem : Int, sep : String)
	{
		var i = 0;
		var str = new StringBuf();
		while (i <= elem)
		{
			if(i != elem)
				str.add(counts[i] + sep);
			else
				str.add(counts[i]);
			i++;
		}
		
		return str.toString();
	}
	
	function idGen(counts : Array<String>, elem : Int)
	{
		var i = 0;
		var str = new StringBuf();
		
		while (i <= elem)
		{
			var before = switch(i)
			{
				case VOL:
					"volume.";
				case CHA:
					"chapter.";
				case SEC:
					"section.";
				case SUB:
					"subsection.";
				case SUBSUB:
					"subsubsection.";
				case OTH:
					"other.";
				default:
					null;
			}
			
			var clearstr = counts[i];
			trace(counts[i]);
			clearstr = StringTools.replace(clearstr," ", "-");
		
			var reg = ~/[a-zA-Z0-9-]+/;
			trace(clearstr);
			if(!reg.match(clearstr))
				break;
			clearstr = reg.matched(0);
			
			if(i != elem)
				str.add(before + clearstr + ".");
			else
				str.add(before + clearstr);
			
			i++;		
		}
		
		return str.toString();
	}
}

