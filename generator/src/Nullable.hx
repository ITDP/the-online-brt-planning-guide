import Assertion.*;
import haxe.ds.Option;

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
		assert(this != null);
		return this;
	}

	public inline function or(alt:T):T
		return notNull() ? this : alt;

	public inline function safe():NullableResolver<T>
		return this;

	public inline function cases():Option<T>
		return notNull() ? Some(this) : None;

	function new(value) this = value;
}

private abstract NullableResolver<T>(Nullable<T>) from Nullable<T> {
	@:op(a.b) static macro function resolve(ethis:haxe.macro.Expr, name:String)
	{
		return macro @:privateAccess new Nullable($ethis.parent().sure().$name);
	}

	// hack to access Nullable<T> methods
	inline function parent():Nullable<T> return this;
}

