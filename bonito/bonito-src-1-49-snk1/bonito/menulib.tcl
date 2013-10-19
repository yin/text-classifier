#  bonito:
#   $Id: menulib.tcl,v 1.3 2003/08/11 05:56:27 pary Exp $
#
#  Copyright (c) 2000-2003  Pavel Rychly

package provide menu 1.0

package require tools 1.0

catch {namespace delete _Menu}

proc kdMakeMenu {menu vars items} {
    if [catch {	
	#set menu [frame $menu -relief groove -borderwidth 1]
	#pack $menu -side top -fill x 
	menu $menu -tearoff 0
	set but 0 
    }] then {
	# menu exists
	set but [llength [info commands $menu.b\[0-9\]]]
    }
    foreach var $vars {
	set val [uplevel [list set $var]]
	namespace eval _Menu [list variable $var $val]
    }
    namespace eval _Menu [list init_variables $menu $but $vars]
    namespace eval _Menu $items
}


proc deleteMenuItem {menu itempath} {
    regsub ~ $itempath "" path
    foreach item [lrange $path 0 [expr [llength $path] -2]] {
	#puts "$menu $item"
	set menu [$menu entrycget $item -menu]
    }
    $menu delete [lindex $path end]
}

namespace eval _Menu {
    proc init_variables {imenu ibut vars} {
	variable menu $imenu
	variable but $ibut
	variable externvars $vars
    }

    proc _importvars {} {
	uplevel {
	    variable menu
	    variable but
	    variable externvars
	    foreach var $externvars {
		variable $var
	    }
	}
    }

    proc main {name body} {
	_importvars

	# test whether exists
	set exists 0
	foreach m [info commands $menu.b\[0-9\]] {
	    if {[$m cget -text] == $name} {
		set exists 1
		break
	}   }
	set savedmenu $menu
	if $exists {
	    set menu $m.m
	} else {
	    # create new one
	    menubutton $menu.b$but -menu $menu.b$but.m -relief raised \
		    -text $name 
	    if [regsub ~ $name "" cname] {
		$menu.b$but configure -text $cname \
			-underline [string first ~ $name]
	    } else {
		$menu.b$but configure -underline 0
	    }
	    menu $menu.b$but.m -tearoff 0
	    pack $menu.b$but -side left
	    set menu $menu.b$but.m 
	}
	eval $body
	set menu $savedmenu
	incr but
    }

    proc addUnderline {menu label} {
	#return
	if [regsub ~ $label "" nlab] {
	    $menu entryconfigure last -label $nlab \
		    -underline [string first ~ $label]
	} else {
	    #$menu entryconfigure last -underline 0
	}
    }

    proc findIndex {menu label} {
	set lastmenu [$menu index last]
	if {$lastmenu != "none"} {
	    regsub ~ $label "" nlab
	    #puts "menu: $menu, label:$label"
	    for {set i 0} {$i <= $lastmenu} {incr i} {
		if {[$menu type $i] != "separator" &&\
			[$menu entrycget $i -label] == $nlab} {
		    return $i
		}
	    }
	}
	return none
    }
	
    proc check {label var {comm ""}} {
	variable menu
	$menu add checkbutton -label $label \
		-variable $var -command $comm
	addUnderline $menu $label
    }

    proc radio {label var {comm ""}} {
	variable menu
	$menu add radiobutton -label $label \
		-variable $var -command $comm
	addUnderline $menu $label
    }

    proc separator {} {
	variable menu
	$menu add separator
    }

    proc cascade {label body} {
	_importvars
	# test whether exists
	set idx [findIndex $menu $label]
	
	#set sub [$menu entrycget $idx -menu]
	if {[$menu type $idx] != "cascade" || \
		[set sub [$menu entrycget $idx -menu]] == ""} {
	    # generovani jednoznacnyho jmena
	    set sub [genUniqName $menu $label]
	    menu $sub -tearoff 0
	    $menu add cascade -label $label -menu $sub
	    addUnderline $menu $label
	}
	set savedmenu $menu
	set menu $sub
	eval $body
	set menu $savedmenu
    }

    proc cascade_path {path body} {
	if {[llength $path] == 1} {
	    cascade [lindex $path 0] $body
	} else {
	    cascade [lindex $path 0] \
		    [list cascade_path [lrange $path 1 end] $body]
	}
    }

    proc command {label comm {key {}}} {
	variable menu
	$menu add command -label $label -command $comm \
		-accelerator [lindex $key 0]
	addUnderline $menu $label
	foreach k $key {
	    catch {bind . [get_tk_key $k] $comm}
	}
    }

    array set keykode {
	*    asterisk
	+    plus
	""   plus
	-    minus
	PgDn Next
	PgUp Prior
    }

    proc get_tk_key {key} {
	variable keykode
	array set mod {Control 0 Alt 0 Shift 0}
	set base ""
	foreach p [split $key +] {
	    switch -exact $p {
		Ctl {set mod(Control) 1}
		Alt {set mod(Alt) 1}
		Shft {set mod(Shift) 1}
		default {
		    if {[info exists keykode($p)]} {
			set base $keykode($p)
		    } else {
			set base $p
		    }
		}
	    }
	}
	if {[string match {[a-zA-Z]} $base]} {
	    if {$mod(Shift)} {
		set base [string toupper $base]
		set mod(Shift) 0
	    } else {
		set base [string tolower $base]
	    }
	}
	set seq {}
	foreach {m b} [array get mod] {
	    if {$b} {
		lappend seq $m
	    }
	}
	lappend seq $base
	return "<[join $seq -]>"
    }

}
