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
#    10/23/2016 - Major re-write for V2.
#

##
##  Define the GUI namespace and procedure supporting operations
##

namespace eval xAIF::GUI {

    variable Widgets

    set Widgets(mainframe) {}
    
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
    ##  xAIF::GUI::Build
    ##
    proc Build {} {
        variable Widgets

        ##  Define fixed with font used for displaying text
        #font create xAIFFont -family Helvetica -size 10 -weight normal
        font create xAIFFont -family Courier -size 10 -weight bold
        #font create xAIFFont -family courier_new -size 10 -weight normal
        font create xAIFFontBold -family courier_new -size 10 -weight bold
        font create xAIFDialogFontBold -family courier_new -size 9 -weight bold
        #font create xAIFFontBold -family Helvetica -size 10 -weight bold
        font create xAIFFontItalic -family arial -size 10 -weight normal -slant italic
        font create xAIFFontBoldItalic -family arial -size 10 -weight bold -slant italic
        font create xAIFCanvasFont -family Helvetica -size 10 -weight bold

        ##  Make the fonts in the dialog boxes look consistent with rest of the UI
        option add *Dialog.msg.font xAIFDialogFontBold

        set menudesc {
            "&File" all filemenu 0 {
                {command "&Open AIF ..."  {} "Open AIF File" {Ctrl O} -command xAIF::GUI::Dashboard::SelectAIF}
                {command "&Close AIF"  {} "Close AIF File" {Ctrl D} -command xAIF::GUI::File::CloseAIF}
                {command "&Reload AIF"  {} "Reload AIF File" {Ctrl R} -command xAIF::GUI::File::ReloadAIF}
                {separator}
                {command "Create &Design Stub ..."  {} "Create Design Stub" {Ctrl N} -command MGC::Generate::DesignStub}
                {separator}
                {command "Export &KYN ..."  {} "Export KYN File" {} -command Netlist::Export::KYN}
                {command "Export &Placement ..."  {} "Export Placement File" {} -command Netlist::Export::Placement}
                {command "Export &Wire Model ..."  {} "Export Wire Model" {} -command MGC::Wirebond::ExportWireModel}
                {separator}
                {cascade "&Design Config" {} {designconfigmenu} 0 {
                    {command "&Save" {} "Save Design Configuration" {} -command {xPCB::SaveDesignConfig}}
                    {command "Save &As ..." {} "Save Design Configuration As" {} -command {xPCB::SaveDesignConfigAs}}
                    {separator}
                    {command "&Load ..." {} "Load Design Configuration" {} -command {xPCB::LoadDesignConfigFrom}}
                }}
                {cascade "&Mesage Text" {} {messagetextmenu} 0 {
                    {command "&Clear" {} "Clear Message Text" {} -command {xAIF::GUI::ClearMessageText}}
                    {command "&Save As ..." {} "Save Message Text to File" {} -command {xAIF::GUI::SaveMessageTextToFile}}
                }}
                {separator}
                {checkbutton "&Show Tcl Console" consolemenu "Show/Hide Tcl Console" {} \
                    -variable xAIF::Settings(ShowConsole) -onvalue on -offvalue off \
                    -command { set s [expr [string is true $xAIF::Settings(ShowConsole)] ?"show":"hide"] ; console $s }}
                {separator}
                {command "&Quit"          {} "Quit" {Ctrl Z} -command { if { [tk_messageBox -title "Close xAIF" -icon question -message "Ok to Quit?" -type okcancel] == "ok" } { destroy . ; exit 1 }}}
            }
            "&Setup" all setupmenu 0 {
                {cascade "&Operating Mode" {} {operatingmodemenu} 0 {
                }}
                {separator}
                {cascade "&Pad Generation"  {} {padgenerationmenu} 0 {}}
                {cascade "Cell &Generation" {} {cellgenerationmenu} 0 {
                    {checkbutton "&Default" cellgendefault "Enable/Disable Cell Generation Default View" {} \
                        -variable xAIF::Settings(MirrorNone) -onvalue on -offvalue off \
                        -command { set s [expr [string is true $xAIF::Settings(MirrorNone)] ?"enabled":"disabled"] ; \
                        xAIF::GUI::Message -severity note -msg [format "Cell Generation default view %s." $s] }}
                    {checkbutton "Mirror &X" cellgendefault "Enable/Disable Cell Generation mirrored across X axis" {} \
                        -variable xAIF::Settings(MirrorX) -onvalue on -offvalue off \
                        -command { set s [expr [string is true $xAIF::Settings(MirrorX)] ?"enabled":"disabled"] ; \
                        xAIF::GUI::Message -severity note -msg [format "Cell Generation mirrored across X axis %s." $s] }}
                    {checkbutton "Mirror &Y" cellgendefault "Enable/Disable Cell Generation mirrored across Y axis" {} \
                        -variable xAIF::Settings(MirrorY) -onvalue on -offvalue off \
                        -command { set s [expr [string is true $xAIF::Settings(MirrorY)] ?"enabled":"disabled"] ; \
                        xAIF::GUI::Message -severity note -msg [format "Cell Generation mirrored across Y axis %s." $s] }}
                    {checkbutton "&Mirror XY" cellgendefault "Enable/Disable Cell Generation mirrored across X and Y axes" {} \
                        -variable xAIF::Settings(MirrorXY) -onvalue on -offvalue off \
                        -command { set s [expr [string is true $xAIF::Settings(MirrorXY)] ?"enabled":"disabled"] ; \
                        xAIF::GUI::Message -severity note -msg [format "Cell Generation mirrored across X and Y axes %s." $s] }}
                }}
                {cascade "Cell &Name Suffix" {} {cellnamesuffixmenu} 0 { }}
                {cascade "&BGA Cell Generation" {} {bgacellgenerationmenu} 0 { }}
                {cascade "&Default Cell Height" {} {defaultcellheightmenu} 0 { }}
                {command "Default &Package Cell ..."  {} "Default Package Cell" {} -command MGC::Design::SetPackageCell}
                {separator}
                {checkbutton "&Verbose Messages" verbosemsgs "Enable/Disable Verbose Messages" {} \
                    -variable xAIF::Settings(verbosemsgs) -onvalue on -offvalue off \
                    -command { set s [expr [string is true $xAIF::Settings(verbosemsgs)] ?"enabled":"disabled"] ; \
                    xAIF::GUI::Message -severity note -msg [format "Verbose Messages %s." $s] }}
            }
            "&View" all viewmenu 0 {
                {cascade "Zoom &In" {} {zoominmenu} 0 {
                    {command "&2x" {} "Zoom In 2x" {} -command "xAIF::GUI::View::Zoom $xAIF::GUI::Widgets(layoutview) 2.00" }
                    {command "&5x" {} "Zoom In 5x" {} -command "xAIF::GUI::View::Zoom $xAIF::GUI::Widgets(layoutview) 5.00" }
                    {command "&10x" {} "Zoom In 10x" {} -command "xAIF::GUI::View::Zoom $xAIF::GUI::Widgets(layoutview) 10.00" }
                    {separator}
                    {command "&Fit" {} "Zoom Fit" {} -command "xAIF::GUI::View::ZoomReset $xAIF::GUI::Widgets(layoutview)" }
                }}
                {cascade "Zoom &Out" {} {zoomoutmenu} 0 {
                    {command "&2x" {} "Zoom Out 2x" {} -command "xAIF::GUI::View::Zoom $xAIF::GUI::Widgets(layoutview) 0.50" }
                    {command "&5x" {} "Zoom Out 5x" {} -command "xAIF::GUI::View::Zoom $xAIF::GUI::Widgets(layoutview) 0.20" }
                    {command "&10x" {} "Zoom Out 10x" {} -command "xAIF::GUI::View::Zoom $xAIF::GUI::Widgets(layoutview) 0.10" }
                    {separator}
                    {command "&Fit" {} "Zoom Fit" {} -command "xAIF::GUI::View::ZoomReset $xAIF::GUI::Widgets(layoutview)" }
                }}
                {separator}
                {cascade "&Text" {} {textmenu} 0 {
                    {command "All &On" {} "All Text Visible" {} \
                        -command { xAIF::GUI::Draw::Visibility "text" -all true -mode on ; \
                        foreach t [array names xAIF::GUI::text] { set xAIF::GUI::text([lindex $t 0]) on }  }}
                    {command "All &Off" {} "All Text Hidden" {} \
                        -command { xAIF::GUI::Draw::Visibility "text" -all true -mode off ; \
                        foreach t [array names xAIF::GUI::text] { set xAIF::GUI::text([lindex $t 0]) off }  }}
                    {separator}
                    {checkbutton "&Pad Numbers" padnumbers "Show/Hide Pad Numbers" {} \
                        -variable xPCB::View(PadNumbers) -onvalue on -offvalue off \
                        -command { set s [expr [string is true $xPCB::View(PadNumbers)] ?"visible":"hidden"] ; \
                        xAIF::GUI::Message -severity note -msg [format "Pad Numbers %s." $s] ; \
                        xAIF::GUI::Draw::Visibility padnumber -mode toggle }}
                    {checkbutton "&Ref Designators" refdesignators "Show/Hide Pad Numbers" {} \
                        -variable xPCB::View(RefDesignators) -onvalue on -offvalue off \
                        -command { set s [expr [string is true $xPCB::View(RefDesignators)] ?"visible":"hidden"] ; \
                        xAIF::GUI::Message -severity note -msg [format "Ref Designators %s." $s] ; \
                        xAIF::GUI::Draw::Visibility refdes -mode toggle }}
                }}
                {cascade "&Devices" {} {devicesmenu} 0 {
                    {command "All &On" {} "All Devices Visible" {} \
                        -command { xAIF::GUI::Draw::Visibility {bga device} -all true -mode on ; \
                        foreach d [array names xAIF::mcmdie] { set xAIF::GUI::devices($d) on }  }}
                    {command "All &Off" {} "All Devices Hidden" {} \
                        -command { xAIF::GUI::Draw::Visibility {bga device} -all true -mode off ; \
                        foreach d [array names xAIF::mcmdie] { set xAIF::GUI::devices($d) off }  }}
                    {separator}
                }}
                {cascade "&Net Lines" {} {netlinesmenu} 0 {
                    {command "All &On" {} "All Net Lines Visible" {} \
                        -command { xAIF::GUI::Draw::Visibility {netline} -all true -mode on ; \
                        foreach nl [array names xAIF::netlines] { set xAIF::GUI::netlines($nl) on }  }}
                    {command "All &Off" {} "All Net Lines Hidden" {} \
                        -command { xAIF::GUI::Draw::Visibility {netline} -all true -mode off ; \
                        foreach nl [array names xAIF::netlines] { set xAIF::GUI::netlines($nl) off }  }}
                    {separator}
                }}
                {cascade "&Pads" {} {padsmenu} 0 {
                    {command "All &On" {} "All Pads Visible" {} \
                        -command { xAIF::GUI::Draw::Visibility {pad} -all true -mode on ; \
                        foreach p [array names xAIF::pads] { set xAIF::GUI::pads($p) on }  }}
                    {command "All &Off" {} "All Pads Hidden" {} \
                        -command { xAIF::GUI::Draw::Visibility {pad} -all true -mode off ; \
                        foreach p [array names xAIF::pads] { set xAIF::GUI::pads($p) off }  }}
                    {separator}
                }}
                {cascade "&Bond Wires" {} {bondwiresmenu} 0 {
                    {command "All &On" {} "All Bond Wires Visible" {} \
                        -command { xAIF::GUI::Draw::Visibility {bondwire} -all true -mode on ; \
                        foreach bw [array names xAIF::bondwires] { set xAIF::GUI::bondwires($bw) on }  }}
                    {command "All &Off" {} "All Bond Wires Hidden" {} \
                        -command { xAIF::GUI::Draw::Visibility {bondwire} -all true -mode off ; \
                        foreach bw [array names xAIF::bondwires] { set xAIF::GUI::bondwires($bw) off }  }}
                    {separator}
                }}
                {separator}
                {cascade "&Guides" {} {guidesmenu} 0 {
                    {command "All &On" {} "All Guides Visible" {} \
                        -command { xAIF::GUI::Draw::Visibility {guides} -all true -mode on ; \
                        foreach g [array names xAIF::guides] { set xAIF::GUI::guides($g) on }  }}
                    {command "All &Off" {} "All Guides Hidden" {} \
                        -command { xAIF::GUI::Draw::Visibility {guides} -all true -mode off ; \
                        foreach g [array names xAIF::guides] { set xAIF::GUI::guides($g) off }  }}
                    {separator}
                    {checkbutton "&XY Axes" xyaxes "Show/Hide X and Y Axes" {} \
                        -variable xPCB::View(XYAxes) -onvalue on -offvalue off \
                        -command { set s [expr [string is true $xPCB::View(XYAxes)] ?"visible":"hidden"] ; \
                        xAIF::GUI::Message -severity note -msg [format "XY Axes %s." $s] }}
                    {checkbutton "&Dimensions" dimensions "Show/Hide Dimensions" {} \
                        -variable xPCB::View(Dimensions) -onvalue on -offvalue off \
                        -command { set s [expr [string is true $xPCB::View(Dimensions)] ?"visible":"hidden"] ; \
                        xAIF::GUI::Message -severity note -msg [format "Dimensions %s." $s] }}
                }}
            }
            "&Library" { all librarymenu } librarymenu 0 {
                {cascade "&Active Library"  {} {activelibrariesmenu} 0 {}}
                {command "&Scan for Libraries"  {} "Scan for Active Libraries" {} -command {xLM::setOpenLibraries}}
                {separator}
                {cascade "&Work Directory" {} {} 0 {
                    {command "&From Library" {} "Set Work Directory from Library" {} -command { xPCB::Setup::WorkDirectoryFromLibrary }}
                    {command "&Choose Directory ..." {} "Choose Work Directory" {} -command { xPCB::Setup::WorkDirectory }}
                }}
            }
            "&Design" {all designmenu} designmenu 0 {
                {cascade "&Active Design"  {} {activedesignsmenu} 0 {}}
                {command "&Scan for Designs"  {} "Scan for Active Designs" {} -command {xPCB::setOpenDocuments}}
                {separator}
                {command "Set &Package Outline"  {} "Set the Package Outline" {}
                    -command { MGC::Design::SetPackageOutline }}
                {command "Set &Route Border"  {} "Set the Route Border" {}
                    -command { MGC::Design::SetRouteBorder }}
                {command "Set &Manufacturing Outline"  {} "Set the Manufacturing Outline" {}
                    -command { MGC::Design::SetManufacturingOutline }}
                {command "Set &Test Fixture Outline"  {} "Set the Test Fixture Outline" {}
                    -command { MGC::Design::SetTestFixtureOutline }}
                {separator}
                {command "Check &Database Units"  {} "Check Database Units" {}
                    -command { MGC::Design::CheckDatabaseUnits }}
                {separator}
                {cascade "&Work Directory" {} {} 0 {
                    {command "&From Design" {} "Set Work Directory from Design" {} -command { xPCB::Setup::WorkDirectoryFromDesign }}
                    {command "&Choose Directory ..." {} "Choose Work Directory" {} -command { xPCB::Setup::WorkDirectory }}
                }}
            }
            "&Generate" all generatemenu 0 {
                {command "&Pads ..."  {} "Generate Pads" {} -command { MGC::Generate::Pads }}
                {command "P&adstacks ..."  {} "Generate Padstacks" {} -command { MGC::Generate::Padstacks }}
                {command "&Cells ..."  {} "Generate Cells" {} -command { MGC::Generate::Cells }}
                {command "P&DBs ..."  {} "Generate PDBs" {} -command { MGC::Generate::PDBs }}
            }
            "&Wirebond" all wirebondmenu 0 {
                {command "&Setup ..."  {} "Setup Wirebond Parameters" {} -command { $xAIF::GUI::Widgets(notebook) raise wbpf }}
                {separator}
                {command "&Apply Wirebond Properties"  {} "Apply Wirebond Properties" {} -command { MGC::Wirebond::ApplyProperties }}
                {separator}
                {command "Place Bond &Pads ..."  {} "Place Bond Pads" {} -command { MGC::Wirebond::PlaceBondPads }}
                {command "Place Bond &Wires ..."  {} "Place Bond Wires" {} -command { MGC::Wirebond::PlaceBondWires }}
            }
            "&Tools" all toolsmenu 0 {
                {command "&XpeditionPCB ..."         {xpeditionpcb}   "Launch XpeditionPCB"       {} -command {xPCB::OpenXpeditionPCB}}
                {command "&Library Manager ..."      {librarymanager} "Launch Library Manager"    {} -command {xLM::OpenLibraryManager}}
            }
            "&Help" all helpmenu 0 {
                {command "&About" {} "About the Program" {} -command xAIF::GUI::Help::About}
                {command "&Version" {} "Program Version Details" {} -command xAIF::GUI::Help::Version}
                {command "&Environment" {} "Environment Variable Details" {} -command xAIF::GUI::Help::EnvVars}
                {command "&Internal State" {} "Internal State of Settings" {} -command xAIF::GUI::Help::InternalState}
                {separator}
                {checkbutton "&Debug Messages" debugmsgs "Enable/Disable Debug Messages" {} \
                    -variable xAIF::Settings(debugmsgs) -onvalue on -offvalue off \
                    -command { set s [expr [string is true $xAIF::Settings(debugmsgs)] ?"enabled":"disabled"] ; \
                    xAIF::GUI::Message -severity note -msg [format "Debug Messages %s." $s] }}
            }
        }

        ##  Build the main frame with the menu bar
        set Widgets(mainframe) [MainFrame .mainframe -menu $menudesc -progresstype infinite \
            -progressfg green -progressmax 10 -progressvar xAIF::Settings(progress) \
            -textvariable xAIF::Settings(status) -height 600 -width 800 -sizegrip true]
        pack $Widgets(mainframe) -fill both -expand yes

        set Widgets(operatingmode) [$Widgets(mainframe) addindicator \
            -text [format " Mode:  %s   Status:  %s" [string totitle $xAIF::Settings(operatingmode)] \
            [string totitle $xAIF::Settings(connectionstatus)]]]
        #$Widgets(mainframe) addindicator -text [format " %s  " [file tail [info script]]]
        $Widgets(mainframe) addindicator -text [format " %s " $xAIF::Settings(name)]
        $Widgets(mainframe) addindicator -text [format " v%s " $xAIF::Settings(version)]
        $Widgets(mainframe) showstatusbar progression

##        ##  Add active designs to Design pulldown menu
##        set designmenu [$Widgets(mainframe) getmenu design]
##        foreach dpath $xAIF::Settings(pcbOpenDocumentPaths) id $xAIF::Settings(pcbOpenDocumentIds) {
##            $designmenu add radiobutton -label [file tail $dpath] \
##                -variable xPCB::Settings(pcbAppId) -value $id \
##                -command { xPCB::setActiveDocument ; xPCB::setConductorLayers }
##        }

        ##  Add active designs to Design pulldown menu
        set menu [$Widgets(mainframe) getmenu operatingmodemenu]
        $menu add radiobutton -label "Design" \
            -variable xAIF::Settings(operatingmode) -value $xAIF::Const::XAIF_MODE_DESIGN \
            -command { xPCB::setOperatingMode } -underline 0
        $menu add radiobutton -label "Library" \
            -variable xAIF::Settings(operatingmode) -value $xAIF::Const::XAIF_MODE_LIBRARY \
            -command { xPCB::setOperatingMode } -underline 0

        ##  Add Cell Name Suffix options to Setup > Cell Name Suffix pulldown menu
        set menu [$Widgets(mainframe) getmenu cellnamesuffixmenu]
        set l [list  \
            $xAIF::Const::CELL_GEN_SUFFIX_NONE_KEY      $xAIF::Const::CELL_GEN_SUFFIX_NONE_VALUE \
            $xAIF::Const::CELL_GEN_SUFFIX_NUMERIC_KEY   $xAIF::Const::CELL_GEN_SUFFIX_NUMERIC_VALUE \
            $xAIF::Const::CELL_GEN_SUFFIX_ALPHA_KEY     $xAIF::Const::CELL_GEN_SUFFIX_ALPHA_VALUE \
            $xAIF::Const::CELL_GEN_SUFFIX_DATESTAMP_KEY $xAIF::Const::CELL_GEN_SUFFIX_DATESTAMP_VALUE \
            $xAIF::Const::CELL_GEN_SUFFIX_TIMESTAMP_KEY $xAIF::Const::CELL_GEN_SUFFIX_TIMESTAMP_VALUE]

        foreach { k v } $l {
            $menu add radiobutton -label $v -variable xAIF::Settings(CellNameSuffix) -value $k \
                -command [list xAIF::GUI::Message -severity note -msg [format "Cell Name Suffix:  %s" $v]]
        }

        ##  Add BGA Cell Generation options to Setup > BGA Generation pulldown menu
        set menu [$Widgets(mainframe) getmenu bgacellgenerationmenu]
        set l [list  \
            $xAIF::Const::CELL_GEN_BGA_NORMAL_KEY       $xAIF::Const::CELL_GEN_BGA_NORMAL_VALUE \
            $xAIF::Const::CELL_GEN_BGA_MSO_KEY          $xAIF::Const::CELL_GEN_BGA_MSO_VALUE]

        foreach { k v } $l {
            $menu add radiobutton -label $v -variable xAIF::Settings(BGACellGeneration) -value $k \
                -command [list xAIF::GUI::Message -severity note -msg [format "BGA Cell Generation:  %s" $v]]
        }

        ##  Add Default Cell Height options to Setup > Default Cell Height pulldown menu
        set menu [$Widgets(mainframe) getmenu defaultcellheightmenu]
        foreach i { 0 10 20 25 40 50 100 200 500 1000 } {
            $menu add radiobutton -label [format "%s" $i] \
                -variable xAIF::Settings(DefaultCellHeight) -value $i \
                -command [list xAIF::GUI::Message -severity note -msg [format "Default Cell Height:  %s" $i]]
        }

        ##  Disable the Show/Hide Console menu when not on Windows.
        set m $xAIF::GUI::Widgets(mainframe)
        if { [string equal $::tcl_platform(platform) windows] } {
            $m setmenustate consolemenu normal
        } else {
            $m setmenustate consolemenu disabled
        }
        
        ##  Add View All On/Off to several menus
        #set menu [$Widgets(mainframe) getmenu textmenu]

        #trace add variable xPCB::Settings(pcbAppId) write xPCB::setActiveDocument

        ##  Place where application widgets get stuffed.
        set mf [$Widgets(mainframe) getframe]

        ##  Create PanedWindow with 3 sections ...
        set Widgets(panedwindow) [PanedWindow $mf.pw -side top -weights available]
        pack $Widgets(panedwindow) -fill both -expand true -in $mf

        ##  Create two panes
        set l_pane [$Widgets(panedwindow) add -weight 1]
        set r_pane [$Widgets(panedwindow) add -weight 10]

        ##  Puts some buttons in the left pane
        set bf [frame $l_pane.buttonframe]

        button $bf.dbf -text "Dashboard" -command { $xAIF::GUI::Widgets(notebook) raise dbf } -relief raised -padx 5 -pady 8 -borderwidth 3
        button $bf.lvf -text "Layout View" -command { $xAIF::GUI::Widgets(notebook) raise lvf } -relief raised -padx 5 -pady 8 -borderwidth 3

        Separator::create $bf.sep1 -orient horizontal

        button $bf.openaif   -text "Open AIF"   -command { xAIF::GUI::Dashboard::SelectAIF } -relief raised -padx 5 -pady 8 -borderwidth 3
        button $bf.closeaif  -text "Close AIF"  -command { xAIF::GUI::File::CloseAIF }  -relief raised -padx 5 -pady 8 -borderwidth 3
        button $bf.reloadaif -text "Reload AIF" -command { xAIF::GUI::File::ReloadAIF }    -relief raised -padx 5 -pady 8 -borderwidth 3

        Separator::create $bf.sep2 -orient horizontal

        button $bf.xpcb -text "XpeditionPCB" -command { xPCB::OpenXpeditionPCB } -relief raised -padx 5 -pady 8 -borderwidth 3
        button $bf.xlm -text "Library Tools" -command { xLM::OpenLibraryManager } -relief raised -padx 5 -pady 8 -borderwidth 3

        pack $bf.dbf -pady 5 -expand y -fill both -ipady 5
        pack $bf.lvf -pady 5 -expand y -fill both -ipady 5
        pack $bf.sep1 -pady 15 -expand y -fill both
        pack $bf.openaif -pady 5 -expand y -fill both -ipady 5
        pack $bf.closeaif -pady 5 -expand y -fill both -ipady 5
        pack $bf.reloadaif -pady 5 -expand y -fill both -ipady 5
        pack $bf.sep2 -pady 15 -expand y -fill both
        pack $bf.xpcb -pady 5 -expand y -fill both -ipady 5
        pack $bf.xlm -pady 5 -expand y -fill both -ipady 5
        pack $bf -in $l_pane -side top
        #pack $l_pane.openaif -side top -padx 3
        #pack $l_pane -fill both -expand true

        ##  Divide right pane into two additional panes
        set r_pane_pw [PanedWindow $r_pane.pw -side left -weights available]
        pack $r_pane_pw -fill both -expand true

        ##  Create two panes within the right pane
        set r_t_pane [$r_pane_pw add -weight 10]
        set r_b_pane [$r_pane_pw add -weight 1]

        ##  Create a Notebook in the right upper pane to hold data
        set nb [NoteBook $r_t_pane.nb -side top] 
        set Widgets(notebook) $nb
        xAIF::GUI::Build::Notebook

        ##  Add a scrollable text widget to the right bottom pane
        set sw [ScrolledWindow $r_b_pane.sw]
        pack $nb $sw -fill both -expand true

        set Widgets(message) [ctext $sw.txt -wrap none -background white \
            -padx 5 -pady 0 -width 80 -height 10 -font xAIFFont]
        $Widgets(message) configure -font xAIFFont -state disabled

        $sw setwidget $Widgets(message)

        xPCB::setOperatingMode

        ##  Configure the main window
        #wm title . [format "%s v%s" $xAIF::Settings(name) $xAIF::Settings(version)]
        wm title . $xAIF::Settings(name)
        wm geometry . 1024x768
        
        wm protocol . WM_DELETE_WINDOW { destroy . ; exit 1 }
        wm transient .
        
        ##  Ready to display the dialog
        wm deiconify .
        
        ##  Setup an Idle Task
        after 0 xAIF::GUI::UpdateWhenIdle

        ##  Display the Console at startup?  Useful for development and debug
        if { [string is true $xAIF::Settings(ShowConsole)] && [string equal $::tcl_platform(platform) windows] } {
            console show
        }

        ##  Make this a modal dialog
        catch { tk visibility . }
        catch { grab set . }
        catch { tkwait window . }

    }

