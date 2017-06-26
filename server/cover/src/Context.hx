import haxe.io.Path;
import sys.FileSystem in Fs;
import sys.io.File;

class Context {
	public var dataDir(default,null):String;

	public function new(dataDir)
	{
		this.dataDir = dataDir;
	}

	public function getVolumeSummary(url)
		return getContent(url, "summary");

	inline function getContent(url, key)
	{
		var path = Path.join([dataDir, url, key]);
		assert(Fs.exists(path) && !Fs.isDirectory(path), path, "missing data");
		return File.getContent(path);
	}
}

