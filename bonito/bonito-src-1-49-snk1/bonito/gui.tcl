#  bonito:
#     $Id: gui.tcl,v 1.44 2003/09/16 07:06:54 pary Exp $
#
#  Copyright (c) 2000-2003  Pavel Rychly

package provide gui 1.0

package require attrib 1.0
package require combobox 1.0
package require commlib 1.0
package require menu 1.0
package require TextList 1.0
package require tools 1.0
package require	result 1.0
package require	outres 1.0
package require	detail 1.0
package require	query 1.0
package require	sort 1.0
package require	freq 1.0
package require corpus 1.0
package require concord 1.0
package require graph 1.0
package require colloc 1.0
package require setopt 1.0
package require wordlist 1.0

proc makeCorpList {} {
    global sel_corp_name
    #catch {destroy .corplist}
    set availcorpora [comm:listcorpora]
    if {$sel_corp_name == ""} {
	set sel_corp_name $opt::defcorp
    }
    makeMenuButon .corplist sel_corp_name $availcorpora
    #pack .corplist -in .queryfr -side left -fill y
}

proc updateCorpVars args {
    global sel_corp_name
    if {$sel_corp_name != $corp::name} {
	if {!$corp::restoring} store_conc
	catch {.list delete 0.0 end}
	catch {.detail.list delete 0.0 end}
	set corp::sellines {}
	set corp::name $sel_corp_name
	set corp::attribs {}
	#[lindex [comm:listatrib] 0]
	set corp::tags {}
	set corp::refs {}
	set corp::stats {}
	set corp::maxcoll 0
	set corp::resultsteps {}
	set corp::resultlen 0
	set corp::displayedfrom 0
	set corp::displayedto 0
	makeConcCollButton
	if {$corp::name != ""} {
	    catch {fconfigure $corp::sock -encoding \
		       [comm:evalcommand "encoding $corp::name"]}
	    catch {canRebuild $corp::name}
	}
    }
    set corp::status ""
}

namespace eval corp {
    variable name {} attribs {} tags {} stats {}
    variable servercolname query
    variable resultlen 0 maxcoll 0 collindex 1
    variable displayedto 0 displayedfrom 0 querytyperesult 0
    variable ctx
    variable refs ""
    variable showattrs 0 showstrucvals 0
    variable rngcount 50 rngfrom first
    variable ssrtfrom beforebeg ssrtpos 1 ssrticase 1 ssrtrtrg 0
    variable frqd_limit 0
    variable reducecount 500 reducefrom first reduceunit lines
    variable query {} qrlabel "" qrgraph {}
    variable conected 0 servreading 0 linesend 1
    variable statsword1 {} statsword2 {}
    variable detailincr 15
    variable read_stop 0
    variable restoring 0
    variable sellines {}
    variable tempfile "#####"
    variable pendcommad 0
    variable collfrom 1 collto 1 collregexp 0
}

proc set_defaults {} {
    array set corp::ctx [list left $opt::defctx right $opt::defctx \
	    lunit chars runit chars]
    set corp::rngcount $opt::defrange
}
    

set sel_corp_name ""
trace variable sel_corp_name w updateCorpVars
#trace variable corp::query w updateCorpVars



proc makeWindow {setgeometry} {
    global sourcedir
    set_defaults
    kdMakeMenu .mb {} [read_with_enc [get_configfilename $opt::language menu]]
    . config -menu .mb
    pack [set f [frame .queryfr]] -side top -fill x -expand no
    pack [makeConcCollButton] -side left
    
    bind . <Control-q> {.queryfr.type.menu invoke 0;focus .queryfr.query.entry}
    bind . <Control-p> {.queryfr.type.menu invoke 1;focus .queryfr.query.entry}
    bind . <Control-n> {.queryfr.type.menu invoke 2;focus .queryfr.query.entry}

    combobox $f.query history_list "" -textvar corp::query
    combobox $f.qrlabel namedquer_list namedquer_select -textvar corp::qrlabel
    pack $f.query -side left -expand yes -fill x
    pack [label $f.qrname] $f.qrlabel -side left -expand no

    bind $f.query.entry <Return> processQuery
    bind $f.query.entry <Up> history_up
    bind $f.query.entry <Down> history_down
    bind $f.qrlabel.entry <Up> namedquer_up
    bind $f.qrlabel.entry <Down> namedquer_down
    bind $f.qrlabel.entry <Return> processQuery

    makeCorpList
    pack .corplist -in .queryfr -side left

    pack [frame .collrangefr] -side top -fill x
    pack [frame .collrange] -in .collrangefr -side left
    radiobutton .collrange.first -variable corp::collindex -value 1
    radiobutton .collrange.last -variable corp::collindex -value -1
    pack .collrange.first .collrange.last \
	    [makerangeedgeframe .collrange.left corp::coll left] \
	    [makerangeedgeframe .collrange.right corp::coll right] -side left
    hide_show_collrange

    pack [label .status -anchor w -textvariable corp::status -relief sunken] \
	    -side bottom -fill x -expand no -padx 5 -pady 3
    
    makeListBox
    makeDetailView

    bind . <F12> {
	if {[focus] == ".queryfr.query.entry"} {
	    focus .list
	} else {
	    focus .queryfr.query.entry
    }   }
    bind .list <Double-1> showDetail
    bind .list <Return> showDetail
    bind .list <3> {
	tlist:moveline .list @%x,%y +0
	showFullref
    }
    bind .list <Control-Return> showFullref
    bindtags . [concat [bindtags .] BonitoApp]
    bind BonitoApp <Destroy> exitApp
    focus .queryfr.query.entry

    if {$setgeometry} {
	wm geometry . $corp::wingeometry(.)
    }
}


