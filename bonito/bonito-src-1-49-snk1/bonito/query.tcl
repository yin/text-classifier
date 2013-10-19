#  bonito:
#  	$Id: query.tcl,v 1.14 2003/11/18 17:34:27 pary Exp $	
#
#  Copyright (c) 2000-2003  Pavel Rychly

package provide query 1.0
package require attrib 1.0
package require listres 1.0

namespace eval corp {
    array set template {all {}}
    variable history_list {} history_num 0 namedquer {} history_lastsaved 0
    variable resultsteps {}
}

proc processQuery {} {
    if !$corp::conected {
	login
	return
    }
    if $corp::animation {
	bell
	return
    }
    set expquery [expandTemplate $corp::query]
    if {$expquery != ""} {
	set hitem [list $corp::query $corp::qrlabel $corp::qrgraph]
	addtoHistory $hitem
	addtoNamedQueries $hitem
	updateStatus query
	set result_item [list $corp::query $corp::qrlabel $expquery]
	set corp::query ""
	set corp::qrlabel ""
	set corp::qrgraph ""
	#.queryfr.qrgraph config -state normal
	#set corp::lastname $corp::name
	if {$corp::qtype == "conc"} {
	    store_conc rename
	} else {
	    store_conc
	}
	switch -glob $corp::qtype {
	    conc {
		set corp::resultsteps [list 0 $result_item]
		comm:evalcommand "set query $corp::name $expquery"
		set corp::maxcoll 0
		set corp::sellines {}
	    }
	    c[1-9] {
		set colnum [string trim $corp::qtype c]
		lappend corp::resultsteps $colnum $result_item
		if {$colnum > $corp::maxcoll} {
		    incr corp::maxcoll
		}
		callcoloc $colnum $expquery
	    }
	    pfil {
		lappend corp::resultsteps p $result_item
		set colnum [incr corp::maxcoll]
		callcoloc $colnum $expquery
		waitForResult
		comm:evalcommand "delpnf query $colnum 1"
		set corp::sellines {}
	    }
	    nfil {
		lappend corp::resultsteps n $result_item
		set colnum [expr $corp::maxcoll +1]
		callcoloc $colnum $expquery
		waitForResult
		comm:evalcommand "delpnf query $colnum 0"
		set corp::sellines {}
	    }
	}
	makeConcCollButton
	refreshResult start
	concinfo_detail
    }
}

proc callcoloc {colnum query} {
    comm:evalcommand "coloc query $colnum [composePos corp::coll left] [composePos corp::coll right] $corp::collindex $query"
}

trace variable corp::qtype w hide_show_collrange

proc hide_show_collrange args {
    if {$corp::qtype == "conc"} {
	catch {pack forget .collrange}
    } else {
	pack .collrange -in .collrangefr -side left
	if [winfo exists .collrange.left] {
	    set list [getposunitlist]
	    makeMenuButon .collrange.left.unit corp::coll(left,unit) $list
	    makeMenuButon .collrange.right.unit corp::coll(right,unit) $list

	    set list [getposfromlist $corp::maxcoll] 
	    makeMenuButon .collrange.left.from corp::coll(left,from) $list
	    makeMenuButon .collrange.right.from corp::coll(right,from) $list
	}
    }
}

proc makeConcCollButton {} {
    set l [getOptionList .queryfr.select conc]
    if {[llength $corp::resultsteps] > 0} {
	set l [concat $l [getOptionList .queryfr.select {pfil nfil}]]
	set collstr [getOption coll .queryfr.select]
	set i 1
	while {$i <= $corp::maxcoll + 1} {
	    lappend l [list [format $collstr $i] c$i]
	    incr i
	}
    }
    makeMenuButon .queryfr.type corp::qtype $l
}

