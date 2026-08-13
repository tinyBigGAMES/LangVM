{===============================================================================
  LangVM™ - Language Virtual Machine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://langvm.org

  See LICENSE for license information
===============================================================================}

unit LangVM.CLI;

{$I StdApp.Defines.inc}

interface

uses
  System.IOUtils,
  StdApp.Console,
  LangVM;

type
  { TLVMCLI }
  TLVMCLI = class
  private
    FVM: TLangVM;
    FScriptFile: string;
    FSourceFile: string;
    FAutoRun: Boolean;
    procedure ShowBanner();
    procedure ShowHelp();
    procedure ShowErrors();
    procedure SetupCallbacks();
    function ParseArgs(): Boolean;
    procedure RunScript();
  public
    constructor Create();
    destructor Destroy(); override;
    procedure Execute();
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  StdApp.Base;

{ TLVMCLI }

constructor TLVMCLI.Create();
begin
  inherited Create();
  FVM := TLangVM.Create();
  FScriptFile := '';
  FSourceFile := '';
  FAutoRun := False;
end;

destructor TLVMCLI.Destroy();
begin
  FreeAndNil(FVM);
  inherited Destroy();
end;

procedure TLVMCLI.ShowBanner();
begin
  TConsole.PrintLn(COLOR_WHITE + COLOR_BOLD +
    'LangVM™ v' + LVM_VERSION);
  TConsole.PrintLn(COLOR_WHITE +
    'Copyright © 2026-present tinyBigGAMES™ LLC, All Rights Reserved.');
  TConsole.PrintLn(COLOR_YELLOW + 'https://langvm.org');
  TConsole.PrintLn('');
end;

procedure TLVMCLI.ShowHelp();
var
  LExeName: string;
begin
  LExeName := TPath.GetFileNameWithoutExtension(ParamStr(0));

  TConsole.PrintLn(COLOR_WHITE +
    'Syntax: ' + LExeName + ' -l <script> [options]');
  TConsole.PrintLn('');
  TConsole.PrintLn(COLOR_BOLD + 'USAGE:');
  TConsole.PrintLn('  ' + LExeName + ' ' + COLOR_CYAN +
    '-l <script>' + COLOR_RESET + ' [OPTIONS]');
  TConsole.PrintLn('');
  TConsole.PrintLn(COLOR_BOLD + 'REQUIRED:');
  TConsole.PrintLn('  ' + COLOR_CYAN + '-l, --lang    <file>' + COLOR_RESET +
    '   LVM script file (.lvm)');
  TConsole.PrintLn('');
  TConsole.PrintLn(COLOR_BOLD + 'OPTIONS:');
  TConsole.PrintLn('  ' + COLOR_CYAN + '-s, --source  <file>' + COLOR_RESET +
    '   Source file for the script to process');
  TConsole.PrintLn('  ' + COLOR_CYAN + '-r, --run           ' + COLOR_RESET +
    '   Run the compiled executable after building');
  TConsole.PrintLn('  ' + COLOR_CYAN + '-h, --help          ' + COLOR_RESET +
    '   Display this help message');
  TConsole.PrintLn('');
  TConsole.PrintLn(COLOR_BOLD + 'EXAMPLES:');
  TConsole.PrintLn('  ' + COLOR_CYAN +
    LExeName + ' -l mylang.lvm');
  TConsole.PrintLn('  ' + COLOR_CYAN +
    LExeName + ' -l mylang.lvm -s hello.src');
  TConsole.PrintLn('');
end;

procedure TLVMCLI.ShowErrors();
begin
  FVM.PrintErrors();
end;

procedure TLVMCLI.SetupCallbacks();
begin
  FVM.SetOnPrint(
    procedure(const AText: string; const AUserData: Pointer)
    begin
      Write(AText);
    end, nil);

  FVM.SetStatusCallback(
    procedure(const AText: string; const AUserData: Pointer)
    begin
      TConsole.PrintLn(AText);
    end, nil);
end;

function TLVMCLI.ParseArgs(): Boolean;
var
  LI: Integer;
  LFlag: string;
