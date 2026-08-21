# Myrissa Runtime Contract (RT_*)

This document defines every RT_* routine and global that the Myrissa
language layer may reference. Emitters call RT_* names without knowing
how they are implemented. Each supported target provides an implementation
in its platform runtime file.

A routine marked **platform** has a different implementation per target
(e.g. HeapAlloc on Win64, malloc on Linux64). A routine marked **shared**
has one implementation that works on all targets via portable C library
calls. A global marked **data** is a named MIR data item (variable or
buffer) emitted into the binary's .data or .bss section.

---

## System

| Name | Kind | Signature | Description |
|---|---|---|---|
| RT_Halt | platform | (exitcode: i32) -> void | Terminate process. Win64: ExitProcess. Linux64: syscall 60. |
| RT_ModuleInit | shared | () -> void | Module initialization entry. Called before main. |
| RT_ModuleFinalize | shared | () -> void | Module finalization. Called after main returns. |

## I/O

| Name | Kind | Signature | Description |
|---|---|---|---|
| RT_InitConsole | platform | () -> void | Initialize console. Win64: SetConsoleOutputCP/SetConsoleCP to UTF-8. Linux64: no-op. |

## Memory

### Functions

| Name | Kind | Signature | Description |
|---|---|---|---|
| RT_GetMem | platform | (size: u64) -> ptr | Allocate uninitialized memory. Win64: HeapAlloc. Linux64: malloc. |
| RT_FreeMem | platform | (ptr: ptr) -> void | Free memory. Win64: HeapFree. Linux64: free. |
| RT_ReAllocMem | platform | (ptr: ptr, newsize: u64) -> ptr | Resize allocation. Win64: HeapReAlloc. Linux64: realloc. |
| RT_AllocMem | platform | (size: u64) -> ptr | Allocate zero-initialized memory. Win64: HeapAlloc+HEAP_ZERO_MEMORY. Linux64: calloc. |
| RT_MemSize | platform | (ptr: ptr) -> u64 | Query allocation size. Win64: HeapSize. Linux64: malloc_usable_size. |
| RT_ReportLeaks | shared | () -> void | Report unfreed allocations (debug builds). |

### Globals (data)

| Name | Type | Description |
|---|---|---|
| RT_AllocCount | i64 | Running count of allocations. |
| RT_FreeCount | i64 | Running count of frees. |

## Strings -- Managed (refcounted TStringRec)

### Functions

| Name | Kind | Signature | Description |
|---|---|---|---|
| RT_StrAlloc | shared | (len: u64) -> ptr | Allocate a string record with space for len bytes + null. |
| RT_StrFree | shared | (str: ptr) -> void | Free a string record unconditionally. |
| RT_StrAddRef | shared | (str: ptr) -> void | Increment reference count. |
| RT_StrRelease | shared | (str: ptr) -> void | Decrement refcount; free if zero. |
| RT_ReleaseOnDetach | shared | (str: ptr) -> void | Release a string when its owning variable goes out of scope. |
| RT_FreeOnDetach | shared | (str: ptr) -> void | Free (not release) a string on scope exit. |
| RT_StrFromLiteral | shared | (data: ptr, len: u64) -> ptr | Create a managed string from a .rdata literal pointer and length. |
| RT_StrFromChar | shared | (ch: i32) -> ptr | Create a managed string from a single character ordinal. |
| RT_StrConcat | shared | (a: ptr, b: ptr) -> ptr | Concatenate two managed strings; returns new string. |
| RT_StrAssign | shared | (dst: ptr*, src: ptr) -> void | Assign src to dst with refcount management. |
| RT_StrSetLength | shared | (str: ptr*, newlen: u64) -> void | Resize a managed string in place. |
| RT_StrLen | shared | (str: ptr) -> u64 | Return byte length of managed string. |
| RT_StrCompare | shared | (a: ptr, b: ptr) -> i32 | Compare two managed strings. Returns <0, 0, >0. |
| RT_StrData | shared | (str: ptr) -> ptr | Return pointer to raw UTF-8 data bytes. |
| RT_StrUtf16 | platform | (str: ptr) -> ptr | Convert managed UTF-8 string to UTF-16. Win64: MultiByteToWideChar. Linux64: iconv or custom. |
| RT_StrLiteralUtf16 | platform | (data: ptr, len: u64) -> ptr | Convert a .rdata UTF-8 literal to UTF-16. |

## Strings -- Wide (raw wchar_t*)

| Name | Kind | Signature | Description |
|---|---|---|---|
| RT_WStrLen | platform | (wstr: ptr) -> u64 | Length of wide string in characters. |
| RT_WStrConcat | platform | (a: ptr, b: ptr) -> ptr | Concatenate two wide strings. |
| RT_WStrCompare | platform | (a: ptr, b: ptr) -> i32 | Compare two wide strings. |
| RT_WStrFromLiteral | platform | (data: ptr, len: u64) -> ptr | Create wide string from literal. |
| RT_WStrAssign | platform | (dst: ptr*, src: ptr) -> void | Assign wide string with lifetime management. |
| RT_WStrSetLength | platform | (wstr: ptr*, newlen: u64) -> void | Resize wide string. |