    proc UpdateWhenIdle { } {
        if { $xAIF::Settings(progress) != 0 } {
            xAIF::GUI::StatusBar::UpdateStatus -busy on
        } else {
            xAIF::GUI::StatusBar::UpdateStatus -busy on
        }
    }

    ##
    ##  Output a message with a severity level
    ##
    proc Message {args} {
        variable Widgets

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
        if { [lsearch [list note warning error none clear] $V(-severity)] == -1 } {
            error "value of \"$a\" must be one of note, warning, or error"
        }

        ##  Clear the message window?
        if { [string equal clear $V(-severity)] } {
            set txt $Widgets(message)
            $txt configure -state normal
            $txt delete 0.0 end
            $txt see end
            $txt configure -state disabled
            update idletasks
        } else {
            if {[string equal "" $V(-msg)]} {
                error "value of \"-msg\" option is missing"
            }

            ##  Generate the message
            if { [string equal $V(-severity) none] } {
                set msg [format "%s" $V(-msg)]
            } else {
                set msg [format "//  %s:  %s" [string totitle $V(-severity)] $V(-msg)]
            }

            set txt $Widgets(message)
            $txt configure -state normal
            $txt insert end "$msg\n"
            $txt see end
            $txt configure -state disabled
            update idletasks

            ##  Echo to console?  Only works on Windows ...
            if { [string is true $xAIF::Settings(ConsoleEcho)] } {
                if { [string compare -nocase $V(-severity) "note"] == 0 } {
                    puts stdout $msg
                } else {
                    puts stderr $msg
                }
                flush stdout
            }

            ##  Echo to stderr when debug enabled
            if { [string is true $xAIF::Settings(debugmsgs)] } {
                puts stderr $msg
                flush stdout
            }

            ##  Add message to Xpedition Message Window Output Tab
            if { [string is true $xAIF::Settings(verbosemsgs)]  && [string is true $xAIF::Settings(connection)] } {
                set pcbApp $xPCB::Settings(pcbApp)
                set mwot [[[[$pcbApp Addins] Item "Message Window"] Control] AddTab "Output"]
                $mwot AppendText "$msg\n"
            }
        }
    }

    ##
    ##  xAIF::ClearMessageText
    ##
    proc ClearMessageText { } {
        Message -severity clear
    }

    ##
    ##  xAIF::SaveMessageTextToFile
    ##
    proc SaveMessageTextToFile { } {
        variable Widgets
        #set msgText [$Widgets(message) get 1.0 {end -1c}]

        set file [tk_getSaveFile -title "Save Message Text" -parent . \
            -initialdir $xAIF::Settings(workdir) -initialfile $xAIF::Const::XAIF_DEFAULT_TXT_FILE]
        if { $file == "" } {
            return; # they clicked cancel
        }
        set x [catch { set fid [open $file w+] }]
        set y [catch { puts $fid [string trim [$Widgets(message) get 1.0 end-1c]] }]
        set z [catch { close $fid }]
        if { $x || $y || $z || ![file exists $file] || ![file isfile $file] || ![file readable $file] } {
            tk_messageBox -parent . -icon error \
                -message "An error occurred while saving to \"$file\"."
            Message -severity error -msg "An error occurred saving Message Text to \"$file\"."
        } else {
            tk_messageBox -parent . -icon info -message "Message Text saved to \"$file\"."
            Message -severity note -msg "Message Text saved to \"$file\"."
        }
    }

    proc TestMessageWindow {} {
        for { set t 0 } { $t <= 25 } { incr t }  {
            Message -severity note -msg [format "Test Message:  %s" $t]
        }
    }
    proc TestMessageWindowFonts {} {
        variable Widgets

        set count 0
        set tabwidth 0
        foreach family [lsort -dictionary [font families]] {
            $Widgets(message) tag configure f[incr count] -font [list $family 10]
            $Widgets(message) insert end ${family}:\t {} \
            "This is a simple sampler\n" f$count
            set w [font measure [$Widgets(message) cget -font] ${family}:]
            if {$w+5 > $tabwidth} {
                set tabwidth [expr {$w+5}]
                $Widgets(message) configure -tabs $tabwidth
            }
        }
    }

    ##
    ##  xAIF::SaveMessageTextToFile
    ##
    proc SaveMessageTextToFile { } {
        variable Widgets
        #set msgText [$Widgets(message) get 1.0 {end -1c}]

        set file [tk_getSaveFile -title "Save Message Text" -parent . -initialdir $xAIF::Settings(workdir) -initialfile "xAIF.txt"]
        if { $file == "" } {
            return; # they clicked cancel
        }
        set x [catch { set fid [open $file w+] }]
        set y [catch { puts $fid [string trim [$Widgets(message) get 1.0 end-1c]] }]
        set z [catch { close $fid }]
        if { $x || $y || $z || ![file exists $file] || ![file isfile $file] || ![file readable $file] } {
            tk_messageBox -parent . -icon error \
                -message "An error occurred while saving to \"$file\"."
            Message -severity error -msg "An error occurred saving Message Text to \"$file\"."
        } else {
            tk_messageBox -parent . -icon info -message "Message Text saved to \"$file\"."
            Message -severity note -msg "Message Text saved to \"$file\"."
        }
    }

}

##
##  Define the xAIF::GUI::Build namespace and procedure supporting operations
##
namespace eval xAIF::GUI::Build {

    ##
    ##  xAIF::GUI::Build::Menus
    ##
    proc Menus {} {
        ##  Create the main menu bar
        set mb [menu .menubar]

        xAIF::GUI::Build::FilePulldown $mb
        xAIF::GUI::Build::SetupPulldown $mb
        xAIF::GUI::Build::ViewPulldown $mb
        xAIF::GUI::Build::GeneratePulldown $mb
        xAIF::GUI::Build::DesignPulldown $mb
        xAIF::GUI::Build::WirebondPulldown $mb
        xAIF::GUI::Build::HelpPulldown $mb
    }

