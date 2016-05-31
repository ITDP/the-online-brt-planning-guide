import haxe.io.Bytes;
import parser.AstTools.*;
import parser.Lexer;
import parser.Parser;
import transform.Document;
import transform.Transform;
import utest.Assert;

class Test_04_Transform {
	static inline var SRC = "Test_04_Transform.hx";

	public function new() {}
	
	function transform(str : String)
	{
		var l = new Lexer(Bytes.ofString(str), SRC);
		var p = new Parser(l).file();
		return Transform.transform(p);
	}
	
	public function test_001_example()
	{
		Assert.same({def : TVList([
			{ def : TVolume( 
				{
					def : Word("a"),
					pos : {min : 8, max : 9, src : SRC}
				}, 
				1,
				{
					def : TVList([
						{
							def : TParagraph(
								{
									def : Word("b"),
									pos : {min : 10, max : 11, src : SRC}
								}),
							pos : {min : 10, max : 11, src : SRC}
						}]),
					pos : {min : 10, max : 11, src : SRC}
				})
				,
			  pos : {min : 0, max : 11, src : SRC}
			},
			{ def : TVolume( 
				{
					def : Word("c"),
					pos : {min : 19, max : 20, src : SRC}
				}, 
				2,
				{
					def : TVList([
						{
							def : TParagraph(
								{
									def : Word("d"),
									pos : {min : 21, max : 22, src : SRC}
								}),
							pos : {min : 21, max : 22, src : SRC}
						}]),
					pos : {min : 21, max : 22, src : SRC}
				})
				,
			  pos : {min : 11, max : 22, src : SRC}
			}
		]),
			pos : {min : 0, max : 22, src : SRC}
		}, transform("\\volume{a}b\\volume{c}d"));
	}

	public function test_002_hierarchy_content_binding()
	{
		// FIXME no lists with length == 1
		Assert.same(
			expand(TVList([
				@wrap(8,0)TVolume(@len(1)Word("a"), 0, @skip(1)TVList([TParagraph(@len(1)Word("b"))]))])),
			transform("\\volume{a}b"));

		Assert.same(
			expand(TVList([
				@wrap(8,0)TVolume(@len(1)Word("a"), 0, @skip(1)TVList([TParagraph(@len(1)Word("b"))])),
				@wrap(8,0)TVolume(@len(1)Word("c"), 0, @skip(1)TVList([TParagraph(@len(1)Word("d"))]))])),
			transform("\\volume{a}b\\volume{c}d"));
	}
}
