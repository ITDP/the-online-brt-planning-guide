package transform;

class ValidationError extends GenericError {
	public var fatal(default,null):Bool;

	override function get_text()
		return "Unknown validation error";

	public function new(fatal, pos)
	{
		this.fatal = fatal;
		super(pos);
	}
}

class BadMath extends ValidationError {
	public var math(default,null):String;
	public var details(default,null):Dynamic;

	override function get_text()
		return 'Bad math: $$$$$math$$$$';

	public function new(math, details, pos)
	{
		this.math = math;
		this.details = details;
		super(true, pos);
	}
}

private class SrcFileError extends ValidationError {
	public var path(default,null):String;
	public function new(path, pos)
	{
		this.path = path;
		super(true, pos);
	}
}

class FileNotFound extends SrcFileError {
	override function get_text()
		return "File not found or not accessible (tip: paths are relative and case sensitive)";
}

class FileIsDirectory extends SrcFileError {
	override function get_text()
		return "Expected file, not directory";
}

class WrongFileType extends SrcFileError {
	public var expected(default,null):Array<transform.Validator.FileType>;

	override function get_text()
		return 'File does not match expected types ($expected)';

	public function new(expected, path, pos)
	{
		this.expected = expected;
		super(path, pos);
	}
}

