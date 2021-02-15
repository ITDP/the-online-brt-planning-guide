import PositionTools;

class Context {
	static var env = Sys.environment();
	static function enabled(name) {
		var val = env[name];
		return val != null && !~/^[ ]*(0|false)[ ]*$/i.match(val);
	}

	public static var googleAnalyticsId = env["GL_ANALYTICS_UA_ID"];
	public static var assetUrlPrefix = env["ASSET_URL_PREFIX"];
	public static var assetServer = env["ASSET_SERVER"];
	public static var tag = env["TAG"];

	//public static var gh_user = env["GH_USER"];
	public static var pullRequest = env["PULL_REQUEST"];
	public static var branch = env["BASE_BRANCH"];
	public static var gh_user = env["GH_USER"];


	public static var debug = enabled("DEBUG");
	public static var draft = enabled("DRAFT");
	@:isVar public static var noMathValidation(get,set) = enabled("DRAFT_NO_MATH_VALIDATION");
		static function get_noMathValidation() return draft || noMathValidation;
		static function set_noMathValidation(flag) return noMathValidation = flag;
	public static var texNoPositions = enabled("TEX_NO_POSITIONS");

	public static var timer = new Map<String,Float>();
	public static var timerOrder = [];
	public static var hlmode = AsciiUnderscore();

	public static function prepareSourceMaps()
	{
#if (debug && hxnodejs)
		try {
			var sms = js.Lib.require("source-map-support");
			sms.install();
			haxe.CallStack.wrapCallSite = sms.wrapCallSite;
		} catch (e:Dynamic) {
			if (debug) trace("WARNING: could not prepare source map support:", e);
		}
#else
		// NOOP
#end
	}

	public static function time<R>(key:String, work:Void->R)
	{
		var start = Sys.time();
		var res = work();
		var finish = Sys.time();
		if (!timer.exists(key)) {
			timer[key] = 0.;
			timerOrder.push(key);
		}
		timer[key] += finish - start;
		return res;
	}

	public static function manualTime(key:String, seconds:Float)
	{
		if (!timer.exists(key)) {
			timer[key] = 0.;
			timerOrder.push(key);
		}
		timer[key] += seconds;
	}
}

