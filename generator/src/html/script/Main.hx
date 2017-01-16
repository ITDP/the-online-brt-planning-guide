package html.script;

import html.script.Const;
import js.jquery.*;

import Assertion.*;
import js.Browser.*;
import js.jquery.Helper.*;

using StringTools;

class Main {
	static var tocData(get,never):String;
		static function get_tocData() return Reflect.field(js.Lib.global, TocData);

	static function drawNav(e:Event)
	{
		// parse and locate myselft
		assert(tocData != null, "toc data is missing");
		var toc = J(JQuery.parseHTML(tocData));
		assert(document.URL.startsWith(document.baseURI));
		var myUrl = document.URL.replace(document.baseURI, "").replace(window.location.hash, "");
		if (myUrl == "")
			myUrl = "index.html";
		var me = toc.find('a[href="$myUrl"]').not("#toc-menu").parent();
		assert(me.length > 0, myUrl);
		assert(me.is("li"));
		assert(me.hasClass("volume") || me.hasClass("chapter") || me.hasClass("section"), "classes used in selectors");

		// remove grandchildren
		me.children("ul").find("ul").remove();
		assert(toc.find('a[href="$myUrl"]').parent().children("ul").find("ul").length == 0);

		// remove distant ancestors
		if (me.hasClass("volume")) {
			toc.find("li.chapter").not(me.find("li.chapter")).remove();
		} else if (me.hasClass("chapter")) {
			toc.find("li.chapter").not(me).not(me.siblings("li.chapter")).remove();
			toc.find("li.section").not(me.find("li.section")).remove();
		} else if (me.hasClass("section")) {
			toc.find("li.chapter").not(me.parents("li.volume").find("li.chapter")).remove();
			toc.find("li.section").not(me).not(me.siblings("li.section")).remove();
			me.siblings("li.section").find("li").not(me.find("li")).not("keep").remove();
		}

		// fix fragments
		toc.find('a[href^="#"]').attr("href", function (_, u) return myUrl + u);

		// set-up the responsive behaviour
		J("#toc-menu").click(function (e) {
			J("nav ul").css("display", function (_, cur) return cur == "none" ? "block" : "");
			e.preventDefault();
		});

		J("#toc-loading").remove();
		J("#toc-menu").removeClass("disabled");
		J("nav").append(toc);
	}

	static function figClick(e:Event)
	{
		var t  = J(e.target);
		if (!t.is("img.overlay-trigger"))
			return;

		var olay = J(JQuery.parseHTML('<div class="overlay"><div style="background-image: url(${t.attr("src")});"></div></div>'));
		olay.click(function (e:Event) {
			olay.off(e);
			olay.remove();
		});
		t.after(olay);
		e.preventDefault();
		e.stopPropagation();
	}

	static function main()
	{
		JTHIS.ready(drawNav);
		JTHIS.click(figClick);
	}
}

