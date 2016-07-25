/**
	Adapted Needleman-Wunsch algorithm for general array alignment
	If NeedlemanWunsch is used as entry point the unit tests are executed

	Copyright (c) 2013, Jonas Malaco Filho
	All rights reserved.

	Redistribution and use in source and binary forms, with or without
	modification, are permitted provided that the following conditions are met:
	- Redistributions of source code must retain the above copyright notice,
	  this list of conditions and the following disclaimer.
	- Redistributions in binary form must reproduce the above copyright notice,
	  this list of conditions and the following disclaimer in the documentation
	  and/or other materials provided with the distribution.

	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
	AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
	IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
	ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
	LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
	CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
	SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
	INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
	CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
	POSSIBILITY OF SUCH DAMAGE.

	This is a BSD 2-clause license. Information available at:
	http://opensource.org/licenses/BSD-2-Clause.
**/

class NeedlemanWunsch<T> {
	
	public var alignedA( default, null ): Array<Null<T>>;
	public var alignedB( default, null ): Array<Null<T>>;
	public var distance( default, null ): Float;
	public var length( default, null ): Int;

	/**
		Global alignment of two arrays, using a modified version of the quadratic running time
		Needleman-Wunsch algorithm with gap penalties
		Params:
			dist( a, b ) should give the (edit) distance between a and b
			skip( a, b, c ) should give (an estimate of) the penalty incured when skipping b
				a (nullable) is the previous element
				c (nullable) is the next element
		Return:
			A Alignment<T> object, with both a and b aligned arrays and the (edit) distance computed
	**/
	public static function globalAlignment<T>( a: Array<T>, b: Array<T>, dist: T -> T -> Float,
	                            ?skip: Null<T> -> T -> Null<T> -> Float): NeedlemanWunsch<T> {
		// array lengths
		var n = a.length;
		var m = b.length;

		// F (?) matrix initialization, size( F ) = n+1, m+1
		// *** the corresponding a and b elements for Fij are a[i - 1] and b[i - 1] ***
		var F = buildMatrix( n + 1, m + 1, function ( i, j ) return Math.POSITIVE_INFINITY );
		
		// pre-computed distance matrix, size( D ) = n+1, m+1
		var D = buildMatrix( n + 1, m + 1, function ( i, j ) return i*j != 0 ? dist( a[i - 1], b[j - 1] ) : Math.NaN );

		// default gap penalty function is cte 1. (as in Levenshtein distance)
		if ( skip == null )
			skip = function ( a, b, c ) return 1.;

		// basis
		F[0][0] = 0.;
		for ( i in 1...n+1 )
			F[i][0] = F[i - 1][0] + skip( ( i > 1 ? a[i - 2] : null ), a[i - 1], ( i < n ? a[i] : null ) );
		for ( j in 1...m+1 )
			F[0][j] = F[0][j - 1] + skip( ( j > 1 ? b[j - 2] : null ), b[j - 1], ( j < m ? b[j] : null ) );

		// recursion
		// for i,j <=> a[i - 1],b[j - 1] there are 3 possible outcomes:
		//     move down and left, a[i - 1] aligns with b[j - 1], AKA "match"
		//     move down, a[i - 1] aligns with a gap in b, AKA "skipA" (one element of a is discarted), AKA "delete"
		//     move left, b[j - 1] aligns with a gap in a, AKA "skipB" (one element of b is discarted), AKA "insert"
		for ( i in 1...n+1 )
			for ( j in 1...m+1 ) {
					var match = F[i - 1][j - 1] + D[i][j];
					var skipA = F[i - 1][j] + skip( ( i > 1 ? a[i - 2] : null ), a[i - 1], ( i < n ? a[i] : null ) );
					var skipB = F[i][j - 1] + skip( ( j > 1 ? b[j - 2] : null ), b[j - 1], ( j < m ? b[j] : null ) );
					F[i][j] = Math.min( match, Math.min( skipA, skipB ) );
				}

		// trace( F.join( '\n' ) );

		if ( !Math.isFinite( F[n][m] ) )
			throw 'Supplied distance or skip penalty functions resulted in infeasible alignment';

		// alignment
		var aligA = new List();
		var aligB = new List();
		var i = n;
		var j = m;
		while ( i > 0 && j > 0 ) {
			if ( Math.isFinite( F[i - 1][j - 1] ) && F[i][j] == F[i - 1][j - 1] + D[i][j] ) {
				// results from match
				aligA.push( a[--i] );
				aligB.push( b[--j] );
			}
			else if ( Math.isFinite( F[i - 1][j] )
			  && F[i][j] == F[i - 1][j] + skip( ( i > 1 ? a[i - 2] : null ), a[i - 1], ( i < n ? a[i] : null ) ) ) {
				// results from skipA
				aligA.push( a[--i] );
				aligB.push( null );
			}
			else if ( Math.isFinite( F[i][j - 1] )
			  && F[i][j] == F[i][j - 1] + skip( ( j > 1 ? b[j - 2] : null ), b[j - 1], ( j < m ? b[j] : null ) ) ) {
				// results from skipB
				aligA.push( null );
				aligB.push( b[--j] );
			}
			else
				throw 'Internal error in alignment reconstruction; F=\n' + F.join( '\n' );
		}
		while ( i > 0 || j > 0 ) {
			aligA.push( i > 0 ? a[--i] : null );
			aligB.push( j > 0 ? b[--j] : null );
		}

		return new NeedlemanWunsch( Lambda.array( aligA ), Lambda.array( aligB ), F[n][m] );
	}

	static function buildMatrix<A>( n: Int, m: Int, init: Int -> Int -> A ) {
		var M = [];
		for ( i in 0...n ) {
			var _i = n - 1 - i;
			M[_i] = [];
			for ( j in 0...m ) {
				var _j = m - 1 - j;
				M[_i][_j] = init( _i, _j );
			}
		}
		return M;
	}
	
	function new( a: Array<Null<T>>, b: Array<Null<T>>, dist: Float ) {
		if ( a.length != b.length )
			throw 'a.length != b.length'; 
		alignedA = a;
		alignedB = b;
		length = alignedA.length;
		distance = dist;
	}
}

