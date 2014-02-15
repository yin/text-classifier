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
wikipre_dir="data-13wiki_rem_accent"
stats_file=$wikipre_dir/megadoc_ar-corpus_word_freq

wiki_extractor="python tools/WikiExtractor.py"
wiki_extractor_mt="python tools/WikiExtractor-mt2.py"
accent_remover="nodejs tools/accent_remover.js"

mt=false

download() {
	mkdir -p $source_bz2_dir
	wget_opts=""
	if [ -w $source_bz2 ]; then
		wget_opts="$wget_opts -c"
	fi
	wget $source_bz2_url \
		$wget_opts -O $source_bz2
}

unpack() {
  echo unpacking
  mkdir $source_file_dir
  bzcat $source_bz2 > $source_file
}

# Download source
if [ ! -f $source_bz2 ]; then
  download
else
  echo "... the wikipedia pack is already downloaded."
fi

# Preprocess
if [ -f $source_bz2 ]; then
	if [ ! -f $source_file ]; then
            unpack
	else
	    echo "... already unpacked"
	fi
fi

echo TODO Following parts work, but should be refactored into functions
exit 0

## TODO(yin): This needs review

# For my XML-wellformness imune MT wikiextractor, I need to split the BIG XML. 
if [ -f $source_file ] && [ "$mt" == true ]; then
	if [ ! -d splits/ ]; then 
		echo splitting mt=true
		mkdir -p $splits_dir
		# Split the BIG XML into files on lines containing <page> tag
		cat $source_file \
			| ( cd $splits_dir; csplit -f 'skwiki' -b '%06d.xml' - '/<page>/' '{*}' ) \
			| awk 'BEGIN{N=0} {N=N+1} N%1000==0{printf "Processed: " N "\n"} N%1000==500{printf "\r"}'
	else
		echo "... already textized (mt)"
	fi
fi

# Convert wikimedia markup format to plain/text
if [ -f $source_file ] && [ "$mt" == false ]; then
	if [ ! -d $wikiout_dir ]; then
		echo textizing
		mkdir -p $wikiout_dir
		echo $wiki_extractor -o $wikiout_dir '<' $source_file
		$wiki_extractor -o $wikiout_dir < $source_file
	else
		echo "... already textized - $wikiout_dir present."
	fi
fi

# Create Megadoc
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

# Remove accents
if [ -f $wikimegadoc_dir/megadoc ]; then
	if [ ! -f $wikipre_dir/megadoc_ar ]; then
		echo 'removing accents'
		mkdir -p $wikipre_dir
		echo $accent_remover '<' $wikimegadoc_dir/megadoc '>' $wikimegadoc_dir/megadoc_ar 
		$accent_remover < $wikimegadoc_dir/megadoc > $wikipre_dir/megadoc_ar 
	else
		echo "... accents already removed."
	fi
fi

# Last preprocessing (remove punctuation, toLower, split numericals followed by letters, etc.)
if [ -f $wikipre_dir/megadoc_ar ]; then
	if [ ! -f $wikipre_dir/megadoc_ar_rp_tl_sn ]; then
		echo "remove punctuation, toLower, split numericals followed by letters, etc."
		echo "tr -cd 'abcderfghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ' \
			< $wikipre_dir/megadoc_ar \
			> $wikipre_dir/megadoc_ar_rp"
		tr -cd 'abcderfghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ' \
			< $wikipre_dir/megadoc_ar \
			> $wikipre_dir/megadoc_ar_rp
		
		echo "tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcderfghijklmnopqrstuvwxyz' \
			< $wikipre_dir/megadoc_ar_rp \
			> $wikipre_dir/megadoc_ar_rp_tl"
		tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcderfghijklmnopqrstuvwxyz' \
			< $wikipre_dir/megadoc_ar_rp \
			> $wikipre_dir/megadoc_ar_rp_tl
		
		echo "sed -e 's/\([0-9]\)\([^0-9]\)/\1 \2/' \
			< $wikipre_dir/megadoc_ar_rp_tl \
			> $wikipre_dir/megadoc_ar_rp_tl_sn"
		sed -e 's/\(\[0-9\]\)\(\[^0-9\]\)/\1 \2/' \
			< $wikipre_dir/megadoc_ar_rp_tl \
			> $wikipre_dir/megadoc_ar_rp_tl_sn
	else
		echo "... preprecess already done."
	fi
fi

# Create basic corpus stats
if [ -f $wikipre_dir/megadoc_ar_rp_tl_sn ]; then
	if [ ! -f $stats_file ]; then
		echo "creating corpus statistics"
		echo "tr ' ' '\n' | sort \
		| awk
	'BEGIN {last=-1} \
	last!=-1 {
		if(last == $0) {
			last_n++;
		} else {
			print last_n " " last;
			last_n=1
		}
	}
	{last=$0}' \
		< $wikipre_dir/megadoc_ar_rp_tl_sn # > $stats_file"
		tr ' ' '\n' \
			< $wikipre_dir/megadoc_ar_rp_tl_sn \
			| sort \
			| awk 'BEGIN {last=-1}
				last!=-1 {
					if(last == $0) {
						last_n++;
					} else {
						print last_n " " last;
						last_n=1
					}
				}
				{last=$0}' \
			> $stats_file

		echo sort -rn $stats_file '>' $stats_file-by_counts
		sort -rn $stats_file > $stats_file-by_counts

		echo sort -k2 $stats_file '>' $stats_file-by_word
		sort -k2 $stats_file > $stats_file-by_word
		
	else
		echo "... statistics already created."
	fi
fi