proc exitApp {} {
    bind BonitoApp <Destroy> {}
    if {$corp::conected} {
	catch {
	    puts $corp::sock "exit"
	    close $corp::sock
	}
    }
    catch {saveTemplates [file join $opt::libdir $opt::templatefile]}
    catch {saveHistory [file join $opt::libdir $opt::historyfile]}
    catch {saveNamedQueries [file join $opt::libdir $opt::namedquerfile]}
    if {$opt::savegeometry && [winfo children .] != ""} {
	set corp::wingeometry(.) [wm geometry .]
	catch {
	    save_one_option savedgeometry [array get corp::wingeometry]
	}
    }
    destroy .
    exit
}

proc login {{w .login}} {
    global env
    set corp::passwd ""
    set corp::inetserver $opt::inetserver
    set corp::servercommand $opt::servercommand
    
    
    makeDialogWindow $w
    grid [frame $w.connect] -columnspan 2 -in $w.frame
    radiobutton $w.internet -variable corp::inetserver -value 1 -command {
	.login.command config -fg gray40
	.login.ecommand config -fg gray40 -state disabled
	.login.host config -fg black
	.login.ehost config -fg black -state normal
	.login.user config -fg black
	.login.euser config -fg black -state normal
	.login.passwd config -fg black
	.login.epasswd config -fg black -state normal
    }
    radiobutton $w.localcmd -variable corp::inetserver -value 0 -command {
	.login.command config -fg black
	.login.ecommand config -fg black -state normal
	.login.host config -fg gray40
	.login.ehost config -fg gray40 -state disabled
	.login.user config -fg gray40
	.login.euser config -fg gray40 -state disabled
	.login.passwd config -fg gray40
	.login.epasswd config -fg gray40 -state disabled
    }

    pack $w.internet $w.localcmd -side left -in $w.connect

    grid [label $w.host ] [entry $w.ehost -textvar corp::host] -sticky w \
	    -in $w.frame
    grid [label $w.user -anchor w ] [entry $w.euser -textvar corp::user] \
	    -in $w.frame -sticky w
    grid [label $w.passwd -anchor w ] [entry $w.epasswd \
	    -textvar corp::passwd -show *]  -in $w.frame -sticky w
    grid [label $w.command -anchor w ] [entry $w.ecommand \
	    -textvar corp::servercommand]  -in $w.frame -sticky w
    
    $w.ok configure -command "destroy $w; initconnection"
    if {$corp::inetserver} {
	$w.internet invoke
	if {$corp::user == ""} {
	    focus $w.euser
	} else {
	    focus $w.epasswd
	}
    } else {
	$w.localcmd invoke
	focus $w.ecommand
    }
}

proc initconnection {} {
    if {$corp::inetserver} {
	set err [comm:login 1 $corp::host $opt::serverport \
		$corp::user $corp::passwd]
    } else {
	if {![info exists ::env(SUBCORPDIR)]} {
	    set ::env(SUBCORPDIR) $opt::subcorpdir
	}
	if {![file isdirectory $::env(SUBCORPDIR)]} {
	    file mkdir $::env(SUBCORPDIR)
	}
	set err [comm:login 0 $corp::servercommand ""]
    }
    if {$err == ""} {
	set corp::store_conc {}
	set corp::resultlen 0
	set corp::name ""
	makeCorpList
    } else {
	set w .loginerr
	makeDialogWindow $w [list ok "destroy $w"]
	set errcode [string range $err 0 [string first : $err]]
	if {$errcode != ""} {
	    set errmsg [getOption \
		    [string tolower [string trim $errcode :]] .loginerr]
	    if {$errcode == "err_internal:"} {
		set err [string range $err [expr [string first : $err] +1] end]
		set err "$errmsg:\n$err"
	    } else {
		set err $errmsg
	    }
	}
	pack [label $w.err -text $err] -in $w.frame
    }
}
    