    ##
    ##  xAIF::GUI::Build::Notebook
    ##
    proc Notebook { } {
        ##  Build the notebook UI
        set nb $xAIF::GUI::Widgets(notebook)

        $nb insert end dbf -text "Dashboard"
        set pane [$nb getframe dbf] 
        set dbf [frame $pane.dashboard]
        #label $dbf.l -text "Dashboard Frame"
        #pack $dbf.l -fill both -expand y
        pack $dbf -fill both -expand y
        set xAIF::GUI::Widgets(dashboard) $dbf

        $nb insert end lvf -text "Layout"
        set pane [$nb getframe lvf] 
        set lvf [frame $pane.layoutview]
        #label $lvf.l -text "Layout Frame"
        #pack $lvf.l -fill both -expand y
        pack $lvf -fill both -expand y
        set xAIF::GUI::Widgets(layoutview) $lvf

        ##$nb insert end tf -text "Transcript"
        ##set pane [$nb getframe tf] 
        ##set tf [frame $pane.transcript]
        ###label $tf.l -text "Transcript Frame"
        ###pack $tf.l -fill both -expand y
        ##pack $tf -fill both -expand y
        ##set xAIF::GUI::Widgets(transcript) $tf

        $nb insert end sf -text "AIF Source File"
        set pane [$nb getframe sf] 
        set sf [frame $pane.sourceview]
        #label $sf.l -text "AIF Source Frame"
        #pack $sf.l -fill both -expand y
        pack $sf -fill both -expand y
        set xAIF::GUI::Widgets(sourceview) $sf

        $nb insert end nf -text "Netlist"
        set pane [$nb getframe nf] 
        set nf [frame $pane.netlistview]
        pack $nf -fill both -expand y
        set xAIF::GUI::Widgets(netlistview) $nf

        ##$nb insert end ssf -text "Sparse Pins"
        ##set pane [$nb getframe ssf] 
        ##set ssf [frame $pane.sparsepinsview]
        ##pack $ssf -fill both -expand y
        ##set xAIF::GUI::Widgets(sparsepinsview) $ssf

        $nb insert end nltf -text "AIF Netlist"
        set pane [$nb getframe nltf] 
        set nltf [frame $pane.netlisttable]
        pack $nltf -fill both -expand y
        set xAIF::GUI::Widgets(netlisttable) $nltf

        $nb insert end knltf -text "KYN Netlist"
        set pane [$nb getframe knltf] 
        set knltf [frame $pane.kynnetlist]
        pack $knltf -fill both -expand y
        set xAIF::GUI::Widgets(kynnetlist) $knltf

        $nb insert end wbpf -text "Wire Bond Parameters"
        set pane [$nb getframe wbpf] 
        set wbpf [frame $pane.wirebondparams]
        pack $wbpf -fill both -expand y
        set xAIF::GUI::Widgets(wirebondparams) $wbpf

        pack $nb -fill both -expand y

        $nb raise lvf 

        ##  Hide the netlist tab, it is used but shouldn't be visible
        #$nb hide $nf
        #$nb hide $ssf
        #foreach i [$pane configure] {
        #    puts $i
        #}

        xAIF::GUI::Build::Notebook::LayoutFrame $lvf
        xAIF::GUI::Build::Notebook::AIFSourceFrame $sf
        ##xAIF::GUI::Build::Notebook::TranscriptFrame $tf
        xAIF::GUI::Build::Notebook::NetlistFrame $nf
        ##xAIF::GUI::Build::Notebook::SparsePinsFrame $ssf
        xAIF::GUI::Build::Notebook::AIFNetlistTableFrame $nltf
        xAIF::GUI::Build::Notebook::KYNNetlistFrame $knltf

        xAIF::GUI::Build::Dashboard
        xAIF::GUI::Build::WirebondParameters
    }

    ##
    ##  xAIF::GUI::Build::Notebook namespace
    ##
    namespace eval Notebook {

        ##
        ##  xAIF::GUI::Build:Notebook::LayoutFrame
        ##
        proc LayoutFrame { lvf } {
            ##  Canvas frame for Layout View
            set lvfcanvas [canvas $lvf.canvas -bg black \
                -xscrollcommand [list $lvf.lvfcanvasscrollx set] \
                -yscrollcommand [list $lvf.lvfcanvasscrolly set]]
            set xAIF::GUI::Widgets(layoutview) $lvfcanvas
            #$lvfcanvas configure -background black
            #$lvfcanvas configure -fg white
            scrollbar $lvf.lvfcanvasscrolly -orient v -command [list $lvfcanvas yview]
            scrollbar $lvf.lvfcanvasscrollx -orient h -command [list $lvfcanvas xview]
            grid $lvfcanvas -row 0 -column 0 -in $lvf -sticky nsew
            grid $lvf.lvfcanvasscrolly -row 0 -column 1 -in $lvf -sticky ns -columnspan 1
            grid $lvf.lvfcanvasscrollx -row 1 -column 0 -in $lvf -sticky ew -columnspan 1

            ##  Add a couple of zooming buttons
            set bf [frame .buttonframe]
            button $bf.zoomfit     -text "Zoom Fit" -command "xAIF::GUI::View::ZoomReset $lvfcanvas" -relief raised -padx 5 -pady 3 -borderwidth 3
            button $bf.zoomin      -text "Zoom In"  -command "xAIF::GUI::View::Zoom $lvfcanvas 1.25" -relief raised -padx 5 -pady 3 -borderwidth 3
            button $bf.zoomout     -text "Zoom Out" -command "xAIF::GUI::View::Zoom $lvfcanvas 0.80" -relief raised -padx 5 -pady 3 -borderwidth 3
            button $bf.zoomin2x    -text "Zoom In 2x"  -command "xAIF::GUI::View::Zoom $lvfcanvas 2.00" -relief raised -padx 5 -pady 3 -borderwidth 3
            button $bf.zoomout2x   -text "Zoom Out 2x" -command "xAIF::GUI::View::Zoom $lvfcanvas 0.50" -relief raised -padx 5 -pady 3 -borderwidth 3
            button $bf.zoomin5x    -text "Zoom In 5x"  -command "xAIF::GUI::View::Zoom $lvfcanvas 5.00" -relief raised -padx 5 -pady 3 -borderwidth 3
            button $bf.zoomout5x   -text "Zoom Out 5x" -command "xAIF::GUI::View::Zoom $lvfcanvas 0.20" -relief raised -padx 5 -pady 3 -borderwidth 3
            button $bf.invertxaxis -text "Invert X Axis" -command "$lvfcanvas scale all 0 0 -1 1" -relief raised -padx 5 -pady 3 -borderwidth 3
            button $bf.invertyaxis -text "Invert Y Axis" -command "$lvfcanvas scale all 0 0 1 -1" -relief raised -padx 5 -pady 3 -borderwidth 3
            grid $bf.zoomfit $bf.zoomin $bf.zoomout $bf.zoomin2x $bf.zoomout2x $bf.zoomin5x $bf.zoomout5x $bf.invertxaxis $bf.invertyaxis -padx 3
            grid $bf -in $lvf -sticky nsew

            grid columnconfigure $lvf 0 -weight 1
            grid    rowconfigure $lvf 0 -weight 1

            ## Set up event bindings for canvas:
            bind $lvfcanvas <3> "xAIF::GUI::View::ZoomMark $lvfcanvas %x %y"
            bind $lvfcanvas <B3-Motion> "xAIF::GUI::View::ZoomStroke $lvfcanvas %x %y"
            bind $lvfcanvas <ButtonRelease-3> "xAIF::GUI::View::ZoomArea $lvfcanvas %x %y"
        }

        ##
        ##  xAIF::GUI::Build:Notebook::TranscriptFrame
        ##
        proc TranscriptFrame { tf } {
            set tftext [ctext $tf.text -wrap none \
                -xscrollcommand [list $tf.tftextscrollx set] \
                -yscrollcommand [list $tf.tftextscrolly set]]
            $tftext configure -font xAIFFont -state disabled
            set xAIF::GUI::Widgets(transcript) $tftext
            scrollbar $tf.tftextscrolly -orient vertical -command [list $tftext yview]
            scrollbar $tf.tftextscrollx -orient horizontal -command [list $tftext xview]
            grid $tftext -row 0 -column 0 -in $tf -sticky nsew
            grid $tf.tftextscrolly -row 0 -column 1 -in $tf -sticky ns
            grid $tf.tftextscrollx x -row 1 -column 0 -in $tf -sticky ew
            grid columnconfigure $tf 0 -weight 1
            grid    rowconfigure $tf 0 -weight 1
        }

        ##
        ##  xAIF::GUI::Build:Notebook::AIFSourceFrame
        ##
        proc AIFSourceFrame { sf } {
            set sftext [ctext $sf.text -wrap none \
                -xscrollcommand [list $sf.sftextscrollx set] \
                -yscrollcommand [list $sf.sftextscrolly set]]
            $sftext configure -font xAIFFont -state disabled
            set xAIF::GUI::Widgets(sourceview) $sftext
            scrollbar $sf.sftextscrolly -orient vertical -command [list $sftext yview]
            scrollbar $sf.sftextscrollx -orient horizontal -command [list $sftext xview]
            grid $sftext -row 0 -column 0 -in $sf -sticky nsew
            grid $sf.sftextscrolly -row 0 -column 1 -in $sf -sticky ns
            grid $sf.sftextscrollx x -row 1 -column 0 -in $sf -sticky ew
            grid columnconfigure $sf 0 -weight 1
            grid    rowconfigure $sf 0 -weight 1
        }

        ##
        ##  xAIF::GUI::Build:Notebook::NetlistFrame
        ##
        proc NetlistFrame { nf } {
            set nftext [ctext $nf.text -wrap none \
                -xscrollcommand [list $nf.nftextscrollx set] \
                -yscrollcommand [list $nf.nftextscrolly set]]

            $nftext configure -font xAIFFont -state disabled
            set xAIF::GUI::Widgets(netlistview) $nftext
            scrollbar $nf.nftextscrolly -orient vertical -command [list $nftext yview]
            scrollbar $nf.nftextscrollx -orient horizontal -command [list $nftext xview]
            grid $nftext -row 0 -column 0 -in $nf -sticky nsew
            grid $nf.nftextscrolly -row 0 -column 1 -in $nf -sticky ns
            grid $nf.nftextscrollx x -row 1 -column 0 -in $nf -sticky ew
            grid columnconfigure $nf 0 -weight 1
            grid    rowconfigure $nf 0 -weight 1
        }

        ##
        ##  xAIF::GUI::Build:Notebook::SparsePinsFrame
        ##
        proc SparsePinsFrame { ssf } {
            set ssftext [ctext $ssf.text -wrap none \
                -xscrollcommand [list $ssf.ssftextscrollx set] \
                -yscrollcommand [list $ssf.ssftextscrolly set]]
            $ssftext configure -font xAIFFont -state disabled
            set xAIF::GUI::Widgets(sparsepinsview) $ssftext
            scrollbar $ssf.ssftextscrolly -orient vertical -command [list $ssftext yview]
            scrollbar $ssf.ssftextscrollx -orient horizontal -command [list $ssftext xview]
            grid $ssftext -row 0 -column 0 -in $ssf -sticky nsew
            grid $ssf.ssftextscrolly -row 0 -column 1 -in $ssf -sticky ns
            grid $ssf.ssftextscrollx x -row 1 -column 0 -in $ssf -sticky ew
            grid columnconfigure $ssf 0 -weight 1
            grid    rowconfigure $ssf 0 -weight 1
        }

        ##
        ##  xAIF::GUI::Build:Notebook::AIFNetlistTableFrame
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

            #$nltable configure -font xAIFFont -state disabled
            set xAIF::GUI::Widgets(netlisttable) $nltable
            scrollbar $nltf.nltablescrolly -orient vertical -command [list $nltable yview]
            scrollbar $nltf.nltablescrollx -orient horizontal -command [list $nltable xview]
            grid $nltable -row 0 -column 0 -in $nltf -sticky nsew
            grid $nltf.nltablescrolly -row 0 -column 1 -in $nltf -sticky ns
            grid $nltf.nltablescrollx x -row 1 -column 0 -in $nltf -sticky ew
            grid columnconfigure $nltf 0 -weight 1
            grid    rowconfigure $nltf 0 -weight 1
        }

