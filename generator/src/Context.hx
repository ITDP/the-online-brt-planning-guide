import PositionTools;

class Context {
	public static var debug = false;
	public static var draft = false;
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

