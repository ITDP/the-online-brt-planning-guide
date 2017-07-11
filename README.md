# The Online BRT Planning Guide [![Current version](https://img.shields.io/badge/view-brtguide.itdp.org-blue.svg?style=flat-square)](https://brtguide.itdp.org)

The Bus Rapid Transit Planning Guide is the most comprehensive resource for
planning a bus rapid transit (BRT) system, beginning with project preparation
all the way through to implementation.

It is a huge effort by the Institute of Transportation and Development Policy
(ITDP), and dozens of authors and reviewers.

This project aims to make the guide more accessible and keep it up-to-date:

 - the guide is now available online in a website format that is easy to navigate
 - a PDF of the guide is available to those that need to print it
 - the online publication of updates is automatic
 - the entire history of the guide is kept with Git
 - revisions and contributions are easier with GitHub


## File structure

Essentially, the project is divided in three top-level folders:

 - [`/guide`](guide): the entire content of the guide (text, images, tables, etc.);
 - [`/generator`](generator): the source-code for **manu**;
 - and auxiliary files for the [`/server`](server)

The text is written in a simple but powerful _manu_-script format that, at the
same time, allows ease of use, independence of content from style and is
compatible with version control.

The generator tool – **manu** – takes the text and assets for the guide and
builds , in a single run, both the full website and the PDF.


## Contributing

You can ask questions or report problems in the guide by [opening a GitHub
issue](https://github.com/ITDP/the-online-brt-planning-guide/issues/new).

If instead you want to propose changes to either the guide (e.g. a typo fix or
a new section) or, if you're a programmer or a designer, to the generator tool,
please (fork the repository and) open a pull request.

More documentation on how to work with the guide and with GitHub will gradually
become available. In the mean time, if you need help, do not hesitate to
[contact the geeks behind the curtain](mailto:contato@protocubo.io).

### Frequently asked questions

#### 1. Tried to pull and got a LFS "rate limit reached for unauthenticated requests" error

_If you're seeing this error you problably have cloned the repository without supplying any authentication.  This works great most of the time, but GitHub will enforce lower rate limits and you might trigger them if you're on a spree._

You should be able to fix that by updating the remote repository URL to use either authenticated HTTPS or SSH.  Check your Git user interface help for instructions on how to do this.  If you're on the command line, adjust and execute one of the following commands:

```
git remote set-url origin https://<your-github-username-here>@github.com/ITDP/the-online-brt-planning-guide
git remote set-url origin git@github.com:/ITDP/the-online-brt-planning-guide
```

#### 2. How to run **manu** and generate the guide locally?

First, you need to [clone](https://help.github.com/articles/cloning-a-repository/) the project's repository.
Then, install [Node.js](https://nodejs.org), get an [up-to-date **manu** package](https://brtguide.itdp.org/branch/master/bin/) and install it with `npm install -g <path-to-downloaded-tgz-file>` (`npm` is automatically installed with Node.js).

_(You can also build **manu** locally from the sources; see [`.robrt.Dockerfile`](.robrt.Dockerfile)/[`.robrt.json`](.robrt.json) for how it's done in the server)_

With _manu_ installed you should be able to run `manu` in your command line.
Try `manu --help` to query the available commands and options.

You can generate the guide with `manu generate guide/index.manu .generated` in a command line at the root of local copy of the project.
This will populate a `.generated` directory with `.html` and `.tex` files.

#### 3. How to test the generated website locally?

After running **manu**, the website is already functional, it's just a matter of starting a server _(configuring it to automatically try adding `.html` extensions)_.

Since we already have Node.js installed for _manu_, the easiest way to do this is with [`http-server`](https://www.npmjs.com/package/http-server) (you can install it with `npm install -g http-server`).

Then, also at the root folder of the project, simply run `http-server .generated/html --ext html -o`.

#### 4. How to build the PDF locally?

To create the PDF you'll need a working LaTeX installation with `lualatex` and `latexmk`.
After running **manu**, navigate to `.generated/pdf` and run `latexmk -lualatex book.tex`.

You may notice that the PDF you generate locally is huge is huge in comparison to the one we provide.
That's because our server automatically compacts all images before running LaTeX, according to their resulting physical size and reasonable assumptions on printer limitations.
You can experiment with that as well by running the [`compress-pdf-assets.sh`](server/compress-pdf-assets.sh) script (note: for this you'll need `bash`, `bc` and ImageMagick).