        ##
        ##  xAIF::GUI::Build:Notebook::KYNNetlistFrame
        ##
        proc KYNNetlistFrame { knltf } {
            set knltftext [ctext $knltf.text -wrap none \
                -xscrollcommand [list $knltf.nftextscrollx set] \
                -yscrollcommand [list $knltf.nftextscrolly set]]

            $knltftext configure -font xAIFFont -state disabled
            set xAIF::GUI::Widgets(kynnetlistview) $knltftext
            scrollbar $knltf.nftextscrolly -orient vertical -command [list $knltftext yview]
            scrollbar $knltf.nftextscrollx -orient horizontal -command [list $knltftext xview]
            grid $knltftext -row 0 -column 0 -in $knltf -sticky nsew
            grid $knltf.nftextscrolly -row 0 -column 1 -in $knltf -sticky ns
            grid $knltf.nftextscrollx x -row 1 -column 0 -in $knltf -sticky ew
            grid columnconfigure $knltf 0 -weight 1
            grid    rowconfigure $knltf 0 -weight 1
        }
    }

    ##
    ##  xAIF::GUI::Build::Dashboard
    ##
    proc Dashboard {} {
        set db $xAIF::GUI::Widgets(dashboard)
        #set dbf [frame $db.frame -borderwidth 5 -relief ridge]
        set dbf $db

        ##  Mode
        labelframe $dbf.mode -pady 2 -text "Mode" -padx 2
        foreach i [list $xAIF::Const::XAIF_MODE_DESIGN $xAIF::Const::XAIF_MODE_LIBRARY] {
            radiobutton $dbf.mode.b$i -text [string totitle $i] -variable xAIF::Settings(operatingmode) \
            -relief flat -value $i -variable xAIF::Settings(operatingmode) -command { xPCB::setOperatingMode }
            pack $dbf.mode.b$i  -side left -pady 2 -anchor w
        }

        ##  Cell Suffix
        set l [list  \
            $xAIF::Const::CELL_GEN_SUFFIX_NONE_KEY      $xAIF::Const::CELL_GEN_SUFFIX_NONE_VALUE \
            $xAIF::Const::CELL_GEN_SUFFIX_NUMERIC_KEY   $xAIF::Const::CELL_GEN_SUFFIX_NUMERIC_VALUE \
            $xAIF::Const::CELL_GEN_SUFFIX_ALPHA_KEY     $xAIF::Const::CELL_GEN_SUFFIX_ALPHA_VALUE \
            $xAIF::Const::CELL_GEN_SUFFIX_DATESTAMP_KEY $xAIF::Const::CELL_GEN_SUFFIX_DATESTAMP_VALUE \
            $xAIF::Const::CELL_GEN_SUFFIX_TIMESTAMP_KEY $xAIF::Const::CELL_GEN_SUFFIX_TIMESTAMP_VALUE]
        labelframe $dbf.cellsuffix -pady 2 -text "Cell Name Suffix (aka Version)" -padx 2
        foreach { k  v } $l {
            radiobutton $dbf.cellsuffix.b$k -text $v -variable xAIF::Settings(CellNameSuffix) -value $k \
                -command [list xAIF::GUI::Message -severity note -msg [format "Cell Name Suffix:  %s" $v]]
            pack $dbf.cellsuffix.b$k  -side top -pady 2 -anchor w
        }

        ##  Cell Generation
        labelframe $dbf.cellgeneration -pady 2 -text "Cell Generation" -padx 2
        foreach { i j } { MirrorNone "Default" MirrorX "Mirror across Y-Axis" MirrorY "Mirror across X-Axis" MirrorXY "Mirror across X & Y Axes" } {
            checkbutton $dbf.cellgeneration.b$i -text "$j" -relief flat -onvalue on -offvalue off -variable xAIF::Settings($i)
            #checkbutton $dbf.cellgeneration.b$i -text "$j" -relief flat -onvalue on -offvalue off -variable xAIF::Settings($i) \
            #    -command [list set s [expr [string is true $xAIF::Settings($i)] ?"enabled":"disabled"] ; \
            #    xAIF::GUI::Message -severity note -msg [format "Cell Generation default view %s." \$s]]
            pack $dbf.cellgeneration.b$i  -side top -pady 2 -anchor w
        }

        ##  BGA Generation
        labelframe $dbf.bgageneration -pady 2 -text "BGA Generation" -padx 2
        set l [list  \
            $xAIF::Const::CELL_GEN_BGA_NORMAL_KEY       $xAIF::Const::CELL_GEN_BGA_NORMAL_VALUE \
            $xAIF::Const::CELL_GEN_BGA_MSO_KEY          $xAIF::Const::CELL_GEN_BGA_MSO_VALUE]
        foreach { k v } $l {
            radiobutton $dbf.bgageneration.b$k -text $v -variable xAIF::Settings(BGACellGeneration) -value $k \
                -command [list xAIF::GUI::Message -severity note -msg [format "BGA Cell Generation:  %s" $v]]
            pack $dbf.bgageneration.b$k  -side top -pady 2 -anchor w
        }
        ##  Until VX.2, a bug in the API prevents generating MSO cells so disable the radio button.
        #$dbf.bgageneration.bmso configure -state disabled

        ##  Default Cell Height
        labelframe $dbf.defaultcellheight -pady 5 -text "Default Cell Height (um)" -padx 5
        entry $dbf.defaultcellheight.e -width 15 -relief sunken -bd 2 -textvariable xAIF::Settings(DefaultCellHeight)
        pack $dbf.defaultcellheight.e

        ##  Visibility
        labelframe $dbf.visibility -pady 2 -text "Application Visibility" -padx 2
        foreach { i j } { on On off Off } {
            radiobutton $dbf.visibility.b$i -text "$j" -variable xAIF::Settings(appVisible) \
	                -relief flat -value $i -command { xAIF::GUI::Message -severity note -msg \
                [format "Application visibility is now %s." \
                [expr [string is true $xAIF::Settings(appVisible)] ? "on" : "off"]] }
            pack $dbf.visibility.b$i  -side left -pady 2 -anchor w
        }

        ##  Connection
        labelframe $dbf.connection -pady 2 -text "Application Connection" -padx 2
        foreach { i j } { on On off Off } {
            radiobutton $dbf.connection.b$i -text "$j" -variable xAIF::Settings(appConnect) \
	                -relief flat -value $i -command {xAIF::GUI::Message -severity note -msg \
                [format "Application Connect mode is now %s." \
                $xAIF::Settings(appConnect) ] ; xAIF::GUI::StatusBar::UpdateStatus -busy off }
            pack $dbf.connection.b$i  -side left -pady 2 -anchor w
        }

        ##  AIF File
        labelframe $dbf.aiffile -pady 3 -text "AIF File" -padx 5
        entry $dbf.aiffile.e -width 65 -relief sunken -bd 2 -textvariable xAIF::GUI::Dashboard::AIFFile
        button $dbf.aiffile.b -text "AIF File ..."  -width 13 -anchor w \
            -command xAIF::GUI::Dashboard::SelectAIF
        grid $dbf.aiffile.e -row 0 -column 0 -pady 5 -padx 5 -sticky w
        grid $dbf.aiffile.b -row 0 -column 1 -pady 5 -padx 5 -sticky ew

        ##  Design Path
        labelframe $dbf.design -pady 3 -text "Design" -padx 5
        entry $dbf.design.e -width 65 -relief sunken -bd 2 -textvariable xAIF::Settings(DesignPath)
        button $dbf.design.b -text "Design ..." -width 13 -anchor w -command \
            { set xAIF::Settings(DesignPath) [tk_getOpenFile -filetypes {{PCB .pcb}}] }
        grid $dbf.design.e -row 0 -column 0 -pady 5 -padx 5 -sticky w
        grid $dbf.design.b -row 0 -column 1 -pady 5 -padx 5 -sticky ew

        ##  Library Path
        labelframe $dbf.library -pady 5 -text "Central Library" -padx 5
        entry $dbf.library.le -width 65 -relief sunken -bd 2 -textvariable xAIF::Settings(LibraryPath)
        button $dbf.library.lb -text "Library ..." -command xAIF::GUI::Dashboard::SelectCentralLibrary -anchor w
        entry $dbf.library.ce -width 35 -relief sunken -bd 2 -textvariable xAIF::GUI::Dashboard::CellPartition
        button $dbf.library.cb -text "Cell Partition ..." -state disabled -command xAIF::GUI::Dashboard::SelectCellPartition
        entry $dbf.library.pe -width 35 -relief sunken -bd 2 -textvariable xAIF::GUI::Dashboard::PartPartition
        button $dbf.library.pb -text "PDB Partition ..." -state disabled -command xAIF::GUI::Dashboard::SelectPartPartition

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
            -textvariable xAIF::GUI::Dashboard::WBParameters -state readonly
        grid $dbf.wbparameters.e -row 0 -column 0 -pady 5 -padx 5 -sticky w

        ##  WBDRCProperty
        labelframe $dbf.wbdrcproperty -pady 5 -text "Wire Bond DRC Property" -padx 5
        entry $dbf.wbdrcproperty.e -width 110 -relief sunken -bd 2 \
            -textvariable xAIF::GUI::Dashboard::WBDRCProperty -state readonly
        grid $dbf.wbdrcproperty.e -row 0 -column 0 -pady 5 -padx 5 -sticky w


        Separator::create $dbf.sep1 -orient vertical
        Separator::create $dbf.sep2 -orient horizontal
        Separator::create $dbf.sep3 -orient horizontal

        ##  Place all of the widgets
        grid $dbf.aiffile           -row 0 -column 0 -sticky new -padx 10 -pady 4 -columnspan 2
        grid $dbf.design            -row 1 -column 0 -sticky new -padx 10 -pady 4 -columnspan 2
        grid $dbf.library           -row 2 -column 0 -sticky new -padx 10 -pady 4 -columnspan 2
        grid $dbf.sep1              -row 0 -column 2 -sticky ns -padx 3 -pady 3 -rowspan 3
        grid $dbf.mode              -row 0 -column 3 -sticky new -padx 10 -pady 4
        grid $dbf.connection        -row 1 -column 3 -sticky new -padx 10 -pady 4
        grid $dbf.visibility        -row 2 -column 3 -sticky new -padx 10 -pady 4
        grid $dbf.sep2              -row 3 -column 0 -sticky ew -padx 3 -pady 3 -columnspan 4
        grid $dbf.cellgeneration    -row 4 -column 0 -sticky new -padx 10 -pady 4 -rowspan 2
        grid $dbf.cellsuffix        -row 4 -column 1 -sticky new -padx 10 -pady 4 -columnspan 2 -rowspan 2
        grid $dbf.bgageneration     -row 4 -column 3 -sticky new -padx 10 -pady 4 -rowspan 2
        grid $dbf.defaultcellheight -row 5 -column 3 -sticky sew -padx 10 -pady 4
        grid $dbf.sep3              -row 6 -column 0 -sticky ew -padx 3 -pady 3 -columnspan 5
        grid $dbf.wbparameters      -row 7 -column 0 -sticky new -padx 10 -pady 4 -columnspan 5
        grid $dbf.wbdrcproperty     -row 8 -column 0 -sticky new -padx 10 -pady 4 -columnspan 5

        grid $dbf -row 0 -column 0 -sticky nw -padx 10 -pady 10
    }

    ##
    ##  xAIF::GUI::Build::WirebondParameters
    ##
    proc WirebondParameters {} {
        set wbp $xAIF::GUI::Widgets(wirebondparams)
        #set wbpf [frame $wbp.frame -borderwidth 5 -relief ridge]
        set wbpf $wbp

        ##  Units
        labelframe $wbpf.units -pady 2 -text "Units" -padx 2
        foreach { i j } { um "Microns" th "Thousandths" } {
            radiobutton $wbpf.units.b$i -text "$j" -variable MGC::Wirebond::Units \
	            -relief flat -value $i
            pack $wbpf.units.b$i  -side top -pady 2 -anchor w
        }

        ##  Angle
        labelframe $wbpf.angle -pady 2 -text "Angle" -padx 2
        foreach { i j } { deg "Degrees" rad "Radians" } {
            radiobutton $wbpf.angle.b$i -text "$j" -variable MGC::Wirebond::Angle \
	            -relief flat -value $i
            pack $wbpf.angle.b$i  -side top -pady 2 -anchor w
        }

        ##  Wire Bond Parameters
        labelframe $wbpf.wbparameters -pady 2 -text "Wire Bond Parameters" -padx 2
        foreach i  [array names MGC::Wirebond::WBParameters] {
            label $wbpf.wbparameters.l$i -text "$i:"
            entry $wbpf.wbparameters.e$i -relief sunken \
                -textvariable MGC::Wirebond::WBParameters($i)
            pack $wbpf.wbparameters.l$i  -side left -pady 2 -anchor w
            pack $wbpf.wbparameters.e$i  -side left -pady 2 -anchor w -expand true
            grid $wbpf.wbparameters.l$i $wbpf.wbparameters.e$i -padx 3 -pady 3 -sticky w
        }
        button $wbpf.wbparameters.b -text "Select Bond Pad ..." -command MGC::Wirebond::SelectBondPad
        grid $wbpf.wbparameters.b -padx 3 -pady 3 -sticky s -column 1

        ##  Wire Bond DRC Property
        labelframe $wbpf.wbdrcproperty -pady 2 -text "Wire Bond DRC Property" -padx 2
        foreach i [array names MGC::Wirebond::WBDRCProperty] {
            label $wbpf.wbdrcproperty.l$i -text "$i:"
            entry $wbpf.wbdrcproperty.e$i -relief sunken -textvariable MGC::Wirebond::WBDRCProperty($i)
            pack $wbpf.wbdrcproperty.l$i  -side left -pady 2 -anchor w
            pack $wbpf.wbdrcproperty.e$i  -side left -pady 2 -anchor w -expand true
            grid $wbpf.wbdrcproperty.l$i $wbpf.wbdrcproperty.e$i -padx 3 -pady 3 -sticky w
        }

        ##  Wire Bond Rule
        #labelframe $wbpf.wbrule -pady 2 -text "Wire Bond Rule" -padx 2
        #foreach i [array names MGC::Wirebond::WBRule] {
        ##    label $wbpf.wbrule.l$i -text "$i:"
        ##    entry $wbpf.wbrule.e$i -relief sunken -textvariable MGC::Wirebond::WBRule($i)
        ##    pack $wbpf.wbrule.l$i  -side left -pady 2 -anchor w
        ##    pack $wbpf.wbrule.e$i  -side left -pady 2 -anchor w -expand true
        ##    grid $wbpf.wbrule.l$i $wbpf.wbrule.e$i -padx 3 -pady 3 -sticky w
        #}

        ##  Bond Wire Setup
        #labelframe $wbpf.bondwireparams -pady 5 -text "Default Bond Wire Setup" -padx 5

        ##  WBParameters
        labelframe $wbpf.wbparametersval -pady 2 -text "Wire Bond Parameters Property Value" -padx 5
        entry $wbpf.wbparametersval.e -width 120 -relief sunken -bd 2 \
            -textvariable xAIF::GUI::Dashboard::WBParameters -state readonly
        button $wbpf.wbparametersval.b -text "Update" -command MGC::Wirebond::UpdateParameters
        grid $wbpf.wbparametersval.b -row 0 -column 0 -pady 2 -padx 5 -sticky w
        grid $wbpf.wbparametersval.e -row 0 -column 1 -pady 2 -padx 5 -sticky w

        ##  WBDRCProperty
        labelframe $wbpf.wbdrcpropertyval -pady 2 -text "Wire Bond DRC Property Property Value" -padx 5
        entry $wbpf.wbdrcpropertyval.e -width 120 -relief sunken -bd 2 \
            -textvariable xAIF::GUI::Dashboard::WBDRCProperty -state readonly
        button $wbpf.wbdrcpropertyval.b -text "Update" -command MGC::Wirebond::UpdateDRCProperty
        grid $wbpf.wbdrcpropertyval.b -row 0 -column 0 -pady 2 -padx 5 -sticky w
        grid $wbpf.wbdrcpropertyval.e -row 0 -column 1 -pady 2 -padx 5 -sticky w

        ##  WBRule
        labelframe $wbpf.wbrule -pady 2 -text "Default Wire Model" -padx 5
        set tftext [text $wbpf.wbrule.text -wrap word  -height 10 \
            -xscrollcommand [list $wbpf.wbrule.tftextscrollx set] \
            -yscrollcommand [list $wbpf.wbrule.tftextscrolly set]]
        $tftext configure -font xAIFFont -state disabled
        scrollbar $wbpf.wbrule.tftextscrolly -orient vertical -command [list $tftext yview]
        scrollbar $wbpf.wbrule.tftextscrollx -orient horizontal -command [list $tftext xview]
        grid $tftext -row 0 -column 0 -in $wbpf.wbrule -sticky nsew
        grid $wbpf.wbrule.tftextscrolly -row 0 -column 1 -in $wbpf.wbrule -sticky ns
        grid $wbpf.wbrule.tftextscrollx x -row 1 -column 0 -in $wbpf.wbrule -sticky ew
        grid columnconfigure $wbpf.wbrule 0 -weight 1
        grid    rowconfigure $wbpf.wbrule 0 -weight 1

        $wbpf.wbrule.text configure -state normal
        $wbpf.wbrule.text insert 1.0 $MGC::Wirebond::WBRule(Value)
        $wbpf.wbrule.text configure -state disabled
        #puts $MGC::Wirebond::WBRule(Value)

        Separator::create $wbpf.sep1 -orient vertical
        Separator::create $wbpf.sep2 -orient vertical
        Separator::create $wbpf.sep3 -orient horizontal

        ##  Place all of the widgets
        grid $wbpf.units            -row 0 -column 0 -sticky new -padx 10 -pady 4
        grid $wbpf.angle            -row 1 -column 0 -sticky new -padx 10 -pady 4
        grid $wbpf.sep1             -row 0 -column 1 -sticky ns -padx 3 -pady 3 -rowspan 4
        grid $wbpf.wbparameters     -row 0 -column 2 -sticky new -padx 10 -pady 4 -rowspan 2
        grid $wbpf.sep2             -row 0 -column 3 -sticky ns -padx 3 -pady 3 -rowspan 4
        grid $wbpf.wbdrcproperty    -row 0 -column 4 -sticky new -padx 10 -pady 4 -rowspan 2
        #grid $wbpf.wbrule           -row 0 -column 4 -sticky new -padx 10 -pady 4 -rowspan 2
        grid $wbpf.sep3             -row 5 -column 0 -sticky ew -padx 2 -pady 2 -columnspan 5
        grid $wbpf.wbparametersval  -row 6 -column 0 -sticky new -padx 10 -pady 4 -columnspan 5
        grid $wbpf.wbdrcpropertyval -row 7 -column 0 -sticky new -padx 10 -pady 4 -columnspan 5
        grid $wbpf.wbrule           -row 8 -column 0 -sticky new -padx 10 -pady 4 -columnspan 5

        ##  Want to expand everything to fill frame but this doesn't work.  :-(
        grid $wbpf -row 0 -column 0 -sticky nsew -padx 0 -pady 0
    }
}

