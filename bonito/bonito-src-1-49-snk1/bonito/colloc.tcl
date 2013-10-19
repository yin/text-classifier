#  bonito:
#     $Id: colloc.tcl,v 1.14 2003/04/28 18:00:40 pary Exp $
#
#  Copyright (c) 2000-2002  Pavel Rychly

package provide colloc 1.0

package require attrib 1.0

namespace eval corp {
    variable collminfreq 5 collminbgr 3
    variable collfrom 1 collto 5
    variable collsort rel
    variable collmaxlines 100
    variable collres_x 0
}

proc collocWindow {} {
    set w .collwin
    makeDialogWindow $w [list ok "finishcolloc $w" close]

    label $w.attrlbl -anchor w
    makeMenuButon $w.attrib corp::collattr [comm:listatrib]
    pack [frame $w.frame.attr] -side top -fill x
    pack $w.attrlbl $w.attrib -side left -in $w.frame.attr -pady 5 -padx 3

    label $w.fromlbl -anchor w
    entry $w.fromentr -width 4 -textvariable corp::collfrom
    label $w.tolbl -anchor w
    entry $w.toentr -width 4 -textvariable corp::collto
    pack [frame $w.frame.range] -side top -fill x
    pack $w.fromlbl $w.fromentr $w.tolbl $w.toentr \
	    -side left -in $w.frame.range -pady 5 -padx 3

    label $w.freqlbl -anchor w
    entry $w.freqentr -width 4 -textvariable corp::collminfreq
    pack [frame $w.frame.freq] -side top -fill x
    pack $w.freqlbl $w.freqentr -side left -in $w.frame.freq -pady 5 -padx 3

    label $w.bgrlbl -anchor w
    entry $w.bgrentr -width 4 -textvariable corp::collminbgr
    pack [frame $w.frame.bgr] -side top -fill x
    pack $w.bgrlbl $w.bgrentr -side left -in $w.frame.bgr -pady 5 -padx 3

    label $w.lineslbl -anchor w
    entry $w.linesentr -width 4 -textvariable corp::collmaxlines
    pack [frame $w.frame.lines] -side top -fill x
    pack $w.lineslbl $w.linesentr -side left -in $w.frame.lines -pady 5 -padx 3

    radiobutton $w.sortabs -variable corp::collsort -value abs
    radiobutton $w.sortrel -variable corp::collsort -value rel
    pack [frame $w.frame.sort] -side top -fill x
    pack [label $w.sortlbl] $w.sortabs $w.sortrel \
	    -side left -in $w.frame.sort -pady 5 -padx 3
}


proc tabbedtext {w headline} {
    frame $w
    scrollbar $w.yscroll -command "$w.table yview" -takefocus 0
    text $w.table -yscroll "$w.yscroll set"
    pack $w.yscroll -side right -fill y
    pack $w.table -side left -fill both -expand yes
    set w $w.table

    regsub -all n [$w cget -tabs] c headtabs
    $w tag configure head -tabs $headtabs -foreground blue -underline 1
    $w insert end [join $headline "\t"] head "\n"
    $w tag bind head <3> "set corp::collres_x %x"
    $w tag bind head <B3-Motion> "tabbedtext-move $w %x"
    if {$headline != ""} {
	$w tag bind head <1> "tabbedtext-sort $w @%x,%y"
    }

    wm resizable [winfo toplevel $w] 1 1
    return $w
}


proc tabbedtext-move {w x} {
    set dx [expr $x - $corp::collres_x]
    set xlimit [expr $corp::collres_x - 20]
    set corp::collres_x $x
    set tabs {}
    set last -10
    foreach t [$w cget -tabs] {
	if {[string match {[0-9]*} $t] && $t >= $xlimit} {
	    incr t $dx
	    if {$t < $last +10} {
		set t [expr $last +10]
	    }
	    set last $t
	}
	lappend tabs $t
    }
    $w configure -tabs $tabs
    regsub -all n $tabs c headtabs
    $w tag configure head -tabs $headtabs
}

proc tabbedtext-sort {w index} {
    set idx [llength [split [$w get 1.0 $index] "\t"]]
    incr idx -1
    set data {}
    foreach line [split [$w get 2.0 end] "\n"] {
	if {$line == ""} break
	lappend data [split $line "\t"]
    }
    if [catch {set data [lsort -index $idx -decreasing -real $data]}] {
	set data [lsort -index $idx -dictionary $data]
    }
    $w configure -state normal
    $w delete 2.0 end
    $w insert end "\n"
    foreach line $data {
	$w insert end [join $line "\t"] {} "\n"
    }
    $w configure -state disabled
}

proc tabbedtext-save {w} {
    set fname [tk_getSaveFile -parent [winfo toplevel $w]]
    if {$fname == ""} return
    set f [open $fname "w"]
    puts $f [$w get 1.0 {end -1 line}]
    close $f
}


