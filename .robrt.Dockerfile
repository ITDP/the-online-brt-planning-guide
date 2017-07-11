FROM ubuntu:16.04
LABEL date=2017-Jul-11
RUN mkdir -p /var/git
RUN apt-get update
RUN apt-get install -y texlive
RUN apt-get install -y texlive-fonts-extra
# we build with luatex but xetex is still required for (at least) xunicode.sty
RUN apt-get install -y texlive-xetex texlive-luatex latexmk
RUN apt-get install -y software-properties-common git time net-tools
RUN apt-get install -y nodejs npm nodejs-legacy
RUN apt-get install -y bc imagemagick
RUN apt-get install -y curl && curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash && apt-get install -y git-lfs && git-lfs install --skip-smudge
RUN add-apt-repository -y ppa:haxe/snapshots && apt-get update && apt-get install -y haxe neko
RUN haxelib setup /usr/share/haxe/lib

