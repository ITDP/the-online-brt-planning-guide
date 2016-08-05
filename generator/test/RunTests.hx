class RunTests {
	static function main()
	{
		Context.debug = true;
		Context.prepareSourceMaps();

		var r = new utest.Runner();
		r.addCase(new Test_01_Tools());
		r.addCase(new Test_02_Lexer());
		r.addCase(new Test_03_Parser());
		r.addCase(new Test_04_Transform());
		r.addCase(new Test_05_Transform());
		r.addCase(new NeedlemanWunschTests());
		r.addCase(new Test_09_Issues());

		utest.ui.Report.create(r);
		r.run();
	}
}