proc finishcolloc {w} {
    destroy $w

    updateStatus colloc
    set res [comm:evalcommand [list findcoll query \
	    $corp::collattr $corp::collsort \
	    $corp::collminfreq $corp::collminbgr \
	    $corp::collfrom $corp::collto $corp::collmaxlines]]
    updateStatus result

    set w .collres
    makeDialogWindow $w {close}
    grab release $w

    set t [tabbedtext $w.frame.res \
	    [concat [list $corp::collattr] [getOption headline $w]]]

    pack [button $w.save -command "tabbedtext-save $t"] \
	    -in $w.buttons -side left -padx 15

    #foreach line [split $res "\n"] {
    #	 $t insert end [join $line "\t"] {} "\n"
    #}
    $t insert end $res

    pack $w.frame.res -expand yes -fill both
    $t configure -state disabled
    bind $t <3> {collPNfilter %W %x %y %X %Y}
}

proc collPNfilter {w x y rootx rooty} {
    set idx [$w index @$x,$y]
    set line [$w index "$idx linestart"]
    set tabidx [$w search "\t" $line "$line lineend"]
    set corp::collselword [$w get $line $tabidx]
    if {$tabidx != "" && [$w compare $tabidx > $idx]} {
	set corp::collword [$w get $line $tabidx]
	set pfstr [getOption pfil .queryfr.select]
	set nfstr [getOption nfil .queryfr.select]
	set m $w.menu
	catch {destroy $m}
	menu $m -tearoff 0
	$m add command -label "$pfstr: $corp::collword" \
	    -command {collRunPNfilter pfil}
	$m add command -label "$nfstr: $corp::collword" \
	    -command {collRunPNfilter nfil}
	tk_popup $m $rootx $rooty
    }
}

proc collRunPNfilter {type} {
    set corp::query "\[$corp::collattr=\"$corp::collword\"]"
    set corp::qrlabel ""
    set corp::qtype $type
    set corp::coll(left,unit) tokens
    set corp::coll(right,unit) tokens
    set corp::coll(left,count) $corp::collfrom
    set corp::coll(right,count) $corp::collto
    if {$corp::collfrom < 0} {
	set corp::coll(left,from) <0
    } else {
	set corp::coll(left,from) >0
    }
    if {$corp::collto < 0} {
	set corp::coll(right,from) <0
    } else {
	set corp::coll(right,from) >0
    }
    processQuery
}

proc distribWindow {} {
    set w .distrib
    makeDialogWindow $w close
    grab release $w
    frame $w.ffr
    frame $w.rffr
    pack [label $w.freq] [label $w.fval -text $corp::resultlen] \
	    -in $w.ffr -side left
    label $w.rfval -text [comm:evalcommand "arf query"]
    pack [label $w.rfreq] $w.rfval -in $w.rffr -side left

    set c [canvas $w.can]
    pack $w.ffr $w.rffr $c -in $w.frame -side top
    set width [$c cget -width]
    set height [$c cget -height]
    incr width -45
    incr height -60
    set x 1
    set res [comm:evalcommand "distrib query [expr $width -1] $height 1"]

    catch {unset corp::distrib}
    array set corp::distrib {}
    foreach {y linenum} [lrange $res 1 end] {
	if {$y > 0} {
	    set id [$c create line $x 1 $x -$y -fill blue -tags bar]
	    set corp::distrib($id) [incr linenum]
	}
	incr x
    }
    set maxy [lindex $res 0]
    $c create text -6 -$height -text $maxy -anchor e
    $c create line -4 -$height $width -$height $width 0 0 0 0 -$height
    set half [expr $maxy / 2]
    set hy [expr double($half) / $maxy * $height]
    $c create text -6 -$hy -text $half -anchor e
    $c create line -4 -$hy 0 -$hy
    $c create text 0 [expr -$height -10] -text [getOption ylbl $w] \
	    -width [getOption ywidth $w] -anchor s
    $c create text [expr $width /2] 3 -text [getOption xlbl $w] \
	    -width [getOption xwidth $w] -anchor n
    foreach {x1 y1 x2 y2} [$c bbox all] break
    incr x1 -5
    incr x2 5
    incr y1 -5
    incr y2 5
    $c config -width [expr $x2 -$x1] -height [expr $y2 -$y1] \
	    -scrollregion [list $x1 $y1 $x2 $y2]

    $c bind bar <Any-Enter> "distribBarEnter $c"
    $c bind bar <Any-Leave> "distribBarLeave $c"
    $c bind bar <1> "distribBarButton $c"
}

proc distribBarEnter {c} {
    set id [$c find withtag current]
    $c itemconfig current -fill red
}

proc distribBarLeave {c} {
    set id [$c find withtag current]
    $c itemconfig current -fill blue
}

proc distribBarButton {c} {
    set id [$c find withtag current]
    set corp::jumpline $corp::distrib($id)
    finishjump
    #XXX (after idle??) showFullref
}
