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
  System.IOUtils,
  StdApp.Utils,
  StdApp.Console,
  StdApp.Console.Menu,
  LangVM,
  UTestCase.Script,
  UTestCase.Backend;

procedure DebugRunMyr(const AMyrFile: string);
var
  LVM: TLangVM;
  LScriptFile: string;
  LSourceFile: string;
begin
  LScriptFile := TPath.GetFullPath('..\..\bin\res\language\myrissa\myrissa.lvm');
  LSourceFile := TPath.GetFullPath(AMyrFile);

  LVM := TLangVM.Create();
  try
    LVM.SourceFilename := LSourceFile;
    LVM.LoadScriptFile(LScriptFile);
    LVM.Run(LVM_MAINFUNC);

    if LVM.GetErrors().HasErrors() then
      TConsole.PrintLn('Errors detected.')
    else
      TConsole.PrintLn('OK.');
  finally
    LVM.Free();
  end;
end;

procedure CompileFile(const AFilename: string; const AAutoRun: Boolean = False);
var
  LVM: TLangVM;
  LScriptFile: string;
  LSourceFile: string;
begin
  LScriptFile := TPath.GetFullPath('..\..\bin\res\language\myrissa\myrissa.lvm');
  LSourceFile := TPath.GetFullPath(AFilename);

  TConsole.PrintLn('Compiling: %s', [LSourceFile]);

  LVM := TLangVM.Create();
  try
    LVM.SourceFilename := LSourceFile;
    if AAutoRun then
      LVM.SetVar('AutoRun', TLVMValue.FromBool(True));
    LVM.LoadScriptFile(LScriptFile);
    LVM.Run(LVM_MAINFUNC);

    if LVM.GetErrors().HasErrors() then
      TConsole.PrintLn(COLOR_RED + 'Failed.')
    else
      TConsole.PrintLn(COLOR_GREEN + 'Success.');
  finally
    LVM.Free();  // <-- set breakpoint here to inspect before cleanup
  end;
end;

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
    //Menu();
    CompileFile('..\..\bin\res\tests\myr\hello.myr');
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
