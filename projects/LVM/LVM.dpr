{===============================================================================
  LangVM™ - Language Virtual Machine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://langvm.org

  See LICENSE for license information
===============================================================================}

program LVM;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  ULVM in 'ULVM.pas',
  LangVM.CLI in '..\..\src\LangVM.CLI.pas';

begin
  RunCLI();
end.
