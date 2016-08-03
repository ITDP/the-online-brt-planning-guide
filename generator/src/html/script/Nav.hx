package html.script;

import js.jquery.*;

import Assertion.*;
import js.Browser.*;
import js.jquery.Helper.*;

using StringTools;

class Nav {
	static var data(get,never):String;
		static function get_data() return js.Lib.global.__navBundle__;

	static function drawNav(e:Event)
	{
		// parse and locate myselft
		assert(data != null, "no data bundled");
		var nav = J(JQuery.parseHTML(data));
		assert(document.URL.startsWith(document.baseURI));
		var myUrl = document.URL.replace(document.baseURI, "").replace(window.location.hash, "");
		var me = nav.find('a[href="$myUrl"]').parent();
		assert(me.length > 0, myUrl);
		assert(me.is("li"));
		assert(me.hasClass("volume") || me.hasClass("chapter") || me.hasClass("section"), "classes used in selectors");

		// remove grandchildren
		me.children("ul").find("ul").remove();
		assert(nav.find('a[href="$myUrl"]').parent().children("ul").find("ul").length == 0);

		// remove distant ancestors
		if (me.hasClass("volume")) {
			nav.find("li.chapter").not(me.find("li.chapter")).remove();
		} else if (me.hasClass("chapter")) {
			nav.find("li.chapter").not(me).not(me.siblings("li.chapter")).remove();
			nav.find("li.section").not(me.find("li.section")).remove();
		} else if (me.hasClass("section")) {
			nav.find("li.chapter").not(me.parents("li.chapter")).remove();
			nav.find("li.section").not(me).not(me.siblings("li.section")).remove();
			me.siblings("li.section").find("li").not(me.find("li")).not("keep").remove();
		}

		// fix download
		nav.find('a[href^="#"]').attr("href", function (_, u) return myUrl + u);

		// insert
		JTHIS.find("div.container").append(nav);
	}

	static function main()
	{
		JTHIS.ready(drawNav);
	}
}

