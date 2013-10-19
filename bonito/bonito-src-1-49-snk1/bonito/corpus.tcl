#  bonito:
#     $Id: corpus.tcl,v 1.28 2003/08/11 05:53:44 pary Exp $
#
#  Copyright (c) 2000-2003  Pavel Rychly

package provide corpus 1.0

package require attrib 1.0


proc corpusInfo {} {
    set w .corpinfo
    makeDialogWindow $w close
    $w.label config -text "[getOption text $w.label] $corp::name"

    array set stats {}
    foreach line [split [comm:evalcommand "info $corp::name"] "\n"] {
	foreach {i v} [split $line "\t"] break
	set stats($i) $v
    }

    # incorrect configuration test
    if {![info exists stats(size)]} {
	pack [label $w.errconf] -in $w.frame
	return
    }

    # info
    if {[info exists stats(info)]} {
	label $w.info -text [subst -nocommands -novariables $stats(info)] \
		-justify left
	pack $w.info -in $w.frame -side top
    }

    # uzivatelske statistiky
    foreach s [getOption statistics $w] {
	if [info exists stats($s)] {
	    pack [frame $w.fr$s] -in $w.frame -side top -fill x
	    pack [label $w.$s] -in $w.fr$s -side left
	    pack [label $w.val$s -text $stats($s)] -in $w.fr$s -side right
	}
    }

    # velikost
    pack [frame $w.sizefr] -in $w.frame -side top -fill x
    pack [label $w.sizelbl] -in $w.sizefr -side left
    pack [label $w.size -text $stats(size)] -in $w.sizefr -side right

    if {$stats(size) != $stats(search_size)} {
	pack [frame $w.ssizefr] -in $w.frame -side top -fill x
	pack [label $w.ssizelbl] -in $w.ssizefr -side left
	pack [label $w.ssize -text $stats(search_size)] \
	    -in $w.ssizefr -side right
    }

    # atributy
    pack [label $w.attrlbl] -in $w.frame -side top -anchor w
    pack [set fr [frame $w.frame.afr]]  -side top
    foreach a [comm:listatrib] {
	grid [label $fr.a_$a -text $a] [label $fr.s_$a -text $stats(a-$a)] \
		-sticky e -padx 10
    }

    # znacky
    pack [label $w.taglbl] -in $w.frame -side top -anchor w
    pack [set fr [frame $w.frame.tfr]]  -side top
    foreach a [comm:listtags] {
	if ![info exists stats($a,num)] {
	    set stats($a,num) ?
	}
	grid [label $fr.a_$a -text $a] [label $fr.s_$a -text $stats(s-$a)] \
		-sticky e -padx 10
    }

}
 
set align_arrow_up [image create bitmap -data {#define up_width 10
#define up_height 10
static unsigned char up_bits[] = {
  0x30, 0x00, 0x30, 0x00, 0x78, 0x00, 0x78, 0x00, 0xfc, 0x00, 0xfc, 0x00,
  0xfe, 0x01, 0xfe, 0x01, 0xff, 0x03, 0xff, 0x03, };
}]

set align_arrow_down [image create bitmap -data {#define down_width 10
#define down_height 10
static unsigned char down_bits[] = {
   0xff, 0x03, 0xff, 0x03, 0xfe, 0x01, 0xfe, 0x01, 0xfc, 0x00, 0xfc, 0x00,
   0x78, 0x00, 0x78, 0x00, 0x30, 0x00, 0x30, 0x00};
}]

proc insert_image {w image tag} {
    set i [$w index "end -1 lines"]
    $w image create end -image $image
    $w tag add $tag "$i linestart" "$i lineend"
    $w insert end "\n"
}

proc align_insert_part {w insert line1 line2} {
    foreach {pos1 pos2 cname} $line1 break
    set ac [lindex $line1 2]
    $w insert $insert "$cname: $pos1--[expr $pos2 -1]" corp 
    set t [encoding convertfrom [comm:evalcommand "encoding $cname"] \
	       [encoding convertto [fconfigure $corp::sock -encoding] $line2]]
    $w insert $insert "\n$t\n" {}
}

proc align_add_prev {w index} {
    set beg [lindex [$w tag nextrange corp $index] 0]
    set i [$w search -forward -exact ": " $beg]
    set j [$w search -forward -exact -- "-" $i]
    set cname [$w get $beg $i]
    set pos [$w get "$i +2 chars" "$j"]
    incr pos -1
    set t [comm:evalcommand "alignpos $cname $pos"]
    if {$t == ""} return
    foreach {l1 l2 l3 l4} [split $t "\n"] break
    $w mark set insert $beg
    align_insert_part $w insert $l1 $l2
    align_insert_part $w insert $l3 $l4
    $w insert insert "-----------" corp "\n" {}
}

proc align_add_next {w index} {
    $w mark set insert "$index linestart"
    set index [lindex [$w tag prevrange corp "$index -1 lines"] 0]
    set beg [lindex [$w tag prevrange corp $index] 0]
    set i [$w search -forward -exact ": " $beg]
    set j [$w search -forward -exact -- "--" $i]
    set cname [$w get $beg $i]
    set pos [$w get "$j +2 chars" "$j lineend"]
    incr pos 1
    set t [comm:evalcommand "alignpos $cname $pos"]
    if {$t == ""} return
    foreach {l1 l2 l3 l4} [split $t "\n"] break
    $w insert insert "-----------" corp "\n" {}
    align_insert_part $w insert $l1 $l2
    align_insert_part $w insert $l3 $l4
    $w see insert
}

