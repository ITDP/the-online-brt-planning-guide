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

	function vertical(v:TElem, counts : Array<Int>)
	{
		switch v.def {
		case TVolume(name, count, id, children), TChapter(name, count, id, children),
		TSection(name, count, id, children), TSubSection(name, count, id, children),
		TSubSubSection(name, count, id, children):
			return hierarchy(v, counts);
		case TFigure(path, caption, copyright, count,id):
			var caption = horizontal(caption);
			var copyright = horizontal(copyright);
			navs.push({name : '', id : id});
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
				buf.add(vertical(i, counts));
				buf.add("</li>\n");
			}
			buf.add("</ul>\n");
			return buf.toString();
		case TVList(li):
			var buf = new StringBuf();
			for (i in li)
				buf.add(vertical(i, counts));
			return buf.toString();
		}
	}

	function hierarchy(cur : TElem, counts : Array<Int>)
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


		navs.push({id : _id , name : _name});

		var count = countGen(counts, type, ".");

		//Vol. doesnt add anything
		if(type > 0)
			buff.add('<section id="${_id}"><h${(type+1)}>${count} ${_name}</h${(type + 1)}>');
		else
			buff.add('<section id="${_id}">');

		buff.add(vertical(_children, counts));

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
		buf.add(vertical(doc,[0,0,0,0,0,0]));
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


}

