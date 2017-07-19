import { Selector } from 'testcafe';

fixture `load and use the dynamic table of contents in the nav bar`
	.page `http://localhost:8080`;

const nav = Selector("nav");

test('load', async t => {
	await t
		.expect(nav.textContent).notContains("Loading the table of contents", "'loading' placeholder removed")
		.expect(nav.find("li").nth(1).textContent).contains("Volume 1", "nav loaded")
});

test('dynamic filtering @ root', async t => {
	await t
		.expect(nav.find("li.volume").count).gt(1, "root has volumes")
		.expect(nav.find("li.chapter").count).gt(1, "and chapters")
		.expect(nav.find("li.chapter li").count).eql(0, "but no sections");
});

test('dynamic filtering @ volume', async t => {
	const someVolume = nav.find("li.volume>a").nth(2);
	const url = await someVolume.getAttribute("href");
	await t.click(someVolume);

	const cur = nav.find("a").withAttribute("href", url).parent("li.volume");
	await t
		.expect(cur.count).eql(1)
		.expect(nav.find("li.volume").count).gte(1, "nav has volumes")
		.expect(cur.find("li.chapter").count).gt(1, "and chapters")
		.expect(cur.find("li.chapter li").count).eql(0, "but no sections")
		.expect(cur.nextSibling().find("li").count).eql(0, "also, no nephews")
		.expect(cur.prevSibling().find("li").count).eql(0, "also, no nephews");
});

test('dynamic filtering @ chapter', async t => {
	const someChapter = nav.find("li.chapter>a").nth(14);
	const url = await someChapter.getAttribute("href");
	await t.click(someChapter);

	const cur = nav.find("a").withAttribute("href", url).parent("li.chapter");
	await t
		.expect(cur.count).eql(1)
		.expect(nav.find("li.volume").count).gte(1, "nav has volumes")
		.expect(cur.parent("li.volume").count).eql(1, "chapter has a parent")
		.expect(cur.find("li.section").count).gt(1, "and sections")
		.expect(cur.find("li").hasClass("section")).ok("but nothing else")
		.expect(cur.nextSibling().find("li").count).eql(0, "also, no nephews")
		.expect(cur.prevSibling().find("li").count).eql(0, "also, no nephews");
});

test('dynamic filtering @ section', async t => {
	const someChapter = nav.find("li.chapter").nth(14);
	const firstUrl = await someChapter.getAttribute("href");
	await t.click(someChapter);

	const someSection = nav.find("a").withAttribute("href", firstUrl).parent("li.chapter").find("li.section>a").nth(1);
	const url = await someSection.getAttribute("href");
	await t.click(someSection);

	const cur = nav.find("a").withAttribute("href", url).parent("li.section");
	await t
		.expect(cur.count).eql(1)
		.expect(nav.find("li.volume").count).gte(1, "nav has volumes")
		.expect(cur.parent("li.chapter").count).eql(1, "section has a parent")
		.expect(cur.parent("li.volume").count).eql(1, "and has a grandparent")
		.expect(cur.find("li").count).gt(1, "and subsections")
		.expect(cur.nextSibling().find("li").count).eql(0, "also, no nephews")
		.expect(cur.prevSibling().find("li").count).eql(0, "also, no nephews");
});

