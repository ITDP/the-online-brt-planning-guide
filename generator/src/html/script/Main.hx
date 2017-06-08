package html.script;

import haxe.io.Path;
import html.script.Const;
import js.jquery.*;

import Assertion.*;
import js.Browser.*;
import js.jquery.Helper.*;

using StringTools;

class Main {

	static function getToc(e:Event)
	{
		var req = new haxe.Http("table-of-contents");
		req.onData =
			function (tocData:String)
			{
				JTHIS.ready(function (_) drawNav(tocData));
			}
		req.onStatus = function (status) weakAssert(status == 200, status);
		req.onError = function (msg) assert(false, msg);
		req.request();
	}

	static function drawNav(tocData:String)
	{
		// parse and locate myselft
		assert(tocData != null, "toc data is missing");
		var toc = J(JQuery.parseHTML(tocData)).find("li.index").closest("ul");
		var myUrl = J("base").attr("x-rel-path");
		assert(myUrl != null);
		var me = toc.find('a[href="$myUrl"]').not("#toc-menu").parent();
		assert(me.length > 0, myUrl);
		assert(me.is("li"));

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

		// draw the nav toc
		J("#toc-loading").remove();
		J("nav").append(toc);
	}

	static function drawOverview(internals:JQuery)
	{
		// TODO customize the internals

		var oview = J(JQuery.parseHTML("<ul></ul>"));
		oview.append(internals);
		J("div.col-text").append(oview);
	}

	static function figClick(e:Event)
	{
		var b = J("body");
		var t  = J(e.target);
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

	static function main()
	{
		JTHIS.ready(getToc);
		JTHIS.click(figClick);
	}
}

