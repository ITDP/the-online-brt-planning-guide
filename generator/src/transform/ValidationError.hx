package transform;

import transform.NewDocument;

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

private class PathError extends ValidationError {
	public var path(default,null):String;

	public function new(path, pos)
	{
		this.path = path;
		super(true, pos);
	}
}

class AbsolutePath extends PathError {
	override function get_text()
		return "path cannot be absolute";
}

class EscapingPath extends PathError {
	public var dir(default,null):String;

	override function get_text()
		return 'path cannot escape $dir';

	public function new(dir, path, pos)
	{
		this.dir = dir;
		super(path, pos);
	}
}

class FileNotFound extends PathError {
	override function get_text()
		return "File not found or not accessible (tip: paths are relative and case sensitive)";
}

class FileIsDirectory extends PathError {
	override function get_text()
		return "Expected file, not directory";
}

class WrongFileType extends PathError {
	public var expected(default,null):Array<transform.Validator.FileType>;

	override function get_text()
		return 'File does not match expected types ($expected)';

	public function new(expected, path, pos)
	{
		this.expected = expected;
		super(path, pos);
	}
}

private class ValueError extends ValidationError {
}

class BlankValue extends ValueError {
	public var parent(default,null):DElem;
	public var name(default,null):String;

	function elemDesc(d:DElem)
	{
		return switch d.def {
		case DVolume(_): "volume";
		case DChapter(_): "chapter";
		case DSection(_): "section";
		case DSubSection(_): "sub-section";
		case DSubSubSection(_): "sub-sub-section";
		case DBox(_): "box";
		case DList(_): "list";
		case DTable(_), DImgTable(_): "table";
		case DFigure(_): "figure";
		case DQuotation(_): "quotation";
		case DParagraph(_): "paragraph";
		case DCodeBlock(_): "code block";
		case DEmpty: "[nothing]";
		case DElemList(_): "[list of elements]";
		case DLaTeXPreamble(_): "LaTeX preamble configuration";
		case DLaTeXExport(_): "LaTeX export call";
		case DHtmlApply(_): "CSS inclusion";
		}
	}

	override function get_text()
		return '${elemDesc(parent)} $name cannot be blank';

	public function new(parent, name, pos)
	{
		this.parent = parent;
		this.name = name;
		super(true, pos);
	}
}

