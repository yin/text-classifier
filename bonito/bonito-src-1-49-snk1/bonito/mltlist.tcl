#  bonito:
# 	$Id: mltlist.tcl,v 1.16 2003/10/02 08:40:55 pary Exp $
#
#  Copyright (c) 2002,2003  Pavel Rychly

# Implements a simple multilistbox widget

package provide mltlist 1.0

namespace eval ::mltlist {
    variable reswin ""
    variable resscale
    variable resx
    variable resstartx
    variable lastsortcol ""
    variable data
}

proc multilistbox args {eval ::mltlist::New $args}


# default options
option add *MultiListBox.TableSep.width        1
option add *MultiListBox.TableSep.background   black
option add *MultiListBox.TableSep.cursor       sb_h_double_arrow
option add *MultiListBox.borderWidth           2
option add *MultiListBox.relief                groove
option add *MultiListBox*box.borderWidth       0
#option add *MultiListBox*box.relief            sunken
option add *MultiListBox*exportSelection       0
option add *MultiListBox*selectBorderWidth     0
option add *MultiListBox*selectBackground      lightblue
option add *MultiListBox*selectMode            extended
#option add *MultiListBox*selectMode            multiple


bind MultiOneCol <<ListboxSelect>> {::mltlist::SyncSelect %W}
bind MultiOneCol <1> {focus %W}

bind TableSep <1> {::mltlist::ResizeStart %W %X}
bind TableSep <B1-Motion> {::mltlist::ResizeMove %X}
bind TableSep <ButtonRelease-1> ::mltlist::ResizeStop


proc ::mltlist::New {w colnum args} {
    frame $w -class MultiListBox
    scrollbar $w.sb -command "$w.0.box yview" -takefocus 0
    pack $w.sb -side right -fill y

    for {set i 0} {$i < $colnum} {incr i} {
	pack [frame $w.$i] -side left -fill both -expand 0
	#grid [frame $w.$i] -column [expr $i * 2] -row 0
	pack [label $w.$i.lbl -relief raised] -side top \
	    -fill x
	bind $w.$i.lbl <1> "::mltlist::Sort $w $i"
	listbox $w.$i.box -yscroll "::mltlist::SyncMove $w $i"
	pack $w.$i.box -side top -fill both -expand yes
	bindtags $w.$i.box [list MultiOneCol Listbox . all $w]

	pack [frame $w.x$i -class TableSep] -side left -fill y
	#grid [frame $w.x$i -class TableSep] -column [expr $i * 2 +1] -row 0 \
	    -sticky ns
    }
    destroy $w.x[expr $i -1]
    pack $w.[expr $i -1] -expand 1
    rename $w $w-framecmd
    proc ::$w args "eval ::mltlist::Command $w \$args"
    set ::mltlist::data($w) {}

    return $w
}

proc ::mltlist::Command {w cmd args} {
    variable lastsortcol
    switch $cmd {
	insert {
	    eval Insert $w $args
	    set lastsortcol ""
	}
	delete {
	    foreach {idx1 idx2} $args break
	    
	    ApplyAllButOne $w "" "" "delete $idx1 $idx2"
	    if {$idx2 == ""} {
		set idx2 $idx1
	    }
	    set ::mltlist::data($w) [lreplace $::mltlist::data($w) $idx1 $idx2]
	}
	selection {
	    switch [lindex $args 0] {
		anchor -
		clear -
		set  {
		    eval [list ApplyAllButOne $w "" "" $cmd] $args
		}
		includes {
		    return $w.0.box selection includes [lindex $args 1]
		}
	    }
	}
	getcolselection {
	    set out {}
	    set b $w.$args.box
	    foreach idx [$b curselection] {
		lappend out [$b get $idx]
	    }
	    return $out
	}
	get {
	    set n [expr [llength [winfo children $w]] /2]
	    set out {}
	    for {set i 0} {$i < $n} {incr i} {
		lappend out [$w.$i.box get $args]
	    }
	    lappend out [lindex $::mltlist::data($w) $args]
	    return $out
	}
	getcol {
	    foreach {col idx1 idx2} $args break
	    if {$idx2 == ""} {
		return [$w.$col.box get $idx1]
	    } else {
		return [$w.$col.box get $idx1 $idx2]
	    }
	}
	getdata {
	    foreach {idx1 idx2} $args break
	    if {$idx2 == ""} {
		return [lindex $::mltlist::data($w) $idx1]
	    } else {
		return [lrange $::mltlist::data($w) $idx1 $idx2]
	    }
	}
	size {
	    return [$w.0.box size]
	}
	header {
	    set n [expr [llength [winfo children $w]] /2]
	    set line [lindex $args 0]
	    for {set i 0} {$i < $n} {incr i} {
		$w.$i.lbl configure -text [lindex $line $i]
	    }
	}
	pack {
	    Pack $w
	}
	default {
	    eval $w-framecmd $cmd $args
	}
    }
}

