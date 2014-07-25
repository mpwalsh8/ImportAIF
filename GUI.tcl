# vim: set expandtab tabstop=4 shiftwidth=4:
#
#  I like Vim (http://www.vim.org) as a text editor.  The above line
#  tells Vim to set the indent to 4 spaces and the tab key to indent
#  4 spaces.
# 
#  GUI.tcl
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
#    07/20/2014 - Initial version.  Moved enumeration mapping to a
#                 separate file and namespace to ease code maintenance.
#

##
##  Define the GUI namespace and procedure supporting operations
##
namespace eval GUI {
    #variable objects
    variable text
    variable devices
    variable pads
    variable bondwires
    variable netlines
    variable guides

    #array set objects {
        #diepads 1
        #balls 1
        #fingers 1
        #dieoutline 1
        #bgaoutline 1
        #partoutline 1
        #rings 1
    #}

    array set text {
        padnumber on
        refdes on
    }

    array set devices {
    }

    array set pads {
    }

    array set bondwires {
    }

    array set netlines {
    }

    array set guides {
        xyaxis on
        dimension on
    }

    #
    #  Visibility
    #
    proc Visibility { tags args } {
    
        #puts "$tags $args"
    
        ##  Process command arguments
        array set V { -mode toggle -all false } ;# Default values
        foreach {a value} $args {
            if {! [info exists V($a)]} {error "unknown option $a"}
            if {$value == {}} {error "value of \"$a\" missing"}
            set V($a) $value
        }
    
        ##  If not tags not a global operation then return
        if { $tags == "" && $V(-all) == false } { return {} }
    
        set cnvs $::widgets(graphicview)
    
        ##  Find all items with the supplied tag
        foreach tag $tags {
            set id [$cnvs find withtag $tag]
            foreach i $id {
                if { $V(-mode) == "toggle" } {
                    set v [lindex [$cnvs itemconfigure $i -state] 4]
                    set v [expr {$v == "hidden" ? "normal" : "hidden"}]
                } elseif { $V(-mode) == "on" } {
                    set v "normal"
                } else {
                    set v "hidden"
                }
    
                $cnvs itemconfigure $i -state $v
            }
        }
    }
    
    #
    #  RotateXY
    #
    #  From Ian Gabbitas ...
    #
    #    x2 = x * cos(radA) - y * sin(radA)
    #    y2 = x * sin(radA) + y * cos(radA)
    #  
    proc RotateXY { x y { angle 0 } } {
        #set radians [expr $angle*(3.14159265/180.0)]
        set radians [expr {$angle * atan(1) * 4 / 180.0}] ;# Radians
        puts "R:  $radians"
        puts "A:  $angle"
        set x2 [expr { $x * cos($radians) - $y * sin($radians) }]
        set y2 [expr { $x * sin($radians) + $y * cos($radians) }]
        #puts "====================================="
        #puts ""
        #puts [format "Rotation:  X1:  %s  Y1:  %s  X2:  %s  Y2:  %s  A:  %s" $x $y $x2 $y2 $angle]
        #puts ""
        #puts "====================================="
        return [list $x2 $y2]
    }
    
