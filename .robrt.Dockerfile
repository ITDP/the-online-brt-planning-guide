FROM ubuntu:15.10
RUN apt-get update && apt-get install -y software-properties-common
RUN add-apt-repository -y ppa:haxe/releases && apt-get update && apt-get install -y haxe neko
RUN haxelib setup /usr/share/haxe/lib && haxelib install utest
RUN apt-get -y install pandoc
ENV PS1="# "

