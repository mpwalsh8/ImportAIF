# vim: set expandtab tabstop=4 shiftwidth=4:
#
#  I like Vim (http://www.vim.org) as a text editor.  The above line
#  tells Vim to set the indent to 4 spaces and the tab key to indent
#  4 spaces.
# 
#  Netlist.tcl
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
#    07/21/2014 - Initial version.  Moved pad processing and info to a
#                 separate file and namespace to ease code maintenance.
#

##
##  Define the netlist namespace and procedure supporting netlist operations
##  Because net names in the netlist are not guaranteed to be unique (e.g. VSS,
##  GND, etc.), nets are looked up by index.  The netlist can be traversed with
##  a traditional FOR loop.
##

namespace eval Netlist {
    variable nl [list]
    variable pads [list]
    variable connections 0

    #  Load the netlist from the text widget
    proc Load { } {
        variable nl
        variable pads
        variable connections
    
        set txt $GUI::widgets(netlistview)
        
        ##  Clean up list, the text widget may
        ##  return empty stuff we don't want
    
        foreach n [split [$txt get 1.0 end] '\n'] {
            if { $n == "" } { continue }
    
            ##  Extract the net name from the first field (col 1)
            set netname [lindex [regexp -inline -all -- {\S+} $n] 0]
            set padname [lindex [regexp -inline -all -- {\S+} $n] 2]
    
            ##  Check net name for legal syntax, add it to the list
            ##  of nets if it is valid.  The list contains just unique
            ##  netnames.  The netlist text widget contains the netlist.
    
            if { [ regexp {^[[:alpha:][:alnum:]_]*\w} $netname ] == 0 } {
                GUI::Transcript -severity error -msg [format "Net name \"%s\" is not supported AIF syntax." $netname]
                set rv -1
            } else {
                incr connections
    
                if { [lsearch -exact $nl $netname ] == -1 } {
                    lappend nl $netname
                    GUI::Transcript -severity note -msg [format "Found net name \"%s\"." $netname]
                }
    
                if { [lsearch -exact $pads $padname ] == -1 && $padname != "-" } {
                    lappend pads $padname
                    GUI::Transcript -severity note -msg [format "Found reference to pad \"%s\"." $padname]
                }
            }
        }
    }
    
    #  Return all of the parameters for a net
    proc GetParams { index } {
        set txt $GUI::widgets(netlistview)
        return [regexp -inline -all -- {\S+} [$txt get [expr $index +1].0 [expr $index +1].end]]
    }
    
    #  Return a specific parameter for a pad (default to first parameter)
    proc GetParam { index { param  0 } } {
        return [lindex [GetParams $index] $param]
    }
    
    #  Return the shape of the pad
    proc GetNetName { index } {
        return [GetParam $index]
    }
    
    proc GetNetCount {} {
        variable nl
        return [llength $nl]
    }
    
    proc GetConnectionCount {} {
        variable connections
        return $connections
    }
    
    proc NetParams {} {
    }
    
    proc GetAllNetNames {} {
        variable nl
        return $nl
    }
    
    proc GetPads { } {
        variable pads
        return $pads
    }
    
    proc GetPinNumber { index } {
        return [GetParam $index 1]
    }
    
    proc GetPadName { index } {
        return [GetParam $index 2]
    }
    
    proc GetDiePadX { index } {
        return [GetParam $index 3]
    }
    
    proc GetDiePadY { index } {
        return [GetParam $index 4]
    }

    ##
    ##  Define the netlist export namespace and procedure supporting netlist operations
    ##
    namespace eval Export {
        ##
        ##  Netlist::Export::KYN
        ##
        proc KYN { { kyn "" } } {
            set txt $GUI::widgets(kynnetlistview)

            if { $kyn == "" } {
                set kyn [tk_getSaveFile -filetypes {{KYN .kyn} {Txt .txt} {All *}} \
                    -initialfile "netlist.kyn" -defaultextension ".kyn"]
            }

            if { $kyn == "" } {
                GUI::Transcript -severity warning -msg "No KYN file specified, Export aborted."
                return
            }
        
            #  Write the KYN netlist content to the file
            set f [open $kyn "w+"]
            puts $f [$txt get 1.0 end]
            close $f

            GUI::Transcript -severity note -msg [format "KYN netlist successfully exported to file \"%s\"." $kyn]

            return
        }

        ##
        ##  Netlist::Export::Placement
        ##
        proc Placement { { plcmnt "" } } {

            if { $plcmnt == "" } {
                set plcmnt [tk_getSaveFile -filetypes {{Dat .dat} {All *}} \
                    -initialfile "xyplace.dat" -defaultextension ".dat"]
            }

            if { $plcmnt == "" } {
                GUI::Transcript -severity warning -msg "No Placement file specified, Export aborted."
                return
            }
        
            #  Write the placement content to the file

            set txt [format ".%s\n" [AIF::GetVar UNITS DATABASE]]

            ###foreach i [dict keys $::mcmdie] {}
            foreach i [array names ::mcmdie] {
                set ctr "0,0"
                ###set sect [format "MCM_%s_%s" [dict get $::mcmdie $i] $i]
                set sect [format "MCM_%s_%s" $::mcmdie($i) $i]

                ##  If the device has a section, extract the CENTER keyword
                if { [lsearch [AIF::Sections] $sect] != -1 } {
                    set ctr [AIF::GetVar CENTER $sect]
                }

                ##  Split the CENTER keyword into an X and Y, handle space or comma
                if { [string first , $ctr] != -1 } {
                    set X [string trim [lindex [split $ctr ,] 0]]
                    set Y [string trim [lindex [split $ctr ,] 1]]
                } else {
                    set X [string trim [lindex [split $ctr] 0]]
                    set Y [string trim [lindex [split $ctr] 1]]
                }

                append txt [format ".REF %s %s,%s 0 top\n" $i $X $Y]
            }

            ##  If this AIF file does not contain a MCM_DIE section then
            ##  the DIE will not appear in the device list and needs to be
            ##  exported separately.

            if { [lsearch -exact $::AIF::sections MCM_DIE] == -1 } {
                set ctr "0,0"

                ##  If the device has a section, extract the CENTER keyword
                if { [lsearch [AIF::Sections] "DIE"] != -1 } {
                    set ctr [AIF::GetVar CENTER "DIE"]
                }

                ##  Split the CENTER keyword into an X and Y, handle space or comma
                if { [string first , $ctr] != -1 } {
                    set X [string trim [lindex [split $ctr ,] 0]]
                    set Y [string trim [lindex [split $ctr ,] 1]]
                } else {
                    set X [string trim [lindex [split $ctr] 0]]
                    set Y [string trim [lindex [split $ctr] 1]]
                }

                append txt [format ".REF %s %s,%s 0 top\n" $::die(refdes) $X $Y]
                GUI::Transcript -severity note -msg [format "Standard AIF file, adding die (\"%s\") to the placement file." $::die(refdes)]
            }

            set f [open $plcmnt "w+"]
            puts $f $txt
            close $f

            GUI::Transcript -severity note -msg [format "Placement successfully exported to file \"%s\"." $plcmnt]

            return
        }
    }
}
