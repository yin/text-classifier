#  bonito:
# 	$Id: outres.tcl,v 1.10 2003/04/23 17:54:41 pary Exp $	
#
#  Copyright (c) 2000-2003  Pavel Rychly

package provide outres 1.0
package require attrib 1.0

proc makeWritefileWindow {w} {
    if {![info exists corp::octx]} {
	array set corp::octx [array get corp::ctx]
    }
    makeDialogWindow $w [list ok "finishWritefile $w" \
	    chctx "contextWindow .octxwin $w corp::octx" close]
    
    makeMenuButon $w.encoding corp::outputenc $opt::outencodings
    pack [frame $w.frame.enc] -anchor w
    pack [label $w.enclbl] $w.encoding \
	    -in $w.frame.enc -side left -pady 10 -padx 3

    set headers {}
    set files [glob -nocomplain [file join $opt::libdir "*.hdr"]]
    if {$opt::libdir != $::sourcedir} {
	set files [concat $files \
		       [glob -nocomplain [file join $::sourcedir "*.hdr"]]]
    }
    foreach f $files {
	# /path/to/simple.lang.hdr
	set h [file rootname [file rootname [file tail $f]]]
	if {[lsearch -exact $headers $h] == -1} {
	    lappend headers $h
	}
    }

    makeMenuButon $w.header corp::outheader [getOptionList $w.hdrs $headers]
    pack [frame $w.frame.head] -anchor w
    pack [label $w.headlbl] $w.header \
	    -in $w.frame.head -side left -pady 10 -padx 3

    set corp::outputsel viewed
    set corp::alignkwic 1
    radiobutton $w.selected -variable corp::outputsel -value viewed
    radiobutton $w.alllines -variable corp::outputsel -value whole
    checkbutton $w.linenumbers -variable corp::linenumbers
    checkbutton $w.alignkwic -variable corp::alignkwic
    pack $w.selected $w.alllines $w.linenumbers $w.alignkwic \
	    -in $w.frame -side top  -anchor w
    
}

proc saveToFile {} {
    set w .writefile
    makeWritefileWindow $w

    set corp::outputfile ""
}

proc finishWritefile {w} {
    if {$corp::outputfile == ""} {
	set corp::outputfile [tk_getSaveFile -parent $w]
    }
    destroy $w
    if {$corp::outputfile != ""} {
	set corp::outfileid [open $corp::outputfile w]
	if {$corp::outputenc == "-"} {
	    set corp::outputenc [fconfigure $corp::sock -encoding]
	}
	fconfigure $corp::outfileid -encoding $corp::outputenc
	set ctxleft [composeContext $corp::octx(left) $corp::octx(lunit)]
	set ctxright [composeContext $corp::octx(right) $corp::octx(runit)]
	initOutput outfile $corp::outputsel "-$ctxleft $ctxright"
    }
}

proc print {} {
    set w .print
    makeWritefileWindow $w
    set corp::tempfile [file join $opt::libdir _print_.tmp]

    if [string match "|*" $opt::printer] {
	set corp::outputfile $opt::printer
    } else {
	set corp::outputfile $corp::tempfile
    }
}


proc substituteheader {header} {
    if {$header == "none"} return
    if {$header != ""} {
	set path [file join $opt::libdir "$header.$opt::language.hdr"]
	if {![file readable $path]} {
	    set path [file join $::sourcedir "$header.$opt::language.hdr"]
	    if {![file readable $path]} {
		set path [file join $opt::libdir "$header.hdr"]
		if {![file readable $path]} {
		    set path [file join $::sourcedir "$header.hdr"]
		}
	    }
	}
    }
    if {$header == "" || ![file readable $path]} {
	set headsrc {#------------------------------------------------------------
#
# Corpus  : $corpus
# Query   : $query
# Expanded: $expanded
#
# Size    : $resultlen
# Context : left $leftcontext, right $rightcontext
#
# User    : $user
# Date    : $date
#
#------------------------------------------------------------
	}
    } else {
	set headsrc [read_with_enc $path]
    }
    set corpus $corp::name
    foreach {query label expanded} [lindex $corp::resultsteps 1] break
    set steps [join [conc_info_str $corp::resultsteps] "\n# "]
    set resultlen $corp::resultlen
    set user $corp::user
    set date [clock format [clock seconds] -format $opt::dateformat]
    set leftcontext "$corp::octx(left) [getOption $corp::octx(lunit) .genstring]" 
    set rightcontext "$corp::octx(right) [getOption $corp::octx(runit) .genstring]"
    return [subst -nocommands $headsrc]
}


