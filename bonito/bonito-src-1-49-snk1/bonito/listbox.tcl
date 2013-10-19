#  bonito:
# 	$Id: listbox.tcl,v 1.14 2002/12/15 11:59:35 pary Exp $	
#
#  Copyright (c) 2000-2002  Pavel Rychly

package provide TextList 1.0

package require listres 1.0
package require outres 1.0

proc makeListBox {} {
    pack [frame .lstfr] -side top -fill both -expand yes
    scrollbar .lstfr.yscroll -command ".list yview" -takefocus 0
    scrollbar .lstfr.xscroll -command ".list xview" -takefocus 0 \
	    -orient horizontal
    text .list -wrap none -insertontime 0 -setgrid yes \
	-exportselection no -cursor {} \
	    -xscroll ".lstfr.xscroll set" -yscroll ".lstfr.yscroll set"
    makeArrowButtons .lstfr.aup .lstfr.adown

    grid .list -row 0 -column 0 -rowspan 1 -columnspan 3 -sticky news \
	    -in .lstfr
    grid .lstfr.yscroll -row 0 -column 3 -rowspan 1 -columnspan 1 -sticky news
    grid .lstfr.xscroll -row 1 -column 0 -rowspan 1 -columnspan 1 -sticky news
    grid .lstfr.aup -row 1 -column 1 -rowspan 1 -columnspan 1
    grid .lstfr.adown -row 1 -column 2 -rowspan 1 -columnspan 1
    grid rowconfig    .lstfr 0 -weight 1 -minsize 3
    grid columnconfig .lstfr 0 -weight 1 -minsize 0
    
    tlist:create .list
    selection handle .list tlist:selection_handler 

    # pro zarovnavani do sloupecku na zjistovani delky textu
    text .list.list -width 1000 -height 2 -takefocus 0
    foreach t {coll col0 word attr strc} {
	tlist:settagdefaults .list.list $t
    }
    place .list.list -x 0 -y -200
}

proc tlist:create {w} {
    # aby neslo editovat text 
    set tags [bindtags $w]
    set i [lsearch $tags Text]
    bindtags $w [lreplace $tags $i $i]
    foreach a {<Button-2> <B2-Motion> <Button-4> <Button-5> <MouseWheel>} {
	bind $w $a [bind Text $a]
    }

    foreach t {select curr coll col0 word attr strc high grp} {
	tlist:settagdefaults $w $t
    }
    $w mark set curr 0.0
    $w mark gravity curr left

    bind $w <Up> "tlist:moveline $w curr -1"
    bind $w <Down> "tlist:moveline $w curr +1"
    bind $w <Home> "tlist:moveline $w 0.0 -1"
    bind $w <End> "tlist:moveline $w end -1"
    bind $w <Prior> "tlist:movepage $w -1"
    bind $w <Next> "tlist:movepage $w 1"
    bind $w <space> "tlist:selectswitch $w curr"
    bind $w <Button-1> "tlist:moveline $w @%x,%y +0 ; focus $w ; \
	    tlist:selectswitch $w @%x,%y"
    bind $w <Shift-Button-1> "tlist:selectrange $w @%x,%y curr; \
	    tlist:moveline $w @%x,%y +0"
    #bind $w <Button-3> "tlist:findword $w @%x,%y"
    bind $w <Tab> {tkTabToWindow [tk_focusNext %W]}
    foreach k {0 1 2 3 4 5 6 7 8 9} {
	bind $w <Key-$k> "tlist:setlinegroup $w $k"
    }
    bind $w <Control-e> {set corp::linegrouppref {};set corp::linegroupnum 2}
}

namespace eval corp {
    variable linegrouppref ""
    variable linegroupnum 0
}

proc tlist:setlinegroup {w key} {
    switch $corp::linegroupnum  {
	0 {
	    set grp $key
	}
	1 {
	    set grp "$corp::linegrouppref$key"
	    set corp::linegroupnum 0
	}
	2 {
	    if {$key != 0} {
		set corp::linegrouppref $key
	    }
	    set corp::linegroupnum 1
	    return
	}	    
    }
    set l [expr int([.list index curr]) + $corp::displayedfrom -1]
    comm:evalcommand "linegroup query $l $grp"
    set rng [$w tag nextrange grp curr {curr lineend}]
    if {$rng != ""} {
	foreach {idx idx1} $rng break
	$w delete $idx $idx1
    } else {
	set idx [lindex [$w tag nextrange col0 curr] 1]
    }
    if {$grp != 0} {
	$w insert $idx "($grp)" grp
    }
    tlist:moveline $w curr +1
}

