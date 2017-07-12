package html.script;

import haxe.io.Path;
import html.script.Const;
import js.jquery.*;

import Assertion.*;
import js.Browser.*;
import js.jquery.Helper.*;

using StringTools;

class Main {
	static function getToc()
	{
		var req = new haxe.Http("table-of-contents");
		req.onData =
			function (tocData:String)
			{
				JTHIS.ready(function (_) drawNavNextPrev(tocData));
			}
		req.onStatus = function (status) weakAssert(status == 200, status);
		req.onError = function (msg) assert(false, msg);
		req.request();
	}

	static function drawNavNextPrev(tocData:String)
	{
		// parse and locate myselft
		assert(tocData != null, "toc data is missing");
		var toc = J(JQuery.parseHTML(tocData)).find("div#toc>ul");
		var myUrl =  J("link[rel=canonical]").attr("href");
		assert(myUrl != null);
		var me = toc.find('a[href="$myUrl"]').not("#toc-menu").parent();
		assert(me.length > 0, myUrl);
		assert(me.is("li"));

        //nav buttons content 
        var prevContent:Null<js.html.Element> = null;
        var nextContent:Null<js.html.Element>  = null;
	
        if (!me.is("nav")) {
            var prev = me.prev("li");
            if (!prev.is("li")) {
                prev = me.parents("li");
            } else if (prev.find("li.chapter, li.section").last().is("li")) {
                prev = prev.find("li.chapter, li.section").last();
            }
            if (prev.is("li")) prevContent = prev.clone().find("a")[0];

            var next = me.find("li.chapter, li.section");
            if (!next.is("li")) next = me.next("li");
            if (!next.is("li")) next = me.parents("li").next();
            if (next.is("li")) nextContent = next.clone().find("a")[0];
        }


		// if we're the ToC, just remove the placeholder
		if (me.hasClass("toc-link")) {
			J("#toc-loading").remove();
			return;
		}

		// fix fragments
		toc.find('a[href^="#"]').attr("href", function (_, u) return myUrl + u);

		// remove distant ancestors and (if necessary) draw the overview toc
		if (me.hasClass("index")) {
			toc.find("li.section").remove();
		} else if (me.hasClass("volume")) {
			toc.find("li.chapter").not(me.find("li.chapter")).remove();
			drawOverview(me.clone());
		} else if (me.hasClass("chapter")) {
			toc.find("li.chapter").not(me).not(me.siblings("li.chapter")).remove();
			toc.find("li.section").not(me.find("li.section")).remove();
			drawOverview(me.clone());
		} else if (me.hasClass("section")) {
			toc.find("li.chapter").not(me.parents("li.volume").find("li.chapter")).remove();
			toc.find("li.section").not(me).not(me.siblings("li.section")).remove();
			me.siblings("li.section").find("li").not(me.find("li")).remove();
		} else {
			assert(false, "missing any of the expected classes", me);
		}

		// remove grandchildren from the nav toc
		me.children("ul").find("ul").remove();
		assert(toc.find('a[href="$myUrl"]').parent().children("ul").find("ul").length == 0);

		// remove prefix from chapters
		toc.find("li.chapter>a").text(function (_, name) return ~/^Chapter /.replace(name, ""));

		// draw the nav toc
		J("#toc-loading").remove();
		J("nav").append(toc);
		me.addClass("active");
		
        drawBottomButtons(prevContent,nextContent);
	}

	static function drawOverview(internals:JQuery)
	{
		var oview = J(JQuery.parseHTML('<div id="toc" class="toccompact"><ul></ul></div>'));
		oview.children("ul").append(internals);
		J("div.col-text").append(oview);
	}

	static function drawBottomButtons(prevContent:Null<js.html.Element>, nextContent:Null<js.html.Element>)
	{
        var navDiv = J(JQuery.parseHTML('<div class="navigation"></div>'));
        if (prevContent  != null) {
            var prev = J(JQuery.parseHTML('<div class="prev"></div>'));
            prev.append(prevContent);
            navDiv.append(prev);
        }
        if (nextContent != null) {
            var next = J(JQuery.parseHTML('<div class="next"></div>'));
            next.append(nextContent);
            navDiv.append(next);
        }
		J("div.col-text").append(navDiv);
	}

	static function figClick(e:Event)
	{
		var b = J("body");
		var t = J(e.target);
		if (!t.is("img.overlay-trigger"))
			return;

		var olay = J(JQuery.parseHTML('<div class="overlay"><div style="background-image: url(${t.attr("src")});"></div></div>'));
		olay.click(function (e:Event) {
			olay.off(e);
			olay.remove();
			b.children().removeClass("blur");
		});
		b.children().addClass("blur");
		b.append(olay);
		e.preventDefault();
		e.stopPropagation();
	}

	static function shareClick(e:Event)
	{
		var t = J(e.target).parents(".share");
		if (t.length == 0 || ((untyped document.getSelection().toString()):String) != "")
			return;

		var id = ( t.is("figcaption") ? t.parent("figure") : t ).attr("id");
		window.location.hash = id;

		e.preventDefault();
		e.stopPropagation();
	}

	static function main()
	{
		getToc();
		JTHIS.click(figClick);
		JTHIS.click(shareClick);
	}
}

