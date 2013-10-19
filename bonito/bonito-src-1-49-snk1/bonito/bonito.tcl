#!/bin/sh
# \
exec wish "$0" "$@"

#  bonito:
#     $Id: bonito.tcl,v 1.20 2003/12/08 09:47:42 pary Exp $
#
#  Copyright (c) 2000-2003  Pavel Rychly

wm withdraw .

catch {while {[file type $argv0] == "link"} {set argv0 [file readlink $argv0]}}
set sourcedir [file dirname $argv0]
if $tcl_interactive {
    set sourcedir ~/mlc/bonito
}

tk appname bonito
option clear
set read_user_conf 1
foreach {o v} $argv {
    switch -exact -- $o {
	-lang {option add *options.language $v}
	-dir {set sourcedir $v}
	-set-lang {
	    if {$tcl_platform(platform) == "unix"} {
		set optf [open ~/.bonitorc a]
	    } else {
		set optf [open bonitorc a]
	    }
	    puts $optf ""
	    puts $optf "*options.language:	$v"
	    close $optf
	}
	-no-user-config {
	    set read_user_conf 0
	}
	-corpus {
	    set start_corpus $v
	}
	-query {
	    set start_query $v
	}
	default {
	    puts "Unknown option: $o"
	}
    }
}


option readfile [file join $sourcedir resource] widgetDefault
if {$read_user_conf} {
    catch {option readfile $env(BONITO_CFG) userDefault}
    if {$tcl_platform(platform) == "unix"} {
	catch {option readfile ~/.bonitorc userDefault}
    } else {
	catch {option readfile bonitorc userDefault}
    }
}


lappend auto_path $sourcedir

package require query 1.0
package require gui 1.0
package require tools 1.0
package require balloon 1.0
package require setopt 1.0

resource2options language
load_language_resource
resource2options {libdir optionsfile alloptions}
if {$read_user_conf} {
    catch {option readfile [file join $opt::libdir $opt::optionsfile] \
	       userDefault}
}

resource2options $opt::alloptions
if {[info exists start_corpus]} {
    set opt::defcorp $start_corpus
}

namespace eval corp {
    set wingeometry(.) ""
    array set wingeometry $opt::savedgeometry
}

if {$read_user_conf && ![file isdirectory $opt::libdir]} {
    catch {file mkdir $opt::libdir}
}

catch {loadTemplates [file join $opt::libdir $opt::templatefile]}
catch {loadHistory [file join $opt::libdir $opt::historyfile]}
catch {loadNamedQueries [file join $opt::libdir $opt::namedquerfile]}

::balloon::Init opt::bhelpenabled $opt::bhelpdelay

makeWindow $opt::savegeometry
wm title . "Bonito"
wm minsize . 40 10
wm deiconify .
tkwait visibility .

proc correct_win_position {{w .}} {
    scan [wm geometry $w] "%dx%d+%d+%d" geom_w geom_h geom_x geom_y
    if {[expr $geom_h + [winfo rooty $w]] > [winfo vrootheight $w] || \
	    [winfo vrootheight $w] <= 600} {
	set geom_y 0
    }
    if {[expr $geom_w + [winfo rootx $w]] > [winfo vrootwidth $w]} {
	set geom_x [expr [winfo vrootwidth $w] - $geom_w -10]
	if {$geom_x < 0} {
	    set geom_x 0
	}
    }
    wm geometry $w "+$geom_x+$geom_y"
}

if {$opt::savegeometry} {
    wm geometry . $corp::wingeometry(.)
} else {
    correct_win_position
}

set corp::inetserver $opt::inetserver
set corp::host $opt::servername
set corp::servercommand $opt::servercommand
if [catch {set corp::user $env(USER)}] {
    set corp::user ""
}

if {$opt::systemencodings != ""} {
    encoding system [lindex $opt::systemencodings 0]
}

if {$opt::showlincese} {
    showLicense
}

if {$corp::inetserver || [catch initconnection]} {
    login
}

if {[info exists start_query]} {
    set corp::query $start_query
    processQuery
}
