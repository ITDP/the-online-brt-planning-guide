package format.tests;

class Main {
	static function main()
	{
		var runner = new utest.Runner();
		runner.addCase(new HtmlGeneration());
		utest.ui.Report.create(runner);
		runner.run();
	}
}

