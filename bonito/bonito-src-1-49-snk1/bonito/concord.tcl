#  bonito:
#     $Id: concord.tcl,v 1.9 2004/01/12 18:53:18 pary Exp $
#
#  Copyright (c) 2000-2003  Pavel Rychly


package provide concord 1.0

package require attrib 1.0
package require mltlist 1.0

namespace eval corp {
    set store_conc {}
    set forward_conc {}
    array set named_conc {}
    set named_conc_num 0
    set swapkwic 0
}

proc store_conc {{cmd clone}} {
    if {$corp::resultlen == 0} return
    set levels [expr $opt::undolevels -1]
    if {[llength $corp::store_conc] > $levels} {
	for {set i 0} {$i < $levels} {incr i} {
	    comm:evalcommand "rename store-[expr $i +1] store-$i"
	}
	set corp::store_conc [lrange $corp::store_conc 1 end]
    } else {
	set levels [llength $corp::store_conc]
    }
    comm:evalcommand "$cmd query store-$levels"
    lappend corp::store_conc [list $corp::name $corp::resultsteps \
				  $corp::maxcoll]

    # delete forward history
    set i $levels
    foreach x $corp::forward_conc {
	comm:evalcommand "erase store-[incr i]"
    }
    set corp::forward_conc {}
}

proc restore_conc_eval {concname concinfo} {
    global sel_corp_name sel_corp_name-text
    foreach {name steps maxcoll} $concinfo break
    set corp::restoring 1
    set sel_corp_name $name
    set sel_corp_name-text $name
    set corp::restoring 0
    set corp::resultsteps $steps
    set corp::maxcoll $maxcoll
    comm:evalcommand "clone $concname query"
    makeConcCollButton
    refreshResult start
}

proc restore_conc {} {
    if {$corp::store_conc == {}} {
	return
    }
    set concinfo [lindex $corp::store_conc end]
    set level [llength $corp::store_conc]
    if {$corp::forward_conc == {}} {
	# store first
	comm:evalcommand "rename query store-$level"
    }
    lappend corp::forward_conc [list $corp::name $corp::resultsteps \
				  $corp::maxcoll]
    set corp::store_conc [lreplace $corp::store_conc end end]
    restore_conc_eval "store-[incr level -1]" $concinfo
    concinfo_detail
}

proc forward_conc {} {
    if {$corp::forward_conc == {}} {
	return
    }
    set concinfo [lindex $corp::forward_conc end]
    lappend corp::store_conc [list $corp::name $corp::resultsteps \
				  $corp::maxcoll]
    set corp::forward_conc [lreplace $corp::forward_conc end end]
    restore_conc_eval "store-[llength $corp::store_conc]" $concinfo
    concinfo_detail
}

proc store_named_conc {} {
    set w .namedconc
    makeDialogWindow $w {ok finish_named_conc close}
    set corp::newconcname ""
    entry $w.name -textvariable corp::newconcname
    pack [label $w.nlbl] $w.name -in $w.frame -side left
}


proc finish_named_conc {} {
    destroy .namedconc
    set corp::named_conc($corp::newconcname) \
	    [list [incr corp::named_conc_num] $corp::name $corp::resultsteps \
		$corp::maxcoll]
    comm:evalcommand "clone query named-$corp::named_conc_num"
    set menupath $opt::namedmenupath
    kdMakeMenu .mb menupath {
	cascade_path $menupath {
	    command $corp::newconcname \
		    [list restore_named_conc $corp::newconcname]
    }   }
}

proc restore_named_conc {name} {
    set id [lindex $corp::named_conc($name) 0]
    restore_conc_eval "named-$id" [lrange $corp::named_conc($name) 1 end]
}


proc delete_named_conc_win {} {
    set w .delnamedconc
    makeDialogWindow $w {ok delete_named_conc close}
    set corp::newconcname ""
    pack [listbox $w.list -exportselection no] -in $w.frame -side left
    foreach n [array names corp::named_conc] {
	$w.list insert end $n
    }
}

proc delete_named_conc {} {
    set w .delnamedconc.list
    set i [$w curselection]
    if {$i == ""} return
    set name [$w get $i]
    $w delete $i
    comm:evalcommand "erase named-[lindex $corp::named_conc($name) 0]"
    unset corp::named_conc($name)
    set menupath $opt::namedmenupath
    lappend menupath $name
    deleteMenuItem .mb $menupath
}

proc conc_info_str {concinfo} {
    set out {}
    array set qtype {
	0 "Query   " p "P-filter" n "N-filter" 
	1 "Collocation 1" 2 "Collocation 2" 3 "Collocation 3" 
	4 "Collocation 4" 5 "Collocation 5" 6 "Collocation 6" 
	7 "Collocation 7" 8 "Collocation 8" 9 "Collocation 9" 
	del "Deleted " swap "Swap" delgrp "Del Group" reduce "Reduced"
    }
    foreach {type info} $concinfo {
	lappend out "  > $qtype($type): [lindex $info 2]"
    }
    return $out
}

proc concinfo_detail {{w .detail.list}} {
    $w delete 0.0 end
    set fin ""
    if {$corp::querytyperesult || [trace vinfo corp::resultlen] != ""} {
	set fin "??"
    }
    $w insert end [getOption numofhits .genstring] strc \
	" $corp::resultlen$fin\n"
    foreach l [conc_info_str $corp::resultsteps] {
	set i [string first : $l]
	$w insert end [string range $l 0 $i] strc 
	$w insert end "[string range $l [incr i] end]\n"
    }
    $w see end
}

proc swapKWICWindow {{w .swapkwic}} {
    if {!$corp::maxcoll} return
    makeDialogWindow $w [list ok "swapKWICfinish $w" close]
    set collstr [getOption coll .queryfr.select]
    for {set i 1} {$i <= $corp::maxcoll} {incr i} {
	radiobutton $w.c$i -text [format $collstr $i] -value $i \
	    -variable corp::swapkwic
	pack $w.c$i -side top -anchor w -in $w.frame
    }
}

proc swapKWICfinish {w} {
    destroy $w
    store_conc
    lappend corp::resultsteps swap [list 0 0 $corp::swapkwic]
    comm:evalcommand "swapkwic query $corp::swapkwic"
    refreshResult
}

proc linegroupstatWindow {{w .lngrpstat}} {
    makeDialogWindow $w {delete delete_linegroup close}
    pack [multilistbox $w.list 2] -in $w.frame
    set lngprs [comm:evalcommand "linegroupstat query"]
    foreach line [split $lngprs "\n"] {
	$w.list insert end [split $line "\t"]
    }
}

proc delete_linegroup {} {
    set w .lngrpstat.list
    set gprs [$w getcolselection 0]
    if {$gprs != ""} {
	store_conc
	lappend corp::resultsteps delgrp [list 0 0 $gprs]
 	comm:evalcommand "dellinegroups query $gprs"
	foreach idx [lsort -decreasing [$w.0.box curselection]] {
	    $w delete $idx
	}
	set corp::sellines {}
	refreshResult start
	concinfo_detail
    }
}
