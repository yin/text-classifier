#  bonito:
#     $Id: graph.tcl,v 1.3 2003/04/23 17:50:02 pary Exp $
#
#  Copyright (c) 2000-2003  Pavel Rychly

package provide graph 1.0

package require attrib 1.0
package require menu 1.0


namespace eval ::graph {

    namespace export graphWindow
    
    variable padx 30 pady 10
    variable maxnum 0 numberedtree {}
    variable values
    array set values {}

    variable firstarg
    array set firstarg {
	seq 1
	opt 1
	rep 3
	alt 1
	att 3
	and 1
	or  1
	not 1
	any 1
    }
    variable numofargs
    array set numofargs {
	seq 100
	opt 1
	rep 1
	alt 100
	att 0
	and 100
	or  100
	not 1
	any 0
    }
}

proc ::graph::graphWindow {tree} {
    variable numberedtree
    variable maxnum
    variable values

    set w .graph
    makeDialogWindow $w [list add "::graph::Add $w.c" \
	    delete "::graph::Delete $w.c" \
	    ok "::graph::Eval $w" close]

    canvas $w.c -width 480 -height 300 -bd 2 -relief groove \
	-yscrollcommand "$w.yscroll set" -xscrollcommand "$w.xscroll set"
    pack [frame $w.globalopt] -side top -in $w.frame
    scrollbar $w.yscroll -command "$w.c yview" -takefocus 0
    scrollbar $w.xscroll -command "$w.c xview" -takefocus 0 -orient horizontal
    pack $w.xscroll -side bottom -fill x -in $w.frame
    pack $w.c $w.yscroll -side left -fill y -in $w.frame

    makeMenuButon $w.type ::graph::newtype [getOptionList $w.type \
	    {att any and or not opt rep alt seq}]
    pack [label $w.typelbl] $w.type -in $w.globalopt -side left

    catch {unset values}; array set values {}
    if {$tree != {}} {
	foreach {maxnum numberedtree} [numbertree 0 $tree] {}
	draw $w.c
    } else {
	set maxnum 0
	set numberedtree {}
    }
}

proc ::graph::map {command list} {
    set out {}
    foreach i $list {
	lappend out [eval $command [list $i]]
    }
    return $out
}

proc ::graph::graph2str_trim {item} {
    return "([string trim [graph2str $item] {[]}])"
}

proc ::graph::graph2str {graph} {
    switch -exact [lindex $graph 0] {
	seq {
	    set items [map graph2str [lrange $graph 1 end]]
	    if {[llength $items] > 1} {
		return "([join $items])"
	    } else {
		return [join $items]
	    }
	}
	opt {
	    return "[graph2str [lindex $graph 1]]?"
	}
	rep {
	    foreach {min max item} [lrange $graph 1 3] {}
	    set item [graph2str $item]
	    return "$item{$min,$max}"
	}
	alt {
	    set items [join [map graph2str [lrange $graph 1 end]] " | " ]
	    return "($items)"
	    #foreach {i1 i2} [map graph2str [lrange $graph 1 2]] {}
	    #return "($i1 | $i2)"
	}
	att {
	    foreach {attr val} [lrange $graph 1 2] {}
	    return "\[$attr=\"$val\"\]"
	}
	any {
	    return {[]}
	}
	and {
	    set items [join [map graph2str_trim [lrange $graph 1 end]] " & " ]
	    return "\[$items\]"
	}
	or {
	    set items [join [map graph2str_trim [lrange $graph 1 end]] " | " ]
	    return "\[$items\]"
	}
	not {
	    return "\[![graph2str_trim [lindex $graph 1]]\]"
	}
	default {
	    return -errorcode incorect_node ""
	}
    }
}


proc ::graph::numbertree {num tree} {
    variable firstarg
    variable values

    set type [lindex $tree 0]
    set out [list $num $type]

    set values($num,type) $type
    for {set i 1} {$i < $firstarg($type)} {incr i} {
	set values($num,arg$i) [lindex $tree $i]
    }

    set n [expr $num +1]
    foreach sub [lrange $tree $i end] {
	set values($n,up) $num
	foreach {n sub} [numbertree $n $sub] {}
	lappend out $sub
    }
    return [list $n $out]
}
    


