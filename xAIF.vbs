' vim: set expandtab tabstop=4 shiftwidth=4:
'
'  Automation example to dump a plethora of information from a 
'  Central Library or from a Design database.  The information is
'  extracted by traversing the library partitions for PDBs and Cells.
'
'  (c) November 2016 - Mentor Graphics Corporation
'
'  Mike Walsh - mike_walsh@mentor.com
'
'  Mentor Graphics Corporation
'  1001 Winstead Drive, Suite 380
'  Cary, North Carolina 27513
'
'  This software is NOT officially supported by Mentor Graphics.
'
'  ####################################################################
'  ####################################################################
'  ## The following  software  is  "freeware" which  Mentor Graphics ##
'  ## Corporation  provides as a courtesy  to our users.  "freeware" ##
'  ## is provided  "as is" and  Mentor  Graphics makes no warranties ##
'  ## with  respect  to "freeware",  either  expressed  or  implied, ##
'  ## including any implied warranties of merchantability or fitness ##
'  ## for a particular purpose.                                      ##
'  ####################################################################
'  ####################################################################
'
'  Change Log:
'
'    11/09/2016 - Initial version.
'

Option Explicit

Dim Quote :  Quote = Chr(34)

Dim dllApp : Set dllApp = CreateObject("MGCPCBReleaseEnvironmentLib.MGCPCBReleaseEnvServer")
dllApp.SetEnvironment("") 'Default environment -- no argument

Dim fso : Set fso = CreateObject("Scripting.FileSystemObject")

'  Figure out the path where the script resides
Dim fullpath : fullpath = fso.GetAbsolutePathName(Wscript.ScriptFullName)
Dim objFile : Set objFile = fso.GetFile(fullpath)

'  Decompose the path
Dim sName : sName = objFile.Name
Dim sPath : sPath = objFile.Path
sPath = Left(sPath, Len(sPath) - Len(sName))

'  Build the path to the Tcl script
Dim TclScript : TclScript = sPath & "xAIF.tcl"

'  Figure out SDD_HOME and SDD_PLATFORM
Dim sddPlatform : sddPlatform  = dllApp.sddPlatform
Dim sddHome : sddHome = Split(dllApp.sddHome, "SDD_HOME")

'  Construct the path to Tcl/Tk Wish
Dim i, wish : wish  = ""
Dim mginvoke : mginvoke = ""
Dim mginvokepath : mginvokepath = Array(sddHome(0), "SDD_HOME", "common", sddPlatform, "bin", "mginvoke.exe")
Dim wishpath : wishpath = Array(sddHome(0), "SDD_HOME", "common", sddPlatform, "tclwtcom", "bin", "wish84.exe")

'  Build the Wish Path
For Each i In wishpath
    wish = fso.BuildPath(wish, i)
Next

'  Build the MGInvoke Path
For Each i In mginvokepath
    mginvoke = fso.BuildPath(mginvoke, i)
Next

'  Run Wish using the Tcl script
Dim objShell : Set objShell = WScript.CreateObject ("WScript.shell")
objShell.Run mginvoke & " " & wish & " " & TclScript

Set objShell = Nothing
