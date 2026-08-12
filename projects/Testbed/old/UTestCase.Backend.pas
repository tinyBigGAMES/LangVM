unit UTestCase.Backend;

interface

uses
  StdApp.TestCase;

type

  { TBackendTestCase }
  TBackendTestCase = class(TTestCase)
  protected
    procedure Run(); override;
  public
    constructor Create(); override;
  end;

implementation

uses
  System.SysUtils,
  StdApp.Utils,
  Myrissa.LVM;

{ TBackendTestCase }

constructor TBackendTestCase.Create();
begin
  inherited;

  Title := 'Backend Tests';

  // -----------------------------------------------------------------------
  // Test 1: mov rax, imm64 + ret -- simplest JIT proof
  // -----------------------------------------------------------------------
  RegisterTest('Encode_MovRaxImm64_Ret', procedure
  var
    LVM: TLVM;
    LOutput: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadSource('''
        routine emit_mov_rax_imm64(buf: any, offset: int, value: int) -> int {
          bufWriteU8(buf, offset, 0x48);
          bufWriteU8(buf, offset + 1, 0xB8);
          bufWriteU8(buf, offset + 2, band(value, 0xFF));
          bufWriteU8(buf, offset + 3, band(shr(value, 8), 0xFF));
          bufWriteU8(buf, offset + 4, band(shr(value, 16), 0xFF));
          bufWriteU8(buf, offset + 5, band(shr(value, 24), 0xFF));
          bufWriteU8(buf, offset + 6, band(shr(value, 32), 0xFF));
          bufWriteU8(buf, offset + 7, band(shr(value, 40), 0xFF));
          bufWriteU8(buf, offset + 8, band(shr(value, 48), 0xFF));
          bufWriteU8(buf, offset + 9, band(shr(value, 56), 0xFF));
          return offset + 10;
        }

        routine emit_ret(buf: any, offset: int) -> int {
          bufWriteU8(buf, offset, 0xC3);
          return offset + 1;
        }

        routine main() {
          let buf = buffer(64, true);
          let off = 0;
          off = emit_mov_rax_imm64(buf, off, 42);
          off = emit_ret(buf, off);
          bufFlush(buf);
          let result = bufCall(buf, 0);
          println(toString(result));
        }
        ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('42'), 'mov rax,42 + ret => 42');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test 2: mov r64, imm64 for RAX, RCX, R8 -- tests REX.B encoding
  // -----------------------------------------------------------------------
  RegisterTest('Encode_MovR64_AllRegs', procedure
  var
    LVM: TLVM;
    LOutput: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadSource('''
        const {
          REG_RAX = 0;
          REG_RCX = 1;
          REG_R8  = 8;
        }

        routine emit_mov_r64_imm64(buf: any, offset: int, reg: int, value: int) -> int {
          let rex = 0x48;
          let regField = reg;
          if reg >= 8 {
            rex = 0x49;
            regField = reg - 8;
          }
          bufWriteU8(buf, offset, rex);
          bufWriteU8(buf, offset + 1, bor(0xB8, regField));
          bufWriteU8(buf, offset + 2, band(value, 0xFF));
          bufWriteU8(buf, offset + 3, band(shr(value, 8), 0xFF));
          bufWriteU8(buf, offset + 4, band(shr(value, 16), 0xFF));
          bufWriteU8(buf, offset + 5, band(shr(value, 24), 0xFF));
          bufWriteU8(buf, offset + 6, band(shr(value, 32), 0xFF));
          bufWriteU8(buf, offset + 7, band(shr(value, 40), 0xFF));
          bufWriteU8(buf, offset + 8, band(shr(value, 48), 0xFF));
          bufWriteU8(buf, offset + 9, band(shr(value, 56), 0xFF));
          return offset + 10;
        }

        routine emit_mov_r64_r64(buf: any, offset: int, dst: int, src: int) -> int {
          let rex = 0x48;
          if src >= 8 {
            rex = bor(rex, 0x04);
          }
          if dst >= 8 {
            rex = bor(rex, 0x01);
          }
          bufWriteU8(buf, offset, rex);
          bufWriteU8(buf, offset + 1, 0x89);
          let srcField = band(src, 7);
          let dstField = band(dst, 7);
          bufWriteU8(buf, offset + 2, bor(0xC0, bor(shl(srcField, 3), dstField)));
          return offset + 3;
        }

        routine emit_ret(buf: any, offset: int) -> int {
          bufWriteU8(buf, offset, 0xC3);
          return offset + 1;
        }

        routine test_reg(buf: any, reg: int, value: int) -> int {
          let off = 0;
          off = emit_mov_r64_imm64(buf, off, reg, value);
          if reg != 0 {
            off = emit_mov_r64_r64(buf, off, 0, reg);
          }
          off = emit_ret(buf, off);
          bufFlush(buf);
          return bufCall(buf, 0);
        }

        routine main() {
          let buf = buffer(64, true);
          println(toString(test_reg(buf, 0, 100)));
          println(toString(test_reg(buf, 1, 200)));
          println(toString(test_reg(buf, 8, 300)));
        }
        ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('100'), 'mov rax,100 => 100');
      Check(LOutput.Contains('200'), 'mov rcx,200; mov rax,rcx => 200');
      Check(LOutput.Contains('300'), 'mov r8,300; mov rax,r8 => 300');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test 3: add r64,r64 and sub r64,r64 arithmetic
  // -----------------------------------------------------------------------
  RegisterTest('Encode_Arithmetic', procedure
  var
    LVM: TLVM;
    LOutput: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadSource('''
        routine emit_mov_r64_imm64(buf: any, offset: int, reg: int, value: int) -> int {
          let rex = 0x48;
          let regField = reg;
          if reg >= 8 {
            rex = 0x49;
            regField = reg - 8;
          }
          bufWriteU8(buf, offset, rex);
          bufWriteU8(buf, offset + 1, bor(0xB8, regField));
          bufWriteU8(buf, offset + 2, band(value, 0xFF));
          bufWriteU8(buf, offset + 3, band(shr(value, 8), 0xFF));
          bufWriteU8(buf, offset + 4, band(shr(value, 16), 0xFF));
          bufWriteU8(buf, offset + 5, band(shr(value, 24), 0xFF));
          bufWriteU8(buf, offset + 6, band(shr(value, 32), 0xFF));
          bufWriteU8(buf, offset + 7, band(shr(value, 40), 0xFF));
          bufWriteU8(buf, offset + 8, band(shr(value, 48), 0xFF));
          bufWriteU8(buf, offset + 9, band(shr(value, 56), 0xFF));
          return offset + 10;
        }

        routine emit_add_r64_r64(buf: any, offset: int, dst: int, src: int) -> int {
          let rex = 0x48;
          if src >= 8 { rex = bor(rex, 0x04); }
          if dst >= 8 { rex = bor(rex, 0x01); }
          bufWriteU8(buf, offset, rex);
          bufWriteU8(buf, offset + 1, 0x01);
          bufWriteU8(buf, offset + 2, bor(0xC0, bor(shl(band(src,7), 3), band(dst,7))));
          return offset + 3;
        }

        routine emit_sub_r64_r64(buf: any, offset: int, dst: int, src: int) -> int {
          let rex = 0x48;
          if src >= 8 { rex = bor(rex, 0x04); }
          if dst >= 8 { rex = bor(rex, 0x01); }
          bufWriteU8(buf, offset, rex);
          bufWriteU8(buf, offset + 1, 0x29);
          bufWriteU8(buf, offset + 2, bor(0xC0, bor(shl(band(src,7), 3), band(dst,7))));
          return offset + 3;
        }

        routine emit_ret(buf: any, offset: int) -> int {
          bufWriteU8(buf, offset, 0xC3);
          return offset + 1;
        }

        routine main() {
          let buf = buffer(128, true);
          let off = 0;

          // add: 30 + 12 = 42
          off = emit_mov_r64_imm64(buf, off, 0, 30);
          off = emit_mov_r64_imm64(buf, off, 1, 12);
          off = emit_add_r64_r64(buf, off, 0, 1);
          off = emit_ret(buf, off);
          bufFlush(buf);
          println("add:" + toString(bufCall(buf, 0)));

          // sub: 50 - 8 = 42
          off = 0;
          off = emit_mov_r64_imm64(buf, off, 0, 50);
          off = emit_mov_r64_imm64(buf, off, 1, 8);
          off = emit_sub_r64_r64(buf, off, 0, 1);
          off = emit_ret(buf, off);
          bufFlush(buf);
          println("sub:" + toString(bufCall(buf, 0)));
        }
        ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('add:42'), 'add rax,rcx = 42');
      Check(LOutput.Contains('sub:42'), 'sub rax,rcx = 42');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test 4: push/pop/sub rsp/add rsp -- prologue/epilogue with shadow space
  // -----------------------------------------------------------------------
  RegisterTest('Encode_PrologueEpilogue', procedure
  var
    LVM: TLVM;
    LOutput: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadSource('''
        const {
          REG_RAX = 0;
          REG_RBX = 3;
          REG_RSP = 4;
          REG_RBP = 5;
        }

        routine emit_push_r64(buf: any, offset: int, reg: int) -> int {
          if reg >= 8 {
            bufWriteU8(buf, offset, 0x41);
            bufWriteU8(buf, offset + 1, bor(0x50, reg - 8));
            return offset + 2;
          }
          bufWriteU8(buf, offset, bor(0x50, reg));
          return offset + 1;
        }

        routine emit_pop_r64(buf: any, offset: int, reg: int) -> int {
          if reg >= 8 {
            bufWriteU8(buf, offset, 0x41);
            bufWriteU8(buf, offset + 1, bor(0x58, reg - 8));
            return offset + 2;
          }
          bufWriteU8(buf, offset, bor(0x58, reg));
          return offset + 1;
        }

        routine emit_sub_rsp_imm8(buf: any, offset: int, value: int) -> int {
          bufWriteU8(buf, offset, 0x48);
          bufWriteU8(buf, offset + 1, 0x83);
          bufWriteU8(buf, offset + 2, 0xEC);
          bufWriteU8(buf, offset + 3, band(value, 0xFF));
          return offset + 4;
        }

        routine emit_add_rsp_imm8(buf: any, offset: int, value: int) -> int {
          bufWriteU8(buf, offset, 0x48);
          bufWriteU8(buf, offset + 1, 0x83);
          bufWriteU8(buf, offset + 2, 0xC4);
          bufWriteU8(buf, offset + 3, band(value, 0xFF));
          return offset + 4;
        }

        routine emit_mov_r64_imm64(buf: any, offset: int, reg: int, value: int) -> int {
          let rex = 0x48;
          let regField = reg;
          if reg >= 8 { rex = 0x49; regField = reg - 8; }
          bufWriteU8(buf, offset, rex);
          bufWriteU8(buf, offset + 1, bor(0xB8, regField));
          bufWriteU8(buf, offset + 2, band(value, 0xFF));
          bufWriteU8(buf, offset + 3, band(shr(value, 8), 0xFF));
          bufWriteU8(buf, offset + 4, band(shr(value, 16), 0xFF));
          bufWriteU8(buf, offset + 5, band(shr(value, 24), 0xFF));
          bufWriteU8(buf, offset + 6, band(shr(value, 32), 0xFF));
          bufWriteU8(buf, offset + 7, band(shr(value, 40), 0xFF));
          bufWriteU8(buf, offset + 8, band(shr(value, 48), 0xFF));
          bufWriteU8(buf, offset + 9, band(shr(value, 56), 0xFF));
          return offset + 10;
        }

        routine emit_mov_r64_r64(buf: any, offset: int, dst: int, src: int) -> int {
          let rex = 0x48;
          if src >= 8 { rex = bor(rex, 0x04); }
          if dst >= 8 { rex = bor(rex, 0x01); }
          bufWriteU8(buf, offset, rex);
          bufWriteU8(buf, offset + 1, 0x89);
          bufWriteU8(buf, offset + 2, bor(0xC0, bor(shl(band(src,7), 3), band(dst,7))));
          return offset + 3;
        }

        routine emit_ret(buf: any, offset: int) -> int {
          bufWriteU8(buf, offset, 0xC3);
          return offset + 1;
        }

        routine main() {
          let buf = buffer(128, true);
          let off = 0;

          // Prologue
          off = emit_push_r64(buf, off, REG_RBP);
          off = emit_mov_r64_r64(buf, off, REG_RBP, REG_RSP);
          off = emit_sub_rsp_imm8(buf, off, 32);

          // Save callee-saved RBX, use it, restore
          off = emit_push_r64(buf, off, REG_RBX);
          off = emit_mov_r64_imm64(buf, off, REG_RBX, 99);
          off = emit_mov_r64_r64(buf, off, REG_RAX, REG_RBX);
          off = emit_pop_r64(buf, off, REG_RBX);

          // Epilogue
          off = emit_add_rsp_imm8(buf, off, 32);
          off = emit_pop_r64(buf, off, REG_RBP);
          off = emit_ret(buf, off);

          bufFlush(buf);
          let result = bufCall(buf, 0);
          println(toString(result));
        }
        ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('99'), 'prologue/epilogue preserves and returns 99');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test 5: Load encode.lvm from file and call routines
  // -----------------------------------------------------------------------
  RegisterTest('Encode_LoadFile', procedure
  var
    LVM: TLVM;
    LOutput: string;
    LPath: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LPath := TUtils.ResolvePath('$P:res\backend\x86_64\encode.lvm');
      LVM.LoadFile(LPath);
      LVM.LoadSource('''
        routine main() {
          let buf = buffer(64, true);
          let off = 0;
          off = emit_mov_r64_imm64(buf, off, REG_RAX, 77);
          off = emit_ret(buf, off);
          bufFlush(buf);
          println(toString(bufCall(buf, 0)));
        }
        ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('77'), 'encode.lvm loaded and working');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Probe 1: shr on high-bit values -- unsigned behavior check
  // -----------------------------------------------------------------------
  RegisterTest('Probe_ShrUnsigned', procedure
  var
    LVM: TLVM;
    LOutput: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadSource('''
        routine main() {
          // 0xDEADBEEF -- high bit of 32-bit range set
          let val = 0xDEADBEEF;
          let hi16 = band(shr(val, 16), 0xFFFF);
          let lo16 = band(val, 0xFFFF);
          println("hi:" + toString(hi16));
          println("lo:" + toString(lo16));

          // Extract bytes from a value with bit 31 set
          let b3 = band(shr(val, 24), 0xFF);
          let b2 = band(shr(val, 16), 0xFF);
          let b1 = band(shr(val, 8), 0xFF);
          let b0 = band(val, 0xFF);
          println("bytes:" + toString(b3) + "," + toString(b2) + "," + toString(b1) + "," + toString(b0));

          // Write to buffer and read back to verify round-trip
          let buf = buffer(8);
          bufWriteU32(buf, 0, val);
          let readback = bufReadU32(buf, 0);
          println("rt:" + toString(readback));
        }
        ''', 'test.lvm');
      LVM.Run('main');
      // 0xDEAD = 57005, 0xBEEF = 48879
      Check(LOutput.Contains('hi:57005'), 'shr 16 extracts high word');
      Check(LOutput.Contains('lo:48879'), 'band extracts low word');
      // 0xDE=222, 0xAD=173, 0xBE=190, 0xEF=239
      Check(LOutput.Contains('bytes:222,173,190,239'), 'byte extraction correct');
      Check(LOutput.Contains('rt:3735928559'), 'bufWriteU32/ReadU32 round-trip');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Probe 2: buffer-to-buffer copy at arbitrary offsets
  // -----------------------------------------------------------------------
  RegisterTest('Probe_BufToBufCopy', procedure
  var
    LVM: TLVM;
    LOutput: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadSource('''
        routine main() {
          // Create "section" buffers
          let text = buffer(16);
          let rdata = buffer(16);

          // Write distinct patterns
          bufWriteU32(text, 0, 0x11223344);
          bufWriteU32(text, 4, 0x55667788);
          bufWriteU32(rdata, 0, 0xAABBCCDD);
          bufWriteU32(rdata, 4, 0xEEFF0011);

          // Create final image, copy sections at specific offsets
          let image = buffer(64);
          // text at offset 0
          bufCopyBytes(text, 0, image, 0, 8);
          // rdata at offset 16 (simulating alignment gap)
          bufCopyBytes(rdata, 0, image, 16, 8);

          // Verify
          println("t0:" + toString(bufReadU32(image, 0)));
          println("t4:" + toString(bufReadU32(image, 4)));
          println("r16:" + toString(bufReadU32(image, 16)));
          println("r20:" + toString(bufReadU32(image, 20)));

          // Verify gap is zero
          println("gap:" + toString(bufReadU32(image, 8)));
        }
        ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('t0:287454020'), 'text[0] = 0x11223344');
      Check(LOutput.Contains('t4:1432778632'), 'text[4] = 0x55667788');
      Check(LOutput.Contains('r16:2864434397'), 'rdata[16] = 0xAABBCCDD');
      Check(LOutput.Contains('r20:4009689105'), 'rdata[20] = 0xEEFF0011');
      Check(LOutput.Contains('gap:0'), 'gap between sections is zero');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Probe 3: scale -- 200+ routines loaded
  // -----------------------------------------------------------------------
  RegisterTest('Probe_ScaleRoutines', procedure
  var
    LVM: TLVM;
    LOutput: string;
    LSource: string;
    I: Integer;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      // Generate 200 routines programmatically
      LSource := '';
      for I := 0 to 199 do
        LSource := LSource + 'routine fn_' + IntToStr(I) +
          '(x: int) -> int { return x + ' + IntToStr(I) + '; }' + #10;
      // main calls a few of them to verify
      LSource := LSource +
        'routine main() {' + #10 +
        '  println(toString(fn_0(100)));' + #10 +
        '  println(toString(fn_99(100)));' + #10 +
        '  println(toString(fn_199(100)));' + #10 +
        '}' + #10;
      LVM.LoadSource(LSource, 'scale.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('100'), 'fn_0(100) = 100');
      Check(LOutput.Contains('199'), 'fn_99(100) = 199');
      Check(LOutput.Contains('299'), 'fn_199(100) = 299');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Probe 4: backpatching -- write placeholder, patch later
  // -----------------------------------------------------------------------
  RegisterTest('Probe_Backpatch', procedure
  var
    LVM: TLVM;
    LOutput: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadSource('''
        routine main() {
          let buf = buffer(64, true);
          let off = 0;

          // Emit: mov rax, <placeholder>; ret
          // The imm64 starts at offset 2
          bufWriteU8(buf, 0, 0x48);
          bufWriteU8(buf, 1, 0xB8);
          // Write placeholder zero
          bufWriteU64(buf, 2, 0);
          bufWriteU8(buf, 10, 0xC3);

          // Now backpatch the immediate with the real value
          bufWriteU64(buf, 2, 12345);

          bufFlush(buf);
          let result = bufCall(buf, 0);
          println(toString(result));

          // Also test patching a 32-bit field mid-buffer
          let data = buffer(32);
          // Write header with placeholder size field at offset 4
          bufWriteU32(data, 0, 0x5A4D);
          bufWriteU32(data, 4, 0);
          // ... later, patch it
          bufWriteU32(data, 4, 512);
          println("patched:" + toString(bufReadU32(data, 4)));
        }
        ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('12345'), 'backpatched imm64 executed correctly');
      Check(LOutput.Contains('patched:512'), 'U32 backpatch reads back');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // PE 1: build a minimal PE64 exe that calls ExitProcess(42)
  // -----------------------------------------------------------------------
  RegisterTest('PE_ExitProcess42', procedure
  var
    LVM: TLVM;
    LOutput: string;
    LExePath: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      // Load the backend
      LVM.LoadFile(TUtils.ResolvePath('$P:res\language\myrissa.lvm'));
      LExePath := TUtils.ResolvePath('$P:output\test_exit42.exe');
      LVM.SetVar('exe_path', TLVMValue.FromString(LExePath));
      LVM.LoadSource('''
          routine main() {
            let code = buffer(64);
            let off = 0;

            // sub rsp, 0x28
            off = emit_sub_rsp_imm8(code, off, 0x28);

            // mov ecx, 42 (B9 2A000000)
            bufWriteU8(code, off, 0xB9);
            bufWriteU32(code, off + 1, 42);
            off = off + 5;

            // call [rip+disp32] -- placeholder, fixup by pe_build_exe
            let call_off = off;
            bufWriteU8(code, off, 0xFF);
            bufWriteU8(code, off + 1, 0x15);
            bufWriteU32(code, off + 2, 0);
            off = off + 6;

            // int3 (safety)
            bufWriteU8(code, off, 0xCC);
            off = off + 1;

            // Build PE
            let fixups = [[call_off, 0]];
            let imports = [["kernel32.dll", ["ExitProcess"]]];
            let image = pe_build_exe(code, off, 0, fixups, imports, nil, 0, [],
                                     nil, 0, []);

            // Save to disk
            createDirsInPath(exe_path);
            bufSave(image, exe_path);
            let exit_code = runPE(exe_path);
            println("exit:" + toString(exit_code));
          }
          ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('exit:42'), 'PE exe returned exit code 42');
      Check(FileExists(LExePath), 'exe file exists on disk');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // ELF 1: build a minimal ELF64 exe that exits with code 42
  // -----------------------------------------------------------------------
  RegisterTest('ELF_Exit42', procedure
  var
    LVM: TLVM;
    LOutput: string;
    LElfPath: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      // Load the backend
      LVM.LoadFile(TUtils.ResolvePath('$P:res\language\myrissa.lvm'));
      LElfPath := TUtils.ResolvePath('$P:output\test_exit42');
      LVM.SetVar('elf_path', TLVMValue.FromString(LElfPath));
      LVM.LoadSource('''
          routine main() {
            let code = buffer(64);
            let off = 0;

            // mov eax, 42 (B8 2A000000)
            bufWriteU8(code, off, 0xB8);
            bufWriteU32(code, off + 1, 42);
            off = off + 5;

            // ret (C3)
            bufWriteU8(code, off, 0xC3);
            off = off + 1;

            // Build ELF -- no imports, entry at offset 0
            let image = elf_build_exe(code, off, 0, [], [], nil, 0, [],
                                      nil, 0, 0, []);

            // Save to disk and run
            createDirsInPath(elf_path + ".tmp");
            bufSave(image, elf_path);
            let exit_code = runELF(elf_path, pathDir(elf_path));
            println("exit:" + toString(exit_code));
          }
          ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('exit:42'), 'ELF exe returned exit code 42');
      Check(FileExists(LElfPath), 'ELF file exists on disk');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // ELF 2: dynamic ELF exe that calls libc exit(99) via GOT
  // -----------------------------------------------------------------------
  RegisterTest('ELF_LibcExit', procedure
  var
    LVM: TLVM;
    LOutput: string;
    LElfPath: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      // Load the backend
      LVM.LoadFile(TUtils.ResolvePath('$P:res\language\myrissa.lvm'));
      LElfPath := TUtils.ResolvePath('$P:output\test_libc_exit');
      LVM.SetVar('elf_path', TLVMValue.FromString(LElfPath));
      LVM.LoadSource('''
          routine main() {
            let code = buffer(64);
            let off = 0;

            // mov edi, 99  (BF 63000000) -- SysV: first int arg in EDI
            bufWriteU8(code, off, 0xBF);
            bufWriteU32(code, off + 1, 99);
            off = off + 5;

            // call [rip+disp32]  (FF 15 00000000) -- GOT fixup fills disp
            let call_off = off;
            bufWriteU8(code, off, 0xFF);
            bufWriteU8(code, off + 1, 0x15);
            bufWriteU32(code, off + 2, 0);
            off = off + 6;

            // Build ELF with one import: exit from libc.so.6
            let fixups = [[call_off, 0]];
            let imports = [["libc.so.6", ["exit"]]];
            let image = elf_build_exe(code, off, 0, fixups, imports, nil, 0, [],
                                      nil, 0, 0, []);

            // Save to disk and run
            createDirsInPath(elf_path + ".tmp");
            bufSave(image, elf_path);
            let exit_code = runELF(elf_path, pathDir(elf_path));
            println("exit:" + toString(exit_code));
          }
          ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('exit:99'), 'ELF dynamic exe returned exit code 99');
      Check(FileExists(LElfPath), 'ELF dynamic file exists on disk');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // PE 2: build PE64 exe with .rdata -- writes "hello!" via WriteFile
  // -----------------------------------------------------------------------
  RegisterTest('PE_WriteStringLiteral', procedure
  var
    LVM: TLVM;
    LOutput: string;
    LExePath: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\language\myrissa.lvm'));
      LExePath := TUtils.ResolvePath('$P:output\test_rdata.exe');
      LVM.SetVar('exe_path', TLVMValue.FromString(LExePath));
      LVM.LoadSource('''
          routine main() {
            let code = buffer(128);
            let off = 0;

            // sub rsp, 0x28 (shadow space + alignment)
            off = emit_sub_rsp_imm8(code, off, 0x28);

            // mov rcx, -11 (STD_OUTPUT_HANDLE)
            // 48 C7 C1 F5FFFFFF  -- mov rcx, 0xFFFFFFFFFFFFFFF5
            bufWriteU8(code, off, 0x48);
            bufWriteU8(code, off + 1, 0xC7);
            bufWriteU8(code, off + 2, 0xC1);
            bufWriteU32(code, off + 3, 0xFFFFFFF5);
            off = off + 7;

            // call [rip+disp32] -- GetStdHandle (IAT[0])
            let call_gsh = off;
            bufWriteU8(code, off, 0xFF);
            bufWriteU8(code, off + 1, 0x15);
            bufWriteU32(code, off + 2, 0);
            off = off + 6;

            // mov rcx, rax (hFile = returned handle)
            off = emit_mov_r64_r64(code, off, REG_RCX, REG_RAX);

            // lea rdx, [rip+disp32] -- lpBuffer = .rdata string (data fixup)
            let lea_off = off;
            off = emit_lea_rip(code, off, REG_RDX, 0);

            // mov r8d, 8  (nNumberOfBytesToWrite)
            // 41 B8 08000000
            bufWriteU8(code, off, 0x41);
            bufWriteU8(code, off + 1, 0xB8);
            bufWriteU32(code, off + 2, 8);
            off = off + 6;

            // xor r9, r9 (lpNumberOfBytesWritten = NULL)
            // 4D 31 C9
            bufWriteU8(code, off, 0x4D);
            bufWriteU8(code, off + 1, 0x31);
            bufWriteU8(code, off + 2, 0xC9);
            off = off + 3;

            // push 0 (lpOverlapped = NULL)
            // 6A 00
            bufWriteU8(code, off, 0x6A);
            bufWriteU8(code, off + 1, 0x00);
            off = off + 2;

            // call [rip+disp32] -- WriteFile (IAT[1])
            let call_wf = off;
            bufWriteU8(code, off, 0xFF);
            bufWriteU8(code, off + 1, 0x15);
            bufWriteU32(code, off + 2, 0);
            off = off + 6;

            // add rsp, 8 (clean up push)
            off = emit_add_rsp_imm8(code, off, 0x08);

            // mov ecx, 0 (exit code)
            bufWriteU8(code, off, 0xB9);
            bufWriteU32(code, off + 1, 0);
            off = off + 5;

            // call [rip+disp32] -- ExitProcess (IAT[2])
            let call_ep = off;
            bufWriteU8(code, off, 0xFF);
            bufWriteU8(code, off + 1, 0x15);
            bufWriteU32(code, off + 2, 0);
            off = off + 6;

            // Build .rdata: "hello!\r\n" (8 bytes)
            let rdata = buffer(8);
            bufWriteU8(rdata, 0, 0x68);
            bufWriteU8(rdata, 1, 0x65);
            bufWriteU8(rdata, 2, 0x6C);
            bufWriteU8(rdata, 3, 0x6C);
            bufWriteU8(rdata, 4, 0x6F);
            bufWriteU8(rdata, 5, 0x21);
            bufWriteU8(rdata, 6, 0x0D);
            bufWriteU8(rdata, 7, 0x0A);

            let iat_fixups = [[call_gsh, 0], [call_wf, 1], [call_ep, 2]];
            let imports = [["kernel32.dll", ["GetStdHandle", "WriteFile", "ExitProcess"]]];
            let data_fixups = [[lea_off, 0]];
            let image = pe_build_exe(code, off, 0, iat_fixups, imports,
                                     rdata, 8, data_fixups,
                                     nil, 0, []);

            createDirsInPath(exe_path);
            bufSave(image, exe_path);
            let exit_code = runPE(exe_path);
            println("exit:" + toString(exit_code));
          }
          ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('exit:0'), 'PE rdata exe exited 0');
      Check(FileExists(LExePath), 'PE rdata exe file exists');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // ELF 2b: static ELF with .rodata -- write syscall + exit 42
  // -----------------------------------------------------------------------
  RegisterTest('ELF_RoDataRef', procedure
  var
    LVM: TLVM;
    LOutput: string;
    LElfPath: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\language\myrissa.lvm'));
      LElfPath := TUtils.ResolvePath('$P:output\test_rodata');
      LVM.SetVar('elf_path', TLVMValue.FromString(LElfPath));
      LVM.LoadSource('''
          routine main() {
            let code = buffer(64);
            let off = 0;

            // mov edi, 1         (BF 01000000) -- fd = stdout
            bufWriteU8(code, off, 0xBF);
            bufWriteU32(code, off + 1, 1);
            off = off + 5;

            // lea rsi, [rip+disp32]  (48 8D 35 xxxxxxxx) -- buf = .rodata
            let lea_off = off;
            off = emit_lea_rip(code, off, REG_RSI, 0);

            // mov edx, 7         (BA 07000000) -- count = 7
            bufWriteU8(code, off, 0xBA);
            bufWriteU32(code, off + 1, 7);
            off = off + 5;

            // mov eax, 1         (B8 01000000) -- SYS_write
            bufWriteU8(code, off, 0xB8);
            bufWriteU32(code, off + 1, 1);
            off = off + 5;

            // syscall            (0F 05)
            bufWriteU8(code, off, 0x0F);
            bufWriteU8(code, off + 1, 0x05);
            off = off + 2;

            // mov eax, 42        (B8 2A000000) -- exit code
            bufWriteU8(code, off, 0xB8);
            bufWriteU32(code, off + 1, 42);
            off = off + 5;

            // ret                (C3)
            bufWriteU8(code, off, 0xC3);
            off = off + 1;

            // Build .rodata: "hello!\n" (7 bytes)
            let rodata = buffer(7);
            bufWriteU8(rodata, 0, 0x68);
            bufWriteU8(rodata, 1, 0x65);
            bufWriteU8(rodata, 2, 0x6C);
            bufWriteU8(rodata, 3, 0x6C);
            bufWriteU8(rodata, 4, 0x6F);
            bufWriteU8(rodata, 5, 0x21);
            bufWriteU8(rodata, 6, 0x0A);

            let data_fixups = [[lea_off, 0]];
            let image = elf_build_exe(code, off, 0, [], [],
                                      rodata, 7, data_fixups,
                                      nil, 0, 0, []);

            createDirsInPath(elf_path + ".tmp");
            bufSave(image, elf_path);
            let exit_code = runELF(elf_path, pathDir(elf_path));
            println("exit:" + toString(exit_code));
          }
          ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('exit:42'), 'ELF rodata exe returned exit code 42');
      Check(FileExists(LElfPath), 'ELF rodata file exists');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // PE 3: build PE64 exe with .data -- store 42 in writable global, load, exit
  // -----------------------------------------------------------------------
  RegisterTest('PE_DataSection', procedure
  var
    LVM: TLVM;
    LOutput: string;
    LExePath: string;
  begin
    LVM := TLVM.Create();
    try
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LExePath := TUtils.ResolvePath('$P:output\test_data.exe');
      LVM.LoadFile(TUtils.ResolvePath('$P:res\language\myrissa.lvm'));
      LVM.SetVar('exe_path', TLVMValue.FromString(LExePath));
      LVM.LoadSource('''
          routine main() {
            let code = buffer(64);
            let off = 0;

            let imports = [["kernel32.dll", ["ExitProcess"]]];
            let iat_fixups = [];
            let data_fixups = [];
            let global_fixups = [];

            // Build .data: one 8-byte int = 42
            let wdata = buffer(8);
            bufWriteU64(wdata, 0, 42);

            // Prologue: sub rsp, 0x28 (shadow space + alignment)
            off = emit_sub_rsp_imm8(code, off, 0x28);

            // LEA RAX, [RIP+disp32] -> .data offset 0 (global fixup)
            let lea_off = off;
            off = emit_lea_rip(code, off, REG_RAX, 0);
            listAppend(global_fixups, [lea_off, 0]);

            // MOV RAX, [RAX+0] -- load the 64-bit value
            off = emit_mov_r64_base_disp(code, off, REG_RAX, REG_RAX, 0);

            // MOV RCX, RAX -- ExitProcess(42)
            off = emit_mov_r64_r64(code, off, REG_RCX, REG_RAX);

            // CALL [RIP+disp32] -> ExitProcess
            let call_off = off;
            off = emit_call_indirect_rip(code, off, 0);
            listAppend(iat_fixups, [call_off, 0]);

            let image = pe_build_exe(code, off, 0, iat_fixups, imports,
                                     nil, 0, data_fixups,
                                     wdata, 8, global_fixups);
            createDirsInPath(exe_path);
            bufSave(image, exe_path);
            let exit_code = runPE(exe_path);
            println("exit:" + toString(exit_code));
          }
      ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('exit:42'), 'PE .data exe exited 42');
      Check(FileExists(LExePath), 'PE .data exe file exists');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // ELF 3: static ELF with .data -- store 42 in writable global, load, exit
  // -----------------------------------------------------------------------
  RegisterTest('ELF_DataSection', procedure
  var
    LVM: TLVM;
    LOutput: string;
    LElfPath: string;
  begin
    LVM := TLVM.Create();
    try
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LElfPath := TUtils.ResolvePath('$P:output\test_data_elf');
      LVM.LoadFile(TUtils.ResolvePath('$P:res\language\myrissa.lvm'));
      LVM.SetVar('elf_path', TLVMValue.FromString(LElfPath));
      LVM.LoadSource('''
          routine main() {
            let code = buffer(64);
            let off = 0;

            let global_fixups = [];
            let data_fixups = [];

            // Build .data: one 8-byte int = 42
            let wdata = buffer(8);
            bufWriteU64(wdata, 0, 42);

            // LEA RAX, [RIP+disp32] -> .data offset 0
            let lea_off = off;
            off = emit_lea_rip(code, off, REG_RAX, 0);
            listAppend(global_fixups, [lea_off, 0]);

            // MOV RAX, [RAX+0] -- load value
            off = emit_mov_r64_base_disp(code, off, REG_RAX, REG_RAX, 0);

            // MOV RDI, RAX -- exit code
            off = emit_mov_r64_r64(code, off, REG_RDI, REG_RAX);

            // MOV RAX, 60 -- sys_exit
            off = emit_mov_r64_imm64(code, off, REG_RAX, 60);

            // SYSCALL
            bufWriteU8(code, off, 0x0F);
            off = off + 1;
            bufWriteU8(code, off, 0x05);
            off = off + 1;

            let image = elf_build_exe(code, off, 0, [], [],
                                      nil, 0, data_fixups,
                                      wdata, 8, 0, global_fixups);
            createDirsInPath(elf_path + ".tmp");
            bufSave(image, elf_path);
            let result = runELF(elf_path, pathDir(elf_path));
            println("exit:" + toString(result));
          }
      ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('exit:42'), 'ELF .data exe exited 42');
      Check(FileExists(LElfPath), 'ELF .data file exists');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test: call rel32 -- two functions in one JIT buffer
  // func_add at offset 0: mov rax,rcx; add rax,rdx; ret
  // func_main calls func_add(30, 12) => 42
  // -----------------------------------------------------------------------
  RegisterTest('Encode_CallRel32', procedure
  var
    LVM: TLVM;
    LOutput: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\backend\x86_64\encode.lvm'));
      LVM.LoadSource('''
        routine main() {
          let buf = buffer(128, true);

          // func_add at offset 0: mov rax,rcx; add rax,rdx; ret
          let off = 0;
          off = emit_mov_r64_r64(buf, off, REG_RAX, REG_RCX);
          off = emit_add_r64_r64(buf, off, REG_RAX, REG_RDX);
          off = emit_ret(buf, off);
          let func_add_end = off;

          // func_main: mov rcx,30; mov rdx,12; call func_add; ret
          let main_start = off;
          off = emit_mov_r64_imm64(buf, off, REG_RCX, 30);
          off = emit_mov_r64_imm64(buf, off, REG_RDX, 12);
          // call rel32: disp = target - (call_addr + 5)
          let call_addr = off;
          let disp = 0 - (call_addr + 5);
          off = emit_call_rel32(buf, off, disp);
          off = emit_ret(buf, off);

          bufFlush(buf);
          let result = bufCall(buf, main_start);
          println(toString(result));
        }
        ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('42'), 'call rel32: func_add(30,12) = 42');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test: cmp + jcc -- conditional branch (JG skips over mov rax,0)
  // mov rax,10; cmp rax,5; jg skip; mov rax,0; skip: ret
  // 10 > 5 so JG taken, result = 10
  // -----------------------------------------------------------------------
  RegisterTest('Encode_CmpJcc', procedure
  var
    LVM: TLVM;
    LOutput: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\backend\x86_64\encode.lvm'));
      LVM.LoadSource('''
        routine main() {
          let buf = buffer(128, true);
          let off = 0;

          // mov rax, 10
          off = emit_mov_r64_imm64(buf, off, REG_RAX, 10);
          // cmp rax, 5
          off = emit_cmp_rax_imm32(buf, off, 5);
          // jg skip (skip over the next mov rax,0 which is 10 bytes)
          let jcc_off = off;
          off = emit_jcc_rel32(buf, off, CC_JG, 10);
          // mov rax, 0 (this is 10 bytes: REX+opcode+imm64)
          off = emit_mov_r64_imm64(buf, off, REG_RAX, 0);
          // skip: ret
          off = emit_ret(buf, off);

          bufFlush(buf);
          let result = bufCall(buf, 0);
          println(toString(result));
        }
        ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('10'), 'cmp+jg: 10>5 so branch taken, result=10');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test: test + jne/jmp -- check zero vs nonzero
  // Two calls: value=0 => returns 0, value=7 => returns 1
  // -----------------------------------------------------------------------
  RegisterTest('Encode_TestJmp', procedure
  var
    LVM: TLVM;
    LOutput: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\backend\x86_64\encode.lvm'));
      LVM.LoadSource('''
        routine test_value(value: int) -> int {
          let buf = buffer(128, true);
          let off = 0;

          // mov rax, value
          off = emit_mov_r64_imm64(buf, off, REG_RAX, value);
          // test rax, rax
          off = emit_test_r64_r64(buf, off, REG_RAX, REG_RAX);
          // jne nonzero (skip mov rax,0 + jmp = 10 + 5 = 15 bytes)
          off = emit_jcc_rel32(buf, off, CC_JNE, 15);
          // zero path: mov rax, 0; jmp done
          off = emit_mov_r64_imm64(buf, off, REG_RAX, 0);
          let jmp_off = off;
          // jmp done (skip mov rax,1 = 10 bytes)
          off = emit_jmp_rel32(buf, off, 10);
          // nonzero: mov rax, 1
          off = emit_mov_r64_imm64(buf, off, REG_RAX, 1);
          // done: ret
          off = emit_ret(buf, off);

          bufFlush(buf);
          return bufCall(buf, 0);
        }

        routine main() {
          println("z:" + toString(test_value(0)));
          println("nz:" + toString(test_value(7)));
        }
        ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('z:0'), 'test rax,rax: value=0 returns 0');
      Check(LOutput.Contains('nz:1'), 'test rax,rax: value=7 returns 1');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test: base+displacement MOV (local variable simulation via RBP and RSP)
  // -----------------------------------------------------------------------
  RegisterTest('Encode_BaseDisp', procedure
  var
    LVM: TLVM;
    LOutput: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\backend\x86_64\encode.lvm'));
      LVM.LoadSource('''
        routine test_rbp_local() -> int {
          let buf = buffer(128, true);
          let off = 0;

          // push rbp
          off = emit_push_r64(buf, off, REG_RBP);
          // mov rbp, rsp
          off = emit_mov_r64_r64(buf, off, REG_RBP, REG_RSP);
          // sub rsp, 16
          off = emit_sub_rsp_imm8(buf, off, 16);

          // mov rax, 42
          off = emit_mov_r64_imm64(buf, off, REG_RAX, 42);
          // mov [rbp-8], rax (store local)
          off = emit_mov_base_disp_r64(buf, off, REG_RBP, -8, REG_RAX);
          // xor rax, rax (clear)
          off = emit_xor_r32_r32(buf, off, REG_RAX, REG_RAX);
          // mov rax, [rbp-8] (load local)
          off = emit_mov_r64_base_disp(buf, off, REG_RAX, REG_RBP, -8);

          // add rsp, 16
          off = emit_add_rsp_imm8(buf, off, 16);
          // pop rbp
          off = emit_pop_r64(buf, off, REG_RBP);
          // ret
          off = emit_ret(buf, off);

          bufFlush(buf);
          return bufCall(buf, 0);
        }

        routine test_rsp_local() -> int {
          let buf = buffer(128, true);
          let off = 0;

          // sub rsp, 32
          off = emit_sub_rsp_imm8(buf, off, 32);

          // mov rax, 99
          off = emit_mov_r64_imm64(buf, off, REG_RAX, 99);
          // mov [rsp+0], rax (store via RSP -- triggers SIB)
          off = emit_mov_base_disp_r64(buf, off, REG_RSP, 0, REG_RAX);
          // xor rax, rax
          off = emit_xor_r32_r32(buf, off, REG_RAX, REG_RAX);
          // mov rax, [rsp+0] (load via RSP -- triggers SIB)
          off = emit_mov_r64_base_disp(buf, off, REG_RAX, REG_RSP, 0);

          // add rsp, 32
          off = emit_add_rsp_imm8(buf, off, 32);
          // ret
          off = emit_ret(buf, off);

          bufFlush(buf);
          return bufCall(buf, 0);
        }

        routine main() {
          println("rbp:" + toString(test_rbp_local()));
          println("rsp:" + toString(test_rsp_local()));
        }
        ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('rbp:42'), 'RBP-relative local store/load returns 42');
      Check(LOutput.Contains('rsp:99'), 'RSP-relative (SIB) store/load returns 99');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test: CALL [RIP+disp32] (indirect call through GOT-style slot)
  // -----------------------------------------------------------------------
  RegisterTest('Encode_CallIndirectRip', procedure
  var
    LVM: TLVM;
    LOutput: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\backend\x86_64\encode.lvm'));
      LVM.LoadSource('''
        routine main() {
          let buf = buffer(256, true);

          // func_add at offset 0: mov rax,rcx; add rax,rdx; ret
          let off = 0;
          off = emit_mov_r64_r64(buf, off, REG_RAX, REG_RCX);
          off = emit_add_r64_r64(buf, off, REG_RAX, REG_RDX);
          off = emit_ret(buf, off);
          // off is now 7 (3+3+1)

          // Pad to offset 16 for alignment (GOT slot at 8, code at 16)
          // GOT slot: 8 bytes at offset 8
          // Write func_add absolute address into GOT slot
          let func_addr = bufPtr(buf);
          bufWriteU64(buf, 8, func_addr);

          // func_main at offset 16:
          let main_off = 16;
          // mov rcx, 30
          main_off = emit_mov_r64_imm64(buf, main_off, REG_RCX, 30);
          // mov rdx, 12
          main_off = emit_mov_r64_imm64(buf, main_off, REG_RDX, 12);
          // call [rip+disp32] -- disp = GOT_addr - (call_addr + 6)
          // GOT is at buf+8, call instruction is at buf+main_off
          // disp = (8) - (main_off + 6)
          let call_pos = main_off;
          let disp = 8 - (call_pos + 6);
          main_off = emit_call_indirect_rip(buf, main_off, disp);
          // ret
          main_off = emit_ret(buf, main_off);

          bufFlush(buf);
          let result = bufCall(buf, 16);
          println("indirect:" + toString(result));
        }
        ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('indirect:42'), 'CALL [RIP+disp32] via GOT slot returns 42');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test: MOV r64,[RIP+disp32] and MOV [RIP+disp32],r64 (RIP-relative load/store)
  // -----------------------------------------------------------------------
  RegisterTest('Encode_MovRipRelative', procedure
  var
    LVM: TLVM;
    LOutput: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\backend\x86_64\encode.lvm'));
      LVM.LoadSource('''
        routine main() {
          let buf = buffer(256, true);

          // "global variable" at offset 0: 8 bytes, initialized to 0
          bufWriteU64(buf, 0, 0);

          // code starts at offset 8
          let off = 8;

          // mov rax, 77
          off = emit_mov_r64_imm64(buf, off, REG_RAX, 77);
          // mov [rip+disp], rax -- store 77 to global at offset 0
          // disp = target - (instr_addr + 7) = 0 - (off + 7)
          let store_disp = 0 - (off + 7);
          off = emit_mov_rip_r64(buf, off, REG_RAX, store_disp);

          // xor rax, rax (clear)
          off = emit_xor_r32_r32(buf, off, REG_RAX, REG_RAX);

          // mov rax, [rip+disp] -- load global back from offset 0
          // disp = target - (instr_addr + 7) = 0 - (off + 7)
          let load_disp = 0 - (off + 7);
          off = emit_mov_r64_rip(buf, off, REG_RAX, load_disp);

          // ret
          off = emit_ret(buf, off);

          bufFlush(buf);
          let result = bufCall(buf, 8);
          println("rip:" + toString(result));
        }
        ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('rip:77'), 'RIP-relative store/load returns 77');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test: IMUL r64,r64 and IDIV r64 (multiply and divide)
  // -----------------------------------------------------------------------
  RegisterTest('Encode_ImulIdiv', procedure
  var
    LVM: TLVM;
    LOutput: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\backend\x86_64\encode.lvm'));
      LVM.LoadSource('''
        routine test_imul() -> int {
          let buf = buffer(64, true);
          let off = 0;
          // mov rax, 7
          off = emit_mov_r64_imm64(buf, off, REG_RAX, 7);
          // mov rcx, 6
          off = emit_mov_r64_imm64(buf, off, REG_RCX, 6);
          // imul rax, rcx -> rax = 42
          off = emit_imul_r64_r64(buf, off, REG_RAX, REG_RCX);
          off = emit_ret(buf, off);
          bufFlush(buf);
          return bufCall(buf, 0);
        }

        routine test_idiv() -> int {
          let buf = buffer(64, true);
          let off = 0;
          // mov rax, 85
          off = emit_mov_r64_imm64(buf, off, REG_RAX, 85);
          // cqo (sign-extend rax into rdx:rax)
          off = emit_cqo(buf, off);
          // mov rcx, 2
          off = emit_mov_r64_imm64(buf, off, REG_RCX, 2);
          // idiv rcx -> rax = 42, rdx = 1
          off = emit_idiv_r64(buf, off, REG_RCX);
          off = emit_ret(buf, off);
          bufFlush(buf);
          return bufCall(buf, 0);
        }

        routine main() {
          println("imul:" + toString(test_imul()));
          println("idiv:" + toString(test_idiv()));
        }
        ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('imul:42'), 'IMUL 7*6 = 42');
      Check(LOutput.Contains('idiv:42'), 'IDIV 85/2 = 42');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test: NEG and NOT
  // -----------------------------------------------------------------------
  RegisterTest('Encode_NegNot', procedure
  var
    LVM: TLVM;
    LOutput: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\backend\x86_64\encode.lvm'));
      LVM.LoadSource('''
        routine test_neg() -> int {
          let buf = buffer(64, true);
          let off = 0;
          // mov rax, -42
          off = emit_mov_r64_imm64(buf, off, REG_RAX, -42);
          // neg rax -> rax = 42
          off = emit_neg_r64(buf, off, REG_RAX);
          off = emit_ret(buf, off);
          bufFlush(buf);
          return bufCall(buf, 0);
        }

        routine test_not() -> int {
          let buf = buffer(64, true);
          let off = 0;
          // mov rax, 0
          off = emit_mov_r64_imm64(buf, off, REG_RAX, 0);
          // not rax -> rax = 0xFFFFFFFFFFFFFFFF = -1
          off = emit_not_r64(buf, off, REG_RAX);
          off = emit_ret(buf, off);
          bufFlush(buf);
          return bufCall(buf, 0);
        }

        routine main() {
          println("neg:" + toString(test_neg()));
          println("not:" + toString(test_not()));
        }
        ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('neg:42'), 'NEG(-42) = 42');
      Check(LOutput.Contains('not:-1'), 'NOT(0) = -1');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test: SHL/SHR/SAR by CL
  // -----------------------------------------------------------------------
  RegisterTest('Encode_Shifts', procedure
  var
    LVM: TLVM;
    LOutput: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\backend\x86_64\encode.lvm'));
      LVM.LoadSource('''
        routine test_shl() -> int {
          let buf = buffer(64, true);
          let off = 0;
          // mov rax, 1
          off = emit_mov_r64_imm64(buf, off, REG_RAX, 1);
          // mov rcx, 5 (shift count in CL)
          off = emit_mov_r64_imm64(buf, off, REG_RCX, 5);
          // shl rax, cl -> 1 << 5 = 32
          off = emit_shl_r64_cl(buf, off, REG_RAX);
          off = emit_ret(buf, off);
          bufFlush(buf);
          return bufCall(buf, 0);
        }

        routine test_shr() -> int {
          let buf = buffer(64, true);
          let off = 0;
          // mov rax, 320
          off = emit_mov_r64_imm64(buf, off, REG_RAX, 320);
          // mov rcx, 3
          off = emit_mov_r64_imm64(buf, off, REG_RCX, 3);
          // shr rax, cl -> 320 >> 3 = 40
          off = emit_shr_r64_cl(buf, off, REG_RAX);
          off = emit_ret(buf, off);
          bufFlush(buf);
          return bufCall(buf, 0);
        }

        routine test_sar() -> int {
          let buf = buffer(64, true);
          let off = 0;
          // mov rax, -16
          off = emit_mov_r64_imm64(buf, off, REG_RAX, -16);
          // mov rcx, 2
          off = emit_mov_r64_imm64(buf, off, REG_RCX, 2);
          // sar rax, cl -> -16 >> 2 = -4
          off = emit_sar_r64_cl(buf, off, REG_RAX);
          off = emit_ret(buf, off);
          bufFlush(buf);
          return bufCall(buf, 0);
        }

        routine main() {
          println("shl:" + toString(test_shl()));
          println("shr:" + toString(test_shr()));
          println("sar:" + toString(test_sar()));
        }
        ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('shl:32'), 'SHL 1<<5 = 32');
      Check(LOutput.Contains('shr:40'), 'SHR 320>>3 = 40');
      Check(LOutput.Contains('sar:-4'), 'SAR -16>>2 = -4');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test: MOVZX r32,r8 and MOVSXD r64,r32
  // -----------------------------------------------------------------------
  RegisterTest('Encode_MovzxMovsxd', procedure
  var
    LVM: TLVM;
    LOutput: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\backend\x86_64\encode.lvm'));
      LVM.LoadSource('''
        routine test_movzx() -> int {
          let buf = buffer(64, true);
          let off = 0;
          // mov rax, 0x12345678AABB00FF
          off = emit_mov_r64_imm64(buf, off, REG_RAX, 0x00000000000000FF);
          // movzx eax, al -> rax = 0xFF = 255
          off = emit_movzx_r32_r8(buf, off, REG_RAX, REG_RAX);
          off = emit_ret(buf, off);
          bufFlush(buf);
          return bufCall(buf, 0);
        }

        routine test_movsxd() -> int {
          let buf = buffer(64, true);
          let off = 0;
          // Put a negative 32-bit value in eax
          // mov rax, 0x00000000FFFFFFD6 (= -42 as uint32)
          off = emit_mov_r64_imm64(buf, off, REG_RAX, 0xFFFFFFD6);
          // movsxd rax, eax -> sign-extend to -42
          off = emit_movsxd_r64_r32(buf, off, REG_RAX, REG_RAX);
          off = emit_ret(buf, off);
          bufFlush(buf);
          return bufCall(buf, 0);
        }

        routine main() {
          println("movzx:" + toString(test_movzx()));
          println("movsxd:" + toString(test_movsxd()));
        }
        ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('movzx:255'), 'MOVZX zero-extends byte to 64');
      Check(LOutput.Contains('movsxd:-42'), 'MOVSXD sign-extends 32 to 64');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test: Float arithmetic via SSE2 (addsd, mulsd, cvtsi2sd, cvttsd2si)
  // -----------------------------------------------------------------------
  RegisterTest('Encode_FloatArith', procedure
  var
    LVM: TLVM;
    LOutput: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\backend\x86_64\encode.lvm'));
      LVM.LoadSource('''
        routine test_float_add() -> int {
          let buf = buffer(128, true);
          let off = 0;

          // cvtsi2sd xmm0, rax (convert 30 to 30.0)
          off = emit_mov_r64_imm64(buf, off, REG_RAX, 30);
          off = emit_cvtsi2sd_xmm_r64(buf, off, REG_XMM0, REG_RAX);

          // cvtsi2sd xmm1, rax (convert 12 to 12.0)
          off = emit_mov_r64_imm64(buf, off, REG_RAX, 12);
          off = emit_cvtsi2sd_xmm_r64(buf, off, REG_XMM1, REG_RAX);

          // addsd xmm0, xmm1 -> 42.0
          off = emit_addsd_xmm_xmm(buf, off, REG_XMM0, REG_XMM1);

          // cvttsd2si rax, xmm0 -> 42
          off = emit_cvttsd2si_r64_xmm(buf, off, REG_RAX, REG_XMM0);

          off = emit_ret(buf, off);
          bufFlush(buf);
          return bufCall(buf, 0);
        }

        routine test_float_mul() -> int {
          let buf = buffer(128, true);
          let off = 0;

          // 7 * 6 = 42 via float
          off = emit_mov_r64_imm64(buf, off, REG_RAX, 7);
          off = emit_cvtsi2sd_xmm_r64(buf, off, REG_XMM0, REG_RAX);
          off = emit_mov_r64_imm64(buf, off, REG_RAX, 6);
          off = emit_cvtsi2sd_xmm_r64(buf, off, REG_XMM1, REG_RAX);
          off = emit_mulsd_xmm_xmm(buf, off, REG_XMM0, REG_XMM1);
          off = emit_cvttsd2si_r64_xmm(buf, off, REG_RAX, REG_XMM0);

          off = emit_ret(buf, off);
          bufFlush(buf);
          return bufCall(buf, 0);
        }

        routine main() {
          println("fadd:" + toString(test_float_add()));
          println("fmul:" + toString(test_float_mul()));
        }
        ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('fadd:42'), 'ADDSD 30.0+12.0 truncated to 42');
      Check(LOutput.Contains('fmul:42'), 'MULSD 7.0*6.0 truncated to 42');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test: Float sub/div and UCOMISD comparison
  // -----------------------------------------------------------------------
  RegisterTest('Encode_FloatSubDivCmp', procedure
  var
    LVM: TLVM;
    LOutput: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\backend\x86_64\encode.lvm'));
      LVM.LoadSource('''
        routine test_float_div() -> int {
          let buf = buffer(128, true);
          let off = 0;

          // 84 / 2 = 42 via float
          off = emit_mov_r64_imm64(buf, off, REG_RAX, 84);
          off = emit_cvtsi2sd_xmm_r64(buf, off, REG_XMM0, REG_RAX);
          off = emit_mov_r64_imm64(buf, off, REG_RAX, 2);
          off = emit_cvtsi2sd_xmm_r64(buf, off, REG_XMM1, REG_RAX);
          off = emit_divsd_xmm_xmm(buf, off, REG_XMM0, REG_XMM1);
          off = emit_cvttsd2si_r64_xmm(buf, off, REG_RAX, REG_XMM0);

          off = emit_ret(buf, off);
          bufFlush(buf);
          return bufCall(buf, 0);
        }

        routine test_float_sub() -> int {
          let buf = buffer(128, true);
          let off = 0;

          // 50 - 8 = 42 via float
          off = emit_mov_r64_imm64(buf, off, REG_RAX, 50);
          off = emit_cvtsi2sd_xmm_r64(buf, off, REG_XMM0, REG_RAX);
          off = emit_mov_r64_imm64(buf, off, REG_RAX, 8);
          off = emit_cvtsi2sd_xmm_r64(buf, off, REG_XMM1, REG_RAX);
          off = emit_subsd_xmm_xmm(buf, off, REG_XMM0, REG_XMM1);
          off = emit_cvttsd2si_r64_xmm(buf, off, REG_RAX, REG_XMM0);

          off = emit_ret(buf, off);
          bufFlush(buf);
          return bufCall(buf, 0);
        }

        routine main() {
          println("fdiv:" + toString(test_float_div()));
          println("fsub:" + toString(test_float_sub()));
        }
        ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('fdiv:42'), 'DIVSD 84.0/2.0 truncated to 42');
      Check(LOutput.Contains('fsub:42'), 'SUBSD 50.0-8.0 truncated to 42');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test: ABI Win64 prologue/epilogue via abi.lvm routines
  // -----------------------------------------------------------------------
  RegisterTest('ABI_Win64_Prologue', procedure
  var
    LVM: TLVM;
    LOutput: string;
    LExePath: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\language\myrissa.lvm'));
      LExePath := TUtils.ResolvePath('$P:output\test_abi_prologue.exe');
      LVM.SetVar('exe_path', TLVMValue.FromString(LExePath));
      LVM.LoadSource('''
          routine main() {
            let code = buffer(256);
            let off = 0;

            // ABI prologue with frame for 1 local + 1 outgoing call arg
            let frame = abi_frame_size(8, 1, 1);
            off = abi_emit_prologue(code, off, frame);

            // mov ecx, 42 (ExitProcess argument)
            off = emit_mov_r64_imm64(code, off, REG_RCX, 42);

            // call [rip+disp32] -- ExitProcess, fixup by pe_build_exe
            let call_off = off;
            bufWriteU8(code, off, 0xFF);
            bufWriteU8(code, off + 1, 0x15);
            bufWriteU32(code, off + 2, 0);
            off = off + 6;

            // Build PE
            let fixups = [[call_off, 0]];
            let imports = [["kernel32.dll", ["ExitProcess"]]];
            let image = pe_build_exe(code, off, 0, fixups, imports, nil, 0, [],
                                     nil, 0, []);

            createDirsInPath(exe_path);
            bufSave(image, exe_path);
            let exit_code = runPE(exe_path);
            println("exit:" + toString(exit_code));
          }
          ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('exit:42'), 'ABI prologue PE exe returned 42');
      Check(FileExists(LExePath), 'ABI prologue exe exists on disk');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test: ABI Win64 call argument setup
  // -----------------------------------------------------------------------
  RegisterTest('ABI_Win64_CallArgs', procedure
  var
    LVM: TLVM;
    LOutput: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\language\myrissa.lvm'));
      LVM.LoadSource('''
          routine main() {
            let buf = buffer(128, true);
            let off = 0;

            // Test abi_win64_arg_reg returns correct registers
            let r0 = abi_win64_arg_reg(0);
            let r1 = abi_win64_arg_reg(1);
            let r2 = abi_win64_arg_reg(2);
            let r3 = abi_win64_arg_reg(3);
            let r4 = abi_win64_arg_reg(4);

            // Verify: RCX=1, RDX=2, R8=8, R9=9, stack=-1
            println(toString(r0) + "," + toString(r1) + "," +
                    toString(r2) + "," + toString(r3) + "," +
                    toString(r4));

            // Test stack alignment
            println(toString(abi_stack_align(1)));
            println(toString(abi_stack_align(16)));
            println(toString(abi_stack_align(17)));

            // Test frame size
            println(toString(abi_frame_size(0, 0, 1)));
            println(toString(abi_frame_size(32, 4, 1)));

            // Test param offset
            println(toString(abi_param_offset(0)));
            println(toString(abi_param_offset(1)));
          }
          ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('1,2,8,9,-1'), 'Win64 arg regs correct');
      Check(LOutput.Contains('16'), 'align 1 -> 16');
      Check(LOutput.Contains('32'), 'align 17 -> 32');
      Check(LOutput.Contains('-40'), 'param 0 offset = -40');
      Check(LOutput.Contains('-48'), 'param 1 offset = -48');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test: ABI SysV arg register assignment
  // -----------------------------------------------------------------------
  RegisterTest('ABI_SysV_ArgRegs', procedure
  var
    LVM: TLVM;
    LOutput: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\language\myrissa.lvm'));
      LVM.LoadSource('''
          routine main() {
            // SysV: RDI=7, RSI=6, RDX=2, RCX=1, R8=8, R9=9
            let r0 = abi_sysv_arg_reg(0);
            let r1 = abi_sysv_arg_reg(1);
            let r2 = abi_sysv_arg_reg(2);
            let r3 = abi_sysv_arg_reg(3);
            let r4 = abi_sysv_arg_reg(4);
            let r5 = abi_sysv_arg_reg(5);
            let r6 = abi_sysv_arg_reg(6);
            println(toString(r0) + "," + toString(r1) + "," +
                    toString(r2) + "," + toString(r3) + "," +
                    toString(r4) + "," + toString(r5) + "," +
                    toString(r6));

            // SysV frame size: no shadow, 0 locals, 0 call args
            println(toString(abi_frame_size(0, 0, 0)));
            // SysV with 8 call args: (8-6)*8 = 16 outgoing + 8 align = 32
            println(toString(abi_frame_size(0, 8, 0)));
          }
          ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('7,6,2,1,8,9,-1'), 'SysV arg regs correct');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Builder: DataBuilder unit test
  // -----------------------------------------------------------------------
  RegisterTest('Builder_DataBuilder', procedure
  var
    LVM: TLVM;
    LOutput: string;
  begin
    LVM := TLVM.Create();
    try
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\language\myrissa.lvm'));
      LVM.LoadSource('''
          routine main() {
            let db = db_create();

            // Add a string
            let h0 = db_add_string(db, "hello");
            println("h0=" + toString(h0));
            println("off0=" + toString(db_get_offset(db, h0)));

            // "hello" = 5 bytes + 1 null = 6 bytes, so size should be 6
            println("sz1=" + toString(db_get_size(db)));

            // Add an i32
            let h1 = db_add_i32(db, 42);
            println("h1=" + toString(h1));
            println("off1=" + toString(db_get_offset(db, h1)));

            // Size should be 6 + 4 = 10
            println("sz2=" + toString(db_get_size(db)));

            // Add with alignment
            db_align(db, 8);
            // 10 -> pad to 16
            println("sz3=" + toString(db_get_size(db)));

            let h2 = db_add_i64(db, 99);
            println("h2=" + toString(h2));
            println("off2=" + toString(db_get_offset(db, h2)));
            // 16 + 8 = 24
            println("sz4=" + toString(db_get_size(db)));
          }
          ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('h0=0'), 'string handle is 0');
      Check(LOutput.Contains('off0=0'), 'string offset is 0');
      Check(LOutput.Contains('sz1=6'), 'size after string is 6');
      Check(LOutput.Contains('h1=1'), 'i32 handle is 1');
      Check(LOutput.Contains('off1=6'), 'i32 offset is 6');
      Check(LOutput.Contains('sz2=10'), 'size after i32 is 10');
      Check(LOutput.Contains('sz3=16'), 'size after align 8 is 16');
      Check(LOutput.Contains('h2=2'), 'i64 handle is 2');
      Check(LOutput.Contains('off2=16'), 'i64 offset is 16');
      Check(LOutput.Contains('sz4=24'), 'size after i64 is 24');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Builder: ImportBuilder unit test
  // -----------------------------------------------------------------------
  RegisterTest('Builder_ImportBuilder', procedure
  var
    LVM: TLVM;
    LOutput: string;
  begin
    LVM := TLVM.Create();
    try
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\language\myrissa.lvm'));
      LVM.LoadSource('''
          routine main() {
            let ib = ib_create();
            let i0 = ib_add(ib, "kernel32.dll", "ExitProcess");
            let i1 = ib_add(ib, "kernel32.dll", "WriteFile");
            let i2 = ib_add(ib, "msvcrt.dll", "printf");

            println("cnt=" + toString(ib_count(ib)));
            println("dlls=" + toString(ib_dll_count(ib)));
            println("i0=" + toString(i0));
            println("i1=" + toString(i1));
            println("i2=" + toString(i2));
            println("find=" + toString(ib_find(ib, "kernel32.dll", "WriteFile")));
            println("miss=" + toString(ib_find(ib, "kernel32.dll", "ReadFile")));

            let imports = ib_to_imports(ib);
            println("ndlls=" + toString(len(imports)));
            println("dll0=" + imports[0][0]);
            println("nf0=" + toString(len(imports[0][1])));
            println("f00=" + imports[0][1][0]);
            println("f01=" + imports[0][1][1]);
            println("dll1=" + imports[1][0]);
            println("f10=" + imports[1][1][0]);
          }
          ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('cnt=3'), 'total count is 3');
      Check(LOutput.Contains('dlls=2'), 'dll count is 2');
      Check(LOutput.Contains('i0=0'), 'ExitProcess index 0');
      Check(LOutput.Contains('i1=1'), 'WriteFile index 1');
      Check(LOutput.Contains('i2=2'), 'printf index 2');
      Check(LOutput.Contains('find=1'), 'find WriteFile returns 1');
      Check(LOutput.Contains('miss=-1'), 'find ReadFile returns -1');
      Check(LOutput.Contains('ndlls=2'), 'to_imports has 2 DLLs');
      Check(LOutput.Contains('dll0=kernel32.dll'), 'first DLL is kernel32');
      Check(LOutput.Contains('nf0=2'), 'kernel32 has 2 funcs');
      Check(LOutput.Contains('f00=ExitProcess'), 'first func is ExitProcess');
      Check(LOutput.Contains('f01=WriteFile'), 'second func is WriteFile');
      Check(LOutput.Contains('dll1=msvcrt.dll'), 'second DLL is msvcrt');
      Check(LOutput.Contains('f10=printf'), 'msvcrt func is printf');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Builder: CodeBuilder unit test
  // -----------------------------------------------------------------------
  RegisterTest('Builder_CodeBuilder', procedure
  var
    LVM: TLVM;
    LOutput: string;
  begin
    LVM := TLVM.Create();
    try
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\language\myrissa.lvm'));
      LVM.LoadSource('''
          routine main() {
            let cb = cb_create(256);

            // Emit sub rsp, 0x28 (4 bytes)
            cb_emit_sub_rsp_imm8(cb, 0x28);
            println("p1=" + toString(cb_get_pos(cb)));

            // Emit ret (1 byte)
            cb_emit_ret(cb);
            println("p2=" + toString(cb_get_pos(cb)));

            // Test IAT fixup tracking
            cb_add_fixup_iat(cb, 10, 0);
            cb_add_fixup_iat(cb, 20, 1);
            let fixups = cb_get_iat_fixups(cb);
            println("nfix=" + toString(len(fixups)));
            println("fx0=" + toString(fixups[0][0]) + "," + toString(fixups[0][1]));
            println("fx1=" + toString(fixups[1][0]) + "," + toString(fixups[1][1]));

            // Test data fixup tracking
            cb_add_fixup_data(cb, 30, 2);
            let dfix = cb_get_data_fixups(cb);
            println("ndfix=" + toString(len(dfix)));
          }
          ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('p1=4'), 'sub rsp,0x28 is 4 bytes');
      Check(LOutput.Contains('p2=5'), 'ret adds 1 byte');
      Check(LOutput.Contains('nfix=2'), '2 IAT fixups');
      Check(LOutput.Contains('fx0=10,0'), 'fixup 0 correct');
      Check(LOutput.Contains('fx1=20,1'), 'fixup 1 correct');
      Check(LOutput.Contains('ndfix=1'), '1 data fixup');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Builder: PE integration -- exit 42 via builders
  // -----------------------------------------------------------------------
  RegisterTest('Builder_PE_Exit42', procedure
  var
    LVM: TLVM;
    LOutput: string;
    LExePath: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\language\myrissa.lvm'));
      LExePath := TUtils.ResolvePath('$P:output\test_builder_exit42.exe');
      LVM.SetVar('exe_path', TLVMValue.FromString(LExePath));
      LVM.LoadSource('''
          routine main() {
            let ib = ib_create();
            let idx_ep = ib_add(ib, "kernel32.dll", "ExitProcess");

            let cb = cb_create(64);

            // sub rsp, 0x28
            cb_emit_sub_rsp_imm8(cb, 0x28);

            // mov ecx, 42
            cb_emit_u8(cb, 0xB9);
            cb_emit_u32(cb, 42);

            // call [rip+disp32] -- ExitProcess
            let call_off = cb_get_pos(cb);
            cb_emit_call_rip_disp32(cb);
            cb_add_fixup_iat(cb, call_off, idx_ep);

            // int3
            cb_emit_u8(cb, 0xCC);

            // Build PE
            let image = pe_build_exe(
              cb_get_buf(cb), cb_get_pos(cb), 0,
              cb_get_iat_fixups(cb), ib_to_imports(ib),
              nil, 0, [],
              nil, 0, []);

            createDirsInPath(exe_path);
            bufSave(image, exe_path);
            let exit_code = runPE(exe_path);
            println("exit:" + toString(exit_code));
          }
          ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('exit:42'), 'Builder PE exit 42');
      Check(FileExists(LExePath), 'Builder PE exe exists');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Builder: PE + rdata integration -- hello stdout via builders
  // -----------------------------------------------------------------------
  RegisterTest('Builder_PE_RData', procedure
  var
    LVM: TLVM;
    LOutput: string;
    LExePath: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\language\myrissa.lvm'));
      LExePath := TUtils.ResolvePath('$P:output\test_builder_rdata.exe');
      LVM.SetVar('exe_path', TLVMValue.FromString(LExePath));
      LVM.LoadSource('''
          routine main() {
            // --- Imports ---
            let ib = ib_create();
            let idx_gsh = ib_add(ib, "kernel32.dll", "GetStdHandle");
            let idx_wf  = ib_add(ib, "kernel32.dll", "WriteFile");
            let idx_ep  = ib_add(ib, "kernel32.dll", "ExitProcess");

            // --- Data (.rdata) ---
            let db = db_create();
            // "hello!\r\n" as raw bytes
            let rdata_buf = buffer(8);
            bufWriteU8(rdata_buf, 0, 0x68);
            bufWriteU8(rdata_buf, 1, 0x65);
            bufWriteU8(rdata_buf, 2, 0x6C);
            bufWriteU8(rdata_buf, 3, 0x6C);
            bufWriteU8(rdata_buf, 4, 0x6F);
            bufWriteU8(rdata_buf, 5, 0x21);
            bufWriteU8(rdata_buf, 6, 0x0D);
            bufWriteU8(rdata_buf, 7, 0x0A);
            let h_str = db_add_bytes(db, rdata_buf, 8);

            // --- Code ---
            let cb = cb_create(256);

            // sub rsp, 0x28 (shadow space + alignment)
            cb_emit_sub_rsp_imm8(cb, 0x28);

            // mov rcx, -11 (STD_OUTPUT_HANDLE)
            // 48 C7 C1 F5FFFFFF
            cb_emit_u8(cb, 0x48);
            cb_emit_u8(cb, 0xC7);
            cb_emit_u8(cb, 0xC1);
            cb_emit_u32(cb, 0xFFFFFFF5);

            // call [rip+disp32] -- GetStdHandle (IAT[0])
            let call_gsh = cb_get_pos(cb);
            cb_emit_call_rip_disp32(cb);
            cb_add_fixup_iat(cb, call_gsh, idx_gsh);

            // mov rcx, rax (hFile = returned handle)
            cb_emit_mov_r64_r64(cb, 1, 0);

            // lea rdx, [rip+disp32] -- lpBuffer = .rdata string
            let lea_off = cb_get_pos(cb);
            cb_emit_lea_rip_disp32(cb, 2);
            cb_add_fixup_data(cb, lea_off, h_str);

            // mov r8d, 8 (nNumberOfBytesToWrite)
            // 41 B8 08000000
            cb_emit_u8(cb, 0x41);
            cb_emit_u8(cb, 0xB8);
            cb_emit_u32(cb, 8);

            // xor r9, r9 (lpNumberOfBytesWritten = NULL)
            // 4D 31 C9
            cb_emit_u8(cb, 0x4D);
            cb_emit_u8(cb, 0x31);
            cb_emit_u8(cb, 0xC9);

            // push 0 (lpOverlapped = NULL, 5th arg on stack)
            // 6A 00
            cb_emit_u8(cb, 0x6A);
            cb_emit_u8(cb, 0x00);

            // call [rip+disp32] -- WriteFile (IAT[1])
            let call_wf = cb_get_pos(cb);
            cb_emit_call_rip_disp32(cb);
            cb_add_fixup_iat(cb, call_wf, idx_wf);

            // add rsp, 8 (clean up push)
            cb_emit_add_rsp_imm8(cb, 0x08);

            // mov ecx, 0 (exit code)
            // B9 00000000
            cb_emit_u8(cb, 0xB9);
            cb_emit_u32(cb, 0);

            // call [rip+disp32] -- ExitProcess (IAT[2])
            let call_ep = cb_get_pos(cb);
            cb_emit_call_rip_disp32(cb);
            cb_add_fixup_iat(cb, call_ep, idx_ep);

            // Build PE
            let image = pe_build_exe(
              cb_get_buf(cb), cb_get_pos(cb), 0,
              cb_get_iat_fixups(cb), ib_to_imports(ib),
              db_get_buf(db), db_get_size(db), cb_get_data_fixups(cb),
              nil, 0, []);

            createDirsInPath(exe_path);
            bufSave(image, exe_path);
            let exit_code = runPE(exe_path);
            println("exit:" + toString(exit_code));
          }
          ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('exit:0'), 'Builder PE rdata exited 0');
      Check(FileExists(LExePath), 'Builder PE rdata exe exists');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test: ABI Win64 Float Args (typed call args with mixed int/float)
  // -----------------------------------------------------------------------
  RegisterTest('ABI_Win64_FloatArgs', procedure
  var
    LVM: TLVM;
    LOutput: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\language\myrissa.lvm'));
      LVM.LoadSource('''
          routine main() {
            let buf = buffer(256, true);
            let off = 0;
            // args: [42, 0x4045000000000000, 99, 0x4059000000000000]
            // types: [0, 1, 0, 1] -- int, float, int, float
            let args = [42, 0x4045000000000000, 99, 0x4059000000000000];
            let tflags = [0, 1, 0, 1];
            off = abi_emit_call_args_win64_typed(buf, off, args, tflags);
            println("size:" + toString(off));
            // Slot 0: int -> MOV RCX, 42 (mov r64,imm64 = 10 bytes)
            // Slot 1: float -> MOV RAX,imm64 + MOVQ XMM1,RAX (10+5 = 15 bytes)
            // Slot 2: int -> MOV R8, 99 (10 bytes)
            // Slot 3: float -> MOV RAX,imm64 + MOVQ XMM3,RAX (10+5 = 15 bytes)
            // Total = 50 bytes
            println("ok");
            // Check that MOVQ XMM1,RAX is present: 66 48 0F 6E C8
            // XMM1 field = 1, RAX field = 0 -> ModRM = C0 + 1*8 + 0 = C8
            let b20 = bufReadU8(buf, 20);
            let b21 = bufReadU8(buf, 21);
            let b22 = bufReadU8(buf, 22);
            let b23 = bufReadU8(buf, 23);
            let b24 = bufReadU8(buf, 24);
            println("movq_xmm1:" + toString(b20) + "," + toString(b21) + "," + toString(b22) + "," + toString(b23) + "," + toString(b24));
          }
          ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('size:50'), 'Win64 typed args total size 50');
      Check(LOutput.Contains('ok'), 'Win64 float args executed');
      // MOVQ XMM1,RAX = 66(102) 48(72) 0F(15) 6E(110) C8(200)
      Check(LOutput.Contains('movq_xmm1:102,72,15,110,200'), 'MOVQ XMM1,RAX encoding');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test: ABI SysV Float Args (independent int/float counters + AL)
  // -----------------------------------------------------------------------
  RegisterTest('ABI_SysV_FloatArgs', procedure
  var
    LVM: TLVM;
    LOutput: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\language\myrissa.lvm'));
      LVM.LoadSource('''
          routine main() {
            let buf = buffer(256, true);
            let off = 0;
            // args: [1, 0x3FF0000000000000, 2]
            // types: [0, 1, 0] -- int, float, int
            // Int counter: 1->RDI, 2->RSI (2 ints)
            // Float counter: 0x3FF..->XMM0 (1 float)
            // AL should = 1
            let args = [1, 0x3FF0000000000000, 2];
            let tflags = [0, 1, 0];
            off = abi_emit_call_args_sysv_typed(buf, off, args, tflags);
            println("size:" + toString(off));
            // Last instruction is MOV EAX, 1 (B8 01 00 00 00 = 5 bytes)
            // Read the last 5 bytes
            let alOff = off - 5;
            let b0 = bufReadU8(buf, alOff);
            let b1 = bufReadU8(buf, alOff + 1);
            println("moveax:" + toString(b0) + "," + toString(b1));
          }
          ''', 'test.lvm');
      LVM.Run('main');
      // MOV EAX, 1 = B8(184) 01(1)
      Check(LOutput.Contains('moveax:184,1'), 'SysV AL = 1 float reg');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test: ABI Callee-Saved Register Preservation
  // -----------------------------------------------------------------------
  RegisterTest('ABI_CalleeSaved', procedure
  var
    LVM: TLVM;
    LOutput: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\language\myrissa.lvm'));
      LVM.LoadSource('''
          routine main() {
            let buf = buffer(64, true);
            let off = 0;
            // Save RBX(3) and R12(12)
            let regs = [REG_RBX, REG_R12];
            off = abi_emit_save_callee_regs(buf, off, regs);
            let save_size = off;
            // PUSH RBX = 53 (1 byte), PUSH R12 = 41 54 (2 bytes) = 3 bytes
            println("save:" + toString(save_size));
            let b0 = bufReadU8(buf, 0);
            let b1 = bufReadU8(buf, 1);
            let b2 = bufReadU8(buf, 2);
            println("push:" + toString(b0) + "," + toString(b1) + "," + toString(b2));

            // Restore (reverse order: POP R12, POP RBX)
            off = abi_emit_restore_callee_regs(buf, off, regs);
            let restore_size = off - save_size;
            println("restore:" + toString(restore_size));
            // POP R12 = 41 5C (2 bytes), POP RBX = 5B (1 byte) = 3 bytes
            let r0 = bufReadU8(buf, save_size);
            let r1 = bufReadU8(buf, save_size + 1);
            let r2 = bufReadU8(buf, save_size + 2);
            println("pop:" + toString(r0) + "," + toString(r1) + "," + toString(r2));
          }
          ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('save:3'), 'Save 2 regs = 3 bytes');
      // PUSH RBX = 0x53(83), PUSH R12 = 0x41(65) 0x54(84)
      Check(LOutput.Contains('push:83,65,84'), 'PUSH RBX + PUSH R12 encoding');
      Check(LOutput.Contains('restore:3'), 'Restore 2 regs = 3 bytes');
      // POP R12 = 0x41(65) 0x5C(92), POP RBX = 0x5B(91)
      Check(LOutput.Contains('pop:65,92,91'), 'POP R12 + POP RBX encoding (reversed)');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test: ABI Struct Return Win64 (hidden pointer homing)
  // -----------------------------------------------------------------------
  RegisterTest('ABI_StructReturn_Win64', procedure
  var
    LVM: TLVM;
    LOutput: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\language\myrissa.lvm'));
      LVM.LoadSource('''
          routine main() {
            let buf = buffer(128, true);
            let off = 0;
            // Home sret pointer (RCX -> [RBP-32])
            off = abi_emit_home_sret_win64(buf, off);
            let sret_size = off;
            println("sret:" + toString(sret_size));
            // MOV [RBP-32], RCX = 48 89 4D E0 (RBP=5, mod=10, RCX field=1)
            // Actually emit_mov_base_disp_r64 with RBP base: 48 89 8D E0FFFFFF
            // REX.W=48, opcode=89, ModRM=8D (mod=10, reg=RCX(1), rm=RBP(5)), disp32=-32
            let b0 = bufReadU8(buf, 0);
            let b1 = bufReadU8(buf, 1);
            let b2 = bufReadU8(buf, 2);
            println("sret_bytes:" + toString(b0) + "," + toString(b1) + "," + toString(b2));

            // Home shifted params (2 params: RDX=p0, R8=p1)
            off = abi_emit_home_sret_params_win64(buf, off, 2);
            let params_size = off - sret_size;
            println("params:" + toString(params_size));
            println("ok");
          }
          ''', 'test.lvm');
      LVM.Run('main');
      // MOV [RBP+disp32], RCX: REX.W(0x48=72), 0x89(137), ModRM(0x8D=141)
      Check(LOutput.Contains('sret_bytes:72,137,141'), 'SRET home RCX encoding');
      Check(LOutput.Contains('ok'), 'Struct return test completed');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test: ABI Param Homing Win64 (fixed version using emit_mov_base_disp_r64)
  // -----------------------------------------------------------------------
  RegisterTest('ABI_ParamHome_Win64', procedure
  var
    LVM: TLVM;
    LOutput: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\language\myrissa.lvm'));
      LVM.LoadSource('''
          routine main() {
            let buf = buffer(128, true);
            let off = 0;
            off = abi_emit_home_params_win64(buf, off, 4);
            println("size:" + toString(off));
            // 4 MOV [RBP+disp32], reg instructions, each 7 bytes = 28
            println("ok");
            // First instruction: MOV [RBP-40], RCX
            // REX.W(0x48) 89 ModRM disp32
            let b0 = bufReadU8(buf, 0);
            let b1 = bufReadU8(buf, 1);
            println("home0:" + toString(b0) + "," + toString(b1));
          }
          ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('size:28'), 'Home 4 params = 28 bytes');
      // REX.W=0x48(72), opcode=0x89(137)
      Check(LOutput.Contains('home0:72,137'), 'Param home encoding starts with REX.W 89');
      Check(LOutput.Contains('ok'), 'Param homing test completed');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test: PE DLL with exported function, loaded and called via LVM builtins
  // -----------------------------------------------------------------------
  RegisterTest('PE_DLL_Exports', procedure
  var
    LVM: TLVM;
    LOutput: string;
    LDllPath: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\language\myrissa.lvm'));
      LDllPath := TUtils.ResolvePath('$P:output\test_dll.dll');
      LVM.SetVar('dll_path', TLVMValue.FromString(LDllPath));
      LVM.LoadSource('''
          routine main() {
            // --- Build the DLL ---

            // No imports needed for this minimal DLL
            let ib = ib_create();

            // Export builder: one export "GetValue"
            let eb = eb_create();

            let cb = cb_create(128);

            // DllMain at offset 0: mov eax,1 / ret
            let dllmain_off = cb_get_pos(cb);
            cb_emit_u8(cb, 0xB8);     // mov eax, imm32
            cb_emit_u32(cb, 1);       // TRUE
            cb_emit_u8(cb, 0xC3);     // ret

            // GetValue at offset 6: mov eax,42 / ret
            let getvalue_off = cb_get_pos(cb);
            cb_emit_u8(cb, 0xB8);     // mov eax, imm32
            cb_emit_u32(cb, 42);
            cb_emit_u8(cb, 0xC3);     // ret

            // Register export
            eb_add(eb, "GetValue", "func", getvalue_off);

            // Build DLL PE image
            let image = pe_build_image({
              "code_buf": cb_get_buf(cb),
              "code_size": cb_get_pos(cb),
              "entry_off": dllmain_off,
              "iat_fixups": [],
              "dll_imports": [],
              "rdata_buf": nil,
              "rdata_size": 0,
              "data_fixups": [],
              "wdata_buf": nil,
              "wdata_size": 0,
              "global_fixups": [],
              "subsystem": IMAGE_SUBSYSTEM_WINDOWS_CUI,
              "output_type": "dll",
              "exports": eb,
              "dll_name": "test_dll.dll"
            });

            // Save the DLL
            createDirsInPath(dll_path);
            bufSave(image, dll_path);
            println("saved");

            // Load and call the exported function
            let hDll = loadDll(dll_path);
            let proc = getDllProc(hDll, "GetValue");
            let result = callDllProc(proc);
            println("result:" + toString(result));
            freeDll(hDll);
          }
          ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('saved'), 'DLL saved to disk');
      Check(LOutput.Contains('result:42'), 'Exported GetValue returned 42');
      Check(FileExists(LDllPath), 'DLL file exists');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test: ELF .so with exported function, verified by reading raw bytes
  // -----------------------------------------------------------------------
  RegisterTest('ELF_SO_Exports', procedure
  var
    LVM: TLVM;
    LOutput: string;
    LSoPath: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\language\myrissa.lvm'));
      LSoPath := TUtils.ResolvePath('$P:output\test_lib.so');
      LVM.SetVar('so_path', TLVMValue.FromString(LSoPath));
      LVM.LoadSource('''
          routine main() {
            let eb = eb_create();
            let cb = cb_create(128);

            // GetValue: mov eax,42 / ret
            let getvalue_off = cb_get_pos(cb);
            cb_emit_u8(cb, 0xB8);
            cb_emit_u32(cb, 42);
            cb_emit_u8(cb, 0xC3);

            eb_add(eb, "GetValue", "func", getvalue_off);

            let image = elf_build_image({
              "code_buf": cb_get_buf(cb),
              "code_size": cb_get_pos(cb),
              "entry_off": 0,
              "got_fixups": [],
              "so_imports": [],
              "rdata_buf": nil,
              "rdata_size": 0,
              "data_fixups": [],
              "wdata_buf": nil,
              "wdata_size": 0,
              "wdata_bss_size": 0,
              "global_fixups": [],
              "output_type": "so",
              "exports": eb,
              "soname": "test_lib.so"
            });

            createDirsInPath(so_path);
            bufSave(image, so_path);

            // Verify ELF header bytes
            // e_ident[0..3] = 7F 45 4C 46
            let ok = bufReadU8(image, 0) == 0x7F;
            ok = ok and bufReadU8(image, 1) == 0x45;
            ok = ok and bufReadU8(image, 2) == 0x4C;
            ok = ok and bufReadU8(image, 3) == 0x46;
            println("magic:" + toString(ok));

            // e_type at offset 16: ET_DYN = 3
            let etype = bufReadU16(image, 16);
            println("etype:" + toString(etype));

            // e_entry at offset 24: should be 0 for .so
            let entry = bufReadU64(image, 24);
            println("entry:" + toString(entry));

            // e_shoff at offset 40: should be nonzero (section headers present)
            let shoff = bufReadU64(image, 40);
            println("shoff:" + toString(shoff));

            // e_shnum at offset 60: should be 8
            let shnum = bufReadU16(image, 60);
            println("shnum:" + toString(shnum));

            // e_shstrndx at offset 62: should be 7
            let shstrndx = bufReadU16(image, 62);
            println("shstrndx:" + toString(shstrndx));

            // Check buffer size is reasonable (> 4096)
            let imgsize = bufSize(image);
            println("size:" + toString(imgsize));

            println("done");
          }
          ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('magic:true'), 'ELF magic correct');
      Check(LOutput.Contains('etype:3'), 'ELF type is ET_DYN (3)');
      Check(LOutput.Contains('entry:0'), 'Entry point is 0 for .so');
      Check(LOutput.Contains('shnum:8'), '8 section headers');
      Check(LOutput.Contains('shstrndx:7'), 'shstrndx is 7');
      Check(FileExists(LSoPath), 'SO file exists');
      Check(LOutput.Contains('done'), 'Script completed without error');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test: COFF .obj with exported function, verified by reading raw bytes
  // -----------------------------------------------------------------------
  RegisterTest('COFF_Obj_Exports', procedure
  var
    LVM: TLVM;
    LOutput: string;
    LObjPath: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\language\myrissa.lvm'));
      LObjPath := TUtils.ResolvePath('$P:output\test_obj.obj');
      LVM.SetVar('obj_path', TLVMValue.FromString(LObjPath));
      LVM.LoadSource('''
          routine main() {
            let eb = eb_create();
            let cb = cb_create(128);

            // GetValue: mov eax,42 / ret
            let getvalue_off = cb_get_pos(cb);
            cb_emit_u8(cb, 0xB8);
            cb_emit_u32(cb, 42);
            cb_emit_u8(cb, 0xC3);

            eb_add(eb, "GetValue", "func", getvalue_off);

            // Build COFF .obj -- function symbol in .text + /EXPORT: in .drectve
            let sect_text = 1;
            let func_sym = {
              "name": "GetValue",
              "sect_num": sect_text,
              "value": getvalue_off,
              "sym_type": COFF_SYM_DTYPE_FUNCTION,
              "sym_class": COFF_SYM_CLASS_EXTERNAL
            };

            let image = coff_build_obj({
              "code_buf": cb_get_buf(cb),
              "code_size": cb_get_pos(cb),
              "rdata_buf": nil,
              "rdata_size": 0,
              "wdata_buf": nil,
              "wdata_size": 0,
              "text_relocs": [],
              "symbols": [func_sym],
              "exports": eb
            });

            createDirsInPath(obj_path);
            bufSave(image, obj_path);

            // Verify COFF header bytes
            // Machine at offset 0: IMAGE_FILE_MACHINE_AMD64 = 0x8664
            let machine = bufReadU16(image, 0);
            println("machine:" + toString(machine));

            // NumberOfSections at offset 2
            let nsect = bufReadU16(image, 2);
            println("nsect:" + toString(nsect));

            // SizeOfOptionalHeader at offset 16: must be 0 for .obj
            let opthdr = bufReadU16(image, 16);
            println("opthdr:" + toString(opthdr));

            // PointerToSymbolTable at offset 8: must be nonzero
            let symtab = bufReadU32(image, 8);
            println("symtab:" + toString(symtab));

            // NumberOfSymbols at offset 12
            let nsyms = bufReadU32(image, 12);
            println("nsyms:" + toString(nsyms));

            println("done");
          }
          ''', 'test.lvm');
      LVM.Run('main');
      // 0x8664 = 34404 decimal
      Check(LOutput.Contains('machine:34404'), 'Machine is AMD64 (0x8664)');
      // 2 sections: .text + .drectve (no rdata/data since nil)
      Check(LOutput.Contains('nsect:2'), '2 sections (.text + .drectve)');
      Check(LOutput.Contains('opthdr:0'), 'No optional header');
      Check(LOutput.Contains('done'), 'Script completed without error');
      Check(FileExists(LObjPath), 'OBJ file exists');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test: .lib archive wrapping a COFF .obj, verified by reading raw bytes
  // -----------------------------------------------------------------------
  RegisterTest('Lib_Archive', procedure
  var
    LVM: TLVM;
    LOutput: string;
    LLibPath: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\language\myrissa.lvm'));
      LLibPath := TUtils.ResolvePath('$P:output\test_lib.lib');
      LVM.SetVar('lib_path', TLVMValue.FromString(LLibPath));
      LVM.LoadSource('''
          routine main() {
            let cb = cb_create(128);

            // GetValue: mov eax,42 / ret
            let getvalue_off = cb_get_pos(cb);
            cb_emit_u8(cb, 0xB8);
            cb_emit_u32(cb, 42);
            cb_emit_u8(cb, 0xC3);

            // Build a minimal COFF .obj first
            let eb = eb_create();
            eb_add(eb, "GetValue", "func", getvalue_off);

            let func_sym = {
              "name": "GetValue",
              "sect_num": 1,
              "value": getvalue_off,
              "sym_type": COFF_SYM_DTYPE_FUNCTION,
              "sym_class": COFF_SYM_CLASS_EXTERNAL
            };

            let obj = coff_build_obj({
              "code_buf": cb_get_buf(cb),
              "code_size": cb_get_pos(cb),
              "text_relocs": [],
              "symbols": [func_sym],
              "exports": eb
            });

            // Wrap in .lib archive
            let lib = lib_build_archive(obj, bufSize(obj), ["GetValue"]);

            createDirsInPath(lib_path);
            bufSave(lib, lib_path);

            // Verify AR signature: "!<arch>\n"
            let sig_ok = bufReadU8(lib, 0) == 0x21;
            sig_ok = sig_ok and bufReadU8(lib, 1) == 0x3C;
            sig_ok = sig_ok and bufReadU8(lib, 2) == 0x61;
            sig_ok = sig_ok and bufReadU8(lib, 3) == 0x72;
            sig_ok = sig_ok and bufReadU8(lib, 4) == 0x63;
            sig_ok = sig_ok and bufReadU8(lib, 5) == 0x68;
            sig_ok = sig_ok and bufReadU8(lib, 6) == 0x3E;
            sig_ok = sig_ok and bufReadU8(lib, 7) == 0x0A;
            println("arsig:" + toString(sig_ok));

            // First member header starts at offset 8
            // Name should be "/" (0x2F at offset 8)
            println("linker_name:" + toString(bufReadU8(lib, 8)));

            // Size should be > 0
            let libsize = bufSize(lib);
            println("libsize:" + toString(libsize));

            println("done");
          }
          ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('arsig:true'), 'AR signature correct');
      Check(LOutput.Contains('linker_name:47'), 'First member is "/" (linker)');
      Check(LOutput.Contains('done'), 'Script completed without error');
      Check(FileExists(LLibPath), 'LIB file exists');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test: ELF relocatable object (.o) with .text/.rodata/.data/.rela.text
  // -----------------------------------------------------------------------
  RegisterTest('ELF_Obj', procedure
  var
    LVM: TLVM;
    LOutput: string;
    LObjPath: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\language\myrissa.lvm'));
      LObjPath := TUtils.ResolvePath('$P:output\test_elfobj.o');
      LVM.SetVar('obj_path', TLVMValue.FromString(LObjPath));
      LVM.LoadSource('''
          routine main() {
            let cb = cb_create(128);

            // func_add: add rdi,rsi; mov rax,rdi; ret
            let add_off = cb_get_pos(cb);
            cb_emit_u8(cb, 0x48); cb_emit_u8(cb, 0x01); cb_emit_u8(cb, 0xF7);
            cb_emit_u8(cb, 0x48); cb_emit_u8(cb, 0x89); cb_emit_u8(cb, 0xF8);
            cb_emit_u8(cb, 0xC3);
            let add_end = cb_get_pos(cb);

            // func_main: mov eax,42; ret
            let main_off = cb_get_pos(cb);
            cb_emit_u8(cb, 0xB8);
            cb_emit_u32(cb, 42);
            cb_emit_u8(cb, 0xC3);
            let main_end = cb_get_pos(cb);

            // Build .rodata with a test string
            let db = db_create();
            db_add_string(db, "Hello ELF .o!");

            // Build .data with a test i32
            let gdb = db_create();
            db_add_i32(gdb, 0xDEADBEEF);

            let obj = elf_build_obj({
              "code_buf": cb_get_buf(cb),
              "code_size": cb_get_pos(cb),
              "rdata_buf": db_get_buf(db),
              "rdata_size": db_get_size(db),
              "wdata_buf": db_get_buf(gdb),
              "wdata_size": db_get_size(gdb),
              "funcs": [
                {"name": "func_add", "offset": add_off, "end_off": add_end, "is_public": false},
                {"name": "main", "offset": main_off, "end_off": main_end, "is_public": true}
              ],
              "imports": [],
              "data_fixups": [],
              "global_fixups": [],
              "func_addr_fixups": [],
              "import_fixups": [],
              "exports": []
            });

            createDirsInPath(obj_path);
            bufSave(obj.buf, obj_path);

            // Verify ELF magic
            let magic_ok = bufReadU8(obj.buf, 0) == 0x7F;
            magic_ok = magic_ok and bufReadU8(obj.buf, 1) == 0x45;
            magic_ok = magic_ok and bufReadU8(obj.buf, 2) == 0x4C;
            magic_ok = magic_ok and bufReadU8(obj.buf, 3) == 0x46;
            println("magic:" + toString(magic_ok));

            // e_type at offset 16 = ET_REL (1)
            let etype = bufReadU16(obj.buf, 16);
            println("etype:" + toString(etype));

            // e_machine at offset 18 = 0x3E (EM_X86_64)
            let emach = bufReadU16(obj.buf, 18);
            println("emach:" + toString(emach));

            // e_phnum at offset 56 = 0 (no program headers for .o)
            let phnum = bufReadU16(obj.buf, 56);
            println("phnum:" + toString(phnum));

            // e_shnum at offset 60 = 8
            let shnum = bufReadU16(obj.buf, 60);
            println("shnum:" + toString(shnum));

            // e_shstrndx at offset 62 = 7
            let shstrndx = bufReadU16(obj.buf, 62);
            println("shstrndx:" + toString(shstrndx));

            println("objsize:" + toString(obj.size));
            println("done");
          }
          ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('magic:true'), 'ELF magic correct');
      Check(LOutput.Contains('etype:1'), 'ELF type is ET_REL (1)');
      Check(LOutput.Contains('emach:62'), 'Machine is EM_X86_64');
      Check(LOutput.Contains('phnum:0'), 'No program headers');
      Check(LOutput.Contains('shnum:8'), '8 section headers');
      Check(LOutput.Contains('shstrndx:7'), 'shstrndx is 7');
      Check(LOutput.Contains('done'), 'Script completed without error');
      Check(FileExists(LObjPath), 'OBJ file exists');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test: ELF static archive (.a) wrapping an ELF .o
  // -----------------------------------------------------------------------
  RegisterTest('ELF_Lib', procedure
  var
    LVM: TLVM;
    LOutput: string;
    LLibPath: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
        end, nil);
      LVM.LoadFile(TUtils.ResolvePath('$P:res\language\myrissa.lvm'));
      LLibPath := TUtils.ResolvePath('$P:output\test_elflib.a');
      LVM.SetVar('lib_path', TLVMValue.FromString(LLibPath));
      LVM.LoadSource('''
          routine main() {
            let cb = cb_create(128);

            // GetValue: mov eax,42 / ret
            let getvalue_off = cb_get_pos(cb);
            cb_emit_u8(cb, 0xB8);
            cb_emit_u32(cb, 42);
            cb_emit_u8(cb, 0xC3);
            let getvalue_end = cb_get_pos(cb);

            // Build a minimal ELF .o first
            let obj = elf_build_obj({
              "code_buf": cb_get_buf(cb),
              "code_size": cb_get_pos(cb),
              "rdata_buf": buffer(0),
              "rdata_size": 0,
              "wdata_buf": buffer(0),
              "wdata_size": 0,
              "funcs": [
                {"name": "GetValue", "offset": getvalue_off, "end_off": getvalue_end, "is_public": true}
              ],
              "imports": [],
              "data_fixups": [],
              "global_fixups": [],
              "func_addr_fixups": [],
              "import_fixups": [],
              "exports": []
            });

            // Wrap in .a archive
            let ar = elf_build_archive(obj.buf, obj.size, ["GetValue"], lib_path);

            createDirsInPath(lib_path);
            bufSave(ar, lib_path);

            // Verify AR signature: "!<arch>\n"
            let sig_ok = bufReadU8(ar, 0) == 0x21;
            sig_ok = sig_ok and bufReadU8(ar, 1) == 0x3C;
            sig_ok = sig_ok and bufReadU8(ar, 2) == 0x61;
            sig_ok = sig_ok and bufReadU8(ar, 3) == 0x72;
            sig_ok = sig_ok and bufReadU8(ar, 4) == 0x63;
            sig_ok = sig_ok and bufReadU8(ar, 5) == 0x68;
            sig_ok = sig_ok and bufReadU8(ar, 6) == 0x3E;
            sig_ok = sig_ok and bufReadU8(ar, 7) == 0x0A;
            println("arsig:" + toString(sig_ok));

            // First member header at offset 8, name should be "/"
            println("linker_name:" + toString(bufReadU8(ar, 8)));

            println("arsize:" + toString(bufSize(ar)));
            println("done");
          }
          ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('arsig:true'), 'AR signature correct');
      Check(LOutput.Contains('linker_name:47'), 'First member is "/" (linker)');
      Check(LOutput.Contains('done'), 'Script completed without error');
      Check(FileExists(LLibPath), 'Archive file exists');
    finally
      LVM.Free();
    end;
  end);

end;

procedure TBackendTestCase.Run();
begin
  inherited;
end;

end.
