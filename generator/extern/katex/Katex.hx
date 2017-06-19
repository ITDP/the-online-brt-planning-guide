package katex;

typedef Options = {
	?displayMode:Bool,  // default: false
	?throwOnError:Bool,  // default:true
	?errorColor:String  // default: #cc0000
}

#if nodejs
@:jsRequire("katex")
#elseif !js
#error "Katex requires a JS runtime.  For Node.js, you also need `-lib hxnodejs`."
#end
extern class Katex {
	public static function renderToString(tex:String, ?opts:Options):String;
}

