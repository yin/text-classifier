#  bonito:
# 	$Id: result.tcl,v 1.10 2003/12/08 10:06:08 pary Exp $	
#
#  Copyright (c) 2000-2003  Pavel Rychly

package provide result 1.0


proc waitForResult {} {
    set corp::pending [string trim [comm:evalcommand "pend query"]]
    if {$corp::pending == 0 || $corp::pending == ""} {
	return
    }
    after 100 waitForResult_every
    anim:start waitForResult_every
    if $corp::animation {
	#puts wait-stop
	tkwait variable corp::pending
	#puts wait-jedu
    }
}

proc waitForResult_every {} {
    set pend [comm:evalcommand "pend query"]
    if {$pend == 0 || [string trim $pend] == ""} {
	anim:stop
	set corp::pending 0
    } else {
	after 100 waitForResult_every
    }
}

proc waitForQueryResult {} {
    #$corp::rngcount $corp::rngfrom
    set pend [comm:evalcommand "pend query"]
    set len [lindex [comm:evalcommand "len query"] 0]
    if {$corp::rngcount <= $len || $pend == 0 || $pend == ""} {
	return
    } else {
	set corp::pending 1
    }
    after 100 waitForQueryResult_every
    anim:start waitForQueryResult_every
    if $corp::animation {
	tkwait variable corp::pending
    }
}

proc waitForQueryResult_every {} {
    set pend [comm:evalcommand "pend query"]
    set len [lindex [comm:evalcommand "len query"] 0]
    if {$corp::rngcount <= $len || $pend == 0 || $pend == ""} {
	anim:stop
	set corp::pending 0
    } else {
	after 100 waitForQueryResult_every
    }
}

proc trace_resultlen args {
    if {$corp::servreading} return
    foreach {curr final} [comm:evalcommand "len query"] break
    if {$final != "UNKNOWN"} {
	set corp::resultlen $final
	trace vdelete corp::resultlen r trace_resultlen
	if {$corp::pendcommad} {
	    set corp::pendcommad [comm:evalcommand "pend query"]
	    after idle refreshResult
	}
	concinfo_detail
    } else {
	set corp::resultlen $curr
    }
}

namespace eval corp {
    variable prevdispfrom ""
    variable prevdispto ""
}

