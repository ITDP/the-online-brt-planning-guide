package transform;

import transform.NewDocument;

enum ValidationErrorValue {
	BadMath(math:String);
	AbsolutePath(path:String);
	EscapingPath(dir:String, path:String);
	FileNotFound(path:String);
	FileIsDirectory(path:String);
	WrongFileType(expected:Array<transform.Validator.FileType>, path:String);
	BlankValue(parent:String, name:String);
}

class ValidationError extends GenericError {
	public var err(default,null):ValidationErrorValue;

	public var fatal(get,never):Bool;
		function get_fatal()
			return true;

	public function new(pos, err)
	{
		super(pos);
		this.err = err;
	}

	function capitalize(s:String)
		return s.charAt(0).toUpperCase() + s.substr(1);

	override public function toString()
	{
		switch err {
		case BadMath(math):
			return 'Bad math: $$$$$math$$$$';
		case AbsolutePath(path):
			return 'Path cannot be absolute';
		case EscapingPath(dir, path):
			return 'Path cannot escape $dir';
		case FileNotFound(path):
			return 'File not found or not accessible (tip: paths are relative and case sensitive)';
		case FileIsDirectory(path):
			return 'Expected file, not directory';
		case WrongFileType(expected, path):
			return 'File does not match expected types (expected: ${expected.join(",")})';
		case BlankValue(parent, name):
			return '${capitalize(parent)} $name cannot be blank';
		}
	}
}