proc updateStatus {msgid} {
    if {$msgid == "result"} {
	set rlen $corp::resultlen
	switch -exact -- $rlen {
	    UNKNOWN - "" {
		set msgid error
	    }
	    0 {
		set msgid notfound
	    }
	    default {
		set corp::status "[getOption found .status] "
		set v [expr int([.list index end]) -1]
		if {$v == $rlen} {
		    append corp::status [getOption all .status]/$rlen
		} else {
		    if {$corp::rngfrom != "random"} {
			append corp::status "[expr $corp::displayedfrom +1]+"
		    }
		    append corp::status $v/$rlen \
			    "  ([expr int(($v*100.0)/$rlen)]%)"
		}
		if {$corp::querytyperesult || \
			[trace vinfo corp::resultlen] != ""} {
		    # jeste neni vse nacteno (velikost se zvetsuje)
		    append corp::status ??
		    if {[after info] == ""} {
			after 1000 after idle updateStatus result
		    }
		}
		append corp::status "   [getOption position .status] " \
			[expr int([.list index curr]) + $corp::displayedfrom]
		set s [ranges:sum $corp::sellines]
		if {$s > 0} {
		    append corp::status "   [getOption selected .status] $s"
		}
		return
	    }
	}
    }
    set corp::status [getOption $msgid .status]
}

#
# Templates
#

