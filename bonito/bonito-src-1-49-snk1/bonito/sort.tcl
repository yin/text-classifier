#  bonito:
# 	$Id: sort.tcl,v 1.16 2002/12/17 14:38:03 pary Exp $	
#
#  Copyright (c) 2000-2002  Pavel Rychly

package provide sort 1.0
package require widlist 1.0
package require attrib 1.0

proc sipmlesortWindow {} {
    set w .simplesort
    makeDialogWindow $w [list ok "finishsimplesort $w"]

    label $w.poslbl
    entry $w.positions -textvar corp::ssrtpos -width 3
    pack [frame $w.frame.posfrm] -side top -fill x
    pack $w.poslbl $w.positions \
	    -side left -in $w.frame.posfrm -pady 10 -padx 3

    label $w.sortlbl -anchor w
    pack [frame $w.frame.fromto] -side top -fill x
    pack $w.sortlbl -side left -in $w.frame.fromto -anchor n
    foreach wb {beforebeg afterbeg beforeend afterend} {
	radiobutton $w.$wb -variable corp::ssrtfrom -value $wb
	pack $w.$wb -in $w.frame.fromto -anchor w
    }

    checkbutton $w.ignorecase -variable corp::ssrticase
    checkbutton $w.retrograde -variable corp::ssrtrtrg
    pack [frame $w.frame.options1] -side top -fill x
    pack $w.ignorecase $w.retrograde \
	    -side left -in $w.frame.options1 -pady 10 -padx 3

    
    label $w.attrlbl
    makeMenuButon $w.attrib corp::ssrtattr [comm:listatrib]
    pack [frame $w.frame.options2] -side top -fill x
    pack $w.attrlbl $w.attrib \
	    -side left -in $w.frame.options2 -pady 10 -padx 3
}

proc finishsimplesort {w} {
    destroy $w
    set format $corp::ssrtattr
    if {$corp::ssrtrtrg || $corp::ssrticase } {
	append format /
    }
    if $corp::ssrtrtrg {
	append format r
    }
    if $corp::ssrticase {
	append format i
    }
    set n $corp::ssrtpos
    switch -glob -- $corp::ssrtfrom {
	beforebeg {append format " -1<0~-$n<0"}
	afterbeg  {append format " 0<0~[expr $n -1]<0"}
	beforeend {append format " 0>0~[expr 1- $n]>0"}
	afterend  {append format " 1>0~$n>0"}
    }

    updateStatus sort
    store_conc
    set corp::sellines {}
    comm:evalcommand "sort query 0 $format"
    refreshResult start
}


#-------------------- pomocny funkce --------------------

proc getposunitlist {{basic_units tokens}} {
    set units [getOptionList .genstring $basic_units]
    foreach tag [comm:listtags] {
	lappend units [list "<$tag>" $tag]
    }
    return $units
}

proc getposfromlist {maxcol} {
    set kwicstr [getOption kwic .genstring]
    set fromlist [list [list "< $kwicstr  " <0] \
	               [list "  $kwicstr >" >0]]

    set collstr [getOption ncolloc .genstring]
    for {set i 1} {$i <= $maxcol} {incr i} {
	lappend fromlist [list [format "< $collstr  " $i] <$i]
	lappend fromlist [list [format "  $collstr >" $i] >$i]
    }
    return $fromlist
}

proc makeposframe {w varname idx} {
    upvar \#0 $varname var
    # inicializace promennych
    if ![info exists var($idx,unit)] {
	set var($idx,unit) tokens
	set var($idx,count) 0
	if [string match *left* $idx] {
	    set var($idx,from) <0
	} else {
	    set var($idx,from) >0
	}
    }
    # okynka
    frame $w
    entry $w.count -textvar ${varname}($idx,count) -width 3
    #makeMenuButon $w.unit ${varname}($idx,unit) [getposunitlist]
    makeMenuButon $w.from ${varname}($idx,from) [getposfromlist $corp::maxcoll]
    pack [label $w.lbl] $w.count [label $w.fromlbl] $w.from -side left
    return $w
}

