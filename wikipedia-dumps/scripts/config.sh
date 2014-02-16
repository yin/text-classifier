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