##
##  Define the xAIF::GUI::Menus namespace and procedure supporting operations
##
namespace eval xAIF::GUI::Menus {
    ##
    ##  xAIF::GUI::Menus::CentralLibraryMode
    ##
    proc CentralLibraryMode {} {
        $xAIF::GUI::Widgets(setupmenu) entryconfigure  3 -state disabled
        $xAIF::GUI::Widgets(setupmenu) entryconfigure 4 -state normal
        #$xAIF::GUI::Widgets(setupmenu) entryconfigure 7 -state disabled

        ##  Disable the Design pulldown menu
        $xAIF::GUI::Widgets(designmenu) entryconfigure 0 -state disabled
        $xAIF::GUI::Widgets(designmenu) entryconfigure 1 -state disabled
        $xAIF::GUI::Widgets(designmenu) entryconfigure 2 -state disabled
        $xAIF::GUI::Widgets(designmenu) entryconfigure 3 -state disabled
        $xAIF::GUI::Widgets(designmenu) entryconfigure 5 -state disabled

        ##  Disable the GUI based on mode
        set dbf $xAIF::GUI::Widgets(dashboard).frame
        $dbf.design.e configure -state disabled
        $dbf.design.b configure -state disabled
        $dbf.library.le configure -state normal
        $dbf.library.lb configure -state normal
        $dbf.library.ce configure -state normal
        $dbf.library.cb configure -state normal
        $dbf.library.pe configure -state normal
        $dbf.library.pb configure -state normal

        ##  If "Connect Mode" is on, go get the active library and populate the Dashboard

        if { $xAIF::Settings(appConnect) } {
            ##  Invoke Xpedition on the design so the Cell Editor can be started
            ##  Catch any exceptions raised by opening the database
            set errorCode [catch { xLM::OpenLibraryManager } errorMessage]
            if {$errorCode != 0} {
                xAIF::GUI::Message -severity error -msg "Unable to connect to Library Manager, is Library Manager running?"
                xAIF::GUI::StatusBar::UpdateStatus -busy off
            } else {
                set xAIF::Settings(LibraryPath)  [$xAIF::Settings(libLib) FullName]
            }
        }

        set xAIF::Settings(TargetPath) xAIF::Settings(LibraryPath)
        xAIF::GUI::Message -severity note -msg "Central Library Mode enabled."
        xAIF::GUI::StatusBar::UpdateStatus -busy off
    }

    ##
    ##  xAIF::GUI::Menus::DesignMode
    ##
    proc DesignMode {} {
        $xAIF::GUI::Widgets(setupmenu) entryconfigure  3 -state normal
        $xAIF::GUI::Widgets(setupmenu) entryconfigure 4 -state disabled
        #$xAIF::GUI::Widgets(setupmenu) entryconfigure 7 -state normal

        ##  Enable the Design pulldown menu
        $xAIF::GUI::Widgets(designmenu) entryconfigure 0 -state normal
        $xAIF::GUI::Widgets(designmenu) entryconfigure 1 -state normal
        $xAIF::GUI::Widgets(designmenu) entryconfigure 2 -state normal
        $xAIF::GUI::Widgets(designmenu) entryconfigure 3 -state normal
        $xAIF::GUI::Widgets(designmenu) entryconfigure 5 -state normal

        ##  Disable the GUI based on mode
        set dbf $xAIF::GUI::Widgets(dashboard).frame
        $dbf.design.e configure -state normal
        $dbf.design.b configure -state normal
        $dbf.library.le configure -state disabled
        $dbf.library.lb configure -state disabled
        $dbf.library.ce configure -state disabled
        $dbf.library.cb configure -state disabled
        $dbf.library.pe configure -state disabled
        $dbf.library.pb configure -state disabled

        ##  If "Connect Mode" is on, go get the active design and populate the Dashboard

        if { $xAIF::Settings(appConnect) } {
            ##  Invoke Xpedition on the design so the Cell Editor can be started
            ##  Catch any exceptions raised by opening the database
            set errorCode [catch { MGC::OpenXpedition } errorMessage]
            if {$errorCode != 0} {
                xAIF::GUI::Message -severity error -msg [format "API error \"%s\", build aborted." $errorMessage]
                xAIF::GUI::Message -severity error -msg "Unable to connect to Xpedition, is Xpedition running?"
                xAIF::GUI::StatusBar::UpdateStatus -busy off
            } else {
                set xPCB::Settings(DesignPath)  [$xPCB::Settings(pcbDoc) FullName]
            }
        }

        set xAIF::Settings(TargetPath) xAIF::Settings(DesignPath)
        xAIF::GUI::Message -severity note -msg "Design Mode enabled."
        xAIF::GUI::StatusBar::UpdateStatus -busy off
    }

    ##
    ##  xAIF::GUI::Menus::BondWireEditMode
    ##
    proc BondWireEditMode {} {
        $xAIF::GUI::Widgets(setupmenu) entryconfigure  3 -state normal
        $xAIF::GUI::Widgets(setupmenu) entryconfigure 4 -state disabled
        $xAIF::GUI::Widgets(setupmenu) entryconfigure 7 -state normal
        #set xAIF::Settings(TargetPath) $xAIF::Const::XAIF_NOTHING
        xAIF::GUI::StatusBar::UpdateStatus -busy off
    }
}

##
##  Define the xAIF::GUI::Dashboard namespace and procedure supporting operations
##
namespace eval xAIF::GUI::Dashboard {
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
    ##  xAIF::GUI::Dashboard::SelectAIF
    ##
    proc SelectAIF { { f "" } } {
        if { [string equal $f ""] } {
            set xAIF::GUI::Dashboard::AIFFile [tk_getOpenFile -filetypes {{AIF .aif} {Txt .txt} {All *}}]
        } else {
            set xAIF::GUI::Dashboard::AIFFile $f
        }

        if { [string equal $xAIF::GUI::Dashboard::AIFFile ""] } {
            xAIF::GUI::Message -severity error -msg "No AIF File selected."
        } else {
            xAIF::GUI::File::OpenAIF $xAIF::GUI::Dashboard::AIFFile
        }
    }

    ##
    ##  xAIF::GUI::Dashboard::SelectCentralLibrary
    ##
    proc SelectCentralLibrary { { f "" } } {
#puts "xAIF::GUI::Dashboard::SelectCentralLibrary"
        set db $xAIF::GUI::Widgets(dashboard)

        if { [string equal $f ""] } {
            set xAIF::Settings(LibraryPath) [tk_getOpenFile -filetypes {{LMC .lmc} { LLM .llm}}]
        } else {
            set xAIF::Settings(LibraryPath) $f
        }

        ##  Valid LMC selected?  If so, enable the buttons and load the partitions
        if { [string length $xAIF::Settings(LibraryPath)] > 0 } {
            #$db.frame.library.cb configure -state normal
            #$db.frame.library.pb configure -state normal

            ##  Open the LMC and get the partition names
            MGC::SetupLMC $xAIF::Settings(LibraryPath)
        }
    }

    ##
    ##  xAIF::GUI::Dashboard::SelectCellPartition
    ##
    proc SelectCellPartition {} {
        set xAIF::GUI::Dashboard::CellPartition \
            [AIFForms::ListBox::SelectOneFromList "Select Target Cell Partition" $xPCB::Settings(cellEdtrPrtnNames)]

        if { [string equal $xAIF::GUI::Dashboard::CellPartition ""] } {
            xAIF::GUI::Message -severity error -msg "No Cell Partition selected."
        } else {
            set xAIF::GUI::Dashboard::CellPartition [lindex $xAIF::GUI::Dashboard::CellPartition 1]
        }
    }

    ##
    ##  xAIF::GUI::Dashboard::SelectPartPartition
    ##
    proc SelectPartPartition {} {
        set xAIF::GUI::Dashboard::PartPartition \
            [AIFForms::ListBox::SelectOneFromList "Select Target Part Partition" $xPCB::Settings(partEdtrPrtnNames)]

        if { [string equal $xAIF::GUI::Dashboard::PartPartition ""] } {
            xAIF::GUI::Message -severity error -msg "No Part Partition selected."
        } else {
            set xAIF::GUI::Dashboard::PartPartition [lindex $xAIF::GUI::Dashboard::PartPartition 1]
        }
    }

    ##
    ##  xAIF::GUI::Dashboard::SetApplicationVisibility
    ##
    proc SetApplicationVisibility {} {
        set xAIF::Settings(appVisible) [expr [string is true $xAIF::Settings(appVisible)] ? on : off]
    }
}

##
##  Define the xAIF::GUI::Dashboard namespace and procedure supporting operations
##
namespace eval xAIF::GUI::View {
    variable zoomArea

    ##--------------------------------------------------------
    ##
    ##  xAIF::GUI::View::ZoomMark
    ##
    ##  Mark the first (x,y) coordinate for zooming.
    ##
    ##--------------------------------------------------------
    proc ZoomMark {c x y} {
        variable zoomArea
        set zoomArea(x0) [$c canvasx $x]
        set zoomArea(y0) [$c canvasy $y]
        $c create rectangle $x $y $x $y -outline white -tag zoomArea
        #puts "zoomMark:  $x $y"
    }

    ##--------------------------------------------------------
    ##
    ##  zoomStroke
    ##
    ##  Zoom in to the area selected by itemMark and
    ##  itemStroke.
    ##
    ##--------------------------------------------------------
    proc ZoomStroke {c x y} {
        variable zoomArea
        set zoomArea(x1) [$c canvasx $x]
        set zoomArea(y1) [$c canvasy $y]
        $c coords zoomArea $zoomArea(x0) $zoomArea(y0) $zoomArea(x1) $zoomArea(y1)
        #puts "zoomStroke:  $x $y"
    }

    ##--------------------------------------------------------
    ##
    ##  zoomArea
    ##
    ##  Zoom in to the area selected by itemMark and
    ##  itemStroke.
    ##
    ##--------------------------------------------------------
    proc ZoomArea {c x y} {
        variable zoomArea

        ##--------------------------------------------------------
        ##  Get the final coordinates.
        ##  Remove area selection rectangle
        ##--------------------------------------------------------
        set zoomArea(x1) [$c canvasx $x]
        set zoomArea(y1) [$c canvasy $y]
        $c delete zoomArea

        ##--------------------------------------------------------
        ##  Check for zero-size area
        ##--------------------------------------------------------
        if {($zoomArea(x0)==$zoomArea(x1)) || ($zoomArea(y0)==$zoomArea(y1))} {
            return
        }

        ##--------------------------------------------------------
        ##  Determine size and center of selected area
        ##--------------------------------------------------------
        set areaxlength [expr {abs($zoomArea(x1)-$zoomArea(x0))}]
        set areaylength [expr {abs($zoomArea(y1)-$zoomArea(y0))}]
        set xcenter [expr {($zoomArea(x0)+$zoomArea(x1))/2.0}]
        set ycenter [expr {($zoomArea(y0)+$zoomArea(y1))/2.0}]

        ##--------------------------------------------------------
        ##  Determine size of current window view
        ##  Note that canvas scaling always changes the coordinates
        ##  into pixel coordinates, so the size of the current
        ##  viewport is always the canvas size in pixels.
        ##  Since the canvas may have been resized, ask the
        ##  window manager for the canvas dimensions.
        ##--------------------------------------------------------
        set winxlength [winfo width $c]
        set winylength [winfo height $c]

        ##--------------------------------------------------------
        ##  Calculate scale factors, and choose smaller
        ##--------------------------------------------------------
        set xscale [expr {$winxlength/$areaxlength}]
        set yscale [expr {$winylength/$areaylength}]
        if { $xscale > $yscale } {
            set factor $yscale
        } else {
            set factor $xscale
        }

        ##--------------------------------------------------------
        ##  Perform zoom operation
        ##--------------------------------------------------------
        xAIF::GUI::View::Zoom $c $factor $xcenter $ycenter $winxlength $winylength
        #puts "zoomArea:  $x $y"
    }


    ##--------------------------------------------------------
    ##
    ##  xAIF::GUI::View::Zoom
    ##
    ##  Zoom the canvas view, based on scale factor 
    ##  and centerpoint and size of new viewport.  
    ##  If the center point is not provided, zoom 
    ##  in/out on the current window center point.
    ##
    ##  This procedure uses the canvas scale function to
    ##  change coordinates of all objects in the canvas.
    ##
    ##--------------------------------------------------------
    proc Zoom { canvas factor \
            {xcenter ""} {ycenter ""} \
            {winxlength ""} {winylength ""} } {

        ##  Do nothing if the canvas is empty
        if { [string equal "" [$canvas bbox all]] } { return }

        ##--------------------------------------------------------
        ##  If (xcenter,ycenter) were not supplied,
        ##  get the canvas coordinates of the center
        ##  of the current view.  Note that canvas
        ##  size may have changed, so ask the window 
        ##  manager for its size
        ##--------------------------------------------------------
        set winxlength [winfo width $canvas]; # Always calculate [ljl]
        set winylength [winfo height $canvas]
        if { [string equal $xcenter ""] } {
            set xcenter [$canvas canvasx [expr {$winxlength/2.0}]]
            set ycenter [$canvas canvasy [expr {$winylength/2.0}]]
        }

        ##--------------------------------------------------------
        ##  Scale all objects in the canvas
        ##  Adjust our viewport center point
        ##--------------------------------------------------------
        $canvas scale all 0 0 $factor $factor
        set xcenter [expr {$xcenter * $factor}]
        set ycenter [expr {$ycenter * $factor}]

        ##--------------------------------------------------------
        ##  Get the size of all the items on the canvas.
        ##
        ##  This is *really easy* using 
        ##      $canvas bbox all
        ##  but it is also wrong.  Non-scalable canvas
        ##  items like text and windows now have a different
        ##  relative size when compared to all the lines and
        ##  rectangles that were uniformly scaled with the 
        ##  [$canvas scale] command.  
        ##
        ##  It would be better to tag all scalable items,
        ##  and make a single call to [bbox].
        ##  Instead, we iterate through all canvas items and
        ##  their coordinates to compute our own bbox.
        ##--------------------------------------------------------
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

        ##--------------------------------------------------------
        ##  Now figure the size of the bounding box
        ##--------------------------------------------------------
        set xlength [expr {$x1-$x0}]
        set ylength [expr {$y1-$y0}]

        ##--------------------------------------------------------
        ##  But ... if we set the scrollregion and xview/yview 
        ##  based on only the scalable items, then it is not 
        ##  possible to zoom in on one of the non-scalable items
        ##  that is outside of the boundary of the scalable items.
        ##
        ##  So expand the [bbox] of scaled items until it is
        ##  larger than [bbox all], but do so uniformly.
        ##--------------------------------------------------------
        foreach {ax0 ay0 ax1 ay1} [$canvas bbox all] {break}

        while { ($ax0<$x0) || ($ay0<$y0) || ($ax1>$x1) || ($ay1>$y1) } {
            ## triple the scalable area size
            set x0 [expr {$x0-$xlength}]
            set x1 [expr {$x1+$xlength}]
            set y0 [expr {$y0-$ylength}]
            set y1 [expr {$y1+$ylength}]
            set xlength [expr {$xlength*3.0}]
            set ylength [expr {$ylength*3.0}]
        }

        ##--------------------------------------------------------
        ##  Now that we've finally got a region defined with
        ##  the proper aspect ratio (of only the scalable items)
        ##  but large enough to include all items, we can compute
        ##  the xview/yview fractions and set our new viewport
        ##  correctly.
        ##--------------------------------------------------------
        set newxleft [expr {($xcenter-$x0-($winxlength/2.0))/$xlength}]
        set newytop  [expr {($ycenter-$y0-($winylength/2.0))/$ylength}]
        $canvas configure -scrollregion [list $x0 $y0 $x1 $y1]
        $canvas xview moveto $newxleft 
        $canvas yview moveto $newytop 

        ##--------------------------------------------------------
        ##  Change the scroll region one last time, to fit the
        ##  items on the canvas.
        ##--------------------------------------------------------
        $canvas configure -scrollregion [$canvas bbox all]
    }

    ##--------------------------------------------------------
    ##
    ##  xAIF::GUI::View::ZoomReset
    ##
    ##  Zoom the canvas view, based on scale factor 
    ##  and centerpoint and size of new viewport.  
    ##  If the center point is not provided, zoom 
    ##  in/out on the current window center point.
    ##
    ##  This procedure uses the canvas scale function to
    ##  change coordinates of all objects in the canvas.
    ##
    ##--------------------------------------------------------
    proc ZoomReset { c } {
        set extents [$c bbox all]

        ##  Don't do anything on an empty canvas
        if { [string length $extents] == 0 } { return }

        ##  Compute XY pairs and use to reset the view
        set x1 [lindex $extents 0]
        set y1 [lindex $extents 1]
        set x2 [lindex $extents 2]
        set y2 [lindex $extents 3]
        ZoomMark $c $x1 $y1
        ZoomStroke $c $x2 $y2
        ZoomArea $c $x2 $y2
        Zoom $c 1.00 [expr $x2 - $x1] [expr $y2 - $y1]
    }
}

##
##  Define the xAIF::GUI::File namespace and procedure supporting operations
##
namespace eval xAIF::GUI::File {
    variable SparsePinNames
    variable SparsePinNumbers
    variable SparsePinsFilePath

