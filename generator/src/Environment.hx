class Environment {
	static var env = Sys.environment();
	static function enabled(name) {
		var val = env[name];
		return val != null && !~/^[ ]*(0|false)[ ]*$/i.match(val);
	}

	public static var debug = enabled("DEBUG");
	public static var draft = enabled("DRAFT");
	public static var googleAnalyticsId = env["GL_ANALYTICS_UA_ID"];
	public static var assetUrlPrefix = env["ASSET_URL_PREFIX"];
	public static var assetServer = env["ASSET_SERVER"];
}

