; #FUNCTION# ====================================================================================================================
; Name ..........: OpenBlueStacks5
; Description ...:
; Syntax ........: OpenBlueStacks5([$bRestart = False])
; Parameters ....: $bRestart            - [optional] a boolean value. Default is False.
; Return values .: None
; Author ........: xbebenk (2020)
; Modified ......: 
; Remarks .......: This file is part of MyBot, previously known as ClashGameBot. Copyright 2015-2019
;                  MyBot is distributed under the terms of the GNU GPL
; Related .......:
; Link ..........: https://github.com/MyBotRun/MyBot/wiki
; Example .......: No
; ===============================================================================================================================

Func GetBlueStacks5ProgramParameter($bAlternative = False)
	Return DoubleQuote("--instance") & " " & DoubleQuote($g_sAndroidInstance)
EndFunc   ;==>GetBlueStacks2ProgramParameter


Func OpenBlueStacks5($bRestart = False)
	SetLog("Starting BlueStacks and Clash Of Clans", $COLOR_SUCCESS)
	If Not InitAndroid() Then Return False
	; open newer BlueStacks versions 5
	Return _OpenBlueStacks5($bRestart)
EndFunc   ;==>OpenBlueStacksX

Func _OpenBlueStacks5($bRestart = False)

	Local $hTimer, $iCount = 0, $cmdPar
	Local $PID, $ErrorResult, $connected_to, $process_killed

	; always start ADB first to avoid ADB connection problems
	LaunchConsole($g_sAndroidAdbPath, AddSpace($g_sAndroidAdbGlobalOptions) & "start-server", $process_killed)

	;$PID = ShellExecute($__BlueStacks_Path & "HD-RunApp.exe", "-p " & $g_sAndroidGamePackage & " -a " & $g_sAndroidGamePackage & $g_sAndroidGameClass)  ;Start BS and CoC with command line
	;$PID = ShellExecute($__BlueStacks_Path & "HD-Frontend.exe", $g_sAndroidInstance) ;Start BS and CoC with command line
	$cmdPar = GetAndroidProgramParameter()
	$PID = LaunchAndroid($g_sAndroidProgramPath, $cmdPar, $g_sAndroidPath)
	;$ErrorResult = ControlGetHandle("BlueStacks Error", "", "") ; Check for BS error window handle if it opens
	;If $g_bDebugAndroid Then SetDebugLog("$PID= " & $PID & ", $ErrorResult = " & $ErrorResult, $COLOR_DEBUG)
	;If $PID = 0 Or $ErrorResult <> 0 Then ; IF ShellExecute failed or BS opens error window = STOP
	;	SetScreenBlueStacks()
	;	SetError(1, 1, -1)
	;	Return False
	;EndIf

	WinGetAndroidHandle()
	$hTimer = __TimerInit() ; start a timer for tracking BS start up time
	While $g_hAndroidControl = 0
		If _Sleep(3000) Then ExitLoop
		_StatusUpdateTime($hTimer, $g_sAndroidEmulator & " Starting")
		If __TimerDiff($hTimer) > $g_iAndroidLaunchWaitSec * 1000 Then ; if no BS position returned in 4 minutes, BS/PC has major issue so exit
			;xbebenk SetScreenBlueStacks()
			SetLog("Serious error has occurred, please restart PC and try again", $COLOR_ERROR)
			SetLog("BlueStacks refuses to load, waited " & Round(__TimerDiff($hTimer) / 1000, 2) & " seconds", $COLOR_ERROR)
			SetLog("Unable to continue........", $COLOR_WARNING)
			btnstop()
			SetError(1, 1, -1)
			Return False
		EndIf
		WinGetAndroidHandle()
	WEnd

	If $g_hAndroidControl Then
		$connected_to = ConnectAndroidAdb(False, 3000) ; small time-out as ADB connection must be available now

		If WaitForAndroidBootCompleted($g_iAndroidLaunchWaitSec - __TimerDiff($hTimer) / 1000, $hTimer) Then Return
		If Not $g_bRunState Then Return False

		SetLog("BlueStacks Loaded, took " & Round(__TimerDiff($hTimer) / 1000, 2) & " seconds to begin.", $COLOR_SUCCESS)

		Return True

	EndIf

	Return False

