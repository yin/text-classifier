#  bonito:
# 	$Id: attrib.tcl,v 1.26 2003/12/08 09:47:17 pary Exp $	
#
#  Copyright (c) 2000-2003 Pavel Rychly

package provide attrib 1.0

proc makeDialogWindow {w {buttlist ok} {parentwin .}} {
    if [winfo exists $w] {
	destroy $w
    }
    toplevel $w
    wm withdraw $w
    wm title $w [getOption title $w]
    wm transient $w $parentwin

    if {[info exists corp::wingeometry($w)]} {
	wm geometry $w $corp::wingeometry($w)
    } else {
	scan [wm geometry [winfo parent $w]] \
	    "%dx%d+%d+%d" geom_h geom_w geom_x geom_y
	wm geometry $w +[expr $geom_x+50]+[expr $geom_y+50]
    }
    wm resizable $w 0 0
    grab set $w

    pack [label $w.label] -side top -padx 5 -pady 5
    pack [frame $w.buttons] -side bottom -padx 10 -pady 5
    pack [frame $w.frame -bd 2 -relief groove] \
	    -side top -padx 10 -pady 5 -expand yes -fill both
    set buttidlist {}
    foreach {buttid buttcom} $buttlist {
	lappend buttidlist $w.$buttid
	switch -exact $buttid {
	    ok {
		if {$buttcom == ""} {
		    set buttcom "destroy $w; refreshResult"
		}
		button $w.ok -command $buttcom
		bind $w <Return> "$w.ok flash; $w.ok invoke"
	    }
	    close {
		if {$buttcom == ""} {
		    set buttcom "destroy $w"
		}
		button $w.close -command $buttcom
		bind $w <Escape> "$w.close flash; $w.close invoke"
	    }
	    default {
		button $w.$buttid -command $buttcom
	    }
	}
    }
    eval pack $buttidlist -side left -in $w.buttons -padx 15
    wm deiconify $w
    focus $w
}

proc saveGeometry {w} {
    set geo [wm geometry $w]
    if {[wm resizable $w] != "1 1"} {
	set geo [string range $geo [string first + $geo] end]
    }
    set corp::wingeometry($w) $geo
}

bind Toplevel <Destroy> {saveGeometry %W}

proc attribWindow {} {
    set w .attrwin
    set attrs [comm:listatrib]
    if {[llength $attrs] == 1} {
	tk_messageBox -message [getOption noattrib $w] -type ok \
		-title [getOption title $w]
	return
    }
    
    makeDialogWindow $w

    set i [lsearch -exact $attrs word]
    foreach a [lreplace $attrs $i $i] {
	pack [checkbuttonList [genUniqName $w at$a] corp::attribs $a \
		-text $a] -anchor w -in $w.frame -padx 10
    }
    pack [radiobutton $w.forall -variable corp::showattrs -value 1] \
	    [radiobutton $w.kwiconly -variable corp::showattrs -value 0] \
	    -anchor w -in $w.frame -padx 10
}

proc tagWindow {} {
    set w .tagwin

    #set alltags [comm:listtags]
    set alltags [concat [comm:listtags] [comm:liststrattr]]
    if {[llength $alltags] <= 15} {
	makeDialogWindow $w
	foreach a $alltags {
	    pack [checkbuttonList [genUniqName $w at$a] corp::tags $a -text $a] \
		    -anchor w -in $w.frame -padx 10
	}
    } else {
	makeDialogWindow $w [list ok "finishtag $w"]
	scrollbar $w.yscroll -command "$w.l yview" -takefocus 0
	listbox $w.l -height 15 -exportselection no -selectmode multiple \
		-yscroll "$w.yscroll set"
	foreach a $alltags {
	    $w.l insert end $a
	}
	foreach a $corp::tags {
	    $w.l selection set [lsearch -exact $alltags $a]
	}
	pack $w.l $w.yscroll -in $w.frame -side left -expand yes -fill y
    }
}

proc finishtag {w} {
    set corp::tags {}
    foreach a [$w.l curselection] {
	lappend corp::tags [$w.l get $a]
    }
    destroy $w
    refreshResult
}