    ##
    ##  xAIF::GUI::File::Init
    ##
    proc Init { } {

        ##  Database Details
        array set xAIF::database {
            type ""
            version ""
            units "um"
            mcm "FALSE"
        }

        ##  Die Details
        array set xAIF::die {
            name ""
            refdes "U1"
            width 0
            height 0
            center { 0 0 }
            partition ""
        }

        ##  BGA Details
        array set xAIF::bga {
            name ""
            refdes "A1"
            width 0
            height 0
        }

        ##  Store devices in a Tcl list
        array set xAIF::devices {}

        ##  Store mcm die in a Tcl dictionary
        ###set xAIF::mcmdie [dict create]
        array set xAIF::mcmdie {}

        ##  Store pads in a Tcl dictionary
        ###set xAIF::pads [dict create]
        array set xAIF::pads {}
        ###set xAIF::padtypes [dict create]
        array set xAIF::padtypes {}

        ##  Store net names in a Tcl list
        set xAIF::netnames [list]

        ##  Store netlist in a Tcl list
        set xAIF::netlist [list]
        set xAIF::netlines [list]

        ##  Store bondpad connections in a Tcl list
        set xAIF::bondpads [list]
        set xAIF::bondwires [list]
        array set xAIF::bondpadsubst {}
    }

    ##
    ##  GUI::File::ReloadAIF
    ##
    ##  Reload a AIF file, read the contents into the
    ##  Source View and update the appropriate status.
    ##
    ##  Reload essentially closes and reopens the file
    ##  currently open.
    ##
    proc ReloadAIF { } {
        set f $xAIF::GUI::Dashboard::AIFFile
        if { [string length $f] > 0 } {
            xAIF::GUI::Message -severity note -msg "Reloading AIF File:  $f"
            xAIF::GUI::File::CloseAIF
            xAIF::GUI::File::OpenAIF $f
            xAIF::GUI::Message -severity note -msg "Reloaded AIF File:  $f"
        } else {
            xAIF::GUI::Message -severity warning -msg "An AIF File is not currently open."
        }
    }

    ##
    ##  GUI::File::OpenAIF
    ##
    ##  Open a AIF file, read the contents into the
    ##  Source View and update the appropriate status.
    ##
    proc OpenAIF { { f "" } } {
    set zzz 0
        xAIF::GUI::StatusBar::UpdateStatus -busy on
        #InitialState

        ##  Set up the sections so they can be highlighted in the AIF source

        set sections {}
        set sectionRegExp ""
        foreach i [array names xAIF::sections] {
            lappend sections $xAIF::sections($i)
            #puts $xAIF::sections($i)
            set sectionRegExp [format "%s%s%s%s%s%s%s" $sectionRegExp \
                [expr {$sectionRegExp == "" ? "(" : "|" }] \
                $xAIF::Const::XAIF_BACKSLASH $xAIF::Const::XAIF_LEFTBRACKET $xAIF::sections($i) $xAIF::Const::XAIF_BACKSLASH $xAIF::Const::XAIF_RIGHTBRACKET ]
        }

        set ignored {}
        set ignoreRegExp ""
        foreach i [array names xAIF::ignored] {
            lappend ignored $xAIF::ignored($i)
            #puts $xAIF::ignored($i)
            set ignoreRegExp [format "%s%s%s%s%s%s%s" $ignoreRegExp \
                [expr {$ignoreRegExp == "" ? "(" : "|" }] \
                $xAIF::Const::XAIF_BACKSLASH $xAIF::Const::XAIF_LEFTBRACKET $xAIF::ignored($i) $xAIF::Const::XAIF_BACKSLASH $xAIF::Const::XAIF_RIGHTBRACKET ]
        }

        set ignoreRegExp [format "%s)" $ignoreRegExp]
        set sectionRegExp [format "%s)" $sectionRegExp]

        ##  Prompt the user for a file if not supplied

        if { $f != $xAIF::Const::XAIF_NOTHING } {
            set xAIF::Settings(filename) $f
        } else {
            set xAIF::Settings(filename) [ xAIF::GUI::Dashboard::SelectAIF]
        }

        ##  Process the user supplied file

        if {$xAIF::Settings(filename) != $xAIF::Const::XAIF_NOTHING } {
            xAIF::GUI::Message -severity note -msg [format "Loading AIF file \"%s\"." $xAIF::Settings(filename)]
            set txt $xAIF::GUI::Widgets(sourceview)
            $txt configure -state normal
            $txt delete 1.0 end

            set f [open $xAIF::Settings(filename)]
            $txt insert end [read $f]
            xAIF::GUI::Message -severity note -msg [format "Scanning AIF file \"%s\" for sections." $xAIF::Settings(filename)]
#puts "Q1"
            ctext::addHighlightClass $txt diesections blue $sections
#puts "Q2"
            ctext::addHighlightClassForRegexp $txt diesections blue $sectionRegExp
#puts "Q3"
            ctext::addHighlightClassForRegexp $txt ignoredsections red $ignoreRegExp
#puts "Q4"
#puts $sections
#puts $sectionRegExp
#puts $ignoreRegExp
            $txt highlight 1.0 end
#puts "Q5"
            $txt configure -state disabled
            close $f
            xAIF::GUI::Message -severity note -msg [format "Loaded AIF file \"%s\"." $xAIF::Settings(filename)]

            ##  Parse AIF file

            AIF::Parse $xAIF::Settings(filename)
            xAIF::GUI::Message -severity note -msg [format "Parsed AIF file \"%s\"." $xAIF::Settings(filename)]

            ##  Load the DATABASE section ...

            if { [ AIF::Database::Section ] == -1 } {
                xAIF::GUI::StatusBar::UpdateStatus -busy off
                return -1
            }

            ##  If the file a MCM-AIF file?
            if { $xAIF::Settings(MCMAIF) == 1 } {
                if { [ AIF::MCMDie::Section ] == -1 } {
                    xAIF::GUI::StatusBar::UpdateStatus -busy off
                    return -1
                }
            }

            ##  Load the DIE section ...

            if { [ AIF::Die::Section ] == -1 } {
                xAIF::GUI::StatusBar::UpdateStatus -busy off
                return -1
            }

            ##  Load the optional BGA section ...

            if { $xAIF::Settings(BGA) == 1 } {
                if { [ AIF::BGA::Section ] == -1 } {
                    xAIF::GUI::StatusBar::UpdateStatus -busy off
                    return -1
                }
            }

            ##  Load the PADS section ...

            if { [ AIF::Pads::Section ] == -1 } {
                xAIF::GUI::StatusBar::UpdateStatus -busy off
                return -1
            }

            ##  Load the NETLIST section ...

            if { [ AIF::Netlist::Section ] == -1 } {
                xAIF::GUI::StatusBar::UpdateStatus -busy off
                return -1
            }

            ##  Draw the Graphic View

            xAIF::GUI::Draw::BuildDesign
        } else {
            xAIF::GUI::Message -severity warning -msg "No AIF file selected."
        }

        xAIF::GUI::StatusBar::UpdateStatus -busy off
    }

    ##
    ##  xAIF::GUI::File::CloseAIF
    ##
    ##  Close the AIF file and flush anything stored in
    ##  xAIF memory.  Clear the text widget for the source
    ##  view and the canvas widget for the graphic view.
    ##
    proc CloseAIF {} {
        xAIF::GUI::StatusBar::UpdateStatus -busy on
        InitialState
        xAIF::GUI::StatusBar::UpdateStatus -busy off

        if { [string length $xAIF::Settings(filename)] > 0 } {
            xAIF::GUI::Message -severity note -msg [format "AIF file \"%s\" closed." $xAIF::Settings(filename)]
        } else {
            xAIF::GUI::Message -severity warning -msg "An AIF file is not currently open, close ignored."
        }
    }

    ##
    ##  xAIF::GUI::File::InitialState
    ##
    proc InitialState {} {

        ##  Put everything back into an initial state
        xAIF::GUI::File::Init
        set xAIF::Settings(filename) $xAIF::Const::XAIF_NOTHING

        ##  Remove all content from the AIF source view
        set txt $xAIF::GUI::Widgets(sourceview)
        $txt configure -state normal
        $txt delete 1.0 end
        $txt configure -state disabled

        ##  Remove all content from the (hidden) netlist text view
        set txt $xAIF::GUI::Widgets(netlistview)
        $txt configure -state normal
        $txt delete 1.0 end
        $txt configure -state disabled

        ##  Remove all content from the keyin netlist text view
        set txt $xAIF::GUI::Widgets(kynnetlistview)
        $txt configure -state normal
        $txt delete 1.0 end
        $txt configure -state disabled

        ##  Remove all content from the source graphic view
        set cnvs $xAIF::GUI::Widgets(layoutview)
        $cnvs delete all

        ##  Remove all content from the AIF Netlist table
        set nlt $xAIF::GUI::Widgets(netlisttable)
        $nlt delete 0 end

        ##  Clean up menus, remove dynamic content
        set m [$xAIF::GUI::Widgets(mainframe) getmenu devicesmenu]
        $m delete 3 end
        set m [$xAIF::GUI::Widgets(mainframe) getmenu padsmenu]
        $m delete 3 end
        set m [$xAIF::GUI::Widgets(mainframe) getmenu padgenerationmenu]
        $m delete 0 end
    }


    ##
    ##  xAIF::GUI::File::OpenSparsePins
    ##
    ##  Open a Text file, read the contents into the
    ##  Source View and update the appropriate status.
    ##
    proc OpenSparsePins {} {
        variable SparsePinNames
        variable SparsePinNumbers
        variable SparsePinsFilePath
        xAIF::GUI::StatusBar::UpdateStatus -busy on

        ##  Prompt the user for a file
        ##set xAIF::Settings(sparsepinsfile) [tk_getOpenFile -filetypes {{TXT .txt} {CSV .csv} {All *}}]
        set SparsePinsFilePath [tk_getOpenFile -filetypes {{TXT .txt} {All *}}]

        ##  Process the user supplied file
        if {[string equal "" SparsePinsFilePath]} {
            xAIF::GUI::Message -severity warning -msg "No Sparse Pins file selected."
        } else {
            xAIF::GUI::Message -severity note -msg [format "Loading Sparse Pins file \"%s\"." $xAIF::Settings(sparsepinsfile)]
            set txt $xAIF::GUI::Widgets(sparsepinsview)
            $txt configure -state normal
            $txt delete 1.0 end

            set f [open $xAIF::Settings(sparsepinsfile)]
            $txt insert end [read $f]
            xAIF::GUI::Message -severity note -msg [format "Scanning Sparse List \"%s\" for pin numbers." $xAIF::Settings(sparsepinsfile)]
            ctext::addHighlightClassForRegexp $txt sparsepinlist blue {[\t ]*[0-9][0-9]*[\t ]*$}
            $txt highlight 1.0 end
            $txt configure -state disabled
            close $f
            xAIF::GUI::Message -severity note -msg [format "Loaded Sparse Pins file \"%s\"." $xAIF::Settings(sparsepinsfile)]
            xAIF::GUI::Message -severity note -msg [format "Extracting Pin Numbers from Sparse Pins file \"%s\"." $xAIF::Settings(sparsepinsfile)]

            set pins [split $xAIF::GUI::Widgets(sparsepinsview) \n]
            set txt $xAIF::GUI::Widgets(sparsepinsview)
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
                    xAIF::GUI::Message -severity warning -msg [format "Skipping line %s, incorrect number of fields." $lc]
                } else {
                    xAIF::GUI::Message -severity note -msg [format "Found Sparse Pin Number:  \"%s\" on line %s" [lindex $pindata 1] $lc]
                    lappend xAIF::Settings(sparsepinnames) [lindex $pindata 1]
                    lappend xAIF::Settings(sparsepinnumbers) [lindex $pindata 1]
                    ##if { [incr lc] > 100 } { break }
                }

                incr lc
            }
        }

        ## Force the scroll to the top of the sparse pins view
        $txt yview moveto 0
        $txt xview moveto 0

        xAIF::GUI::StatusBar::UpdateStatus -busy off
    }

    ##
    ##  xAIF::GUI::File::CloseSparsePins
    ##
    ##  Close the sparse rules file and flush anything stored
    ##  in xAIF memory.  Clear the text widget for the sparse
    ##  rules.
    ##
    proc CloseSparsePins {} {
        variable SparsePinsFilePath
        xAIF::GUI::StatusBar::UpdateStatus -busy on
        xAIF::GUI::Message -severity note -msg [format "Sparse Pins file \"%s\" closed." $xAIF::Settings(sparsepinsfile)]
        set SparsePinsFilePath $xAIF::Const::XAIF_NOTHING
        set txt $xAIF::GUI::Widgets(sparsepinsview)
        $txt configure -state normal
        $txt delete 1.0 end
        $txt configure -state disabled
        xAIF::GUI::StatusBar::UpdateStatus -busy off
    }
}

