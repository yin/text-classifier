#  bonito:
# 	$Id: combobox.tcl,v 1.2 2001/08/07 15:45:59 pary Exp $
#
#  Copyright (c) 2001  Pavel Rychly

# Implements a simple combobox widget

package provide combobox 1.0

namespace eval ::combobox {
    variable arrow [image create bitmap -data {#define up_width 11
#define up_height 6
static char up_bits[] = {
  0x00, 0x00, 0xfe, 0x03, 0xfc, 0x01, 0xf8, 0x00, 0x70, 0x00, 0x20, 0x00, };
}]
}

proc combobox args {eval ::combobox::New $args}

proc ::combobox::New {w listfn {setfn ""} args} {
    variable arrow
    frame $w -relief sunken -bd 2
    entry $w.entry -bd 0
    button $w.button -command [list ::combobox::PopUp $w $listfn $setfn] \
	    -image $arrow -takefocus 0
    pack $w.entry -expand yes -side left -fill both
    pack $w.button -side left -fill y
    bind $w.entry <Alt-Down> [list ::combobox::PopUp $w $listfn $setfn]
    if [llength $args] {
	    eval "$w.entry configure $args"
    }
    return $w
}


proc ::combobox::PopUp {w listfn setfn} {
    set lines [eval $listfn]

    set count [llength $lines]
    if {$count == 0} return

    set p .cbpopup
    if [winfo exists $p] {
	destroy $p
    }
    toplevel $p -cursor top_left_arrow

    wm withdraw $p
    wm overrideredirect $p 1
    wm positionfrom $p program
    set topw [winfo toplevel $w]
    wm transient $p $topw
    wm group $p $topw

    listbox $p.list -selectmode browse -relief sunken -bd 1 \
	     -width [$w.entry cget -width] -bg [$w.entry cget -bg]
    pack $p.list -side left -fill x -expand yes
    if {$count > [$p.list cget -height]} {
	$p.list configure -yscroll "$p.sb set"
	scrollbar $p.sb -command "$p.list yview"
	pack $p.sb -side left -fill y -expand no
    } else {
	$p.list configure -height $count
    }
    foreach l $lines {
	$p.list insert 0 $l
    }
    $p.list activate 0

    bind $p <ButtonPress-1> "::combobox::CheckMousePos $w %X %Y"
    bind $p.list <ButtonRelease-1> [list ::combobox::PopDown $w $setfn]
    bind $p.list <Return> [list ::combobox::PopDown $w $setfn]
    bind $p.list <Escape> "::combobox::Release $w"

    update idletasks
    set xpos [winfo rootx $w]
    set ypos [expr [winfo rooty $w]+[winfo reqheight $w]]
    wm geometry $p [winfo width $w]x[winfo reqheight $p]+$xpos+$ypos
    wm deiconify $p
    raise $p
    grab -global $p
    
    focus $p.list
}

proc ::combobox::Release {w} {
    set p .cbpopup
    wm withdraw $p
    grab release $p
    focus $w.entry
    #destroy $p
}

proc ::combobox::PopDown {w setfn} {
    set p .cbpopup
    $w.entry delete 0 end

    set s [$p.list curselection]
    if {$s != ""} {
	set s [$p.list get $s]
	if {$setfn == ""} {
	    $w.entry insert 0 $s
	} else {
	    eval $setfn [list $s]
	}
    }
    Release $w
}

proc ::combobox::CheckMousePos {w xpos ypos} {
    set c [winfo containing $xpos $ypos]
    if {$c == "" || [winfo toplevel $c] != ".cbpopup"} {
	Release $w
    }
}