    #
    #  ArcPath
    #
    #  @see http://wiki.tcl.tk/8612
    #
    #  
    proc ArcPath {x0 y0 x1 y1 args} {
        
        array set V {-sides 0 -start 90 -extent 360} ;# Default values
        foreach {a value} $args {
            if {! [info exists V($a)]} {error "unknown option $a"}
            if {$value == {}} {error "value of \"$a\" missing"}
            set V($a) $value
        }
        if {$V(-extent) == 0} {return {}}
        
        set xm [expr {($x0+$x1)/2.0}]
        set ym [expr {($y0+$y1)/2.0}]
        set rx [expr {$xm-$x0}]
        set ry [expr {$ym-$y0}]
     
        set n $V(-sides)
        if {$n == 0} {                              ;# 0 sides => circle
            set n [expr {round(($rx+$ry)*0.5)}]
            if {$n < 2} {set n 4}
        }
        
        set dir [expr {$V(-extent) < 0 ? -1 : 1}]   ;# Extent can be negative
        if {abs($V(-extent)) > 360} {
            set V(-extent) [expr {$dir * (abs($V(-extent)) % 360)}]
        }
        set step [expr {$dir * 360.0 / $n}]
        set numsteps [expr {1 + double($V(-extent)) / $step}]
                                  
        set xy {}
        set DEG2RAD [expr {4*atan(1)*2/360}]
                                  
        for {set i 0} {$i < int($numsteps)} {incr i} {
            set rad [expr {($V(-start) - $i * $step) * $DEG2RAD}]
            set x [expr {$rx*cos($rad)}]
            set y [expr {$ry*sin($rad)}]
            lappend xy [expr {$xm + $x}] [expr {$ym - $y}]
        }
     
        # Figure out where last segment should end
        if {$numsteps != int($numsteps)} {
            # Vecter V1 is last drawn vertext (x,y) from above
            # Vector V2 is the edge of the polygon
            set rad2 [expr {($V(-start) - int($numsteps) * $step) * $DEG2RAD}]
            set x2 [expr {$rx*cos($rad2) - $x}]
            set y2 [expr {$ry*sin($rad2) - $y}]
     
            # Vector V3 is unit vector in direction we end at
            set rad3 [expr {($V(-start) - $V(-extent)) * $DEG2RAD}]
            set x3 [expr {cos($rad3)}]
            set y3 [expr {sin($rad3)}]
     
            # Find where V3 crosses V1+V2 => find j s.t.  V1 + kV2 = jV3
            set j [expr {($x*$y2 - $x2*$y) / ($x3*$y2 - $x2*$y3)}]
     
            lappend xy [expr {$xm + $j * $x3}] [expr {$ym - $j * $y3}]
        }
        return $xy
    }

    ##
    ##  Menus
    namespace eval Menus {

        ##
        ##  GUI::Menus::CentralLibraryMode
        ##
        proc CentralLibraryMode {} {
            $::widgets(setupmenu) entryconfigure  3 -state disabled
            $::widgets(setupmenu) entryconfigure 4 -state normal
            $::widgets(setupmenu) entryconfigure 7 -state disabled
            #set ::ediu(targetPath) $::ediu(Nothing)
            ediuUpdateStatus $::ediu(ready)
        }

        ##
        ##  GUI::Menus::DesignMode
        ##
        proc DesignMode {} {
            $::widgets(setupmenu) entryconfigure  3 -state normal
            $::widgets(setupmenu) entryconfigure 4 -state disabled
            $::widgets(setupmenu) entryconfigure 7 -state normal
            #set ::ediu(targetPath) $::ediu(Nothing)
            ediuUpdateStatus $::ediu(ready)
        }

        ##
        ##  GUI::Menus::BondWireEditMode
        ##
        proc BondWireEditMode {} {
            $::widgets(setupmenu) entryconfigure  3 -state normal
            $::widgets(setupmenu) entryconfigure 4 -state disabled
            $::widgets(setupmenu) entryconfigure 7 -state normal
            #set ::ediu(targetPath) $::ediu(Nothing)
            ediuUpdateStatus $::ediu(ready)
        }
    }

    ##
    ##  Define the GUI::Dashboard namespace and procedure supporting operations
    ##
    namespace eval Dashboard {
        variable Mode Design
        variable AIFFile ""
        variable FileType
        variable DesignPath ""
        variable DesignName ""
        variable FullDesignPath ""
        variable LibraryPath ""
        variable CellPartition ""
        variable PartPartition ""
        variable ConnectMode On
        variable Visibility On
        variable CellGeneration
        variable CellVersioning none

        array set CellGeneration {
            MirrorNone on
            MirrorX off
            MirroyY off
            MirrorXY off
        }

