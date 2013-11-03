#!/bin/bash

# Download source
mkdir -p source/
source_bz2=source/skwiki-20131006-pages-articles.xml.bz2
wget_opts=""
if [ -w $source_bz2 ]; then
	wget_opts="$wget_opts -c"
fi
wget http://dumps.wikimedia.org/skwiki/20131006/skwiki-20131006-pages-articles.xml.bz2 \
	$wget_opts -O $source_bz2

# Preprocess
unpack=${source_bz2%.bz2}
if [ ! -f $unpack ]; then
	echo unpacking
	bzcat $source_bz2 > $unpack
fi
if [ ! -d splits/ ]; then 
	echo splitting
	mkdir -p splits/
	cat $unpack \
		| ( cd splits; csplit -f 'skwiki' -b '%06d.xml' - '/<page>/' '{*}' ) \
		| awk 'BEGIN{N=0} {N=N+1} N%1000==0{printf "Processed: " N "\n"} N%1000==500{printf "\r"}'
fi

# wiki-markup2txt
echo textizing
mkdir -p wikiout/
python tools/WikiExtractor.py -o wikiout/ < $unpack