proc change_passwd {{w .chpasswd}} {
    set corp::oldpasswd ""
    set corp::newpasswd ""
    set corp::retypepasswd ""
    
    makeDialogWindow $w [list ok "finish_change_passwd $w" close]

    pack [frame $w.old] -side top -padx 5 -pady 5 -in $w.frame -anchor e
    pack [label $w.old.lbl -anchor w ] -side left
    pack [entry $w.old.enr -width 15 -textvar corp::oldpasswd -show *] \
	    -side left

    pack [frame $w.new] -side top -padx 5 -pady 5 -in $w.frame -anchor e
    pack [label $w.new.lbl -anchor w ] -side left
    pack [entry $w.new.enr -width 15 -textvar corp::newpasswd -show *] \
	    -side left
    pack [frame $w.retype] -side top -padx 5 -pady 5 -in $w.frame -anchor e
    pack [label $w.retype.lbl -anchor w ] -side left
    pack [entry $w.retype.enr -width 15 -textvar corp::retypepasswd -show *] \
	    -side left
    
    focus $w.old.enr
}

proc finish_change_passwd {w} {
    if {$corp::newpasswd != $corp::retypepasswd} {
	tk_messageBox -message [getOption diffpass $w] -type ok \
		-title [getOption title $w]
	return
    }
    destroy $w
    set res [comm:evalcommand "passwd $corp::newpasswd $corp::oldpasswd"]
    #puts "res:>>$res<<"
    if {$res == ""} {
	tk_messageBox -message [getOption changed $w] -type ok \
		-title [getOption title $w]
    } else {
	tk_messageBox -message [getOption error $w] -type ok \
		-title [getOption title $w]
    }	
}

proc aboutWin {} {
    set w .aboutwin 
    makeDialogWindow $w [list ok "destroy $w"]
    label $w.ver
    $w.ver configure -text "[$w.ver cget -text] [getOption version $w]"
    set text [subst -nocommands -novariables [getOption message $w]]
    pack [label $w.bonito] $w.ver [label $w.msg -text $text] -in $w.frame
}

proc showLicense {} {
    set w .licensewin 
    makeDialogWindow $w [list ok "destroy $w"]
    if {[glob -nocomplain license.txt] != ""} {
	set text [read_with_enc license.txt]
    } else {
	set text [subst -nocommands -novariables [getOption message $w]]
    }
    pack [label $w.msg -text $text] -in $w.frame
}


proc runDocumentation {} {
    global sourcedir
    set docfile [file nativename [file join $sourcedir doc $opt::docstartname]]
    exec $opt::runbrowser $docfile &
}


proc get_configfilename {lang basename} {
    set f [file join $::sourcedir $basename]
    if {$::tk_version >= 8.2 && $basename == "resource"} {
	set suff utf
    } else {
	set suff [string range $::tcl_platform(platform) 0 2]
    }
    if [file readable $f.$lang$suff] {
	return $f.$lang$suff
    } elseif [file readable $f.$lang] {
	return $f.$lang
    } else {
	return $f
    }
}

proc load_language_resource {} {
    set f [file join $::sourcedir \
	    resource.[string range $::tcl_platform(platform) 0 2]]
    if {[file readable $f]} {
	option readfile $f startupFile
    }
    option readfile [get_configfilename $opt::language resource] startupFile
}

proc changeLanguage {lang} {
    if {![file readable [get_configfilename $lang menu]]} {
	return
    }
    set balloon $opt::bhelpenabled
    set opt::bhelpenabled 0
    set corp::qtype conc
    unset ::globopt
    array set ::globopt {}
    set corp::wingeometry(.) [wm geometry .]
    eval destroy [winfo children .]
    set opt::language $lang

    set f [file join $::sourcedir resource]
    option readfile $f widgetDefault
    load_language_resource
    makeWindow 1
    hide_show_collrange
    set opt::bhelpenabled $balloon
    resource2options $opt::alloptions
    set opt::language $lang
    save_one_option language $lang rc
    #refreshResult
}


proc changeLanguageWin {{w .chlang}} {
    makeDialogWindow $w [list ok "changeLanguageWinfinish $w" close]
    pack [label $w.newlbl] [listbox $w.lang] \
	    -side top -in $w.frame -padx 15 -pady 5
    eval $w.lang insert 0 $opt::availlanguages
    $w.lang selection set [lsearch -exact $opt::availlanguages $opt::language]
}

proc changeLanguageWinfinish {w} {
    set lang [$w.lang get [$w.lang curselection]]
    destroy $w
    changeLanguage $lang
}

proc read_with_enc {filename} {
    set f [open $filename]
    set first [gets $f]
    if [string match "#encoding *" $first] {
	scan $first "#encoding %s" enc
	fconfigure $f -encoding $enc
	set first ""
    } else {
	set first "$first\n"
    }
    set data [read $f]
    close $f
    return "$first$data"
}

proc changeEncoding {} {
    if {[llength $opt::systemencodings] <= 1} return
    set enc [encoding system]
    set i [lsearch -exact $opt::systemencodings $enc]
    incr i
    if {[llength $opt::systemencodings] == $i} {
	set i 0
    }
    encoding system [lindex $opt::systemencodings $i]
}
