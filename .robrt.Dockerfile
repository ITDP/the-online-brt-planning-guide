FROM ubuntu:16.04
ENV PS1="# "
RUN mkdir -p /var/git
RUN apt-get update
RUN apt-get install -y time net-tools
RUN apt-get install -y texlive
RUN apt-get install -y software-properties-common git texlive-xetex texlive-luatex latexmk
RUN apt-get install -y texlive-fonts-extra
RUN apt-get install -y nodejs npm nodejs-legacy
RUN apt-get install -y imagemagick
RUN apt-get install -y curl && curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash && apt-get install -y git-lfs && git-lfs install --skip-smudge
RUN add-apt-repository -y ppa:haxe/snapshots && apt-get update && apt-get install -y haxe neko
RUN haxelib setup /usr/share/haxe/lib