proc tlist:moveline {w index n} {
    set i [$w index "$index linestart $n lines"]
    if {$i == [$w index end]} {
	set i [$w index {end -1 lines}]
    }
    $w mark set curr $i
    $w tag remove curr 1.0 end
    $w tag add curr $i "$i +1 lines"
    catch {$w see [lindex [.list tag nextrange col0 $i] 0]}
    updateStatus result
}

proc tlist:movepage {w n} {
    set lines [expr int( $n * \
	    ([$w index "@0,[winfo height $w] linestart"] \
	    - [$w index @0,0])) ]
    if {$lines >= 0} {
	set lines "+$lines"
    }
    tlist:moveline $w curr $lines
    updateStatus result
}

proc ranges:locate {list num} {
    set idx 0
    foreach {beg end} $list {
	if {$end > $num} {
	    return [list [expr $idx *2] $beg $end]
	}
	incr idx
    }
    return None
}

proc ranges:sum {list} {
    set sum 0
    foreach {beg end} $list {
	set sum [expr $sum + $end - $beg]
    }
    return $sum
}

proc ranges:normalize {list idx} {
    set i [expr $idx -1]
    if {$i >= 0 && [lindex $list $i] == [lindex $list $idx]} {
	set list [lreplace $list $i $idx]
    } else {
	incr i 2
	incr idx 2
    }
    if {[lindex $list $i] == [lindex $list $idx]} {
	set list [lreplace $list $i $idx]
    }
    return $list
}

proc ranges:set {var num} {
    upvar $var list
    if {[llength $list] == 0 || [lindex $list end] < $num} {
	lappend list $num [expr $num +1]
	return
    }
    foreach {idx beg end} [ranges:locate $list $num] break
    if {$idx == "None"} {
	# $num musi byt rovno poslednimu prvku
	set list [lreplace $list end end [incr num]]
    } elseif {$beg > $num} {
	set list [ranges:normalize [concat [lrange $list 0 [expr $idx -1]] \
		$num [expr $num +1] [lrange $list $idx end]] $idx]
    }
}

proc ranges:setrange {var from to} {
    upvar $var list
    if {[llength $list] == 0 || [lindex $list end] < $from} {
	lappend list $from $to
	return
    }
    foreach {idx1 beg end} [ranges:locate $list $from] break
    if {$idx1 == "None"} {
	# $num musi byt rovno poslednimu prvku
	set list [lreplace $list end end $to]
	return
    } 
    if {$beg < $from} {
	set from $beg
    }
    foreach {idx2 beg end} [ranges:locate $list $to] break
    if {$idx2 == "None"} {
	set tail {}
    } else {
	if {$beg < $to} {
	    incr idx2 2
	    if {$end > $to} {
		set to $end
	    }
	}
	set tail [lrange $list $idx2 end]
    }
    set list [ranges:normalize [concat [lrange $list 0 [expr $idx1 -1]] \
	    $from $to $tail] $idx1]
}

proc ranges:unset {var num} {
    upvar $var list
    foreach {idx beg end} [ranges:locate $list $num] break
    if {$idx != "None" && $beg <= $num} {
	if {$beg == $num} {
	    if {$end == $num +1} {
		set list [lreplace $list $idx [expr $idx +1]]
	    } else {
		set list [lreplace $list $idx $idx [expr $num +1]]
	    }
	} else {
	    if {$end == $num +1} {
		incr idx
		set list [lreplace $list $idx $idx $num]
	    } else {
		set list [concat [lrange $list 0 $idx] $num \
			[expr $num +1] [lrange $list [expr $idx +1] end]]
	    }
	}
    }
}

proc ranges:invert {var min max} {
    upvar $var list
    if {[lindex $list 0] == $min} {
	set list [lreplace $list 0 0]
    } else {
	set list [linsert $list 0 $min]
    }
    if {[lindex $list end] == $max} {
	set list [lreplace $list end end]
    } else {
	lappend list $max
    }
}

proc tlist:selectswitch {w index} {
    set num [expr int([$w index "$index linestart"]) + $corp::displayedfrom -1]
    # XXX vyresit posledni radek (nezobrazene)
    foreach {idx beg end} [ranges:locate $corp::sellines $num] break
    if {$idx == "None" | $beg > $num} {
	ranges:set corp::sellines $num
    } else {
	ranges:unset corp::sellines $num
    }
    tlist:updateselected $w
}