##
##  Define the xAIF::GUI::Draw namespace and procedure supporting operations
##
namespace eval xAIF::GUI::Draw {
    ##
    ##  xAIF::GUI::Draw::BuildDesign
    ##
    proc BuildDesign {} {
        set rv 0
        set line_no 0
        set m [$xAIF::GUI::Widgets(mainframe) getmenu devicesmenu]
        $m add separator

        set cnvs $xAIF::GUI::Widgets(layoutview)
        set txt $xAIF::GUI::Widgets(netlistview)
        set nlt $xAIF::GUI::Widgets(netlisttable)
        set kyn $xAIF::GUI::Widgets(kynnetlistview)

        $cnvs delete all

        ##  Add the outline

        ##  Draw the BGA outline (if it exists)
        if { $xAIF::Settings(BGA) == 1 } {
            xAIF::GUI::Draw::BGAOutline
            set xAIF::devices($xAIF::bga(name)) [list]

            ##  Add BGA to the View Devices menu and make it visible
            set xAIF::GUI::devices($xAIF::bga(name)) on
            $m add checkbutton -label "$xAIF::bga(name)" -underline 0 \
                -variable xAIF::GUI::devices($xAIF::bga(name)) -onvalue on -offvalue off \
                -command  "xAIF::GUI::Draw::Visibility $xAIF::bga(name) -mode toggle"

            $m add separator
        }

        ##  Is this an MCM-AIF?

        if { $xAIF::Settings(MCMAIF) == 1 } {
            foreach i [AIF::MCMDie::GetAllDie] {
                #set section [format "MCM_%s_%s" [string toupper $i] [dict get $xAIF::mcmdie $i]]
                ###set section [format "MCM_%s_%s" [dict get $xAIF::mcmdie $i] $i]
                set section [format "MCM_%s_%s" $xAIF::mcmdie($i) $i]
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

                    ##  Extract each of the expected keywords from the section
                    foreach key [array names part] {
                        if { [lsearch -exact [AIF::Variables $section] $key] != -1 } {
                            set part($key) [AIF::GetVar $key $section]
                        }
                    }

                    ##  Need to handle multiple cell parts 
                    set part(NAME) [format "%s_%s" $part(NAME) $i]

                    ##  Need the REF designator for later

                    set part(REF) $i
                    set xAIF::devices($part(NAME)) [list]

                    ##  Split the CENTER keyword into X and Y components
                    ##
                    ##  The AIF specification and sample file have the X and Y separated by
                    ##  both a space and comma character so we'll plan to handle either situation.
                    if { [llength [split $part(CENTER) ,]] == 2 } {
                        set part(X) [lindex [split $part(CENTER) ,] 0]
                        set part(Y) [lindex [split $part(CENTER) ,] 1]
                    } else {
                        set part(X) [lindex [split $part(CENTER)] 0]
                        set part(Y) [lindex [split $part(CENTER)] 1]
                    }

                    ##  Draw the Part Outline
                    PartOutline $part(REF) $part(HEIGHT) $part(WIDTH) $part(X) $part(Y)

                    ##  Add part to the View Devices menu and make it visible
                    set xAIF::GUI::devices($part(REF)) on
                    $m add checkbutton -label "$part(REF)" -underline 0 \
                        -variable xAIF::GUI::devices($part(REF)) -onvalue on -offvalue off \
                        -command  "xAIF::GUI::Draw::Visibility device-$part(REF) -mode toggle"
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

                ##  Extract each of the expected keywords from the section
                foreach key [array names part] {
                    if { [lsearch -exact [AIF::Variables DIE] $key] != -1 } {
                        set part($key) [AIF::GetVar $key DIE]
                    }
                }

                ##  Need the REF designator for later

                set part(REF) $xAIF::Settings(DIEREF)
                set xAIF::devices($part(NAME)) [list]

                ##  Split the CENTER keyword into X and Y components
                ##
                ##  The AIF specification and sample file have the X and Y separated by
                ##  both a space and comma character so we'll plan to handle either situation.
                if { [llength [split $part(CENTER) ,]] == 2 } {
                    set part(X) [lindex [split $part(CENTER) ,] 0]
                    set part(Y) [lindex [split $part(CENTER) ,] 1]
                } else {
                    set part(X) [lindex [split $part(CENTER)] 0]
                    set part(Y) [lindex [split $part(CENTER)] 1]
                }

                ##  Draw the Part Outline
                PartOutline $part(REF) $part(HEIGHT) $part(WIDTH) $part(X) $part(Y)

                ##  Add part to the View Devices menu and make it visible
                set xAIF::GUI::devices($part(REF)) on
                $m add checkbutton -label "$part(REF)" -underline 0 \
                    -variable xAIF::GUI::devices($part(REF)) -onvalue on -offvalue off \
                    -command  "xAIF::GUI::Draw::Visibility device-$part(REF) -mode toggle"
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

            ##  A simple netlist has 5 fields

            set nlr(NETNAME) [lindex $net 0]
            set nlr(PADNUM) [lindex $net 1]
            set nlr(PADNAME) [lindex $net 2]
            set nlr(PAD_X) [lindex $net 3]
            set nlr(PAD_Y) [lindex $net 4]

            ##  A simple netlist with ball assignment has 6 fields
            if { [llength [split $net]] > 5 } {
                set nlr(BALLNUM) [lindex $net 5]
            }

            ##  A netlist with ball assignments  and locations has 9 fields
            if { [llength [split $net]] > 6 } {
                set nlr(BALLNAME) [lindex $net 6]
                set nlr(BALL_X) [lindex $net 7]
                set nlr(BALL_Y) [lindex $net 8]
            }

            ##  A complex netlist with ball and rings assignments has 14 fields
            if { [llength [split $net]] > 9 } {
                set nlr(FINNUM) [lindex $net 9]
                set nlr(FINNAME) [lindex $net 10]
                set nlr(FIN_X) [lindex $net 11]
                set nlr(FIN_Y) [lindex $net 12]
                set nlr(ANGLE) [lindex $net 13]
            }

            #printArray nlr

            ##  Check the netname and store it for later use
            if { [ regexp {^[[:alpha:][:alnum:]_]*\w} $netname ] == 0 } {
                xAIF::GUI::Message -severity error -msg [format "Net name \"%s\" is not supported AIF syntax." $netname]
                set rv -1
            } else {
                if { [lsearch -exact $xAIF::netlist $netname ] == -1 } {
                    #lappend xAIF::netlist $netname
                    xAIF::GUI::Message -severity note -msg [format "Found net name \"%s\"." $netname]
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
                    ###set name [dict get $xAIF::mcmdie $ref]
                    set name $xAIF::mcmdie($ref)
                } else {
                    set name [AIF::GetVar NAME DIE]
                }

                lappend xAIF::devices($name) [list $nlr(PADNAME) $padnum $nlr(PAD_X) $nlr(PAD_Y)]

                xAIF::GUI::Draw::AddPin $nlr(PAD_X) $nlr(PAD_Y) $nlr(PADNUM) $nlr(NETNAME) $nlr(PADNAME) $line_no "diepad pad pad-$nlr(PADNAME) $ref"
                ###if { ![dict exists $xAIF::padtypes $nlr(PADNAME)] } {
                ###    dict lappend xAIF::padtypes $nlr(PADNAME) "smdpad"
                ###}
                if { [lsearch [array names xAIF::padtypes] $nlr(PADNAME)] == -1 } {
                    set xAIF::padtypes($nlr(PADNAME)) "diepad"
                }
                #set xAIF::padtypes($nlr(PADNAME)) "smdpad"
            } else {
                xAIF::GUI::Message -severity warning -msg [format "Skipping die pad for net \"%s\" on line %d, no pad assignment." $netname, $line_no]
            }

            ##  Can the BALL pad be placed?

            if { $nlr(BALLNAME) != "-" } {
                #puts "---------------------> Ball"

                ##  Record the pad and location in the device list
                lappend xAIF::devices($xAIF::bga(name)) [list $nlr(BALLNAME) $nlr(BALLNUM) $nlr(BALL_X) $nlr(BALL_Y)]
                #puts "---------------------> Ball Middle"

                xAIF::GUI::Draw::AddPin $nlr(BALL_X) $nlr(BALL_Y) $nlr(BALLNUM) $nlr(NETNAME) $nlr(BALLNAME) $line_no "ballpad pad pad-$nlr(BALLNAME)" "white" "red"
                #puts "---------------------> Ball Middle"
                ###if { ![dict exists $xAIF::padtypes $nlr(BALLNAME)] } {
                ###    dict lappend xAIF::padtypes $nlr(BALLNAME) "ballpad"
                ###}
                if { [lsearch [array names xAIF::padtypes] $nlr(BALLNAME)] == -1 } {
                    set xAIF::padtypes($nlr(BALLNAME)) "ballpad"
                }
                set xAIF::padtypes($nlr(BALLNAME)) "ballpad"
                #puts "---------------------> Ball End"
            } else {
                xAIF::GUI::Message -severity warning -msg [format "Skipping ball pad for net \"%s\" on line %d, no ball assignment." $netname, $line_no]
            }

            ##  Can the Finger pad be placed?

            if { $nlr(FINNAME) != "-" } {
                #puts "---------------------> Finger"
                xAIF::GUI::Draw::AddPin $nlr(FIN_X) $nlr(FIN_Y) $nlr(FINNUM) $nlr(NETNAME) \
                    $nlr(FINNAME) $line_no "bondpad pad pad-$nlr(FINNAME)" "purple" "white" $nlr(ANGLE)
                lappend xAIF::bondpads [list $nlr(NETNAME) $nlr(FINNAME) $nlr(FIN_X) $nlr(FIN_Y) $nlr(ANGLE)]
                if { [lsearch [array names xAIF::padtypes] $nlr(FINNAME)] == -1 } {
                    set xAIF::padtypes($nlr(FINNAME)) "bondpad"
                }
                set xAIF::padtypes($nlr(FINNAME)) "bondpad"

                ##  Does this bond pad need a swap to account for bond fingers constructed vertically?
                if { [lsearch [array names xAIF::bondpadsubst] $nlr(FINNAME)] == -1 } {

                    ##  Extract height and width from the PADS section
                    set w [lindex [AIF::GetVar $nlr(FINNAME) PADS] 1]
                    set h [lindex [AIF::GetVar $nlr(FINNAME) PADS] 2]

                    ##  If height > width a bond pad substitution is required so Xpedition will operate correctly

                    if { $h > $w } {
                        set xAIF::bondpadsubst($nlr(FINNAME)) [format "%s_h" $nlr(FINNAME)]
                    }
                }
            } else {
                xAIF::GUI::Message -severity warning -msg \
                    [format "Skipping finger for net \"%s\" on line %d, no finger assignment." $netname, $line_no]
            }

            ##  Need to detect connections - there are two types:
            ##
            ##  1)  Bond Pad connections
            ##  2)  Any other connection (Die to Die,  Die to BGA, etc.)
            ##

            ##  Look for bond wire connections

            if { $nlr(PAD_X) != "-"  && $nlr(PAD_Y) != "-"  && $nlr(FINNAME) != "-" && $nlr(FIN_X) != "-"  && $nlr(FIN_Y) != "-" } {
                lappend xAIF::bondwires [list $nlr(NETNAME) $nlr(PAD_X) $nlr(PAD_Y) $nlr(FIN_X) $nlr(FIN_Y)]
            }

            ##  Look for net line connections (which are different than netlist connections)

            if { $nlr(PAD_X) != "-"  && $nlr(PAD_Y) != "-"  && $nlr(BALL_X) != "-"  && $nlr(BALL_Y) != "-" } {
                lappend xAIF::netlines [list $nlr(NETNAME) $nlr(PAD_X) $nlr(PAD_Y) $nlr(BALL_X) $nlr(BALL_Y)]
            }

            ##  Add any connections to the netlist

            if { $nlr(PADNUM) != "-" && $nlr(PADNAME) != "-" && $nlr(PAD_X) != "-"  && $nlr(PAD_Y) != "-" } {
                if { 1 } {
                    lappend xAIF::netlist [list $nlr(NETNAME) $nlr(PADNUM)]
                } else {
                    lappend xAIF::netlist [list $nlr(NETNAME) [format "%s.%s" $xAIF::Settings(DIEREF) $nlr(PADNUM)]]
                }
            }

    if { 1 } {
            if { $nlr(BALLNUM) != "-" && $nlr(BALLNAME) != "-" && $nlr(BALL_X) != "-"  && $nlr(BALL_Y) != "-" } {
                if { 0 } {
                    lappend xAIF::netlist [list $nlr(NETNAME) [format "%s.%s" $xAIF::bga(refdes) $nlr(BALLNUM)]]
                } else {
                    lappend xAIF::netlist [list $nlr(NETNAME) [format "%s.%s" $xAIF::bga(refdes) $nlr(BALLNUM)]]
                }
            }
    }
        }

        ##  Due to the structure of the AIF file, it is possible to have
        ##  replicated pins in our device list.  Need to roll through them
        ##  and make sure all of the stored lists are unique.

        foreach d [array names xAIF::devices] {
            set xAIF::devices($d) [lsort -unique $xAIF::devices($d)]
        }

        ##  Similarly, bond pads can have more than one connection and may
        ##  appear in the AIF file multiple times.  Need to eliminate any
        ##  duplicates prevent placing bond pads multiple times.

        #puts [format "++++++>  %d" [llength $xAIF::bondpads]]
        set xAIF::bondpads [lsort -unique $xAIF::bondpads]
        #puts [format "++++++>  %d" [llength $xAIF::bondpads]]

        ##  Generate KYN Netlist
        $kyn configure -state normal

        ##  Netlist file header 
        $kyn insert end ";; V4.1.0\n"
        $kyn insert end "%net\n"
        $kyn insert end "%Prior=1\n\n"
        $kyn insert end "%page=0\n"

        ##  Netlist content
        set p ""
        foreach n $xAIF::netlist {
#puts $n
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
            ###$kyn insert end [format "\\%s\\   \\%s\\\n" [dict get $xAIF::mcmdie $i] $i]
            $kyn insert end [format "\\%s\\   \\%s\\\n" $xAIF::mcmdie($i) $i]
        }

        ##  If this AIF file does not contain a MCM_DIE section then
        ##  the DIE will not appear in the part list and needs to be
        ##  added separately.

        if { [lsearch -exact $::AIF::sections MCM_DIE] == -1 } {
            $kyn insert end [format "\\%s\\   \\%s\\\n" $xAIF::die(name) $xAIF::die(refdes)]
        }


        ##  If there is a BGA, make sure to put it in the part list
        #if { $xAIF::Settings(BGA) == 1 } {
        ##    $kyn insert end [format "\\%s\\   \\%s\\\n" $xAIF::bga(name) $xAIF::bga(refdes)]
        #}

        $kyn configure -state disabled

        ##  Draw Bond Wires
        foreach bw $xAIF::bondwires {
            foreach {net x1 y1 x2 y2} $bw {
                #puts [format "Wire (%s) -- X1:  %s  Y1:  %s  X2:  %s  Y2:  %s" $net $x1 $y1 $x2 $y2]
                $cnvs create line $x1 $y1 $x2 $y2 -tags "bondwire bondwire-$net" -fill "orange" -width 1
                set m [$xAIF::GUI::Widgets(mainframe) getmenu bondwiresmenu]

                ##  Add bond wire to the View Bond Wires menu and make it visible
                ##  Because a net can have more than one bond wire, need to ensure
                ##  already hasn't been added or it will result in redundant menus.

                if { [array size xAIF::GUI::bondwires] == 0 || \
                     [lsearch [array names xAIF::GUI::bondwires] $net] == -1 } {
                    set xAIF::GUI::bondwires($net) on
                    $m add checkbutton -label "$net" \
                        -variable xAIF::GUI::bondwires($net) -onvalue on -offvalue off \
                        -command  "xAIF::GUI::Draw::Visibility bondwire-$net -mode toggle"
                }
            }
        }

        ##  Draw Net Lines
        foreach nl $xAIF::netlines {
            foreach {net x1 y1 x2 y2} $nl {
                #puts [format "Net Line (%s) -- X1:  %s  Y1:  %s  X2:  %s  Y2:  %s" $net $x1 $y1 $x2 $y2]
                $cnvs create line $x1 $y1 $x2 $y2 -tags "netline netline-$net" -fill "cyan" -width 1
                set m [$xAIF::GUI::Widgets(mainframe) getmenu netlinesmenu]

                ##  Add bond wire to the View Bond Wires menu and make it visible
                ##  Because a net can have more than one bond wire, need to ensure
                ##  already hasn't been added or it will result in redundant menus.

                if { [array size xAIF::GUI::netlines] == 0 || \
                     [lsearch [array names xAIF::GUI::netlines] $net] == -1 } {
                    set xAIF::GUI::netlines($net) on
                    $m add checkbutton -label "$net" \
                        -variable xAIF::GUI::netlines($net) -onvalue on -offvalue off \
                        -command  "xAIF::GUI::Draw::Visibility netline-$net -mode toggle"
                }
            }
        }

        #$nlt configure -state disabled

        ##  Set an initial scale so the die is visible
        ##  This is an estimate based on trying a couple of
        ##  die files.

        set scaleX [expr ($xAIF::Const::XAIF_WINDOWSIZEX / (2*$xAIF::die(width)) * $xAIF::Const::XAIF_SCALEFACTOR)]
        #puts [format "A:  %s  B:  %s  C:  %s" $scaleX $xAIF::Const::XAIF_WINDOWSIZEX) $xAIF::die(width)]
        if { $scaleX > 0 } {
            #zoom 1 0 0 
            set extents [$cnvs bbox all]
            #puts $extents
            #$cnvs create rectangle $extents -outline green
            #$cnvs create oval \
            ##    [expr [lindex $extents 0]-2] [expr [lindex $extents 1]-2] \
            ##    [expr [lindex $extents 0]+2] [expr [lindex $extents 1]+2] \
            ##    -fill green
            #$cnvs create oval \
            ##    [expr [lindex $extents 2]-2] [expr [lindex $extents 3]-2] \
            ##    [expr [lindex $extents 2]+2] [expr [lindex $extents 3]+2] \
            ##    -fill green
            #zoomMark $cnvs [lindex $extents 2] [lindex $extents 3]
            #zoomStroke $cnvs [lindex $extents 0] [lindex $extents 1]
            #zoomArea $cnvs [lindex $extents 0] [lindex $extents 1]

            ##  Set the initial view
            xAIF::GUI::View::Zoom $cnvs 20
            xAIF::GUI::View::ZoomReset $cnvs
        }

        #destroy $pb

        return $rv
    }

    ##
    ##  xAIF::GUI::Draw::GenKYN
    ##
    proc GenKYN {} {
        set kyn $xAIF::GUI::Widgets(kynnetlistview)
        ##  Generate KYN Netlist
        $kyn configure -state normal
        $kyn delete 1.0 end

        ##  Netlist file header 
        $kyn insert end ";; V4.1.0\n"
        $kyn insert end "%net\n"
        $kyn insert end "%Prior=1\n\n"
        $kyn insert end "%page=0\n"

        #puts $xAIF::netlist
        ##  Netlist content
        set p ""
        foreach n $xAIF::netlist {
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
#puts "${i}::${n}::${p}"
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
            ###$kyn insert end [format "\\%s\\   \\%s\\\n" [dict get $xAIF::mcmdie $i] $i]
            $kyn insert end [format "\\%s\\   \\%s\\\n" $xAIF::mcmdie($i) $i]
        }

        ##  If this AIF file does not contain a MCM_DIE section then
        ##  the DIE will not appear in the part list and needs to be
        ##  added separately.

        if { [lsearch -exact $::AIF::sections MCM_DIE] == -1 } {
            $kyn insert end [format "\\%s\\   \\%s\\\n" $xAIF::die(name) $xAIF::die(refdes)]
        }


        ##  If there is a BGA, make sure to put it in the part list
        #if { $xAIF::Settings(BGA) == 1 } {
        ##    $kyn insert end [format "\\%s\\   \\%s\\\n" $xAIF::bga(name) $xAIF::bga(refdes)]
        #}

        $kyn configure -state disabled
    }

    ##
    ##  xAIF::GUI::Draw::AddPin
    ##
    proc AddPin { x y pin net pad line_no { tags "diepad" } { color "yellow" } { outline "red" } { angle 0 } } {
        set cnvs $xAIF::GUI::Widgets(layoutview)
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

                ##  Add text: Use pin number if it was supplied, otherwise pad name
                $cnvs create text $x $y -text $padtxt -fill $outline \
                    -anchor center -font xAIFCanvasFont -justify center \
                    -tags "text padnumber padnumber-$pin $tags"
            }
            "CIRCLE" -
            "ROUND" {
                set pw [AIF::Pad::GetWidth $pad]
                $cnvs create oval [expr {$x-($pw/2.0)}] [expr {$y-($pw/2.0)}] \
                    [expr {$x + ($pw/2.0)}] [expr {$y + ($pw/2.0)}] -outline $outline \
                    -fill $color -tags "$tags" 

                ##  Add text: Use pin number if it was supplied, otherwise pad name
                $cnvs create text $x $y -text $padtxt -fill $outline \
                    -anchor center -font xAIFCanvasFont -justify center \
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

                ##  Compose the pad - it is four pieces:  Arc, Segment, Arc, Segment

                set padxy {}

                ##  Top arc
                set arc [xAIF::GUI::Draw::ArcPath [expr {$x-($pw/2.0)}] $y1 \
                    [expr {$x + ($pw/2.0)}] [expr {$y1+$pw}] -start 180 -extent 180 -sides 20]
                foreach e $arc { lappend padxy $e }

                ##  Bottom Arc
                set arc [xAIF::GUI::Draw::ArcPath [expr {$x-($pw/2.0)}] \
                    [expr {$y2-$pw}] [expr {$x + ($pw/2.0)}] $y2 -start 0 -extent 180 -sides 20]

                foreach e $arc { lappend padxy $e }

                set id [$cnvs create poly $padxy -outline $outline -fill $color -tags "$tags"]

                ##  Add text: Use pin number if it was supplied, otherwise pad name
                $cnvs create text $x $y -text $padtxt -fill $outline \
                    -anchor center -font xAIFCanvasFont -justify center \
                    -tags "text padnumber padnumber-$pin $tags"

                ##  Handle any angle ajustment

                if { $angle != 0 } {
                    set Ox $x
                    set Oy $y

                    set radians [expr {$angle * atan(1) * 4 / 180.0}] ;# Radians
                    set xy {}
                    foreach {x y} [$cnvs coords $id] {
                        ## rotates vector (Ox,Oy)->(x,y) by angle clockwise

                        ## Shift the object to the origin
                        set x [expr {$x - $Ox}]
                        set y [expr {$y - $Oy}]

                        ##  Rotate the object
                        set xx [expr {$x * cos($radians) - $y * sin($radians)}]
                        set yy [expr {$x * sin($radians) + $y * cos($radians)}]

                        ## Shift the object back to the original XY location
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

                ##  Add text: Use pin number if it was supplied, otherwise pad name
                $cnvs create text $x $y -text $padtxt -fill $outline \
                    -anchor center -font xAIFCanvasFont -justify center \
                    -tags "text padnumber padnumber-$pin $tags"
            }
            "POLY" {
                set polypts {}
                set padxy [AIF::Pad::GetPoints $pad]
                #puts $padxy
                foreach {px py} $padxy {
                    #puts $px
                    #puts $py
                    lappend polypts [expr $px + $x]
                    lappend polypts [expr $py + $y]
                }

                #set id [$cnvs create poly $padxy -outline $outline -fill $color -tags "$tags"]
                set id [$cnvs create poly $polypts -outline $outline -fill $color -tags "$tags"]

                ##  Add text: Use pin number if it was supplied, otherwise pad name
                $cnvs create text $x $y -text $padtxt -fill $outline \
                    -anchor center -font xAIFCanvasFont -justify center \
                    -tags "text padnumber padnumber-$pin $tags"

                ##  Handle any angle ajustment

                if { $angle != 0 } {
                    set Ox $x
                    set Oy $y

                    set radians [expr {$angle * atan(1) * 4 / 180.0}] ;# Radians
                    set xy {}
                    foreach {x y} [$cnvs coords $id] {
                        ## rotates vector (Ox,Oy)->(x,y) by angle clockwise

                        ## Shift the object to the origin
                        set x [expr {$x - $Ox}]
                        set y [expr {$y - $Oy}]

                        ##  Rotate the object
                        set xx [expr {$x * cos($radians) - $y * sin($radians)}]
                        set yy [expr {$x * sin($radians) + $y * cos($radians)}]

                        ## Shift the object back to the original XY location
                        set xx [expr {$xx + $Ox}]
                        set yy [expr {$yy + $Oy}]

                        lappend xy $xx $yy
                    }
                    $cnvs coords $id $xy
                }

            }
            default {
                #error "Error parsing $filename (line: $line_no): $line"
                xAIF::GUI::Message -severity warning -msg [format "Skipping line %d in AIF file \"%s\"." $line_no $xAIF::Settings(filename)]
                #puts $line
            }
        }

        #$cnvs scale "pads" 0 0 100 100

        $cnvs configure -scrollregion [$cnvs bbox all]
    }

    ##
    ##  xAIF::GUI::Draw::AddOutline
    ##
    proc AddOutline {} {
        set x2 [expr ($xAIF::die(width) / 2) * $xAIF::Const::XAIF_SCALEFACTOR]
        set x1 [expr (-1 * $x2) * $xAIF::Const::XAIF_SCALEFACTOR]
        set y2 [expr ($xAIF::die(height) / 2) * $xAIF::Const::XAIF_SCALEFACTOR]
        set y1 [expr (-1 * $y2) * $xAIF::Const::XAIF_SCALEFACTOR]

        set cnvs $xAIF::GUI::Widgets(layoutcview)
        $cnvs create rectangle $x1 $y1 $x2 $y2 -outline blue -tags "outline"

        #puts [format "Outline extents:  X1:  %s  Y1:  %s  X2:  %s  Y2:  %s" $x1 $y1 $x2 $y2]:w

        $cnvs configure -scrollregion [$cnvs bbox all]
    }

    ##
    ##  xAIF::GUI::Draw::PartOutline
    ##
    proc PartOutline { name height width x y { color "green" } { tags "partoutline" } } {
        #puts [format "Part Outline input:  Name:  %s H:  %s  W:  %s  X:  %s  Y:  %s  C:  %s" $name $height $width $x $y $color]

        set x1 [expr $x-($width/2.0)]
        set x2 [expr $x+($width/2.0)]
        set y1 [expr $y-($height/2.0)]
        set y2 [expr $y+($height/2.0)]

        set cnvs $xAIF::GUI::Widgets(layoutview)
        $cnvs create rectangle $x1 $y1 $x2 $y2 -outline $color -tags "device device-$name $tags"
        $cnvs create text $x2 $y2 -text $name -fill $color \
            -anchor sw -font xAIFCanvasFont -justify right -tags "text device device-$name refdes refdes-$name"

        #puts [format "Part Outline extents:  X1:  %s  Y1:  %s  X2:  %s  Y2:  %s" $x1 $y1 $x2 $y2]

        $cnvs configure -scrollregion [$cnvs bbox all]
    }

    ##
    ##  xAIF::GUI::Draw::BGAOutline
    ##
    proc BGAOutline { { color "white" } } {
        set cnvs $xAIF::GUI::Widgets(layoutview)

        set x1 [expr -($xAIF::bga(width) / 2)]
        set x2 [expr +($xAIF::bga(width) / 2)]
        set y1 [expr -($xAIF::bga(height) / 2)]
        set y2 [expr +($xAIF::bga(height) / 2)]

        xAIF::GUI::Message -severity note -msg \
            [format "BGA Outline extents:  X1:  %s  Y1:  %s  X2:  %s  Y2:  %s" $x1 $y1 $x2 $y2]

        ##  Does BGA section contain POLYGON outline?  If not, use the height and width
        if { [lsearch -exact [AIF::Variables BGA] OUTLINE] != -1 } {
            set poly [split [AIF::GetVar OUTLINE BGA]]
            set pw [lindex $poly 2]
            #puts $poly
            if { [lindex $poly 1] == 1 } {
                set points [lreplace $poly  0 3 ]
                #puts $points 
            } else {
                xAIF::GUI::Message -severity warning -msg "Only one polygon supported for BGA outline, reverting to derived outline."
                set x1 [expr -($xAIF::bga(width) / 2)]
                set x2 [expr +($xAIF::bga(width) / 2)]
                set y1 [expr -($xAIF::bga(height) / 2)]
                set y2 [expr +($xAIF::bga(height) / 2)]

                #set points { $x1 $y1 $x2 $y2 }
                set points [list $x1 $y1 $x2 $y1 $x2 $y2 $x1 $y2]
            }


        } else {
            #set points { $x1 $y1 $x2 $y2 }
            #set points [list $x1 $y1 $x2 $y2]
            set points [list $x1 $y1 $x2 $y1 $x2 $y2 $x1 $y2]
        }

        $cnvs create polygon $points -outline $color -tags "$xAIF::bga(name) bga bgaoutline"
        $cnvs create text $x2 $y2 -text $xAIF::bga(name) -fill $color \
            -anchor sw -font xAIFCanvasFont -justify right -tags "$xAIF::bga(name) bga text refdes"

        ##  Add some text to note the corner XY coordinates - visual reference only
        $cnvs create text $x1 $y1 -text [format "X: %.2f  Y: %.2f" $x1 $y1] -fill $color \
            -anchor sw -font xAIFCanvasFont -justify left -tags "guides dimension text"
        $cnvs create text $x1 $y2 -text [format "X: %.2f  Y: %.2f" $x1 $y2] -fill $color \
            -anchor nw -font xAIFCanvasFont -justify left -tags "guides dimension text"
        $cnvs create text $x2 $y1 -text [format "X: %.2f  Y: %.2f" $x2 $y1] -fill $color \
            -anchor se -font xAIFCanvasFont -justify left -tags "guides dimension text"
        $cnvs create text $x2 $y2 -text [format "X: %.2f  Y: %.2f" $x2 $y2] -fill $color \
            -anchor ne -font xAIFCanvasFont -justify left -tags "guides dimension text"

        ##  Add cross hairs through the origin - visual reference only
        $cnvs create line [expr $x1 - $xAIF::bga(width) / 4] 0 [expr $x2 +$xAIF::bga(width) / 4] 0 \
            -fill $color -dash . -tags "guides xyaxis"
        $cnvs create line 0 [expr $y1 - $xAIF::bga(height) / 4] 0 [expr $y2 +$xAIF::bga(height) / 4] \
            -fill $color -dash . -tags "guides xyaxis"

        $cnvs configure -scrollregion [$cnvs bbox all]
    }

}

##
##  xAIF::GUI::Draw
##
namespace eval xAIF::GUI::Draw {

