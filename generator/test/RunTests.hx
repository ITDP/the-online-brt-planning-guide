class RunTests {
	static function main()
	{
		var r = new utest.Runner();
		r.addCase(new Test_01_Tools());
		r.addCase(new Test_02_Lexer());
		r.addCase(new Test_03_Parser());
		r.addCase(new Test_04_Transform());
		r.addCase(new NeedlemanWunschTests());

		utest.ui.Report.create(r);
		r.run();
	}
}

