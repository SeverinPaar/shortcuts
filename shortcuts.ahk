#SingleInstance force
#NoEnv
#MaxHotkeysPerInterval, 99999
SendMode Input
SetWorkingDir %A_ScriptDir%

; --- Shortcuts

; numpad , & numpad 0 --- suspend all hotkeys
NumpadDot & Numpad0::
    Suspend, Toggle
return

; numpad 0 --- to retain functionality
Numpad0::Send, 0

; numpad 1
Numpad0 & Numpad1::return

; numpad 2 --- if explorer is active, open folder with code
Numpad0 & Numpad2::
    if WinActive("ahk_class CabinetWClass") {
        Send, {AppsKey} ; open context menu
        Send, i ; select code
        Send, Enter
    }
return

; numpad 3
Numpad0 & Numpad3::return

; numpad 5 --- ocr from clipboard image
Numpad0 & Numpad5::
    RunWait, pythonw.exe "C:\Users\sever\Projects\ocr from clipboard\main.py"
    Send, ^v
return

; numpad 6 --- eject removeable drive
Numpad0 & Numpad6::
    DriveGet, removeable, List, REMOVABLE
    DriveGet, cdrom, List, CDROM
    drives := removeable . cdrom

    Loop, Parse, drives
	{
        Eject(A_LoopField)
    }
return

; numpad 7 --- let window stay on top
Numpad0 & Numpad7::Winset, Alwaysontop,,A

; numpad 8
Numpad0 & Numpad8::return

; numpad 9 --- open/close notification center
Numpad0 & Numpad9::
    If !WinActive("Action Centre")
        Send, #a
    else {
        MouseGetPos mouseX, mouseY	
        MouseClick, left, 300, 1000
        MouseMove mouseX, mouseY
        Sleep, 100
        Send, #a
    }
return

; capslock --- quick alt+tab
CapsLock::
    Send {Alt Down}{Tab}{Alt Up}
    SetCapsLockState, Off
return

; --- SHUTDOWN

; break --- monitor off
Pause::Run, cmd /c nircmd.exe monitor off,,hide

; numpad 0 & break --- hibernate
Numpad0 & Pause::
    Send, {Numpad0 up}{Pause up} ; reset key states
    Run, shutdown /h ; hibernate
    ; DllCall("PowrProf\SetSuspendState", "int", 0, "int", 0, "int", 0) ; Sleep
return

; ctrl & break --- shutdown
^CtrlBreak::Shutdown, 1

; turn monitor off when locking
#L::Run, cmd /c nircmd.exe monitor off,,hide

; --- MEDIA CONTROLS

; mouse forward button & scroll wheel:: volume up/down
XButton2 & WheelUp::volume("up")
XButton2 & WheelDown::volume("down")
XButton2::Send, {XButton2} ; hack to not loose functionality

; --- Helper Functions

; change volume more precisely
volume(change) { ; eg: volume("up") or volume("down")
    ; determine time difference between now and last run to eliminate race conditions
    static startTime := %A_TickCount%
    timeSinceLastRun = %A_TickCount%
    timeSinceLastRun -= %startTime%

    if (timeSinceLastRun > 30) {

        ; get volume and add/substract
        SoundGet, volume
        volume := Round(volume)

        if (change = "up")
            volume++
        else {
            volume--
        }

        Send, {Volume_Up} ; send volume up to show volume slider
        SoundSet, volume

        startTime = %A_TickCount%
    }
}

; eject drives
Eject( DRV ) { ; eg: Eject("D:"), Eject("D")
    ; By SKAN,  http://goo.gl/pUUGRt,  CD:01/Sep/2014 | MD:13/Sep/2014
    Local hMod, hVol, queryEnum, VAR := "", sPHDRV := "", nDID := 0, nVT := 1, nTC := A_TickCount
    Local IOCTL_STORAGE_GET_DEVICE_NUMBER := 0x2D1080, STORAGE_DEVICE_NUMBER, FILE_DEVICE_DISK := 0x00000007

    DriveGet, VAR, Type, % DRV := SubStr( DRV, 1, 1 ) ":"
    If ( VAR = "" )
        Return ( ErrorLevel := -1 ) + 1

    If ( VAR = "CDROM" ) {
        Drive, Eject, %DRV%
        If ( nTC + 1000 > A_Tickcount )
            Drive, Eject, %DRV%, 1
        Return ( ErrorLevel ? 0 : 1 )
    }

    ; Find physical drive number from drive letter.
    hVol := DllCall( "CreateFile", "Str","\\.\" DRV, "Int",0, "Int",0, "Int",0, "Int",3, "Int",0, "Int",0 )

    VarSetcapacity( STORAGE_DEVICE_NUMBER, 12, 0 )
    DllCall( "DeviceIoControl", "Ptr",hVol, "UInt",IOCTL_STORAGE_GET_DEVICE_NUMBER
    , "Int",0, "Int",0, "Ptr",&STORAGE_DEVICE_NUMBER, "Int",12, "PtrP",0, "Ptr",0 )

    DllCall( "CloseHandle", "Ptr",hVol )

    If ( NumGet( STORAGE_DEVICE_NUMBER, "UInt" ) = FILE_DEVICE_DISK )
        sPHDRV := "\\\\.\\PHYSICALDRIVE" NumGet( STORAGE_DEVICE_NUMBER, 4, "UInt" )

    ; Find PNPDeviceID = USBSTOR for given physical drive
    queryEnum := ComObjGet( "winmgmts:" ).ExecQuery( "Select * from Win32_DiskDrive "
    . "where DeviceID='" sPHDRV "' and InterfaceType='USB'" )._NewEnum()
    If not queryEnum[ DRV ]
        Return ( ErrorLevel := -2 ) + 2

    hMod := DllCall( "LoadLibrary", "Str","SetupAPI.dll", "UPtr" )

    ; Locate USBSTOR node and move up to its parent
    DllCall( "SetupAPI\CM_Locate_DevNode", "PtrP",nDID, "Str",DRV.PNPDeviceID, "Int",0 )
    DllCall( "SetupAPI\CM_Get_Parent", "PtrP",nDID, "UInt",nDID, "Int",0 )

    VarSetCapacity( VAR, 520, 0 )
    While % ( nDID and nVT and A_Index < 4 )
        DllCall( "SetupAPI\CM_Request_Device_Eject", "UInt",nDID, "PtrP",nVT, "Str",VAR, "Int",260, "Int",0 )

    DllCall("FreeLibrary", "Ptr",hMod ), DllCall( "SetLastError", "UInt",nVT )

Return ( nVT ? ( ErrorLevel := -3 ) + 3 : 1 )
}
