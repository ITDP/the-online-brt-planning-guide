FROM ubuntu:15.10
RUN apt-get update && apt-get install -y software-properties-common
RUN add-apt-repository -y ppa:haxe/releases && apt-get update && apt-get install -y haxe neko
RUN haxelib setup /usr/share/haxe/lib && haxelib install utest
RUN apt-get -y install pandoc
RUN apt-get -y install git
RUN mkdir -p /var/git
RUN git clone https://github.com/jonasmalacofilho/docopt.hx /var/git/docopt.hx && cd /var/git/docopt.hx && git checkout a716273 && haxelib dev docopt /var/git/docopt.hx
RUN apt-get install -y texlive texlive-xetex
ENV PS1="# "

