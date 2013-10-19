#  bonito:
#	$Id: tools.tcl,v 1.5 2002/11/04 09:46:21 pary Exp $	
#
#  Copyright (c) 2000-2002  Pavel Rychly

package provide tools 1.0

proc genUniqName {w {sub ""}} {
    if {$sub != ""} {
	regsub -all {[-~. ]} $sub "" ssub
	set new $w.[string tolower [string range $ssub 0 4]]
	regsub {^\.\.} $new . w
    }
    if {[info commands $w] == ""} {
	return $w
    }
    set i 1
    while {[info commands $w$i] != ""} {
	incr i
    }
    return $w$i
}

array set globopt {}
namespace eval opt {variable debug 0}

proc getOption {id w} {
    global globopt
    if [info exists globopt($w,$id)] {
	return $globopt($w,$id)
    }
    if [catch {option get $w $id ""} opt] {
	set tmpw ""
	if ![winfo exists ".tmp$w"] {
	    foreach p [split "tmp$w" .] {
		append tmpw .$p
		catch {frame $tmpw}
	    }
	}
	set opt [option get ".tmp$w" $id ""]
	if {$opt == "" && $opt::debug} {
	    set opt "--> $id <--"
	}
    }
    set globopt($w,$id) $opt
    return $opt
}

proc getOptionList {w idlist} {
    set res {}
    foreach id $idlist {
	set opt [getOption $id $w]
	if {$opt == "--> $id <--" || $opt == ""} {
	    lappend res $id
	} else {
	    lappend res [list $opt $id]
	}
    }
    return $res
}

proc checkbuttonList {w listname value args} {
    upvar \#0 $listname list
    
    eval checkbutton [list $w -onvalue $value -variable tempvar$w] $args
    if {[lsearch -exact $list $value] >= 0} {
	$w select
    } else {
	$w deselect
    }
    $w configure -command "updateCheckList $w $listname"
    return $w
}

proc updateCheckList {w listname} {
    upvar \#0 [$w cget -variable] var
    upvar \#0 $listname list
    set val [$w cget -onvalue]
    set idx [lsearch -exact $list $val]
    if {$var == $val} {
	if {$idx < 0} {
	    lappend list $val
	}
    } else {
	set list [lreplace $list $idx $idx]
    }
}
	
proc makeMenuButon {w var list} {
    global $var $var-text
    set m $w.menu 
    catch {menubutton $w -highlightthickness 1 -takefocus 1}
    $w config -menu $m -textvariable $var-text -relief raise \
	    -indicatoron 1 -direction flush
    catch {destroy $m}
    menu $m -tearoff 0
    set maxwidth 0
    set setval ""
    set setlab ""
    foreach e $list {
	set lab [lindex $e 0]
	set val [lindex $e 1]
	if {$val == {}} {
	    set val $lab
	}
	$m add radiobutton -label $lab -value $val -variable $var \
		-indicatoron 0 -command [list set $var-text $lab]
	if {[set $var] == $val || $setval == ""} {
	    set setval $val
	    set setlab $lab
	}
	if {[set l [string length $lab]] > $maxwidth} {
	    set maxwidth $l
	}
    }
    set $var $setval
    set $var-text $setlab
    if {[option get $w width ""] == ""} {
	$w config -width $maxwidth
    }
    return $w
}
    
namespace eval corp {
    variable animation 0 animtext "" anim_cancel ""
}

proc anim:start {cancelcom {w .queryfr}} {
    if $corp::animation {
	anim:stop
    }
    set corp::animation 1
    set corp::animtext "Stop "
    set corp::anim_cancel $cancelcom
    set corp::anim_inwin $w

    catch {destroy .animation}
    after 500 anim:createbutton
}

proc anim:createbutton {} {
    button .animation -textvariable corp::animtext -command comm:stop -pady 1
    pack .animation -in $corp::anim_inwin -side left
    anim:update
}

proc anim:stop {} {
    set corp::animation 0
    catch {destroy .animation}
    after cancel anim:createbutton
    after cancel anim:update
    after cancel $corp::anim_cancel
}

proc anim:update {} {
    set corp::animtext "[string range $corp::animtext 1 end][string range $corp::animtext 0 0]"
    after 300 anim:update
}

proc initarrays {args} {
    foreach a $args {
	uplevel "catch {unset $a}; array set $a {}"
    }
}

proc errWindow {w text} {
    tk_messageBox -message [getOption $text $w] -type ok \
	    -title [getOption title $w] 
    #-icon error
}

