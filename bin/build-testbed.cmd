@echo off
rem ---------------------------------------------------------------------------
rem build-testbed.cmd -- build the Myrissa Testbed project
rem
rem Output:  projects\Testbed\Win64\Release\Testbed.exe
rem
rem Usage:   build-testbed.cmd
rem
rem ALWAYS a full rebuild. See build-myrc.cmd for rationale.
rem ---------------------------------------------------------------------------

setlocal

call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"

cd /d "C:\Dev\Delphi\Projects\Myrissa\repo\projects\Testbed"
if errorlevel 1 (echo BUILD FAILED - project folder not found & exit /b 1)

msbuild Testbed.dproj /t:Build /p:Config=Release /p:Platform=Win64 /verbosity:minimal
if errorlevel 1 (echo BUILD FAILED & exit /b 1)

echo BUILD OK
exit /b 0
