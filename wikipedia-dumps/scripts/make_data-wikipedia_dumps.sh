#!/bin/bash

###
# This script downloads wikipedia dump, prepares the megadoc and makes some stats
#

. config.sh
. lib_prepare()

if [ ! -f $source_bz2 ]; then
  download
else
  echo "... the wikipedia pack is already downloaded."
fi

if [ -f $source_bz2 ]; then
	if [ ! -f $source_file ]; then
            unpack
	else
	    echo "... already unpacked"
	fi
fi

if [ -f $source_file ]; then
	if [ ! -d $wikiout_dir ]; then
            split_articles
	else
		echo "... already textized - $wikiout_dir present."
	fi
fi

if [ -d $wikiout_dir ]; then
	if [ ! -d $wikimegadoc_dir ]; then
            create_megadoc
	else
		echo "... the Wikipedia MegaDocument is already built."
	fi
fi

if [ -f $wikimegadoc_dir/megadoc ]; then
	if [ ! -f $wikipre_dir/megadoc_ar ]; then
            remove_accents
	else
		echo "... accents already removed."
	fi
fi

if [ -f $wikipre_dir/megadoc_ar ]; then
	if [ ! -f $wikipre_dir/megadoc_ar_rp_tl_sn ]; then
            preprocess
	else
		echo "... preprecess already done."
	fi
fi

if [ -f $wikipre_dir/megadoc_ar_rp_tl_sn ]; then
	if [ ! -f $stats_file ]; then
            create_basic_stats
	else
		echo "... statistics already created."
	fi
fi