proc makerangeedgeframe {w varname idx} {
    upvar \#0 $varname var
    # inicializace promennych
    if ![info exists var($idx,unit)] {
	set var($idx,unit) tokens
	set var($idx,count) 0
	if [string match *left* $idx] {
	    set var($idx,from) <0
	} else {
	    set var($idx,from) >0
	}
    }
    # okynka
    frame $w
    entry $w.count -textvar ${varname}($idx,count) -width 3
    makeMenuButon $w.unit ${varname}($idx,unit) [getposunitlist]
    makeMenuButon $w.from ${varname}($idx,from) [getposfromlist $corp::maxcoll]
    pack [label $w.lbl] $w.count $w.unit \
	    [label $w.fromlbl] $w.from -side left
    return $w
}

proc makesortoptframe {w varname idx} {
    frame $w
    #XXX
    makeMenuButon $w.attr ${varname}($idx,attr) [concat [comm:listatrib] [comm:liststrattr]]
    #makeMenuButon $w.attr ${varname}($idx,attr) [comm:listatrib]
    checkbutton $w.icase -variable ${varname}($idx,icase)
    checkbutton $w.rtgr -variable ${varname}($idx,rtrg)
    
    pack $w.attr $w.icase $w.rtgr -side left
    return $w
}

proc composePos {varname idx} {
    upvar \#0 $varname var
    set pos $var($idx,count)
    switch -exact -- $var($idx,unit) {
	chars {
	    append pos "#"
	}
	tokens {}
	default {
	    append pos ":$var($idx,unit)"
	}
    }
    append pos "$var($idx,from)"
    return $pos
}
    

#-------------------- generic --------------------

proc gensortWindow {} {
    set w .gensort
    widlistInit $w gensort
    checkbutton $w.uniq -variable corp::gsrtuniq
    pack $w.uniq -in $w.globalopt
}

proc gensort-add {w var n} {
    pack [makesortoptframe $w.opt $var $n,opt] \
	    [makeposframe $w.left $var $n,left] \
	    -side top -padx 20 -pady 2
    #[makeposframe $w.right $var $n,right] \

}

proc gensort-eval {w ranges varname} {
    upvar \#0 $varname var
    destroy $w
    set criteria ""
    foreach n $ranges {
	# sort options
	append criteria $var($n,opt,attr)/
	if $var($n,opt,rtrg) { append criteria r }
	if $var($n,opt,icase) { append criteria i }
	# sort poses
	set pos [composePos $varname $n,left]
	append criteria " $pos "
    }
    updateStatus sort
    store_conc
    set corp::sellines {}
    comm:evalcommand "sort query $corp::gsrtuniq $criteria"
    refreshResult start
}

#-------------------- count --------------------

proc countsortWindow {} {
    set w .countsort
    if {![info exists corp::csctx]} {
	array set corp::csctx [array get corp::ctx]
    }
    makeDialogWindow $w [list ok "finishcountsort $w" close]

    label $w.attrlbl -anchor w
    makeMenuButon $w.attrib corp::csrtattr [comm:listatrib]


    grid $w.attrlbl $w.attrib -sticky w -in $w.frame
    grid [label $w.ctxlbl -anchor w] [frame $w.ctx] -sticky w -in $w.frame
    contextWindow $w.ctx - corp::csctx
}

proc finishcountsort {w} {
    destroy $w
    set ctxleft [composeContext $corp::csctx(left) $corp::csctx(lunit)]
    set ctxright [composeContext $corp::csctx(right) $corp::csctx(runit)]
    updateStatus sort
    store_conc
    set corp::sellines {}
    comm:evalcommand "countsort query $corp::csrtattr 1 -$ctxleft $ctxright"
    refreshResult start
}

#-------------------- group --------------------

proc linegroupsort {} {
    updateStatus sort
    store_conc
    set corp::sellines {}
    comm:evalcommand "sort query 0 ^ 0"
    refreshResult start
}
