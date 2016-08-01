import utest.Assert.equals in assertEquals;
import utest.Assert.raises in assertRaises;

class NeedlemanWunschTests {

	// Tests

	// Test alignment using Levenshtein distance penalties
	function testLevenshteinDistance() {
		var dist = function ( a, b ) return a==b ? 0 : 1;
		var skip = function ( a, b, c ) return 1;

		assertEquals( '3|kitten_|sitting', stAl( 'kitten', 'sitting', dist, skip ) );
		assertEquals( '6|industry|interest', stAl( 'industry', 'interest', dist, skip ) );
		assertEquals( '3|horse|ror__', stAl( 'horse', 'ror', dist, skip ) );

		assertEquals( '1|start|_tart', stAl( 'start', 'tart', dist, skip ) );
		assertEquals( '1|finish|finis_', stAl( 'finish', 'finis', dist, skip ) );
		assertEquals( '1|skipped|ski_ped', stAl( 'skipped', 'skiped', dist, skip ) );
	}

	// Test different skip functions, specially one that does not allow
	// gaps in the beginning or end
	function testSkipFunction() {
		var dist = function ( a, b ) return a==b ? 0 : 1;
		var skip = function ( ?a, b, ?c ) {
			if ( a == null )
				return Math.POSITIVE_INFINITY;
			else if ( c == null )
				return Math.POSITIVE_INFINITY;
			else if ( b == a || b == c )
				return 0.;
			else
				return 1.;
		};

		assertEquals( '2|start|t_art', stAl( 'start', 'tart', dist, skip ) );
		assertEquals( '2|finish|fini_s', stAl( 'finish', 'finis', dist, skip ) );
		assertEquals( '0|skipped|ski_ped', stAl( 'skipped', 'skiped', dist, skip ) );

		// expect exception if b is only one char long and a has more than one char
		assertRaises( stAl.bind( 'ar', 'b', dist, skip ) );
		assertEquals( '1|a|b', stAl( 'a', 'b', dist, skip ) );
	}

	// Helpers

	// Global alignment of strings
	static function stAl( a: String, b: String, dist: Int -> Int -> Float, skip: Int -> Int -> Int -> Float ): String {
		var _a = stAr( a );
		var _b = stAr( b );
		var nwa = NeedlemanWunsch.globalAlignment( _a, _b, dist, skip );
		return stRes( nwa );
	}

	// String to Array<Int>
	static function stAr( s: String ): Array<Int> {
		var bytes = haxe.io.Bytes.ofString( s );
		var a = [];
		for ( i in 0...bytes.length ) {
			a.push( bytes.get( i ) );
		}
		return a;
	}

	// Array<Int> to String
	static function arSt( a: Array<Null<Int>>, ?nullValue = '_' ): String {
		var bytes = haxe.io.Bytes.alloc( a.length );
		var nl = nullValue.charCodeAt( 0 );
		for ( i in 0...a.length )
			bytes.set( i, a[i] == null ? nl : a[i] );
		return bytes.toString();
	}

	// Alignment results printer
	static function stRes( x: NeedlemanWunsch<Int>, ?sep='|', ?nl='_'  ): String {
		return '${x.distance}$sep${arSt( x.alignedA, nl )}$sep${arSt( x.alignedB, nl )}';
	}

	public function new() {}
}

