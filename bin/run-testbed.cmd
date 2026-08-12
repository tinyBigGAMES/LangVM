@echo off
cd /d "%~dp0"
start "" /wait cmd /c "Testbed.exe %* > ..\temp\testbed.txt 2>&1"
type ..\temp\testbed.txt
