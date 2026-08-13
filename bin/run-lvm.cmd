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
rem  run-lvm.cmd -- run LVM with the mandatory start wrapper
rem
rem  Usage:   run-lvm.cmd -l <script.lvm> [-s <source>]
rem
rem  Passes all arguments through to LVM.exe. The start wrapper is required
rem  because TConsole.Print is gated on HasConsole().
rem ============================================================================

cd /d "%~dp0"
start "" /wait cmd /c LVM.exe %* ^> lvm.txt 2^>^&1
type lvm.txt