proc refreshResult {{viewtype sub}} {
    if {[llength $corp::resultsteps] == 0} {
	return
    }
    
    if {$viewtype != "start"} {
	set corp::prevdispfrom $corp::displayedfrom
	set corp::prevdispto $corp::displayedto
    }
    listview_clear
    if {$viewtype == "modify"} {
	set corp::pendcommad [comm:evalcommand "pend query"]
    }
    if 1 {
	#set viewtype sub
	waitForQueryResult
	set len [comm:evalcommand "len query"]
	if {[lindex $len 1] != "UNKNOWN"} {
	    set corp::resultlen [lindex $len 1]
	    set corp::querytyperesult 0
	    updateStatus result
	} else {
	    set corp::resultlen [lindex $len 0]
	    set corp::querytyperesult 1
	    updateStatus subresult
	}
    } else {
	waitForResult
	set corp::resultlen [lindex [comm:evalcommand "len query"] 1]
	set corp::querytyperesult 0
	updateStatus result
    }
    set corp::query_error [string trim [comm:evalcommand "err query"] \"]
    if {$corp::query_error != ""} {
	tk_messageBox -title [getOption queryerror .status] \
		-message [subst -nocommands -novariables $corp::query_error] \
		-type ok -icon error
		
    }
    if {$corp::resultlen != "UNKNOWN"} {
	#puts "refreshResult resultlen: >>$corp::resultlen<<"
	set corp::displayedfrom [initOutput listview $viewtype]
	set corp::displayedto $corp::displayedfrom
    }
}

proc initOutput {target range {context ""}} {
    if {$corp::servreading} return
    ${target}_init
    #puts init
    set range [composeRange $range]
    if {$context == ""} {
	set ctxleft [composeContext $corp::ctx(left) $corp::ctx(lunit)]
	set ctxright [composeContext $corp::ctx(right) $corp::ctx(runit)]
	set context "-$ctxleft $ctxright"
    }
    set attrs {word}
    foreach a [comm:listatrib] {
	if {$a != "word" && [lsearch $corp::attribs $a] >= 0} {
	    lappend attrs $a
	}
    }
    set attrs [join $attrs ,]
    if $corp::showattrs {
	set ctxattrs $attrs
    } else {
	set ctxattrs word
    }
    
    set coll {}
    for {set i 0} {$i <= $corp::maxcoll} {incr i} {
	lappend coll $i
    }

    #if {! $corp::querytyperesult} {
	#comm:evalcommand "sync $corp::servercolname"
    #}
    #puts "get $corp::servercolname $range $context"
    if [llength $corp::tags] {
	set structs [join $corp::tags ,]
    } else {
	set structs -
    }
    
    comm:startcommand "get $corp::servercolname $range $context \
	    $ctxattrs $attrs $structs [join $corp::refs ,]"

    #fileevent $corp::sock readable "outputLines $target"
    after idle outputLines $target
    anim:start xx
    #puts "initOutput range: >>$range<<"
    return [lindex $range 0]
}



proc outputLines {target} {
    set linenum 0
    initarrays words attribs structs
    while {[set line [comm:getline]] != ""} {
	#puts ">>$line<<"
	foreach {structval left kwic right} [split $line "\t"] break

	#set tags word
	set tags {}
	set part struct
	if {$structval != ""} {
	    ${target}_add $structval struct struct
	}
	${target}_add $left pre struct
	${target}_add $kwic in pre
	${target}_add $right post in
	${target}_done_line
	if {[incr linenum] >= $opt::batchlines} break
    }
    if $linenum {
	${target}_done_part
    }
    if $corp::linesend {
	#fileevent $corp::sock readable {}
	anim:stop
	${target}_done_all
	if {$corp::querytyperesult} {
	    if {[trace vinfo corp::resultlen] == ""} {
		trace variable corp::resultlen r trace_resultlen
	    }
	    set corp::querytyperesult 0
	    updateStatus result
	}
    } else {
	#after 100 after idle outputLines $target
	update
	#idletasks
	after idle outputLines $target
    }
}

proc outputLines_org {target} {
    set linenum 0
    initarrays words attribs structs
    while {[set line [comm:getline]] != ""} {
	#puts ">>$line<<"
	set intervals {}
	foreach {col dbeg dend} [lindex $line 0] {
	    if !$col {
		set concbeg $dbeg
		set concend [expr $dend +1]
	    }
	    lappend intervals [list $dbeg add $col]
	    lappend intervals [list [incr dend] del $col]
	}
	initarrays words attribs structs
	set from 0
	set to 0
	foreach attr [lindex $line 1] {
	    if {[lindex $attr 0] == "word"} {
		parseattrib $attr words
		set from [lindex $attr 1]
		set to [expr [llength $attr] + $from -2]
		lappend intervals $to
	    } else {
		parseattrib $attr attribs
	    }
	}
	set structval [parsestructs [lindex $line 2] structs 0]

	#set tags word
	set tags {}
	set part struct
	if {$structval != ""} {
	    ${target}_add [list $structval strc] struct struct
	}
	foreach bound [lsort -index 0 -integer $intervals] {
	    foreach {pos op col} $bound break
	    if {$pos >= $from} {
		set prevpart $part
		if {$pos <= $concbeg} {
		    set part pre
		} elseif {$pos <= $concend} {
		    set part in 
		} else {
		    set part post
		}
		${target}_add [combinearrwords $from $pos $tags] \
			$part $prevpart
		set from $pos
		#incr part
	    }
	    if {$pos == $to} break
	    if {$op == "add"} {
		lappend tags col$col coll
	    } elseif {$op == "del"} {
		set i [lsearch -exact $tags col$col]
		set tags [lreplace $tags $i [expr $i +1]]
	    }
	}
	${target}_done_line
	if {[incr linenum] >= $opt::batchlines} break
    }
    if $linenum {
	${target}_done_part
    }
    if $corp::linesend {
	#fileevent $corp::sock readable {}
	anim:stop
	${target}_done_all
	if {$corp::querytyperesult} {
	    if {[trace vinfo corp::resultlen] == ""} {
		trace variable corp::resultlen r trace_resultlen
	    }
	    set corp::querytyperesult 0
	    updateStatus result
	}
    } else {
	#after 100 after idle outputLines $target
	update
	#idletasks
	after idle outputLines $target
    }
}


proc composeContext {num unit} {
    switch -exact -- $unit {
	chars {
	    set unit "#"
	    if {$num == 0} {
		set num [expr int ([lindex [split [wm geometry .] x] 0] / 2)]
	    }
	}
	tokens {
	    set unit ""
	}
    }
    return "$num$unit"
}

proc composeRange {range} {
    if {[lindex $range 0] == "="} {
	return [lrange $range 1 end]
    }
    if [string match {@[0-9]*} $range] {
	set from [string trim $range @]
	set to [expr $from +1]
    } elseif {$range == "add_before"} {
	set from $corp::displayedfrom
	set to [expr $corp::displayedfrom - $opt::addlines]
	if {$to < 0} {
	    set to 0
	}
    } elseif {$range == "add_after"} {
	set from $corp::displayedto
	set to [expr $corp::displayedto + $opt::addlines]
    } elseif {$range == "whole" || $corp::rngcount == 0} {
	set corp::servercolname query
	set from 0
	set to $corp::resultlen
    } elseif {$range == "viewed"} {
	set from $corp::displayedfrom
	set to $corp::displayedto
    } elseif {$range == "jump"} {
	set from [expr $corp::jumpline -1]
	set to [expr $from + $corp::rngcount]
    } elseif {$range == "start"} {
	set corp::servercolname query
	switch -exact -- $corp::rngfrom {
	    first {
		set from 0
	    }
	    last {
		set from [expr $corp::resultlen - $corp::rngcount]
	    }
	    center {
		set from [expr int(($corp::resultlen - $corp::rngcount)/2)]
	    }
	    random {
		comm:evalcommand "clone query view"
		comm:evalcommand "reduce view $corp::rngcount"
		set corp::servercolname view
		set from 0
	    }
	}
	set to [expr $from + $corp::rngcount]
    } else {
	set from $corp::prevdispfrom
	set to $corp::prevdispto
    }
    if {$from < 0} {
	set from 0
    }
    return [list $from $to]
}


proc combinearrwords {from to tags} {
    upvar words words attribs attribs structs structs
    set out {}
    while {$from < $to} {
	if [info exists structs($from)] {
	    lappend out [join $structs($from) ""] strc
	} else {
	    lappend out " " {}
	}
	lappend out [lindex $words($from) 0] $tags
	if [info exists attribs($from)] {
	    lappend out "/[join $attribs($from) /]" attr
	}
	incr from
    }
    if {[lindex $out 0] == " "} {
	return [lrange $out 2 end]
    } else {
	return $out
    }
}


proc parsestructs {structlist posarray collpos} {
    upvar $posarray pos
    set structval ""
    foreach struct $structlist {
	set str [lindex $struct 0]
	foreach {a b val} [lrange $struct 1 end] {
	    if {$val != "" && $a <= $collpos && $collpos <= $b} {
		append structval "<$str $val>"
	    }
	    incr b
	    if $corp::showstrucvals {
		lappend pos($a) "<$str $val>"
	    } else {
		lappend pos($a) "<$str>"
	    }
	    append pos($b) ""
	    set pos($b) [linsert $pos($b) 0 "</$str>"]
	}
    }
    return $structval
}

proc parseattrib {attrib posarray} {
    upvar $posarray pos
    set idx [lindex $attrib 1]
    foreach a [lrange $attrib 2 end] {
	lappend pos($idx) $a
	incr idx
    }
}