## Intrinsics

| Name | Kind | Signature | Description |
|---|---|---|---|
| RT_Utf8 | platform | (wstr: ptr) -> ptr | Convert UTF-16 wide string to UTF-8 managed string. |
| RT_Len | shared | (str: ptr) -> u64 | Generic length intrinsic (dispatches to StrLen or DynLen). |
| RT_DynLen | shared | (arr: ptr) -> u64 | Return element count of a dynamic array. |
| RT_SetLength | shared | (arr: ptr*, newlen: u64, elemsize: u64) -> void | Resize a dynamic array. |
| RT_DynFree | shared | (arr: ptr) -> void | Free a dynamic array. |
| RT_DynFreeOnDetach | shared | (arr: ptr) -> void | Free a dynamic array on scope exit. |

## Arrays -- Fixed arrays of managed elements

| Name | Kind | Signature | Description |
|---|---|---|---|
| RT_ArrayRelease | shared | (arr: ptr, count: u64) -> void | Release refcount on each managed element in a fixed array. |
| RT_ArrayReleaseOnDetach | shared | (arr: ptr, count: u64) -> void | Same as ArrayRelease, called on scope exit. |
| RT_ArrayReleaseComposite | shared | (arr: ptr, count: u64, stride: u64) -> void | Release managed fields within composite (record) array elements. |
| RT_ArrayReleaseCompositeOnDetach | shared | (arr: ptr, count: u64, stride: u64) -> void | Same on scope exit. |

## Exceptions

### Functions

| Name | Kind | Signature | Description |
|---|---|---|---|
| RT_InitExceptions | platform | () -> void | Initialize exception subsystem. Win64: SEH setup. Linux64: signal handlers. |
| RT_SetException | shared | (code: i32, msg: ptr) -> void | Store current exception code and message in TLS. |
| RT_Raise | shared | (msg: ptr) -> void | Raise an exception with a message string. |
| RT_RaiseCode | shared | (code: i32, msg: ptr) -> void | Raise an exception with a numeric code and message. |
| RT_GetExceptionCode | shared | () -> i32 | Get current exception code from TLS. |
| RT_GetExceptionMessage | shared | () -> ptr | Get current exception message from TLS. |
| RT_SEHFilter | platform | (record: ptr) -> i32 | Win64 SEH filter function. Linux64: not applicable. |
| RT_PushExceptFrame | platform | (frame: ptr) -> void | Push exception handler frame. Win64: SEH. Linux64: sigsetjmp. |
| RT_PopExceptFrame | platform | () -> void | Pop exception handler frame. |
| RT_InitSignals | platform | () -> void | Linux64: install signal handlers. Win64: no-op. |
| RT_SignalHandler | platform | (signo: i32) -> void | Linux64: signal handler entry. Win64: not applicable. |
| RT_GetExceptFrame | shared | () -> ptr | Get current exception frame from TLS chain. |
| RT_FreeExceptions | shared | () -> void | Cleanup exception TLS state on shutdown. |

### Globals (data)

| Name | Type | Description |
|---|---|---|
| RT_TlsExcCode | i32 | TLS: current exception code. |
| RT_TlsExcMsg | ptr | TLS: current exception message pointer. |
| RT_TlsExcChain | ptr | TLS: exception handler frame chain. |

## Path

| Name | Kind | Signature | Description |
|---|---|---|---|
| RT_BaseName | platform | (path: ptr) -> ptr | Extract filename from path. Win64: PathFindFileNameA. Linux64: basename. |

## Command Line

### Functions

| Name | Kind | Signature | Description |
|---|---|---|---|
| RT_InitCommandLine | platform | () -> void | Parse command line into argc/argv. Win64: GetCommandLineA. Linux64: uses main(argc, argv). |
| RT_FreeCommandLine | shared | () -> void | Free parsed command line data. |
| RT_ParamCount | shared | () -> i32 | Return number of command line parameters. |
| RT_ParamStr | shared | (index: i32) -> ptr | Return parameter string by index. |

### Globals (data)

| Name | Type | Description |
|---|---|---|
| RT_Argc | i32 | Argument count. |
| RT_Argv | ptr | Pointer to argument string array. |

## Finalizers

### Functions

| Name | Kind | Signature | Description |
|---|---|---|---|
| RT_RegisterFinalizer | shared | (func: ptr) -> void | Register a routine to run at shutdown. |
| RT_RunFinalizers | shared | () -> void | Execute all registered finalizers in reverse order. |

### Globals (data)

| Name | Type | Description |
|---|---|---|
| RT_FinCount | i32 | Number of registered finalizers. |
| RT_FinSlots | ptr | Pointer to finalizer function pointer array. |

## Unit Testing

### Functions

