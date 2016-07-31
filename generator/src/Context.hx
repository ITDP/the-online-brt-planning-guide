class Context {
	public static var debug = false;

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
}

