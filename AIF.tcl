# vim: set expandtab tabstop=4 shiftwidth=4:
#
#  I like Vim (http://www.vim.org) as a text editor.  The above line
#  tells Vim to set the indent to 4 spaces and the tab key to indent
#  4 spaces.
# 
#  Pad.tcl
#
#  Tcl based Mentor Graphics Automation solution to Import an AIF file and
#  generate Pad, Padstack, Cell, and PDB to be used in a IC Package design.
#  This script should be run with "wish" or "tclsh" - it cannot be dragged
#  onto LM.
#
#  This script requires Tcl 8.4.20.  Tcl 8.5.x and 8.6.x are not supported
#  by the Mentor Graphics COM API interface.  You can download Tcl 8.4.20
#  from ActiveState.com:
#
#    http://www.activestate.com/activetcl/downloads
#
#
#  (c) July 2014 - Mentor Graphics Corporation
#
#  Mike Walsh - mike_walsh@mentor.com
#
#  Mentor Graphics Corporation
#  1001 Winstead Drive, Suite 380
#  Cary, North Carolina 27513
#
#  This software is NOT officially supported by Mentor Graphics.
#
#  ####################################################################
#  ####################################################################
#  ## The following  software  is  "freeware" which  Mentor Graphics ##
#  ## Corporation  provides as a courtesy  to our users.  "freeware" ##
#  ## is provided  "as is" and  Mentor  Graphics makes no warranties ##
#  ## with  respect  to "freeware",  either  expressed  or  implied, ##
#  ## including any implied warranties of merchantability or fitness ##
#  ## for a particular purpose.                                      ##
#  ####################################################################
#  ####################################################################
#
#  Change Log:
#
#    07/20/2014 - Initial version.  Moved AIF processing and info to a
#                 separate file and namespace to ease code maintenance.
#

##
##  Define the AIF namespace and procedure supporting parsing operations
##
namespace eval AIF {
    variable version 1.0

    variable sections [list DEFAULT]

    variable cursection DEFAULT
    variable DEFAULT;   # DEFAULT section

    proc Sections {} {
        variable sections
        return ::AIF::$sections
    }
    
    proc Variables {{section DEFAULT}} {
        return [array names ::AIF::$section]
    }
    
    proc AddSection {str} {
        variable sections
        variable cursection
    
        set cursection [string trim $str \[\]]
        if {[lsearch -exact $sections $cursection] == -1} {
            lappend sections $cursection
            variable ::AIF::${cursection}
        }
    }
    
    proc SetVar {varname value {section DEFAULT}} {
        variable sections
        if {[lsearch -exact $sections $section] == -1} {
          AddSection $section
        }
        set ::AIF::${section}($varname) $value
    }
    
    proc GetVar {varname {section DEFAULT}} {
        variable sections
        if {[lsearch -exact $sections $section] == -1} {
            error "No such section: $section"
        }
        return [set ::AIF::${section}($varname)]
    }
    
    
    ##
    ##  init
    ##
    ##  Reset the parsing data structures for subsequent file loads
    ##
    proc Init { } {
        variable sections
        variable cursection
    
        foreach section $sections {
            if { $section == "DEFAULT" } continue
    
            if { [info exists ::AIF::${section}] } {
                unset ::AIF::${section}
            }
        }
        set sections { }
    }
    
    proc Parse {filename} {
        variable sections
        variable cursection
    
        #  Reset data structure
        Init
    
        #  Reset Netlist tab
        set txt $::widgets(netlistview)
        $txt configure -state normal
        $txt delete 1.0 end
    
        set line_no 0
        set fd [open $filename r]
        while {![eof $fd]} {
            set line [string trim [gets $fd] " "]
            incr line_no
            if {$line == ""} continue
    
            ##  Handle [NETLIST] section special case
            ##
            ##  Need to insert the "=" character into the net definitions
            ##  so the standard parser will pick each of them up.
            ##
    
            if { $cursection == "NETLIST" && [ regexp {^[[:alpha:][:alnum:]_]*\w} $line net ] } {
                #puts [format "Net?  %s" $net]
    
                #set line [format "%s=%s" [string trim $net] [string trimleft $line [string length $net]]]
                $txt insert end "$line\n"
                $txt see end
                continue
            }
    
            ##  Look at each line and process sections versus section variables
    
            switch -regexp -- $line {
                ^;.* { }
                ^\\[.*\\]$ {
                    AddSection $line
                }
                .*=.* {
                    set pair [split $line =]
                    set name [string trim [lindex $pair 0] " "]
                    set value [string trim [lindex $pair 1] " "]
                    SetVar $name $value $cursection
                } 
                default {
                    #error "Error parsing $filename (line: $line_no): $line"
                    Transcript $::ediu(MsgWarning) [format "Skipping line %d in AIF file \"%s\"." $line_no $::ediu(filename)]
                    puts $line
                }
            }
        }
    
        # Cleanup the netlist, sort it and eliminate duplicates
        set nl [lsort -unique [split [$txt get 1.0 end] '\n']]
        $txt delete 1.0 end
        foreach n $nl {
            if { $n != "" } {
                $txt insert end "$n\n"
            }
        }
    
        # Force the scroll to the top of the netlist view
        $txt yview moveto 0
        $txt xview moveto 0
    
        $txt configure -state disabled
        close $fd
    }
}
