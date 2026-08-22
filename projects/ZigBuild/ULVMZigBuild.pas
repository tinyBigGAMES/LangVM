{===============================================================================
  LangVM™ - Language Virtual Machine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://langvm.org

  See LICENSE for license information
===============================================================================}

unit ULVMZigBuild;

{$I StdApp.Defines.inc}

interface

uses
  LangVM.DllApi;

// All exported functions use the TLVMDllFunc signature (cdecl).
// First arg is always the context handle (from zbInit), except zbInit itself.

function zbInit(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
function zbFree(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
function zbClear(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
function zbSetOutputPath(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
function zbSetProjectName(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
function zbSetTarget(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
function zbSetBuildMode(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
function zbSetOptimizeLevel(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
function zbSetSubsystem(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
function zbAddSourceFile(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
function zbAddIncludePath(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
function zbAddLibraryPath(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
function zbAddLinkLibrary(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
function zbSetDefine(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
function zbProcess(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
function zbRun(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
function zbGetLastExitCode(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
function zbSetToolchainPath(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
function zbSetRunArguments(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
function zbPushState(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
function zbPopState(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;

exports
  zbInit,
  zbFree,
  zbClear,
  zbSetOutputPath,
  zbSetProjectName,
  zbSetTarget,
  zbSetBuildMode,
  zbSetOptimizeLevel,
  zbSetSubsystem,
  zbAddSourceFile,
  zbAddIncludePath,
  zbAddLibraryPath,
  zbAddLinkLibrary,
  zbSetDefine,
  zbProcess,
  zbRun,
  zbGetLastExitCode,
  zbSetToolchainPath,
  zbSetRunArguments,
  zbPushState,
  zbPopState;

implementation

uses
  System.SysUtils,
  StdApp.Base,
  StdApp.Console,
  LangVM.ZigBuild;

type
  // Array accessor for TLVMDllValue pointer arithmetic
  TLVMDllValueArray = array[0..MaxInt div SizeOf(TLVMDllValue) - 1] of TLVMDllValue;
  PLVMDllValueArray = ^TLVMDllValueArray;

var
  // Holds the last error message so PAnsiChar stays valid until next call
  GLastError: UTF8String;

  // Global singleton -- created in initialization, freed in finalization
  GZigBuild: TLVMZigBuild;

// ---------------------------------------------------------------------------
// Helper routines
// ---------------------------------------------------------------------------

function MakeError(out AResult: TLVMDllValue; const AMsg: string): Integer;
begin
  GLastError := UTF8String(AMsg);
  AResult := Default(TLVMDllValue);
  AResult.VKind := Ord(dvkString);
  AResult.VStr := PAnsiChar(GLastError);
  Result := 1;
end;

function MakeNil(out AResult: TLVMDllValue): Integer;
begin
  AResult := Default(TLVMDllValue);
  AResult.VKind := Ord(dvkNil);
  Result := 0;
end;

function MakeInt(out AResult: TLVMDllValue; const AValue: Int64): Integer;
begin
  AResult := Default(TLVMDllValue);
  AResult.VKind := Ord(dvkInt);
  AResult.VInt := AValue;
  Result := 0;
end;

function MakeBool(out AResult: TLVMDllValue; const AValue: Boolean): Integer;
begin
  AResult := Default(TLVMDllValue);
  AResult.VKind := Ord(dvkBool);
  AResult.VBool := AValue;
  Result := 0;
end;

function MakePtr(out AResult: TLVMDllValue; const AValue: Pointer): Integer;
begin
  AResult := Default(TLVMDllValue);
  AResult.VKind := Ord(dvkPtr);
  AResult.VPtr := AValue;
  Result := 0;
end;

function ArgStr(const AArgs: PLVMDllValue; const AIndex: Integer): string; inline;
var
  LP: PLVMDllValue;
begin
  LP := AArgs;
  Inc(LP, AIndex);
  if LP^.VStr <> nil then
    Result := string(UTF8String(LP^.VStr))
  else
    Result := '';
end;

function ArgInt(const AArgs: PLVMDllValue; const AIndex: Integer): Int64; inline;
var
  LP: PLVMDllValue;
begin
  LP := AArgs;
  Inc(LP, AIndex);
  Result := LP^.VInt;
end;

function ArgBool(const AArgs: PLVMDllValue; const AIndex: Integer): Boolean; inline;
var
  LP: PLVMDllValue;
begin
  LP := AArgs;
  Inc(LP, AIndex);
  Result := LP^.VBool;
end;

function GetObj(const AArgs: PLVMDllValue; const ACount: Integer;
  out AObj: TLVMZigBuild; out AResult: TLVMDllValue): Boolean;
begin
  if ACount < 1 then
    begin
      MakeError(AResult, 'missing handle argument');
      Result := False;
      Exit;
    end;
  AObj := TLVMZigBuild(AArgs^.VPtr);
  if AObj = nil then
    begin
      MakeError(AResult, 'invalid handle (nil)');
      Result := False;
      Exit;
    end;
  Result := True;
end;

// ---------------------------------------------------------------------------
// Exported functions
// ---------------------------------------------------------------------------

function zbInit(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
begin
  Result := MakePtr(AResult, GZigBuild);
end;

function zbFree(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
begin
  // No-op -- singleton lifetime managed by initialization/finalization
  Result := MakeNil(AResult);
end;

function zbClear(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
var
  LObj: TLVMZigBuild;
begin
  if not GetObj(AArgs, ACount, LObj, AResult) then
    Exit(1);
  LObj.Clear();
  Result := MakeNil(AResult);
end;

function zbSetOutputPath(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
var
  LObj: TLVMZigBuild;
begin
  if not GetObj(AArgs, ACount, LObj, AResult) then
    Exit(1);
  if ACount < 2 then
    Exit(MakeError(AResult, 'zbSetOutputPath: missing path argument'));
  LObj.SetOutputPath(ArgStr(AArgs, 1));
  Result := MakeNil(AResult);
end;

function zbSetProjectName(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
var
  LObj: TLVMZigBuild;
begin
  if not GetObj(AArgs, ACount, LObj, AResult) then
    Exit(1);
  if ACount < 2 then
    Exit(MakeError(AResult, 'zbSetProjectName: missing name argument'));
  LObj.SetProjectName(ArgStr(AArgs, 1));
  Result := MakeNil(AResult);
end;

function zbSetTarget(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
var
  LObj: TLVMZigBuild;
begin
  if not GetObj(AArgs, ACount, LObj, AResult) then
    Exit(1);
  if ACount < 2 then
    Exit(MakeError(AResult, 'zbSetTarget: missing target argument'));
  LObj.SetTarget(ArgStr(AArgs, 1));
  Result := MakeNil(AResult);
end;

function zbSetBuildMode(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
var
  LObj: TLVMZigBuild;
  LMode: string;
begin
  if not GetObj(AArgs, ACount, LObj, AResult) then
    Exit(1);
  if ACount < 2 then
    Exit(MakeError(AResult, 'zbSetBuildMode: missing mode argument'));
  LMode := ArgStr(AArgs, 1);
  if LMode = 'exe' then
    LObj.SetBuildMode(bmExe)
  else if LMode = 'lib' then
    LObj.SetBuildMode(bmLib)
  else if LMode = 'dll' then
    LObj.SetBuildMode(bmDll)
  else
    Exit(MakeError(AResult, 'zbSetBuildMode: unknown mode "' + LMode + '"'));
  Result := MakeNil(AResult);
end;

function zbSetOptimizeLevel(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
var
  LObj: TLVMZigBuild;
  LLevel: string;
begin
  if not GetObj(AArgs, ACount, LObj, AResult) then
    Exit(1);
  if ACount < 2 then
    Exit(MakeError(AResult, 'zbSetOptimizeLevel: missing level argument'));
  LLevel := ArgStr(AArgs, 1);
  if LLevel = 'debug' then
    LObj.SetOptimizeLevel(olDebug)
  else if LLevel = 'release_safe' then
    LObj.SetOptimizeLevel(olReleaseSafe)
  else if LLevel = 'release_fast' then
    LObj.SetOptimizeLevel(olReleaseFast)
  else if LLevel = 'release_small' then
    LObj.SetOptimizeLevel(olReleaseSmall)
  else
    Exit(MakeError(AResult, 'zbSetOptimizeLevel: unknown level "' + LLevel + '"'));
  Result := MakeNil(AResult);
end;

function zbSetSubsystem(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
var
  LObj: TLVMZigBuild;
  LSub: string;
begin
  if not GetObj(AArgs, ACount, LObj, AResult) then
    Exit(1);
  if ACount < 2 then
    Exit(MakeError(AResult, 'zbSetSubsystem: missing subsystem argument'));
  LSub := ArgStr(AArgs, 1);
  if LSub = 'console' then
    LObj.SetSubsystem(stConsole)
  else if LSub = 'gui' then
    LObj.SetSubsystem(stGUI)
  else
    Exit(MakeError(AResult, 'zbSetSubsystem: unknown subsystem "' + LSub + '"'));
  Result := MakeNil(AResult);
end;

function zbAddSourceFile(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
var
  LObj: TLVMZigBuild;
begin
  if not GetObj(AArgs, ACount, LObj, AResult) then
    Exit(1);
  if ACount < 2 then
    Exit(MakeError(AResult, 'zbAddSourceFile: missing path argument'));
  LObj.AddSourceFile(ArgStr(AArgs, 1));
  Result := MakeNil(AResult);
end;

function zbAddIncludePath(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
var
  LObj: TLVMZigBuild;
begin
  if not GetObj(AArgs, ACount, LObj, AResult) then
    Exit(1);
  if ACount < 2 then
    Exit(MakeError(AResult, 'zbAddIncludePath: missing path argument'));
  LObj.AddIncludePath(ArgStr(AArgs, 1));
  Result := MakeNil(AResult);
end;

function zbAddLibraryPath(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
var
  LObj: TLVMZigBuild;
begin
  if not GetObj(AArgs, ACount, LObj, AResult) then
    Exit(1);
  if ACount < 2 then
    Exit(MakeError(AResult, 'zbAddLibraryPath: missing path argument'));
  LObj.AddLibraryPath(ArgStr(AArgs, 1));
  Result := MakeNil(AResult);
end;

function zbAddLinkLibrary(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
var
  LObj: TLVMZigBuild;
begin
  if not GetObj(AArgs, ACount, LObj, AResult) then
    Exit(1);
  if ACount < 2 then
    Exit(MakeError(AResult, 'zbAddLinkLibrary: missing name argument'));
  LObj.AddLinkLibrary(ArgStr(AArgs, 1));
  Result := MakeNil(AResult);
end;

function zbSetDefine(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
var
  LObj: TLVMZigBuild;
begin
  if not GetObj(AArgs, ACount, LObj, AResult) then
    Exit(1);
  if ACount < 2 then
    Exit(MakeError(AResult, 'zbSetDefine: missing define name'));
  if ACount >= 3 then
    LObj.SetDefine(ArgStr(AArgs, 1), ArgStr(AArgs, 2))
  else
    LObj.SetDefine(ArgStr(AArgs, 1));
  Result := MakeNil(AResult);
end;

function zbProcess(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
var
  LObj: TLVMZigBuild;
  LAutoRun: Boolean;
begin
  if not GetObj(AArgs, ACount, LObj, AResult) then
    Exit(1);
  LAutoRun := (ACount >= 2) and ArgBool(AArgs, 1);
  Result := MakeBool(AResult, LObj.Process(LAutoRun));
end;

function zbRun(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
var
  LObj: TLVMZigBuild;
begin
  if not GetObj(AArgs, ACount, LObj, AResult) then
    Exit(1);
  Result := MakeBool(AResult, LObj.Run());
end;

function zbGetLastExitCode(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
var
  LObj: TLVMZigBuild;
begin
  if not GetObj(AArgs, ACount, LObj, AResult) then
    Exit(1);
  Result := MakeInt(AResult, LObj.GetLastExitCode());
end;

function zbSetToolchainPath(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
var
  LObj: TLVMZigBuild;
begin
  if not GetObj(AArgs, ACount, LObj, AResult) then
    Exit(1);
  if ACount < 2 then
    Exit(MakeError(AResult, 'zbSetToolchainPath: missing path argument'));
  LObj.SetToolchainPath(ArgStr(AArgs, 1));
  Result := MakeNil(AResult);
end;

function zbSetRunArguments(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
var
  LObj: TLVMZigBuild;
begin
  if not GetObj(AArgs, ACount, LObj, AResult) then
    Exit(1);
  if ACount < 2 then
    LObj.SetRunArguments('')
  else
    LObj.SetRunArguments(ArgStr(AArgs, 1));
  Result := MakeNil(AResult);
end;

function zbPushState(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
var
  LObj: TLVMZigBuild;
begin
  if not GetObj(AArgs, ACount, LObj, AResult) then
    Exit(1);
  LObj.PushState();
  Result := MakeNil(AResult);
end;

function zbPopState(AArgs: PLVMDllValue; ACount: Integer;
  out AResult: TLVMDllValue): Integer; cdecl;
var
  LObj: TLVMZigBuild;
begin
  if not GetObj(AArgs, ACount, LObj, AResult) then
    Exit(1);
  LObj.PopState();
  Result := MakeNil(AResult);
end;

initialization
  GZigBuild := TLVMZigBuild.Create();
  GZigBuild.SetStatusCallback(
    procedure(const AText: string; const AUserData: Pointer)
    begin
      TConsole.PrintLn(AText);
    end);
  GZigBuild.SetOutputCallback(
    procedure(const AText: string; const AUserData: Pointer)
    begin
      TConsole.Print(AText);
    end);

finalization
  GZigBuild.Free();

end.
