{===============================================================================
  LangVM™ - Language Virtual Machine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://langvm.org

  See LICENSE for license information
===============================================================================}

program Testbed;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  UTestbed in 'UTestbed.pas',
  StdApp.Resources in '..\..\src\StdApp.Resources.pas',
  LangVM in '..\..\src\LangVM.pas',
  UTestCase.Backend in 'UTestCase.Backend.pas',
  UTestCase.Script in 'UTestCase.Script.pas',
  LangVM.CLI in '..\..\src\LangVM.CLI.pas',
  LangVM.ZigBuild in '..\..\src\LangVM.ZigBuild.pas',
  LangVM.ZigBuild.Targets in '..\..\src\LangVM.ZigBuild.Targets.pas';

begin
  RunTestbed();
end.