begin
  Result := True;

  if ParamCount() = 0 then
  begin
    ShowHelp();
    Result := False;
    Exit;
  end;

  LI := 1;
  while LI <= ParamCount() do
  begin
    LFlag := ParamStr(LI).Trim();

    if (LFlag = '-h') or (LFlag = '--help') then
    begin
      ShowHelp();
      Result := False;
      Exit;
    end
    else if (LFlag = '-l') or (LFlag = '--lang') then
    begin
      Inc(LI);
      if LI > ParamCount() then
      begin
        TConsole.PrintLn(COLOR_RED + 'Error: ' + LFlag +
          ' requires a file argument');
        TConsole.PrintLn('');
        ExitCode := 2;
        Result := False;
        Exit;
      end;
      FScriptFile := TPath.ChangeExtension(ParamStr(LI).Trim(), LVM_FILEEXT);
    end
    else if (LFlag = '-s') or (LFlag = '--source') then
    begin
      Inc(LI);
      if LI > ParamCount() then
      begin
        TConsole.PrintLn(COLOR_RED + 'Error: ' + LFlag +
          ' requires a file argument');
        TConsole.PrintLn('');
        ExitCode := 2;
        Result := False;
        Exit;
      end;
      FSourceFile := ParamStr(LI).Trim();
    end
    else if (LFlag = '-r') or (LFlag = '--run') then
    begin
      FAutoRun := True;
    end
    else
    begin
      TConsole.PrintLn(COLOR_RED + 'Error: Unknown flag: ' +
        COLOR_YELLOW + LFlag);
      TConsole.PrintLn('');
      TConsole.PrintLn('Run ' + COLOR_CYAN +
        TPath.GetFileNameWithoutExtension(ParamStr(0)) + ' -h' +
        COLOR_RESET + ' to see available options');
      TConsole.PrintLn('');
      ExitCode := 2;
      Result := False;
      Exit;
    end;

    Inc(LI);
  end;

  // Validate: script file is required
  if FScriptFile = '' then
  begin
    TConsole.PrintLn(COLOR_RED +
      'Error: LVM script file is required (-l <file>)');
    TConsole.PrintLn('');
    TConsole.PrintLn('Run ' + COLOR_CYAN +
      TPath.GetFileNameWithoutExtension(ParamStr(0)) + ' -h' +
      COLOR_RESET + ' to see available options');
    TConsole.PrintLn('');
    ExitCode := 2;
    Result := False;
    Exit;
  end;

  // Validate: script file must exist
  if not TFile.Exists(FScriptFile) then
  begin
    TConsole.PrintLn(COLOR_RED +
      'Error: Script file not found: ' + COLOR_YELLOW + FScriptFile);
    TConsole.PrintLn('');
    ExitCode := 2;
    Result := False;
    Exit;
  end;

  // Validate: source file must exist if specified
  if (FSourceFile <> '') and (not TFile.Exists(FSourceFile)) then
  begin
    TConsole.PrintLn(COLOR_RED +
      'Error: Source file not found: ' + COLOR_YELLOW + FSourceFile);
    TConsole.PrintLn('');
    ExitCode := 2;
    Result := False;
    Exit;
  end;
end;

procedure TLVMCLI.RunScript();
begin
  SetupCallbacks();

  // Set source filename before loading the script
  if FSourceFile <> '' then
    FVM.SourceFilename := TPath.GetFullPath(FSourceFile);

  // Set auto-run flag for the script to check
  FVM.SetVar('AutoRun', TLVMValue.FromBool(FAutoRun));

  FVM.LoadScriptFile(FScriptFile);
  FVM.Run(LVM_MAINFUNC);

  // Display errors
  ShowErrors();

  if FVM.GetErrors().HasErrors() then
  begin
    TConsole.PrintLn(COLOR_RED + 'Failed.');
    ExitCode := 1;
  end
  else
  begin
    // Propagate VM exit code to process
    ExitCode := FVM.ExitCode;
  end;
end;

procedure TLVMCLI.Execute();
begin
  ShowBanner();

  if not ParseArgs() then
    Exit;

  try
    RunScript();
  except
    on E: Exception do
    begin
      TConsole.PrintLn('');
      TConsole.PrintLn(COLOR_RED + COLOR_BOLD + 'Fatal Error: ' +
        E.Message + COLOR_RESET);
      TConsole.PrintLn('');
      ExitCode := 1;
    end;
  end;
end;

end.
