/*
A quick and dirty writer of ANSI escape codes.

Based on work by Miha Lunar <https://github.com/SmilyOrg/ansi> licensed under
the MIT license:

> The MIT License (MIT) Copyright (c) 2016 Miha Lunar
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of
> this software and associated documentation files (the "Software"), to deal in
> the Software without restriction, including without limitation the rights to
> use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
> of the Software, and to permit persons to whom the Software is furnished to do
> so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all
> copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.
*/

package;

@:enum abstract Attribute(Int) {
	var Off = 0;
	
	var Bold = 1;
	var Underline = 4;
	var Blink = 5;
	var ReverseVideo = 7;
	var Concealed = 8;
	
	var BoldOff = 22;
	var UnderlineOff = 24;
	var BlinkOff = 25;
	var NormalVideo = 27;
	var ConcealedOff = 28;
	
	var Black = 30;
	var Red = 31;
	var Green = 32;
	var Yellow = 33;
	var Blue = 34;
	var Magenta = 35;
	var Cyan = 36;
	var White = 37;
	var DefaultForeground = 39;
	
	var BlackBack = 40;
	var RedBack = 41;
	var GreenBack = 42;
	var YellowBack = 43;
	var BlueBack = 44;
	var MagentaBack = 45;
	var CyanBack =46;
	var WhiteBack = 47;
	var DefaultBackground = 48;
}

class Ansi {
	public inline static var ESCAPE:String = "\x1B";

	public static var available(default,null) = {
		#if (sys || nodejs)
		if (Sys.systemName().toLowerCase().indexOf("window") == -1) {
			var result = -1;
			try {
				#if nodejs
				result = js.node.ChildProcess.spawnSync("tput", ["colors"]).error == null ? 0 : 125;
				#else
				var process = new sys.io.Process("tput", ["colors"]);
				result = process.exitCode ();
				process.close();
				#end
			} catch (e:Dynamic) {};
			result == 0;
		} else {
			Sys.getEnv ("ANSICON") != null;
		}
		#else
		false;
		#end
	}

	public static var set(default,null) =
		if (available)
			function (attr:Attribute) return '${ESCAPE}[${attr}m';
		else
			function (attr) return "";

	public static var setm(default,null) =
		if (available)
			function (attrs:Array<Attribute>) return '${ESCAPE}[${attrs.join(";")}m';
		else
			function (attrs) return "";
}

