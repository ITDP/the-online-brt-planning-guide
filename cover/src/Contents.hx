typedef Contents = Array<Volume>;

typedef Volume = {
	> Element,
	chapters:Array<Chapter>
}

typedef Chapter = {
	> Element,
}

typedef Element = {
	name:String,
	url:String
}

