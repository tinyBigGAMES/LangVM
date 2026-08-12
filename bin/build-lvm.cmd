@echo off
rem ---------------------------------------------------------------------------
rem build-lvm.cmd -- build the LVM CLI runner
rem
rem Output:  C:\Dev\Delphi\Projects\LangVM\repo\bin\LVM.exe
rem
rem Usage:   build-lvm.cmd
rem ---------------------------------------------------------------------------

setlocal

call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"

cd /d "C:\Dev\Delphi\Projects\LangVM\repo\projects\LVM"
if errorlevel 1 (echo BUILD FAILED - project folder not found & exit /b 1)

msbuild LVM.dproj /t:Build /p:Config=Release /p:Platform=Win64 /verbosity:minimal
if errorlevel 1 (echo BUILD FAILED & exit /b 1)

echo BUILD OK
exit /b 0
