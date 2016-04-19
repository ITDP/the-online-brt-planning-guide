
class RunAll {
	static function main()
	{
		var r = new utest.Runner();
		r.addCase(new LexerTests());
		r.addCase(new ParserTests());

		utest.ui.Report.create(r);
		r.run();
	}
}

