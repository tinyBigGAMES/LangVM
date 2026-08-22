{===============================================================================
  LangVM™ - Language Virtual Machine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://langvm.org

  See LICENSE for license information
===============================================================================}

unit LangVM.DllApi;

{$I StdApp.Defines.inc}

interface

type
  { TLVMDllValueKind }
  TLVMDllValueKind = (
    dvkNil    = 0,
    dvkInt    = 1,
    dvkFloat  = 2,
    dvkBool   = 3,
    dvkString = 4,
    dvkPtr    = 5
  );

  { TLVMDllValue }
  TLVMDllValue = record
    VKind: Integer;
    case Integer of
      0: (VInt: Int64);
      1: (VFloat: Double);
      2: (VStr: PAnsiChar);
      3: (VBool: Boolean);
      4: (VPtr: Pointer);
  end;
  PLVMDllValue = ^TLVMDllValue;

  { TLVMDllFunc }
  // Every exported DLL function has this signature.
  // Returns 0 = success, non-zero = error code.
  // On error, AResult.VStr points to error message.
  TLVMDllFunc = function(AArgs: PLVMDllValue; ACount: Integer;
    out AResult: TLVMDllValue): Integer; cdecl;

implementation

end.
