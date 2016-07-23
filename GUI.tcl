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

    ##
    ##  GUI::Build
    ##
    proc Build {} {
        #  Define fixed with font used for displaying text
        font create xAIFFont -family Courier -size 10 -weight bold

        ##  Build menus and notebook structure
        GUI::Build::Menus
        GUI::Build::Notebook

        ##  Build the status bar
        GUI::Build::StatusBar

        ##  Build the Dashboard
        GUI::Build::Dashboard
        GUI::Build::WireBondParameters

        ##  Arrange the top level widgets
        grid $GUI::widgets(notebook) -row 0 -column 0 -sticky nsew -padx 4 -pady 4
        grid $GUI::widgets(statusframe) -row 1 -column 0 -sticky sew -padx 4 -pady 4

        grid columnconfigure . 0 -weight 1
        grid    rowconfigure . 0 -weight 1

        #  Configure the main window
        wm title . $xAIF::Settings(xAIF).
        wm geometry . 1024x768
        . configure -menu .menubar -width 200 -height 150

        #  Bind some function keys
        bind . "<Key F1>" { GUI::Help::About }
        bind . "<Key F5>" { GUI::Dashboard::SelectAIFFile }
        bind . "<Key F6>" { GUI::File::CloseAIF }

        ## Update the status fields
        GUI::StatusBar::UpdateStatus -busy off
    }

    #
    #  Transcript a message with a severity level
    #
    proc Transcript {args} {
        ##  Process command arguments
        array set V { {-msg} "" {-severity} note} ;# Default values
        foreach {a value} $args {
            if {! [info exists V($a)]} {
                error "unknown option $a"
            } elseif {$value == {}} {
                error "value of \"$a\" missing"
            } else {
                set V($a) $value
            }
        }

        ##  Make sure what we received makes sense
        if {[string equal "" $V(-msg)]} {
            error "value of \"-msg\" option is missing"
        }

        if { [lsearch [list note warning error] $V(-severity)] == -1 } {
            error "value of \"$a\" must be one of note, warning, or error"
        }

        ##  Generate the message
        set msg [format "# %s:  %s" [string toupper $V(-severity) 0 0] $V(-msg)]

        set txt $GUI::widgets(transcript)
        $txt configure -state normal
        $txt insert end "$msg\n"
        $txt see end
        $txt configure -state disabled
        set GUI::widgets(lastmsg) $msg
        update idletasks

        if { $xAIF::Settings(consoleEcho) } {
            puts $msg
            flush stdout
        }
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
    ##  Define the GUI::Build namespace and procedure supporting operations
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
            GUI::Build::DesignPulldown $mb
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
                -accelerator "F5" -underline 0 -command GUI::Dashboard::SelectAIFFile
            $fm add command -label "Close AIF" \
                -accelerator "F6" -underline 0 -command GUI::File::CloseAIF
            $fm add separator
            $fm add command -label "Create Design Stub ..." \
                -underline 7 -command MGC::Generate::DesignStub
            $fm add separator
            $fm add command -label "Export KYN ..." \
                -underline 7 -command Netlist::Export::KYN
            $fm add command -label "Export Placement ..." \
                -underline 7 -command Netlist::Export::Placement
            $fm add command -label "Export Wire Model ..." \
                -underline 7 -command MGC::WireBond::ExportWireModel
            #$fm add separator
            #$fm add command -label "Open Sparse Pins ..." \
                -underline 1 -command GUI::File::OpenSparsePins
            #$fm add command -label "Close Sparse Pins " \
                #-underline 1 -command GUI::File::CloseSparsePins
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
                -variable GUI::Dashboard::Mode -value $xAIF::Settings(designMode) \
                -command GUI::Menus::DesignMode
            $sm add radiobutton -label "Central Library Mode" -underline 0 \
                -variable GUI::Dashboard::Mode -value $xAIF::Settings(libraryMode) \
                -command GUI::Menus::CentralLibraryMode
            $sm add separator
            $sm add command \
                -label "Design ..." -state normal -underline 1 -command \
                { set GUI::Dashboard::FullDesignPath [tk_getOpenFile -filetypes {{PCB .pcb}}] }
            $sm add command \
                -label "Central Library ..." -state disabled \
                -underline 2 -command GUI::Dashboard::SelectCentralLibrary
            #$sm add separator
            #$sm add checkbutton -label "Sparse Mode" -underline 0 \
                #-variable xAIF::Settings(sparseMode) -command GUI::Dashboard::ToggleSparseMode
            $sm add separator
            $sm add checkbutton -label "Application Visibility" \
                -variable GUI::Dashboard::Visibility -onvalue on -offvalue off \
                -command  { GUI::Transcript -severity note -msg [format "Application visibility is now %s." \
                [expr [string is true $GUI::Dashboard::Visibility] ? "on" : "off"]] }
            $sm add checkbutton -label "Connect to Running Application" \
                -variable xAIF::Settings(connectMode) -onvalue on -offvalue off \
                -command  { GUI::Transcript -severity note -msg [format "Application Connect mode is now %s." \
                $xAIF::Settings(connectMode) ] ; GUI::StatusBar::UpdateStatus -busy off }
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
                 -command { GUI::View::Zoom $GUI::widgets(layoutview) 2.0 }
            $vm.in add command -label "5x" -underline 0 \
                 -command { GUI::View::Zoom $GUI::widgets(layoutview)  5.0 }
            $vm.in add command -label "10x" -underline 0 \
                 -command { GUI::View::Zoom $GUI::widgets(layoutview)  10.0 }
            $vm add cascade -label "Zoom Out" -underline 5 -menu $vm.out
            menu $vm.out -tearoff 0
            $vm.out add cascade -label "2x" -underline 0 \
                 -command { GUI::View::Zoom $GUI::widgets(layoutview)  0.5 }
            $vm.out add command -label "5x" -underline 0 \
                 -command { GUI::View::Zoom $GUI::widgets(layoutview)  0.2 }
            $vm.out add command -label "10x" -underline 0 \
                 -command { GUI::View::Zoom $GUI::widgets(layoutview)  0.1 }

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
                foreach p [array names ::pads] { set GUI::pads([lindex $p 0]) on }  }
            $vm.pads add cascade -label "All Off" -underline 5 \
                -command { GUI::Visibility "pad" -all true -mode off ; \
                foreach p [array names ::pads] { set GUI::pads([lindex $p 0]) off }  }
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
        ##  GUI::Build::DesignPulldown
        ##
        proc DesignPulldown { mb } {
            set dm [menu $mb.design -tearoff 0]
            set GUI::widgets(designmenu) $dm
            $mb add cascade -label "Design" -menu $mb.design -underline 0
            $dm add command -label "Set Package Outline" \
                -underline 4 -command MGC::Design::SetPackageOutline
            $dm add command -label "Set Route Border" \
                -underline 4 -command MGC::Design::SetRouteBorder
            $dm add command -label "Set Manufacturing Outline" \
                -underline 4 -command MGC::Design::SetManufacturingOutline
            $dm add command -label "Set Test Fixture Outline" \
                -underline 4 -command MGC::Design::SetTestFixtureOutline
            $dm add separator
            $dm add command -label "Check Database Units" \
                -underline 6 -command MGC::Design::CheckDatabaseUnits
            $dm add separator
            $dm add command -label "Set Package Cell" \
                -underline 0 -command MGC::Design::SetPackageCell
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
            $wbm add command -label "Apply Wire Bond Properties" \
                -underline 0 -command MGC::WireBond::ApplyProperies
            $wbm add separator
            $wbm add command -label "Place Bond Pads ..." \
                -underline 11 -command MGC::WireBond::PlaceBondPads
            $wbm add command -label "Place Bond Wires ..." \
                -underline 11 -command MGC::WireBond::PlaceBondWires
        }

        ##
        ##  GUI::Build::HelpPulldown
        ##
        proc HelpPulldown { mb } {
            set hm [menu .menubar.help -tearoff 0]
            $mb add cascade -label "Help" -menu $mb.help -underline 0
            $hm add command -label "About ..." \
                -accelerator "F1" -underline 0 \
                -command GUI::Help::About
            $hm add command -label "Version ..." \
                -underline 0 \
                -command GUI::Help::Version
        }

        ##
        ##  GUI::Build::StatusBar
        ##
        proc StatusBar { } {
            set sf [ttk::frame .status -borderwidth 5 -relief sunken]

            set slf [ttk::frame .statuslightframe -width 20 -borderwidth 3 -relief raised]
            set sl [frame $slf.statuslight -width 15 -background green]
            set GUI::widgets(statusframe) $sf
            set GUI::widgets(statuslight) $sl
            pack $sl -in $slf -fill both -expand yes
            $sl configure -background green

            set pbf [ttk::frame .progressbarframe -width 20 -borderwidth 3 -relief raised]
            #set pb [frame $pbf.progressbar -width 15 -background green]
            set pb [ttk::progressbar $pbf.progressbar -orient horizontal -mode indeterminate]
            set GUI::widgets(progressframe) $sf
            set GUI::widgets(progressbar) $pb
            pack $pb -in $pbf -fill both -expand yes

            #set mode [ttk::label .mode \
            #    -padding 5 -textvariable xAIF::widgets(mode)]
            #set AIFfile [ttk::label .aifFile \
            #    -padding 5 -textvariable xAIF::widgets(AIFFile)]
            #set AIFType [ttk::label .aifType \
            #    -padding 5 -textvariable xAIF::widgets(AIFType)]
            #set targetpath [ttk::label .targetPath \
            #    -padding 5 -textvariable xAIF::widgets(targetPath)]

            set lastmsg [ttk::label .lastmsg \
                -padding 5 -textvariable GUI::widgets(lastmsg)]

            pack $slf -side left -in $sf -fill both
            pack $pbf -side right -in $sf -fill both
            #pack $mode $AIFfile $AIFType $targetpath -side left -in $sf -fill both -padx 10
            pack $lastmsg -side left -in $sf -fill both -padx 10
            grid $sf -sticky sew -padx 4 -pady 4
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
            set wbpf [ttk::frame $nb.wirebondparams]
            set GUI::widgets(wirebondparams) $wbpf

            $nb add $dbf -text "Dashboard" -padding 4
            $nb add $lvf -text "Layout" -padding 4
            $nb add $tf -text "Transcript" -padding 4
            $nb add $sf -text "AIF Source File" -padding 4
            $nb add $nf -text "Netlist" -padding 4
            $nb add $ssf -text "Sparse Pins" -padding 4
            $nb add $nltf -text "AIF Netlist" -padding 4
            $nb add $knltf -text "KYN Netlist" -padding 4
            $nb add $wbpf -text "Wire Bond Parameters" -padding 4

            #  Hide the netlist tab, it is used but shouldn't be visible
            $nb hide $nf
            $nb hide $ssf

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
                button $bf.zoomin  -text "Zoom In"  -command "GUI::View::Zoom $lvfcanvas 1.25" -relief groove -padx 3
                button $bf.zoomout -text "Zoom Out" -command "GUI::View::Zoom $lvfcanvas 0.80" -relief groove -padx 3
                #button $bf.zoomfit -text "Zoom Fit" -command "GUI::View::Zoom $lvfcanvas 1" -relief groove -padx 3
                button $bf.zoomin2x  -text "Zoom In 2x"  -command "GUI::View::Zoom $lvfcanvas 2.00" -relief groove -padx 3
                button $bf.zoomout2x -text "Zoom Out 2x" -command "GUI::View::Zoom $lvfcanvas 0.50" -relief groove -padx 3
                button $bf.zoomin5x  -text "Zoom In 5x"  -command "GUI::View::Zoom $lvfcanvas 5.00" -relief groove -padx 3
                button $bf.zoomout5x -text "Zoom Out 5x" -command "GUI::View::Zoom $lvfcanvas 0.20" -relief groove -padx 3
                button $bf.invertxaxis -text "Invert X Axis" -command "$lvfcanvas scale all 0 0 -1 1" -relief groove -padx 3
                button $bf.invertyaxis -text "Invert Y Axis" -command "$lvfcanvas scale all 0 0 1 -1" -relief groove -padx 3
                #grid $bf.zoomin $bf.zoomout -sticky ew -columnspan 1
                #grid $bf.zoomin $bf.zoomout $bf.zoomfit
                grid $bf.zoomin $bf.zoomout $bf.zoomin2x $bf.zoomout2x $bf.zoomin5x $bf.zoomout5x $bf.invertxaxis $bf.invertyaxis
                grid $bf -in $lvf -sticky w

                grid columnconfigure $lvf 0 -weight 1
                grid    rowconfigure $lvf 0 -weight 1

                # Set up event bindings for canvas:
                bind $lvfcanvas <3> "GUI::View::ZoomMark $lvfcanvas %x %y"
                bind $lvfcanvas <B3-Motion> "GUI::View::ZoomStroke $lvfcanvas %x %y"
                bind $lvfcanvas <ButtonRelease-3> "GUI::View::ZoomArea $lvfcanvas %x %y"
            }

            ##
            ##  GUI::Build:Notebook::TranscriptFrame
            ##
            proc TranscriptFrame { tf } {
                set tftext [ctext $tf.text -wrap none \
                    -xscrollcommand [list $tf.tftextscrollx set] \
                    -yscrollcommand [list $tf.tftextscrolly set]]
                $tftext configure -font xAIFFont -state disabled
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
            ##  GUI::Build:Notebook::AIFSourceFrame
            ##
            proc AIFSourceFrame { sf } {
                set sftext [ctext $sf.text -wrap none \
                    -xscrollcommand [list $sf.sftextscrollx set] \
                    -yscrollcommand [list $sf.sftextscrolly set]]
                $sftext configure -font xAIFFont -state disabled
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

                $nftext configure -font xAIFFont -state disabled
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
                $ssftext configure -font xAIFFont -state disabled
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
                    -stripebackground "#ddd" -showseparators true -columns { \
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

                $knltftext configure -font xAIFFont -state disabled
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

        ##
        ##  GUI::Build::Dashboard
        ##
        proc Dashboard {} {
            set db $GUI::widgets(dashboard)
            set dbf [frame $db.frame -borderwidth 5 -relief ridge]

            ##  Mode
            labelframe $dbf.mode -pady 2 -text "Mode" -padx 2
            foreach { i j } [list $xAIF::Settings(designMode) "Design" $xAIF::Settings(libraryMode) "Central Library" ] {
                radiobutton $dbf.mode.b$i -text "$j" -variable GUI::Dashboard::Mode -relief flat -value $i \
                    -command { if { [string equal $GUI::Dashboard::Mode $xAIF::Settings(designMode)] } \
                    { GUI::Menus::DesignMode } else { GUI::Menus::CentralLibraryMode } }
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
            foreach { i j } { MirrorNone "Default" MirrorX "Mirror across Y-Axis" MirrorY "Mirror across X-Axis" MirrorXY "Mirror across X & Y Axis" } {
                checkbutton $dbf.cellgeneration.b$i -text "$j" -variable GUI::Dashboard::CellGeneration($i) \
	            -relief flat -onvalue on -offvalue off
                pack $dbf.cellgeneration.b$i  -side top -pady 2 -anchor w
            }

            ##  BGA Generation
            labelframe $dbf.bgageneration -pady 2 -text "BGA Generation" -padx 2
            foreach { i j } { std Standard mso "Mount Side Opposite" } {
                radiobutton $dbf.bgageneration.b$i -text "$j" -variable GUI::Dashboard::BGAGeneration \
	            -relief flat -value $i
                pack $dbf.bgageneration.b$i  -side top -pady 2 -anchor w
            }
            ##  Until VX.2, a bug in the API prevents generating MSO cells so disable the radio button.
            $dbf.bgageneration.bmso configure -state disabled

            ##  Default Cell Height
            labelframe $dbf.defaultcellheight -pady 5 -text "Default Cell Height (um)" -padx 5
            entry $dbf.defaultcellheight.e -width 15 -relief sunken -bd 2 -textvariable GUI::Dashboard::DefaultCellHeight
            pack $dbf.defaultcellheight.e

            ##  Visibility
            labelframe $dbf.visibility -pady 2 -text "Application Visibility" -padx 2
            foreach { i j } { on On off Off } {
                radiobutton $dbf.visibility.b$i -text "$j" -variable GUI::Dashboard::Visibility \
	                -relief flat -value $i -command { GUI::Transcript -severity note -msg \
                    [format "Application visibility is now %s." \
                    [expr [string is true $GUI::Dashboard::Visibility] ? "on" : "off"]] }
                pack $dbf.visibility.b$i  -side top -pady 2 -anchor w
            }

            ##  Connection
            labelframe $dbf.connection -pady 2 -text "Application Connection" -padx 2
            foreach { i j } { on On off Off } {
                radiobutton $dbf.connection.b$i -text "$j" -variable xAIF::Settings(connectMode) \
	                -relief flat -value $i -command {GUI::Transcript -severity note -msg \
                    [format "Application Connect mode is now %s." \
                    $xAIF::Settings(connectMode) ] ; GUI::StatusBar::UpdateStatus -busy off }
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


            ##  Bond Wire Setup
            #labelframe $dbf.bondwireparams -pady 5 -text "Default Bond Wire Setup" -padx 5

            ##  WBParameters
            labelframe $dbf.wbparameters -pady 5 -text "Wire Bond Parameters" -padx 5
            entry $dbf.wbparameters.e -width 110 -relief sunken -bd 2 \
                -textvariable GUI::Dashboard::WBParameters -state readonly
            grid $dbf.wbparameters.e -row 0 -column 0 -pady 5 -padx 5 -sticky w

            ##  WBDRCProperty
            labelframe $dbf.wbdrcproperty -pady 5 -text "Wire Bond DRC Property" -padx 5
            entry $dbf.wbdrcproperty.e -width 110 -relief sunken -bd 2 \
                -textvariable GUI::Dashboard::WBDRCProperty -state readonly
            grid $dbf.wbdrcproperty.e -row 0 -column 0 -pady 5 -padx 5 -sticky w


            ttk::separator $dbf.sep1 -orient vertical
            ttk::separator $dbf.sep2 -orient horizontal
            ttk::separator $dbf.sep3 -orient horizontal

            ##  Place all of the widgets
            grid $dbf.aiffile           -row 0 -column 0 -sticky new -padx 10 -pady 8 -columnspan 2
            grid $dbf.design            -row 1 -column 0 -sticky new -padx 10 -pady 8 -columnspan 2
            grid $dbf.library           -row 2 -column 0 -sticky new -padx 10 -pady 8 -columnspan 2
            grid $dbf.sep1              -row 0 -column 2 -sticky nsew -padx 3 -pady 3 -rowspan 3
            grid $dbf.mode              -row 0 -column 3 -sticky new -padx 10 -pady 8
            grid $dbf.connection        -row 1 -column 3 -sticky new -padx 10 -pady 8
            grid $dbf.visibility        -row 2 -column 3 -sticky new -padx 10 -pady 8
            grid $dbf.sep2              -row 3 -column 0 -sticky nsew -padx 3 -pady 3 -columnspan 4
            grid $dbf.cellgeneration    -row 4 -column 0 -sticky new -padx 10 -pady 8 -rowspan 2
            grid $dbf.cellsuffix        -row 4 -column 1 -sticky new -padx 10 -pady 8 -columnspan 2 -rowspan 2
            grid $dbf.bgageneration     -row 4 -column 3 -sticky new -padx 10 -pady 8 -rowspan 2
            grid $dbf.defaultcellheight -row 5 -column 3 -sticky sew -padx 10 -pady 8
            grid $dbf.sep3              -row 6 -column 0 -sticky nsew -padx 3 -pady 3 -columnspan 5
            grid $dbf.wbparameters      -row 7 -column 0 -sticky new -padx 10 -pady 8 -columnspan 5
            grid $dbf.wbdrcproperty     -row 8 -column 0 -sticky new -padx 10 -pady 8 -columnspan 5

            grid $dbf -row 0 -column 0 -sticky nw -padx 10 -pady 10
        }

        ##
        ##  GUI::Build::WireBondParameters
        ##
        proc WireBondParameters {} {
            set wbp $GUI::widgets(wirebondparams)
            set wbpf [frame $wbp.frame -borderwidth 5 -relief ridge]

            ##  Units
            labelframe $wbpf.units -pady 2 -text "Units" -padx 2
            foreach { i j } { um "Microns" th "Thousandths" } {
                radiobutton $wbpf.units.b$i -text "$j" -variable MGC::WireBond::Units \
	            -relief flat -value $i
                pack $wbpf.units.b$i  -side top -pady 2 -anchor w
            }

            ##  Angle
            labelframe $wbpf.angle -pady 2 -text "Angle" -padx 2
            foreach { i j } { deg "Degrees" rad "Radians" } {
                radiobutton $wbpf.angle.b$i -text "$j" -variable MGC::WireBond::Angle \
	            -relief flat -value $i
                pack $wbpf.angle.b$i  -side top -pady 2 -anchor w
            }

            ##  Wire Bond Parameters
            labelframe $wbpf.wbparameters -pady 2 -text "Wire Bond Parameters" -padx 2
            foreach i  [array names MGC::WireBond::WBParameters] {
                label $wbpf.wbparameters.l$i -text "$i:"
                entry $wbpf.wbparameters.e$i -relief sunken \
                    -textvariable MGC::WireBond::WBParameters($i)
                pack $wbpf.wbparameters.l$i  -side left -pady 2 -anchor w
                pack $wbpf.wbparameters.e$i  -side left -pady 2 -anchor w -expand true
                grid $wbpf.wbparameters.l$i $wbpf.wbparameters.e$i -padx 3 -pady 3 -sticky w
            }
            button $wbpf.wbparameters.b -text "Select Bond Pad ..." -command MGC::WireBond::SelectBondPad
            grid $wbpf.wbparameters.b -padx 3 -pady 3 -sticky s -column 1

            ##  Wire Bond DRC Property
            labelframe $wbpf.wbdrcproperty -pady 2 -text "Wire Bond DRC Property" -padx 2
            foreach i [array names MGC::WireBond::WBDRCProperty] {
                label $wbpf.wbdrcproperty.l$i -text "$i:"
                entry $wbpf.wbdrcproperty.e$i -relief sunken -textvariable MGC::WireBond::WBDRCProperty($i)
                pack $wbpf.wbdrcproperty.l$i  -side left -pady 2 -anchor w
                pack $wbpf.wbdrcproperty.e$i  -side left -pady 2 -anchor w -expand true
                grid $wbpf.wbdrcproperty.l$i $wbpf.wbdrcproperty.e$i -padx 3 -pady 3 -sticky w
            }

            ##  Wire Bond Rule
            #labelframe $wbpf.wbrule -pady 2 -text "Wire Bond Rule" -padx 2
            #foreach i [array names MGC::WireBond::WBRule] {
            #    label $wbpf.wbrule.l$i -text "$i:"
            #    entry $wbpf.wbrule.e$i -relief sunken -textvariable MGC::WireBond::WBRule($i)
            #    pack $wbpf.wbrule.l$i  -side left -pady 2 -anchor w
            #    pack $wbpf.wbrule.e$i  -side left -pady 2 -anchor w -expand true
            #    grid $wbpf.wbrule.l$i $wbpf.wbrule.e$i -padx 3 -pady 3 -sticky w
            #}

            ##  Bond Wire Setup
            #labelframe $wbpf.bondwireparams -pady 5 -text "Default Bond Wire Setup" -padx 5

            ##  WBParameters
            labelframe $wbpf.wbparametersval -pady 2 -text "Wire Bond Parameters Property Value" -padx 5
            entry $wbpf.wbparametersval.e -width 120 -relief sunken -bd 2 \
                -textvariable GUI::Dashboard::WBParameters -state readonly
            button $wbpf.wbparametersval.b -text "Update" -command MGC::WireBond::UpdateParameters
            grid $wbpf.wbparametersval.b -row 0 -column 0 -pady 2 -padx 5 -sticky w
            grid $wbpf.wbparametersval.e -row 0 -column 1 -pady 2 -padx 5 -sticky w

            ##  WBDRCProperty
            labelframe $wbpf.wbdrcpropertyval -pady 2 -text "Wire Bond DRC Property Property Value" -padx 5
            entry $wbpf.wbdrcpropertyval.e -width 120 -relief sunken -bd 2 \
                -textvariable GUI::Dashboard::WBDRCProperty -state readonly
            button $wbpf.wbdrcpropertyval.b -text "Update" -command MGC::WireBond::UpdateDRCProperty
            grid $wbpf.wbdrcpropertyval.b -row 0 -column 0 -pady 2 -padx 5 -sticky w
            grid $wbpf.wbdrcpropertyval.e -row 0 -column 1 -pady 2 -padx 5 -sticky w

            ##  WBRule
            labelframe $wbpf.wbrule -pady 2 -text "Default Wire Model" -padx 5
            set tftext [text $wbpf.wbrule.text -wrap word  -height 10 \
                -xscrollcommand [list $wbpf.wbrule.tftextscrollx set] \
                -yscrollcommand [list $wbpf.wbrule.tftextscrolly set]]
            $tftext configure -font xAIFFont -state disabled
            ttk::scrollbar $wbpf.wbrule.tftextscrolly -orient vertical -command [list $tftext yview]
            ttk::scrollbar $wbpf.wbrule.tftextscrollx -orient horizontal -command [list $tftext xview]
            grid $tftext -row 0 -column 0 -in $wbpf.wbrule -sticky nsew
            grid $wbpf.wbrule.tftextscrolly -row 0 -column 1 -in $wbpf.wbrule -sticky ns
            grid $wbpf.wbrule.tftextscrollx x -row 1 -column 0 -in $wbpf.wbrule -sticky ew
            grid columnconfigure $wbpf.wbrule 0 -weight 1
            grid    rowconfigure $wbpf.wbrule 0 -weight 1

            $wbpf.wbrule.text configure -state normal
            $wbpf.wbrule.text insert 1.0 $MGC::WireBond::WBRule(Value)
            $wbpf.wbrule.text configure -state disabled
            #puts $MGC::WireBond::WBRule(Value)

            ttk::separator $wbpf.sep1 -orient vertical
            ttk::separator $wbpf.sep2 -orient vertical
            ttk::separator $wbpf.sep3 -orient horizontal

            ##  Place all of the widgets
            grid $wbpf.units            -row 0 -column 0 -sticky new -padx 10 -pady 8
            grid $wbpf.angle            -row 1 -column 0 -sticky new -padx 10 -pady 8
            grid $wbpf.sep1             -row 0 -column 1 -sticky nsew -padx 3 -pady 3 -rowspan 4
            grid $wbpf.wbparameters     -row 0 -column 2 -sticky new -padx 10 -pady 8 -rowspan 2
            grid $wbpf.sep2             -row 0 -column 3 -sticky nsew -padx 3 -pady 3 -rowspan 4
            grid $wbpf.wbdrcproperty    -row 0 -column 4 -sticky new -padx 10 -pady 8 -rowspan 2
            #grid $wbpf.wbrule           -row 0 -column 4 -sticky new -padx 10 -pady 8 -rowspan 2
            grid $wbpf.sep3             -row 5 -column 0 -sticky nsew -padx 2 -pady 2 -columnspan 5
            grid $wbpf.wbparametersval  -row 6 -column 0 -sticky new -padx 10 -pady 8 -columnspan 5
            grid $wbpf.wbdrcpropertyval -row 7 -column 0 -sticky new -padx 10 -pady 8 -columnspan 5
            grid $wbpf.wbrule           -row 8 -column 0 -sticky new -padx 10 -pady 8 -columnspan 5

            ##  Want to expand everything to fill frame but this doesn't work.  :-(
            grid $wbpf -row 0 -column 0 -sticky nsew -padx 0 -pady 0
        }
    }

    ##
    ##  Define the GUI::Menus namespace and procedure supporting operations
    ##
    namespace eval Menus {
        ##
        ##  GUI::Menus::CentralLibraryMode
        ##
        proc CentralLibraryMode {} {
            $GUI::widgets(setupmenu) entryconfigure  3 -state disabled
            $GUI::widgets(setupmenu) entryconfigure 4 -state normal
            #$GUI::widgets(setupmenu) entryconfigure 7 -state disabled

            ##  Disable the Design pulldown menu
            $GUI::widgets(designmenu) entryconfigure 0 -state disabled
            $GUI::widgets(designmenu) entryconfigure 1 -state disabled
            $GUI::widgets(designmenu) entryconfigure 2 -state disabled
            $GUI::widgets(designmenu) entryconfigure 3 -state disabled
            $GUI::widgets(designmenu) entryconfigure 5 -state disabled

            ##  Disable the GUI based on mode
            set dbf $GUI::widgets(dashboard).frame
            $dbf.design.e configure -state disabled
            $dbf.design.b configure -state disabled
            $dbf.library.le configure -state normal
            $dbf.library.lb configure -state normal
            $dbf.library.ce configure -state normal
            $dbf.library.cb configure -state normal
            $dbf.library.pe configure -state normal
            $dbf.library.pb configure -state normal

            ##  If "Connect Mode" is on, go get the active library and populate the Dashboard

            if { $xAIF::Settings(connectMode) } {
                ##  Invoke Expedition on the design so the Cell Editor can be started
                ##  Catch any exceptions raised by opening the database
                set errorCode [catch { MGC::OpenLibraryManager } errorMessage]
                if {$errorCode != 0} {
                    GUI::Transcript -severity error -msg "Unable to connect to Library Manager, is Library Manager running?"
                    GUI::StatusBar::UpdateStatus -busy off
                } else {
                    set GUI::Dashboard::LibraryPath  [$xAIF::Settings(libLib) FullName]
                }
            }

            set xAIF::Settings(targetPath) GUI::Dashboard::LibraryPath
            GUI::Transcript -severity note -msg "Central Library Mode enabled."
            GUI::StatusBar::UpdateStatus -busy off
        }

        ##
        ##  GUI::Menus::DesignMode
        ##
        proc DesignMode {} {
            $GUI::widgets(setupmenu) entryconfigure  3 -state normal
            $GUI::widgets(setupmenu) entryconfigure 4 -state disabled
            #$GUI::widgets(setupmenu) entryconfigure 7 -state normal

            ##  Enable the Design pulldown menu
            $GUI::widgets(designmenu) entryconfigure 0 -state normal
            $GUI::widgets(designmenu) entryconfigure 1 -state normal
            $GUI::widgets(designmenu) entryconfigure 2 -state normal
            $GUI::widgets(designmenu) entryconfigure 3 -state normal
            $GUI::widgets(designmenu) entryconfigure 5 -state normal

            ##  Disable the GUI based on mode
            set dbf $GUI::widgets(dashboard).frame
            $dbf.design.e configure -state normal
            $dbf.design.b configure -state normal
            $dbf.library.le configure -state disabled
            $dbf.library.lb configure -state disabled
            $dbf.library.ce configure -state disabled
            $dbf.library.cb configure -state disabled
            $dbf.library.pe configure -state disabled
            $dbf.library.pb configure -state disabled

            ##  If "Connect Mode" is on, go get the active design and populate the Dashboard

            if { $xAIF::Settings(connectMode) } {
                ##  Invoke Expedition on the design so the Cell Editor can be started
                ##  Catch any exceptions raised by opening the database
                set errorCode [catch { MGC::OpenExpedition } errorMessage]
                if {$errorCode != 0} {
                    GUI::Transcript -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                    GUI::Transcript -severity error -msg "Unable to connect to Xpedition, is Xpedition running?"
                    GUI::StatusBar::UpdateStatus -busy off
                } else {
                    set GUI::Dashboard::FullDesignPath  [$xAIF::Settings(pcbDoc) FullName]
                }
            }

            set xAIF::Settings(targetPath) GUI::Dashboard::FullDesignPath
            GUI::Transcript -severity note -msg "Design Mode enabled."
            GUI::StatusBar::UpdateStatus -busy off
        }

        ##
        ##  GUI::Menus::BondWireEditMode
        ##
        proc BondWireEditMode {} {
            $GUI::widgets(setupmenu) entryconfigure  3 -state normal
            $GUI::widgets(setupmenu) entryconfigure 4 -state disabled
            $GUI::widgets(setupmenu) entryconfigure 7 -state normal
            #set xAIF::Settings(targetPath) $xAIF::Settings(Nothing)
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
        variable CellPartition "xAIF-Work"
        variable PartPartition "xAIF-Work"
        variable ConnectMode on
        variable Visibility on
        variable CellGeneration
        variable CellSuffix none
        variable BGAGeneration "std"
        variable DefaultCellHeight "50"
        variable WBParameters
        variable WBDRCProperty
        variable WBRule

        array set CellGeneration {
            MirrorNone on
            MirrorX off
            MirrorY off
            MirrorXY off
        }

        ##
        ##  GUI::Dashboard::SelectAIFFile
        ##
        proc SelectAIFFile { { f "" } } {
            if { [string equal $f ""] } {
                set GUI::Dashboard::AIFFile [tk_getOpenFile -filetypes {{AIF .aif} {Txt .txt} {All *}}]
            } else {
                set GUI::Dashboard::AIFFile $f
            }

            if { [string equal $GUI::Dashboard::AIFFile ""] } {
                GUI::Transcript -severity error -msg "No AIF File selected."
            } else {
                GUI::File::OpenAIF $GUI::Dashboard::AIFFile
            }
        }

        ##
        ##  GUI::Dashboard::SelectCentralLibrary
        ##
        proc SelectCentralLibrary { { f "" } } {
puts "GUI::Dashboard::SelectCentralLibrary"
            set db $GUI::widgets(dashboard)

            if { [string equal $f ""] } {
                set GUI::Dashboard::LibraryPath [tk_getOpenFile -filetypes {{LMC .lmc} { LLM .llm}}]
            } else {
                set GUI::Dashboard::LibraryPath $f
            }

            ##  Valid LMC selected?  If so, enable the buttons and load the partitions
            if { [expr { $GUI::Dashboard::LibraryPath ne "" }] } {
                $db.frame.library.cb configure -state normal
                $db.frame.library.pb configure -state normal

                ##  Open the LMC and get the partition names
                MGC::SetupLMC $GUI::Dashboard::LibraryPath
            }
        }

        ##
        ##  GUI::Dashboard::SelectCellPartition
        ##
        proc SelectCellPartition {} {
            set GUI::Dashboard::CellPartition \
                [AIFForms::ListBox::SelectOneFromList "Select Target Cell Partition" $xAIF::Settings(cellEdtrPrtnNames)]

            if { [string equal $GUI::Dashboard::CellPartition ""] } {
                GUI::Transcript -severity error -msg "No Cell Partition selected."
            } else {
                set GUI::Dashboard::CellPartition [lindex $GUI::Dashboard::CellPartition 1]
            }
        }

        ##
        ##  GUI::Dashboard::SelectPartPartition
        ##
        proc SelectPartPartition {} {
            set GUI::Dashboard::PartPartition \
                [AIFForms::ListBox::SelectOneFromList "Select Target Part Partition" $xAIF::Settings(partEdtrPrtnNames)]

            if { [string equal $GUI::Dashboard::PartPartition ""] } {
                GUI::Transcript -severity error -msg "No Part Partition selected."
            } else {
                set GUI::Dashboard::PartPartition [lindex $GUI::Dashboard::PartPartition 1]
            }
        }

        ##
        ##  GUI::Dashboard::SetApplicationVisibility
        ##
        proc SetApplicationVisibility {} {
            set xAIF::Settings(appVisible) [expr [string is true $GUI::Dashboard::Visibility] ? on : off]
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
            set slf $GUI::widgets(statuslight)
            if { [string is true $V(-busy)] } {
                $slf configure -background red
                $GUI::widgets(progressbar) start
            } else {
                $slf configure -background green
                $GUI::widgets(progressbar) stop
            } 

            if { $GUI::Dashboard::Mode == $xAIF::Settings(designMode) } {
                set $xAIF::Settings(targetPath) $GUI::Dashboard::FullDesignPath
            } else {
                set $xAIF::Settings(targetPath) $GUI::Dashboard::LibraryPath
            }
            set $xAIF::Settings(targetPath)
            update idletasks
        }
    }

    ##
    ##  Define the GUI::Dashboard namespace and procedure supporting operations
    ##
    namespace eval View {
        variable zoomArea

        #--------------------------------------------------------
        #
        #  GUI::View::ZoomMark
        #
        #  Mark the first (x,y) coordinate for zooming.
        #
        #--------------------------------------------------------
        proc ZoomMark {c x y} {
            variable zoomArea
            set zoomArea(x0) [$c canvasx $x]
            set zoomArea(y0) [$c canvasy $y]
            $c create rectangle $x $y $x $y -outline white -tag zoomArea
            #puts "zoomMark:  $x $y"
        }

        #--------------------------------------------------------
        #
        #  zoomStroke
        #
        #  Zoom in to the area selected by itemMark and
        #  itemStroke.
        #
        #--------------------------------------------------------
        proc ZoomStroke {c x y} {
            variable zoomArea
            set zoomArea(x1) [$c canvasx $x]
            set zoomArea(y1) [$c canvasy $y]
            $c coords zoomArea $zoomArea(x0) $zoomArea(y0) $zoomArea(x1) $zoomArea(y1)
            #puts "zoomStroke:  $x $y"
        }

        #--------------------------------------------------------
        #
        #  zoomArea
        #
        #  Zoom in to the area selected by itemMark and
        #  itemStroke.
        #
        #--------------------------------------------------------
        proc ZoomArea {c x y} {
            variable zoomArea

            #--------------------------------------------------------
            #  Get the final coordinates.
            #  Remove area selection rectangle
            #--------------------------------------------------------
            set zoomArea(x1) [$c canvasx $x]
            set zoomArea(y1) [$c canvasy $y]
            $c delete zoomArea

            #--------------------------------------------------------
            #  Check for zero-size area
            #--------------------------------------------------------
            if {($zoomArea(x0)==$zoomArea(x1)) || ($zoomArea(y0)==$zoomArea(y1))} {
                return
            }

            #--------------------------------------------------------
            #  Determine size and center of selected area
            #--------------------------------------------------------
            set areaxlength [expr {abs($zoomArea(x1)-$zoomArea(x0))}]
            set areaylength [expr {abs($zoomArea(y1)-$zoomArea(y0))}]
            set xcenter [expr {($zoomArea(x0)+$zoomArea(x1))/2.0}]
            set ycenter [expr {($zoomArea(y0)+$zoomArea(y1))/2.0}]

            #--------------------------------------------------------
            #  Determine size of current window view
            #  Note that canvas scaling always changes the coordinates
            #  into pixel coordinates, so the size of the current
            #  viewport is always the canvas size in pixels.
            #  Since the canvas may have been resized, ask the
            #  window manager for the canvas dimensions.
            #--------------------------------------------------------
            set winxlength [winfo width $c]
            set winylength [winfo height $c]

            #--------------------------------------------------------
            #  Calculate scale factors, and choose smaller
            #--------------------------------------------------------
            set xscale [expr {$winxlength/$areaxlength}]
            set yscale [expr {$winylength/$areaylength}]
            if { $xscale > $yscale } {
                set factor $yscale
            } else {
                set factor $xscale
            }

            #--------------------------------------------------------
            #  Perform zoom operation
            #--------------------------------------------------------
            GUI::View::Zoom $c $factor $xcenter $ycenter $winxlength $winylength
            #puts "zoomArea:  $x $y"
        }


        #--------------------------------------------------------
        #
        #  GUI::View::Zoom
        #
        #  Zoom the canvas view, based on scale factor 
        #  and centerpoint and size of new viewport.  
        #  If the center point is not provided, zoom 
        #  in/out on the current window center point.
        #
        #  This procedure uses the canvas scale function to
        #  change coordinates of all objects in the canvas.
        #
        #--------------------------------------------------------
        proc Zoom { canvas factor \
                {xcenter ""} {ycenter ""} \
                {winxlength ""} {winylength ""} } {

            #  Do nothing if the canvas is empty
            if { [string equal "" [$canvas bbox all]] } { return }

            #--------------------------------------------------------
            #  If (xcenter,ycenter) were not supplied,
            #  get the canvas coordinates of the center
            #  of the current view.  Note that canvas
            #  size may have changed, so ask the window 
            #  manager for its size
            #--------------------------------------------------------
            set winxlength [winfo width $canvas]; # Always calculate [ljl]
            set winylength [winfo height $canvas]
            if { [string equal $xcenter ""] } {
                set xcenter [$canvas canvasx [expr {$winxlength/2.0}]]
                set ycenter [$canvas canvasy [expr {$winylength/2.0}]]
            }

            #--------------------------------------------------------
            #  Scale all objects in the canvas
            #  Adjust our viewport center point
            #--------------------------------------------------------
            $canvas scale all 0 0 $factor $factor
            set xcenter [expr {$xcenter * $factor}]
            set ycenter [expr {$ycenter * $factor}]

            #--------------------------------------------------------
            #  Get the size of all the items on the canvas.
            #
            #  This is *really easy* using 
            #      $canvas bbox all
            #  but it is also wrong.  Non-scalable canvas
            #  items like text and windows now have a different
            #  relative size when compared to all the lines and
            #  rectangles that were uniformly scaled with the 
            #  [$canvas scale] command.  
            #
            #  It would be better to tag all scalable items,
            #  and make a single call to [bbox].
            #  Instead, we iterate through all canvas items and
            #  their coordinates to compute our own bbox.
            #--------------------------------------------------------
            set x0 1.0e30; set x1 -1.0e30 ;
            set y0 1.0e30; set y1 -1.0e30 ;
            foreach item [$canvas find all] {
                switch -exact [$canvas type $item] {
                    "arc" -
                    "line" -
                    "oval" -
                    "polygon" -
                    "rectangle" {
                        set coords [$canvas coords $item]
                        foreach {x y} $coords {
                            if { $x < $x0 } {set x0 $x}
                            if { $x > $x1 } {set x1 $x}
                            if { $y < $y0 } {set y0 $y}
                            if { $y > $y0 } {set y1 $y}
                        }
                    }
                }
            }

            #--------------------------------------------------------
            #  Now figure the size of the bounding box
            #--------------------------------------------------------
            set xlength [expr {$x1-$x0}]
            set ylength [expr {$y1-$y0}]

            #--------------------------------------------------------
            #  But ... if we set the scrollregion and xview/yview 
            #  based on only the scalable items, then it is not 
            #  possible to zoom in on one of the non-scalable items
            #  that is outside of the boundary of the scalable items.
            #
            #  So expand the [bbox] of scaled items until it is
            #  larger than [bbox all], but do so uniformly.
            #--------------------------------------------------------
            foreach {ax0 ay0 ax1 ay1} [$canvas bbox all] {break}

            while { ($ax0<$x0) || ($ay0<$y0) || ($ax1>$x1) || ($ay1>$y1) } {
                # triple the scalable area size
                set x0 [expr {$x0-$xlength}]
                set x1 [expr {$x1+$xlength}]
                set y0 [expr {$y0-$ylength}]
                set y1 [expr {$y1+$ylength}]
                set xlength [expr {$xlength*3.0}]
                set ylength [expr {$ylength*3.0}]
            }

            #--------------------------------------------------------
            #  Now that we've finally got a region defined with
            #  the proper aspect ratio (of only the scalable items)
            #  but large enough to include all items, we can compute
            #  the xview/yview fractions and set our new viewport
            #  correctly.
            #--------------------------------------------------------
            set newxleft [expr {($xcenter-$x0-($winxlength/2.0))/$xlength}]
            set newytop  [expr {($ycenter-$y0-($winylength/2.0))/$ylength}]
            $canvas configure -scrollregion [list $x0 $y0 $x1 $y1]
            $canvas xview moveto $newxleft 
            $canvas yview moveto $newytop 

            #--------------------------------------------------------
            #  Change the scroll region one last time, to fit the
            #  items on the canvas.
            #--------------------------------------------------------
            $canvas configure -scrollregion [$canvas bbox all]
        }
    }

    ##
    ##  Define the GUI::File namespace and procedure supporting operations
    ##
    namespace eval File {
        variable SparsePinNames
        variable SparsePinNumbers
        variable SparsePinsFilePath

        ##
        ##  GUI::File::Init
        ##
        proc Init { } {

            ##  Database Details
            array set ::database {
                type ""
                version ""
                units "um"
                mcm "FALSE"
            }

            ##  Die Details
            array set ::die {
                name ""
                refdes "U1"
                width 0
                height 0
                center { 0 0 }
                partition ""
            }

            ##  BGA Details
            array set ::bga {
                name ""
                refdes "A1"
                width 0
                height 0
            }

            ##  Store devices in a Tcl list
            array set ::devices {}

            ##  Store mcm die in a Tcl dictionary
            ###set ::mcmdie [dict create]
            array set ::mcmdie {}

            ##  Store pads in a Tcl dictionary
            ###set ::pads [dict create]
            array set ::pads {}
            ###set ::padtypes [dict create]
            array set ::padtypes {}

            ##  Store net names in a Tcl list
            set ::netnames [list]

            ##  Store netlist in a Tcl list
            set ::netlist [list]
            set ::netlines [list]

            ##  Store bondpad connections in a Tcl list
            set ::bondpads [list]
            set ::bondwires [list]
            array set ::bondpadsubst {}
        }

        #
        #  GUI::File::OpenAIF
        #
        #  Open a AIF file, read the contents into the
        #  Source View and update the appropriate status.
        #
        proc OpenAIF { { f "" } } {
        set zzz 0
            GUI::StatusBar::UpdateStatus -busy on
            InitialState

            ##  Set up the sections so they can be highlighted in the AIF source

            set sections {}
            set sectionRegExp ""
            foreach i [array names xAIF::sections] {
                lappend sections $xAIF::sections($i)
                #puts $xAIF::sections($i)
                set sectionRegExp [format "%s%s%s%s%s%s%s" $sectionRegExp \
                    [expr {$sectionRegExp == "" ? "(" : "|" }] \
                    $xAIF::Settings(BackSlash) $xAIF::Settings(LeftBracket) $xAIF::sections($i) $xAIF::Settings(BackSlash) $xAIF::Settings(RightBracket) ]
            }

            set ignored {}
            set ignoreRegExp ""
            foreach i [array names xAIF::ignored] {
                lappend ignored $xAIF::ignored($i)
                #puts $xAIF::ignored($i)
                set ignoreRegExp [format "%s%s%s%s%s%s%s" $ignoreRegExp \
                    [expr {$ignoreRegExp == "" ? "(" : "|" }] \
                    $xAIF::Settings(BackSlash) $xAIF::Settings(LeftBracket) $xAIF::ignored($i) $xAIF::Settings(BackSlash) $xAIF::Settings(RightBracket) ]
            }

            set ignoreRegExp [format "%s)" $ignoreRegExp]

            ##  Prompt the user for a file if not supplied

            if { $f != $xAIF::Settings(Nothing) } {
                set xAIF::Settings(filename) $f
            } else {
                set xAIF::Settings(filename) [ GUI::Dashboard::SelectAIFFile]
            }

            ##  Process the user supplied file

            if {$xAIF::Settings(filename) != $xAIF::Settings(Nothing) } {
                GUI::Transcript -severity note -msg [format "Loading AIF file \"%s\"." $xAIF::Settings(filename)]
                set txt $GUI::widgets(sourceview)
                $txt configure -state normal
                $txt delete 1.0 end

                set f [open $xAIF::Settings(filename)]
                $txt insert end [read $f]
                GUI::Transcript -severity note -msg [format "Scanning AIF file \"%s\" for sections." $xAIF::Settings(filename)]
                #ctext::addHighlightClass $txt diesections blue $sections
                #ctext::addHighlightClassForRegexp $txt diesections blue $sectionRegExp
                #ctext::addHighlightClassForRegexp $txt ignoredsections red $ignoreRegExp
                $txt highlight 1.0 end
                $txt configure -state disabled
                close $f
                GUI::Transcript -severity note -msg [format "Loaded AIF file \"%s\"." $xAIF::Settings(filename)]

                ##  Parse AIF file

                AIF::Parse $xAIF::Settings(filename)
                GUI::Transcript -severity note -msg [format "Parsed AIF file \"%s\"." $xAIF::Settings(filename)]

                ##  Load the DATABASE section ...

                if { [ AIF::Database::Section ] == -1 } {
                    GUI::StatusBar::UpdateStatus -busy off
                    return -1
                }

                ##  If the file a MCM-AIF file?
                if { $xAIF::Settings(MCMAIF) == 1 } {
                    if { [ AIF::MCMDie::Section ] == -1 } {
                        GUI::StatusBar::UpdateStatus -busy off
                        return -1
                    }
                }

                ##  Load the DIE section ...

                if { [ AIF::Die::Section ] == -1 } {
                    GUI::StatusBar::UpdateStatus -busy off
                    return -1
                }

                ##  Load the optional BGA section ...

                if { $xAIF::Settings(BGA) == 1 } {
                    if { [ AIF::BGA::Section ] == -1 } {
                        GUI::StatusBar::UpdateStatus -busy off
                        return -1
                    }
                }

                ##  Load the PADS section ...

                if { [ AIF::Pads::Section ] == -1 } {
                    GUI::StatusBar::UpdateStatus -busy off
                    return -1
                }

                ##  Load the NETLIST section ...

                if { [ AIF::Netlist::Section ] == -1 } {
                    GUI::StatusBar::UpdateStatus -busy off
                    return -1
                }

                ##  Draw the Graphic View

                GUI::Draw::BuildDesign
            } else {
                GUI::Transcript -severity warning -msg "No AIF file selected."
            }

            GUI::StatusBar::UpdateStatus -busy off
        }

        #
        #  GUI::File::CloseAIF
        #
        #  Close the AIF file and flush anything stored in
        #  xAIF memory.  Clear the text widget for the source
        #  view and the canvas widget for the graphic view.
        #
        proc CloseAIF {} {
            GUI::StatusBar::UpdateStatus -busy on
            GUI::Transcript -severity note -msg [format "AIF file \"%s\" closed." $xAIF::Settings(filename)]
            InitialState
            GUI::StatusBar::UpdateStatus -busy off
        }

        #
        #  GUI::File::InitialState
        #
        proc InitialState {} {

            ##  Put everything back into an initial state
            GUI::File::Init
            set xAIF::Settings(filename) $xAIF::Settings(Nothing)

            ##  Remove all content from the AIF source view
            set txt $GUI::widgets(sourceview)
            $txt configure -state normal
            $txt delete 1.0 end
            $txt configure -state disabled

            ##  Remove all content from the (hidden) netlist text view
            set txt $GUI::widgets(netlistview)
            $txt configure -state normal
            $txt delete 1.0 end
            $txt configure -state disabled

            ##  Remove all content from the keyin netlist text view
            set txt $GUI::widgets(kynnetlistview)
            $txt configure -state normal
            $txt delete 1.0 end
            $txt configure -state disabled

            ##  Remove all content from the source graphic view
            set cnvs $GUI::widgets(layoutview)
            $cnvs delete all

            ##  Remove all content from the AIF Netlist table
            set nlt $GUI::widgets(netlisttable)
            $nlt delete 0 end

            ##  Clean up menus, remove dynamic content
            set vm $GUI::widgets(viewmenu)
            $vm.devices delete 3 end
            $vm.pads delete 3 end
        }


        #
        #  GUI::File::OpenSparsePins
        #
        #  Open a Text file, read the contents into the
        #  Source View and update the appropriate status.
        #
        proc OpenSparsePins {} {
            variable SparsePinNames
            variable SparsePinNumbers
            variable SparsePinsFilePath
            GUI::StatusBar::UpdateStatus -busy on

            ##  Prompt the user for a file
            ##set xAIF::Settings(sparsepinsfile) [tk_getOpenFile -filetypes {{TXT .txt} {CSV .csv} {All *}}]
            set SparsePinsFilePath [tk_getOpenFile -filetypes {{TXT .txt} {All *}}]

            ##  Process the user supplied file
            if {[string equal "" SparsePinsFilePath]} {
                GUI::Transcript -severity warning -msg "No Sparse Pins file selected."
            } else {
                GUI::Transcript -severity note -msg [format "Loading Sparse Pins file \"%s\"." $xAIF::Settings(sparsepinsfile)]
                set txt $GUI::widgets(sparsepinsview)
                $txt configure -state normal
                $txt delete 1.0 end

                set f [open $xAIF::Settings(sparsepinsfile)]
                $txt insert end [read $f]
                GUI::Transcript -severity note -msg [format "Scanning Sparse List \"%s\" for pin numbers." $xAIF::Settings(sparsepinsfile)]
                ctext::addHighlightClassForRegexp $txt sparsepinlist blue {[\t ]*[0-9][0-9]*[\t ]*$}
                $txt highlight 1.0 end
                $txt configure -state disabled
                close $f
                GUI::Transcript -severity note -msg [format "Loaded Sparse Pins file \"%s\"." $xAIF::Settings(sparsepinsfile)]
                GUI::Transcript -severity note -msg [format "Extracting Pin Numbers from Sparse Pins file \"%s\"." $xAIF::Settings(sparsepinsfile)]

                set pins [split $GUI::widgets(sparsepinsview) \n]
                set txt $GUI::widgets(sparsepinsview)
                set pins [split [$txt get 1.0 end] \n]

                set lc 1
                set SparsePinNames {}
                set SparsePinNumbers {}

                ##  Loop through the pin data and extract the pin names and numbers

                foreach i $pins {
                    set pindata [regexp -inline -all -- {\S+} $i]
                    if { [llength $pindata] == 0 } {
                        continue
                    } elseif { [llength $pindata] != 2 } {
                        GUI::Transcript -severity warning -msg [format "Skipping line %s, incorrect number of fields." $lc]
                    } else {
                        GUI::Transcript -severity note -msg [format "Found Sparse Pin Number:  \"%s\" on line %s" [lindex $pindata 1] $lc]
                        lappend xAIF::Settings(sparsepinnames) [lindex $pindata 1]
                        lappend xAIF::Settings(sparsepinnumbers) [lindex $pindata 1]
                        ##if { [incr lc] > 100 } { break }
                    }

                    incr lc
                }
            }

            # Force the scroll to the top of the sparse pins view
            $txt yview moveto 0
            $txt xview moveto 0

            GUI::StatusBar::UpdateStatus -busy off
        }

        #
        #  GUI::File::CloseSparsePins
        #
        #  Close the sparse rules file and flush anything stored
        #  in xAIF memory.  Clear the text widget for the sparse
        #  rules.
        #
        proc CloseSparsePins {} {
            variable SparsePinsFilePath
            GUI::StatusBar::UpdateStatus -busy on
            GUI::Transcript -severity note -msg [format "Sparse Pins file \"%s\" closed." $xAIF::Settings(sparsepinsfile)]
            set SparsePinsFilePath $xAIF::Settings(Nothing)
            set txt $GUI::widgets(sparsepinsview)
            $txt configure -state normal
            $txt delete 1.0 end
            $txt configure -state disabled
            GUI::StatusBar::UpdateStatus -busy off
        }
    }

    ##
    ##  Define the GUI::Draw namespace and procedure supporting operations
    ##
    namespace eval Draw {
        #
        #  GUI::Draw::BuildDesign
        #
        proc BuildDesign {} {
            set rv 0
            set line_no 0
            set vm $GUI::widgets(viewmenu)
            $vm.devices add separator
    
            set cnvs $GUI::widgets(layoutview)
            set txt $GUI::widgets(netlistview)
            set nlt $GUI::widgets(netlisttable)
            set kyn $GUI::widgets(kynnetlistview)
    
            $cnvs delete all
    
            ##  Add the outline
    
            ##  Draw the BGA outline (if it exists)
            if { $xAIF::Settings(BGA) == 1 } {
                GUI::Draw::BGAOutline
                set ::devices($::bga(name)) [list]
    
                #  Add BGA to the View Devices menu and make it visible
                set GUI::devices($::bga(name)) on
                $vm.devices add checkbutton -label "$::bga(name)" -underline 0 \
                    -variable GUI::devices($::bga(name)) -onvalue on -offvalue off \
                    -command  "GUI::Visibility $::bga(name) -mode toggle"
    
                $vm.devices add separator
            }
    
            ##  Is this an MCM-AIF?
    
            if { $xAIF::Settings(MCMAIF) == 1 } {
                foreach i [AIF::MCMDie::GetAllDie] {
                    #set section [format "MCM_%s_%s" [string toupper $i] [dict get $::mcmdie $i]]
                    ###set section [format "MCM_%s_%s" [dict get $::mcmdie $i] $i]
                    set section [format "MCM_%s_%s" $::mcmdie($i) $i]
                    if { [lsearch -exact [::AIF::Sections] $section] != -1 } {
                        array set part {
                            REF ""
                            NAME ""
                            WIDTH 0.0
                            HEIGHT 0.0
                            CENTER [list 0.0 0.0]
                            X 0.0
                            Y 0.0
                        }
    
                        #  Extract each of the expected keywords from the section
                        foreach key [array names part] {
                            if { [lsearch -exact [AIF::Variables $section] $key] != -1 } {
                                set part($key) [AIF::GetVar $key $section]
                            }
                        }
    
                        #  Need the REF designator for later
    
                        set part(REF) $i
                        set ::devices($part(NAME)) [list]
    
                        #  Split the CENTER keyword into X and Y components
                        #
                        #  The AIF specification and sample file have the X and Y separated by
                        #  both a space and comma character so we'll plan to handle either situation.
                        if { [llength [split $part(CENTER) ,]] == 2 } {
                            set part(X) [lindex [split $part(CENTER) ,] 0]
                            set part(Y) [lindex [split $part(CENTER) ,] 1]
                        } else {
                            set part(X) [lindex [split $part(CENTER)] 0]
                            set part(Y) [lindex [split $part(CENTER)] 1]
                        }
    
                        #  Draw the Part Outline
                        PartOutline $part(REF) $part(HEIGHT) $part(WIDTH) $part(X) $part(Y)
    
                        #  Add part to the View Devices menu and make it visible
                        set GUI::devices($part(REF)) on
                        $vm.devices add checkbutton -label "$part(REF)" -underline 0 \
                            -variable GUI::devices($part(REF)) -onvalue on -offvalue off \
                            -command  "GUI::Visibility device-$part(REF) -mode toggle"
                    }
                }
            } else {
                if { [lsearch -exact [AIF::Sections] DIE] != -1 } {
                    array set part {
                        REF ""
                        NAME ""
                        WIDTH 0.0
                        HEIGHT 0.0
                        CENTER { 0.0 0.0 }
                        X 0.0
                        Y 0.0
                    }
    
                    #  Extract each of the expected keywords from the section
                    foreach key [array names part] {
                        if { [lsearch -exact [AIF::Variables DIE] $key] != -1 } {
                            set part($key) [AIF::GetVar $key DIE]
                        }
                    }
    
                    #  Need the REF designator for later
    
                    set part(REF) $xAIF::Settings(DIEREF)
                    set ::devices($part(NAME)) [list]
    
                    #  Split the CENTER keyword into X and Y components
                    #
                    #  The AIF specification and sample file have the X and Y separated by
                    #  both a space and comma character so we'll plan to handle either situation.
                    if { [llength [split $part(CENTER) ,]] == 2 } {
                        set part(X) [lindex [split $part(CENTER) ,] 0]
                        set part(Y) [lindex [split $part(CENTER) ,] 1]
                    } else {
                        set part(X) [lindex [split $part(CENTER)] 0]
                        set part(Y) [lindex [split $part(CENTER)] 1]
                    }
    
                    #  Draw the Part Outline
                    PartOutline $part(REF) $part(HEIGHT) $part(WIDTH) $part(X) $part(Y)
    
                    #  Add part to the View Devices menu and make it visible
                    set GUI::devices($part(REF)) on
                    $vm.devices add checkbutton -label "$part(REF)" -underline 0 \
                        -variable GUI::devices($part(REF)) -onvalue on -offvalue off \
                        -command  "GUI::Visibility device-$part(REF) -mode toggle"
                }
            }
    
            ##  Load the NETLIST section
    
            set nl [$txt get 1.0 end]
    
            ##  Clean up netlist table
            #$nlt configure -state normal
            $nlt delete 0 end
    
            ##  Process the netlist looking for the pads
    
            foreach n [split $nl '\n'] {
                #puts "==>  $n"
                incr line_no
                ##  Skip blank or empty lines
                if { [string length $n] == 0 } { continue }
    
                set net [regexp -inline -all -- {\S+} $n]
                set netname [lindex [regexp -inline -all -- {\S+} $n] 0]
    
                ##  Put netlist into table for easy review
    
                $nlt insert end $net
    
                ##  Initialize array to store netlist fields
    
                array set nlr {
                    NETNAME "-"
                    PADNUM "-"
                    PADNAME "-"
                    PAD_X "-"
                    PAD_Y "-"
                    BALLNUM "-"
                    BALLNAME "-"
                    BALL_X "-"
                    BALL_Y "-"
                    FINNUM "-"
                    FINNAME "-"
                    FIN_X "-"
                    FIN_Y "-"
                    ANGLE "-"
                }
    
                #  A simple netlist has 5 fields
    
                set nlr(NETNAME) [lindex $net 0]
                set nlr(PADNUM) [lindex $net 1]
                set nlr(PADNAME) [lindex $net 2]
                set nlr(PAD_X) [lindex $net 3]
                set nlr(PAD_Y) [lindex $net 4]
    
                #  A simple netlist with ball assignment has 6 fields
                if { [llength [split $net]] > 5 } {
                    set nlr(BALLNUM) [lindex $net 5]
                }
    
                #  A netlist with ball assignments  and locations has 9 fields
                if { [llength [split $net]] > 6 } {
                    set nlr(BALLNAME) [lindex $net 6]
                    set nlr(BALL_X) [lindex $net 7]
                    set nlr(BALL_Y) [lindex $net 8]
                }
    
                #  A complex netlist with ball and rings assignments has 14 fields
                if { [llength [split $net]] > 9 } {
                    set nlr(FINNUM) [lindex $net 9]
                    set nlr(FINNAME) [lindex $net 10]
                    set nlr(FIN_X) [lindex $net 11]
                    set nlr(FIN_Y) [lindex $net 12]
                    set nlr(ANGLE) [lindex $net 13]
                }
    
                #printArray nlr
    
                #  Check the netname and store it for later use
                if { [ regexp {^[[:alpha:][:alnum:]_]*\w} $netname ] == 0 } {
                    GUI::Transcript -severity error -msg [format "Net name \"%s\" is not supported AIF syntax." $netname]
                    set rv -1
                } else {
                    if { [lsearch -exact $::netlist $netname ] == -1 } {
                        #lappend ::netlist $netname
                        GUI::Transcript -severity note -msg [format "Found net name \"%s\"." $netname]
                    }
                }
    
                ##  Can the die pad be placed?
    
                if { $nlr(PADNAME) != "-" } {
                    set ref [lindex [split $nlr(PADNUM) "."] 0]
                    if { $ref == $nlr(PADNUM) } {
                        set padnum $nlr(PADNUM)
                        set ref $xAIF::Settings(DIEREF)
                    } else {
                        set padnum [lindex [split $nlr(PADNUM) "."] 1]
                    }
    
                    #puts "---------------------> Die Pad:  $ref-$padnum"
    
                    ##  Record the pad and location in the device list
                    if { $xAIF::Settings(MCMAIF) == 1 } {
                        ###set name [dict get $::mcmdie $ref]
                        set name $::mcmdie($ref)
                    } else {
                        set name [AIF::GetVar NAME DIE]
                    }
    
                    lappend ::devices($name) [list $nlr(PADNAME) $padnum $nlr(PAD_X) $nlr(PAD_Y)]
    
                    GUI::Draw::AddPin $nlr(PAD_X) $nlr(PAD_Y) $nlr(PADNUM) $nlr(NETNAME) $nlr(PADNAME) $line_no "diepad pad pad-$nlr(PADNAME) $ref"
                    ###if { ![dict exists $::padtypes $nlr(PADNAME)] } {
                    ###    dict lappend ::padtypes $nlr(PADNAME) "smdpad"
                    ###}
                    if { [lsearch [array names ::padtypes] $nlr(PADNAME)] == -1 } {
                        set ::padtypes($nlr(PADNAME)) "smdpad"
                    }
                    set ::padtypes($nlr(PADNAME)) "smdpad"
                } else {
                    GUI::Transcript -severity warning -msg [format "Skipping die pad for net \"%s\" on line %d, no pad assignment." $netname, $line_no]
                }
    
                ##  Can the BALL pad be placed?
    
                if { $nlr(BALLNAME) != "-" } {
                    #puts "---------------------> Ball"
    
                    ##  Record the pad and location in the device list
                    lappend ::devices($::bga(name)) [list $nlr(BALLNAME) $nlr(BALLNUM) $nlr(BALL_X) $nlr(BALL_Y)]
                    #puts "---------------------> Ball Middle"
    
                    GUI::Draw::AddPin $nlr(BALL_X) $nlr(BALL_Y) $nlr(BALLNUM) $nlr(NETNAME) $nlr(BALLNAME) $line_no "ballpad pad pad-$nlr(BALLNAME)" "white" "red"
                    #puts "---------------------> Ball Middle"
                    ###if { ![dict exists $::padtypes $nlr(BALLNAME)] } {
                    ###    dict lappend ::padtypes $nlr(BALLNAME) "ballpad"
                    ###}
                    if { [lsearch [array names ::padtypes] $nlr(BALLNAME)] == -1 } {
                        set ::padtypes($nlr(BALLNAME)) "ballpad"
                    }
                    set ::padtypes($nlr(BALLNAME)) "ballpad"
                    #puts "---------------------> Ball End"
                } else {
                    GUI::Transcript -severity warning -msg [format "Skipping ball pad for net \"%s\" on line %d, no ball assignment." $netname, $line_no]
                }
    
                ##  Can the Finger pad be placed?
    
                if { $nlr(FINNAME) != "-" } {
                    puts "---------------------> Finger"
                    GUI::Draw::AddPin $nlr(FIN_X) $nlr(FIN_Y) $nlr(FINNUM) $nlr(NETNAME) $nlr(FINNAME) $line_no "bondpad pad pad-$nlr(FINNAME)" "purple" "white" $nlr(ANGLE)
                    lappend ::bondpads [list $nlr(NETNAME) $nlr(FINNAME) $nlr(FIN_X) $nlr(FIN_Y) $nlr(ANGLE)]
                    if { [lsearch [array names ::padtypes] $nlr(FINNAME)] == -1 } {
                        set ::padtypes($nlr(FINNAME)) "bondpad"
                    }
                    set ::padtypes($nlr(FINNAME)) "bondpad"

                    ##  Does this bond pad need a swap to account for bond fingers constructed vertically?
                    if { [lsearch [array names ::bondpadsubst] $nlr(FINNAME)] == -1 } {

                        ##  Extract height and width from the PADS section
                        set w [lindex [AIF::GetVar $nlr(FINNAME) PADS] 1]
                        set h [lindex [AIF::GetVar $nlr(FINNAME) PADS] 2]

                        ##  If height > width a bond pad substitution is required so Xpedition will operate correctly

                        if { $h > $w } {
                            set ::bondpadsubst($nlr(FINNAME)) [format "%s_h" $nlr(FINNAME)]
                        }
                    }
                } else {
                    GUI::Transcript -severity warning -msg [format "Skipping finger for net \"%s\" on line %d, no finger assignment." $netname, $line_no]
                }
    
                ##  Need to detect connections - there are two types:
                ##
                ##  1)  Bond Pad connections
                ##  2)  Any other connection (Die to Die,  Die to BGA, etc.)
                ##
    
                ##  Look for bond wire connections
    
                if { $nlr(PAD_X) != "-"  && $nlr(PAD_Y) != "-"  && $nlr(FINNAME) != "-" && $nlr(FIN_X) != "-"  && $nlr(FIN_Y) != "-" } {
                    lappend ::bondwires [list $nlr(NETNAME) $nlr(PAD_X) $nlr(PAD_Y) $nlr(FIN_X) $nlr(FIN_Y)]
                }
    
                ##  Look for net line connections (which are different than netlist connections)
    
                if { $nlr(PAD_X) != "-"  && $nlr(PAD_Y) != "-"  && $nlr(BALL_X) != "-"  && $nlr(BALL_Y) != "-" } {
                    lappend ::netlines [list $nlr(NETNAME) $nlr(PAD_X) $nlr(PAD_Y) $nlr(BALL_X) $nlr(BALL_Y)]
                }
    
                ##  Add any connections to the netlist
    
                if { $nlr(PADNUM) != "-" && $nlr(PADNAME) != "-" && $nlr(PAD_X) != "-"  && $nlr(PAD_Y) != "-" } {
                    if { 1 } {
                        lappend ::netlist [list $nlr(NETNAME) $nlr(PADNUM)]
                    } else {
                        lappend ::netlist [list $nlr(NETNAME) [format "%s.%s" $xAIF::Settings(DIEREF) $nlr(PADNUM)]]
                    }
                }
    
        if { 1 } {
                if { $nlr(BALLNUM) != "-" && $nlr(BALLNAME) != "-" && $nlr(BALL_X) != "-"  && $nlr(BALL_Y) != "-" } {
                    if { 0 } {
                        lappend ::netlist [list $nlr(NETNAME) [format "%s.%s" $::bga(refdes) $nlr(BALLNUM)]]
                    } else {
                        lappend ::netlist [list $nlr(NETNAME) [format "%s.%s" $::bga(refdes) $nlr(BALLNUM)]]
                    }
                }
        }
            }
    
            ##  Due to the structure of the AIF file, it is possible to have
            ##  replicated pins in our device list.  Need to roll through them
            ##  and make sure all of the stored lists are unique.
    
            foreach d [array names ::devices] {
                set ::devices($d) [lsort -unique $::devices($d)]
            }
    
            ##  Similarly, bond pads can have more than one connection and may
            ##  appear in the AIF file multiple times.  Need to eliminate any
            ##  duplicates prevent placing bond pads multiple times.
    
            puts [format "++++++>  %d" [llength $::bondpads]]
            set ::bondpads [lsort -unique $::bondpads]
            puts [format "++++++>  %d" [llength $::bondpads]]
    
            #  Generate KYN Netlist
            $kyn configure -state normal
    
            ##  Netlist file header 
            $kyn insert end ";; V4.1.0\n"
            $kyn insert end "%net\n"
            $kyn insert end "%Prior=1\n\n"
            $kyn insert end "%page=0\n"
    
            ##  Netlist content
            set p ""
            foreach n $::netlist {
puts $n
                set c ""
                foreach i $n {
                    if { [lsearch $n $i] == 0 } {
                        set c $i
                        if { $c == $p } {
                            $kyn insert end "*  "
                        } else {
                            $kyn insert end "\\$i\\  "
                        }
                    } else {
                        set p [split $i "."]
                        if { [llength $p] > 1 } {
                            $kyn insert end [format " \\%s\\-\\%s\\" [lindex $p 0] [lindex $p 1]]
                        } else {
                            $kyn insert end [format " \\%s\\-\\%s\\" $xAIF::Settings(DIEREF) [lindex $p 0]]
                        }
                    }
                }
    
                set p $c
                $kyn insert end "\n"
                #puts "$n"
            }
    
            ##  Output the part list
            $kyn insert end "\n%Part\n"
            foreach i [AIF::MCMDie::GetAllDie] {
                ###$kyn insert end [format "\\%s\\   \\%s\\\n" [dict get $::mcmdie $i] $i]
                $kyn insert end [format "\\%s\\   \\%s\\\n" $::mcmdie($i) $i]
            }

            ##  If this AIF file does not contain a MCM_DIE section then
            ##  the DIE will not appear in the part list and needs to be
            ##  added separately.

            if { [lsearch -exact $::AIF::sections MCM_DIE] == -1 } {
                $kyn insert end [format "\\%s\\   \\%s\\\n" $::die(name) $::die(refdes)]
            }

    
            ##  If there is a BGA, make sure to put it in the part list
            #if { $xAIF::Settings(BGA) == 1 } {
            #    $kyn insert end [format "\\%s\\   \\%s\\\n" $::bga(name) $::bga(refdes)]
            #}
    
            $kyn configure -state disabled
    
            #  Draw Bond Wires
            foreach bw $::bondwires {
                foreach {net x1 y1 x2 y2} $bw {
                    #puts [format "Wire (%s) -- X1:  %s  Y1:  %s  X2:  %s  Y2:  %s" $net $x1 $y1 $x2 $y2]
                    $cnvs create line $x1 $y1 $x2 $y2 -tags "bondwire bondwire-$net" -fill "orange" -width 1
    
                    #  Add bond wire to the View Bond Wires menu and make it visible
                    #  Because a net can have more than one bond wire, need to ensure
                    #  already hasn't been added or it will result in redundant menus.
    
                    if { [array size GUI::bondwires] == 0 || \
                         [lsearch [array names GUI::bondwires] $net] == -1 } {
                        set GUI::bondwires($net) on
                        $vm.bondwires add checkbutton -label "$net" \
                            -variable GUI::bondwires($net) -onvalue on -offvalue off \
                            -command  "GUI::Visibility bondwire-$net -mode toggle"
                    }
                }
            }
    
            #  Draw Net Lines
            foreach nl $::netlines {
                foreach {net x1 y1 x2 y2} $nl {
                    #puts [format "Net Line (%s) -- X1:  %s  Y1:  %s  X2:  %s  Y2:  %s" $net $x1 $y1 $x2 $y2]
                    $cnvs create line $x1 $y1 $x2 $y2 -tags "netline netline-$net" -fill "cyan" -width 1
    
                    #  Add bond wire to the View Bond Wires menu and make it visible
                    #  Because a net can have more than one bond wire, need to ensure
                    #  already hasn't been added or it will result in redundant menus.
    
                    if { [array size GUI::netlines] == 0 || \
                         [lsearch [array names GUI::netlines] $net] == -1 } {
                        set GUI::netlines($net) on
                        $vm.netlines add checkbutton -label "$net" \
                            -variable GUI::netlines($net) -onvalue on -offvalue off \
                            -command  "GUI::Visibility netline-$net -mode toggle"
                    }
                }
            }
    
            #$nlt configure -state disabled
    
            ##  Set an initial scale so the die is visible
            ##  This is an estimate based on trying a couple of
            ##  die files.
    
            set scaleX [expr ($xAIF::widgets(windowSizeX) / (2*$::die(width)) * $xAIF::Settings(ScaleFactor))]
            #puts [format "A:  %s  B:  %s  C:  %s" $scaleX $xAIF::widgets(windowSizeX) $::die(width)]
            if { $scaleX > 0 } {
                #zoom 1 0 0 
                set extents [$cnvs bbox all]
                #puts $extents
                #$cnvs create rectangle $extents -outline green
                #$cnvs create oval \
                #    [expr [lindex $extents 0]-2] [expr [lindex $extents 1]-2] \
                #    [expr [lindex $extents 0]+2] [expr [lindex $extents 1]+2] \
                #    -fill green
                #$cnvs create oval \
                #    [expr [lindex $extents 2]-2] [expr [lindex $extents 3]-2] \
                #    [expr [lindex $extents 2]+2] [expr [lindex $extents 3]+2] \
                #    -fill green
                #zoomMark $cnvs [lindex $extents 2] [lindex $extents 3]
                #zoomStroke $cnvs [lindex $extents 0] [lindex $extents 1]
                #zoomArea $cnvs [lindex $extents 0] [lindex $extents 1]
    
                #  Set the initial view
                GUI::View::Zoom $cnvs 25
            }
    
            #destroy $pb
    
            return $rv
        }
    
        #
        #  GUI::Draw::GenKYN
        #
        proc GenKYN {} {
            set kyn $GUI::widgets(kynnetlistview)
            #  Generate KYN Netlist
            $kyn configure -state normal
            $kyn delete 1.0 end
    
            ##  Netlist file header 
            $kyn insert end ";; V4.1.0\n"
            $kyn insert end "%net\n"
            $kyn insert end "%Prior=1\n\n"
            $kyn insert end "%page=0\n"
    
            puts $::netlist
            ##  Netlist content
            set p ""
            foreach n $::netlist {
                set c ""
                foreach i $n {
                    if { [lsearch $n $i] == 0 } {
#puts "${i}::${n}"
                        set c $i
                        if { $c == $p } {
                            $kyn insert end "*  "
                        } else {
                            $kyn insert end "\\$i\\  "
                        }
                    } else {
                        set p [split $i "."]
puts "${i}::${n}::${p}"
                        if { [llength $p] > 1 } {
                            $kyn insert end [format " \\%s\\-\\%s\\" [lindex $p 0] [lindex $p 1]]
                        } else {
                            $kyn insert end [format " \\%s\\-\\%s\\" $xAIF::Settings(DIEREF) [lindex $p 0]]
                        }
                    }
                }
    
                set p $c
                $kyn insert end "\n"
                #puts "$n"
            }
    
            ##  Output the part list
            $kyn insert end "\n%Part\n"
            foreach i [AIF::MCMDie::GetAllDie] {
                ###$kyn insert end [format "\\%s\\   \\%s\\\n" [dict get $::mcmdie $i] $i]
                $kyn insert end [format "\\%s\\   \\%s\\\n" $::mcmdie($i) $i]
            }

            ##  If this AIF file does not contain a MCM_DIE section then
            ##  the DIE will not appear in the part list and needs to be
            ##  added separately.

            if { [lsearch -exact $::AIF::sections MCM_DIE] == -1 } {
                $kyn insert end [format "\\%s\\   \\%s\\\n" $::die(name) $::die(refdes)]
            }

    
            ##  If there is a BGA, make sure to put it in the part list
            #if { $xAIF::Settings(BGA) == 1 } {
            #    $kyn insert end [format "\\%s\\   \\%s\\\n" $::bga(name) $::bga(refdes)]
            #}
    
            $kyn configure -state disabled
        }

        #
        #  GUI::Draw::AddPin
        #
        proc AddPin { x y pin net pad line_no { tags "diepad" } { color "yellow" } { outline "red" } { angle 0 } } {
            set cnvs $GUI::widgets(layoutview)
            set padtxt [expr {$pin == "-" ? $pad : $pin}]
            #puts [format "Pad Text:  %s (Pin:  %s  Pad:  %s" $padtxt $pin $pad]
    
            ##  Figure out the pad shape
            set shape [AIF::Pad::GetShape $pad]
    
            switch -regexp -- $shape {
                "SQ" -
                "SQUARE" {
                    set pw [AIF::Pad::GetWidth $pad]
                    $cnvs create rectangle [expr {$x-($pw/2.0)}] [expr {$y-($pw/2.0)}] \
                        [expr {$x + ($pw/2.0)}] [expr {$y + ($pw/2.0)}] -outline $outline \
                        -fill $color -tags "$tags" 
    
                    #  Add text: Use pin number if it was supplied, otherwise pad name
                    $cnvs create text $x $y -text $padtxt -fill $outline \
                        -anchor center -font [list arial] -justify center \
                        -tags "text padnumber padnumber-$pin $tags"
                }
                "CIRCLE" -
                "ROUND" {
                    set pw [AIF::Pad::GetWidth $pad]
                    $cnvs create oval [expr {$x-($pw/2.0)}] [expr {$y-($pw/2.0)}] \
                        [expr {$x + ($pw/2.0)}] [expr {$y + ($pw/2.0)}] -outline $outline \
                        -fill $color -tags "$tags" 
    
                    #  Add text: Use pin number if it was supplied, otherwise pad name
                    $cnvs create text $x $y -text $padtxt -fill $outline \
                        -anchor center -font [list arial] -justify center \
                        -tags "text padnumber padnumber-$pin $tags"
                }
                "OBLONG" -
                "OBROUND" {
                    set pw [AIF::Pad::GetWidth $pad]
                    set ph [AIF::Pad::GetHeight $pad]
    
                    set x1 [expr $x-($pw/2.0)]
                    set y1 [expr $y-($ph/2.0)]
                    set x2 [expr $x+($pw/2.0)]
                    set y2 [expr $y+($ph/2.0)]
    
                    ##  An "oblong" pad is a rectangular pad with rounded ends.  The rounded
                    ##  end is circular based on the width of the pad.  Ideally we'd draw this
                    ##  as a single polygon but for now the pad is drawn with two round pads
                    ##  connected by a rectangular pad.
    
                    #  Compose the pad - it is four pieces:  Arc, Segment, Arc, Segment
    
                    set padxy {}
    
                    #  Top arc
                    set arc [GUI::ArcPath [expr {$x-($pw/2.0)}] $y1 \
                        [expr {$x + ($pw/2.0)}] [expr {$y1+$pw}] -start 180 -extent 180 -sides 20]
                    foreach e $arc { lappend padxy $e }
    
                    #  Bottom Arc
                    set arc [GUI::ArcPath [expr {$x-($pw/2.0)}] \
                        [expr {$y2-$pw}] [expr {$x + ($pw/2.0)}] $y2 -start 0 -extent 180 -sides 20]
    
                    foreach e $arc { lappend padxy $e }
    
                    set id [$cnvs create poly $padxy -outline $outline -fill $color -tags "$tags"]
    
                    #  Add text: Use pin number if it was supplied, otherwise pad name
                    $cnvs create text $x $y -text $padtxt -fill $outline \
                        -anchor center -font [list arial] -justify center \
                        -tags "text padnumber padnumber-$pin $tags"
    
                    #  Handle any angle ajustment
    
                    if { $angle != 0 } {
                        set Ox $x
                        set Oy $y
    
                        set radians [expr {$angle * atan(1) * 4 / 180.0}] ;# Radians
                        set xy {}
                        foreach {x y} [$cnvs coords $id] {
                            # rotates vector (Ox,Oy)->(x,y) by angle clockwise
    
                            # Shift the object to the origin
                            set x [expr {$x - $Ox}]
                            set y [expr {$y - $Oy}]
    
                            #  Rotate the object
                            set xx [expr {$x * cos($radians) - $y * sin($radians)}]
                            set yy [expr {$x * sin($radians) + $y * cos($radians)}]
    
                            # Shift the object back to the original XY location
                            set xx [expr {$xx + $Ox}]
                            set yy [expr {$yy + $Oy}]
    
                            lappend xy $xx $yy
                        }
                        $cnvs coords $id $xy
                    }
    
                }
                "RECT" -
                "RECTANGLE" {
                    set pw [AIF::Pad::GetWidth $pad]
                    set ph [AIF::Pad::GetHeight $pad]
    
                    set x1 [expr $x-($pw/2.0)]
                    set y1 [expr $y-($ph/2.0)]
                    set x2 [expr $x+($pw/2.0)]
                    set y2 [expr $y+($ph/2.0)]
    
                    #puts [format "Pad extents:  X1:  %s  Y1:  %s  X2:  %s  Y2:  %s" $x1 $y1 $x2 $y2]
    
                    $cnvs create rectangle $x1 $y1 $x2 $y2 -outline $outline -fill $color -tags "$tags $pad"
    
                    #  Add text: Use pin number if it was supplied, otherwise pad name
                    $cnvs create text $x $y -text $padtxt -fill $outline \
                        -anchor center -font [list arial] -justify center \
                        -tags "text padnumber padnumber-$pin $tags"
                }
                "POLY" {
                    set polypts {}
                    set padxy [AIF::Pad::GetPoints $pad]
                    puts $padxy
                    foreach {px py} $padxy {
                        #puts $px
                        #puts $py
                        lappend polypts [expr $px + $x]
                        lappend polypts [expr $py + $y]
                    }
    
                    #set id [$cnvs create poly $padxy -outline $outline -fill $color -tags "$tags"]
                    set id [$cnvs create poly $polypts -outline $outline -fill $color -tags "$tags"]
    
                    #  Add text: Use pin number if it was supplied, otherwise pad name
                    $cnvs create text $x $y -text $padtxt -fill $outline \
                        -anchor center -font [list arial] -justify center \
                        -tags "text padnumber padnumber-$pin $tags"
    
                    #  Handle any angle ajustment
    
                    if { $angle != 0 } {
                        set Ox $x
                        set Oy $y
    
                        set radians [expr {$angle * atan(1) * 4 / 180.0}] ;# Radians
                        set xy {}
                        foreach {x y} [$cnvs coords $id] {
                            # rotates vector (Ox,Oy)->(x,y) by angle clockwise
    
                            # Shift the object to the origin
                            set x [expr {$x - $Ox}]
                            set y [expr {$y - $Oy}]
    
                            #  Rotate the object
                            set xx [expr {$x * cos($radians) - $y * sin($radians)}]
                            set yy [expr {$x * sin($radians) + $y * cos($radians)}]
    
                            # Shift the object back to the original XY location
                            set xx [expr {$xx + $Ox}]
                            set yy [expr {$yy + $Oy}]
    
                            lappend xy $xx $yy
                        }
                        $cnvs coords $id $xy
                    }
    
                }
                default {
                    #error "Error parsing $filename (line: $line_no): $line"
                    GUI::Transcript -severity warning -msg [format "Skipping line %d in AIF file \"%s\"." $line_no $xAIF::Settings(filename)]
                    #puts $line
                }
            }
    
            #$cnvs scale "pads" 0 0 100 100
    
            $cnvs configure -scrollregion [$cnvs bbox all]
        }
    
        #
        #  GUI::Draw::AddOutline
        #
        proc AddOutline {} {
            set x2 [expr ($::die(width) / 2) * $xAIF::Settings(ScaleFactor)]
            set x1 [expr (-1 * $x2) * $xAIF::Settings(ScaleFactor)]
            set y2 [expr ($::die(height) / 2) * $xAIF::Settings(ScaleFactor)]
            set y1 [expr (-1 * $y2) * $xAIF::Settings(ScaleFactor)]
    
            set cnvs $GUI::widgets(layoutcview)
            $cnvs create rectangle $x1 $y1 $x2 $y2 -outline blue -tags "outline"
    
            #puts [format "Outline extents:  X1:  %s  Y1:  %s  X2:  %s  Y2:  %s" $x1 $y1 $x2 $y2]:w
    
            $cnvs configure -scrollregion [$cnvs bbox all]
        }
    
        #
        #  GUI::Draw::PartOutline
        #
        proc PartOutline { name height width x y { color "green" } { tags "partoutline" } } {
            #puts [format "Part Outline input:  Name:  %s H:  %s  W:  %s  X:  %s  Y:  %s  C:  %s" $name $height $width $x $y $color]
    
            set x1 [expr $x-($width/2.0)]
            set x2 [expr $x+($width/2.0)]
            set y1 [expr $y-($height/2.0)]
            set y2 [expr $y+($height/2.0)]
    
            set cnvs $GUI::widgets(layoutview)
            $cnvs create rectangle $x1 $y1 $x2 $y2 -outline $color -tags "device device-$name $tags"
            $cnvs create text $x2 $y2 -text $name -fill $color \
                -anchor sw -font [list arial] -justify right -tags "text device device-$name refdes refdes-$name"
    
            #puts [format "Part Outline extents:  X1:  %s  Y1:  %s  X2:  %s  Y2:  %s" $x1 $y1 $x2 $y2]
    
            $cnvs configure -scrollregion [$cnvs bbox all]
        }
    
        #
        #  GUI::Draw::BGAOutline
        #
        proc BGAOutline { { color "white" } } {
            set cnvs $GUI::widgets(layoutview)
    
            set x1 [expr -($::bga(width) / 2)]
            set x2 [expr +($::bga(width) / 2)]
            set y1 [expr -($::bga(height) / 2)]
            set y2 [expr +($::bga(height) / 2)]
            #puts [format "BGA Outline extents:  X1:  %s  Y1:  %s  X2:  %s  Y2:  %s" $x1 $y1 $x2 $y2]
    
            #  Does BGA section contain POLYGON outline?  If not, use the height and width
            if { [lsearch -exact [AIF::Variables BGA] OUTLINE] != -1 } {
                set poly [split [AIF::GetVar OUTLINE BGA]]
                set pw [lindex $poly 2]
                #puts $poly
                if { [lindex $poly 1] == 1 } {
                    set points [lreplace $poly  0 3 ]
                    puts $points 
                } else {
                    GUI::Transcript -severity warning -msg "Only one polygon supported for BGA outline, reverting to derived outline."
                    set x1 [expr -($::bga(width) / 2)]
                    set x2 [expr +($::bga(width) / 2)]
                    set y1 [expr -($::bga(height) / 2)]
                    set y2 [expr +($::bga(height) / 2)]
    
                    set points { $x1 $y1 $x2 $y2 }
                }
    
    
            } else {
                #set points { $x1 $y1 $x2 $y2 }
                set points [list $x1 $y1 $x2 $y2]
            }
    
            $cnvs create polygon $points -outline $color -tags "$::bga(name) bga bgaoutline"
            $cnvs create text $x2 $y2 -text $::bga(name) -fill $color \
                -anchor sw -font [list arial] -justify right -tags "$::bga(name) bga text refdes"
    
            #  Add some text to note the corner XY coordinates - visual reference only
            $cnvs create text $x1 $y1 -text [format "X: %.2f  Y: %.2f" $x1 $y1] -fill $color \
                -anchor sw -font [list arial] -justify left -tags "guides dimension text"
            $cnvs create text $x1 $y2 -text [format "X: %.2f  Y: %.2f" $x1 $y2] -fill $color \
                -anchor nw -font [list arial] -justify left -tags "guides dimension text"
            $cnvs create text $x2 $y1 -text [format "X: %.2f  Y: %.2f" $x2 $y1] -fill $color \
                -anchor se -font [list arial] -justify left -tags "guides dimension text"
            $cnvs create text $x2 $y2 -text [format "X: %.2f  Y: %.2f" $x2 $y2] -fill $color \
                -anchor ne -font [list arial] -justify left -tags "guides dimension text"
    
            #  Add cross hairs through the origin - visual reference only
            $cnvs create line [expr $x1 - $::bga(width) / 4] 0 [expr $x2 +$::bga(width) / 4] 0 \
                -fill $color -dash . -tags "guides xyaxis"
            $cnvs create line 0 [expr $y1 - $::bga(height) / 4] 0 [expr $y2 +$::bga(height) / 4] \
                -fill $color -dash . -tags "guides xyaxis"
    
            $cnvs configure -scrollregion [$cnvs bbox all]
        }
    
    }

    namespace eval Help {
        #
        #  GUI::Help::About
        #
        proc About {} {
            tk_messageBox -type ok -message "$xAIF::Settings(xAIF)\nVersion $xAIF::Settings(xAIFVersion)" \
                -icon info -title "About"
        }

        #
        #  GUI::Help::Version
        #
        proc Version {} {
            tk_messageBox -type ok -message "$xAIF::Settings(xAIF)\nVersion $xAIF::Settings(xAIFVersion)" \
                -icon info -title "Version"
        }

        #
        #  GUI::Help::NotImplemented
        #
        #  Stub procedure for GUI development to prevent Tcl and Tk errors.
        #
        proc NotImplemented {} {
            tk_messageBox -type ok -icon info -message "This operation has not been implemented."
        }
    }
}
