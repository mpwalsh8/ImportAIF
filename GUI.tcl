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

    namespace eval Menus {

        ##
        ##  GUI::Menus::CentralLibraryMode
        ##
        proc CentralLibraryMode {} {
            $::widgets(setupmenu) entryconfigure  3 -state disabled
            $::widgets(setupmenu) entryconfigure 4 -state normal
            $::widgets(setupmenu) entryconfigure 7 -state disabled
            set ::ediu(targetPath) $::ediu(Nothing)
            ediuUpdateStatus $::ediu(ready)
        }

        ##
        ##  GUI::Menus::DesignMode
        ##
        proc DesignMode {} {
            $::widgets(setupmenu) entryconfigure  3 -state normal
            $::widgets(setupmenu) entryconfigure 4 -state disabled
            $::widgets(setupmenu) entryconfigure 7 -state normal
            set ::ediu(targetPath) $::ediu(Nothing)
            ediuUpdateStatus $::ediu(ready)
        }
    }
}
