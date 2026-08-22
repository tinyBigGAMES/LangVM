@echo off
rem ============================================================================
rem  LangVM(tm) - Language Virtual Machine
rem
rem  Copyright (c) 2026-present tinyBigGAMES(tm) LLC
rem  All Rights Reserved.
rem
rem  https://langvm.org
rem
rem  See LICENSE for license information
rem ============================================================================
rem  build-lvm.cmd -- build the LVM CLI runner
rem
rem  Output:  C:\Dev\Delphi\Projects\LangVM\repo\bin\LVM.exe
rem
rem  Usage:   build-lvm.cmd
rem ============================================================================

setlocal

call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"

cd /d "C:\Dev\Delphi\Projects\LangVM\repo\projects"
if errorlevel 1 (echo BUILD FAILED - project folder not found & exit /b 1)

msbuild "LangVM - Language Virtual Machine.groupproj" /t:LVM /p:Config=Release /p:Platform=Win64 /verbosity:minimal
if errorlevel 1 (echo BUILD FAILED & exit /b 1)

echo BUILD OK
exit /b 0