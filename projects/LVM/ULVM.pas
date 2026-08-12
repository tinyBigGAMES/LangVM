{===============================================================================
  LangVM™ - Language Virtual Machine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://langvm.org

  See LICENSE for license information
===============================================================================}

unit ULVM;

{$I StdApp.Defines.inc}

interface

procedure RunCLI();

implementation

uses
  System.SysUtils,
  System.IOUtils,
  StdApp.Console,
  LangVM.CLI;

procedure RunCLI();
var
  LCLI: TLVMCLI;
begin
 try
    ExitCode := 0;
    LCLI := TLVMCLI.Create();
    try
      LCLI.Execute();
    finally
      LCLI.Free();
    end;
  except
    on E: Exception do
    begin
      TConsole.PrintLn('');
      TConsole.PrintLn(COLOR_RED + 'EXCEPTION: ' + E.Message + COLOR_RESET);
    end;
  end;
end;

end.
