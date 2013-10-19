#  bonito:
# 	$Id: commlib.tcl,v 1.10 2002/12/01 11:30:42 pary Exp $	
#
#  Copyright (c) 2000-2002  Pavel Rychly

package provide commlib 1.0

proc comm:evalcommand {command} {
    #puts "CQS-beg: >>$command<< ([info level 1])"
    if {!$corp::conected || $corp::servreading} {
	bell
	#puts -nonewline "evalcommand: >>$command<< ("
	#for {set i [expr [info level]-1]} {$i > 0} {incr i -1} {
	#    puts -nonewline "> [lindex [info level $i] 0] "
	#}
	#puts ")"
	return ""
    }
    puts $corp::sock $command
    flush $corp::sock

    set corp::servreading 1
    set res [comm:readresult]
    set corp::servreading 0
    #puts "CQS-end: >>$command<< >>$res<<"
    return [string trim $res]
}

proc comm:appendlineevent {} {
    while {[gets $corp::sock line] >= 0} {
	append corp::sock_read "\n" $line
	if {[string last "\v" $line] >= 0} break
    }
    if [eof $corp::sock] {
	fileevent $corp::sock readable {}
	append corp::sock_read "\v"
	set corp::conected 0
    }
}

proc comm:readresult {} {
    set corp::sock_read {}
    fileevent $corp::sock readable comm:appendlineevent

    while {[string last "\v" $corp::sock_read] < 0} {
	#puts -nonewline cekam
	tkwait variable corp::sock_read
	#puts jedu
    }
    fileevent $corp::sock readable {}
    return [string trimright $corp::sock_read "\v"]
}

proc comm:startcommand {command} {
    if {!$corp::conected || $corp::servreading} {
	bell
	return ""
    }
    #puts "CQS-start: >>$command<<"
    puts $corp::sock $command
    flush $corp::sock
    set corp::linesend 0
    set corp::servreading 1
    set corp::sock_read {}
}

proc comm:getline {} {
    if $corp::linesend {
	bell
	return
    }
    if {$corp::read_stop > 0} {
	#puts "CQS-stop: getline - read_stop"
	comm:readresult
	comm:readresult
	set corp::read_stop 0
	set corp::linesend 1
	set corp::servreading 0
	return ""
    }
    if {$corp::sock_read != ""} {
	set line "$corp::sock_read\n[gets $corp::sock]"
    } else {
	set line [gets $corp::sock]
    }

    #while {![fblocked $corp::sock] && ![eof $corp::sock] \
    #	     && ![info complete $line]} {
    #	 append line "\n" [gets $corp::sock]
    #}
    #if {[fblocked $corp::sock]} {
    #	after 50
    #}
    #puts "LINE: >>$line<< eof:[eof $corp::sock] fblocked:[fblocked $corp::sock]"
    if {[string last "\v" $line] >= 0 || [eof $corp::sock]} {
	set line ""
	set corp::linesend 1
	set corp::servreading 0
	#puts "CQS-stop: end"
    }
    #if [info complete $line] {
	set corp::sock_read ""
	return $line
    #} else {
    #	 set corp::sock_read $line
    #	 return ""
    #}
}

proc comm:stop {} {
    if !$corp::servreading {
	anim:stop
	set corp::pending 0
    } elseif !$corp::read_stop {
	puts $corp::sock "stop"
	flush $corp::sock
	set corp::read_stop 1
    }
}

proc comm:listcorpora {} {
    if {!$corp::conected} {return ""}
    return [comm:evalcommand "lscorp"]
}

proc comm:getlabvallist {cachevar command} {
    upvar \#0 $cachevar cache

    if {[info exists cache($corp::name)]} {
	return $cache($corp::name)
    }
    if {!$corp::conected} {return ""}
    set res {}
    foreach line [split [comm:evalcommand "$command $corp::name"] "\n"] {
	foreach {val lab} [split $line "\t"] break
	if {$lab == ""} {
	    set lab $val
	}
	lappend res [list $lab $val]
    }
    set cache($corp::name) $res
    return $res
}

proc comm:listatriblab {} {
    return [comm:getlabvallist corp::cachedattrib lsdpos]
}
    
proc comm:listtagslab {} {
    return [comm:getlabvallist corp::cachedtags lsdstr]
}

proc comm:liststrattrlab {} {
    return [comm:getlabvallist corp::cachedstrattr lsdstrattr]
}

proc comm:listatrib {} {
    if {!$corp::conected} {return ""}
    return [comm:evalcommand "lsdpos $corp::name"]
}
    
proc comm:listtags {} {
    if {!$corp::conected} {return ""}
    return [comm:evalcommand "lsdstr $corp::name"]
}
    
proc comm:liststrattr {} {
    if {!$corp::conected} {return ""}
    return [comm:evalcommand "lsdstrattr $corp::name"]
}
    
proc comm:corpinfo {} {
    set r [comm:evalcommand "info $corp::name"]
    if {[llength $r] < 2 } {
	set r [list $corp::name ""]
    }
    return $r
}

proc comm:corpconfitem {item} {
    if {!$corp::conected} {return ""}
    return [comm:evalcommand "corpconf $corp::name $item"]
}
    
proc comm:corpfreq {attr value {regexp 0}} {
    if {$regexp} {
	regsub -all {\"} $value {\\&} vv
	return [comm:evalcommand "count $corp::name \[$attr=\"$vv\"\]"]
    } else {
	return [comm:evalcommand "freq $corp::name $attr $value"]
    }
}

proc comm:corpbigram {attr1 val1 attr2 val2 {from 1} {to 1} {regexp 0}} {
    if {$regexp} {
	regsub -all {\"} $val1 {\\&} v1
	regsub -all {\"} $val2 {\\&} v2
    } else {
	regsub -all {[\]\[.?*+\"{}]} $val1 {\\&} v1
	regsub -all {[\]\[.?*+\"{}]} $val2 {\\&} v2
    }
    return [comm:evalcommand "count $corp::name MU (meet \[$attr1=\"$v1\"\] \[$attr2=\"$v2\"\] $from $to)"]
}
    
proc comm:login {inetserver host port {name ""} {passwd ""}} {
    catch {close $corp::sock}
    set corp::conected 0
    set corp::servreading 0
    catch {unset corp::cachedattrib}
    catch {unset corp::cachedtags}
    catch {unset corp::cachedstrattr}
    
    if {[catch {
	if {$inetserver} {
	    set corp::sock [socket -async $host $port]
	} else {
	    set corp::sock [open "|$host" r+]
	}   
    } errcode]} {
	return "err_internal:$errcode"
    }

    if {$inetserver && [set errcode [fconfigure $corp::sock -error]] != ""} {
	return "err_internal:$errcode"
    }

    fconfigure $corp::sock -blocking 0
    set corp::conected 1
    if {$inetserver} {
	set ret [string trim [comm:evalcommand "user $name $passwd"]]
	if {$ret != "OK." && $ret != ""} {
	    set corp::conected 0
	    close $corp::sock
	    return $ret
	}
    }
    return ""
}