proc ::graph::select {c w} {
    $c dtag all selected
    foreach i [$c find withtag window] {
	set wi [$c itemcget $i -window] 
	if {$wi == $w} {
	    $wi config -relief sunken
	    $c addtag selected withtag $i
	} else {
	    $wi config -relief raise
	}
    }
}

proc ::graph::Delete {c} {
    variable numberedtree
    variable can2id
    set id [$c find withtag selected]
    if {$id != ""} {
	set numberedtree [substsubtree $numberedtree $can2id($id) {}]
	draw $c
    }
}

proc ::graph::substsubtree {tree num repl} {
    if {$num == [lindex $tree 0]} {
	return $repl
    }
    set out [lrange $tree 0 1]
    foreach sub [lrange $tree 2 end] {
	set sub [substsubtree $sub $num $repl]
	if {$sub != {}} {
	    lappend out $sub
	}
    }
    return $out
}

proc ::graph::findsubtree {tree num} {
    if {$num == [lindex $tree 0]} {
	return $tree
    }
    set out [lrange $tree 0 1]
    foreach sub [lrange $tree 2 end] {
	set sub [findsubtree $sub $num]
	if {$sub != {}} {
	    return $sub
	}
    }
    return {}
}


proc ::graph::createitemwindow {c n type} {
    set w $c.w$n

    frame $w -relief sunken -bd 2
    pack [label $w.lbl -text [getOption $type .graph.type]] \
	    -side left -padx 20
    bindtags $w.lbl [concat [bindtags $w.lbl] $w]
    switch -exact $type {
	rep {
	    entry $w.min -width 2 -textvariable ::graph::values($n,arg1)
	    entry $w.max -width 2 -textvariable ::graph::values($n,arg2)
	    pack [label $w.minlbl] $w.min [label $w.maxlbl] $w.max \
		    -side left
	}
	att {
	    makeMenuButon $w.attr ::graph::values($n,arg1) [comm:listatrib]
	    pack [label $w.attrlbl] $w.attr -side left
	    entry $w.val -width 10 -textvariable ::graph::values($n,arg2)
	    pack [label $w.varlbl] $w.val -side left
	}
    }
    bind $w <Button-1> "::graph::select $c $w"
    bind $w <Button-3> "::graph::localmenu $c $n %X %Y"
}

proc ::graph::localmenu {c num x y} {
    set m $c.menu
    catch {destroy $m}
    foreach {lab com} [getOption localmenu .graph] {
	lappend com $c $num
	kdMakeMenu $m {} [list command $lab $com]
    }
    $m post $x $y
    grab -global $m
}

proc ::graph::cutoff {c num} {
    variable numberedtree
    variable values

    set numberedtree [findsubtree $numberedtree $num]
    catch {unset values($num,up)}
    draw $c
}

proc ::graph::remove {c num} {
    variable numberedtree
    variable values

    set sub [lindex [findsubtree $numberedtree $num] 2]
    if {$sub != {}} {
	set subnum [lindex $sub 0]
	if {[lindex $numberedtree 0] == $num} {
	    unset values($subnum,up)
	} else {
	    set values($subnum,up) $values($num,up)
	}
    }
    set numberedtree [substsubtree $numberedtree $num $sub]
    draw $c
}

proc ::graph::prepend {type c num} {
    variable numberedtree
    variable values
    variable maxnum

    set values($maxnum,type) $type
    if {[lindex $numberedtree 0] != $num} {
	set values($maxnum,up) $values($num,up)
    }
    set numberedtree [substsubtree $numberedtree $num \
	    [list $maxnum $type [findsubtree $numberedtree $num]]]
    set values($num,up) $maxnum
    incr maxnum
    draw $c
}

