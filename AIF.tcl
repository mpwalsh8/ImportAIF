# vim: set expandtab tabstop=4 shiftwidth=4:
#
#  I like Vim (http://www.vim.org) as a text editor.  The above line
#  tells Vim to set the indent to 4 spaces and the tab key to indent
#  4 spaces.
# 
#  AIF.tcl
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
        set txt $xAIF::GUI::Widgets(netlistview)
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
                    xAIF::GUI::Message -severity warning -msg [format "Skipping line %d in AIF file \"%s\"." $line_no $xAIF::Settings(filename)]
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

    namespace eval BGA {
        #
        #  AIF::BGA::Section
        #
        #  Scan the AIF source file for the "BGA" section
        #
        proc Section {} {
            ##  Make sure we have a BGA section!
            if { [lsearch -exact $::AIF::sections BGA] != -1 } {
                ##  Load the BGA section
                set vars [AIF::Variables BGA]

                foreach v $vars {
                    #puts [format "-->  %s" $v]
                    set xAIF::bga([string tolower $v]) [AIF::GetVar $v BGA]
                }

                ##  Default Package Cell to BGA
                set xAIF::Settings(PackageCell) $xAIF::bga(name)

                ##  Add the BGA to the list of devices
                set xAIF::mcmdie($xAIF::Settings(BGAREF)) $xAIF::bga(name)

                foreach i [array names xAIF::bga] {
                    xAIF::GUI::Message -severity note -msg [format "BGA \"%s\":  %s" [string toupper $i] $xAIF::bga($i)]
                }
            } else {
                xAIF::GUI::Message -severity error -msg [format "AIF file \"%s\" does not contain a BGA section." $xAIF::Settings(filename)]
                return -1
            }
        }
    }

    ##
    ##  Define the die namespace and procedure supporting die operations
    ##
    namespace eval Die {
        variable sections
        #
        #  Scan the AIF source file for the "DIE" section
        #
        proc Section {} {
            ##  Make sure we have a DIE section!
            if { [lsearch -exact $::AIF::sections DIE] != -1 } {
                ##  Load the DIE section
                set vars [AIF::Variables DIE]

                foreach v $vars {
                    #puts [format "-->  %s" $v]
                    set xAIF::die([string tolower $v]) [AIF::GetVar $v DIE]
                }

                foreach i [array names xAIF::die] {
                    xAIF::GUI::Message -severity note -msg [format "Die \"%s\":  %s" [string toupper $i] $xAIF::die($i)]
                }

                ##  Need a partition for Cell and PDB generaton when  in CL mode
                #set xAIF::die(partition) [format "%s_die" $xAIF::die(name)]

            } else {
                xAIF::GUI::Message -severity error -msg [format "AIF file \"%s\" does not contain a DIE section." $xAIF::Settings(filename)]
                return -1
            }
        }
    }

    ##
    ##  Define the MCM die namespace and procedure supporting die operations
    ##
    namespace eval MCMDie {

        #
        #  Get All Die references
        #
        proc GetAllDie {} {
            return [array names xAIF::mcmdie]
        }

        #  AIF::MCMDie::Section
        #
        #  Scan the AIF source file for the "MCM_DIE" section
        #
        proc Section {} {
            set rv 0

            ##  Make sure we have a MCM_DIE section!

            if { [lsearch -exact $::AIF::sections MCM_DIE] != -1 } {
                ##  Load the DATABASE section
                set vars [AIF::Variables MCM_DIE]

                ##  Populate the mcmdie array

                foreach v $vars {
                    ##  Need to handle reference designators separated
                    ##  by white space or comma, examples have shown both
                    if { [string match [AIF::GetVar $v MCM_DIE] ","] == 1 } {
                        set refs [split [AIF::GetVar $v MCM_DIE] ","]
                    } else {
                        set refs [split [AIF::GetVar $v MCM_DIE] " "]
                    }

                    foreach ref $refs {
                        xAIF::GUI::Message -severity note -msg [format "Device:  %s  Ref:  %s" $v [string  trim $ref]]
                        set xAIF::mcmdie([string trim $ref]) $v
                    }
                }

                foreach i [GetAllDie] {
                    xAIF::GUI::Message -severity note -msg \
                        [format "Device \"%s\" with reference designator:  %s" \
                        $xAIF::mcmdie($i) $i]
                }
            } else {
                xAIF::GUI::Message -severity error -msg [format "AIF file \"%s\" does not contain a MCM_DIE section." $xAIF::Settings(filename)]
                set rv -1
            }

            return $rv
        }
    }

    ##
    ##  Define the pad namespace and procedure supporting pad operations
    ##
    namespace eval Pad {

        #  Get all Pad names
        proc GetAllPads {} {
            return [array names xAIF::pads]
        }

        #  Return all of the parameters for a pad
        proc GetParams { pad } {
            return [regexp -inline -all -- {\S+} $xAIF::pads($pad)]
        }

        #  Return a specific parameter for a pad (default to first parameter)
        proc GetParam { pad { param  0 } } {
            return [lindex [GetParams $pad] $param]
        }

        #  Return the shape of the pad
        proc GetShape { pad } {
            return [GetParam $pad]
        }

        #  Return the xy points of the pad
        proc GetPoints { pad } {
            set pts {}
            foreach p [GetParams $pad] {
                if { [string equal POLY $p] } continue

                #  The AIF specification and sample file have the X and Y separated by
                #  both a space and comma character so we'll plan to handle either situation.
                if { [llength [split $p ,]] == 2 } {
                    set X [lindex [split $p ,] 0]
                    set Y [lindex [split $p ,] 1]
                } else {
                    set X [lindex [split $p] 0]
                    set Y [lindex [split $p] 1]
                }

                lappend pts $X $Y

                #puts $p
            }
            #puts $pts
            return $pts
        }

        #  Return the width of the pad
        proc GetWidth { pad } {
            return [GetParam $pad 1]
        }

        #  Return the height of the pad
        proc GetHeight { pad } {
            switch -exact -- [GetShape $pad] {
                "CIRCLE" -
                "ROUND" -
                "SQ" -
                "SQUARE" {
                    return [GetParam $pad 1]
                }
                "OBLONG" -
                "OBROUND" -
                "RECT" -
                "RECTANGLE" {
                    return [GetParam $pad 2]
                }
                default {
                    return 0
                }
            }
        }
    }

    ##
    ##  Define the database namespace and procedure supporting pad operations
    ##
    namespace eval Database {
        #
        #  AIF::Database::Section
        #
        #  Scan the AIF source file for the "DATABASE" section
        #
        proc Section {} {
            set rv 0

            ##  Make sure we have a DATABASE section!

            if { [lsearch -exact $::AIF::sections DATABASE] != -1 } {
                ##  Load the DATABASE section
                set vars [AIF::Variables DATABASE]

                foreach v $vars {
                    #puts [format "-->  %s" $v]
                    set xAIF::database([string tolower $v]) [AIF::GetVar $v DATABASE]
                }

                ##  Make sure file format is AIF!

                if { $xAIF::database(type) != "AIF" } {
                    xAIF::GUI::Message -severity error -msg [format "File \"%s\" is not an AIF file." $xAIF::Settings(filename)]
                    set rv -1
                }

                if { ([lsearch [AIF::Variables "DATABASE"] "MCM"] != -1) && ($xAIF::database(mcm) == "TRUE") } {
                    xAIF::GUI::Message -severity note -msg [format "File \"%s\" is a MCM-AIF file." $xAIF::Settings(filename)]
                    set xAIF::Settings(MCMAIF) 1
                    set xAIF::GUI::Widgets(AIFType) "File Type:  MCM-AIF"
                } else {
                    xAIF::GUI::Message -severity note -msg [format "File \"%s\" is an AIF file." $xAIF::Settings(filename)]
                    set xAIF::Settings(MCMAIF) 0
                    set xAIF::GUI::Widgets(AIFType) "File Type:  AIF"
                }

                ##  Does the AIF file contain a BGA section?
                set xAIF::Settings(BGA) [expr [lsearch [AIF::Sections] "BGA"] != -1 ? 1 : 0]

                ##  Check units for legal option - AIF supports UM, MM, CM, INCH, MIL

                if { [lsearch -exact $xAIF::units [string tolower $xAIF::database(units)]] == -1 } {
                    xAIF::GUI::Message -severity error -msg [format "Units \"%s\" are not supported AIF syntax." $xAIF::database(units)]
                    set rv -1
                }

                foreach i [array names xAIF::database] {
                    xAIF::GUI::Message -severity note -msg [format "Database \"%s\":  %s" [string toupper $i] $xAIF::database($i)]
                }
            } else {
                xAIF::GUI::Message -severity error -msg [format "AIF file \"%s\" does not contain a DATABASE section." $xAIF::Settings(filename)]
                set rv -1
            }

            return $rv
        }
    }

    ##
    ##  Define the Pads namespace and procedure supporting pad operations
    ##
    namespace eval Pads {
        #
        #  AIF::Pads::Section
        #
        #  Scan the AIF source file for the "PADS" section
        #
        proc Section {} {

            set rv 0
            set vm [$xAIF::GUI::Widgets(mainframe) getmenu padsmenu]
            set sm [$xAIF::GUI::Widgets(mainframe) getmenu padgenerationmenu]
            $sm delete 0 end
            
            #$vm add separator

            ##  Make sure we have a PADS section!
            if { [lsearch -exact $::AIF::sections PADS] != -1 } {
                ##  Load the PADS section
                set vars [AIF::Variables PADS]

                ##  Flush the pads array

                array set xAIF::pads {}
                array set xAIF::padtypes {}

                ##  Populate the pads array

                foreach v $vars {
                    set xAIF::pads($v) [AIF::GetVar $v PADS]
                    ##  Default all padtypes to SMD, may be adjusted later when processing netlist
                    set xAIF::padtypes($v) "smdpad"

                    #  Add pad to the View Devices menu and make it visible
                    set xAIF::GUI::pads($v) on
                    #$vm.pads add checkbutton -label "$v" -underline 0 \
                    #    -variable xAIF::GUI::pads($v) -onvalue on -offvalue off -command GUI::VisiblePad
                    $vm add checkbutton -label "$v" \
                        -variable xAIF::GUI::pads($v) -onvalue on -offvalue off \
                        -command  "xAIF::GUI::Draw::Visibility pad-$v -mode toggle"

                    ##  Create the submenu for changing the pad type
                    ##  Destroy the menu in case it already exists.
                    destroy [string tolower $sm.$v]
                    set pm [menu [string tolower $sm.$v] -tearoff 0]
                    $sm add cascade -label "$v" -menu $pm -underline 0
                    $pm add radiobutton -label "Ball Pad" -variable xAIF::padtypes($v) \
                        -value $xAIF::Const::XAIF_PADTYPE_BALLPAD -underline 1
                    $pm add radiobutton -label "Bond Pad" -variable xAIF::padtypes($v) \
                        -value $xAIF::Const::XAIF_PADTYPE_BONDPAD -underline 1
                    $pm add radiobutton -label "Die Pad" -variable xAIF::padtypes($v) \
                        -value $xAIF::Const::XAIF_PADTYPE_DIEPAD -underline 0
                    $pm add radiobutton -label "SMD Pad" -variable xAIF::padtypes($v) \
                        -value $xAIF::Const::XAIF_PADTYPE_SMDPAD -underline 0
                }

                foreach i [array names xAIF::pads] {

                    set padshape [lindex [regexp -inline -all -- {\S+} [lindex $xAIF::pads($i) 0]] 0]
                    puts [format ">>> Pad:  %s %s" $i $xAIF::pads($i)]

                    ##  Check units for legal option - AIF supports UM, MM, CM, INCH, MIL

                    if { [lsearch -exact $xAIF::padshapes [string tolower $padshape]] == -1 } {
                        xAIF::GUI::Message -severity error -msg [format "Pad shape \"%s\" is not supported AIF syntax." $padshape]
                        set rv -1
                    } else {
                        xAIF::GUI::Message -severity note -msg [format "Found pad \"%s\" with shape \"%s\"." [string toupper $i] $padshape]
                    }
                }

                xAIF::GUI::Message -severity note -msg [format "AIF source file contains %d %s." [array size xAIF::pads] [xAIF::Utility::Plural [array size xAIF::pads] "pad"]]
            } else {
                xAIF::GUI::Message -severity error -msg [format "AIF file \"%s\" does not contain a PADS section." $xAIF::Settings(filename)]
                set rv -1
            }

            return rv
        }

    }

    ##
    ##  Define the Netlist namespace and procedure supporting pad operations
    ##
    namespace eval Netlist {
        #
        #  AIF::Netlist::Section
        #
        #  Scan the AIF source file for the "NETLIST" section
        #
        proc Section {} {
            set rv 0
            set txt $xAIF::GUI::Widgets(netlistview)

            ##  Make sure we have a NETLIST section!
            if { [lsearch -exact $::AIF::sections NETLIST] != -1 } {

                ##  Load the NETLIST section which was previously stored in the netlist text widget

                Netlist::Load

                xAIF::GUI::Message -severity note -msg [format "AIF source file contains %d net %s." [ Netlist::GetConnectionCount ] [xAIF::Utility::Plural [Netlist::GetConnectionCount] "connection"]]
                xAIF::GUI::Message -severity note -msg [format "AIF source file contains %d unique %s." [Netlist::GetNetCount] [xAIF::Utility::Plural [Netlist::GetNetCount] "net"]]

            } else {
                xAIF::GUI::Message -severity error -msg [format "AIF file \"%s\" does not contain a NETLIST section." $xAIF::Settings(filename)]
                set rv -1
            }

            return rv
        }

    }
}
