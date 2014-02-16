## Should be sourced

# Download source
download() {
    mkdir -p $source_bz2_dir
    wget_opts=""
    if [ -w $source_bz2 ]; then
	wget_opts="$wget_opts -c"
    fi
    wget $source_bz2_url \
	$wget_opts -O $source_bz2
}

# Preprocess
unpack() {
    echo unpacking
    mkdir $source_file_dir
    bzcat $source_bz2 > $source_file
}

# Convert wikimedia markup format to plain/text
split_articles() {
    echo splitting articles
    mkdir -p $wikiout_dir
    echo $wiki_extractor -o $wikiout_dir '<' $source_file
    $wiki_extractor -o $wikiout_dir < $source_file
}

# Create Megadoc
create_megadoc() {
    echo 'building megadoc'
    mkdir -p $wikimegadoc_dir
    echo "find $wikiout_dir -type f -exec cat '{}' ';' | awk \
			'/<\\/doc>/{printf \"\\n\"} !/^</{printf \"%s \",$0}' \
			> $wikimegadoc_dir/megadoc"
    find $wikiout_dir -type f -exec cat '{}' ';' | awk \
	'/<\/doc>/{printf "\n"} !/^</{printf "%s ",$0}' \
	> $wikimegadoc_dir/megadoc 

}

# Remove accents
remove_accents() {
    echo 'removing accents'
    mkdir -p $wikipre_dir
    echo $accent_remover '<' $wikimegadoc_dir/megadoc '>' $wikimegadoc_dir/megadoc_ar 
    $accent_remover < $wikimegadoc_dir/megadoc > $wikipre_dir/megadoc_ar 
}

# Last preprocessing (remove punctuation, toLower, split numericals followed by letters, etc.)
preprocess() {
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
}
