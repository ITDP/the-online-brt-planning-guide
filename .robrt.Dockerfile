FROM ubuntu:16.04
ENV PS1="# "
RUN mkdir -p /var/git
RUN apt-get update
RUN apt-get install -y time net-tools
RUN apt-get install -y texlive
RUN apt-get install -y software-properties-common git texlive-xetex texlive-luatex latexmk
RUN apt-get install -y texlive-fonts-extra
RUN apt-get install -y nodejs npm nodejs-legacy
RUN apt-get install -y curl && curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash && apt-get install -y git-lfs && git-lfs install --skip-smudge
RUN add-apt-repository -y ppa:haxe/snapshots && apt-get update && apt-get install -y haxe neko
RUN haxelib setup /usr/share/haxe/lib
RUN haxelib install version
RUN haxelib install ansi
RUN haxelib install hxnodejs
RUN haxelib git utest https://github.com/jonasmalacofilho/utest && cd /usr/share/haxe/lib/hxparse/git && git checkout 173015f; cd -
RUN haxelib git hxparse https://github.com/jonasmalacofilho/hxparse && cd /usr/share/haxe/lib/hxparse/git && git checkout e0edc8d; cd -
RUN haxelib git assertion https://github.com/protocubo/assertion.hx && cd /usr/share/haxe/lib/assertion.hx/git && git checkout 5e37f06; cd -
RUN haxelib git literals https://github.com/protocubo/literals.hx && cd /usr/share/haxe/lib/literals.hx/git && git checkout 5287256; cd -
RUN haxelib git sys-utils https://github.com/jonasmalacofilho/sys-utils.hx && cd /usr/share/haxe/lib/sys-utils/git && git checkout 43b7ddd; cd -
RUN haxelib install tink_template
