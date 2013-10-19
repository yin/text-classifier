#  bonito:
#	$Id: detail.tcl,v 1.14 2004/01/12 18:54:14 pary Exp $
#
#  Copyright (c) 2000-2003  Pavel Rychly

package provide detail 1.0

proc makeDetailView {} {
    pack [frame .detail] -side top -fill x
    pack [scrollbar .detail.yscroll -command ".detail.list yview" \
	    -takefocus 0] -side right -fill y
    set lw .detail.list
    text $lw -insertontime 0 -wrap word -setgrid yes \
	    -exportselection yes -yscroll ".detail.yscroll set"
    pack $lw -side top -fill both -expand yes

    set tags [bindtags $lw]
    set i [lsearch $tags Text]
    bindtags $lw [lreplace $tags $i $i]
    foreach a {<Button-1> <B1-Motion> <Double-Button-1> <Triple-Button-1> 
	<Shift-Button-1> <Double-Shift-Button-1> <Triple-Shift-Button-1>
	<B1-Leave> <B1-Enter> <ButtonRelease-1> <Button-2> <B2-Motion>} {
	bind $lw $a [bind Text $a]
    }

    foreach t {coll col0 word attr strc grp} {
	tlist:settagdefaults $lw $t
    }
    bind $lw <Up> "addDetail 0.0"
    bind $lw <Down> "addDetail end"
    bind $lw <Tab> {tkTabToWindow [tk_focusNext %W]}
    bind $lw <Shift-Tab> {tkTabToWindow [tk_focusPrev %W]}
    bind $lw <Button-4> "scrollDetail %W 1"
    bind $lw <Button-5> "scrollDetail %W -1"
    bind $lw <MouseWheel> "scrollDetail %W %D"
}

proc scrollDetail {w dir} {
    if {$corp::detailtype == "context"} {
	foreach {vbeg vend} [$w yview] break
	if {$dir > 0 && $vbeg == 0} {
	    addDetail 0.0
	    return
	} elseif {$dir < 0 && $vend == 1} {
	    addDetail end
	    return
	}
    }
    if {$dir > 0} {
	$w yview scroll -1 units
    } else {
	$w yview scroll 1 units
    }
}

proc insertDetailIntoClipboard {w} {
    if {[$w tag ranges sel] == {}} {
	set data [$w get 1.0 1.end]
	clipboard clear -displayof $w
	clipboard append -displayof $w $data
    } else {
	tk_textCopy $w
    }
}

namespace eval corp {
    variable detailtype ""
}

proc showFullref {} {
    set corp::detailtype ref
    set curr [.list index curr]
    #XXX
    #if {$curr + 2 > [.list index end]} return
    set curr [expr int($curr) + $corp::displayedfrom -1]
    set corp::detailline $curr
    .detail.list delete 0.0 end
    set reflist [comm:corpconfitem FULLREF]
    if {$reflist == ""} {
	set reflist [join [split [comm:liststrattr] "\n"] ","]
    }
    foreach line [split [comm:evalcommand \
		         "concref $corp::servercolname $curr $reflist"] "\n"] {
	set validx [string first = $line]
	set attr [string range $line 0 [expr $validx -1]]
	set val [string range $line [expr $validx +1] end]
	.detail.list insert end $attr strc "\t$val\n" {}
    }
}

proc showDetail {} {
    set curr [.list index curr]
    #XXX
    #if {$curr + 2 > [.list index end]} return
    set curr [expr int($curr) + $corp::displayedfrom -1]
    set corp::detailline $curr
    .detail.list delete 0.0 end
    set corp::detailinsert end
    set n $corp::detailincr
    set corp::detailfrom -$n
    set corp::detailto $n
    set corp::showstrucvals 1
    set corp::detailtype context
    initOutput viewdetail "@$curr" "-$n $n"
}

proc addDetail {dir} {
    if {$corp::detailtype != "context"} return
    if {[string length [.detail.list get 0.0 end]] <= 1} return
    set corp::detailinsert $dir
    switch -exact -- $dir {
	end {
	    set from [incr corp::detailto]
	    set to [incr corp::detailto $corp::detailincr]
	    set start >0
	}
	0.0 {
	    set to [incr corp::detailfrom -1]
	    set from [incr corp::detailfrom -$corp::detailincr]
	    set start <0
	}
    }
    set corp::showstrucvals 1
    initOutput viewdetail "@$corp::detailline" "$from$start $to$start"
}


proc viewdetail_init {} {
}


proc viewdetail_add {words part prevpart} {
    if {$words == {} || $part == "struct"} {
	return
    }
    if {$corp::detailinsert == "end"} {
	.detail.list insert end " "
    }
    eval .detail.list insert $corp::detailinsert $words
    if {$corp::detailinsert == "0.0"} {
	.detail.list insert 0.0 " "
    }
  
}

proc viewdetail_done_line {} {}
proc viewdetail_done_part {} {}
proc viewdetail_done_all {} {
    .detail.list see $corp::detailinsert
    set corp::showstrucvals 0
}
