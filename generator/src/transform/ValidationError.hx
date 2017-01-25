package transform;

import transform.NewDocument;

enum ValidationErrorValue {
	BadMath(math:String, errors:Array<String>);
	AbsoluteOutputPath(path:String);  // best to pass the original path
	EscapingOutputPath(path:String);  // best to pass the original path
	FileNotFound(path:String);  // best to pass the computed path
	FileIsDirectory(path:String);  // best to pass the computed path
	WrongFileType(expected:Array<transform.Validator.FileType>, path:String);  // best to pass the computed path
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
		case BadMath(_, errors):
			return 'Bad math: ${errors.join("; ")}';
		case AbsoluteOutputPath(_):
			return 'Output path cannot be absolute';
		case EscapingOutputPath(_):
			return 'Output path cannot escape the destination directory';
		case FileNotFound(_):
			return 'File not found or not accessible (tip: paths are relative and case sensitive)';
		case FileIsDirectory(_):
			return 'Expected file, not directory';
		case WrongFileType(expected, _):
			var valid = expected.map(function (i) {
				var exts = i.validExtensions();
				return exts.length > 0 ? '$i [.${exts.join(",.")}]' : i;
			});
			return 'File does not match expected types (expected: ${valid.join(", ")})';
		case BlankValue(parent, name):
			return '${capitalize(parent)} $name cannot be blank';
		}
	}
}

