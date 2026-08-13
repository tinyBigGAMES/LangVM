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
rem  run-testbed.cmd -- run the LangVM Testbed
rem
rem  Usage:   run-testbed.cmd -all
rem           run-testbed.cmd (interactive menu)
rem
rem  Passes all arguments through to Testbed.exe. The start wrapper is required
rem  because TConsole.Print is gated on HasConsole().
rem ============================================================================

cd /d "%~dp0"
start "" /wait cmd /c Testbed.exe %* ^> testbed.txt 2^>^&1
type testbed.txt