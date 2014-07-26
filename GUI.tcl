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
    variable widgets

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

        set cnvs $GUI::widgets(layoutview)

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
    ##  Build
    ##
    namespace eval Build {

        ##
        ##  GUI::Build::Menus
        ##
        proc Menus {} {
            #  Create the main menu bar
            set mb [menu .menubar]

            GUI::Build::FilePulldown $mb
            GUI::Build::SetupPulldown $mb
            GUI::Build::ViewPulldown $mb
            GUI::Build::GeneratePulldown $mb
            GUI::Build::WireBondPulldown $mb
            GUI::Build::HelpPulldown $mb
        }

        ##
        ##  GUI::Build::FilePulldown
        ##
        proc FilePulldown { mb } {
            set fm [menu $mb.file -tearoff 0]
            $mb add cascade -label "File" -menu $mb.file -underline 0
            $fm add command -label "Open AIF ..." \
                -accelerator "F5" -underline 0 \
                -command GUI::Dashboard::SelectAIFFile
            $fm add command -label "Close AIF" \
                -accelerator "F6" -underline 0 \
                -command ediuAIFFileClose
            $fm add command -label "Export KYN ..." \
                -underline 7 -command Netlist::Export::KYN
            $fm add command -label "Export Placement ..." \
                -underline 7 -command Netlist::Export::Placement
            #$fm add separator
            #$fm add command -label "Open Sparse Pins ..." \
                -underline 1 -command ediuSparsePinsFileOpen
            #$fm add command -label "Close Sparse Pins " \
                #-underline 1 -command ediuSparsePinsFileClose
            if {[llength [info commands console]]} {
                $fm add separator
	            $fm add command -label "Show Console" \
                    -underline 0 -command { console show }
            }

            $fm add separator
            $fm add command -label "Exit" -underline 0 -command exit
        }

        ##
        ##  GUI::Build::SetupPulldown
        ##
        proc SetupPulldown { mb } {
            set sm [menu $mb.setup -tearoff 0]
            set GUI::widgets(setupmenu) $sm
            $mb add cascade -label "Setup" -menu $sm -underline 0
            $sm add radiobutton -label "Design Mode" -underline 0 \
                -variable ::ediu(mode) -value $::ediu(designMode) \
                -command GUI::Menus::DesignMode
            $sm add radiobutton -label "Central Library Mode" -underline 0 \
                -variable ::ediu(mode) -value $::ediu(libraryMode) \
                -command GUI::Menus::CentralLibraryMode
            $sm add separator
            $sm add command \
                -label "Target Design ..." -state normal \
                -underline 1 -command ediuSetupOpenPCB
            $sm add command \
                -label "Target Central Library ..." -state disabled \
                -underline 2 -command ediuSetupOpenLMC
            #$sm add separator
            #$sm add checkbutton -label "Sparse Mode" -underline 0 \
                #-variable ::ediu(sparseMode) -command ediuToggleSparseMode
            $sm add separator
            $sm add checkbutton -label "Application Visibility" \
                -variable GUI::Dashboard::Visibility -onvalue on -offvalue off \
                -command  {Transcript MsgNote [format "Application visibility is now %s." \
                [expr [string is true $GUI::Dashboard::Visibility] ? "on" : "off"]] }
            $sm add checkbutton -label "Connect to Running Application" \
                -variable ::ediu(connectMode) -onvalue True -offvalue False \
                -command  {Transcript MsgNote [format "Application Connect mode is now %s." \
                [expr $::ediu(connectMode) ? "on" : "off"]] ; GUI::StatusBar::UpdateStatus -busy off }
        }

        ##
        ##  GUI::Build::ViewPulldown
        ##
        proc ViewPulldown { mb } {
            set vm [menu $mb.zoom -tearoff 0]
            set GUI::widgets(viewmenu) $vm

            $mb add cascade -label "View" -menu $vm -underline 0
            $vm add cascade -label "Zoom In" -underline 5 -menu $vm.in
            menu $vm.in -tearoff 0
            $vm.in add cascade -label "2x" -underline 0 \
                 -command {ediuGraphicViewZoom 2.0}
            $vm.in add command -label "5x" -underline 0 \
                 -command {ediuGraphicViewZoom 5.0}
            $vm.in add command -label "10x" -underline 0 \
                 -command {ediuGraphicViewZoom 10.0}
            $vm add cascade -label "Zoom Out" -underline 5 -menu $vm.out
            menu $vm.out -tearoff 0
            $vm.out add cascade -label "2x" -underline 0 \
                 -command {ediuGraphicViewZoom 0.5}
            $vm.out add command -label "5x" -underline 0 \
                 -command {ediuGraphicViewZoom 0.2}
            $vm.out add command -label "10x" -underline 0 \
                 -command {ediuGraphicViewZoom 0.1}

            $vm add separator

##  Not sure about keeping this menu ...
if { 0 } {
            $vm add cascade -label "Objects" \
                 -underline 1 -menu $vm.objects
            menu $vm.objects -tearoff 0
            $vm.objects add cascade -label "All On" -underline 5 -command { gui::VisibleObject -all on }
            $vm.objects add cascade -label "All Off" -underline 5 -command { gui::VisibleObject -all off }
            $vm.objects add separator
            $vm.objects add checkbutton -label "Pads" -underline 0 \
                -variable gui::objects(diepads) -onvalue 1 -offvalue 0 -command gui::VisibleObject
            $vm.objects add checkbutton -label "Balls" -underline 0 \
                -variable gui::objects(balls) -onvalue 1 -offvalue 0 -command gui::VisibleObject
            $vm.objects add checkbutton -label "Fingers" -underline 0 \
                -variable gui::objects(fingers) -onvalue 1 -offvalue 0 -command gui::VisibleObject
            $vm.objects add checkbutton -label "Die Outline" -underline 0 \
                -variable gui::objects(dieoutline) -onvalue 1 -offvalue 0 -command gui::VisibleObject
            $vm.objects add checkbutton -label "BGA Outline" -underline 0 \
                -variable gui::objects(bgaoutline) -onvalue 1 -offvalue 0 -command gui::VisibleObject
            $vm.objects add checkbutton -label "Part Outlines" -underline 5 \
                -variable gui::objects(partoutline) -onvalue 1 -offvalue 0 -command gui::VisibleObject
            $vm.objects add checkbutton -label "Rings" -underline 0 \
                -variable gui::objects(rings) -onvalue 1 -offvalue 0 -command gui::VisibleObject
}

            $vm add cascade -label "Text" \
                 -underline 1 -menu $vm.text
            menu $vm.text -tearoff 0
            $vm.text add cascade -label "All On" -underline 5 \
                -command { GUI::Visibility "text" -all true -mode on ; \
                foreach t [array names GUI::text] { set GUI::text([lindex $t 0]) on }  }
            $vm.text add cascade -label "All Off" -underline 5 \
                -command { GUI::Visibility "text" -all true -mode off ; \
                foreach t [array names GUI::text] { set GUI::text([lindex $t 0]) off }  }
            $vm.text add separator
            $vm.text add checkbutton -label "Pad Numbers" -underline 0 \
                -variable GUI::text(padnumber) -onvalue on -offvalue off \
                -command  "GUI::Visibility padnumber -mode toggle"
            $vm.text add checkbutton -label "Ref Designators" -underline 5 \
                -variable GUI::text(refdes) -onvalue on -offvalue off \
                -command  "GUI::Visibility refdes -mode toggle"

            $vm add cascade -label "Devices" \
                 -underline 0 -menu $vm.devices
            menu $vm.devices -tearoff 0
            $vm.devices add cascade -label "All On" -underline 5 \
                -command { GUI::Visibility {bga device} -mode on ; \
                foreach d $::mcmdie { set GUI::devices($d) on } }
            $vm.devices add cascade -label "All Off" -underline 5 \
                -command { GUI::Visibility {bga device} -mode off ; \
                foreach d $::mcmdie { set GUI::devices($d) off } }
            $vm.devices add separator

            $vm add cascade -label "Bond Wires" \
                 -underline 0 -menu $vm.bondwires
            menu $vm.bondwires -tearoff 0
            $vm.bondwires add cascade -label "All On" -underline 5 \
                -command { GUI::Visibility "bondwire" -all true -mode on ; \
                foreach bw $::bondwires { set GUI::bondwires([lindex $bw 0]) on }  }
            $vm.bondwires add cascade -label "All Off" -underline 5 \
                -command { GUI::Visibility "bondwire" -all true -mode off ; \
                foreach bw $::bondwires { set GUI::bondwires([lindex $bw 0]) off }  }
            $vm.bondwires add separator

            $vm add cascade -label "Net Lines" \
                 -underline 0 -menu $vm.netlines
            menu $vm.netlines -tearoff 0
            $vm.netlines add cascade -label "All On" -underline 5 \
                -command { GUI::Visibility "netline" -all true -mode on ; \
                foreach nl $::netlines { set GUI::netlines([lindex $nl 0]) on }  }
            $vm.netlines add cascade -label "All Off" -underline 5 \
                -command { GUI::Visibility "netline" -all true -mode off ; \
                foreach nl $::netlines { set GUI::netlines([lindex $nl 0]) off }  }
            $vm.netlines add separator

            $vm add cascade -label "Pads" \
                 -underline 0 -menu $vm.pads
            menu $vm.pads -tearoff 0
            $vm.pads add cascade -label "All On" -underline 5 \
                -command { GUI::Visibility "pad" -all true -mode on ; \
                foreach p $::pads { set GUI::pads([lindex $p 0]) on }  }
            $vm.pads add cascade -label "All Off" -underline 5 \
                -command { GUI::Visibility "pad" -all true -mode off ; \
                foreach p $::pads { set GUI::pads([lindex $p 0]) off }  }
            $vm.pads add separator


            $vm add separator

            $vm add cascade -label "Guides" \
                 -underline 0 -menu $vm.guides
            menu $vm.guides -tearoff 0
            $vm.guides add cascade -label "All On" -underline 5 \
                -command { GUI::Visibility "guides" -all true -mode on ; \
                foreach g [array names GUI::guides] { set GUI::guides($g) on }  }
            $vm.guides add cascade -label "All Off" -underline 5 \
                -command { GUI::Visibility "guides" -all true -mode off ; \
                foreach g [array names GUI::guides] { set GUI::guides($g) off }  }
            $vm.guides add separator
            $vm.guides add checkbutton -label "XY Axis" \
                -variable GUI::guides(xyaxis) -onvalue on -offvalue off \
                -command  "GUI::Visibility xyaxis -mode toggle"
            $vm.guides add checkbutton -label "Dimensions" \
                -variable GUI::guides(dimension) -onvalue on -offvalue off \
                -command  "GUI::Visibility dimension -mode toggle"
        }

        ##
        ##  GUI::Build::GeneratePulldown
        ##
        proc GeneratePulldown { mb } {
            set gm [menu $mb.generate -tearoff 0]
            $mb add cascade -label "Generate" -menu $mb.generate -underline 0
            $gm add command -label "Pads ..." \
                -underline 0 -command MGC::Generate::Pads
            $gm add command -label "Padstacks ..." \
                -underline 0 -command MGC::Generate::Padstacks
            $gm add command -label "Cells ..." \
                -underline 0 -command MGC::Generate::Cells
                    $gm add command -label "PDBs ..." \
                -underline 1 -command MGC::Generate::PDBs
            }

        ##
        ##  GUI::Build::WireBondPulldown
        ##
        proc WireBondPulldown { mb } {
            set wbm [menu $mb.wirebond -tearoff 0]
            $mb add cascade -label "Wire Bond" -menu $mb.wirebond -underline 0
            $wbm add command -label "Setup ..." \
                -underline 0 -command MGC::WireBond::Setup
            $wbm add separator
            $wbm add command -label "Place Bond Pads ..." \
                -underline 0 -command MGC::WireBond::PlaceBondPads
            $wbm add command -label "Place Bond Wires ..." \
                -underline 0 -command MGC::WireBond::PlaceBondWires
        }

        ##
        ##  GUI::Build::HelpPulldown
        ##
        proc HelpPulldown { mb } {
            set hm [menu .menubar.help -tearoff 0]
            $mb add cascade -label "Help" -menu $mb.help -underline 0
            $hm add command -label "About ..." \
                -accelerator "F1" -underline 0 \
                -command ediuHelpAbout
            $hm add command -label "Version ..." \
                -underline 0 \
                -command ediuHelpVersion
        }

        ##
        ##  GUI::Build::Notebook
        ##
        proc Notebook { } {
            ##  Build the notebook UI
            set nb [ttk::notebook .notebook]
            set GUI::widgets(notebook) $nb

            set dbf [ttk::frame $nb.dashboard]
            set GUI::widgets(dashboard) $dbf
            set tf [ttk::frame $nb.transcript]
            set GUI::widgets(transcript) $tf
            set sf [ttk::frame $nb.sourceview]
            set GUI::widgets(sourceview) $sf
            set lvf [ttk::frame $nb.layoutview]
            set GUI::widgets(layoutview) $lvf
            set nf [ttk::frame $nb.netlistview]
            set GUI::widgets(netlistview) $nf
            set ssf [ttk::frame $nb.sparsepinsview]
            set GUI::widgets(sparsepinsview) $ssf
            set nltf [ttk::frame $nb.netlisttable]
            set GUI::widgets(netlisttable) $nltf
            set knltf [ttk::frame $nb.kynnetlist]
            set GUI::widgets(kynnetlist) $knltf

            $nb add $dbf -text "Dashboard" -padding 4
            $nb add $lvf -text "Layout" -padding 4
            $nb add $tf -text "Transcript" -padding 4
            $nb add $sf -text "AIF Source File" -padding 4
            $nb add $nf -text "Netlist" -padding 4
            #$nb add $ssf -text "Sparse Pins" -padding 4
            $nb add $nltf -text "AIF Netlist" -padding 4
            $nb add $knltf -text "KYN Netlist" -padding 4

            #  Hide the netlist tab, it is used but shouldn't be visible
            #$nb hide $nf
            #$nb hide $ssf

            GUI::Build::Notebook::LayoutFrame $lvf
            GUI::Build::Notebook::AIFSourceFrame $sf
            GUI::Build::Notebook::TranscriptFrame $tf
            GUI::Build::Notebook::NetlistFrame $nf
            GUI::Build::Notebook::SparsePinsFrame $ssf
            GUI::Build::Notebook::AIFNetlistTableFrame $nltf
            GUI::Build::Notebook::KYNNetlistFrame $knltf
        }

        ##
        ##  GUI::Build::Notebook namespace
        ##
        namespace eval Notebook {

            ##
            ##  GUI::Build:Notebook::LayoutFrame
            ##
            proc LayoutFrame { lvf } {
                #  Canvas frame for Layout View
                set lvfcanvas [canvas $lvf.canvas -bg black \
                    -xscrollcommand [list $lvf.lvfcanvasscrollx set] \
                    -yscrollcommand [list $lvf.lvfcanvasscrolly set]]
                set GUI::widgets(layoutview) $lvfcanvas
                #$lvfcanvas configure -background black
                #$lvfcanvas configure -fg white
                ttk::scrollbar $lvf.lvfcanvasscrolly -orient v -command [list $lvfcanvas yview]
                ttk::scrollbar $lvf.lvfcanvasscrollx -orient h -command [list $lvfcanvas xview]
                grid $lvfcanvas -row 0 -column 0 -in $lvf -sticky nsew
                grid $lvf.lvfcanvasscrolly -row 0 -column 1 -in $lvf -sticky ns -columnspan 1
                grid $lvf.lvfcanvasscrollx -row 1 -column 0 -in $lvf -sticky ew -columnspan 1

                #  Add a couple of zooming buttons
                set bf [frame .buttonframe]
                button $bf.zoomin  -text "Zoom In"  -command "zoom $lvfcanvas 1.25" -relief groove -padx 3
                button $bf.zoomout -text "Zoom Out" -command "zoom $lvfcanvas 0.80" -relief groove -padx 3
                #button $bf.zoomfit -text "Zoom Fit" -command "zoom $lvfcanvas 1" -relief groove -padx 3
                button $bf.zoomin2x  -text "Zoom In 2x"  -command "zoom $lvfcanvas 2.00" -relief groove -padx 3
                button $bf.zoomout2x -text "Zoom Out 2x" -command "zoom $lvfcanvas 0.50" -relief groove -padx 3
                button $bf.zoomin5x  -text "Zoom In 5x"  -command "zoom $lvfcanvas 5.00" -relief groove -padx 3
                button $bf.zoomout5x -text "Zoom Out 5x" -command "zoom $lvfcanvas 0.20" -relief groove -padx 3
                #grid $bf.zoomin $bf.zoomout -sticky ew -columnspan 1
                #grid $bf.zoomin $bf.zoomout $bf.zoomfit
                grid $bf.zoomin $bf.zoomout $bf.zoomin2x $bf.zoomout2x $bf.zoomin5x $bf.zoomout5x
                grid $bf -in $lvf -sticky w

                grid columnconfigure $lvf 0 -weight 1
                grid    rowconfigure $lvf 0 -weight 1

                # Set up event bindings for canvas:
                bind $lvfcanvas <3> "zoomMark $lvfcanvas %x %y"
                bind $lvfcanvas <B3-Motion> "zoomStroke $lvfcanvas %x %y"
                bind $lvfcanvas <ButtonRelease-3> "zoomArea $lvfcanvas %x %y"
            }

            ##
            ##  GUI::Build:Notebook::TranscriptFrame
            ##
            proc TranscriptFrame { tf } {
                set tftext [ctext $tf.text -wrap none \
                    -xscrollcommand [list $tf.tftextscrollx set] \
                    -yscrollcommand [list $tf.tftextscrolly set]]
                $tftext configure -font EDIUFont -state disabled
                set GUI::widgets(transcript) $tftext
                ttk::scrollbar $tf.tftextscrolly -orient vertical -command [list $tftext yview]
                ttk::scrollbar $tf.tftextscrollx -orient horizontal -command [list $tftext xview]
                grid $tftext -row 0 -column 0 -in $tf -sticky nsew
                grid $tf.tftextscrolly -row 0 -column 1 -in $tf -sticky ns
                grid $tf.tftextscrollx x -row 1 -column 0 -in $tf -sticky ew
                grid columnconfigure $tf 0 -weight 1
                grid    rowconfigure $tf 0 -weight 1
            }

            ##
            ##  GUI::Build:Notebook::TranscriptFrame
            ##
            proc AIFSourceFrame { sf } {
                set sftext [ctext $sf.text -wrap none \
                    -xscrollcommand [list $sf.sftextscrollx set] \
                    -yscrollcommand [list $sf.sftextscrolly set]]
                $sftext configure -font EDIUFont -state disabled
                set GUI::widgets(sourceview) $sftext
                ttk::scrollbar $sf.sftextscrolly -orient vertical -command [list $sftext yview]
                ttk::scrollbar $sf.sftextscrollx -orient horizontal -command [list $sftext xview]
                grid $sftext -row 0 -column 0 -in $sf -sticky nsew
                grid $sf.sftextscrolly -row 0 -column 1 -in $sf -sticky ns
                grid $sf.sftextscrollx x -row 1 -column 0 -in $sf -sticky ew
                grid columnconfigure $sf 0 -weight 1
                grid    rowconfigure $sf 0 -weight 1
            }

            ##
            ##  GUI::Build:Notebook::NetlistFrame
            ##
            proc NetlistFrame { nf } {
                set nftext [ctext $nf.text -wrap none \
                    -xscrollcommand [list $nf.nftextscrollx set] \
                    -yscrollcommand [list $nf.nftextscrolly set]]
        
                $nftext configure -font EDIUFont -state disabled
                set GUI::widgets(netlistview) $nftext
                ttk::scrollbar $nf.nftextscrolly -orient vertical -command [list $nftext yview]
                ttk::scrollbar $nf.nftextscrollx -orient horizontal -command [list $nftext xview]
                grid $nftext -row 0 -column 0 -in $nf -sticky nsew
                grid $nf.nftextscrolly -row 0 -column 1 -in $nf -sticky ns
                grid $nf.nftextscrollx x -row 1 -column 0 -in $nf -sticky ew
                grid columnconfigure $nf 0 -weight 1
                grid    rowconfigure $nf 0 -weight 1
            }

            ##
            ##  GUI::Build:Notebook::SparsePinsFrame
            ##
            proc SparsePinsFrame { ssf } {
                set ssftext [ctext $ssf.text -wrap none \
                    -xscrollcommand [list $ssf.ssftextscrollx set] \
                    -yscrollcommand [list $ssf.ssftextscrolly set]]
                $ssftext configure -font EDIUFont -state disabled
                set GUI::widgets(sparsepinsview) $ssftext
                ttk::scrollbar $ssf.ssftextscrolly -orient vertical -command [list $ssftext yview]
                ttk::scrollbar $ssf.ssftextscrollx -orient horizontal -command [list $ssftext xview]
                grid $ssftext -row 0 -column 0 -in $ssf -sticky nsew
                grid $ssf.ssftextscrolly -row 0 -column 1 -in $ssf -sticky ns
                grid $ssf.ssftextscrollx x -row 1 -column 0 -in $ssf -sticky ew
                grid columnconfigure $ssf 0 -weight 1
                grid    rowconfigure $ssf 0 -weight 1
            }

            ##
            ##  GUI::Build:Notebook::AIFNetlistTableFrame
            ##
            proc AIFNetlistTableFrame { nltf } {
                set nltable [tablelist::tablelist $nltf.tl -stretch all -background white \
                    -xscrollcommand [list $nltf.nltablescrollx set] \
                    -yscrollcommand [list $nltf.nltablescrolly set] \
                    -fullseparators true -stripebackground "#ddd" -showseparators true -columns { \
                    0 "NETNAME" 0 "PADNUM" 0 "PADNAME" 0 "PAD_X" 0 "PAD_Y" 0 "BALLNUM" 0 "BALLNAME" \
                    0 "BALL_X" 0 "BALL_Y" 0 "FINNUM" 0 "FINNAME" 0 "FIN_X" 0 "FIN_Y" 0 "ANGLE" }]
                $nltable columnconfigure 0 -sortmode ascii
                $nltable columnconfigure 1 -sortmode ascii
                $nltable columnconfigure 2 -sortmode ascii

                #$nltable configure -font courier-bold -state disabled
                set GUI::widgets(netlisttable) $nltable
                ttk::scrollbar $nltf.nltablescrolly -orient vertical -command [list $nltable yview]
                ttk::scrollbar $nltf.nltablescrollx -orient horizontal -command [list $nltable xview]
                grid $nltable -row 0 -column 0 -in $nltf -sticky nsew
                grid $nltf.nltablescrolly -row 0 -column 1 -in $nltf -sticky ns
                grid $nltf.nltablescrollx x -row 1 -column 0 -in $nltf -sticky ew
                grid columnconfigure $nltf 0 -weight 1
                grid    rowconfigure $nltf 0 -weight 1
            }

            ##
            ##  GUI::Build:Notebook::KYNNetlistFrame
            ##
            proc KYNNetlistFrame { knltf } {
                set knltftext [ctext $knltf.text -wrap none \
                    -xscrollcommand [list $knltf.nftextscrollx set] \
                    -yscrollcommand [list $knltf.nftextscrolly set]]
        
                $knltftext configure -font EDIUFont -state disabled
                set GUI::widgets(kynnetlistview) $knltftext
                ttk::scrollbar $knltf.nftextscrolly -orient vertical -command [list $knltftext yview]
                ttk::scrollbar $knltf.nftextscrollx -orient horizontal -command [list $knltftext xview]
                grid $knltftext -row 0 -column 0 -in $knltf -sticky nsew
                grid $knltf.nftextscrolly -row 0 -column 1 -in $knltf -sticky ns
                grid $knltf.nftextscrollx x -row 1 -column 0 -in $knltf -sticky ew
                grid columnconfigure $knltf 0 -weight 1
                grid    rowconfigure $knltf 0 -weight 1
            }
        }
    }

    ##
    ##  Menus
    ##
    namespace eval Menus {
        ##
        ##  GUI::Menus::CentralLibraryMode
        ##
        proc CentralLibraryMode {} {
            $GUI::widgets(setupmenu) entryconfigure  3 -state disabled
            $GUI::widgets(setupmenu) entryconfigure 4 -state normal
            $GUI::widgets(setupmenu) entryconfigure 7 -state disabled
            #set ::ediu(targetPath) $::ediu(Nothing)
            GUI::StatusBar::UpdateStatus -busy off
        }

        ##
        ##  GUI::Menus::DesignMode
        ##
        proc DesignMode {} {
            $GUI::widgets(setupmenu) entryconfigure  3 -state normal
            $GUI::widgets(setupmenu) entryconfigure 4 -state disabled
            $GUI::widgets(setupmenu) entryconfigure 7 -state normal
            #set ::ediu(targetPath) $::ediu(Nothing)
            GUI::StatusBar::UpdateStatus -busy off
        }

        ##
        ##  GUI::Menus::BondWireEditMode
        ##
        proc BondWireEditMode {} {
            $GUI::widgets(setupmenu) entryconfigure  3 -state normal
            $GUI::widgets(setupmenu) entryconfigure 4 -state disabled
            $GUI::widgets(setupmenu) entryconfigure 7 -state normal
            #set ::ediu(targetPath) $::ediu(Nothing)
            GUI::StatusBar::UpdateStatus -busy off
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
        variable ConnectMode on
        variable Visibility on
        variable CellGeneration
        variable CellSuffix none

        array set CellGeneration {
            MirrorNone on
            MirrorX off
            MirrorY off
            MirrorXY off
        }

        ##
        ##  GUI::Dashboard::Build
        ##
        proc Build {} {
            variable CellGeneration

            set db $GUI::widgets(dashboard)
            set dbf [frame $db.frame -borderwidth 5 -relief ridge]

#pack $db -anchor nw
#pack $dbf -in $db -anchor nw

            ##  Mode
            labelframe $dbf.mode -pady 2 -text "Mode" -padx 2
            foreach i { "Design" "Central Library" } {
                radiobutton $dbf.mode.b$i -text "$i" -variable GUI::Dashboard::Mode \
	            -relief flat -value $i
                pack $dbf.mode.b$i  -side top -pady 2 -anchor w
            }

            ##  Cell Suffix
            set suffixes { \
                none "None" \
                numeric "Numeric (-1, -2, -3, etc.)" \
                alpha "Alpha (-A, -B, -C, etc.)" \
                datestamp "Date Stamp (YYYY-MM-DD)" \
                timestamp "Time Stamp (YYYY-MM-DD-HH:MM:SS)" \
            }
            labelframe $dbf.cellsuffix -pady 2 -text "Cell Name Suffix (aka Version)" -padx 2
            foreach { i  j } $suffixes {
                radiobutton $dbf.cellsuffix.b$i -text "$j" \
                    -variable GUI::Dashboard::CellSuffix -relief flat -value $i
                pack $dbf.cellsuffix.b$i  -side top -pady 2 -anchor w
            }

            ##  Cell Generation
            labelframe $dbf.cellgeneration -pady 2 -text "Cell Generation" -padx 2
            foreach { i j } { MirrorNone "Default" MirrorX "Mirror X Coordinates" MirrorY "Mirror Y Coordinates" MirrorXY "Mirror X and Y Coordinates" } {
                checkbutton $dbf.cellgeneration.b$i -text "$j" -variable GUI::Dashboard::CellGeneration($i) \
	            -relief flat -onvalue on -offvalue off
                pack $dbf.cellgeneration.b$i  -side top -pady 2 -anchor w
            }

            ##  Visibility
            labelframe $dbf.visibility -pady 2 -text "Application Visibility" -padx 2
            foreach { i j } { on On off Off } {
                radiobutton $dbf.visibility.b$i -text "$j" -variable GUI::Dashboard::Visibility \
	            -relief flat -value $i
                pack $dbf.visibility.b$i  -side top -pady 2 -anchor w
            }

            ##  Connection
            labelframe $dbf.connection -pady 2 -text "Application Connection" -padx 2
            foreach { i j } { on On off Off } {
                radiobutton $dbf.connection.b$i -text "$j" -variable GUI::Dashboard::ConnectMode \
	            -relief flat -value $i
                pack $dbf.connection.b$i  -side top -pady 2 -anchor w
            }

            ##  AIF File
            labelframe $dbf.aiffile -pady 5 -text "AIF File" -padx 5
            entry $dbf.aiffile.e -width 65 -relief sunken -bd 2 -textvariable GUI::Dashboard::AIFFile
            button $dbf.aiffile.b -text "AIF File ..."  -width 13 -anchor w \
                -command GUI::Dashboard::SelectAIFFile
            grid $dbf.aiffile.e -row 0 -column 0 -pady 5 -padx 5 -sticky w
            grid $dbf.aiffile.b -row 0 -column 1 -pady 5 -padx 5 -sticky ew

            ##  Design Path
            labelframe $dbf.design -pady 5 -text "Design" -padx 5
            entry $dbf.design.e -width 65 -relief sunken -bd 2 -textvariable GUI::Dashboard::FullDesignPath
            button $dbf.design.b -text "Design ..." -width 13 -anchor w -command \
                { set GUI::Dashboard::FullDesignPath [tk_getOpenFile -filetypes {{PCB .pcb}}] }
            grid $dbf.design.e -row 0 -column 0 -pady 5 -padx 5 -sticky w
            grid $dbf.design.b -row 0 -column 1 -pady 5 -padx 5 -sticky ew

            ##  Library Path
            labelframe $dbf.library -pady 5 -text "Central Library" -padx 5
            entry $dbf.library.le -width 65 -relief sunken -bd 2 -textvariable GUI::Dashboard::LibraryPath
            button $dbf.library.lb -text "Library ..." -command GUI::Dashboard::SelectCentralLibrary -anchor w
            entry $dbf.library.ce -width 35 -relief sunken -bd 2 -textvariable GUI::Dashboard::CellPartition
            button $dbf.library.cb -text "Cell Partition ..." -state disabled -command GUI::Dashboard::SelectCellPartition
            entry $dbf.library.pe -width 35 -relief sunken -bd 2 -textvariable GUI::Dashboard::PartPartition
            button $dbf.library.pb -text "PDB Partition ..." -state disabled -command GUI::Dashboard::SelectPartPartition

            grid $dbf.library.le -row 0 -column 0 -pady 5 -padx 5 -sticky w
            grid $dbf.library.ce -row 1 -column 0 -pady 5 -padx 5 -sticky w
            grid $dbf.library.pe -row 2 -column 0 -pady 5 -padx 5 -sticky w
            grid $dbf.library.lb -row 0 -column 1 -pady 5 -padx 5 -sticky ew
            grid $dbf.library.cb -row 1 -column 1 -pady 5 -padx 5 -sticky ew
            grid $dbf.library.pb -row 2 -column 1 -pady 5 -padx 5 -sticky ew

            ##  Place all of the widgets
            grid $dbf.aiffile        -row 0 -column 0 -sticky new -padx 10 -pady 10 -columnspan 2
            grid $dbf.design         -row 1 -column 0 -sticky new -padx 10 -pady 10 -columnspan 2
            grid $dbf.library        -row 2 -column 0 -sticky new -padx 10 -pady 10 -columnspan 2
            grid $dbf.mode           -row 0 -column 2 -sticky new -padx 10 -pady 10
            grid $dbf.connection     -row 1 -column 2 -sticky new -padx 10 -pady 10
            grid $dbf.visibility     -row 2 -column 2 -sticky new -padx 10 -pady 10
            grid $dbf.cellgeneration -row 3 -column 0 -sticky new -padx 10 -pady 10
            grid $dbf.cellsuffix     -row 3 -column 1 -sticky new -padx 10 -pady 10

            grid $dbf -row 0 -column 0 -sticky nw -padx 10 -pady 10
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
            set db $GUI::widgets(dashboard)
            set GUI::Dashboard::LibraryPath [tk_getOpenFile -filetypes {{LMC .lmc}}]

            ##  Valid LMC selected?  If so, enable the buttons and load the partitions
            if { [expr { $GUI::Dashboard::LibraryPath ne "" }] } {
                $dbf.library.cb configure -state normal
                $dbf.library.pb configure -state normal

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

    ##
    ##  Define the GUI::Dashboard namespace and procedure supporting operations
    ##
    namespace eval StatusBar {
        ##
        ##  GUI::StatusBar::UpdateStatus
        ##
        proc UpdateStatus { args } {
            ##  Process command arguments
            array set V { -busy off } ;# Default values
            foreach {a value} $args {
                if {! [info exists V($a)]} {error "unknown option $a"}
                if {$value == {}} {error "value of \"$a\" missing"}
                set V($a) $value
            }

            ##  Set the color of the status light
            set slf $::widgets(statuslight)
            if { [string is true $V(-busy)] } {
                $slf configure -background red
            } else {
                $slf configure -background green
            } 
        }
    }
}
