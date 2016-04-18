package format.tests;

import format.tests.HtmlGeneration;
import format.tests.Parsing;

class Main {
	static function main()
	{
		var runner = new utest.Runner();
		runner.addCase(new Parsing());
		runner.addCase(new HtmlGeneration());
		utest.ui.Report.create(runner);
		runner.run();
	}
}