proc show_aligned {} {
    set curr [.list index curr]
    if {$curr + 1 > [.list index end]} return
    set curr [expr int($curr) + $corp::displayedfrom -1]
    set t [comm:evalcommand "align query $curr"]
    if {$t != ""} {
	set w .align.frame.text
	if {![winfo exists $w]} {
	    makeDialogWindow .align {close "" save save_aligned}
	    scrollbar .align.frame.scr -command "$w yview" -takefocus 0
	    text $w -wrap word -yscroll ".align.frame.scr set"
	    pack .align.frame.scr -fill y  -expand no -side right
	    pack $w -expand yes -fill both -side left
	    $w tag config corp -foreground blue
	    $w tag config kwic -foreground red
	    $w tag config arup -background green
	    $w tag config ardown -background green
	    $w tag bind arup <Enter> "$w config -cursor hand2"
	    $w tag bind arup <Leave> "$w config -cursor xterm"	    
	    $w tag bind ardown <Enter> "$w config -cursor hand2"
	    $w tag bind ardown <Leave> "$w config -cursor xterm"
	    $w tag bind arup <ButtonRelease-1> "align_add_prev $w @%x,%y"
	    $w tag bind ardown <ButtonRelease-1> "align_add_next $w @%x,%y"
	    wm resizable .align 1 1
	    grab release .align
	}
	foreach {l1 l2 l3 l4} [split $t "\n"] break
	insert_image $w $::align_arrow_up arup
	$w insert end "${corp::name}: [lindex $l1 0]--[expr [lindex $l1 1] -1]" corp 
	foreach {lctx kwic rctx} [split $l2 "\t"] break
	$w insert end "\n$lctx" {} "$kwic" kwic "$rctx\n"
	align_insert_part $w end $l3 $l4
	insert_image $w $::align_arrow_down ardown
	$w insert end "--------------------" corp "\n" {}
	$w see end
    }
}

proc save_aligned {} {
    set name [tk_getSaveFile]
    if {$name != ""} {
	set f [open $name w]
	puts $f [.align.frame.text get 0.0 end]
	close $f
    }
}


proc subcorpWindow {} {
    set w .subcwin
    makeDialogWindow $w [list ok "finishsubcorp $w"]

    if {[set i [string first : $corp::name]] > 0} {
	set corp::subcbase [string range $corp::name 0 [incr i -1]]
    } else {
	set corp::subcbase $corp::name
    }

    label $w.baselbl -anchor w
    label $w.basecorp -textvar corp::subcbase

    label $w.namelbl -anchor w
    entry $w.name -textvar corp::subcname -width 10

    label $w.structlbl -anchor w
    makeMenuButon $w.struct corp::subcstruct [comm:listtags]

    label $w.querylbl -anchor w
    entry $w.query -textvar corp::subcquery -width 40

    grid $w.baselbl $w.basecorp -sticky w -in $w.frame
    grid $w.namelbl $w.name -sticky w -in $w.frame
    grid $w.structlbl $w.struct -sticky w -in $w.frame
    grid $w.querylbl $w.query -sticky w -in $w.frame
}

proc finishsubcorp {w} {
    destroy $w
    if {$corp::subcquery == ""} return
    comm:evalcommand "subcorp $corp::subcname $corp::subcbase $corp::subcstruct $corp::subcquery"

    set corp::query_error [string trim [comm:evalcommand "err query"] \"]
    if {$corp::query_error != ""} {
	tk_messageBox -title [getOption queryerror .status] \
		-message [subst -nocommands -novariables $corp::query_error] \
		-type ok -icon error
		
    } else {
	global sel_corp_name
	set sel_corp_name "$corp::subcbase:$corp::subcname"
	makeCorpList
    }
}

proc deletesubcorpWindow {{w .delsubc}} {
    makeDialogWindow $w [list ok "deletesubcorpDelete $w" close]
    pack [listbox $w.subc] -side top -in $w.frame -padx 15 -pady 5
    foreach c [comm:listcorpora] {
	if {[string match "*:*" $c]} {
	    $w.subc insert end $c
	}
    }
}

proc deletesubcorpDelete {w} {
    set i [$w.subc curselection]
    if {$i == ""} return
    comm:evalcommand "removesubc [$w.subc get $i]"
    $w.subc delete $i
    makeCorpList
}

proc defaultattrWindow {} {
    set w .defattrwin
    set attrs [comm:listatrib]
    if {[llength $attrs] == 1} {
	tk_messageBox -message [getOption noattrib $w] -type ok \
		-title [getOption title $w]
	return
    }
    set corp::defattr [comm:evalcommand "corpconf $corp::name DEFAULTATTR"]
    
    makeDialogWindow $w {ok finishdefaultattr}

    foreach a $attrs {
	pack [radiobutton [genUniqName $w at$a] -variable corp::defattr \
		  -text $a -value $a] -anchor w -in $w.frame -padx 10
    }
}

proc finishdefaultattr {} {
    destroy .defattrwin
    comm:evalcommand "setdefaultattr $corp::name $corp::defattr"
}


proc canRebuild {name} {
    #puts "canRebuild $name"
    set c [comm:evalcommand "canrebuild $name"]
    set menupath $opt::rebuildmenupath
    catch {deleteMenuItem .mb $menupath}
    if {$c == "OK"} {
	kdMakeMenu .mb menupath {
	    cascade [lindex $menupath 0] {
		command [lindex $menupath 1] rebuildCorpus
	    }
	}
    }
}

proc rebuildCorpus {{w .rebuild}} {
    makeDialogWindow $w close
    pack [text $w.log -height 15] -in $w.frame -padx 15 -pady 5
    listview_clear
    set corp::resultlen 0
    updateStatus rebuild
    $w.log insert 0.0 [comm:evalcommand "rebuild $corp::name"]
    updateStatus result
}
