#!/bin/bash

download_date=20131006
source_bz2_dir="data-01packed"
source_bz2_name="skwiki-$download_date-pages-articles.xml.bz2"
source_bz2="$source_bz2_dir/skwiki-$download_date-pages-articles.xml.bz2"
source_bz2_url="http://dumps.wikimedia.org/skwiki/$download_date/skwiki-$download_date-pages-articles.xml.bz2"
source_file_dir="data-02unpacked"
source_file_name=${source_bz2_name%.bz2}
source_file="$source_file_dir/$source_file_name"
splits_dir="data-04splits"
wikiout_dir="data-10wikiout_pseudo_xml"
wikitext_dir="data-11wiki_plain_text"
wikimegadoc_dir="data-12wiki_megadoc"

wiki_extractor="python tools/WikiExtractor.py"
wiki_extractor_mt="python tools/WikiExtractor-mt2.py"

mt=false

# Download source
if [ ! -f $source_bz2 ]; then
	mkdir -p $source_bz2_dir
	wget_opts=""
	if [ -w $source_bz2 ]; then
		wget_opts="$wget_opts -c"
	fi
	wget $source_bz2_url \
		$wget_opts -O $source_bz2
else
	echo "... the wikipedia pack is downloaded."
fi

# Preprocess
if [ ! -f $source_file ]; then
	echo unpacking
	mkdir $source_file_dir
	bzcat $source_bz2 > $source_file
fi
# For my XML-wellformness imune MT wikiextractor, I need to split the BIG XML. 
if [ ! -d splits/ ] && [ "$mt" == true ]; then 
	echo splitting mt=true
	mkdir -p $splits_dir
	# Split the BIG XML into files on lines containing <page> tag
	cat $source_file \
		| ( cd $splits_dir; csplit -f 'skwiki' -b '%06d.xml' - '/<page>/' '{*}' ) \
		| awk 'BEGIN{N=0} {N=N+1} N%1000==0{printf "Processed: " N "\n"} N%1000==500{printf "\r"}'
fi

# Convert wikimedia markup format to plain/text
if [ ! -d $wikiout_dir ] && [ "$mt" == false ]; then 
	echo textizing
	mkdir -p $wikiout_dir
	echo $wiki_extractor -o $wikiout_dir '<' $source_file
	$wiki_extractor -o $wikiout_dir < $source_file
else
	echo "... already textized - $wikiout_dir present."
fi

if [ -d $wikiout_dir ] && [ "$mt" == false ]; then
	if [ ! -d $wikimegadoc_dir ]; then
		echo 'building megadoc'
		mkdir -p $wikimegadoc_dir
		echo "find $wikiout_dir -type f -exec cat '{}' ';' | awk \
			'/<\\/doc>/{printf \"\\n\"} !/^</{printf \"%s \",$0}' \
			> $wikimegadoc_dir/megadoc"
		find $wikiout_dir -type f -exec cat '{}' ';' | awk \
			'/<\/doc>/{printf "\n"} !/^</{printf "%s ",$0}' \
			> $wikimegadoc_dir/megadoc 
	else
		echo "... the Wikipedia MegaDocument is already built."
	fi
fi


