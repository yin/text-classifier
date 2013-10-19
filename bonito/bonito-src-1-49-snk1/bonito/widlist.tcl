#  bonito:
#       $Id: widlist.tcl,v 1.1 2001/01/31 12:01:23 pary Exp $
#
#  Copyright (c) 2000,2001  Pavel Rychly

package provide widlist 1.0
package require attrib 1.0

catch {namespace delete widlist}
namespace eval widlist {}

proc widlistInit {w prefix {initlines 1} {buttons {add delete ok close}}} {
    namespace eval widlist [list variable $w-pref $prefix \
	    $w-ranges {} $w-curr {} $w-nomodify 1]
    array set buttonaction [list add "widlist::Add $w" \
	    delete "widlist::Delete $w" \
	    ok "widlist::Eval $w" close {}]
    set actions {}
    foreach b $buttons {
	if {$b == "add" || $b == "delete"} {
	    set widlist::$w-nomodify 0
	}
	lappend actions $b $buttonaction($b)
    }
    makeDialogWindow $w $actions

    pack [frame $w.globalopt] [frame $w.r] \
	    -side top -expand no -in $w.frame
    while {$initlines > 0} {
	widlist::Add $w
	incr initlines -1
    }
}


namespace eval widlist {

proc Add {w} {
    variable $w-pref
    variable $w-ranges
    variable $w-curr
    variable $w-nomodify

    set prefix [set $w-pref]
    set maxn -1
    foreach n [set $w-ranges] {
	$w.r.$n config -relief raise
	if {$n > $maxn} { set maxn $n}
    }
    set n [incr maxn]
    lappend $w-ranges $n
    set rw $w.r.$n
    frame $rw -bd 2 -relief raise
    $prefix-add $rw corp::${prefix}_r $n
    grid $rw -column 0 -row $n -sticky ew
    focus $rw
    set $w-curr $rw
    if {![set $w-nomodify]} {
	bind $rw <Button-1> "widlist::Select $w $rw"
	$rw configure -relief sunken
    }
}

proc Select {w rw} {
    variable $w-ranges
    variable $w-curr

    foreach n [set $w-ranges] {
	$w.r.$n config -relief raise
    }
    $rw config -relief sunken
    set $w-curr $rw
}

proc Delete {w} {
    variable $w-ranges
    variable $w-curr

    set rw [set $w-curr]
    if {$rw != ""} {
	destroy $rw
	set n [string range $rw [expr [string last . $rw] +1] end]
	set i [lsearch -exact [set $w-ranges] $n]
	set $w-ranges [lreplace [set $w-ranges] $i $i]
	set $w-curr ""
    }
}

proc Eval {w} {
    variable $w-pref
    variable $w-ranges

    set prefix [set $w-pref]
    set ranges [set $w-ranges]
    $prefix-eval $w $ranges corp::${prefix}_r
}

}