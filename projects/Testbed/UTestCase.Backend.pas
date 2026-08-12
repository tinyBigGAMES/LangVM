{===============================================================================
  LangVM™ - Language Virtual Machine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://langvm.org

  See LICENSE for license information
===============================================================================}

unit UTestCase.Backend;

interface

uses
  System.IOUtils,
  StdApp.TestCase,
  LangVM;

type

  { TBackendTest }
  TBackendTest = class(TTestCase)
  protected
    FLVM: TLangVM;
    FLastExitCode: Int64;
    procedure RunScript(const ARelPath: string;
      const AVarName: string = '';
      const AVarValue: string = '');
  public
    destructor Destroy(); override;
  end;

  { TBackendEncoding }
  TBackendEncoding = class(TBackendTest)
  protected
    procedure Run(); override;
  public
    constructor Create(); override;
  end;

  { TBackendProbes }
  TBackendProbes = class(TBackendTest)
  protected
    procedure Run(); override;
  public
    constructor Create(); override;
  end;

  { TBackendPE }
  TBackendPE = class(TBackendTest)
  protected
    procedure Run(); override;
  public
    constructor Create(); override;
  end;

  { TBackendELF }
  TBackendELF = class(TBackendTest)
  protected
    procedure Run(); override;
  public
    constructor Create(); override;
  end;

  { TBackendABI }
  TBackendABI = class(TBackendTest)
  protected
    procedure Run(); override;
  public
    constructor Create(); override;
  end;

  { TBackendBuilders }
  TBackendBuilders = class(TBackendTest)
  protected
    procedure Run(); override;
  public
    constructor Create(); override;
  end;

  { TBackendFormats }
  TBackendFormats = class(TBackendTest)
  protected
    procedure Run(); override;
  public
    constructor Create(); override;
  end;

  { TBackendMIR }
  TBackendMIR = class(TBackendTest)
  protected
    procedure Run(); override;
  public
    constructor Create(); override;
  end;

implementation

uses
  System.SysUtils,
  StdApp.Base,
  StdApp.Utils;

// =========================================================================
//  TBackendTest -- base helper
// =========================================================================

{ TBackendTest.Destroy }

destructor TBackendTest.Destroy();
begin
  if Assigned(FLVM) then
    FLVM.Free();
  inherited Destroy();
end;

{ TBackendTest.RunScript }

procedure TBackendTest.RunScript(const ARelPath: string;
  const AVarName: string; const AVarValue: string);
