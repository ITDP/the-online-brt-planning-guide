package html.script;

import js.jquery.*;

import Assertion.*;
import js.Browser.*;
import js.jquery.Helper.*;

class Nav {
	static function drawNav(e:Event)
	{
		show("hi");
	}

	static function main()
	{
		JTHIS.ready(drawNav);
	}
}