proc expandTemplate {query} {
    switch -glob -- $query {
	!:* {
	    regsub -all {[\]\[.?*+\"{}()]} $query {\\&} query
	    set out ""
	    foreach w [split [string range $query 2 end]] {
		if {$w != ""} {
		    append out " \"$w\""
		}
	    }
	    return $out
	} 
	!*:* {
	    set i [string first : $query]
	    set template [string range $query 1 [expr $i -1]]
	    set args [split [string range $query [expr $i +1] end]]
	    return [substTemplate $template $args]
	}
	*\"* -
	*<* {
	    return $query
	}
	default {
	    # XXX bez uvozovek a zobaku -> doplnujeme; jak bude COFE, vyhodit
	    regsub -all { +} [string trim $query] {" "} tmpq
	    return "\"$tmpq\""
	}
    }
}


proc substTemplate {tmplname values} {
    if [catch {set corp::template($tmplname:str)} tmplstr] {
	# neznama predloha
	errWindow .errtmpl unknown
	return ""
    }
    set count 0
    array set vals {}
    foreach  val $values {
	if {$val != ""} {
	    incr count
	    set vals($count) $val
	    #puts [list set $var $val]
	}
    }
    if {$count != $corp::template($tmplname:count)} {
	#puts "pocet $count $corp::template($tmplname:count)"
	# chybny pocet parametru
	errWindow .errtmpl parnum
	return ""
    }
    
    set result ""
    foreach s [split $tmplstr {$}] {
	if {[string match {[1-9]*} $s]} {
	    append result $vals([string index $s 0]) [string range $s 1 end]
	} else {
	    append result {$} $s
	}
    }
    return [string range $result 1 end]
}
    

proc loadTemplates {filename} {
    set file [open $filename]
    while {![eof $file]} {
	gets $file line
	if {$line != ""} {
	    eval addTemplate $line
	}
    }
    close $file
}
    
proc addTemplate {name string note} {
    if [info exists corp::template($name:str)] {
	# err
	return 1
    }
    lappend corp::template(all) $name
    set corp::template($name:str) $string
    set corp::template($name:note) $note
    set count 0
    array set vars {} 
    while {[regexp -indices {\$[0-9]} $string match]} {
	foreach {i1 i2} $match break
	incr i1
	set vars([string index $string $i1]) 1
	set string [string range $string $i2 end]
    }
    set corp::template($name:count) [llength [array names vars]]
    return 0
}


proc saveTemplates {filename} {
    set file [open $filename w]
    foreach name $corp::template(all) {
	puts $file [list $name $corp::template($name:str) \
		$corp::template($name:note)]
    }
    close $file
}

proc exportTemplates {} {
    set filename [tk_getSaveFile -defaultextension .tpl \
	    -filetypes $opt::templateext]
    if {$filename != ""} {
	saveTemplates $filename
    }
}

proc loadnewTemplates {} {
    set filename [tk_getOpenFile -defaultextension .tpl \
	    -filetypes $opt::templateext]
    if {$filename != ""} {
	loadTemplates $filename
    }
}

proc addTemplateWindow {{updatelist ""}} {
    set w .addtmpl
    if {$corp::query != "" && ![string match !*:* $corp::query]} {
	set corp::addtmplstr $corp::query
    }
    makeDialogWindow $w [list ok "addTemplatefinish $w $updatelist" close]
    
    pack [frame $w.frame.name] -side top -anchor e
    pack [label $w.namelbl] \
	    [entry $w.name -textvar corp::addtmplname -width 30] \
	    -in $w.frame.name -side left -pady 10 -padx 3

    pack [frame $w.frame.str] -side top -anchor e
    pack [label $w.strlbl] \
	    [entry $w.string -textvar corp::addtmplstr -width 30] \
	    -in $w.frame.str -side left -pady 10 -padx 3

    pack [frame $w.frame.note] -side top -anchor e
    pack [label $w.notelbl] \
	    [entry $w.note -textvar corp::addtmplnote -width 30] \
	    -in $w.frame.note -side left -pady 10 -padx 3
    
}

proc addTemplatefinish {w {updatelist ""}} {
    destroy $w
    addTemplate $corp::addtmplname $corp::addtmplstr $corp::addtmplnote
    if {$updatelist != ""} {
	listTemplateUpdate $updatelist
    }
} 
	
proc listTemplateWindow {} {
    set w .listtmpl
    set lw $w.lfr.list
    makeDialogWindow $w [list delete "listTemplateDelete $lw" \
	    ok "addTemplateWindow $lw" close]

    frame $w.lfr -borderwidth 10
    pack $w.lfr -in $w.frame -side top -expand yes -fill y

    scrollbar $w.lfr.scroll -command "$lw yview"
    listbox $lw -yscroll "$w.lfr.scroll set" \
	    -setgrid 1 -exportselection no
    pack $lw $w.lfr.scroll -side left -fill y -expand 1

    bind $lw <Double-1> "destroy $w"
    bind $lw <1> "listTemplateSelect $w @%x,%y"

    pack [frame $w.frame.str] -side top -anchor e
    entry $w.string -textvar corp::addtmplstr -state disabled -width 30
    pack [label $w.strlbl] $w.string \
	    -in $w.frame.str -side left -pady 10 -padx 3

    pack [frame $w.frame.note] -side top -anchor e
    entry $w.note -textvar corp::addtmplnote -state disabled -width 30
    pack [label $w.notelbl] $w.note \
	    -in $w.frame.note -side left -pady 10 -padx 3

    listTemplateUpdate $lw
}

proc listTemplateUpdate {lw} {
    $lw delete 0 end
    set corp::addtmplname ""
    set corp::addtmplstr ""
    set corp::addtmplnote ""
    eval $lw insert 0 $corp::template(all)
}

proc listTemplateDelete {lw} {
    foreach i [$lw curselection] {
	set name [$lw get $i]
	unset corp::template($name:str)
	unset corp::template($name:note)
	unset corp::template($name:count)
	set i [lsearch -exact $corp::template(all) $name]
	set corp::template(all) [lreplace $corp::template(all) $i $i]
    }
    listTemplateUpdate $lw
}

proc listTemplateSelect {w idx} {
    set lw $w.lfr.list
    set name [$lw get $idx]
    $lw selection clear 0 end
    $lw selection set $idx
    if {$name == ""} {
	$w.string config -state disabled
	$w.note config -state disabled
    } else {
	$w.string config -state normal -textvar corp::template($name:str)
	$w.note config -state normal -textvar corp::template($name:note)
	set corp::query "!$name: "
    }
}

#
# History
#

proc addtoHistory {histitem} {
    if {$histitem != {} && $histitem != [lindex $corp::history_list end]} {
	lappend corp::history_list $histitem
	set l [llength $corp::history_list]
	if {$l > $opt::historysize} {
	    set corp::history_list [lreplace $corp::history_list 0 \
		    [expr $l - $opt::historysize -1]]
	    if $corp::history_lastsaved {
		incr corp::history_lastsaved -1
	    }
	}
    }
    set corp::history_num [llength $corp::history_list]
    
}

proc history_list {} {
    set r {}
    foreach i $corp::history_list {
	lappend r [lindex $i 0]
    }
    return $r
}

proc set_hist_item {hi} {
    set corp::query [lindex $hi 0]
    set corp::qrlabel [lindex $hi 1]
    set corp::qrgraph [lindex $hi 2]
    #if {$corp::query != "" && $corp::qrgraph == ""} {
    #    .queryfr.qrgraph config -state disabled
    #} else {
    #    .queryfr.qrgraph config -state normal
    #}
}

proc history_up {} {
    if {$corp::history_num > 0} {
	incr corp::history_num -1
	set_hist_item [lindex $corp::history_list $corp::history_num]
    }
}

proc history_down {} {
    if {$corp::history_num < [llength $corp::history_list]} {
	incr corp::history_num
	set_hist_item [lindex $corp::history_list $corp::history_num]
    }
}

proc loadHistory {filename} {
    set file [open $filename]
    while {![eof $file]} {
	gets $file line
	addtoHistory $line
    }
    close $file
    set corp::history_lastsaved [llength $corp::history_list]
}
    
proc saveHistory {filename} {
    set file [open $filename w]
    foreach histitem $corp::history_list {
	puts $file $histitem
    }
    close $file
}

#
# Named queries
#

proc namedquer_list {} {
    set r {}
    foreach i $corp::namedquer {
	lappend r [lindex $i 1]
    }
    return $r
}

proc namedquer_index {name} {
    set idx 0
    foreach item $corp::namedquer {
	if {[lindex $item 1] == $name} {
	    return $idx
	}
	incr idx
    }
    return -1
}

proc namedquer_select {name} {
    if {$name != ""} {
	set i [namedquer_index $name]
	if {$i < 0} {
	    set selitem [list "" $name]
	} else {
	    set selitem [lindex $corp::namedquer $i]
	    set corp::namedquer [lreplace $corp::namedquer $i $i]
	    lappend corp::namedquer $selitem
	}
	set_hist_item $selitem
    }
}

proc namedquer_up {} {
    set i [namedquer_index $corp::qrlabel]
    if {$i < 0} {
	set i end
    } elseif {$i > 0} {
	incr i -1
    }
    set_hist_item [lindex $corp::namedquer $i]
}

proc namedquer_down {} {
    set i [namedquer_index $corp::qrlabel]
    if {$i < 0} {
	return
    } elseif {$i == [llength $corp::namedquer]} {
	set_hist_item {}
	return
    }
    incr i
    set_hist_item [lindex $corp::namedquer $i]
}

proc addtoNamedQueries {histitem} {
    set name [lindex $histitem 1]
    if {$name != ""} {
	set i [namedquer_index $name]
	if {$i >= 0} {
	    set corp::namedquer [lreplace $corp::namedquer $i $i]
	}
	lappend corp::namedquer $histitem
    }
}

proc listNamedWindow {} {
    set w .listoft
    set lw $w.lfr.list
    makeDialogWindow $w [list delete "listNamedDelete $lw" close]

    frame $w.lfr -borderwidth 10
    pack $w.lfr -in $w.frame -side top -expand yes -fill y

    scrollbar $w.lfr.scroll -command "$lw yview"
    listbox $lw -yscroll "$w.lfr.scroll set" \
	    -setgrid 1 -exportselection no
    pack $lw $w.lfr.scroll -side left -fill y -expand 1

    bind $lw <Double-1> "destroy $w"
    bind $lw <1> "listNamedSelect $w @%x,%y"

    listNamedUpdate $lw
}

proc listNamedUpdate {lw} {
    $lw delete 0 end
    set maxlen 0
    foreach q $corp::namedquer {
	set l [string length [lindex $q 1]]
	if {$l > $maxlen} {
	    set maxlen $l
    }   }
    incr maxlen 3
    foreach q $corp::namedquer {
	foreach {q1 q2} $q break
	$lw insert end [format "%-*s%s" $maxlen $q2 $q1]
    }
}

proc listNamedDelete {lw} {
    set i [$lw curselection] 
    if {$i != ""} {
	set corp::namedquer [lreplace $corp::namedquer $i $i]
	listNamedUpdate $lw
    }
}

proc listNamedSelect {w idx} {
    set lw $w.lfr.list
    set i [$lw index $idx]
    $lw selection clear 0 end
    $lw selection set $i
    set q [lindex $corp::namedquer $i]
    set corp::query [lindex $q 0]
    set corp::qrlabel [lindex $q 1]
}

proc loadNamedQueries {filename} {
    set file [open $filename]
    while {![eof $file]} {
	gets $file line
	if {[llength $line] > 1} {
	    addtoNamedQueries $line
	}
    }
    close $file
}

proc saveNamedQueries {filename} {
    set file [open $filename w]
    foreach q $corp::namedquer {
	puts $file $q
    }
    close $file
}

proc exportNamedQueries {} {
    set filename [tk_getSaveFile -defaultextension .qry \
	    -filetypes $opt::namedquerext]
    if {$filename != ""} {
	saveNamedQueries $filename
    }
}

proc loadnewNamedQueries {} {
    set filename [tk_getOpenFile -defaultextension .qry \
	    -filetypes $opt::namedquerext]
    if {$filename != ""} {
	loadNamedQueries $filename
    }
}
