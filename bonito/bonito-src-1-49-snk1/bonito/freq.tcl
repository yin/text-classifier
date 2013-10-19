#  bonito:
#       $Id: freq.tcl,v 1.7 2002/12/17 14:39:15 pary Exp $
#
#  Copyright (c) 2000-2002  Pavel Rychly

package provide freq 1.0

package require colloc 1.0

proc freqdistWindow {} {
    set w .freqdist
    widlistInit $w freqdist
    entry $w.limit -textvar corp::frqd_limit -width 5
    pack [label $w.limlbl] $w.limit -in $w.globalopt -side left
}

proc freqdist-add {w var idx} {
    frame $w.attrfr
    # XXX
    makeMenuButon $w.attr ${var}($idx,attr) [concat [comm:listatrib] [comm:liststrattr]]
    #makeMenuButon $w.attr ${var}($idx,attr) [comm:listatrib]
    checkbutton $w.icase -variable ${var}($idx,icase)
    pack [label $w.attrlbl] $w.attr $w.icase -in $w.attrfr -side left
    pack $w.attrfr [makeposframe $w.left $var $idx,left] \
	    -side top -padx 20 -pady 2
    #[makeposframe $w.right $var $idx,right] \
}

proc freqdist-eval {w ranges varname} {
    upvar \#0 $varname var
    destroy $w
    set criteria ""
    foreach n $ranges {
	# poses
	append criteria $var($n,attr)
	if $var($n,icase) { append criteria /i }
	set pos [composePos $varname $n,left]
	append criteria " $pos "
    }
    updateStatus freqdist
    set res [comm:evalcommand "fdist query $corp::frqd_limit $criteria"]
    freqdistresultWindow $res $criteria
}
   
proc filter_freqres {res} {
    set out {}
    foreach line [split $res "\n"] {
	lappend out [split $line "\t"]
    }
    return $out
}

proc filter_criteria {critlist} {
    set substrs {}
    set kwicstr [getOption kwic .genstring]
    lappend substrs >0 "$kwicstr>" <0 "<$kwicstr"
    set collstr [getOption ncolloc .genstring]
    for {set i 1} {$i <= $corp::maxcoll} {incr i} {
	lappend substrs >$i [format "$collstr>" $i] <$i [format "<$collstr" $i]
    }

    set out {}
    foreach {a c} [string trim $critlist] {
	regsub /i $a {} a2
	set c [lindex [split $c ~] 0]
	foreach {from to} $substrs {
	    regsub $from $c $to c2
	    set c $c2
	}
	lappend out "$a2: $c"
    }
    return $out
}

proc freqdistresultWindow {res criteria} {
    updateStatus result
    set corp::frqd_result [filter_freqres $res]
    set corp::frqd_criteria  [filter_criteria $criteria]
    set w .freqres
    catch {unset corp::frqdres_r}
    widlistInit $w frqdres [llength $corp::frqd_criteria] {close}
    entry $w.limit -textvar corp::frqd_limit -width 5
    pack [label $w.limlbl] $w.limit -in $w.globalopt -side left
    label $w.lines -textvar corp::freqd_lines -anchor w
    pack [label $w.showlines] $w.lines -in $w.globalopt -side left -padx 10
    pack $w.frame -expand yes -fill both

    set t [tabbedtext $w.resfr ""]
    $t tag configure subtotal -foreground red
    $t tag configure value -foreground blue
    pack $w.resfr -in $w.frame -expand yes -fill both

    pack [button $w.save -command "tabbedtext-save $t"] \
	    -in $w.buttons -side left -padx 15
    wm resizable $w 1 1
    set corp::frqd_limit_last x
    updateFreqdistLines
    trace variable corp::frqdres_r w "frqdres-autoeval"
}

namespace eval corp {variable frqd_limit}
trace variable corp::frqd_limit w "after 500 updateFreqdistLines"

proc updateFreqdistLines args {
    if {[winfo exists .freqres]} {
	if {$corp::frqd_limit_last != $corp::frqd_limit} {
	    set corp::frqd_limit_last $corp::frqd_limit
	    set s 0
	    foreach l $corp::frqd_result {
		if {[lindex $l 0] > $corp::frqd_limit} {
		    incr s
	    }   }
	    set corp::freqd_lines $s
	    frqdres-autoeval
	}
    }
}


