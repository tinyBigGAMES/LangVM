@echo off
rem ---------------------------------------------------------------------------
rem run-lvm.cmd -- run LVM with the mandatory start wrapper
rem
rem Usage:   run-lvm.cmd -l <script.lvm> [-s <source>]
rem
rem Passes all arguments through to LVM.exe. The start wrapper is required
rem because TConsole.Print is gated on HasConsole().
rem ---------------------------------------------------------------------------

setlocal

cd /d "C:\Dev\Delphi\Projects\LangVM\repo"
start "" /wait cmd /c "bin\LVM.exe %* > temp\lvm.txt 2>&1"
type temp\lvm.txt
