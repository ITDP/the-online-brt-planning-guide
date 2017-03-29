import Assertion.*;
import haxe.ds.Option;
import haxe.macro.Expr;

/**
Safe nullable values.

Inspired on:
 - Dan's Maybe<T> from the Cookbook
 - Kotlin's null safety
**/
abstract Nullable<T>(Null<T>) from Null<T> {
	public inline function isNull():Bool
		return this == null;

	public inline function notNull():Bool
		return this != null;

	public inline function sure():T
	{
#if macro
		if (this == null) throw "Assertion failed: calling sure() on null";
#else
		assert(this != null);
#end
		return this;
	}

	public inline function or(alt:T):T
		return notNull() ? this : alt;

	public inline function safe():NullableResolver<T>
		return this;

	public function cases():Option<T>
		return notNull() ? Some(this) : None;

	public macro function extractOr(ethis:Expr, alt:Expr):ExprOf<T>
		return macro @:pos(ethis.pos) {
			var __ethis__ = $ethis;  // FIXME
			__ethis__.notNull() ? @:privateAccess __ethis__.raw() : @:pos(alt.pos) $alt;
		};

	inline function raw():T
		return this;

	inline function new(value)
		this = value;
}

private abstract NullableResolver<T>(Nullable<T>) from Nullable<T> {
	@:op(a.b) static macro function resolve(ethis:haxe.macro.Expr, name:String)
	{
		return macro @:pos(ethis.pos) @:privateAccess new Nullable($ethis.parent().sure().$name);
	}

	// hack to access Nullable<T> methods
	inline function parent():Nullable<T> return this;
}

