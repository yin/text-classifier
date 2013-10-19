#  bonito:
#     $Id: balloon.tcl,v 1.1 2001/01/31 12:01:23 pary Exp $
#
#  Copyright (c) 2000,2001  Pavel Rychly

package provide balloon 1.0

namespace eval ::balloon {
    namespace export Init
}

proc ::balloon::Init {{init_enabled 1} {delay 500}} {
    # Set up general bindings for widgets that will have balloon help
    bind all <Enter> {::balloon::Prepare %W}
    bind balloon <Leave> ::balloon::Hide
    bind balloon <Any-Button> ::balloon::Hide
    bind balloon <Any-KeyPress> ::balloon::Hide

    variable enabled $init_enabled
    if [info exists $init_enabled] {
	set enabled [set $init_enabled]
	proc ::balloon::UpdateEnabled {name1 name2 op} {
	    upvar $name1 n
	    set ::balloon::enabled $n
	}
	trace variable $init_enabled w ::balloon::UpdateEnabled
    }
    variable bhelp
    set bhelp(after) ""
    set bhelp(delay) $delay
    set bhelp(window) ""
}

proc ::balloon::Prepare {w} {
    variable enabled
    variable bhelp
    if !$enabled return
    if {![string match $bhelp(window)* $w]} {catch Hide}
    set text [option get $w bhelp ""]
    if {$text == ""} return
    set bhelp(text) $text
    catch Hide
    set bhelp(after) [after $bhelp(delay) [list ::balloon::Show $w $text]]
    set bhelp(window) $w
}

# Produce balloon if appropriate
proc ::balloon::Show {w text} {
    # has the pointer already left the window?
    if {![string match $w* [eval winfo containing [winfo pointerxy .]]]} {
	#puts jsem-mimo
	return
    }
    set tags [bindtags $w]
    if {[lsearch -exact $tags balloon] < 0} {
	bindtags $w [concat balloon $tags]
    }
    set b .balloonhelp
    if {![winfo exists $b]} CreateWin
    $b.lbl configure -text $text
    update idletasks

    # compute position, staying on the screen and adjacent to the
    # widget in question
    set x [winfo pointerx .]
    if {([winfo vrootwidth .] - $x - [winfo reqwidth $b]) < 0} {
	set x [expr [winfo vrootwidth .] - [winfo reqwidth $b]]
    }
    set y [expr [winfo rooty $w] - [winfo reqheight $b]]
    if {$y < 0} {
	set y [expr [winfo rooty $w] + [winfo height $w]]
    }
    wm geometry $b +$x+$y
    wm deiconify $b
    if {![string match *+$x+$y [wm geometry $b]]} {
        tkwait visibility $b
        wm geometry $b +$x+$y
    }
    raise $b
}

proc ::balloon::CreateWin {} {
    set b .balloonhelp
    toplevel $b
    wm withdraw $b
    wm overrideredirect $b 1
    wm positionfrom $b program
    wm group $b .
    pack [label $b.lbl -highlightthickness 0 -relief raised -bd 1 -bg yellow]
}


# Destroy the help baloon unless it's a leave event and the 
# pointer is in a child.
proc ::balloon::Hide {} {
    variable bhelp
    after cancel $bhelp(after)
    wm withdraw .balloonhelp
}
