#!/bin/bash
set -e

if [ "$#" -lt 2 ]; then
	echo "Usage: compress-pdf-assets.sh <pdf-build-dir> <desired-resolution> [additional-options-for-convert]"
	exit 1;
fi

pdf_build_dir=$1
resolution=$2
shift 2
cmdline=$@

inch=25.4
# geometry dimensions in mm (manually copied from preamble.tex)
mw=49
tw=105
msw=7

# computed new sizes
size_mw=$(bc <<< "$resolution*$mw/$inch")
size_tw=$(bc <<< "$resolution*$tw/$inch")
size_fw=$(bc <<< "$resolution*($mw+$msw+$tw)/$inch")

set -x

find "$pdf_build_dir/assets/mw" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -exec convert \{\} -resize $size_mw\> $cmdline \{\} \;
find "$pdf_build_dir/assets/tw" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -exec convert \{\} -resize $size_tw\> $cmdline \{\} \;
find "$pdf_build_dir/assets/fw" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -exec convert \{\} -resize $size_fw\> $cmdline \{\} \;