proc ::graph::draw {c} {
    variable numberedtree
    variable can2id
    # rusi localmenu
    catch {destroy $c.menu}
    set sel [$c find withtag selected]
    if {$sel != ""} {
	set sel $can2id($sel)
    }
    $c delete all
    if {$numberedtree != {}} {
	drawbranch $c $numberedtree 10 10 root 0
	foreach {x1 y1 x2 y2} [$c bbox all] {}
	set width  [expr $x2 > 450 ? $x2 + 10 : 460]
	set height [expr $y2 > 200 ? $y2 + 10 : 210]
	$c configure -scrollregion [list 0 0 $width $height]
	select $c $c.w$sel
    }
}

proc ::graph::drawbranch {c tree minx miny up nonroot} {
    variable padx
    variable pady
    variable can2id
    
    set num [lindex $tree 0]
    set win $c.w$num
    if ![winfo exists $win] {
	createitemwindow $c $num [lindex $tree 1]
    }
    update idle
    set t [$c create window $minx $miny -window $win -anchor nw \
	    -tags [concat $up "p[lindex $up end]" window]]
    set can2id($t) $num
    
    foreach {x1 y1 x2 y2} [$c bbox $t] {}
    if {$nonroot} {
	set y1 [expr ($y1 + $y2)/2]
	$c create line [expr $minx - $padx] $y1 [expr $minx -2] $y1 \
		-tags [concat $up line]
    }
    incr minx $padx
    set nextx [expr $minx + $padx]
    set nexty [expr $y2 + $pady]
    
    # nakreslime potomky
    lappend up n$t
    set lasty ""
    foreach l [lrange $tree 2 end] {
	foreach {nexty lasty} [drawbranch $c $l $nextx $nexty $up 1] {}
    }
    if {$lasty != ""} {
	$c create line $minx [incr y2 2] $minx $lasty \
		-tags [concat $up vertline]
    }
    return [list $nexty $y1]
}


proc ::graph::Add {c} {
    variable maxnum
    variable newtype
    variable numberedtree
    variable can2id
    variable values
    variable numofargs

    set values($maxnum,type) $newtype
    set newitem [list $maxnum $newtype]

    set t $numberedtree
    if {$t == {}} {
	set numberedtree $newitem
    } else {
	set id [$c find withtag selected]
	if {$id == ""} {
	    set n [lindex $t 0]
	} else {
	    set n $can2id($id)
	}
	set sub [findsubtree $t $n]
	if {$numofargs($values($n,type)) > [llength $sub] -2} {
	    set values($maxnum,up) $n
	    lappend sub $newitem
	    set numberedtree [substsubtree $t $n $sub]
	} else {
	    if {[lindex $t 0] == $n} {
		set values($maxnum,up) [expr $maxnum +1]
		incr maxnum
		set values($n,up) $maxnum
		set values($maxnum,type) seq
		set numberedtree [list $maxnum seq $t $newitem]
	    } else {
		set upn $values($n,up)
		set upsub [findsubtree $t $upn]
		if {$numofargs($values($upn,type)) > 1} {
		    set values($maxnum,up) $upn
		    set i [lsearch -exact $upsub $sub]
		    set upsub [linsert $upsub $i $newitem]
		} else {
		    set values($maxnum,up) [expr $maxnum +1]
		    incr maxnum
		    set values($maxnum,type) seq
		    set values($maxnum,up) $upn
		    set values($n,up) $maxnum
		    set upsub [concat [lrange $upsub 0 1] \
			    [list $maxnum seq $sub $newitem]]
		}
		set numberedtree [substsubtree $t $upn $upsub]
	    }
	}
    }
    incr maxnum
    draw $c
}




proc ::graph::Eval {w} {
    variable numberedtree
    if {$numberedtree == {}} {
	set ::corp::qrgraph {}
    } else {
	set ::corp::qrgraph [decodesubtree $numberedtree]
	set ::corp::query [graph2str $::corp::qrgraph]
    }
    destroy $w
}


proc ::graph::decodesubtree {tree} {
    variable values
    variable firstarg

    set n [lindex $tree 0]
    set type [lindex $tree 1]
    set out $type
    for {set i 1} {$i < $firstarg($type)} {incr i} {
	lappend out $values($n,arg$i)
    }
    foreach sub [lrange $tree 2 end] {
	lappend out [decodesubtree $sub]
    }
    return $out
}