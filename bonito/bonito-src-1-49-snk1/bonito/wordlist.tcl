#  bonito:
#     $Id: wordlist.tcl,v 1.8 2003/12/01 10:18:29 pary Exp $
#
#  Copyright (c) 2002-2003  Pavel Rychly

package provide wordlist 1.0

package require attrib 1.0
package require mltlist 1.0



proc wordlistWindow {} {
    set w .wlistwin
    makeDialogWindow $w {
	ok wordlistFillList 
	conc wordlistCreateConc
	save wordlistSave
	close
    }
    pack .wlistwin.frame -expand no
    wm resizable $w 1 1
    grab release $w

    label $w.attrlbl -anchor w
    makeMenuButon $w.attr corp::wlistattr [comm:listatrib]

    label $w.patlbl -anchor w
    entry $w.pattern -textvar corp::wlistpat

    pack [frame $w.frame.qfr] -side top -fill x -pady 3
    pack $w.attrlbl $w.attr $w.patlbl -in $w.frame.qfr -side left -padx 3
    pack $w.pattern -in $w.frame.qfr -side left -fill x -expand 1 -padx 3

    checkbutton $w.icase -anchor w -variable corp::wlisticase
    pack $w.icase -side top -fill x -pady 3 -in $w.frame

    label $w.freqlbl -anchor w
    entry $w.freqentr -width 8 -textvariable corp::wlistminfreq
    pack [frame $w.frame.freq] -side top -fill x -pady 3
    pack $w.freqlbl $w.freqentr -side left -in $w.frame.freq -padx 3

    label $w.lineslbl -anchor w
    entry $w.linesentr -width 8 -textvariable corp::wlistmaxlines
    pack [frame $w.frame.lines] -side top -fill x -pady 3
    pack $w.lineslbl $w.linesentr -side left -in $w.frame.lines -padx 3

    radiobutton $w.addtolist -variable corp::wlistnewlist -value add
    radiobutton $w.newlist -variable corp::wlistnewlist -value new
    pack [frame $w.frame.addnewlist] -side top -fill x -pady 3
    pack $w.addtolist $w.newlist -side left -in $w.frame.addnewlist -padx 3


    pack [multilistbox $w.res 2] -side top -fill both -expand 1 \
	-pady 5 -padx 10

    pack [label $w.status -anchor w -relief sunken] -side top -fill x \
	-pady 5 -padx 10 -ipady 3

    focus $w.pattern

    wordlistAttrChanged
    bind .wlistwin.res <<ListboxSelect>> wordlistUpdateStatus
}


namespace eval corp {
    variable wlistattr ""
    variable wlistminfreq 5 wlistmaxlines 100 wlisticase 0
    variable wlistnewlist new
}

trace variable corp::wlistattr w wordlistAttrChanged

proc wordlistAttrChanged args {
    set res .wlistwin.res
    if {[winfo exists $res]} {
	$res.0.lbl config -text $corp::wlistattr
	$res delete 0 end
	wordlistUpdateStatus
    }
}

proc wordlistFillList {} {
    if {$corp::wlistpat == ""} return
    set w .wlistwin
    if {$corp::wlistnewlist == "new"} {
	$w.res delete 0 end
	set currlist {}
    } else {
	set currlist [$w.res getcol 0 0 end]
    }
    set list [comm:evalcommand "wordlist $corp::name $corp::wlistattr $corp::wlistminfreq $corp::wlistmaxlines $corp::wlisticase $corp::wlistpat"]
    set idx 0
    foreach line [lsort -dictionary [split $list "\n"]] {
	set ll [split $line "\t"]
	if {[lsearch -exact $currlist [lindex $ll 0]] == -1} {
	    $w.res insert $idx $ll
	    incr idx
	}
    }
    wordlistUpdateStatus
}

proc wordlistCreateConc {} {
    set w .wlistwin
    set q ""
    foreach v [$w.res getcolselection 0] {
	append q " | $corp::wlistattr=\"$v\""
    }
    if {$q == ""} return
    set q [string range $q 3 end]
    set corp::query "\[$q\]"
    set corp::qrlabel ""
    set corp::qtype conc
    processQuery
}


proc wordlistUpdateStatus {} {
    set w .wlistwin
    set ws $w.status
    set wr $w.res
    
    set size [$wr size]
    if {$size == 0} {
	$ws config -text ""
    } else {
	set freqs [$wr getcolselection 1]
	set sum 0
	foreach f $freqs {
	    incr sum $f
	}
	$ws config -text [format [getOption text $ws] $size [llength $freqs] \
			      $sum]
    }
}

proc wordlistSave {} {
    set w .wlistwin
    set fname [tk_getSaveFile -parent [winfo toplevel $w]]
    if {$fname == ""} return
    set size [$w.res size]
    set f [open $fname "w"]
    for {set i 0} {$i < $size} {incr i} {
	puts $f [join [lrange [$w.res get $i] 0 1] "\t"]
    }
    close $f
}