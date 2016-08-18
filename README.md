### _Online collaborative version of the BRT Planning Guide_

This is a work in progress, that shall later be hosted under ITDP's github account.

###### Newcomers to git

- [Git](https://en.wikipedia.org/wiki/Git_%28software%29) is a computer program [ideally] to be installed on a contributor's computer, where it shall manage a copy (clone) of the required content to produce the BRT Planning Guide (this repository) and submit proposals for changes. Git is originally a command line tool, but there are several graphic tools. It may require a two hour effort to install it and learn the basics of using it without assistance and 20 minutes with assistance. More about git in the [Pro Git book](https://git-scm.com/book/en/v2).

- [Github](github.com) is a website that hosts repositories like this one, where contribution from several people can be centralized, its use is free for open-source projects. Contributors to the BRT Planning Guide are required to have a *github* account, with that only it is possible to submit changes proposals to the guide, although it is not practical for large ones.

_To simply navigate through foloders and files make sure you click on the file name (in light blue on the left side) and *NOT* in the gray message in the middle of the same container (that will lead you to the last changes on the file)_

###### Files structure

*Generator* directory holds code files that will process the content in the *Guide* directory, which contains the source (text files and assets as images referenced in the text files) for the BRT Planning Guide, the *dot files* have configuration information (describing where and how processing the repository must take place and about git itself).

###### The content in the guide 

At the moment, the entry point of processing is in the file [`guide/the-guide.src`](guide/the-guide.src), where other files are pointed with the `\include{point/to/other/file.src}` command. A user manual on how to contribute and of the supported syntax is being developed in the chapter called [Manual for Collaboration](https://brt.robrt.io/branch/development/guide/manual-to-collaboration/).