| Name | Kind | Signature | Description |
|---|---|---|---|
| RT_TestRegister | shared | (name: ptr, func: ptr, file: ptr, line: i32) -> void | Register a test case. |
| RT_TestRunAll | shared | () -> void | Run all registered tests, report results. |
| RT_TestAssert | shared | (cond: i32, file: ptr, line: i32) -> void | Assert a boolean condition. |
| RT_TestAssertTrue | shared | (val: i32, file: ptr, line: i32) -> void | Assert value is true. |
| RT_TestAssertFalse | shared | (val: i32, file: ptr, line: i32) -> void | Assert value is false. |
| RT_TestAssertCmpInt | shared | (rel: i32, a: i64, b: i64, file: ptr, line: i32) -> void | Assert integer comparison. |
| RT_TestAssertCmpUInt | shared | (rel: i32, a: u64, b: u64, file: ptr, line: i32) -> void | Assert unsigned comparison. |
| RT_TestAssertCmpFloat | shared | (rel: i32, a: f64, b: f64, file: ptr, line: i32) -> void | Assert float comparison. |
| RT_TestAssertCmpFloatTol | shared | (rel: i32, a: f64, b: f64, tol: f64, file: ptr, line: i32) -> void | Assert float with tolerance. |
| RT_TestAssertCmpStr | shared | (rel: i32, a: ptr, b: ptr, file: ptr, line: i32) -> void | Assert string comparison. |
| RT_TestAssertCmpBool | shared | (rel: i32, a: i32, b: i32, file: ptr, line: i32) -> void | Assert boolean comparison. |
| RT_TestAssertCmpChar | shared | (rel: i32, a: i32, b: i32, file: ptr, line: i32) -> void | Assert char comparison. |
| RT_TestAssertCmpWChar | shared | (rel: i32, a: i32, b: i32, file: ptr, line: i32) -> void | Assert wide char comparison. |
| RT_TestAssertCmpWStr | shared | (rel: i32, a: ptr, b: ptr, file: ptr, line: i32) -> void | Assert wide string comparison. |
| RT_TestAssertCmpPtr | shared | (rel: i32, a: ptr, b: ptr, file: ptr, line: i32) -> void | Assert pointer comparison. |
| RT_TestAssertNil | shared | (val: ptr, file: ptr, line: i32) -> void | Assert pointer is nil. |
| RT_TestAssertNotNil | shared | (val: ptr, file: ptr, line: i32) -> void | Assert pointer is not nil. |
| RT_TestFail | shared | (msg: ptr, file: ptr, line: i32) -> void | Unconditionally fail a test with message. |

### Globals (data)

| Name | Type | Description |
|---|---|---|
| RT_TestCount | i32 | Number of registered tests. |
| RT_TestNames | ptr | Array of test name string pointers. |
| RT_TestFuncs | ptr | Array of test function pointers. |
| RT_TestFiles | ptr | Array of source file name pointers. |
| RT_TestLines | ptr | Array of source line numbers. |
| RT_TestFailed | i32 | Number of failed tests. |
| RT_TestErrBuf | ptr | Error message buffer. |
| RT_TestErrPos | i32 | Current position in error buffer. |

### Constants

| Name | Value | Description |
|---|---|---|
| RT_CMP_EQ | 0 | Comparison relation: equal. |
| RT_CMP_NEQ | 1 | Comparison relation: not equal. |

## Compile-Time Helpers (not emitted as native code)

These are LVM-level routines called by emitters at compile time.
They produce MIR instructions but are not themselves in the binary.

| Name | Description |
|---|---|
| RT_Print(node) | Walk print statement AST children, emit printf MIR calls with format-appropriate args. |
| RT_Println(node) | Same as RT_Print, plus emit a trailing newline printf call. |
| RT_AllocStr(text) | Allocate a unique MIR string constant, return its name for use in mirCallArg. |
| RT_GetDll(func_name) | Map an imported function name to its DLL (platform runtime only). |
| RT_EmitImports() | Emit all mirImport/mirProto declarations for platform APIs. |
| RT_EmitGetMem() | Emit the RT_GetMem native function body. |
| RT_EmitFreeMem() | Emit the RT_FreeMem native function body. |
| RT_EmitAllocMem() | Emit the RT_AllocMem native function body. |
| RT_EmitReAllocMem() | Emit the RT_ReAllocMem native function body. |
| RT_EmitMemSize() | Emit the RT_MemSize native function body. |
| RT_EmitInitConsole() | Emit the RT_InitConsole native function body. |

---

## Implementation Status

Currently implemented in `win_runtime.lvm`:
- RT_Halt, RT_EmitImports, RT_InitConsole (RT_EmitInitConsole)
- RT_GetMem/FreeMem/AllocMem/ReAllocMem/MemSize (RT_Emit* wrappers)
- RT_Print, RT_Println, RT_AllocStr, RT_GetDll

Everything else is defined in this contract but not yet implemented.