begin
  if Assigned(FLVM) then
    FLVM.Free();
  FLVM := TLangVM.Create();
  FLVM.SetOnPrint(
    procedure(const AText: string; const AUserData: Pointer)
    begin
      // OnPrint displays output -- no accumulation needed
    end, nil);
  if AVarName <> '' then
    FLVM.SetVar(AVarName, TLVMValue.FromString(
      TUtils.ResolvePath(AVarValue)));
  FLVM.LoadScriptFile('$P:res\tests\lvm\backend\' + ARelPath);
  FLVM.Run(LVM_MAINFUNC);
  FLVM.PrintErrors();
  FLastExitCode := FLVM.ExitCode;
end;


// =========================================================================
//  TBackendEncoding -- x86_64 instruction encoding tests
// =========================================================================

{ TBackendEncoding }

constructor TBackendEncoding.Create();
begin
  inherited;

  Title := 'Encoding';

  // Test 1: mov rax, imm64 + ret
  RegisterTest('Encode_MovRaxImm64_Ret', procedure
  begin
    RunScript('encoding/mov_rax_imm64_ret.lvm');
    Check(FLVM.GetVar(LVM_RESULT).AsInt() = 42, 'mov rax,42 + ret => 42');
  end);

  // Test 2: mov r64, imm64 for RAX, RCX, R8
  RegisterTest('Encode_MovR64_AllRegs', procedure
  var
    LResult: TLVMValue;
  begin
    RunScript('encoding/mov_r64_all_regs.lvm');
    LResult := FLVM.GetVar(LVM_RESULT);
    Check(LResult.AsMap()['rax'].AsInt() = 100, 'mov rax,100 => 100');
    Check(LResult.AsMap()['rcx'].AsInt() = 200, 'mov rcx,200; mov rax,rcx => 200');
    Check(LResult.AsMap()['r8'].AsInt() = 300, 'mov r8,300; mov rax,r8 => 300');
  end);

  // Test 3: add/sub r64,r64
  RegisterTest('Encode_Arithmetic', procedure
  var
    LResult: TLVMValue;
  begin
    RunScript('encoding/arithmetic.lvm');
    LResult := FLVM.GetVar(LVM_RESULT);
    Check(LResult.AsMap()['add'].AsInt() = 42, 'add rax,rcx = 42');
    Check(LResult.AsMap()['sub'].AsInt() = 42, 'sub rax,rcx = 42');
  end);

  // Test 4: push/pop/sub rsp/add rsp
  RegisterTest('Encode_PrologueEpilogue', procedure
  begin
    RunScript('encoding/prologue_epilogue.lvm');
    Check(FLVM.GetVar(LVM_RESULT).AsInt() = 99,
      'prologue/epilogue preserves and returns 99');
  end);

  // Test 5: Load encode.lvm from file
  RegisterTest('Encode_LoadFile', procedure
  begin
    RunScript('encoding/load_file.lvm');
    Check(FLVM.GetVar(LVM_RESULT).AsInt() = 77,
      'encode.lvm loaded and working');
  end);

  // Test 6: call rel32
  RegisterTest('Encode_CallRel32', procedure
  begin
    RunScript('encoding/call_rel32.lvm');
    Check(FLVM.GetVar(LVM_RESULT).AsInt() = 42,
      'call rel32: func_add(30,12) = 42');
  end);

  // Test 7: cmp + jcc
  RegisterTest('Encode_CmpJcc', procedure
  begin
    RunScript('encoding/cmp_jcc.lvm');
    Check(FLVM.GetVar(LVM_RESULT).AsInt() = 10,
      'cmp+jg: 10>5 so branch taken, result=10');
  end);

  // Test 8: test + jne/jmp
  RegisterTest('Encode_TestJmp', procedure
  var
    LResult: TLVMValue;
  begin
    RunScript('encoding/test_jmp.lvm');
    LResult := FLVM.GetVar(LVM_RESULT);
    Check(LResult.AsMap()['z'].AsInt() = 0,
      'test rax,rax: value=0 returns 0');
    Check(LResult.AsMap()['nz'].AsInt() = 1,
      'test rax,rax: value=7 returns 1');
  end);

  // Test 9: base+displacement MOV
  RegisterTest('Encode_BaseDisp', procedure
  var
    LResult: TLVMValue;
  begin
    RunScript('encoding/base_disp.lvm');
    LResult := FLVM.GetVar(LVM_RESULT);
    Check(LResult.AsMap()['rbp'].AsInt() = 42,
      'RBP-relative local store/load returns 42');
    Check(LResult.AsMap()['rsp'].AsInt() = 99,
      'RSP-relative (SIB) store/load returns 99');
  end);

  // Test 10: CALL [RIP+disp32]
  RegisterTest('Encode_CallIndirectRip', procedure
  begin
    RunScript('encoding/call_indirect_rip.lvm');
    Check(FLVM.GetVar(LVM_RESULT).AsInt() = 42,
      'CALL [RIP+disp32] via GOT slot returns 42');
  end);

  // Test 11: MOV r64,[RIP+disp32] and MOV [RIP+disp32],r64
  RegisterTest('Encode_MovRipRelative', procedure
  begin
    RunScript('encoding/mov_rip_relative.lvm');
    Check(FLVM.GetVar(LVM_RESULT).AsInt() = 77,
      'RIP-relative store/load returns 77');
  end);

  // Test 12: IMUL/IDIV
  RegisterTest('Encode_ImulIdiv', procedure
  var
    LResult: TLVMValue;
  begin
    RunScript('encoding/imul_idiv.lvm');
    LResult := FLVM.GetVar(LVM_RESULT);
    Check(LResult.AsMap()['imul'].AsInt() = 42, 'IMUL 7*6 = 42');
    Check(LResult.AsMap()['idiv'].AsInt() = 42, 'IDIV 85/2 = 42');
  end);

  // Test 13: NEG/NOT
  RegisterTest('Encode_NegNot', procedure
  var
    LResult: TLVMValue;
  begin
    RunScript('encoding/neg_not.lvm');
    LResult := FLVM.GetVar(LVM_RESULT);
    Check(LResult.AsMap()['neg'].AsInt() = 42, 'NEG(-42) = 42');
    Check(LResult.AsMap()['not'].AsInt() = -1, 'NOT(0) = -1');
  end);

  // Test 14: SHL/SHR/SAR
  RegisterTest('Encode_Shifts', procedure
  var
    LResult: TLVMValue;
  begin
    RunScript('encoding/shifts.lvm');
    LResult := FLVM.GetVar(LVM_RESULT);
    Check(LResult.AsMap()['shl'].AsInt() = 32, 'SHL 1<<5 = 32');
    Check(LResult.AsMap()['shr'].AsInt() = 40, 'SHR 320>>3 = 40');
    Check(LResult.AsMap()['sar'].AsInt() = -4, 'SAR -16>>2 = -4');
  end);

  // Test 15: MOVZX/MOVSXD
  RegisterTest('Encode_MovzxMovsxd', procedure
  var
    LResult: TLVMValue;
  begin
    RunScript('encoding/movzx_movsxd.lvm');
    LResult := FLVM.GetVar(LVM_RESULT);
    Check(LResult.AsMap()['movzx'].AsInt() = 255,
      'MOVZX zero-extends byte to 64');
    Check(LResult.AsMap()['movsxd'].AsInt() = -42,
      'MOVSXD sign-extends 32 to 64');
  end);

  // Test 16: Float arithmetic (addsd, mulsd)
  RegisterTest('Encode_FloatArith', procedure
  var
    LResult: TLVMValue;
  begin
    RunScript('encoding/float_arith.lvm');
    LResult := FLVM.GetVar(LVM_RESULT);
    Check(LResult.AsMap()['fadd'].AsInt() = 42,
      'ADDSD 30.0+12.0 truncated to 42');
    Check(LResult.AsMap()['fmul'].AsInt() = 42,
      'MULSD 7.0*6.0 truncated to 42');
  end);

  // Test 17: Float sub/div/cmp
  RegisterTest('Encode_FloatSubDivCmp', procedure
  var
    LResult: TLVMValue;
  begin
    RunScript('encoding/float_sub_div_cmp.lvm');
    LResult := FLVM.GetVar(LVM_RESULT);
    Check(LResult.AsMap()['fdiv'].AsInt() = 42,
      'DIVSD 84.0/2.0 truncated to 42');
    Check(LResult.AsMap()['fsub'].AsInt() = 42,
      'SUBSD 50.0-8.0 truncated to 42');
  end);
end;

procedure TBackendEncoding.Run();
begin
  inherited;
end;


// =========================================================================
//  TBackendProbes -- infrastructure probes
// =========================================================================

{ TBackendProbes }

constructor TBackendProbes.Create();
begin
  inherited;

  Title := 'Probes';

  // Probe 1: shr on high-bit values
  RegisterTest('Probe_ShrUnsigned', procedure
  var
    LResult: TLVMValue;
  begin
    RunScript('probes/shr_unsigned.lvm');
    LResult := FLVM.GetVar(LVM_RESULT);
    Check(LResult.AsMap()['hi'].AsInt() = 57005,
      'shr 16 extracts high word');
    Check(LResult.AsMap()['lo'].AsInt() = 48879,
      'band extracts low word');
    Check(LResult.AsMap()['bytes'].AsString() = '222,173,190,239',
      'byte extraction correct');
    Check(LResult.AsMap()['rt'].AsInt() = 3735928559,
      'bufWriteU32/ReadU32 round-trip');
  end);

  // Probe 2: buffer-to-buffer copy
  RegisterTest('Probe_BufToBufCopy', procedure
  var
    LResult: TLVMValue;
  begin
    RunScript('probes/buf_to_buf_copy.lvm');
    LResult := FLVM.GetVar(LVM_RESULT);
    Check(LResult.AsMap()['t0'].AsInt() = 287454020,
      'text[0] = 0x11223344');
    Check(LResult.AsMap()['t4'].AsInt() = 1432778632,
      'text[4] = 0x55667788');
    Check(LResult.AsMap()['r16'].AsInt() = 2864434397,
      'rdata[16] = 0xAABBCCDD');
    Check(LResult.AsMap()['r20'].AsInt() = 4009689105,
      'rdata[20] = 0xEEFF0011');
    Check(LResult.AsMap()['gap'].AsInt() = 0,
      'gap between sections is zero');
  end);

  // Probe 3: 200+ routines loaded
  RegisterTest('Probe_ScaleRoutines', procedure
  var
    LResult: TLVMValue;
  begin
    RunScript('probes/scale_routines.lvm');
    LResult := FLVM.GetVar(LVM_RESULT);
    Check(LResult.AsMap()['fn0'].AsInt() = 100, 'fn_0(100) = 100');
    Check(LResult.AsMap()['fn99'].AsInt() = 199, 'fn_99(100) = 199');
    Check(LResult.AsMap()['fn199'].AsInt() = 299, 'fn_199(100) = 299');
  end);

  // Probe 4: backpatching
  RegisterTest('Probe_Backpatch', procedure
  var
    LResult: TLVMValue;
  begin
    RunScript('probes/backpatch.lvm');
    LResult := FLVM.GetVar(LVM_RESULT);
    Check(LResult.AsMap()['exec'].AsInt() = 12345,
      'backpatched imm64 executed correctly');
    Check(LResult.AsMap()['patched'].AsInt() = 512,
      'U32 backpatch reads back');
  end);
end;

procedure TBackendProbes.Run();
begin
  inherited;
end;

// =========================================================================
//  TBackendPE -- PE output tests
// =========================================================================

{ TBackendPE }

constructor TBackendPE.Create();
var
  LExePath: string;
  LDllPath: string;
begin
  inherited;

  Title := 'PE Output';

  // PE 1: ExitProcess(42)
  RegisterTest('PE_ExitProcess42', procedure
  begin
    LExePath := TUtils.ResolvePath('$P:output\test_exit42.exe');
    RunScript('pe/exit_process_42.lvm',
      'exe_path', '$P:output\test_exit42.exe');
    Check(FLastExitCode = 42, 'PE exe returned exit code 42');
    Check(FileExists(LExePath), 'exe file exists on disk');
  end);

  // PE 2: WriteFile string literal
  RegisterTest('PE_WriteStringLiteral', procedure
  begin
    LExePath := TUtils.ResolvePath('$P:output\test_rdata.exe');
    RunScript('pe/write_string_literal.lvm',
      'exe_path', '$P:output\test_rdata.exe');
    Check(FLastExitCode = 0, 'PE rdata exe exited 0');
    Check(FileExists(LExePath), 'PE rdata exe file exists');
  end);

  // PE 3: .data section
  RegisterTest('PE_DataSection', procedure
  begin
    LExePath := TUtils.ResolvePath('$P:output\test_data.exe');
    RunScript('pe/data_section.lvm',
      'exe_path', '$P:output\test_data.exe');
    Check(FLastExitCode = 42, 'PE .data exe exited 42');
    Check(FileExists(LExePath), 'PE .data exe file exists');
  end);

  // PE 4: DLL with exports
  RegisterTest('PE_DLL_Exports', procedure
  var
    LResult: TLVMValue;
  begin
    LDllPath := TUtils.ResolvePath('$P:output\test_dll.dll');
    RunScript('pe/dll_exports.lvm',
      'dll_path', '$P:output\test_dll.dll');
    LResult := FLVM.GetVar(LVM_RESULT);
    Check(LResult.AsMap()['saved'].AsBool() = True,
      'DLL saved to disk');
    Check(LResult.AsMap()['value'].AsInt() = 42,
      'Exported GetValue returned 42');
    Check(FileExists(LDllPath), 'DLL file exists');
  end);
end;

procedure TBackendPE.Run();
begin
  inherited;
end;

// =========================================================================
//  TBackendELF -- ELF output tests
// =========================================================================

{ TBackendELF }

constructor TBackendELF.Create();
var
  LElfPath: string;
  LSoPath: string;
begin
  inherited;

  Title := 'ELF Output';

  // ELF 1: exit 42
  RegisterTest('ELF_Exit42', procedure
  begin
    LElfPath := TUtils.ResolvePath('$P:output\test_exit42');
    RunScript('elf/exit_42.lvm',
      'elf_path', '$P:output\test_exit42');
    Check(FLastExitCode = 42, 'ELF exe returned exit code 42');
    Check(FileExists(LElfPath), 'ELF file exists on disk');
  end);

  // ELF 2: libc exit(99)
  RegisterTest('ELF_LibcExit', procedure
  begin
    LElfPath := TUtils.ResolvePath('$P:output\test_libc_exit');
    RunScript('elf/libc_exit.lvm',
      'elf_path', '$P:output\test_libc_exit');
    Check(FLastExitCode = 99,
      'ELF dynamic exe returned exit code 99');
    Check(FileExists(LElfPath),
      'ELF dynamic file exists on disk');
  end);

  // ELF 3: .rodata ref
  RegisterTest('ELF_RoDataRef', procedure
  begin
    LElfPath := TUtils.ResolvePath('$P:output\test_rodata');
    RunScript('elf/rodata_ref.lvm',
      'elf_path', '$P:output\test_rodata');
    Check(FLastExitCode = 42,
      'ELF rodata exe returned exit code 42');
    Check(FileExists(LElfPath), 'ELF rodata file exists');
  end);

  // ELF 4: .data section
  RegisterTest('ELF_DataSection', procedure
  begin
    LElfPath := TUtils.ResolvePath('$P:output\test_data_elf');
    RunScript('elf/data_section.lvm',
      'elf_path', '$P:output\test_data_elf');
    Check(FLastExitCode = 42, 'ELF .data exe exited 42');
    Check(FileExists(LElfPath), 'ELF .data file exists');
  end);

  // ELF 5: .so with exports
  RegisterTest('ELF_SO_Exports', procedure
  var
    LResult: TLVMValue;
  begin
    LSoPath := TUtils.ResolvePath('$P:output\test_lib.so');
    RunScript('elf/so_exports.lvm',
      'so_path', '$P:output\test_lib.so');
    LResult := FLVM.GetVar(LVM_RESULT);
    Check(LResult.AsMap()['magic'].AsBool() = True,
      'ELF magic correct');
    Check(LResult.AsMap()['etype'].AsInt() = 3,
      'ELF type is ET_DYN (3)');
    Check(LResult.AsMap()['entry'].AsInt() = 0,
      'Entry point is 0 for .so');
    Check(LResult.AsMap()['shnum'].AsInt() = 8,
      '8 section headers');
    Check(LResult.AsMap()['shstrndx'].AsInt() = 7,
      'shstrndx is 7');
    Check(FileExists(LSoPath), 'SO file exists');
    Check(LResult.AsMap()['done'].AsBool() = True,
      'Script completed without error');
  end);
end;

procedure TBackendELF.Run();
begin
  inherited;
end;


// =========================================================================
//  TBackendABI -- ABI tests
// =========================================================================

{ TBackendABI }

constructor TBackendABI.Create();
var
  LExePath: string;
begin
  inherited;

  Title := 'ABI';

  // ABI 1: Win64 prologue/epilogue
  RegisterTest('ABI_Win64_Prologue', procedure
  begin
    LExePath := TUtils.ResolvePath('$P:output\test_abi_prologue.exe');
    RunScript('abi/win64_prologue.lvm',
      'exe_path', '$P:output\test_abi_prologue.exe');
    Check(FLastExitCode = 42, 'ABI prologue PE exe returned 42');
    Check(FileExists(LExePath), 'ABI prologue exe exists on disk');
  end);

  // ABI 2: Win64 call argument setup
  RegisterTest('ABI_Win64_CallArgs', procedure
  var
    LResult: TLVMValue;
  begin
    RunScript('abi/win64_call_args.lvm');
    LResult := FLVM.GetVar(LVM_RESULT);
    Check(LResult.AsMap()['regs'].AsString() = '1,2,8,9,-1',
      'Win64 arg regs correct');
    Check(LResult.AsMap()['align1'].AsInt() = 16,
      'align 1 -> 16');
    Check(LResult.AsMap()['align17'].AsInt() = 32,
      'align 17 -> 32');
    Check(LResult.AsMap()['p0'].AsInt() = -40,
      'param 0 offset = -40');
    Check(LResult.AsMap()['p1'].AsInt() = -48,
      'param 1 offset = -48');
  end);

  // ABI 3: SysV arg register assignment
  RegisterTest('ABI_SysV_ArgRegs', procedure
  begin
    RunScript('abi/sysv_arg_regs.lvm');
    Check(FLVM.GetVar(LVM_RESULT).AsString() = '7,6,2,1,8,9,-1',
      'SysV arg regs correct');
  end);

  // ABI 4: Win64 float args
  RegisterTest('ABI_Win64_FloatArgs', procedure
  var
    LResult: TLVMValue;
  begin
    RunScript('abi/win64_float_args.lvm');
    LResult := FLVM.GetVar(LVM_RESULT);
    Check(LResult.AsMap()['size'].AsInt() = 50,
      'Win64 typed args total size 50');
    Check(LResult.AsMap()['ok'].AsBool() = True,
      'Win64 float args executed');
    Check(LResult.AsMap()['movq_xmm1'].AsString() = '102,72,15,110,200',
      'MOVQ XMM1,RAX encoding');
  end);

  // ABI 5: SysV float args
  RegisterTest('ABI_SysV_FloatArgs', procedure
  var
    LResult: TLVMValue;
  begin
    RunScript('abi/sysv_float_args.lvm');
    LResult := FLVM.GetVar(LVM_RESULT);
    Check(LResult.AsMap()['moveax'].AsString() = '184,1',
      'SysV AL = 1 float reg');
  end);

  // ABI 6: Callee-saved register preservation
  RegisterTest('ABI_CalleeSaved', procedure
  var
    LResult: TLVMValue;
  begin
    RunScript('abi/callee_saved.lvm');
    LResult := FLVM.GetVar(LVM_RESULT);
    Check(LResult.AsMap()['save'].AsInt() = 3,
      'Save 2 regs = 3 bytes');
    Check(LResult.AsMap()['push'].AsString() = '83,65,84',
      'PUSH RBX + PUSH R12 encoding');
    Check(LResult.AsMap()['restore'].AsInt() = 3,
      'Restore 2 regs = 3 bytes');
    Check(LResult.AsMap()['pop'].AsString() = '65,92,91',
      'POP R12 + POP RBX encoding (reversed)');
  end);

  // ABI 7: Struct return Win64
  RegisterTest('ABI_StructReturn_Win64', procedure
  var
    LResult: TLVMValue;
  begin
    RunScript('abi/struct_return_win64.lvm');
    LResult := FLVM.GetVar(LVM_RESULT);
    Check(LResult.AsMap()['sret_bytes'].AsString() = '72,137,141',
      'SRET home RCX encoding');
    Check(LResult.AsMap()['ok'].AsBool() = True,
      'Struct return test completed');
  end);

  // ABI 8: Param homing Win64
  RegisterTest('ABI_ParamHome_Win64', procedure
  var
    LResult: TLVMValue;
  begin
    RunScript('abi/param_home_win64.lvm');
    LResult := FLVM.GetVar(LVM_RESULT);
    Check(LResult.AsMap()['size'].AsInt() = 28,
      'Home 4 params = 28 bytes');
    Check(LResult.AsMap()['home0'].AsString().StartsWith('72,137'),
      'Param home encoding starts with REX.W 89');
    Check(LResult.AsMap()['ok'].AsBool() = True,
      'Param homing test completed');
  end);
end;

procedure TBackendABI.Run();
begin
  inherited;
end;

// =========================================================================
//  TBackendBuilders -- builder unit tests
// =========================================================================

{ TBackendBuilders }

constructor TBackendBuilders.Create();
var
  LExePath: string;
begin
  inherited;

  Title := 'Builders';

  // Builder 1: DataBuilder
  RegisterTest('Builder_DataBuilder', procedure
  var
    LResult: TLVMValue;
  begin
    RunScript('builders/data_builder.lvm');
    LResult := FLVM.GetVar(LVM_RESULT);
    Check(LResult.AsMap()['h0'].AsInt() = 0, 'string handle is 0');
    Check(LResult.AsMap()['off0'].AsInt() = 0, 'string offset is 0');
    Check(LResult.AsMap()['sz1'].AsInt() = 6, 'size after string is 6');
    Check(LResult.AsMap()['h1'].AsInt() = 1, 'i32 handle is 1');
    Check(LResult.AsMap()['off1'].AsInt() = 6, 'i32 offset is 6');
    Check(LResult.AsMap()['sz2'].AsInt() = 10, 'size after i32 is 10');
    Check(LResult.AsMap()['sz3'].AsInt() = 16,
      'size after align 8 is 16');
    Check(LResult.AsMap()['h2'].AsInt() = 2, 'i64 handle is 2');
    Check(LResult.AsMap()['off2'].AsInt() = 16, 'i64 offset is 16');
    Check(LResult.AsMap()['sz4'].AsInt() = 24,
      'size after i64 is 24');
  end);

  // Builder 2: ImportBuilder
  RegisterTest('Builder_ImportBuilder', procedure
  var
    LResult: TLVMValue;
  begin
    RunScript('builders/import_builder.lvm');
    LResult := FLVM.GetVar(LVM_RESULT);
    Check(LResult.AsMap()['cnt'].AsInt() = 3, 'total count is 3');
    Check(LResult.AsMap()['dlls'].AsInt() = 2, 'dll count is 2');
    Check(LResult.AsMap()['i0'].AsInt() = 0, 'ExitProcess index 0');
    Check(LResult.AsMap()['i1'].AsInt() = 1, 'WriteFile index 1');
    Check(LResult.AsMap()['i2'].AsInt() = 2, 'printf index 2');
    Check(LResult.AsMap()['find'].AsInt() = 1,
      'find WriteFile returns 1');
    Check(LResult.AsMap()['miss'].AsInt() = -1,
      'find ReadFile returns -1');
    Check(LResult.AsMap()['ndlls'].AsInt() = 2,
      'to_imports has 2 DLLs');
    Check(LResult.AsMap()['dll0'].AsString() = 'kernel32.dll',
      'first DLL is kernel32');
    Check(LResult.AsMap()['nf0'].AsInt() = 2,
      'kernel32 has 2 funcs');
    Check(LResult.AsMap()['f00'].AsString() = 'ExitProcess',
      'first func is ExitProcess');
    Check(LResult.AsMap()['f01'].AsString() = 'WriteFile',
      'second func is WriteFile');
    Check(LResult.AsMap()['dll1'].AsString() = 'msvcrt.dll',
      'second DLL is msvcrt');
    Check(LResult.AsMap()['f10'].AsString() = 'printf',
      'msvcrt func is printf');
  end);

  // Builder 3: CodeBuilder
  RegisterTest('Builder_CodeBuilder', procedure
  var
    LResult: TLVMValue;
  begin
    RunScript('builders/code_builder.lvm');
    LResult := FLVM.GetVar(LVM_RESULT);
    Check(LResult.AsMap()['p1'].AsInt() = 4,
      'sub rsp,0x28 is 4 bytes');
    Check(LResult.AsMap()['p2'].AsInt() = 5, 'ret adds 1 byte');
    Check(LResult.AsMap()['nfix'].AsInt() = 2, '2 IAT fixups');
    Check(LResult.AsMap()['fx0'].AsString() = '10,0',
      'fixup 0 correct');
    Check(LResult.AsMap()['fx1'].AsString() = '20,1',
      'fixup 1 correct');
    Check(LResult.AsMap()['ndfix'].AsInt() = 1, '1 data fixup');
  end);

  // Builder 4: PE exit 42 via builders
  RegisterTest('Builder_PE_Exit42', procedure
  begin
    LExePath := TUtils.ResolvePath('$P:output\test_builder_exit42.exe');
    RunScript('builders/pe_exit42.lvm',
      'exe_path', '$P:output\test_builder_exit42.exe');
    Check(FLastExitCode = 42, 'Builder PE exit 42');
    Check(FileExists(LExePath), 'Builder PE exe exists');
  end);

  // Builder 5: PE + rdata via builders
  RegisterTest('Builder_PE_RData', procedure
  begin
    LExePath := TUtils.ResolvePath('$P:output\test_builder_rdata.exe');
    RunScript('builders/pe_rdata.lvm',
      'exe_path', '$P:output\test_builder_rdata.exe');
    Check(FLastExitCode = 0, 'Builder PE rdata exited 0');
    Check(FileExists(LExePath), 'Builder PE rdata exe exists');
  end);
end;

procedure TBackendBuilders.Run();
begin
  inherited;
end;

// =========================================================================
//  TBackendFormats -- object format tests
// =========================================================================

{ TBackendFormats }

constructor TBackendFormats.Create();
var
  LObjPath: string;
  LLibPath: string;
begin
  inherited;

  Title := 'Object Formats';

  // Format 1: COFF .obj
  RegisterTest('COFF_Obj_Exports', procedure
  var
    LResult: TLVMValue;
  begin
    LObjPath := TUtils.ResolvePath('$P:output\test_obj.obj');
    RunScript('formats/coff_obj_exports.lvm',
      'obj_path', '$P:output\test_obj.obj');
    LResult := FLVM.GetVar(LVM_RESULT);
    Check(LResult.AsMap()['machine'].AsInt() = 34404,
      'Machine is AMD64 (0x8664)');
    Check(LResult.AsMap()['nsect'].AsInt() = 2,
      '2 sections (.text + .drectve)');
    Check(LResult.AsMap()['opthdr'].AsInt() = 0,
      'No optional header');
    Check(LResult.AsMap()['done'].AsBool() = True,
      'Script completed without error');
    Check(FileExists(LObjPath), 'OBJ file exists');
  end);

  // Format 2: .lib archive
  RegisterTest('Lib_Archive', procedure
  var
    LResult: TLVMValue;
  begin
    LLibPath := TUtils.ResolvePath('$P:output\test_lib.lib');
    RunScript('formats/lib_archive.lvm',
      'lib_path', '$P:output\test_lib.lib');
    LResult := FLVM.GetVar(LVM_RESULT);
    Check(LResult.AsMap()['arsig'].AsBool() = True,
      'AR signature correct');
    Check(LResult.AsMap()['linker_name'].AsInt() = 47,
      'First member is "/" (linker)');
    Check(LResult.AsMap()['done'].AsBool() = True,
      'Script completed without error');
    Check(FileExists(LLibPath), 'LIB file exists');
  end);

  // Format 3: ELF .o
  RegisterTest('ELF_Obj', procedure
  var
    LResult: TLVMValue;
  begin
    LObjPath := TUtils.ResolvePath('$P:output\test_elfobj.o');
    RunScript('formats/elf_obj.lvm',
      'obj_path', '$P:output\test_elfobj.o');
    LResult := FLVM.GetVar(LVM_RESULT);
    Check(LResult.AsMap()['magic'].AsBool() = True,
      'ELF magic correct');
    Check(LResult.AsMap()['etype'].AsInt() = 1,
      'ELF type is ET_REL (1)');
    Check(LResult.AsMap()['emach'].AsInt() = 62,
      'Machine is EM_X86_64');
    Check(LResult.AsMap()['phnum'].AsInt() = 0,
      'No program headers');
    Check(LResult.AsMap()['shnum'].AsInt() = 8,
      '8 section headers');
    Check(LResult.AsMap()['shstrndx'].AsInt() = 7,
      'shstrndx is 7');
    Check(LResult.AsMap()['done'].AsBool() = True,
      'Script completed without error');
    Check(FileExists(LObjPath), 'OBJ file exists');
  end);

  // Format 4: ELF .a archive
  RegisterTest('ELF_Lib', procedure
  var
    LResult: TLVMValue;
  begin
    LLibPath := TUtils.ResolvePath('$P:output\test_elflib.a');
    RunScript('formats/elf_lib.lvm',
      'lib_path', '$P:output\test_elflib.a');
    LResult := FLVM.GetVar(LVM_RESULT);
    Check(LResult.AsMap()['arsig'].AsBool() = True,
      'AR signature correct');
    Check(LResult.AsMap()['linker_name'].AsInt() = 47,
      'First member is "/" (linker)');
    Check(LResult.AsMap()['done'].AsBool() = True,
      'Script completed without error');
    Check(FileExists(LLibPath), 'Archive file exists');
  end);
end;

procedure TBackendFormats.Run();
begin
  inherited;
end;

// =========================================================================
//  TBackendMIR -- MIR pipeline tests
// =========================================================================

{ TBackendMIR }

constructor TBackendMIR.Create();
var
  LExePath: string;
begin
  inherited;
  Title := 'MIR Pipeline';

  RegisterTest('MIR_E2E_Exit42', procedure
  begin
    LExePath := TUtils.ResolvePath('$P:output\test_mir_exit42.exe');
    RunScript('mir/mir_e2e_exit42.lvm',
      'exe_path', '$P:output\test_mir_exit42.exe');
    Check(FLastExitCode = 42, 'MIR pipeline PE exe returned 42');
    Check(TFile.Exists(LExePath), 'MIR pipeline exe exists');
  end);

  RegisterTest('MIR_Full_Pipeline', procedure
  begin
    LExePath := TUtils.ResolvePath('$P:output\mir_full_pipeline.exe');
    RunScript('mir/mir_full_pipeline.lvm');
    Check(FLastExitCode = 0, 'Full pipeline exe exited 0');
    Check(TFile.Exists(LExePath), 'Full pipeline exe exists');
  end);

  RegisterTest('MIR_Full_Pipeline_Src', procedure
  begin
    LExePath := TUtils.ResolvePath('$P:output\say_lang.exe');
    if Assigned(FLVM) then
      FLVM.Free();
    FLVM := TLangVM.Create();
    FLVM.SetOnPrint(
      procedure(const AText: string; const AUserData: Pointer)
      begin
      end, nil);
    FLVM.SourceFilename := TUtils.ResolvePath('$P:res\tests\lvm\backend\mir\hello.say');
    FLVM.LoadScriptFile('$P:res\tests\lvm\backend\mir\say_lang.lvm');
    FLVM.Run(LVM_MAINFUNC);
    FLVM.PrintErrors();
    FLastExitCode := FLVM.ExitCode;
    Check(FLastExitCode = 0, 'Full pipeline src exe exited 0');
    Check(TFile.Exists(LExePath), 'Full pipeline src exe exists');
  end);
end;

procedure TBackendMIR.Run();
begin
  inherited;
end;

end.