proc tlist:selectrange {w from to} {
    set from [$w index "$from linestart"]
    set to [$w index "$to linestart"]
    if {$from > $to} {
	foreach {from to} [list $to $from] break
    }
    set from [expr int($from) + $corp::displayedfrom -1]
    set to [expr int($to) + $corp::displayedfrom]
    ranges:setrange corp::sellines $from $to
    tlist:updateselected $w
}

proc tlist:selectno {w} {
    set corp::sellines {}
    tlist:updateselected $w
}

proc tlist:selectall {w} {
    set corp::sellines [list 0 $corp::resultlen]
    tlist:updateselected $w
}

proc tlist:selectinvert {w} {
    ranges:invert corp::sellines 0 $corp::resultlen
    tlist:updateselected $w
}

proc tlist:updateselected {w} {
    $w tag remove select 1.0 end
    foreach {beg end} $corp::sellines {
	set beg [expr $beg - $corp::displayedfrom +1]
	set end [expr $end - $corp::displayedfrom +1]
	$w tag add select $beg.0 $end.0
    }
    updateStatus result
}

proc tlist:clipboard {w} {
    global unix_selection
    clipboard clear
    set unix_selection ""
    savetostring $corp::sellines ::unix_selection
    if {$::tk_version >= 8.2 && $::tcl_platform(platform) == "unix"} {
	set unix_selection [encoding convertto $unix_selection]
    }
    clipboard append $unix_selection
    selection own .list
}

set ::unix_selection ""
proc tlist:selection_handler {offset maxbytes} {
    global unix_selection
    return [string range $unix_selection $offset [expr $offset + $maxbytes -1]]
}



proc tlist:exportced {w} {
    if {[catch {set cedf [open "|ced --bonito" w]}]} return
    fconfigure $cedf -blocking 0
    puts $cedf "\$$corp::name:1"
    foreach {beg len}  [comm:evalcommand "positions query $corp::sellines"] {
	puts $cedf "*:1:-1:$beg:$len"
    }
    close $cedf
}


proc tlist:findword {w index} {
    $w tag remove high 1.0 end
    set word [$w tag prevrange word "$index +1 chars"]
    if {$word != "" && [$w compare $index < [lindex $word 1]]} {
	eval $w tag add high $word
	set index [lindex $word 0]
	set line [expr int($index)]
	set coll [lindex [$w tag nextrange coll "$index linestart"] 0]
	set pos [expr [tlist:wordofline $w $index] \
		- [tlist:wordofline $w $coll]]
	set corp::statsword2 $corp::statsword1
	set corp::statsword1 [eval $w get $word]
	#[list $line $pos]
    }
}

proc tlist:wordofline {w index} {
    set num -1
    set index [$w index "$index +1 chars"]
    while {$index != ""} {
	set index [lindex [$w tag prevrange word $index "$index linestart"] 0]
	incr num
    }
    return $num
}

proc tlist:settagdefaults {w tag} {
    foreach optline [$w tag config $tag] {
	foreach {opt name class def val} $optline break
	if {$val == ""} {
	    set val [option get $w $tag$opt $class]
	    if {$val != ""} {
		$w tag config $tag $opt $val
	    }
    }   }
}

proc tlist:storetext {w from to} {
    set text ""
    set currtags ""
    array set accepted {
	coll 1
	word 1
	attr 1
	select  0
	curr 0
	high 0
	strc 0
	col0 1
    }

    foreach {key value index} [$w dump -tag -text $from $to] {
	switch -exact $key {
	    tagon {
		if $accepted($value) {
		    lappend currtags $value
		}
	    }
	    tagoff {
		if $accepted($value) {
		    set i [lsearch -exact $currtags $value]
		    set currtags [lreplace $currtags $i $i]
		}
	    }
	    text {
		lappend text $value $currtags
	    }
	}
    }
    return $text
}

proc makeArrowButtons {up down} {
    button $up -command listview_add_before -takefocus 0 \
	    -image [image create bitmap -data {#define up_width 10
#define up_height 10
static unsigned char up_bits[] = {
  0x30, 0x00, 0x30, 0x00, 0x78, 0x00, 0x78, 0x00, 0xfc, 0x00, 0xfc, 0x00,
  0xfe, 0x01, 0xfe, 0x01, 0xff, 0x03, 0xff, 0x03, };
}]

    button $down -command listview_add_after -takefocus 0 \
	    -image [image create bitmap -data {#define down_width 10
#define down_height 10
static unsigned char down_bits[] = {
   0xff, 0x03, 0xff, 0x03, 0xfe, 0x01, 0xfe, 0x01, 0xfc, 0x00, 0xfc, 0x00,
   0x78, 0x00, 0x78, 0x00, 0x30, 0x00, 0x30, 0x00};
}]
}
