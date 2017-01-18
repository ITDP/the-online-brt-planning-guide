# The Online BRT Planning Guide [![Current version](https://img.shields.io/badge/view-brtguide.itdp.org-blue.svg?style=flat-square)](https://brtguide.itdp.org)

The Bus Rapid Transit Planning Guide is the most comprehensive resource for
planning a bus rapid transit (BRT) system, beginning with project preparation
all the way through to implementation.

It is a huge effort by the Institute of Transportation and Development Policy
(ITDP), and dozens of authors and reviewers.

This project aims to make the guide more accessible and keep it up-to-date:

 - the guide is now available online in a website format that is easy to navigate
 - PDFs are also available to those that need to print it
 - the online publication of updates is automatic
 - the entire history of the guide is kept with Git
 - revisions and contributions are easier with GitHub


## File structure

Essentially, the project is divided in two top-level folders: the
[`/guide`](guide) and the [`/generator`](generator).

The first has the files for the entire contents of the guide (text, images,
tables, etc).  The text is written in a simple but powerful format, that at the
same allows ease of use, independence of content from style and is compatible
with version control.

The second contains the source-code for the generator tool, that takes the text
for the guide and the assets and builds, in a single run, both the full website
and the PDFs.


## Contributing

You can ask questions or report problems in the guide by [opening a GitHub
issue](https://github.com/ITDP/the-online-brt-planning-guide/issues/new).

If instead you want to propose changes to either the guide (i.e. a typo fix or
a new section) or, if you're a programmer or a designer, to the generator tool,
please (fork the repository and) open a pull request.

More documentation on how to work with the guide and with GitHub will gradually
become available. In the mean time, if you need help, do not hesitate to
[contact the geeks behind the curtain](mailto:contato@protocubo.io).

### Frequetly asked questions

1. Tried to pull and got a LFS "rate limit reached for unauthenticated requests" error

_If you're seeing this error you problably have cloned the repository without supplying any authentication.  This works great most of the time, but GitHub will enforce lower rate limits and you might trigger them if you're on a spree._

_You should be able to fix that by updating the remote repository URL to use either authenticated HTTPS or SSH.  Check your Git user interface help for instructions on how to do this.  If you're on the command line, adjust and execute one of the following commands:_

```
git remote set-url origin https://<your-github-username-here>@github.com/ITDP/the-online-brt-planning-guide
git remote set-url origin git@github.com:/ITDP/the-online-brt-planning-guide
```