EndFunc   ;==>_OpenBlueStacks

Func GetBlueStacks5AdbPath()
	Return GetBlueStacksXAdbPath()
EndFunc   ;==>GetBlueStacks5AdbPath

Func InitBlueStacks5X($bCheckOnly = False, $bAdjustResolution = False, $bLegacyMode = False)
	;Bluestacks5 doesn't have registry tree for engine
	Local $frontend_exe = ["HD-Frontend.exe", "HD-Player.exe"]
	Local $i, $aFiles = [$frontend_exe, "HD-Adb.exe"] ; first element can be $frontend_exe array!
	Local $Values[4][3] = [ _
			["Screen Width", $g_iAndroidClientWidth, $g_iAndroidClientWidth], _
			["Screen Height", $g_iAndroidClientHeight, $g_iAndroidClientHeight], _
			["Window Width", $g_iAndroidWindowWidth, $g_iAndroidWindowWidth], _
			["Window Height", $g_iAndroidWindowHeight, $g_iAndroidWindowHeight] _
			]
	Local $bChanged = False

	$__BlueStacks_Version = RegRead($g_sHKLM & "\SOFTWARE\BlueStacks_nxt\", "Version")
	$__BlueStacks_Path = RegRead($g_sHKLM & "\SOFTWARE\BlueStacks_nxt\", "InstallDir")
	If @error <> 0 Then
		$__BlueStacks_Path = @ProgramFilesDir & "\BlueStacks_nxt\"
		SetError(0, 0, 0)
	EndIf
	$__BlueStacks_Path = StringReplace($__BlueStacks_Path, "\\", "\")

	Local $sPreferredADB = FindPreferredAdbPath()
	If $sPreferredADB Then _ArrayDelete($aFiles, 1)

	For $i = 0 To UBound($aFiles) - 1
		Local $File
		Local $bFileFound = False
		Local $aFiles2 = $aFiles[$i]
		If Not IsArray($aFiles2) Then Local $aFiles2 = [$aFiles[$i]]
		For $j = 0 To UBound($aFiles2) - 1
			$File = $__BlueStacks_Path & $aFiles2[$j]
			$bFileFound = FileExists($File)
			If $bFileFound Then
				; check if $frontend_exe is array, then convert
				If $i = 0 And IsArray($frontend_exe) Then $frontend_exe = $aFiles2[$j]
				ExitLoop
			EndIf
		Next
		If Not $bFileFound Then
			If Not $bCheckOnly Then
				SetLog("Serious error has occurred: Cannot find " & $g_sAndroidEmulator & ":", $COLOR_ERROR)
				SetLog($File, $COLOR_ERROR)
				SetError(1, @extended, False)
			EndIf
			Return False
		EndIf
	Next

	If Not $bCheckOnly Then
		; update global variables
		$g_sAndroidPath = $__BlueStacks_Path
		$g_sAndroidProgramPath = $__BlueStacks_Path & $frontend_exe
		$g_sAndroidAdbPath = $sPreferredADB
		If $g_sAndroidAdbPath = "" Then $g_sAndroidAdbPath = $__BlueStacks_Path & "HD-Adb.exe"
		$g_sAndroidVersion = $__BlueStacks_Version

		ConfigureSharedFolderBlueStacks5() ; something like D:\ProgramData\BlueStacks\Engine\UserData\SharedFolder\
		WinGetAndroidHandle()
	EndIf
	Return True
EndFunc   ;==>InitBlueStacks5

Func ConfigureSharedFolderBlueStacks5($iMode = 0, $bSetLog = Default)
	If $bSetLog = Default Then $bSetLog = True
	Local $bResult = False

	Switch $iMode
		Case 0 ; check that shared folder is configured in VM
			For $i = 0 To 5
				If FileExists("C:\ProgramData\BlueStacks_nxt\Engine\UserData\SharedFolder") Then
					$bResult = True
					$g_bAndroidSharedFolderAvailable = True
					$g_sAndroidPicturesPath = "/storage/sdcard/windows/BstSharedFolder/"
					$g_sAndroidPicturesHostPath = "C:\ProgramData\BlueStacks_nxt\Engine\UserData\SharedFolder\"
					ExitLoop
				EndIf
			Next
		Case 1 ; create missing shared folder
		Case 2 ; Configure VM and add missing shared folder
	EndSwitch

	Return SetError(0, 0, $bResult)

EndFunc   ;==>ConfigureSharedFolderBlueStacks5

Func InitBlueStacks5($bCheckOnly = False)
	Local $bInstalled = InitBlueStacks5X($bCheckOnly, True)
	If $bInstalled And StringInStr($__BlueStacks_Version, "5.") <> 1 Then
		If Not $bCheckOnly Then
			SetLog("BlueStacks 5 supported version 5.x not found", $COLOR_ERROR)
			SetError(1, @extended, False)
		EndIf
		Return False
	EndIf

	If $bInstalled And Not $bCheckOnly Then
		$__VBoxManage_Path = $__BlueStacks_Path & "BstkVMMgr.exe"
		Local $bsNow = GetVersionNormalized($__BlueStacks_Version)
		If $bsNow > GetVersionNormalized("5.0") Then
			; only Version 4 requires new options
			;$g_sAndroidAdbInstanceShellOptions = " -t -t" ; Additional shell options, only used by BlueStacks2 " -t -t"
			$g_sAndroidAdbShellOptions = " /data/anr/../../system/xbin/bstk/su root" ; Additional shell options when launch shell with command, only used by BlueStacks2 " /data/anr/../../system/xbin/bstk/su root"

			; tcp forward not working in BS4
			$g_iAndroidAdbMinitouchMode = 1
		EndIf

		CheckBlueStacksVersionMod()

		; read ADB port
		Local $BstAdbPort = RegRead($g_sHKLM & "\SOFTWARE\BlueStacks_nxt\Guests\" & $g_sAndroidInstance & "\Config\", "BstAdbPort")
		If $BstAdbPort Then
			$g_sAndroidAdbDevice = "127.0.0.1:" & $BstAdbPort
		Else
			; use default
			$g_sAndroidAdbDevice = $g_avAndroidAppConfig[$__BS5_Idx][10]
		EndIf
	EndIf

	Return $bInstalled
EndFunc   ;==>InitBlueStacks2

Func GetBlueStacks5BackgroundMode()
	; Only DirectX-Mode is supported for Background Mode
	Return $g_iAndroidBackgroundModeDirectX
EndFunc   ;==>GetBlueStacksBackgroundMode

;Func GetBlueStacks2BackgroundMode()
;	; check if BlueStacks 2 is running in OpenGL mode
;	Local $GlRenderMode = RegRead($g_sHKLM & "\SOFTWARE\BlueStacks\Guests\" & $g_sAndroidInstance & "\Config\", "GlRenderMode")
;	Switch $GlRenderMode
;		Case 4
;			; DirectX
;			Return $g_iAndroidBackgroundModeDirectX
;		Case 1
;			; OpenGL
;			Return $g_iAndroidBackgroundModeOpenGL
;		Case Else
;			SetLog($g_sAndroidEmulator & " unsupported render mode " & $GlRenderMode, $COLOR_WARNING)
;			Return 0
;	EndSwitch
;EndFunc   ;==>GetBlueStacks2BackgroundMode

Func RestartBlueStacks5CoC()
	Return RestartBlueStacksXCoC()
EndFunc   ;==>RestartBlueStacks2CoC

Func CheckScreenBlueStacks5($bSetLog = True)
	;Return CheckScreenBlueStacksX($bSetLog)
	Return True
EndFunc   ;==>CheckScreenBlueStacks

Func SetScreenBlueStacks5()
	Local $REGISTRY_KEY_DIRECTORY = $g_sHKLM & "\SOFTWARE\BlueStacks_nxt\Guests\" & $g_sAndroidInstance & "\FrameBuffer\0"
	RegWrite($REGISTRY_KEY_DIRECTORY, "FullScreen", "REG_DWORD", "0")
	RegWrite($REGISTRY_KEY_DIRECTORY, "GuestHeight", "REG_DWORD", $g_iAndroidClientHeight)
	RegWrite($REGISTRY_KEY_DIRECTORY, "GuestWidth", "REG_DWORD", $g_iAndroidClientWidth)
	RegWrite($REGISTRY_KEY_DIRECTORY, "WindowHeight", "REG_DWORD", $g_iAndroidClientHeight)
	RegWrite($REGISTRY_KEY_DIRECTORY, "WindowWidth", "REG_DWORD", $g_iAndroidClientWidth)
	; Enable bottom action bar with Back- and Home-Button (Menu-Button has no function and don't click Full-Screen-Button at the right as you cannot go back - F11 is not working!)
	; 2015-12-24 cosote Disabled with "0" again because latest version 2.0.2.5623 doesn't support it anymore
	$REGISTRY_KEY_DIRECTORY = $g_sHKLM & "\SOFTWARE\BlueStacks_nxt\Guests\" & $g_sAndroidInstance & "\Config"
	RegWrite($REGISTRY_KEY_DIRECTORY, "FEControlBar", "REG_DWORD", "0")
	$REGISTRY_KEY_DIRECTORY = $g_sHKLM & "\SOFTWARE\BlueStacks_nxt\Guests\" & $g_sAndroidInstance
	Local $BootParameter = RegRead($REGISTRY_KEY_DIRECTORY, "BootParameters")
	$BootParameter = StringRegExpReplace($BootParameter, "DPI=\d+", "DPI=160")
	If @error = 0 And @extended > 0 Then
		RegWrite($REGISTRY_KEY_DIRECTORY, "BootParameters", "REG_SZ", $BootParameter)
	Else
		; DPI=160 was missing
		RegWrite($REGISTRY_KEY_DIRECTORY, "BootParameters", "REG_SZ", $BootParameter & " DPI=160")
	EndIf
EndFunc   ;==>SetScreenBlueStacks2

Func ConfigBlueStacks5WindowManager()
	If Not $g_bRunState Then Return
	Local $cmdOutput
	; shell wm density 160
	; shell wm size 860x672
	; shell reboot

	; Reset Window Manager size
	$cmdOutput = AndroidAdbSendShellCommand("wm size reset", Default, Default, False)

	; Set expected dpi
	$cmdOutput = AndroidAdbSendShellCommand("wm density 160", Default, Default, False)

	; Set font size to normal
	AndroidSetFontSizeNormal()
EndFunc   ;==>ConfigBlueStacks2WindowManager

Func RebootBlueStacks5SetScreen($bOpenAndroid = True)

	;RebootAndroidSetScreenDefault()

	If Not InitAndroid() Then Return False

	ConfigBlueStacks5WindowManager()

	; Close Android
	CloseAndroid("RebootBlueStacks5SetScreen")
	If _Sleep(1000) Then Return False

	SetScreenAndroid()
	If Not $g_bRunState Then Return False

	If $bOpenAndroid Then
		; Start Android
		OpenAndroid(True)
	EndIf

	Return True

EndFunc   ;==>RebootBlueStacks2SetScreen

Func GetBlueStacks5RunningInstance($bStrictCheck = True)
	WinGetAndroidHandle()
	Local $a[2] = [$g_hAndroidWindow, ""]
	If $g_hAndroidWindow <> 0 Then Return $a
	If $bStrictCheck Then Return False
	Local $WinTitleMatchMode = Opt("WinTitleMatchMode", -3) ; in recent 2.3.x can be also "BlueStacks App Player"
	Local $h = WinGetHandle("Bluestacks App Player", "") ; Need fixing as BS2 Emulator can have that title when configured in registry
	If @error = 0 Then
		$a[0] = $h
	EndIf
	Opt("WinTitleMatchMode", $WinTitleMatchMode)
	Return $a
EndFunc   ;==>GetBlueStacks2RunningInstance

Func BlueStacks5BotStartEvent()
	Return False
EndFunc   ;==>BlueStacks2BotStartEvent

Func BlueStacks5BotStopEvent()
	Return False
EndFunc   ;==>BlueStacks2BotStopEvent

Func GetBlueStacks5SvcPid()
	; find process PID
	Local $PID = ProcessExists2("HD-Service.exe")
	Return $PID
EndFunc   ;==>GetBlueStacksSvcPid

Func CloseBlueStacks5()

	Local $bOops = False

	If Not InitAndroid() Then Return

	If Not CloseUnsupportedBlueStacksX(False) And GetVersionNormalized($g_sAndroidVersion) > GetVersionNormalized("2.10") Then
		; BlueStacks 3 supports multiple instance
		Local $aFiles = ["HD-Frontend.exe", "HD-Plus-Service.exe", "HD-Service.exe"]

		Local $bError = False
		For $sFile In $aFiles
			Local $PID
			$PID = ProcessExists2($sFile, $g_sAndroidInstance)
			If $PID Then
				ShellExecute(@WindowsDir & "\System32\taskkill.exe", " -f -t -pid " & $PID, "", Default, @SW_HIDE)
				If _Sleep(1000) Then Return ; Give OS time to work
			EndIf
		Next
		If _Sleep(1000) Then Return ; Give OS time to work
		For $sFile In $aFiles
			Local $PID
			$PID = ProcessExists2($sFile, $g_sAndroidInstance)
			If $PID Then
				SetLog($g_sAndroidEmulator & " failed to kill " & $sFile, $COLOR_ERROR)
			EndIf
		Next

		; also close vm
		CloseVboxAndroidSvc()
	Else
		SetDebugLog("Closing BlueStacks: " & $__BlueStacks_Path & "HD-Quit.exe")
		RunWait($__BlueStacks_Path & "HD-Quit.exe")
		If @error <> 0 Then
			SetLog($g_sAndroidEmulator & " failed to quit", $COLOR_ERROR)
			;SetError(1, @extended, -1)
			;Return False
		EndIf
	EndIf

	If _Sleep(2000) Then Return ; wait a bit

	If $bOops Then
		SetError(1, @extended, -1)
	EndIf

EndFunc   ;==>CloseBlueStacks2

Func CloseUnsupportedBlueStacks5()
	Local $WinTitleMatchMode = Opt("WinTitleMatchMode", -3) ; in recent 2.3.x can be also "BlueStacks App Player"
	Local $sPartnerExePath = RegRead($g_sHKLM & "\SOFTWARE\BlueStacks_nxt\Config\", "PartnerExePath")
	If IsArray(ControlGetPos("Bluestacks App Player", "", "")) Or ($sPartnerExePath And ProcessExists2($sPartnerExePath)) Then ; $g_avAndroidAppConfig[1][4]
		Opt("WinTitleMatchMode", $WinTitleMatchMode)
		; Offical "Bluestacks App Player" v2.0 not supported because it changes the Android Screen!!!		
		SetLog("MyBot doesn't work with " & $g_sAndroidEmulator & " App Player", $COLOR_ERROR)
		SetLog("Please let MyBot start " & $g_sAndroidEmulator & " automatically", $COLOR_INFO)
		RebootBlueStacks2SetScreen(False)
		Return True
	EndIf
	Opt("WinTitleMatchMode", $WinTitleMatchMode)
	Return False
EndFunc   ;==>CloseUnsupportedBlueStacks2

Func BlueStacks5AdjustClickCoordinates(ByRef $x, ByRef $y)
	$x = Round(32767.0 / $g_iAndroidClientWidth * $x)
	$y = Round(32767.0 / $g_iAndroidClientHeight * $y)
EndFunc   ;==>BlueStacksAdjustClickCoordinates