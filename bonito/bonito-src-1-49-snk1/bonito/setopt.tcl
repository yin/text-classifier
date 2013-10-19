#  bonito:
#     $Id: setopt.tcl,v 1.4 2003/04/23 17:58:48 pary Exp $
#
#  Copyright (c) 2000-2003  Pavel Rychly

package provide setopt 1.0

package require attrib 1.0



proc setopt_win {} {
    global setoption
    set w .setopt
    makeDialogWindow $w {apply apply_options save save_options close}
    namespace eval setoption {}
    foreach opt $opt::setoptions {
	if {[llength $opt] > 1} {
	    set comm [lindex $opt 1]
	    set opt [lindex $opt 0]
	    $comm $w.$opt -variable setoption($opt)
	    grid $w.$opt -sticky w -in $w.frame -columnspan 2
	} else {
	    set o $w.$opt
	    entry $o -textvariable setoption($opt)
	    grid [label ${o}lbl] $o -sticky w -in $w.frame
	}
	set setoption($opt) [set opt::$opt]
    }
}


namespace eval opt {}

proc resource2options {optlist} {
    foreach opt $optlist {
	set opt::$opt [getOption $opt .options]
    }
}


proc apply_options {} {
    global setoption
    foreach opt $opt::setoptions {
	set opt [lindex $opt 0]
	set opt::$opt $setoption($opt)
    }
    destroy .setopt
}

proc save_options {} {
    global setoption
    apply_options
    set optlist {}
    foreach opt $opt::setoptions {
	lappend optlist [lindex $opt 0]
    }
    set filename [file join $opt::libdir $opt::optionsfile]
    catch {file rename -force $filename $filename.bak}
    set fout [open $filename w]
    if ![catch {set fin [open $filename.bak]}] {
	while {![eof $fin]} {
	    gets $fin line
	    if {[regexp {^\*options\.([a-z]*):} $line _ opt] \
		    && [set i [lsearch -exact $optlist $opt]] >= 0 } {
		puts $fout "*options.$opt: $setoption($opt)"
		set optlist [lreplace $optlist $i $i]
	    } else {
		puts $fout $line
	    }
	}
	close $fin
    }
    foreach opt $optlist {
	if {$setoption($opt) != [getOption $opt .options]} {
	    puts $fout "*options.$opt: $setoption($opt)"
	}
    }
    close $fout
    destroy .setopt
}

proc save_one_option {optname value {config std}} {
    if {$config == "rc"} {
	global tcl_platform
	if {$tcl_platform(platform) == "unix"} {
	    set filename ~/.bonitorc
	} else {
	    set filename bonitorc
	}
    } else {
	set filename [file join $opt::libdir $opt::optionsfile]
    }
    set fout [open $filename.new w]
    if {![catch {set fin [open $filename r]}]} {
	while {![eof $fin]} {
	    gets $fin line
	    if {$line != "" && ![string match "\\*options.$optname:*" $line]} {
		puts $fout $line
	    }
	}
	close $fin
    }
    puts $fout "*options.$optname: $value"
    close $fout
    file rename -force $filename.new $filename
}
