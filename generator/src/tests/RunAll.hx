package tests;

class RunAll {
	public static function runAll()
	{
		Context.debug = true;
		Context.draft = false;
		Context.noMathValidation = false;

		Assertion.enableShow = true;
		Assertion.enableWeakAssert = true;
		Assertion.enableAssert = true;

		var r = new utest.Runner();
		r.addCase(new Test_01_Tools());
		r.addCase(new Test_02_Lexer());
		r.addCase(new Test_03_Parser());
		r.addCase(new Test_04_Validation());
		r.addCase(new Test_05_Transform());
		r.addCase(new NeedlemanWunschTests());
		r.addCase(new Test_09_Issues());

		utest.ui.Report.create(r);
		r.onProgress.add(function (o) if (o.done == o.totals) util.sys.FsUtil.remove(Const.UNIT_TEMP_DIR));
		r.run();
	}

	static function main()
	{
		Context.prepareSourceMaps();
		runAll();
	}
}

