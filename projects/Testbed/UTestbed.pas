{===============================================================================
  LangVM™ - Language Virtual Machine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://langvm.org

  See LICENSE for license information
===============================================================================}

unit UTestbed;

interface

procedure RunTestbed();

implementation

uses
  System.SysUtils,
  StdApp.Utils,
  StdApp.Console,
  StdApp.Console.Menu,
  UTestCase.Script,
  UTestCase.Backend;

procedure RegisterMenuItems(const AMenu: TConsoleMenu);
begin
  AMenu.SetCategory('Script');
  AMenu.AddTestCase(TLVMDeclarations);
  AMenu.AddTestCase(TLVMTypes);
  AMenu.AddTestCase(TLVMVariables);
  AMenu.AddTestCase(TLVMRoutines);
  AMenu.AddTestCase(TLVMControlFlow);
  AMenu.AddTestCase(TLVMExpressions);
  AMenu.AddTestCase(TLVMDataStructures);
  AMenu.AddTestCase(TLVMErrorHandling);
  AMenu.AddTestCase(TLVMBuiltins);
  AMenu.AddTestCase(TLVMMir);
  AMenu.ClearCategory();

  AMenu.SetCategory('Backend');
  AMenu.AddTestCase(TBackendEncoding);
  AMenu.AddTestCase(TBackendProbes);
  AMenu.AddTestCase(TBackendPE);
  AMenu.AddTestCase(TBackendELF);
  AMenu.AddTestCase(TBackendABI);
  AMenu.AddTestCase(TBackendBuilders);
  AMenu.AddTestCase(TBackendFormats);
  AMenu.AddTestCase(TBackendMIR);
  AMenu.ClearCategory();
end;

procedure Menu();
var
  LMenu: TConsoleMenu;
begin
    LMenu := TConsoleMenu.Create();
    try
      LMenu.Title('LangVM Testbed');

      RegisterMenuItems(LMenu);

      LMenu.Run();
    finally
      LMenu.Free();
    end;
end;

procedure RunTestbed();
begin
  try
    Menu();
  except
    on E: Exception do
    begin
      TConsole.PrintLn('');
      TConsole.PrintLn(COLOR_RED + 'EXCEPTION: %s', [E.Message]);

      if TUtils.RunFromIDE() then
        TConsole.Pause();
    end;
  end;
end;

end.