        ##
        ##  GUI::Dashboard::Build
        ##
        proc Build {} {
            variable CellGeneration

            set db $::widgets(dashboard)

            ##  Mode
            labelframe $db.mode -pady 2 -text "Mode" -padx 2
            foreach i { "Design" "Central Library" } {
                radiobutton $db.mode.b$i -text "$i" -variable GUI::Dashboard::Mode \
	            -relief flat -value $i
                pack $db.mode.b$i  -side top -pady 2 -anchor w
            }
            
            ##  Cell Versioning
            labelframe $db.cellversioning -pady 2 -text "Cell Versioning (suffix)" -padx 2
            foreach { i  j } { none "None" numeric "Numeric (-1, -2, -3, etc.)" alpha "Alpha (-A, -B, -C, etc.)" } {
                radiobutton $db.cellversioning.b$i -text "$j" -variable GUI::Dashboard::CellVersioning \
	            -relief flat -value $i
                pack $db.cellversioning.b$i  -side top -pady 2 -anchor w
            }
            
            ##  Cell Generation
            labelframe $db.cellgeneration -pady 2 -text "Cell Generation" -padx 2
            foreach { i j } { MirrorNone "Default" MirrorX "Mirror X Coordinates" MirrorY "Mirror Y Coordinates" MirrorXY "Mirror X and Y Coordinates" } {
                checkbutton $db.cellgeneration.b$i -text "$j" -variable GUI::Dashboard::CellGeneration($i) \
	            -relief flat -onvalue on -offvalue off
                pack $db.cellgeneration.b$i  -side top -pady 2 -anchor w
            }
            
            ##  Visibility
            labelframe $db.visibility -pady 2 -text "Application Visibility" -padx 2
            foreach i { On Off } {
                radiobutton $db.visibility.b$i -text "$i" -variable GUI::Dashboard::Visibility \
	            -relief flat -value $i
                pack $db.visibility.b$i  -side top -pady 2 -anchor w
            }
            
            ##  Connection
            labelframe $db.connection -pady 2 -text "Application Connection" -padx 2
            foreach i { On Off } {
                radiobutton $db.connection.b$i -text "$i" -variable GUI::Dashboard::ConnectMode \
	            -relief flat -value $i
                pack $db.connection.b$i  -side top -pady 2 -anchor w
            }

            ##  AIF File
            labelframe $db.aiffile -pady 5 -text "AIF File" -padx 5
            entry $db.aiffile.e -width 65 -relief sunken -bd 2 -textvariable GUI::Dashboard::AIFFile
            button $db.aiffile.b -text "AIF File ..." -command GUI::Dashboard::SelectAIFFile
            grid $db.aiffile.e -row 0 -column 0 -pady 5 -padx 5 -sticky w
            grid $db.aiffile.b -row 0 -column 1 -pady 5 -padx 5 -sticky ew

            ##  Design Path
            labelframe $db.design -pady 5 -text "Design" -padx 5
            entry $db.design.e -width 65 -relief sunken -bd 2 -textvariable GUI::Dashboard::FullDesignPath
            button $db.design.b -text "Design ..." -command \
                { set GUI::Dashboard::FullDesignPath [tk_getOpenFile -filetypes {{PCB .pcb}}] }
            grid $db.design.e -row 0 -column 0 -pady 5 -padx 5 -sticky w
            grid $db.design.b -row 0 -column 1 -pady 5 -padx 5 -sticky ew

            ##  Library Path
            labelframe $db.library -pady 5 -text "Central Library" -padx 5
            entry $db.library.le -width 65 -relief sunken -bd 2 -textvariable GUI::Dashboard::LibraryPath
            button $db.library.lb -text "Library ..." -command GUI::Dashboard::SelectCentralLibrary
            entry $db.library.ce -width 35 -relief sunken -bd 2 -textvariable GUI::Dashboard::CellPartition
            button $db.library.cb -text "Cell Partition ..." -state disabled -command GUI::Dashboard::SelectCellPartition
            entry $db.library.pe -width 35 -relief sunken -bd 2 -textvariable GUI::Dashboard::PartPartition
            button $db.library.pb -text "PDB Partition ..." -state disabled -command GUI::Dashboard::SelectPartPartition

            grid $db.library.le -row 0 -column 0 -pady 5 -padx 5 -sticky w
            grid $db.library.ce -row 1 -column 0 -pady 5 -padx 5 -sticky w
            grid $db.library.pe -row 2 -column 0 -pady 5 -padx 5 -sticky w
            grid $db.library.lb -row 0 -column 1 -pady 5 -padx 5 -sticky ew
            grid $db.library.cb -row 1 -column 1 -pady 5 -padx 5 -sticky ew
            grid $db.library.pb -row 2 -column 1 -pady 5 -padx 5 -sticky ew

            ##  Place all of the widgets
            grid $db.aiffile        -row 0 -column 0 -sticky ew -padx 10 -pady 10 -columnspan 2
            grid $db.design         -row 1 -column 0 -sticky ew -padx 10 -pady 10 -columnspan 2
            grid $db.library        -row 2 -column 0 -sticky ew -padx 10 -pady 10 -columnspan 2
            grid $db.mode           -row 0 -column 2 -sticky ew -padx 10 -pady 10
            grid $db.connection     -row 1 -column 2 -sticky ew -padx 10 -pady 10
            grid $db.visibility     -row 2 -column 2 -sticky ew -padx 10 -pady 10
            grid $db.cellgeneration -row 3 -column 0 -sticky ew -padx 10 -pady 10
            grid $db.cellversioning -row 3 -column 1 -sticky ew -padx 10 -pady 10
        }