    ##
    ##  Visibility
    ##
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

        set cnvs $xAIF::GUI::Widgets(layoutview)

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

    ##
    ##  RotateXY
    ##
    ##  From Ian Gabbitas ...
    ##
    ##    x2 = x * cos(radA) - y * sin(radA)
    ##    y2 = x * sin(radA) + y * cos(radA)
    ##  
    proc RotateXY { x y { angle 0 } } {
        #set radians [expr $angle*(3.14159265/180.0)]
        set radians [expr {$angle * atan(1) * 4 / 180.0}] ;# Radians
        #puts "R:  $radians"
        #puts "A:  $angle"
        set x2 [expr { $x * cos($radians) - $y * sin($radians) }]
        set y2 [expr { $x * sin($radians) + $y * cos($radians) }]
        #puts "====================================="
        #puts ""
        #puts [format "Rotation:  X1:  %s  Y1:  %s  X2:  %s  Y2:  %s  A:  %s" $x $y $x2 $y2 $angle]
        #puts ""
        #puts "====================================="
        return [list $x2 $y2]
    }

    ##
    ##  ArcPath
    ##
    ##  @see http://wiki.tcl.tk/8612
    ##
    ##  
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

        ## Figure out where last segment should end
        if {$numsteps != int($numsteps)} {
            ## Vector V1 is last drawn vertext (x,y) from above
            ## Vector V2 is the edge of the polygon
            set rad2 [expr {($V(-start) - int($numsteps) * $step) * $DEG2RAD}]
            set x2 [expr {$rx*cos($rad2) - $x}]
            set y2 [expr {$ry*sin($rad2) - $y}]

            ## Vector V3 is unit vector in direction we end at
            set rad3 [expr {($V(-start) - $V(-extent)) * $DEG2RAD}]
            set x3 [expr {cos($rad3)}]
            set y3 [expr {sin($rad3)}]

            ## Find where V3 crosses V1+V2 => find j s.t.  V1 + kV2 = jV3
            set j [expr {($x*$y2 - $x2*$y) / ($x3*$y2 - $x2*$y3)}]

            lappend xy [expr {$xm + $j * $x3}] [expr {$ym - $j * $y3}]
        }
        return $xy
    }
}

##
##  Define the xAIF::GUI::Dashboard namespace and procedure supporting operations
##
namespace eval xAIF::GUI::StatusBar {
    ##
    ##  xAIF::GUI::StatusBar::UpdateStatus
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
        #set slf $xAIF::GUI::Widgets(statuslight)
        if { [string is true $V(-busy)] } {
            set xAIF::Settings(status) "Busy ..."
            incr xAIF::Settings(progress) 
            #puts "Progress:  $xAIF::Settings(progress)"
            $xAIF::GUI::Widgets(mainframe).status.prg configure -fg red
            #$slf configure -background red
            #$xAIF::GUI::Widgets(progressbar) start
        } else {
            set xAIF::Settings(status) "Ready"
            #$slf configure -background green
            #$xAIF::GUI::Widgets(progressbar) stop
            $xAIF::GUI::Widgets(mainframe).status.prg configure -fg green
            set xAIF::Settings(progress) 0
        } 

        if { $xAIF::GUI::Dashboard::Mode == $xAIF::Const::XAIF_MODE_DESIGN } {
            set $xAIF::Settings(TargetPath) $xAIF::Settings(DesignPath)
        } else {
            set $xAIF::Settings(TargetPath) $xAIF::Settings(LibraryPath)
        }
        set $xAIF::Settings(TargetPath)
        update idletasks
    }
}

##
##  xAIF::GUI::Help
##
namespace eval xAIF::GUI::Help {
    ##
    ##  xAIF::GUI::Help::About
    ##
    proc About {} {
        tk_messageBox -type ok -icon info -title "About" -message [format "%s\nVersion:  %s\nBuild Date:  %s" \
             $xAIF::Settings(name) $xAIF::Settings(version) $xAIF::Settings(date)]
    }

    ##
    ##  xAIF::GUI::Help::Version
    ##
    proc Version {} {
        tk_messageBox -type ok -message "$xAIF::Settings(name)\nVersion $xAIF::Settings(version)" \
            -icon info -title "Version"
    }

    ##
    ##  xAIF::GUI::Help::EnvVars
    ##
    proc EnvVars {} {
        set env ""
        foreach e { MGC_HOME MGLS_HOME SDD_HOME SDD_PLATFORM } {
            if { [lsearch [array names ::env] $e] == -1 } {
                set env [format "%s\n%s = undefined" $env $e]
                xAIF::GUI::Message -severity note -msg [format "%s = undefined" $e]
            } else {
                set env [format "%s\n%s = %s" $env $e $::env($e)]
                xAIF::GUI::Message -severity note -msg [format "%s = %s" $e $::env($e)]
            }
        }

        tk_messageBox -type ok -message "Environment Variables:$env" \
            -icon info -title "Environment Variables"
    }

    ##
    ##  xAIF::GUI::Help::InternalState
    ##
    proc InternalState {} {
        parray xLM::Settings
        parray xPCB::Settings
        parray xAIF::Settings
    }

    ##
    ##  xAIF::GUI::Help::NotImplemented
    ##
    ##  Stub procedure for GUI development to prevent Tcl and Tk errors.
    ##
    proc NotImplemented {} {
        tk_messageBox -type ok -icon info -message "This operation has not been implemented."
    }
}
