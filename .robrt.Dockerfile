FROM ubuntu:15.10
ENV PS1="# "
RUN mkdir -p /var/git
RUN apt-get update
RUN apt-get install -y texlive
RUN apt-get install -y software-properties-common git texlive-xetex latexmk
RUN add-apt-repository -y ppa:haxe/snapshots && apt-get update && apt-get install -y haxe neko
RUN haxelib setup /usr/share/haxe/lib
RUN haxelib install utest
RUN haxelib install hxparse
RUN haxelib git assertion https://github.com/protocubo/assertion.hx && cd /usr/share/haxe/lib/assertion.hx/git && git checkout b104566; cd -

