package generator;  // TODO move out of the package

import sys.FileSystem;
import transform.Document;

// temporary
import parser.Ast;

import haxe.io.Path.join in joinPaths;

typedef Path = String;

class HtmlGen {
	
	static inline var VOL = 0;
	static inline var CHA = 1;
	static inline var SEC = 2;
	static inline var SUB = 3;
	static inline var SUBSUB = 4;
	//Figs,tbls,etc
	static inline var OTH = 5;
	
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
	 
	function idGen(counts : Array<Int>, elem : Int, sep : String)
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
	function hierarchy(cur : TElem, counts : Array<Int>)
	{
		var buff = new StringBuf();
		var _children = null;
		var type : Int = null;
		
		switch(cur.def)
		{
			case TVolume(name, count, children):
				counts[VOL] = count;
				_children = children;
				type = VOL;				
				buff.add('<section id="${idGen(counts, VOL, "_")}"><h1>${horizontal(name)}</h1>');
			case TChapter(name, count, children):
				counts[CHA] = count;
				_children = children;
				type = VOL;
				buff.add('<section id="${idGen(counts, CHA, "_")}"><h2>${idGen(counts, CHA, ".")} ${horizontal(name)}</h2>');
			case TSection(name, count, children):
				counts[SEC] = count;
				type = VOL;
				_children = children;
				buff.add('<section id="${idGen(counts, SEC, "_")}"><h3>${idGen(counts, SEC, ".")} ${horizontal(name)}</h2>');
			case TSubSection(name, count, children):
				counts[SUB] = count;
				_children = children;
				type = VOL;
				buff.add('<section id="${idGen(counts, SUB, "_")}"><h4>${idGen(counts, SUB, ".")} ${horizontal(name)}</h4>');
			case TSubSubSection(name, count, children):
				counts[SUBSUB] = count;
				_children = children;
				type = VOL;
				buff.add('<section id="${idGen(counts, SUBSUB, "_")}"><h5>${idGen(counts, SUBSUB, ".")} ${horizontal(name)}</h5>');
			default:
				throw "Invalid element " + cur.def;
		}
		
		buff.add(vertical(_children, counts));
		
		buff.add("</section>");
		
		return buff.toString();
	}
	
	
	function vertical(v:TElem, counts : Array<Int>)
	{
		switch v.def {
		case TVolume(name, count, children), TChapter(name, count, children), 
		TSection(name, count, children), TSubSection(name, count, children),
		TSubSubSection(name, count, children):
			return hierarchy(v, counts);
		case TFigure(path, caption, copyright, count):
			var caption = horizontal(caption);
			var copyright = horizontal(copyright);
			//TODO: Make FIG SIZE param
			return '<section class="md img-block><img src="${path}"/><p><strong>Fig ${count}</strong>${caption} <em>${caption}</em></p>'; 
		case TQuotation(t,a):
			return '<blockquote class="md"><q>${horizontal(t)}</q><span>${horizontal(a)}</span></blockquote>';
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
		case TParagraph(h):
			return '<p>${horizontal(h)}</p>\n';
		case TVList(li):
			var buf = new StringBuf();
			for (i in li)
				buf.add(vertical(i, counts));
			return buf.toString();
		}
	}

	function document(doc:Document)
	{
		var buf = new StringBuf();
		buf.add('<meta charset="utf-8">
		<title></title>
		<!-- Google Fonts -->
		<link href="https://fonts.googleapis.com/css?family=PT+Serif:400,400italic,700italic,700|PT+Sans:400,400italic,700,700italic" rel="stylesheet" type="text/css">
		<!-- Normalize -->
		<link href="https://cdnjs.cloudflare.com/ajax/libs/normalize/4.0.0/normalize.min.css" rel="stylesheet" type="text/css">
		<!-- CSS -->
		<link href="../../generator/docs/design/web/mockup/style.css" rel="stylesheet" type="text/css">
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
}

