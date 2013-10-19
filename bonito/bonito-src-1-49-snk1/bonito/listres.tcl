#  bonito:
# 	$Id: listres.tcl,v 1.3 2001/06/22 18:54:04 pary Exp $	
#
#  Copyright (c) 2000,2001  Pavel Rychly

package provide listres 1.0

namespace eval corp {variable displaying 0}

proc listview_clear {} {
    .list delete 0.0 end
    .detail.list delete 0.0 end
    array set corp::maxwidth {struct 0 0 0 1 0 2 0 3 0 4 0 5 0 6 0 pre 0 in 0 post 0}
    set corp::displaybackward 0
    set corp::displaying 1
    set corp::displayedfrom 0
    set corp::displayedto 0
}

proc listview_init {} {
    set corp::currwidth 0
}

proc listview_add {words part prevpart} {
    if {$part != $prevpart} {
	.list insert insert "\t" {}
	if {$corp::currwidth > $corp::maxwidth($prevpart)} {
	    set corp::maxwidth($prevpart) $corp::currwidth
	}
	set corp::currwidth 0
    } else {
	.list insert insert " "
    }
    if {$words == {}} {
	return
    }
    eval .list insert insert $words
    
    # compute width
    .list.list delete 0.0 end
    eval .list.list insert 0.0 $words
    if [catch {incr corp::currwidth [lindex [.list.list bbox 1.end] 0]}] {
	incr corp::currwidth [expr [string length $words] * 2]
    }
}


proc listview_done_line {} {
    .list insert insert "\n"
    if {$corp::currwidth > $corp::maxwidth(post)} {
	set corp::maxwidth(post) $corp::currwidth
    }
    set corp::currwidth 0
    if $corp::displaybackward {
	.list mark set insert 1.0
	incr corp::displayedfrom -1
    } else {
	incr corp::displayedto
    }
}

proc listview_done_part {} {
    set len1 [expr $corp::maxwidth(struct) + $corp::maxwidth(pre)]
    set len2 $corp::maxwidth(in)
    .list config -tabs [list $len1 right [expr $len1 +5 + $len2 /2] \
	    center [expr $len1 +8 + $len2]]
    #place forget .list.list
    updateStatus result
    tlist:updateselected .list
    # center KWIC
    set xview [.list xview]
    if {$xview != {0 1}} {
	set len [expr $len1 + $len2 + $corp::maxwidth(post)]
	set center [expr double($len1 + $len2/2) / $len]
	set viewlen [expr [lindex $xview 1] - [lindex $xview 0]]
	.list xview moveto [expr $center - $viewlen / 2]
    }
}

proc listview_done_all {} {
    .list delete "end -1 char"
    tlist:updateselected .list
    set corp::displaying 0
}

proc get_addlines {} {
    set b [expr $corp::displayedto - $corp::displayedfrom]
    return [expr $opt::addlines <= $b ? $opt::addlines : $b]
}

proc listview_add_before {} {
    if {($corp::rngfrom != "random" && $corp::displayedfrom == 0) \
	    || $corp::displaying} return
    if {$corp::rngfrom == "random"} {
	set corp::rngfrom first
	refreshResult
	return
    }
    update
    set n [get_addlines]
    incr corp::displayedto -$n
    .list delete "end -$n lines" end
    .list mark set insert 1.0
    set corp::displaybackward 1
    set corp::displaying 1
    initOutput listview add_before
}

proc listview_add_after {} {
    if {$corp::displayedto >= $corp::resultlen || $corp::displaying} return
    if {$corp::rngfrom == "random"} {
	set corp::rngfrom last
	refreshResult
	return
    }
    update
    set n [get_addlines]
    incr corp::displayedfrom $n
    .list delete 1.0 [incr n].0
    .list mark set insert end
    if {[.list compare "1.0 +1 chars" < end]} {
	.list insert end "\n"
    }
    set corp::displaybackward 0
    set corp::displaying 1
    initOutput listview add_after
}