proc ::mltlist::ApplyAllButOne {w n except cmd} {
    if {$n == ""} {
	set n [expr [llength [winfo children $w]] /2]
    }
    for {set i 0} {$i < $n} {incr i} {
	if {"$w.$i.box" != $except} {
	    eval $w.$i.box $cmd
	}
    }
}

proc ::mltlist::SyncSelect {box} {
    set boxl [split $box .]
    set l [expr [llength $boxl] -3]
    set w [join [lrange $boxl 0 $l] .]

    set n [expr [llength [winfo children $w]] /2]

    ApplyAllButOne $w $n $box "selection clear 0 end"
    foreach idx [$box curselection] {
	ApplyAllButOne $w $n $box "selection set $idx"
    }
    event generate $w <<ListboxSelect>>
}

proc ::mltlist::SyncMove {w col fracfrom fracto} {
    set n [expr [llength [winfo children $w]] /2]
    for {set i 0} {$i < $n} {incr i} {
	if {$i != $col} {
	    $w.$i.box yview moveto $fracfrom
	}
    }
    
    $w.sb set $fracfrom $fracto
}

proc ::mltlist::Insert {w index line} {
    set n [expr [llength [winfo children $w]] /2]
    for {set i 0} {$i < $n} {incr i} {
	$w.$i.box insert $index [lindex $line $i]
    }
    set ::mltlist::data($w) [linsert $::mltlist::data($w) $index \
				 [lrange $line $i end]]
}


proc ::mltlist::ResizeStart {w x} {
    set wl [split $w .]
    set w [join [lreplace $wl end end [string range [lindex $wl end] 1 end]] .]
    
    set ::mltlist::reswin $w.box
    set ::mltlist::resx $x
    if {[catch {set s [expr double([winfo width $w.box]) / [$w.box cget -width]]}]} {
	set s 1
    }
    set ::mltlist::resscale $s
    set ::mltlist::resstarx [winfo width $w.box]
}

proc ::mltlist::ResizeMove {x} {
    set w [set ::mltlist::reswin]
    if {$w != ""} {
	set prevx [set ::mltlist::resx]
	set newx [expr [set ::mltlist::resstarx] + ($x - $prevx)]
	set newwidth [expr int ($newx / [set ::mltlist::resscale])]
	#puts "$prevx $x $newx $newwidth"
	if {$newwidth > 0} {
	    $w configure -width $newwidth
	}
    }
}

proc ::mltlist::ResizeStop {} {
    set ::mltlist::reswin ""
}

proc ::mltlist::Sort {w col} {
    variable lastsortcol
    if {$lastsortcol == $col} {
	InvertOrder $w
	return
    }
    set lastsortcol $col
    set sl {}
    set i 0
    foreach x [$w.$col.box get 0 end] {
	lappend sl [list $x $i]
	incr i
    }
    set sl [lsort -dictionary -index 0 $sl]
    $w.$col.box delete 0 end
    set idxs {}
    foreach xi $sl {
	$w.$col.box insert end [lindex $xi 0]
	lappend idxs [lindex $xi 1]
    }
    set n [expr [llength [winfo children $w]] /2]
    for {set i 0} {$i < $n} {incr i} {
	if {$i != $col} {
	    set sl [$w.$i.box get 0 end]
	    $w.$i.box delete 0 end
	    foreach idx $idxs {
		$w.$i.box insert end [lindex $sl $idx]
	    }
	}
    }
    
    set newdata {}
    foreach idx $idxs {
	lappend newdata [lindex $::mltlist::data($w) $idx]
    }
    set ::mltlist::data($w) $newdata
}

proc ::mltlist::InvertOrder {w} {
    set n [expr [llength [winfo children $w]] /2]
    for {set i 0} {$i < $n} {incr i} {
	set vals [$w.$i.box get 0 end]
	$w.$i.box delete 0 end
	foreach x $vals {
	    $w.$i.box insert 0 $x
	}
    }
    set newdata {}
    foreach x $::mltlist::data($w) {
	set newdata [linsert $newdata 0 $x]
    }
    set ::mltlist::data($w) $newdata
}

proc ::mltlist::Pack {w} {
    set n [expr [llength [winfo children $w]] /2]
    for {set i 0} {$i < $n} {incr i} {
	set max [string length [$w.$i.lbl cget -text]]
	foreach x [$w.$i.box get 0 end] {
	    if {[set l [string length $x]] > $max} {
		set max $l
	    }
	}
	$w.$i.box configure -width [incr max]
    }
}