        ##
        ##  GUI::Dashboard::SelectAIFFile
        ##
        proc SelectAIFFile {} {
            set GUI::Dashboard::AIFFile [tk_getOpenFile -filetypes {{AIF .aif} {Txt .txt} {All *}}]
        
            if { [string equal $GUI::Dashboard::AIFFile ""] } {
                Transcript $::ediu(MsgError) "No AIF File selected."
            } else {
                ediuAIFFileOpen $GUI::Dashboard::AIFFile
            }
        }

        ##
        ##  GUI::Dashboard::SelectCentralLibrary
        ##
        proc SelectCentralLibrary {} {
            set db $::widgets(dashboard)
            set GUI::Dashboard::LibraryPath [tk_getOpenFile -filetypes {{LMC .lmc}}]

            ##  Valid LMC selected?  If so, enable the buttons and load the partitions
            if { [expr { $GUI::Dashboard::LibraryPath ne "" }] } {
                $db.library.cb configure -state normal
                $db.library.pb configure -state normal

                ##  Open the LMC and get the partition names
                MGC::SetupLMC $GUI::Dashboard::LibraryPath
            }
        }

        ##
        ##  GUI::Dashboard::SelectCellPartition
        ##
        proc SelectCellPartition {} {
            set GUI::Dashboard::CellPartition \
                [AIFForms::SelectOneFromList "Select Target Cell Partition" $::ediu(cellEdtrPrtnNames)]

            if { [string equal $GUI::Dashboard::CellPartition ""] } {
                Transcript $::ediu(MsgError) "No Cell Partition selected."
            } else {
                set GUI::Dashboard::CellPartition [lindex $GUI::Dashboard::CellPartition 1]
            }
        }

        ##
        ##  GUI::Dashboard::SelectPartPartition
        ##
        proc SelectPartPartition {} {
            set GUI::Dashboard::PartPartition \
                [AIFForms::SelectOneFromList "Select Target Part Partition" $::ediu(partEdtrPrtnNames)]

            if { [string equal $GUI::Dashboard::PartPartition ""] } {
                Transcript $::ediu(MsgError) "No Part Partition selected."
            } else {
                set GUI::Dashboard::PartPartition [lindex $GUI::Dashboard::PartPartition 1]
            }
        }

        ##
        ##  GUI::Dashboard::SetApplicationVisibility
        ##
        proc SetApplicationVisibility {} {
            set ::ediu(appVisible) [expr [string is true $GUI::Dashboard::Visibility] ? on : off]
        }
    }
}