proc frqdres-add {w var idx} {
    set ${var}($idx) show
    pack [label $w.lbl -text [lindex $corp::frqd_criteria $idx] -anchor w] \
	    -side left -padx 10 -expand yes -fill x
    pack [radiobutton $w.show -variable ${var}($idx) -value show] \
	    [radiobutton $w.sum -variable ${var}($idx) -value sum]   \
	    [radiobutton $w.hide -variable ${var}($idx) -value hide] \
	    -side left -padx 5
}

proc frqdres-autoeval args {
    catch {after cancel $corp::frqdres_after_id}
    after 500 [list frqdres-eval .freqres [set widlist::.freqres-ranges] \
	    corp::frqdres_r]
}

proc frqdres-eval {w ranges varname} {
    upvar \#0 $varname var
    set idxes {}
    set sums {}
    set last 0
    set i 0
    set suffix ""
    set heads ""
    foreach n $ranges {
	if {$var($n) == "sum"} {
	    lappend sums $i
	}
	if {$var($n) != "hide"} {
	    append heads "[lindex [lindex $corp::frqd_criteria $n] 0]\t"
	    lappend idxes [incr n]
	    set last $i
	    incr i
	    append suffix "\t"
	}
    }

    set p ""
    set prefs [list ""]
    set suffs {}
    for {set i 0} {$i < [llength $idxes]} {incr i} {
	set p "\t$p"
	set suffix [string range $suffix 1 end]
	if {[lsearch -exact $sums $i] >= 0} {
	    lappend suffs $suffix
	    lappend prefs $p
	}
    }

    if {[lindex $sums end] != $last} {
	lappend sums [expr $i -1]
    }

    set corp::frqd_ressel [freqres_select $idxes $sums]
    freqres_showresult $w.resfr.table $corp::frqd_ressel $prefs $suffs $heads
}



proc freqres_select {idxlist sumlist} {
    #puts "i: $idxlist  s: $sumlist"
    array set freqs {}
    array set sums {0 0 1 0 2 0 3 0 4 0 5 0 6 0 7 0 8 0 9 0}
    foreach i $sumlist {set sums($i) 1}
    # compute sums
    foreach line $corp::frqd_result {
	set f [lindex $line 0]
	set id {}
	set i 0
	#puts "line: $line"
	foreach idx $idxlist {
	    append id "\1[lindex $line $idx]"
	    #puts "idx:[lindex $line $idx]"
	    if $sums($i) {
		if [info exists freqs($i$id)] {
		    incr freqs($i$id) $f 
		} else {
		    set freqs($i$id) $f
		}
	    }
	    incr i
	}
    }
    # sort
    return [freqres_sortlevel $sumlist ""] 
}

proc freqres_sortlevel {sumlist pref} {
    upvar freqs freqs
    set level [lindex $sumlist 0]
    #puts "sums: $sumlist  pref:$pref  level $level"
    set sumlist [lreplace $sumlist 0 0]
    set len [string length "$level$pref\1"]
    set out {}
    #puts "sort: [array names freqs $level$pref\1*]"
    regsub -all {[*?]} $pref {\\&} safepref
    if {[llength $sumlist] == 0} {
	foreach id [array names freqs "$level$safepref\1*"] {
	    if {$freqs($id) > $corp::frqd_limit} {
		lappend out [list $freqs($id) \
			[split [string range $id $len end] "\1"]]
	    }
	}
    } else {
	foreach id [array names freqs "$level$safepref\1*"] {
	    if {$freqs($id) > $corp::frqd_limit} {
		lappend out [list $freqs($id) \
			[split [string range $id $len end] "\1"] \
			[freqres_sortlevel $sumlist [string range $id 1 end]]]
	    }
	}
    }
    return [lsort -integer -decreasing -index 0 $out]
}	


proc freqres_showresult {w tree prefs suffs heads} {
    $w configure -state normal
    $w delete 1.0 end
    $w insert end "$heads##" head "\n"
    freqres_showsubresult $w $tree $prefs $suffs
    $w configure -state disabled
}

proc freqres_showsubresult {w tree prefs suffs} {
    set pref [lindex $prefs 0]
    set suff [lindex $suffs 0]
    set prefs [lrange $prefs 1 end]
    set suffs [lrange $suffs 1 end]
    foreach line $tree {
	foreach {f val sub} $line break
	$w insert end $pref
	foreach v $val {
	    $w insert end $v {} "\t"
	}
	if {$suff == ""} {
	    $w insert end $f value "\n"
	} else {
	    $w insert end $suff {} $f subtotal "\n"
	}
	if {$sub != ""} {
	    freqres_showsubresult $w $sub $prefs $suffs
	}
    }
}