proc outfile_init {} {
    puts $corp::outfileid [substituteheader $corp::outheader]
    array set corp::maxwidth {struct 0 pre 0 in 0}
    set corp::outstr ""
    set corp::currlinenum 1
    if {$corp::linenumbers} {
	set corp::linenumbers 2
    }
}


proc outfile_add {words part prevpart} {
    set outstr $corp::outstr 
    if {$corp::linenumbers == 2} {
	puts -nonewline $corp::outfileid "$corp::currlinenum: "
	set corp::linenumbers 1
    }
    if {$part != $prevpart} {
	if {$corp::alignkwic || $prevpart == "in"} {
	    switch -exact -- $prevpart {
		struct {
		    # zarovname na max velikost doleva
		    if {$corp::maxwidth(struct) <= [string length $outstr]} {
			set corp::maxwidth(struct) \
				[expr [string length $outstr] +1]
			append outstr " "
		    } else {
			set outstr [format "%-*s" $corp::maxwidth(struct) $outstr]
		    }
		}
		pre {
		    # zarovname na max velikost doprava
		    if {$corp::maxwidth(pre) < [string length $outstr]} {
			set corp::maxwidth(pre) [string length $outstr]
		    } else {
			set outstr [format "%*s" $corp::maxwidth(pre) $outstr]
		    }
		}
		in   { 
		    # hodime do zobaku
		    set outstr " <$outstr> "
		}

	    }
	}
	puts -nonewline $corp::outfileid $outstr
	set outstr ""
    } else {
	append outstr " "
    }
    foreach {word tag} $words {
	append outstr $word
    }
    if {$part == "post"} {
	puts -nonewline $corp::outfileid $outstr
	set corp::outstr ""
    } else {
	set corp::outstr $outstr
    }
}


proc outfile_done_line {} {
    puts $corp::outfileid ""
    if {!$corp::alignkwic} {
	puts $corp::outfileid ""
    }
    incr corp::currlinenum
    if {$corp::linenumbers} {
	set corp::linenumbers 2
    }
}

proc outfile_done_part {} {}
proc outfile_done_all {} {
    catch {close $corp::outfileid}
    if {$corp::outputfile == $corp::tempfile} {
	eval exec $opt::printer $corp::tempfile &
    }
    if {$corp::linenumbers} {
	set corp::linenumbers 1
    }
}


proc savetostring {ranges var} {
    set corp::outfileid $var
    set $var ""
    set corp::outheader none
    set corp::linenumbers 0
    set ctxleft [composeContext $corp::ctx(left) $corp::ctx(lunit)]
    set ctxright [composeContext $corp::ctx(right) $corp::ctx(runit)]
    set context "-$ctxleft $ctxright"
    foreach {beg end} $ranges {
	set corp::savetostringstopper 0
	initOutput tostring [list = $beg $end] $context
	tkwait variable corp::savetostringstopper
    }
}

proc tostring_init {} {
    array set corp::maxwidth {struct 0 pre 0 in 0}
    set corp::outstr ""
}


proc tostring_add {words part prevpart} {
    set outstr $corp::outstr 
    if {$part != $prevpart} {
	if {1 || $prevpart == "in"} {
	    switch -exact -- $prevpart {
		struct {
		    # zarovname na max velikost doleva
		    if {$corp::maxwidth(struct) < [string length $outstr]} {
			set corp::maxwidth(struct) [string length $outstr]
		    } else {
			set outstr [format "%-*s" $corp::maxwidth(struct) $outstr]
		    }
		}
		pre {
		    # zarovname na max velikost doprava
		    if {$corp::maxwidth(pre) < [string length $outstr]} {
			set corp::maxwidth(pre) [string length $outstr]
		    } else {
			set outstr [format "%*s" $corp::maxwidth(pre) $outstr]
		    }
		}
		in   { 
		    # hodime do zobaku
		    set outstr " <$outstr> "
		}

	    }
	}
	append $corp::outfileid $outstr
	set outstr ""
    } else {
	append outstr " "
    }
    foreach {word tag} $words {
	append outstr $word
    }
    if {$part == "post"} {
	append $corp::outfileid $outstr
	set corp::outstr ""
    } else {
	set corp::outstr $outstr
    }
}


proc tostring_done_line {} {
    append $corp::outfileid "\n"
}

proc tostring_done_part {} {}
proc tostring_done_all {} {
    set corp::savetostringstopper 1
}