proc refWindow {} {
    set w .refwin

    set alltags [concat [comm:listtags] [comm:liststrattr]]
    if {[llength $alltags] <= 15} {
	makeDialogWindow $w
	pack [checkbuttonList $w.positions corp::refs \#] \
		-anchor w -in $w.frame -padx 10
	foreach a $alltags {
	    pack [checkbuttonList [genUniqName $w at$a] corp::refs $a -text $a] \
		    -anchor w -in $w.frame -padx 10
	}
    } else {
	makeDialogWindow $w [list ok "finishref $w"]
	scrollbar $w.yscroll -command "$w.l yview" -takefocus 0
	listbox $w.l -height 15 -exportselection no -selectmode multiple \
		-yscroll "$w.yscroll set"
	foreach a $alltags {
	    $w.l insert end $a
	}
	foreach a $corp::refs {
	    $w.l selection set [lsearch -exact $alltags $a]
	}
	$w.l insert 0 [getOption text $w.positions]
	if {[lsearch -exact $corp::refs \#] >= 0} {
	    $w.l selection set 0
	}
	pack $w.l $w.yscroll -in $w.frame -side left -expand yes -fill y
    }
}

proc finishref {w} {
    set corp::refs {}
    if [$w.l selection includes 0] {
	set corp::refs \#
    }
    $w.l delete 0
    foreach a [$w.l curselection] {
	lappend corp::refs [$w.l get $a]
    }
    destroy $w
    refreshResult
}

proc contextWindow {{w .ctxwin} {parentwin .} {ctxvar corp::ctx}} {
    set wf $w.frame
    if {$parentwin == "."} {
	makeDialogWindow $w
    } elseif {$parentwin != "-"} {
	makeDialogWindow $w [list ok "destroy $w"] $parentwin
    } else {
	set wf $w
    }
    label $w.leftlbl -anchor w
    entry $w.leftval -textvar ${ctxvar}(left) -width 3

    set ctxunits [getOptionList .genstring {chars tokens}]
    foreach tag [comm:listtags] {
	lappend ctxunits [list "<$tag>" :$tag]
    }

    makeMenuButon $w.leftunit ${ctxvar}(lunit) $ctxunits
    pack $w.leftlbl $w.leftval $w.leftunit -side left \
	    -in $wf -pady 10 -padx 3
    bind $w.leftval <FocusOut> "set ${ctxvar}(right) \$${ctxvar}(left)"
    #bind $w.leftunit.menu <Leave> "set ${ctxvar}(runit) \$${ctxvar}(lunit)"
    

    label $w.rightlbl -anchor w
    entry $w.rightval -textvar ${ctxvar}(right) -width 3
    makeMenuButon $w.rightunit ${ctxvar}(runit) $ctxunits
    pack $w.rightlbl $w.rightval $w.rightunit -side left \
	    -in $wf -pady 10 -padx 3

}

    
proc rangeWindow {} {
    set w .rngwin
    makeDialogWindow $w [list ok "destroy $w; refreshResult start"]

    set rng ""
    foreach r {first center last random} {
	lappend rng [list [getOption $r $w] $r]
    }
    makeMenuButon $w.from corp::rngfrom $rng
    entry $w.count -textvar corp::rngcount -width 5
    pack $w.from $w.count -side left -in $w.frame -pady 10 -padx 3
}

proc jumpWindow {} {
    set w .jumpwin
    makeDialogWindow $w [list ok "destroy $w; finishjump"]

    set corp::jumpline [expr $corp::displayedfrom + int([.list index curr])]
    entry $w.line -textvar corp::jumpline -width 8
    pack [label $w.linelbl] $w.line -side left -in $w.frame -pady 10 -padx 3
}

proc finishjump {} {
    if {$corp::jumpline > $corp::displayedfrom && \
	    $corp::jumpline <= $corp::displayedto} {
	tlist:moveline .list 0.0 \
		+[expr $corp::jumpline - $corp::displayedfrom -1]
    } else {
	refreshResult jump
    }
}

proc reduceWindow {} {
    set w .reduce
    makeDialogWindow $w [list ok "finishreduce $w"]

    set from {}
    foreach r {first center last random} {
	lappend from [list [getOption $r $w] $r]
    }
    label $w.reducelbl
    makeMenuButon $w.from corp::reducefrom $from
    entry $w.count -textvar corp::reducecount -width 7
    makeMenuButon $w.unit corp::reduceunit \
	    [list [list [getOption lines $w] lines] \
	          [list [getOption percent $w] percent] \
	          [list [getOption 100percent $w] 100percent]]
    pack $w.reducelbl $w.from $w.count $w.unit \
	    -side left -in $w.frame -pady 10 -padx 3
}

proc finishreduce {w} {
    destroy $w
    
    if {$corp::reducefrom == "random"} {
	set command "reduce query $corp::reducecount"
	if {$corp::reduceunit == "percent"} {
	    append command %
	} elseif {$corp::reduceunit == "100percent"} {
	    append command %%
	}
    } else {
	set size $corp::resultlen
	if {$corp::reduceunit == "percent"} {
	    set res [expr int($corp::reducecount * $size /100.0)]
	} elseif {$corp::reduceunit == "100percent"} {
	    set res [expr int($corp::reducecount * $size /10000.0)]
	} else {
	    set res $corp::reducecount
	}
	
	switch -exact -- $corp::reducefrom {
	    first  {set range "$res $size"}
	    last   {set range "0 [expr $size - $res]"}
	    center {set range "0 [expr int(($size - $res)/2)] [expr int(($size + $res)/2)] $size"
	    }
	}
	set command "del query $range"
    }
    updateStatus reduce
    store_conc
    lappend corp::resultsteps reduce [list 0 0 \
                   "$corp::reducefrom $corp::reducecount $corp::reduceunit"]
    set corp::sellines {}
    comm:evalcommand $command
    refreshResult modify
    concinfo_detail
}


proc deleteSelected {} {
    if {$corp::sellines != {}} {
	makeDialogWindow .delselect [list ok finishDelete close]
    }
}

proc finishDelete {} {
    destroy .delselect
    updateStatus delete
    store_conc
    lappend corp::resultsteps del [list 0 0 [ranges:sum $corp::sellines]]
    comm:evalcommand "del query $corp::sellines"
    set corp::sellines {}
    refreshResult modify
    concinfo_detail
} 


proc miscoreWindow {} {
    set w .miscore
    makeDialogWindow $w [list ok computeMIscore close]

    label $w.attr1lbl -anchor w
    makeMenuButon $w.attrib1 corp::miscoreattr1 [comm:listatrib]
    label $w.val1lbl -anchor w
    entry $w.val1entr -width 20 -textvariable corp::statsword1
    pack [frame $w.frame.input1] -side top -fill x
    pack $w.attr1lbl $w.attrib1 $w.val1lbl $w.val1entr \
	    -side left -in $w.frame.input1 -pady 10 -padx 3

    label $w.attr2lbl -anchor w
    makeMenuButon $w.attrib2 corp::miscoreattr2 [comm:listatrib]
    label $w.val2lbl -anchor w
    entry $w.val2entr -width 20 -textvariable corp::statsword2
    pack [frame $w.frame.input2] -side top -fill x
    pack $w.attr2lbl $w.attrib2 $w.val2lbl $w.val2entr \
	    -side left -in $w.frame.input2 -pady 10 -padx 3

    label $w.fromlbl -anchor w
    entry $w.fromentr -width 4 -textvariable corp::collfrom
    label $w.tolbl -anchor w
    entry $w.toentr -width 4 -textvariable corp::collto
    pack [frame $w.frame.range] -side top -fill x
    pack $w.fromlbl $w.fromentr $w.tolbl $w.toentr \
	    -side left -in $w.frame.range -pady 5 -padx 3

    pack [checkbutton $w.asregexp -variable corp::collregexp] -side top \
	    -in $w.frame

    pack [label $w.result -textvariable corp::miscoreresult] \
	    -side top -in $w.frame
}

proc computeMIscore {} {
    set size [comm:evalcommand "corpsize $corp::name"]
    set freq1 [comm:corpfreq $corp::miscoreattr1 $corp::statsword1 \
	    $corp::collregexp]
    set freq2 [comm:corpfreq $corp::miscoreattr2 $corp::statsword2 \
	    $corp::collregexp]

    set corp::miscoreresult "f($corp::statsword1) = $freq1\n"
    if {$corp::statsword2 == ""} return
    append corp::miscoreresult "f($corp::statsword2) = $freq2\n"
    if {$freq1 == 0 || $freq2 == 0} return
    set freq1 $freq1.0
    set freq2 $freq2.0
    updateStatus bigrams
    set freq12 [comm:corpbigram $corp::miscoreattr1 $corp::statsword1 \
	    $corp::miscoreattr2 $corp::statsword2 \
	    $corp::collfrom $corp::collto $corp::collregexp]
    updateStatus result
    append corp::miscoreresult \
	    "f($corp::statsword1,$corp::statsword2) = $freq12\n"
    set freq12 $freq12.0
    if {$freq12 != 0} {
	set miscore [expr log($size * ($freq12 / $freq2) / $freq1 ) / log(2)]
	set tscore [expr ($freq12 - $freq1 * $freq2 / $size) / sqrt ($freq12)]
	append corp::miscoreresult [format "MI = %.3f\n" $miscore]
	append corp::miscoreresult [format "T = %.3f\n" $tscore]
	#set kor [expr ($freq12 - $freq1 * $freq2 / $size) / \
		#sqrt ($freq1 * $freq2)]
	#append corp::miscoreresult [format "korelace = %.5f" $kor]
    }
}

