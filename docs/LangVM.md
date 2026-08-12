<div align="center">

![LangVM](../media/langvm.jpg)

</div>

<a id="what-is-langvm"></a>

## 🔧 What is LangVM?

**LangVM** is a pipeline-driven language virtual machine. You feed it a language definition written as a `.lvm` script, and it gives you a working language -- complete with lexer, parser, semantic analysis, and code generation -- without writing a single line of C, Java, or LLVM IR.

The `.lvm` scripting language is **Turing complete**. This is not a configuration format or a template language -- it is a full programming language with variables, control flow, recursion, data structures, and ~200 builtins. Turing completeness is what makes the entire architecture possible: the x86_64 instruction encoder (890 lines), the PE image writer (928 lines), the ELF writer (1498 lines), and the ABI handling (521 lines) are all written in `.lvm` scripts. Without a Turing-complete scripting layer, none of this could live in script.

Write a `.lvm` script. Run `lvm`. Get a working language.

```lvm
language 1 version "1.0.0";

tokens {
  casesensitive;
  keyword "print";
  keyword "let";
  string single;
  linecomment "//";
}

grammar {
  rule stmt "let" {
    let node = createNode("let_decl");
    advance();
    setAttr(node, "name", currentText());
    requireToken("ident");
    requireToken("=");
    let val = parseExpr();
    addChild(node, val);
    return node;
  }
}

routine main() {
  println("Language defined!");
}
```

```
> lvm -l mylang.lvm
Language defined!
```

> [!TIP]
> 💡 **Fast path:** read [Getting Started](#getting-started), skim [Language Reference](#language-reference), then jump into [How-To Guide](#how-to-guide) when you want copy-paste examples.

### 🚦 Documentation Roadmap

| Reader Goal | Start Here | Why |
|-------------|------------|-----|
| 🚀 Run your first program | [Getting Started](#getting-started) | Install, first `.lvm` script, CLI usage |
| 📘 Learn the script language | [Language Reference](#language-reference) | Types, routines, records, control flow, imports |
| 🧾 Verify exact syntax | [Formal Grammar](#formal-grammar) | BNF rules derived from the parser |
| 🔩 Define a language | [Pipeline Blocks](#pipeline-blocks) | tokens, types, grammar, semantics, emitters |
| 🧬 Use the MIR backend | [MIR Reference](#mir-reference) | Textual format, programmatic builtins, native codegen |
| 📚 Look up a builtin | [Builtin Functions](#builtin-functions) | All ~200 builtins, categorized with signatures |
| 🔌 Embed in Delphi | [API Reference](#api-reference) | TLangVM lifecycle, methods, callbacks, host objects |
| 🧪 Solve a task | [How-To Guide](#how-to-guide) | Practical recipes with complete examples |
| 🖥️ Run from the command line | [CLI Reference](#cli-reference) | LVM.exe flags, build scripts, examples |

### 💡 Core Idea

LangVM is a virtual machine purpose-built for implementing computer languages. The pipeline goes:

```text
.lvm script  ->  tokens{} / types{} / grammar{} / semantics{} / emitters{}  ->  working language
```

The VM reads your `.lvm` script at startup and configures itself: the `tokens` block defines keywords and operators, the `grammar` block defines parsing rules using a Pratt parser, the `semantics` block runs analysis passes, and the `emitters` block generates output. Everything is scripted -- no recompilation needed to change the language.

> [!IMPORTANT]
> 🧱 LangVM is not a compiler that produces a standalone language tool. It IS the language tool -- a runtime that executes language definitions. Feed it a different `.lvm` script and you get a different language.

### ✨ Key Features

| Feature | What It Means |
|---------|---------------|
| **🧰 Zero external dependencies** | Single Delphi unit (~13K lines). No LLVM, no ANTLR, no external parsers. |
| **🔩 Pipeline architecture** | Define tokens, grammar, semantics, and emitters in declarative blocks inside your `.lvm` script. |
| **🧠 Pratt parsing engine** | Runtime-configurable operator precedence parser. Define prefix, infix, and statement rules in script. |
| **🧬 MIR backend** | Full intermediate representation with types, opcodes, registers, and labels -- for scripts that need native code generation. |
| **📦 ~200 builtin functions** | Strings, lists, maps, buffers, file I/O, math, AST manipulation, binary construction, DLL loading, and more. |
| **🔌 Embeddable** | Delphi host API: `Create`, `LoadScriptFile`, `Run`, `Call`, `GetVar`, `SetVar`, `RegisterBuiltin`. |
| **🖥️ Standalone CLI** | `LVM.exe` runs any `.lvm` script from the command line with source file passthrough. |
| **🏗️ Cross-platform potential** | Architecture designed so any runtime implementing the same API and builtins runs the same `.lvm` scripts. |

### 🏗️ Architecture

```
.lvm Script
    |
    v
+-------------------------------------------+
|  LangVM Runtime                           |
|                                           |
|  Lexer --> Parser --> AST                 |
|              |                            |
|              v                            |
|  Pipeline Block Walking                   |
|    tokens{} / types{} / grammar{}         |
|    semantics{} / emitters{} / mir{}       |
|              |                            |
|              v                            |
|  Tree-Walking Interpreter                 |
|    (statements, expressions, builtins)    |
+-------------------------------------------+
    |                          |
    v                          v
Script output            MIR Program
(println, files,         (modules, funcs,
 buffers, etc.)           instructions)
                               |
                               v
                         Binary output
                         (PE/ELF via
                          buffer builtins)
```

The VM is built as a single-pass pipeline. The lexer tokenizes `.lvm` source, the parser builds an AST, and the tree-walker executes it. Pipeline blocks (`tokens`, `types`, `grammar`, `semantics`, `emitters`) configure the generic lexer and parser at runtime. MIR blocks define intermediate representation programs that can be walked and emitted as native code.

### 🧩 Component Map

| Component | Description |
|-----------|-------------|
| **TLVMLexer** | Tokenizes `.lvm` source into a stream of typed tokens |
| **TLVMParser** | Recursive-descent parser that builds an AST from the token stream |
| **TLVMASTNode** | Tree node structure for the abstract syntax tree |
| **TLangVM** | Main VM class: builtin registry, statement execution, expression evaluation |
| **TLVMGenericLexer** | Runtime-configurable lexer driven by `tokens{}` block definitions |
| **TLVMGenericParser** | Runtime-configurable Pratt parser driven by `grammar{}` block definitions |
| **TLVMScope / TLVMEnvironment** | Variable storage with block scoping |
| **TLVMScopeManager** | Semantic analysis scope tracking |
| **TLVMMirProgram** | MIR intermediate representation: modules, functions, instructions |
| **TLVMCLI** | Command-line interface: argument parsing, banner, error display, script execution |

### 🎯 Who Is This For?

- **Language designers** who want to prototype a language without building a compiler from scratch. Define your grammar, semantics, and output in a single `.lvm` script and iterate instantly.
- **Compiler writers** who need a scriptable frontend that can lex, parse, analyze, and generate MIR for arbitrary languages.
- **Tool builders** who need an embeddable language engine. Create a `TLangVM`, register custom builtins, load a script, and call routines from Delphi.
- **Educators** teaching compiler construction. LangVM makes every stage of the pipeline visible and editable without recompilation.

### 🖥️ CLI Reference

<a id="cli-reference"></a>

LangVM includes a standalone command-line runner (`LVM.exe`) for executing `.lvm` scripts directly.

**Syntax:**

```
LVM.exe -l <script.lvm> [OPTIONS]
```

**Required:**

| Flag | Description |
|------|-------------|
| `-l, --lang <file>` | LVM script file (.lvm) to execute |

**Options:**

| Flag | Description |
|------|-------------|
| `-s, --source <file>` | Source file for the script to process (sets `SourceFilename` in the VM) |
| `-h, --help` | Display help message |

**Examples:**

```
lvm -l mylang.lvm
lvm -l mylang.lvm -s hello.src
```

**Build and run scripts** (Windows):

```
bin\build-lvm.cmd          -- compiles LVM.exe (Release/Win64)
bin\run-lvm.cmd -l my.lvm  -- runs LVM.exe with console wrapper
```

> [!NOTE]
> The `-s` flag sets the `SourceFilename` well-known global inside the VM. Your `.lvm` script reads it with `getVar("SourceFile")` or the `SourceFilename` environment variable to know which file the host wants processed.

### 📌 Current Status

The VM is working end-to-end with support for:

- Value types: nil, int, float, bool, string, handle, list, map, routine, buffer
- Declarations: `let`, `const`, `enum`, `record`, `routine`, `fragment`
- Control flow: `if`/`else`, `while`, `for..in`, `match`, `guard`, `try`/`recover`, `break`, `continue`, `return`
- String interpolation, triple-quoted strings, multiline strings
- ~200 builtin functions across 15+ categories
- Pipeline blocks: `tokens`, `types`, `grammar`, `semantics`, `emitters`
- MIR: full intermediate representation with types, opcodes, labels, and programmatic construction
- Generic lexer/parser: runtime-configurable from `.lvm` definitions
- Import system with path resolution
- Structured error diagnostics with file, line, and column
- Host API: `LoadScriptFile`, `Run`, `Call`, `GetVar`, `SetVar`, `RegisterBuiltin`, host objects
- CLI runner: `LVM.exe` with `-l` and `-s` flags

### 💻 System Requirements

| Area | Requirement |
|------|-------------|
| **Operating system** | Windows 10/11 x64 |
| **Runtime dependencies** | None |
| **External toolchain** | None |
| **Building from source** | Delphi 12.x or higher |

### 🗺️ Table of Contents

- 🚀 [Getting Started](#getting-started): embedding TLangVM, running scripts, host communication
- 📘 [Language Reference](#language-reference): types, operators, routines, control flow, records, enums, imports
- 🧾 [Formal Grammar](#formal-grammar): BNF rules derived from the parser
- 🔩 [Pipeline Blocks](#pipeline-blocks): tokens, types, grammar, semantics, emitters
- 🧬 [MIR Reference](#mir-reference): textual format and programmatic builtins
- 📚 [Builtin Functions](#builtin-functions): all ~200 builtins, categorized
- 🔌 [API Reference](#api-reference): TLangVM Delphi host API
- 🧪 [How-To Guide](#how-to-guide): practical recipes for common tasks
- ✍️ [Code Style](#code-style): .lvm script coding conventions
- 🖥️ [CLI Reference](#cli-reference): LVM.exe command-line runner

<a id="getting-started"></a>

## Getting Started

This section gets you from zero to a working language definition. For language details, see [Language Reference](#language-reference). For the full pipeline reference, see [Pipeline Blocks](#pipeline-blocks). For task-based examples, see [How-To Guide](#how-to-guide).


### Requirements

- Windows 10 or later, x64
- No external compiler, linker, SDK, runtime, or package manager

> [!NOTE]
> LangVM is self-contained. The lexer, parser, tree-walker, pipeline engine, MIR backend, and ~200 builtins are all built into a single Delphi unit.


### What LangVM Is

LangVM is a **language workbench** -- a virtual machine purpose-built for implementing computer languages. You write a `.lvm` script that **defines** a language, and LangVM becomes a working implementation of that language. Change the script, change the language. No recompilation of the VM itself.

Every `.lvm` script can use two kinds of constructs:

| Construct | Purpose |
|-----------|---------|
| Script language | Routines, variables, control flow, builtins -- general-purpose scripting that drives the pipeline |
| Pipeline blocks | `tokens{}`, `grammar{}`, `semantics{}`, `emitters{}` -- declarations that define your language |

The scripting features exist to serve the pipeline. The pipeline is the point.


### Your First Script

Create a file named `hello.lvm`:

```lvm
language 1 version "1.0.0";

routine main() {
  println("Hello, LangVM!");
}
```

Run it from the command line:

```
lvm -l hello.lvm
```

Expected output:

```
Hello, LangVM!
```

> [!TIP]
> Every `.lvm` file starts with a `language` declaration that specifies the script version. The entry point is always `routine main()`.


### Your First Language

The real power of LangVM is defining languages. Here is a complete, working language definition -- a tiny language with one statement (`say "text";`) that prints text to the console:

```lvm
language TestLang version "1.0";

tokens {
  casesensitive = true;
  token keyword.say = "say";
  token delimiter.semicolon = ";";
  token string.default = "\"";
  token comment.line = "//";
}

grammar {
  rule stmt.say {
    expect keyword.say;
    let text: string = currentText();
    advance();
    let nd: handle = getResultNode();
    setAttr(nd, "message", text);
    requireToken("delimiter.semicolon");
  }
}

semantics {
  on stmt.say {
    let msg: string = getAttr(node, "message");
    setShared("last_message", msg);
  }
}

emitters {
  on stmt.say {
    let msg: string = getAttr(node, "message");
    println(msg);
  }
}

routine main() {
  let source: string = 'say "hello"; say "world";';
  let toks: any = lexSource(source, "test.say");
  let ast: any = parseProgram(toks, "test.say");
  runEmitters(ast);
}
```

Run it:

```
lvm -l saylang.lvm
```

Output:

```
hello
world
```

What happened:

1. `tokens{}` told LangVM's generic lexer how to tokenize the source -- what keywords, delimiters, string styles, and comments to recognize
2. `grammar{}` told LangVM's generic Pratt parser how to parse `say "text";` into an AST node with a `message` attribute
3. `semantics{}` ran an analysis pass over the AST (here it just stores a shared value, but real languages do scope management, type checking, symbol resolution)
4. `emitters{}` walked the AST and generated output -- here it prints, but real languages emit MIR instructions for native code generation
5. `routine main()` fed source text through the pipeline: `lexSource()` tokenized it, `parseProgram()` parsed it, `runEmitters()` generated output

This is the full pipeline at its simplest. The same architecture scales to production languages -- the Myrissa language definition is 5,000+ lines of `.lvm` script defining 70+ keywords, a full Pratt parser grammar, semantic analysis with scope management and type checking, and code generation via MIR.

> [!TIP]
> For native code generation, emitters call `mir*` builtins (`mirBeginModule`, `mirInsn`, etc.) instead of `println`. The MIR backend -- including x86_64 instruction encoding, PE/ELF image writing, and ABI handling -- is itself written in `.lvm` scripts. See [MIR Reference](#mir-reference) and [Pipeline Blocks](#pipeline-blocks) for details.


### Embedding in Delphi

LangVM can be embedded in any Delphi application. The host creates a `TLangVM` instance, loads a script, and calls routines on it.

**Minimal embedding:**

```delphi
uses
  LangVM;

var
  LVM: TLangVM;
begin
  LVM := TLangVM.Create();
  try
    LVM.LoadScriptFile('saylang.lvm');
    LVM.Run('main');
  finally
    LVM.Free();
  end;
end;
```

Three calls: `Create`, `LoadScriptFile`, `Run`.


### Host-VM Communication

The host and the VM communicate through well-known environment variables and the public API.

**Well-known globals** (set by the host, read by the script, or vice versa):

| Variable | Type | Direction | Purpose |
|----------|------|-----------|---------|
| `ExitCode` | int | VM writes, host reads | Script's return status |
| `SourceFilename` | string | Host writes, VM reads | File the script should process |
| `Result` | any | VM writes, host reads | General-purpose return value |
| `Main` | string | Read-only | Name of the entry routine (default: `"main"`) |

**Setting and reading variables:**

```delphi
// Host sets a source file for the script to process
LVM.SourceFilename := 'input.src';

// Run the script
LVM.Run('main');

// Read the script's exit code
WriteLn('Exit code: ', LVM.ExitCode);

// Read any variable by name
WriteLn('Result: ', LVM.GetVar('Result').AsString());
```

> [!TIP]
> Use `ExitCode` for simple pass/fail status. Use `SetVar`/`GetVar` for richer data exchange.


### Registering Custom Builtins

The host can extend the VM with custom builtin functions written in Delphi:

```delphi
LVM.RegisterBuiltin('hostVersion',
  function(const AVM: TLangVM;
    const AArgs: TArray<TLVMValue>): TLVMValue
  begin
    Result := TLVMValue.FromString('1.0.0');
  end);
```

The script can then call `hostVersion()` like any other builtin.


### Error Handling

LangVM reports errors through a structured diagnostic system. The host can install a callback to receive errors with file, line, column, severity, and message:

```delphi
LVM.SetOnDiag(
  procedure(const ASeverity: string; const AMessage: string;
    const AFilename: string; const ALine, ACol: Integer;
    const AUserData: Pointer)
  begin
    WriteLn(Format('%s(%d,%d): %s: %s',
      [AFilename, ALine, ACol, ASeverity, AMessage]));
  end, nil);
```

Use `TryRun` for non-throwing execution:

```delphi
if not LVM.TryRun('main') then
  WriteLn('Script failed: ', LVM.LastError);
```

> [!NOTE]
> Errors are accumulated in `TLangVM.GetErrors()`. The VM does not raise Delphi exceptions for script errors -- it records diagnostics and continues where possible. Use `GetErrors().HasErrors()` to check after execution.


### Import Paths

When a `.lvm` script uses `import`, the VM searches for the imported file in registered import paths:

```delphi
LVM.AddImportPath('C:\MyProject\libs');
LVM.AddImportPath('C:\Shared\lvm-modules');
LVM.LoadScriptFile('main.lvm');
LVM.Run('main');
```

Import paths are searched in order. The script's own directory is always searched first.


### First-Project Checklist

Before moving from a sample to a real project:

- A `.lvm` script runs successfully with `lvm -l script.lvm`
- Pipeline blocks (`tokens`, `grammar`, `semantics`, `emitters`) define your language
- `lexSource()`, `parseProgram()`, and `runEmitters()` drive the pipeline from `main()`
- If embedding: the Delphi host creates `TLangVM`, loads the script, and calls `Run('main')`
- If embedding: host-VM communication uses `ExitCode`, `SourceFilename`, `SetVar`/`GetVar`
- Import paths are registered before loading the script
- A diagnostic callback is installed to capture errors
- Custom builtins (if any) are registered before loading the script


### Common First-Run Issues

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| Script does nothing | Missing `routine main()` | Every `.lvm` file needs a `main` routine |
| `unknown routine 'main'` | Script failed to parse | Check for syntax errors in the diagnostic output |
| `file not found` on import | Import path not registered | Call `AddImportPath` before `LoadScriptFile` |
| Variable not found | Reading a var the script did not declare | Use `HasVar` to check before `GetVar` |
| No output from `println` | Missing print callback | Call `SetOnPrint` before running the script |
| Pipeline produces no output | Missing `runEmitters(ast)` call | Pipeline blocks define the language, but `main()` must drive the pipeline with `lexSource`, `parseProgram`, `runEmitters` |

<a id="language-reference"></a>

## Language Reference

The `.lvm` scripting language is a **Turing-complete** language you use to build your pipeline. It provides variables, control flow, recursion, data structures, routines, and ~200 builtins -- everything needed to define languages, drive compilation passes, and construct native code, all from script.

This section covers the script language itself. For the pipeline blocks that define your language, see [Pipeline Blocks](#pipeline-blocks). For the MIR backend, see [MIR Reference](#mir-reference). For builtin functions, see [Builtins](#builtins).

> [!NOTE]
> The `.lvm` language is dynamically typed at runtime. Type annotations on `let` declarations are hints for readability and documentation, not compile-time enforcement.


### File Structure

Every `.lvm` file begins with a `language` declaration and contains top-level declarations (routines, constants, enums, records, fragments, imports) and pipeline blocks. The entry point is always `routine main()`.

```lvm
language 1 version "1.0.0";

import "helpers.lvm";

const {
  MAX_SIZE = 1024;
}

routine main() {
  println("Hello from LangVM");
}
```


### Value Types

| Type | Description | Example |
|------|-------------|---------|
| `nil` | Absence of value | `nil` |
| `int` | 64-bit signed integer | `42`, `-7`, `0xFF` |
| `float` | 64-bit floating point | `3.14`, `-0.5` |
| `bool` | Boolean | `true`, `false` |
| `string` | UTF-8 text | `"hello"`, `'single-quoted'` |
| `list` | Ordered collection | `[1, 2, 3]` |
| `map` | Key-value pairs | `{"name": "test", "value": 42}` |
| `handle` | Opaque reference (AST nodes, internal objects) | returned by builtins |
| `buffer` | Mutable byte buffer for binary data | created by `buffer()` builtin |
| `any` | Accepts any value type | used when the type varies |

Triple-quoted strings (`'''...'''`) are literal blocks -- no escape processing, no doubling of quotes:

```lvm
let code: string = '''
  routine main() {
    println('hello');
  }
''';
```


### Variables -- `let`

Variables are declared with `let`, followed by a name, type annotation, and optional initializer:

```lvm
let x: int = 42;
let name: string = "hello";
let flag: bool = true;
let items: list = [1, 2, 3];
```

Assignment uses `=`:

```lvm
x = 100;
name = "world";
```

Variables are block-scoped. A variable declared inside `if`, `while`, `for`, or any `{}` block is not visible outside it.


### Constants -- `const`

Constants are declared in a `const {}` block at the top level:

```lvm
const {
  PI = 3.14;
  MAX = 100;
  NAME = "test";
}
```

Constants are immutable and visible throughout the script.


### Enumerations -- `enum`

Enums declare named constants:

```lvm
enum Colors {
  Red,
  Green,
  Blue
}

let c: any = Red;
```


### Records -- `record`

Records declare structured data with named fields:

```lvm
record Point {
  x: 0;
  y: 0;
}
```

The `layout` modifier adds size-type annotations for binary layout definitions used in PE/ELF/COFF construction:

```lvm
record DosHeader layout {
  e_magic: u16 = 0x5A4D;
  e_cblp: u16 = 0;
  // ...
}
```


### Routines

Routines are declared with `routine`. Parameters are listed in parentheses. An optional return type follows `->`:

```lvm
routine add(a: int, b: int) -> int {
  return a + b;
}

routine greet(name: string) {
  println("Hello, " + name);
}
```

Routines are called with parentheses, even when there are no arguments:

```lvm
let r: int = add(3, 4);
greet("LangVM");
```


### Fragments

Fragments group reusable top-level declarations (routines, constants, enums) under a name. They are used to organize pipeline helper code:

```lvm
fragment helpers {
  routine formatHex(value: int) -> string {
    return toString(value);
  }
}
```


### Imports and Includes

`import` loads another `.lvm` file. All its top-level declarations (routines, constants, enums, records, fragments, pipeline blocks) become available:

```lvm
import "encode.lvm";
import "abi.lvm";
import "builders.lvm";
```

Import paths are resolved relative to the importing file's directory. When embedded in a Delphi host, additional search paths can be registered via `AddImportPath`.

`include` textually inserts another file's content at the include point.


### Control Flow

#### If/Else

```lvm
if x > 5 {
  println("big");
} else {
  println("small");
}
```

The `else` branch is optional. Chain with `else if` for multiple conditions.

#### While

```lvm
let i: int = 0;
while i < 5 {
  i = i + 1;
}
```

#### For..In

Iterates over lists:

```lvm
let items: list = [1, 2, 3];
for item in items {
  println(item);
}
```

#### Match

Pattern matching on values. Arms use `=>` and can match multiple patterns with `|`:

```lvm
match value {
  1 => { println("one"); }
  2 | 3 => { println("two or three"); }
  else => { println("other"); }
}
```

#### Guard

Guard evaluates an expression and executes the block only if it is truthy:

```lvm
guard someCondition {
  println("condition was true");
}
```

#### Try/Recover

Error handling. If an error occurs in the `try` block, execution jumps to `recover`:

```lvm
let caught: bool = false;
try {
  let x: int = 1 / 0;
} recover {
  caught = true;
}
```

#### Break and Continue

`break` exits the innermost loop. `continue` skips to the next iteration.


#### Return

Exits the current routine, optionally with a value:

```lvm
routine abs(x: int) -> int {
  if x < 0 {
    return -x;
  }
  return x;
}
```


### Operators

| Category | Operators |
|----------|-----------|
| Arithmetic | `+`, `-`, `*`, `/`, `%` |
| Comparison | `==`, `!=`, `<`, `>`, `<=`, `>=` |
| Logical | `and`, `or`, `not` |
| Assignment | `=` |
| Member access | `.` |
| Index | `[]` |
| Range | `..` |


### Comments

```lvm
// Single-line comment

/* Block comment
   can span multiple lines */
```


### Data Structures

#### Lists

Lists are ordered, heterogeneous collections:

```lvm
let items: list = [1, "hello", true, 3.14];
let first: any = items[0];
listAppend(items, "new item");
let count: int = len(items);
```

#### Maps

Maps are key-value collections with string keys. Fields are accessed with dot notation:

```lvm
let m: map = {"name": "test", "value": 42};
let n: string = m.name;
m.extra = true;
```

Maps can also be accessed with bracket notation: `m["name"]`.

#### Buffers

Buffers are mutable byte arrays used for binary data construction -- essential for the native code backend:

```lvm
let buf: buffer = buffer(256);
bufWriteU8(buf, 0, 0x90);     // NOP
bufWriteU32(buf, 1, 0x12345678);
bufSave(buf, "output.bin");
```

See [Builtins](#builtins) for the complete list of buffer operations.


### Pipeline Blocks (Overview)

Pipeline blocks are the mechanism for defining languages. They appear at the top level of a `.lvm` file and are detailed in [Pipeline Blocks](#pipeline-blocks):

| Block | Purpose |
|-------|---------|
| `tokens {}` | Define the lexer: keywords, operators, string styles, comments |
| `grammar {}` | Define the parser: Pratt parser rules for your language's syntax |
| `semantics {}` | Define analysis passes: scope, types, validation |
| `emitters {}` | Define code generation: walk the AST and emit output |
| `mir {}` | Define the backend: lower MIR events to machine code |

Pipeline blocks are declarations, not executable code. They are activated by calling `lexSource()`, `parseProgram()`, `runSemantics()`, `runEmitters()`, and `runMir()` from `routine main()`.

<a id="bnf-grammar"></a>

## BNF Grammar

Formal grammar for `.lvm` scripts, derived from the `TLVMParser.Parse*` methods in `LangVM.pas`. Terminals are shown in `'monospace'`. `{ X }` denotes zero or more repetitions. `[ X ]` denotes optional elements. `|` separates alternatives.


### Source File

```
SourceFile     = [ LanguageDecl ] { TopLevelBlock } .
LanguageDecl   = 'language' IDENT 'version' STRING ';' .
TopLevelBlock  = TokensBlock | TypesBlock | GrammarBlock
               | SemanticsBlock | EmittersBlock | MirBlock
               | ConstBlock | EnumDecl | RoutineDecl
               | FragmentDecl | RecordDecl
               | ImportStmt | IncludeStmt | GuardBlock
               | Stmt .
```


### Declarations

```
ConstBlock     = 'const' '{' { ConstDecl } '}' .
ConstDecl      = IDENT '=' Expr ';' .

EnumDecl       = 'enum' IDENT '{' IDENT { ',' IDENT } '}' .
```

```
RoutineDecl    = 'routine' IDENT '(' [ ParamList ] ')' [ '->' TypeName ] StmtBlock .
ParamList      = Param { ',' Param } .
Param          = IDENT ':' TypeName .
TypeName       = IDENT { '.' IDENT } .

FragmentDecl   = 'fragment' IDENT '{' { TopLevelBlock } '}' .

RecordDecl     = 'record' IDENT [ 'layout' ] '{' { RecordField } '}' .
RecordField    = IDENT ':' ( SizeType '=' Expr | Expr ) ';' .
SizeType       = IDENT .

ImportStmt     = 'import' STRING ';' .
IncludeStmt    = 'include' STRING ';' .

GuardBlock     = 'guard' Expr StmtBlock .
```


### Statements

```
StmtBlock      = '{' { Stmt } '}' .

Stmt           = LetStmt | IfStmt | WhileStmt | ForStmt
               | MatchStmt | GuardStmt | ReturnStmt
               | BreakStmt | ContinueStmt | TryRecover
               | ExpectStmt | ConsumeStmt | ParseDirective
               | OptionalBlock | SyncStmt | ScopeBlock
               | DeclareStmt | VisitStmt | LookupStmt
               | SectionBlock | DiagStmt
               | AssignOrExprStmt .
```

```
LetStmt        = 'let' IDENT ':' TypeName '=' Expr ';' .

IfStmt         = 'if' Expr StmtBlock { 'else' 'if' Expr StmtBlock } [ 'else' StmtBlock ] .

WhileStmt      = 'while' Expr StmtBlock .

ForStmt        = 'for' IDENT 'in' Expr StmtBlock .

MatchStmt      = 'match' Expr '{' { MatchArm } [ MatchElse ] '}' .
MatchArm       = Expr { '|' Expr } '=>' StmtBlock .
MatchElse      = 'else' '=>' StmtBlock .

GuardStmt      = 'guard' Expr StmtBlock .

ReturnStmt     = 'return' [ Expr ] ';' .

BreakStmt      = 'break' ';' .

ContinueStmt   = 'continue' ';' .

TryRecover     = 'try' StmtBlock 'recover' StmtBlock .

DiagStmt       = ( 'error' | 'warning' | 'hint' | 'note' | 'info' ) Expr ';' .

AssignOrExprStmt = IDENT '=' Expr ';'
               | Expr '=' Expr ';'
               | Expr ';' .
```


### Pipeline Statements (used inside grammar/semantics/emitters rules)

```
ExpectStmt     = 'expect' TokenRef ';' .
ConsumeStmt    = 'consume' TokenRef '->' '@' IDENT ';' .
ParseDirective = 'parse' ParseMode '->' '@' IDENT ';' .
ParseMode      = 'expr' | 'stmt' | 'many' 'stmt' 'until' TokenRef .
OptionalBlock  = 'optional' StmtBlock .
SyncStmt       = 'sync' TokenRef ';' .
ScopeBlock     = 'scope' ( STRING | '@' IDENT ) StmtBlock .
DeclareStmt    = 'declare' '@' IDENT 'as' IDENT [ 'typed' '@' IDENT ] ';' .
VisitStmt      = 'visit' ( 'children' | 'child' '[' Expr ']' | '@' IDENT ) ';' .
LookupStmt     = 'lookup' '@' IDENT ( '->' 'let' IDENT | 'or' StmtBlock ) ';' .
SectionBlock   = 'section' IDENT StmtBlock .

TokenRef       = IDENT '.' IDENT
               | '[' IDENT '.' IDENT { ',' IDENT '.' IDENT } ']'
               | 'identifier' .
```


### Pipeline Blocks

```
TokensBlock    = 'tokens' '{' { TokenDecl | TokenConfig | IncludeStmt | GuardBlock } '}' .
TokenDecl      = 'token' IDENT '.' IDENT '=' STRING ';' .
TokenConfig    = IDENT '=' ( STRING | IDENT | 'true' | 'false' ) ';' .
```

```
TypesBlock     = 'types' '{' { TypeDecl | IncludeStmt | GuardBlock } '}' .
TypeDecl       = 'type' IDENT '=' STRING ';'
               | 'map' STRING '->' STRING ';'
               | 'literal' STRING '=' STRING ';'
               | 'compatible' STRING ',' STRING [ '->' STRING ] ';'
               | ( 'decl_kind' | 'call_kind' ) STRING ';'
               | 'call_name_attr' '=' STRING ';' .

GrammarBlock   = 'grammar' '{' { RuleDecl } '}' .
RuleDecl       = 'rule' IDENT '.' IDENT [ 'precedence' ( 'left' | 'right' ) INT ] '{' { Stmt } '}' .

SemanticsBlock = 'semantics' '{' { PassBlock | SemanticDecl } '}' .
PassBlock      = 'pass' INT STRING '{' { SemanticDecl } '}' .
SemanticDecl   = 'on' IDENT '.' IDENT '{' { Stmt } '}' .

EmittersBlock  = 'emitters' '{' { EmitDecl } '}' .
EmitDecl       = 'on' IDENT '.' IDENT '{' { Stmt } '}' .

MirBlock       = 'mir' '{' { MirHandlerDecl } '}' .
MirHandlerDecl = 'on' IDENT '{' { Stmt } '}' .
```


### Expressions

```
Expr           = OrExpr .
OrExpr         = AndExpr { 'or' AndExpr } .
AndExpr        = NotExpr { 'and' NotExpr } .
NotExpr        = 'not' Comparison | Comparison .
Comparison     = Addition [ CompOp Addition ] .
CompOp         = '==' | '!=' | '<' | '>' | '<=' | '>=' .
Addition       = Term { ( '+' | '-' ) Term } .
Term           = Factor { ( '*' | '/' | '%' ) Factor } .
Factor         = '-' Atom | Atom .
```

```
Atom           = INT | FLOAT | STRING | TRIPLESTRING
               | 'true' | 'false' | 'nil'
               | '@' IDENT
               | IDENT
               | '(' Expr ')'
               | '[' [ Expr { ',' Expr } ] ']'
               | '{' [ STRING ':' Expr { ',' STRING ':' Expr } ] '}' .

PostfixOp      = '(' [ Expr { ',' Expr } ] ')'
               | '.' IDENT
               | '[' Expr ']' .
```

Postfix operators (call, dot access, index) bind left-to-right and can be chained: `obj.field[0].method(arg)`.


### MIR Textual Format

The MIR textual format is parsed by `ParseMirBlock` and defines a complete intermediate representation:

```
MirModule      = MirWord ':' 'module' { MirItem } 'endmodule' .

MirItem        = MirImport | MirExport | MirForward | MirProto
               | MirFunc | MirData .

MirImport      = 'import' MirWord { ',' MirWord } .
MirExport      = 'export' MirWord { ',' MirWord } .
MirForward     = 'forward' MirWord { ',' MirWord } .

MirProto       = MirWord ':' 'proto' Signature .
MirFunc        = MirWord ':' 'func' Signature
                 { MirLocal } { MirFuncBody } 'endfunc' .
MirLocal       = MirWord ':' 'local' MirType .
MirFuncBody    = MirLabel | MirInsn .
MirLabel       = MirWord ':' .
MirInsn        = MirWord Operand { ',' Operand } .

MirData        = MirWord ':' DataKind DataBody .
DataKind       = 'string' | 'data' | 'bss' | 'rodata' .
DataBody       = STRING | INT | '{' { DataEntry } '}' .
DataEntry      = MirType INT ';' | 'zeros' INT ';' | 'align' INT ';' .

Signature      = MirType [ ':' MirWord ] { ',' MirType [ ':' MirWord ] } [ ',' '...' ] .
Operand        = INT | FLOAT | STRING | MirWord
               | MirType ':' [ INT ] '(' MirWord [ ',' MirWord [ ',' INT ] ] ')' .

MirWord        = IDENT | any keyword .
MirType        = 'i8' | 'i16' | 'i32' | 'i64' | 'u8' | 'u16' | 'u32' | 'u64'
               | 'f32' | 'f64' | 'void' | 'ptr' | 'bool' | 'str' | 'label' .
```


### Lexical Elements

```
IDENT          = letter { letter | digit | '_' } .
INT            = digit { digit } | '0x' hexdigit { hexdigit } .
FLOAT          = digit { digit } '.' digit { digit } .
STRING         = '"' { char } '"' | "'" { char } "'" .
TRIPLESTRING   = "'''" { any } "'''" .
COMMENT        = '//' { any } newline | '/*' { any } '*/' .
```

<a id="pipeline-blocks"></a>

## Pipeline Blocks

Pipeline blocks are the mechanism for defining languages in LangVM. They appear at the top level of a `.lvm` file and configure LangVM's runtime-configurable lexer, parser, and code generation engine. This section is the reference for each block type. For working examples, see the Myrissa frontend definition (`.claude/research/myrissa/language/`) and the x86_64 backend scripts (`bin/res/backend/x86_64/`).

The pipeline flows in one direction:

```
tokens{} -> grammar{} -> semantics{} -> emitters{} -> mir{}
```

Each stage takes the output of the previous one. The `routine main()` drives the pipeline by calling `lexSource()`, `parseProgram()`, `runSemantics()`, `runEmitters()`, and `runMir()`.


### tokens {}

The `tokens` block configures LangVM's generic lexer. It declares keywords, operators, delimiters, string styles, comment styles, and directives that the lexer should recognize when tokenizing your language's source code.

#### Configuration Options

```lvm
tokens {
  casesensitive = true;         // Whether keywords are case-sensitive
  terminator = ";";             // Statement terminator character
  block_open = "{";             // Block open delimiter
  block_close = "}";            // Block close delimiter
  directive_prefix = "@";       // Prefix for directives
  hex_prefix = "0x";            // Hex literal prefix
}
```

#### Token Declarations

Tokens are declared with `token category.name = "pattern";`. The category determines how the lexer processes the token:

| Category | Purpose | Example |
|----------|---------|---------|
| `keyword.*` | Reserved words | `token keyword.if = "if";` |
| `op.*` | Operators | `token op.assign = ":=";` |
| `delimiter.*` | Punctuation | `token delimiter.semicolon = ";";` |
| `string.*` | String literal styles | `token string.default = "\"";` |
| `comment.line` | Line comment opener | `token comment.line = "//";` |
| `comment.block_open` | Block comment open | `token comment.block_open = "/*";` |
| `comment.block_close` | Block comment close | `token comment.block_close = "*/";` |
| `directive.*` | Compiler directives | `token directive.define = "define";` |
| `literal.*` | Literal patterns | `token literal.integer = "integer";` |

#### Token Flags

Token declarations can include optional flags in brackets:

```lvm
token string.wide = "w\"" [wide];
token string.raw  = "r\"" [raw, close "\""];
token directive.ifdef = "ifdef" [no_terminator];
```

The `close` flag specifies an explicit closing delimiter. Without it, the closing delimiter defaults to the last character of the opening pattern.

#### Real-World Example (from Myrissa)

The Myrissa token definition (`myrissa_tokens.mld`, 347 lines) declares 70+ keywords, operators, comment styles, two string styles (C-style and wide), directives with conditional compilation, and a full type system. A snippet:

```lvm
tokens {
  casesensitive = true;

  token keyword.if     = "if";
  token keyword.then   = "then";
  token keyword.else   = "else";
  token keyword.while  = "while";

  token op.assign      = ":=";
  token op.plusassign   = "+=";
  token op.eq          = "=";
  token op.neq         = "<>";

  token comment.line       = "//";
  token comment.block_open = "/*";
  token comment.block_close= "*/";

  token string.default = "\"";
  token string.wide    = "w\"" [wide];
}
```


### types {}

The `types` block defines the type system for your language -- type keywords, type mappings, literal-to-type mappings, and type compatibility rules.

| Declaration | Syntax | Purpose |
|-------------|--------|---------|
| `type` | `type ident = "backend_type";` | Map a language type name to a backend type |
| `map` | `map "from" -> "to";` | Map one type name to another |
| `literal` | `literal "pattern" = "type";` | Assign a type to literal expressions |
| `compatible` | `compatible "from", "to" [-> "via"];` | Declare type compatibility (implicit conversion) |
| `decl_kind` | `decl_kind "kind";` | Set the declaration kind for type declarations |
| `call_kind` | `call_kind "kind";` | Set the call kind for function calls |
| `call_name_attr` | `call_name_attr = "attr";` | Set the attribute name used for call names |

Example from Myrissa:

```lvm
types {
  type int8    = "i8";
  type int16   = "i16";
  type int32   = "i32";
  type int64   = "i64";
  type float32 = "f32";
  type float64 = "f64";
  type string  = "str";
  type boolean = "bool";

  literal "expr.integer" = "int32";
  literal "expr.float"   = "float64";
  literal "expr.cstring" = "string";

  compatible "int8", "int16";
  compatible "int16", "int32";
  compatible "int32", "int64";
  compatible "float32", "float64";
}
```


### grammar {}

The `grammar` block defines your language's parser using Pratt parser rules. Each rule handles one syntactic form -- a prefix expression, an infix expression, or a statement. LangVM's generic parser executes these rules at runtime to parse your language's source into an AST.

#### Rule Declarations

```lvm
grammar {
  rule category.name { ... }
  rule category.name precedence left 10 { ... }
}
```

The `category` determines how the rule is dispatched:

| Category | Role | When fired |
|----------|------|------------|
| `expr.*` | Prefix expression | When the parser sees a token matching this rule in prefix position |
| `expr.*` (with precedence) | Infix expression | When the parser sees a token in infix position at matching precedence |
| `stmt.*` | Statement | When the parser sees a token at statement level |

Precedence and associativity (`left` or `right`) control operator binding for infix rules.

#### Pipeline Builtins Available in Grammar Rules

These builtins are available inside grammar rule bodies to interact with the generic parser:

| Builtin | Purpose |
|---------|---------|
| `expect token_ref;` | Require and consume a specific token |
| `consume token_ref -> @attr;` | Consume a token and store its text in an AST attribute |
| `parse expr -> @attr;` | Recursively parse an expression, store in attribute |
| `parse stmt -> @attr;` | Recursively parse a statement, store in attribute |
| `parse many stmt until token_ref -> @attr;` | Parse statements until a delimiter |
| `optional { ... }` | Try the block; backtrack if it fails |
| `sync token_ref;` | Skip tokens until the sync token is found (error recovery) |
| `advance()` | Consume current token |
| `currentText()` | Text of current token |
| `currentKind()` | Kind of current token |
| `checkToken("kind")` | Check if current token matches |
| `getResultNode()` | Get the AST node being built for this rule |
| `setAttr(node, "key", value)` | Set an attribute on an AST node |
| `getAttr(node, "key")` | Get an attribute from an AST node |
| `requireToken("kind")` | Require and consume a token (simpler than expect) |

#### Real-World Example (from Myrissa)

The Myrissa grammar definition (`myrissa_grammar.mld`, 1544 lines) defines a complete Pratt parser for a Pascal/Oberon-style language. Some representative rules:

```lvm
grammar {
  // Prefix: integer literal with optional hex
  rule expr.integer {
    consume literal.integer -> @value;
    let nd = getResultNode();
    if getAttr(nd, "value") == "0" and checkToken("identifier") {
      let rest = currentText();
      if startsWith(rest, "x") or startsWith(rest, "X") {
        advance();
        setAttr(nd, "value", "0" + rest);
      }
    }
  }

  // Infix: binary addition, left-associative, precedence 3
  rule expr.binary precedence left 3 {
    consume [op.plus, op.minus] -> @op;
    parse expr -> @right;
  }

  // Statement: if/then/else
  rule stmt.if {
    expect keyword.if;
    parse expr -> @condition;
    expect keyword.then;
    parse many stmt until [keyword.else, keyword.end] -> @body;
    optional {
      expect keyword.else;
      parse many stmt until keyword.end -> @else_body;
    }
    expect keyword.end;
    expect delimiter.semicolon;
  }

  // Statement: variable declaration
  rule stmt.var_decl {
    consume identifier -> @name;
    expect delimiter.colon;
    parse expr -> @type;
    optional {
      expect op.eq;
      parse expr -> @init;
    }
    expect delimiter.semicolon;
  }
}
```


### semantics {}

The `semantics` block defines analysis passes that walk the AST after parsing. Each `on` handler fires when the walker encounters a matching node kind. Handlers can declare symbols, manage scopes, check types, and stamp attributes on AST nodes for use by emitters.

#### Structure

```lvm
semantics {
  // Single-pass (all handlers in one pass)
  on category.name { ... }

  // Multi-pass (handlers grouped by numbered passes)
  pass 1 "Declarations" {
    on stmt.var_decl { ... }
    on stmt.routine_decl { ... }
  }
  pass 2 "Type checking" {
    on expr.binary { ... }
    on expr.call { ... }
  }
}
```

#### Semantic Builtins

| Builtin | Purpose |
|---------|---------|
| `scope "name" { ... }` | Push a named scope, execute block, pop scope |
| `scope @attr { ... }` | Push a scope named by an AST attribute |
| `declare @attr as kind;` | Declare a symbol from an attribute value |
| `declare @attr as kind typed @type;` | Declare a typed symbol |
| `lookup @attr -> let name;` | Look up a symbol, bind to variable |
| `lookup @attr or { ... };` | Look up a symbol, execute block if not found |
| `visit children;` | Visit all child nodes (triggers their handlers) |
| `visit child[n];` | Visit a specific child by index |
| `visit @attr;` | Visit the node stored in an attribute |
| `section name { ... }` | Named section for organization |
| `error expr;` | Emit an error diagnostic |
| `warning expr;` | Emit a warning diagnostic |
| `hint expr;` | Emit a hint |
| `note expr;` | Emit a note |
| `info expr;` | Emit an info message |

#### Real-World Example (from Myrissa)

The Myrissa semantic analysis (`myrissa_semantics.mld`, 685 lines) handles scope management, symbol declaration, type checking, and attribute stamping:

```lvm
semantics {
  on program.root {
    scope "global" {
      visit children;
    }
  }

  on stmt.module {
    let kind = getAttr(node, "module.kind");
    if kind == "exe" { setBuildMode("exe"); }
    else if kind == "lib" { setBuildMode("lib"); }
    else if kind == "dll" { setBuildMode("dll"); }
    visit children;
  }

  on stmt.var_decl {
    declare @name as "variable" typed @type;
    visit children;
  }

  on stmt.routine_decl {
    declare @name as "routine";
    scope @name {
      visit children;
    }
  }

  on expr.ident {
    lookup @name or {
      error "Undeclared identifier: " + getAttr(node, "name");
    };
  }
}
```


### emitters {}

The `emitters` block defines code generation. Each `on` handler fires when the AST walker encounters a matching node kind. Emitters produce output -- printing text, calling `ir*` builtins for the old Delphi backend, or calling `mir*` builtins for the scriptable MIR backend.

#### Structure

```lvm
emitters {
  on category.name { ... }
}
```

Handlers have access to all standard .lvm builtins plus the AST traversal builtins (`getAttr`, `setAttr`, `node`, `child_count`, `getChild`, `nodeKind`, `emitChildren`).

#### Simple Example (print output)

```lvm
emitters {
  on stmt.say {
    let msg: string = getAttr(node, "message");
    println(msg);
  }
}
```

#### Native Code Example (MIR output)

For native code generation, emitters call `mir*` builtins to build a MIR program:

```lvm
emitters {
  on stmt.say {
    let msg: string = getAttr(node, "message");
    let label: string = mirString("s_" + toString(g_str_count), msg);
    g_str_count = g_str_count + 1;
    mirInsn("call", "p_printf", "printf", "_", label);
  }
}
```

See [MIR Reference](#mir-reference) for the complete list of `mir*` builtins.


### mir {}

The `mir` block defines the backend -- the stage that lowers MIR (Machine Intermediate Representation) events into actual machine code. Each `on` handler fires at a specific point in the MIR lowering process. The MIR backend is what makes LangVM's native code generation fully scriptable.

#### Events

| Event | When fired | Available data |
|-------|------------|----------------|
| `on module` | Start of a MIR module | `imports` (list of imported function names) |
| `on func` | Start of a function | `name`, `params`, `result_types` |
| `on insn` | Each MIR instruction | `opcode`, `operands` |
| `on string` | String data item | `name`, `value` |
| `on data` | Data item | `name`, `value` |
| `on endfunc` | End of a function | |
| `on endmodule` | End of the module | |

#### Real-World Example (from mir_full_pipeline.lvm)

This is the actual backend from the end-to-end proof. It takes MIR events and emits x86_64 machine code, then writes a PE executable:

```lvm
mir {
  on module {
    g_ib = ib_create();
    g_import_map = {};
    // Map imported functions to DLLs
    let dll_map: map = {
      "printf": "msvcrt.dll",
      "ExitProcess": "kernel32.dll"
    };
    let i: int = 0;
    while i < len(imports) {
      let fname: string = imports[i];
      let idx: int = ib_add(g_ib, dll_map[fname], fname);
      g_import_map[fname] = idx;
      i = i + 1;
    }
    g_cb = cb_create(1024);
    g_db = db_create();
    g_str_map = {};
  }

  on string {
    let h: int = db_add_string(g_db, value);
    g_str_map[name] = h;
  }

  on func {
    // Win64 prologue: sub rsp, 0x28
    cb_emit_sub_rsp_imm8(g_cb, 0x28);
  }

  on insn {
    if opcode == "call" {
      // Encode arguments into Win64 registers, emit call
      // ... (register assignment, LEA for strings, CALL via IAT)
    }
  }

  on endfunc {
    // Win64 epilogue: add rsp, 0x28; ret
    cb_emit_add_rsp_imm8(g_cb, 0x28);
    cb_emit_ret(g_cb);
  }

  on endmodule {
    // Build PE image and write to disk
    let image: map = pe_build_exe(
      cb_get_buf(g_cb), cb_get_pos(g_cb), 0,
      cb_get_iat_fixups(g_cb), ib_to_imports(g_ib),
      db_get_buf(g_db), db_get_size(g_db),
      cb_get_data_fixups(g_cb), nil, 0, []);
    bufSave(image, exe_path);
    ExitCode = runPE(exe_path);
  }
}
```

The production x86_64 backend (`bin/res/backend/x86_64/`, ~165KB of .lvm script) provides the full infrastructure: `encode.lvm` (instruction encoding), `abi.lvm` (Win64/SysV calling conventions), `builders.lvm` (code/data/import builders), `pe.lvm` (PE64 writer), `elf.lvm` (ELF64 writer), and `coff.lvm` (COFF .obj writer).


### Driving the Pipeline

Pipeline blocks are declarations -- they configure the engine but do not execute on their own. The `routine main()` drives the pipeline by calling these builtins in sequence:

```lvm
routine main() {
  // 1. Tokenize source with the configured generic lexer
  let toks: any = lexSource(source, "filename.src");

  // 2. Parse tokens with the configured generic parser
  let ast: any = parseProgram(toks, "filename.src");

  // 3. Run semantic analysis (optional)
  runSemantics(ast);

  // 4. Run emitters (code generation)
  runEmitters(ast);

  // 5. Lower MIR to native code (if emitters produced MIR)
  runMir();
}
```

Each call activates the corresponding pipeline stage using the declarations from the pipeline blocks. The pipeline is compositional -- you can use any subset of stages. A simple interpreter needs only `tokens{}`, `grammar{}`, and `emitters{}` (where emitters execute directly rather than emitting MIR). A native compiler uses all five stages.

<a id="mir-reference"></a>

## MIR Reference

MIR (Machine Intermediate Representation) is LangVM's **virtual CPU assembly language**. It sits between your language's frontend (grammar, semantics, emitters) and the native backend (x86_64 machine code, PE/ELF images). Think of it as a portable assembly language -- it has registers, typed instructions, calling conventions, branches, labels, and memory operands, just like a real CPU. But it runs nowhere. Its only purpose is to be lowered by your `mir{}` handlers into real machine instructions.

The full compilation chain:

```
Source text
  -> tokens{}    (lexer: text to tokens)
  -> grammar{}   (parser: tokens to AST)
  -> semantics{} (analysis: validate AST)
  -> emitters{}  (codegen: AST to MIR assembly)
  -> mir{}       (backend: MIR assembly to native machine code)
  -> PE/ELF binary
```

Emitters walk the AST and call `mir*` builtins to emit virtual assembly. The `mir{}` on-handlers then fire in sequence and translate each virtual instruction into real x86_64 (or whatever target) using the encoder, ABI, and image-writer scripts.

MIR can be constructed two ways: programmatically via `mir*` builtins (the normal path -- emitters call these), or written in a textual assembly format (useful for testing and standalone programs). Both produce the same data structures.


### MIR Types (Virtual Registers)

MIR registers are typed. These are the available data types:

| Type | Size | Description |
|------|------|-------------|
| `i8`, `i16`, `i32`, `i64` | 1/2/4/8 bytes | Signed integers |
| `u8`, `u16`, `u32`, `u64` | 1/2/4/8 bytes | Unsigned integers |
| `f` | 4 bytes | 32-bit float |
| `d` | 8 bytes | 64-bit double |
| `ld` | 10+ bytes | Long double |
| `p` | 8 bytes | Pointer |
| `void` | 0 | No value |
| `blk`, `blk1`..`blk5`, `rblk` | variable | Block/aggregate types |


### MIR Textual Format (Virtual Assembly)

MIR programs can be written directly in a textual assembly format. This reads like assembly for a virtual CPU:

```lvm
mir {
  m0: module
    import printf, ExitProcess
    export main

    p_printf: proto void, p:fmt, ...
    p_exit:   proto void, i32:code

    msg: string "Hello MIR!\n"

    main: func i64
      local i64:n
      mov n, 0
      add n, n, 1
      call p_printf, printf, msg
      call p_exit, ExitProcess, 0
      ret n
    endfunc
  endmodule
}

routine main() {
  runMir();
}
```

This is real assembly -- `mov`, `add`, `call`, `ret` -- just for a virtual CPU instead of x86_64. The `mir{}` on-handlers translate each instruction into the real thing.


### Instruction Set

MIR provides a complete virtual CPU instruction set. Opcode names map directly to the string passed to `mirInsn()`.

#### Naming Convention

- No suffix: 64-bit (`add`, `sub`, `mul`)
- `s` suffix: 32-bit (`adds`, `subs`, `muls`)
- `f`/`d`/`ld` prefix: float/double/long-double (`fadd`, `dadd`, `ldadd`)
- `u` prefix: unsigned (`umul`, `udiv`, `ult`)
- `b` prefix on branches: conditional branch (`beq`, `bne`, `blt`)

#### Instructions by Category

| Category | Instructions |
|----------|-------------|
| **Data movement** | `mov`, `fmov`, `dmov`, `ldmov` |
| **Integer arithmetic** | `add`, `sub`, `mul`, `div`, `mod`, `neg` (64-bit); `adds`..`negs` (32-bit); `umul`, `udiv`, `umod` (unsigned) |
| **Overflow-checked** | `addo`, `subo`, `mulo`, `umulo` (64-bit); `addos`..`umulos` (32-bit) |
| **Bitwise** | `and`, `or`, `xor`, `lsh`, `rsh`, `ursh` (64-bit); `ands`..`urshs` (32-bit) |
| **Comparison** | `eq`, `ne`, `lt`, `le`, `gt`, `ge`, `ult`, `ule`, `ugt`, `uge` (64-bit); 32-bit variants with `s` suffix |
| **Float arithmetic** | `fadd`, `fsub`, `fmul`, `fdiv`, `fneg` (float); `dadd`..`dneg` (double); `ldadd`..`ldneg` (long double) |
| **Float comparison** | `feq`..`fge` (float); `deq`..`dge` (double); `ldeq`..`ldge` (long double) |
| **Type conversion** | `ext8`, `uext8`, `ext16`, `uext16`, `ext32`, `uext32` (integer widening); `i2f`, `i2d`, `f2i`, `d2i`, `f2d`, `d2f` (int/float conversion) |
| **Address** | `addr`, `addr8`, `addr16`, `addr32` |
| **Unconditional branch** | `jmp`, `jmpi` (indirect) |
| **Conditional branch** | `bt` (branch if true), `bf` (branch if false), `bts`/`bfs` (32-bit) |
| **Overflow branch** | `bo`, `bno`, `ubo`, `ubno` |
| **Compare-and-branch** | `beq`, `bne`, `blt`, `ble`, `bgt`, `bge`, `ublt`..`ubge` (64-bit); 32-bit and float variants |
| **Switch** | `switch` |
| **Label address** | `laddr` |
| **Call/return** | `call`, `inline`, `ret`, `jcall` (indirect call), `jret` (indirect return) |
| **Stack** | `alloca`, `bstart`, `bend` |
| **Varargs** | `va_start`, `va_arg`, `va_block_arg`, `va_end` |
| **Properties** | `prset`, `prbeq`, `prbne` |


### Operand Kinds

| Kind | Description | Example |
|------|-------------|---------|
| Register | Named local/register | `n`, `result`, `tmp` |
| Immediate int | Integer constant | `42`, `-1`, `0xFF` |
| Immediate float | Float constant | `3.14` |
| Label | Branch target | `loop_start`, `exit` |
| Reference | Function/data name | `printf`, `msg` |
| Memory | Address: `type:disp(base,index,scale)` | `i64:8(rbp)`, `i32:(rsp)` |
| String | Inline string | `"hello"` |


### Programmatic API (mir* Builtins)

These builtins construct MIR assembly from emitter code. Emitters walk the AST and emit virtual assembly instructions -- the same instructions you would write in the textual format, but built programmatically.

#### Module Structure

| Builtin | Signature | Description |
|---------|-----------|-------------|
| `mirBeginModule(name)` | `(string)` | Start a module |
| `mirEndModule()` | `()` | Close the module |
| `mirImport(name)` | `(string)` | Declare an imported function (like `extern` in C) |
| `mirExport(name)` | `(string)` | Declare an exported function |
| `mirForward(name)` | `(string)` | Declare a forward reference |
| `mirProto(name, resultTypes, paramTypes)` | `(string, list, list)` | Declare a calling convention prototype |

#### Functions and Instructions

| Builtin | Signature | Description |
|---------|-----------|-------------|
| `mirBeginFunc(name, resultTypes, params)` | `(string, list, list)` | Start a function. Params are `"type:name"` strings |
| `mirEndFunc()` | `()` | Close the function |
| `mirLocal(name, type)` | `(string, string)` | Declare a local register |
| `mirLabel(name)` | `(string)` | Place a label |
| `mirInsn(opcode, operands...)` | `(string, ...)` | Emit an instruction (variadic) |

#### Data Declarations

| Builtin | Signature | Description |
|---------|-----------|-------------|
| `mirString(name, value)` | `(string, string)` | Declare a string constant |
| `mirData(name, type, values)` | `(string, string, list)` | Declare typed data |
| `mirBss(name, size)` | `(string, int)` | Declare uninitialized space |
| `mirRef(name, target, disp)` | `(string, string, int)` | Pointer to target + displacement |
| `mirExpr(name, funcName)` | `(string, string)` | Link-time evaluated expression |
| `mirLref(name, label1, label2, disp)` | `(string, string, string, int)` | Label-relative reference |


### How MIR Gets Lowered (the mir{} Block)

When you call `runMir()`, the VM walks the MIR program and fires `mir{}` on-handlers in this exact sequence:

```
on module        (name, imports, exports)
  on proto       (name, resultTypes, paramTypes, isVararg)   -- for each prototype
  on string      (name, value)                               -- for each string constant
  on data        (name, dataType, values)                    -- for each data item
  on bss         (name, size)                                -- for each BSS block
  on ref         (name, target, disp)                        -- for each reference
  on func        (name, resultTypes, params, locals, isVararg) -- for each function
    on label     (name)                                      -- for each label
    on insn      (opcode, operands)                          -- for each instruction
  on endfunc     (name)
on endmodule     (name)
```

Each handler receives variables injected into its scope. Your handler code translates these virtual assembly events into real machine code using the encoder and image-writer scripts.

#### Example: Lowering to x86_64

This is from `mir_full_pipeline.lvm` -- the end-to-end proof. The `mir{}` handlers take MIR assembly events and produce a working PE executable:

```lvm
mir {
  on module {
    // Initialize builders for code, data, and imports
    g_cb = cb_create(1024);
    g_db = db_create();
    g_ib = ib_create();
    // Map imported functions to their DLLs
    // ...
  }

  on string {
    // Store string constant in data section
    g_str_map[name] = db_add_string(g_db, value);
  }

  on func {
    // Emit Win64 prologue: sub rsp, 0x28
    cb_emit_sub_rsp_imm8(g_cb, 0x28);
  }

  on insn {
    // Translate each MIR instruction to x86_64 machine code
    if opcode == "call" {
      // Assign arguments to Win64 registers (rcx, rdx, r8, r9)
      // Emit: mov reg, imm64 / lea reg, [rip+disp32]
      // Emit: call [rip+disp32] via IAT
    }
  }

  on endfunc {
    // Emit Win64 epilogue: add rsp, 0x28; ret
    cb_emit_add_rsp_imm8(g_cb, 0x28);
    cb_emit_ret(g_cb);
  }

  on endmodule {
    // Assemble PE image from code, data, and import sections
    let image: map = pe_build_exe(...);
    bufSave(image, exe_path);
  }
}
```

The production x86_64 backend (`bin/res/backend/x86_64/`, ~165KB) provides the full infrastructure for this lowering: `encode.lvm` (x64 instruction encoding), `abi.lvm` (Win64/SysV calling conventions), `builders.lvm` (code/data/import builders), `pe.lvm` (PE64 image writer), `elf.lvm` (ELF64 image writer), and `coff.lvm` (COFF .obj writer).

<a id="builtins"></a>

## Builtins

LangVM provides ~200 builtin functions. This section lists them by category. For MIR-specific builtins (`mir*`), see [MIR Reference](#mir-reference). For pipeline-specific builtins used inside grammar/semantics/emitters blocks, see [Pipeline Blocks](#pipeline-blocks).


### String Operations

| Builtin | Signature | Description |
|---------|-----------|-------------|
| `len(v)` | `(string\|list\|map\|buffer) -> int` | Length of a string, list, map, or buffer |
| `upper(s)` | `(string) -> string` | Convert to uppercase |
| `lower(s)` | `(string) -> string` | Convert to lowercase |
| `trim(s)` | `(string) -> string` | Remove leading/trailing whitespace |
| `replace(s, old, new)` | `(string, string, string) -> string` | Replace all occurrences |
| `substr(s, start, len)` | `(string, int, int) -> string` | Extract substring |
| `startsWith(s, prefix)` | `(string, string) -> bool` | Check prefix |
| `endsWith(s, suffix)` | `(string, string) -> bool` | Check suffix |
| `contains(s, sub)` | `(string, string) -> bool` | Check containment |
| `concat(a, b)` | `(string, string) -> string` | Concatenate strings |
| `split(s, delim)` | `(string, string) -> list` | Split string into list |
| `charAt(s, index)` | `(string, int) -> string` | Character at index |
| `indexOf(s, sub)` | `(string, string) -> int` | Find substring position (-1 if not found) |
| `padLeft(s, len, ch)` | `(string, int, string) -> string` | Pad on the left |
| `padRight(s, len, ch)` | `(string, int, string) -> string` | Pad on the right |
| `repeat(s, count)` | `(string, int) -> string` | Repeat string |
| `utf8Len(s)` | `(string) -> int` | UTF-8 character count |
| `charOrd(s)` | `(string) -> int` | Character ordinal value |
| `charToInt(s)` | `(string) -> int` | Character to integer |
| `fmtEscape(s)` | `(string) -> string` | Escape special characters |
| `unescapeStr(s)` | `(string) -> string` | Unescape special characters |


### Type Conversion and Checking

| Builtin | Signature | Description |
|---------|-----------|-------------|
| `typeOf(v)` | `(any) -> string` | Type name as string |
| `sizeof(v)` | `(any) -> int` | Size in bytes |
| `toString(v)` | `(any) -> string` | Convert to string |
| `toInt(v)` | `(any) -> int` | Convert to integer |
| `toFloat(v)` | `(any) -> float` | Convert to float |
| `toBool(v)` | `(any) -> bool` | Convert to boolean |
| `intToStr(n)` | `(int) -> string` | Integer to string |
| `strToInt(s)` | `(string) -> int` | String to integer |
| `strToFloat(s)` | `(string) -> float` | String to float |
| `hexToInt(s)` | `(string) -> int` | Hex string to integer |
| `intToHex(n)` | `(int) -> string` | Integer to hex string |
| `isInt(v)` | `(any) -> bool` | Check if integer |
| `isFloat(v)` | `(any) -> bool` | Check if float |
| `isString(v)` | `(any) -> bool` | Check if string |
| `isBool(v)` | `(any) -> bool` | Check if boolean |
| `isList(v)` | `(any) -> bool` | Check if list |
| `isMap(v)` | `(any) -> bool` | Check if map |
| `isNil(v)` | `(any) -> bool` | Check if nil |
| `isBuffer(v)` | `(any) -> bool` | Check if buffer |


### I/O

| Builtin | Signature | Description |
|---------|-----------|-------------|
| `print(args...)` | `(variadic)` | Print values without newline |
| `println(args...)` | `(variadic)` | Print values with newline |
| `readln()` | `() -> string` | Read a line from stdin |


### List Operations

| Builtin | Signature | Description |
|---------|-----------|-------------|
| `listAppend(list, value)` | `(list, any)` | Append a value |
| `listInsert(list, index, value)` | `(list, int, any)` | Insert at index |
| `listRemove(list, index)` | `(list, int)` | Remove at index |
| `listIndexOf(list, value)` | `(list, any) -> int` | Find index of value (-1 if not found) |
| `listReverse(list)` | `(list)` | Reverse in place |
| `listSort(list)` | `(list)` | Sort in place |
| `listClear(list)` | `(list)` | Remove all elements |
| `listSlice(list, start, end)` | `(list, int, int) -> list` | Extract a sublist |
| `listJoin(list, delim)` | `(list, string) -> string` | Join elements with delimiter |
| `listCopy(list)` | `(list) -> list` | Shallow copy |


### Map Operations

| Builtin | Signature | Description |
|---------|-----------|-------------|
| `mapKeys(map)` | `(map) -> list` | List of all keys |
| `mapValues(map)` | `(map) -> list` | List of all values |
| `mapHas(map, key)` | `(map, string) -> bool` | Check if key exists |
| `mapRemove(map, key)` | `(map, string)` | Remove a key |
| `mapClear(map)` | `(map)` | Remove all entries |
| `mapCopy(map)` | `(map) -> map` | Shallow copy |


### Math

| Builtin | Signature | Description |
|---------|-----------|-------------|
| `abs(n)` | `(number) -> number` | Absolute value |
| `min(a, b)` | `(number, number) -> number` | Minimum |
| `max(a, b)` | `(number, number) -> number` | Maximum |
| `clamp(v, lo, hi)` | `(number, number, number) -> number` | Clamp to range |
| `floor(n)` | `(float) -> int` | Floor |
| `ceil(n)` | `(float) -> int` | Ceiling |
| `round(n)` | `(float) -> int` | Round to nearest |
| `pow(base, exp)` | `(number, number) -> float` | Exponentiation |
| `log2(n)` | `(number) -> float` | Base-2 logarithm |
| `random(max)` | `(int) -> int` | Random integer in [0, max) |
| `randomFloat()` | `() -> float` | Random float in [0, 1) |


### Bitwise Operations

| Builtin | Signature | Description |
|---------|-----------|-------------|
| `band(a, b)` | `(int, int) -> int` | Bitwise AND |
| `bor(a, b)` | `(int, int) -> int` | Bitwise OR |
| `bxor(a, b)` | `(int, int) -> int` | Bitwise XOR |
| `bnot(a)` | `(int) -> int` | Bitwise NOT |
| `shl(a, n)` | `(int, int) -> int` | Shift left |
| `shr(a, n)` | `(int, int) -> int` | Shift right |


### Buffer Operations

Buffers are mutable byte arrays used for binary data construction -- essential for the native code backend.

| Builtin | Signature | Description |
|---------|-----------|-------------|
| `buffer(size)` | `(int) -> buffer` | Create a buffer of given size |
| `bufSize(buf)` | `(buffer) -> int` | Current buffer size |
| `bufGrow(buf, size)` | `(buffer, int)` | Grow buffer to at least size |
| `bufWriteU8(buf, off, val)` | `(buffer, int, int)` | Write unsigned 8-bit integer |
| `bufWriteU16(buf, off, val)` | `(buffer, int, int)` | Write unsigned 16-bit integer |
| `bufWriteU32(buf, off, val)` | `(buffer, int, int)` | Write unsigned 32-bit integer |
| `bufWriteU64(buf, off, val)` | `(buffer, int, int)` | Write unsigned 64-bit integer |
| `bufWriteF32(buf, off, val)` | `(buffer, int, float)` | Write 32-bit float |
| `bufWriteF64(buf, off, val)` | `(buffer, int, float)` | Write 64-bit float |
| `bufReadU8(buf, off)` | `(buffer, int) -> int` | Read unsigned 8-bit integer |
| `bufReadU16(buf, off)` | `(buffer, int) -> int` | Read unsigned 16-bit integer |
| `bufReadU32(buf, off)` | `(buffer, int) -> int` | Read unsigned 32-bit integer |
| `bufReadU64(buf, off)` | `(buffer, int) -> int` | Read unsigned 64-bit integer |
| `bufReadF32(buf, off)` | `(buffer, int) -> float` | Read 32-bit float |
| `bufReadF64(buf, off)` | `(buffer, int) -> float` | Read 64-bit float |
| `bufWriteBytes(buf, off, src, srcOff, len)` | `(buffer, int, buffer, int, int)` | Copy bytes between buffers |
| `bufWriteString(buf, off, str)` | `(buffer, int, string)` | Write string bytes at offset |
| `bufReadString(buf, off, len)` | `(buffer, int, int) -> string` | Read string from buffer |
| `bufWriteRecord(buf, off, record)` | `(buffer, int, any)` | Write record as aligned binary |
| `bufReadRecord(buf, off, recordDef)` | `(buffer, int, any) -> map` | Read record from buffer |
| `bufToBytes(buf)` | `(buffer) -> list` | Convert buffer to byte list |
| `bufCopyBytes(dst, dstOff, src, srcOff, len)` | `(buffer, int, buffer, int, int)` | Copy between buffers |
| `bufIsExec(buf, flag)` | `(buffer, bool)` | Mark buffer as executable |
| `bufFlush(buf)` | `(buffer)` | Flush instruction cache |
| `bufCall(buf)` | `(buffer) -> int` | Call buffer as function |
| `bufSave(buf, path)` | `(buffer, string)` | Write buffer to file |
| `bufLoadFile(path)` | `(string) -> buffer` | Load file into buffer |
| `bufPtr(buf)` | `(buffer) -> int` | Get raw pointer value |


### File I/O

| Builtin | Signature | Description |
|---------|-----------|-------------|
| `fileCreate(path)` | `(string) -> handle` | Create a new file |
| `fileOpen(path)` | `(string) -> handle` | Open an existing file |
| `fileClose(handle)` | `(handle)` | Close a file |
| `fileWrite(handle, data, len)` | `(handle, buffer, int) -> int` | Write bytes |
| `fileRead(handle, buf, len)` | `(handle, buffer, int) -> int` | Read bytes |
| `fileSize(handle)` | `(handle) -> int` | Get file size |
| `fileSeek(handle, pos, origin)` | `(handle, int, int)` | Seek to position |
| `filePos(handle)` | `(handle) -> int` | Get current position |
| `loadTextFile(path)` | `(string) -> string` | Read entire file as text |
| `saveTextFile(path, text)` | `(string, string)` | Write text to file |
| `fileExists(path)` | `(string) -> bool` | Check if file exists |
| `dirExists(path)` | `(string) -> bool` | Check if directory exists |
| `createDirsInPath(path)` | `(string)` | Create parent directories |
| `runPE(path)` | `(string) -> int` | Execute a PE binary, return exit code |
| `runELF(path)` | `(string) -> int` | Execute an ELF binary, return exit code |


### Path Operations

| Builtin | Signature | Description |
|---------|-----------|-------------|
| `pathJoin(parts...)` | `(variadic) -> string` | Join path segments |
| `pathDir(path)` | `(string) -> string` | Directory part |
| `pathFile(path)` | `(string) -> string` | Filename part |
| `pathExt(path)` | `(string) -> string` | Extension |
| `pathChangeExt(path, ext)` | `(string, string) -> string` | Change extension |


### AST Node Operations

Used inside pipeline block handlers to manipulate AST nodes.

| Builtin | Signature | Description |
|---------|-----------|-------------|
| `getAttr(node, key)` | `(handle, string) -> any` | Get node attribute |
| `setAttr(node, key, value)` | `(handle, string, any)` | Set node attribute |
| `hasAttr(node, key)` | `(handle, string) -> bool` | Check if attribute exists |
| `childCount(node)` | `(handle) -> int` | Number of child nodes |
| `getChild(node, index)` | `(handle, int) -> handle` | Get child by index |
| `nodeKind(node)` | `(handle) -> string` | Get node kind string |
| `getNodeKind(node)` | `(handle) -> string` | Alias for nodeKind |
| `nodeFile(node)` | `(handle) -> string` | Source file of node |
| `nodeLine(node)` | `(handle) -> int` | Source line of node |
| `nodeCol(node)` | `(handle) -> int` | Source column of node |
| `createNode(kind)` | `(string) -> handle` | Create a new AST node |
| `addChild(parent, child)` | `(handle, handle)` | Add child node |
| `setChild(parent, index, child)` | `(handle, int, handle)` | Replace child at index |
| `removeChild(parent, index)` | `(handle, int)` | Remove child at index |
| `cloneNode(node)` | `(handle) -> handle` | Deep clone a node |


### Shared State

| Builtin | Signature | Description |
|---------|-----------|-------------|
| `setShared(key, value)` | `(string, any)` | Set a shared variable (persists across pipeline stages) |
| `getShared(key)` | `(string) -> any` | Get a shared variable |
| `hasShared(key)` | `(string) -> bool` | Check if shared variable exists |
| `clearShared()` | `()` | Clear all shared variables |


### Generic Parser Builtins

Used inside `grammar{}` rule bodies to interact with the generic Pratt parser.

| Builtin | Signature | Description |
|---------|-----------|-------------|
| `checkToken(kind)` | `(string) -> bool` | Check if current token matches kind |
| `matchToken(kind)` | `(string) -> bool` | Check and consume if match |
| `advance()` | `() -> any` | Consume and return current token |
| `requireToken(kind)` | `(string)` | Require and consume a token |
| `currentText()` | `() -> string` | Text of the current token |
| `currentKind()` | `() -> string` | Kind of the current token |
| `peekKind()` | `() -> string` | Kind of the current token (alias) |
| `peekKindAt(n)` | `(int) -> string` | Kind of token at offset n |
| `getResultNode()` | `() -> handle` | Get the AST node being built |
| `parseExpr()` | `() -> handle` | Recursively parse an expression |
| `parseExprFrom(prec)` | `(int) -> handle` | Parse expression at given precedence |
| `parseStmt()` | `() -> handle` | Parse a single statement |
| `collectUntil(kind)` | `(string) -> list` | Collect tokens until kind found |
| `collectRaw()` | `() -> list` | Collect remaining tokens |


### Compiler/Pipeline Control

| Builtin | Signature | Description |
|---------|-----------|-------------|
| `lexSource(source, filename)` | `(string, string) -> any` | Tokenize source with the generic lexer |
| `parseProgram(tokens, filename)` | `(any, string) -> handle` | Parse tokens into AST |
| `runSemantics(ast)` | `(handle)` | Run semantic analysis |
| `runEmitters(ast)` | `(handle)` | Run code generation |
| `runMir()` | `()` | Lower MIR to native via on-handlers |
| `setDefine(name, value)` | `(string, string)` | Set a preprocessor define |
| `removeDefine(name)` | `(string)` | Remove a preprocessor define |
| `hasDefine(name)` | `(string) -> bool` | Check if define exists |
| `clearDefines()` | `()` | Clear all defines |
| `setModuleExtension(ext)` | `(string)` | Set module file extension |
| `addModulePath(path)` | `(string)` | Add a module search path |
| `addImportPath(path)` | `(string)` | Add an import search path |


### Symbol Table

| Builtin | Signature | Description |
|---------|-----------|-------------|
| `symbolExists(name)` | `(string) -> bool` | Check if symbol is declared in current scope |
| `lookupSymbol(name)` | `(string) -> any` | Look up a symbol in semantic scope |
| `lookupGlobal(name)` | `(string) -> any` | Look up a global symbol |


### DLL Loading

| Builtin | Signature | Description |
|---------|-----------|-------------|
| `loadDll(path)` | `(string) -> handle` | Load a dynamic library |
| `freeDll(handle)` | `(handle)` | Free a loaded library |
| `getDllProc(handle, name)` | `(handle, string) -> handle` | Get a function pointer |
| `callDllProc(proc, args...)` | `(handle, variadic) -> any` | Call a DLL function |


### Miscellaneous

| Builtin | Signature | Description |
|---------|-----------|-------------|
| `assert(cond, msg)` | `(bool, string)` | Assert condition, fail with message |
| `error(msg)` | `(string)` | Raise a runtime error |
| `range(start, end)` | `(int, int) -> list` | Generate integer range |
| `time()` | `() -> float` | Current time in seconds |
| `unixTime()` | `() -> int` | Current Unix timestamp |
| `environ(name)` | `(string) -> string` | Get environment variable |

<a id="api-reference"></a>

## Delphi Host API Reference

This section documents the `TLangVM` class and supporting types for embedding LangVM in a Delphi application. For a quick-start guide, see [Getting Started](#getting-started).

```delphi
uses
  LangVM;
```


### TLangVM

The main VM class. Create an instance, load a script, and run it.

#### Lifecycle

| Method | Description |
|--------|-------------|
| `Create()` | Create a new VM instance |
| `Destroy()` | Free the VM and all resources |
| `Reset()` | Reset the VM to initial state (clears environment, builtins, pipeline) |

#### Loading Scripts

| Method | Signature | Description |
|--------|-----------|-------------|
| `LoadScript` | `(ASource, AFilename: string)` | Load a script from a string |
| `LoadScriptFile` | `(AFilename: string)` | Load a script from a file |
| `AddImportPath` | `(APath: string)` | Add a search path for `import` statements |

#### Execution

| Method | Signature | Description |
|--------|-----------|-------------|
| `Run` | `(ARoutineName: string)` | Execute a named routine (raises on error) |
| `Call` | `(ARoutineName: string; AArgs: array of TLVMValue): TLVMValue` | Call a routine with arguments, return result |
| `TryRun` | `(ARoutineName: string): Boolean` | Execute a routine, return False on error |
| `TryCall` | `(ARoutineName: string; AArgs: array of TLVMValue; out AResult: TLVMValue): Boolean` | Call with error handling |
| `Eval` | `(AExpr: string): TLVMValue` | Evaluate a single expression string |
| `HasRoutine` | `(AName: string): Boolean` | Check if a routine is defined |

#### Variables

| Method | Signature | Description |
|--------|-----------|-------------|
| `GetVar` | `(AName: string): TLVMValue` | Read a variable from the environment |
| `SetVar` | `(AName: string; AValue: TLVMValue)` | Write a variable to the environment |
| `HasVar` | `(AName: string): Boolean` | Check if a variable exists |

#### Well-Known Globals

| Property | Type | Description |
|----------|------|-------------|
| `ExitCode` | `Int64` | Script's return status (VM writes, host reads) |
| `SourceFilename` | `string` | File the script should process (host writes, VM reads) |

#### Custom Builtins

| Method | Signature | Description |
|--------|-----------|-------------|
| `RegisterBuiltin` | `(AName: string; AFunc: TLVMBuiltinFunc)` | Register a custom builtin function |
| `CallBuiltin` | `(AName: string; AArgs: TArray<TLVMValue>): TLVMValue` | Call a builtin by name |
| `HasBuiltin` | `(AName: string): Boolean` | Check if a builtin is registered |

#### Callbacks

| Method | Signature | Description |
|--------|-----------|-------------|
| `SetOnPrint` | `(ACallback: TLVMPrintCallback; AUserData: Pointer)` | Install a print output handler |
| `SetOnDiag` | `(ACallback: TLVMDiagCallback; AUserData: Pointer)` | Install a diagnostic (error) handler |

#### Host Objects

| Method | Signature | Description |
|--------|-----------|-------------|
| `SetHostObject` | `(AName: string; AObj: TObject)` | Store a Delphi object accessible by name |
| `GetHostObject` | `(AName: string): TObject` | Retrieve a stored host object |
| `HasHostObject` | `(AName: string): Boolean` | Check if a host object exists |

#### Error Handling

| Property/Method | Description |
|-----------------|-------------|
| `LastError: string` | Last error message from `TryRun`/`TryCall` |
| `GetErrors()` | Access the accumulated error list (`TLVMDiagnostics`) |

#### Read-Only Properties

| Property | Type | Description |
|----------|------|-------------|
| `LanguageName` | `string` | Name from the `language` declaration |
| `LanguageVersion` | `string` | Version from the `language` declaration |
| `BaseDir` | `string` | Base directory for relative paths |
| `ImportPaths` | `TStringList` | Registered import search paths |
| `Environment` | `TLVMEnvironment` | Direct access to the variable environment |
| `Lexer` | `TLVMLexer` | The script lexer |
| `Parser` | `TLVMParser` | The script parser |


### TLVMValue

The tagged variant value type used for all data exchange between host and VM.

#### Creation (class functions)

| Method | Returns | Description |
|--------|---------|-------------|
| `Nil_()` | nil value | |
| `FromInt(AValue: Int64)` | int value | |
| `FromFloat(AValue: Double)` | float value | |
| `FromBool(AValue: Boolean)` | bool value | |
| `FromString(AValue: string)` | string value | |
| `FromHandle(AValue: Pointer)` | handle value | |
| `FromList()` | empty list | |
| `FromArray(AValues: TArray<TLVMValue>)` | list from array | |
| `FromMap()` | empty map | |
| `FromBuffer(ASize: Integer)` | byte buffer | |

#### Extraction (raises on type mismatch)

| Method | Returns |
|--------|---------|
| `AsInt(): Int64` | Integer value |
| `AsFloat(): Double` | Float value |
| `AsBool(): Boolean` | Boolean value |
| `AsString(): string` | String value |
| `AsHandle(): Pointer` | Handle value |
| `AsList(): TLVMListStore` | List store |
| `AsMap(): TLVMMapStore` | Map store |
| `AsBuffer(): TVirtualMemory<Byte>` | Buffer store |

#### Queries

| Method/Property | Returns | Description |
|-----------------|---------|-------------|
| `Kind` | `TLVMValueKind` | The value's type tag |
| `IsNil(): Boolean` | | Check for nil |
| `IsTrue(): Boolean` | | Truthiness check |
| `ToString(): string` | | Human-readable representation |
| `KindName(): string` | | Type name as string |


### Callback Types

```delphi
{ Print callback -- receives all println/print output }
TLVMPrintCallback = reference to procedure(
  const AText: string;
  const AUserData: Pointer);

{ Diagnostic callback -- receives errors, warnings, hints }
TLVMDiagCallback = reference to procedure(
  const ASeverity: string;
  const AMessage: string;
  const AFile: string;
  const ALine: Integer;
  const ACol: Integer;
  const AUserData: Pointer);

{ Builtin function signature }
TLVMBuiltinFunc = reference to function(
  const AArgs: TArray<TLVMValue>;
  const AVM: TLangVM): TLVMValue;
```


### Complete Embedding Example

```delphi
uses
  LangVM;

var
  LVM: TLangVM;
begin
  LVM := TLangVM.Create();
  try
    // Install callbacks
    LVM.SetOnPrint(
      procedure(const AText: string; const AUserData: Pointer)
      begin
        Write(AText);
      end, nil);

    LVM.SetOnDiag(
      procedure(const ASeverity, AMessage, AFile: string;
        const ALine, ACol: Integer; const AUserData: Pointer)
      begin
        WriteLn(Format('%s(%d,%d): %s: %s',
          [AFile, ALine, ACol, ASeverity, AMessage]));
      end, nil);

    // Register a custom builtin
    LVM.RegisterBuiltin('hostVersion',
      function(const AArgs: TArray<TLVMValue>;
        const AVM: TLangVM): TLVMValue
      begin
        Result := TLVMValue.FromString('2.0.0');
      end);

    // Load and run
    LVM.AddImportPath('C:\MyProject\libs');
    LVM.SourceFilename := 'input.src';
    LVM.LoadScriptFile('mylang.lvm');

    if LVM.TryRun('main') then
      WriteLn('Exit code: ', LVM.ExitCode)
    else
      WriteLn('Failed: ', LVM.LastError);
  finally
    LVM.Free();
  end;
end;
```

<a id="how-to-guide"></a>

## How-To Guide

Practical recipes for common LangVM tasks.


### Define a Minimal Language

Create a language that recognizes one statement type and prints output:

```lvm
language MyLang version "1.0";

tokens {
  casesensitive = true;
  token keyword.say    = "say";
  token delimiter.semi = ";";
  token string.default = "\"";
  token comment.line   = "//";
}

grammar {
  rule stmt.say {
    expect keyword.say;
    let text: string = currentText();
    advance();
    let nd: handle = getResultNode();
    setAttr(nd, "message", text);
    requireToken("delimiter.semi");
  }
}

emitters {
  on stmt.say {
    let msg: string = getAttr(node, "message");
    println(msg);
  }
}

routine main() {
  let source: string = 'say "hello world";';
  let toks: any = lexSource(source, "input");
  let ast: any = parseProgram(toks, "input");
  runEmitters(ast);
}
```


### Process a Source File from the Host

Pass a source file from the Delphi host and have the script process it:

```delphi
// Delphi host
LVM.SourceFilename := 'myfile.src';
LVM.LoadScriptFile('mylang.lvm');
LVM.Run('main');
WriteLn('Exit code: ', LVM.ExitCode);
```

```lvm
// mylang.lvm
routine main() {
  let src: string = loadTextFile(SourceFilename);
  let toks: any = lexSource(src, SourceFilename);
  let ast: any = parseProgram(toks, SourceFilename);
  runEmitters(ast);
  ExitCode = 0;
}
```


### Add Expression Parsing to a Language

Add infix binary operators with precedence to your grammar:

```lvm
grammar {
  // Prefix: integer literal
  rule expr.integer {
    consume literal.integer -> @value;
  }

  // Prefix: parenthesized expression
  rule expr.grouped {
    expect delimiter.lparen;
    parse expr -> @inner;
    expect delimiter.rparen;
  }

  // Infix: addition/subtraction, left-associative, precedence 3
  rule expr.binary precedence left 3 {
    consume [op.plus, op.minus] -> @op;
    parse expr -> @right;
  }

  // Infix: multiplication/division, left-associative, precedence 4
  rule expr.binary_mul precedence left 4 {
    consume [op.star, op.slash] -> @op;
    parse expr -> @right;
  }
}
```


### Add Semantic Analysis

Declare symbols and check for undeclared identifiers:

```lvm
semantics {
  on program.root {
    scope "global" {
      visit children;
    }
  }

  on stmt.var_decl {
    declare @name as "variable";
    visit children;
  }

  on expr.ident {
    lookup @name or {
      error "Undeclared identifier: " + getAttr(node, "name");
    };
  }
}
```


### Emit Native Code via MIR

Use emitters to produce MIR instructions, then lower to native:

```lvm
emitters {
  on stmt.say {
    let msg: string = getAttr(node, "message");
    let label: string = mirString("s_" + toString(g_str_count), msg);
    g_str_count = g_str_count + 1;
    mirInsn("call", "p_printf", "printf", "_", label);
  }
}

routine main() {
  let g_str_count: int = 0;

  // Set up MIR module
  mirBeginModule("app");
  mirImport("printf");
  mirImport("ExitProcess");
  mirProto("p_printf", ["void"], ["p:fmt"]);
  mirProto("p_ExitProcess", ["void"], ["i32:code"]);
  mirBeginFunc("main", ["void"], []);

  // Compile source through the pipeline
  let src: string = 'say "hello";';
  let toks: any = lexSource(src, "test");
  let ast: any = parseProgram(toks, "test");
  runEmitters(ast);

  // Close MIR and lower to native
  mirInsn("call", "p_ExitProcess", "ExitProcess", "_", 0);
  mirEndFunc();
  mirEndModule();
  runMir();
}
```


### Write Binary Data with Buffers

Construct binary files (PE headers, ELF sections, etc.) from script:

```lvm
routine main() {
  let buf: buffer = buffer(64);

  // Write a DOS MZ header stub
  bufWriteU16(buf, 0, 0x5A4D);  // 'MZ' magic
  bufWriteU32(buf, 60, 64);     // e_lfanew -> PE header at offset 64

  bufSave(buf, "output.bin");
  println("Wrote " + toString(bufSize(buf)) + " bytes");
}
```


### Import and Compose Scripts

Split a large language definition across multiple files:

```lvm
// main.lvm
language MyLang version "1.0";

import "tokens.lvm";
import "grammar.lvm";
import "semantics.lvm";
import "emitters.lvm";

routine main() {
  let src: string = loadTextFile(SourceFilename);
  let toks: any = lexSource(src, SourceFilename);
  let ast: any = parseProgram(toks, SourceFilename);
  runSemantics(ast);
  runEmitters(ast);
}
```

Each imported file contains the relevant pipeline block (`tokens{}`, `grammar{}`, etc.) and any helper routines.

<a id="code-style"></a>

## Code Style Guide

Conventions for writing clean, maintainable `.lvm` scripts.


### File Structure

1. `language` declaration
2. `import` statements
3. `const {}` blocks
4. `enum {}` declarations
5. `record {}` declarations
6. Helper routines
7. Pipeline blocks (`tokens`, `grammar`, `semantics`, `emitters`, `mir`)
8. `routine main()`


### Naming Conventions

| Item | Style | Example |
|------|-------|---------|
| Variables | `camelCase` | `lineCount`, `srcFile` |
| Constants | `UPPER_SNAKE` | `MAX_SIZE`, `VERSION` |
| Routines | `camelCase` | `parseExpr()`, `emitCall()` |
| Enum values | `PascalCase` | `Red`, `Green`, `Blue` |
| Record names | `PascalCase` | `DosHeader`, `SectionEntry` |
| Token kinds | `category.name` | `keyword.if`, `op.plus`, `delimiter.semicolon` |
| Grammar rules | `category.name` | `stmt.if`, `expr.binary`, `expr.integer` |
| Semantic handlers | `category.name` | `stmt.var_decl`, `expr.call` |


### Formatting

- Use 2-space indentation inside blocks
- One statement per line
- Terminate statements with `;`
- Use `//` comments for inline documentation
- Keep routines focused -- one concern per routine
- Use blank lines to separate logical sections within long routines


### Pipeline Block Organization

For large language definitions, split pipeline blocks into separate files:

```
mylang/
  main.lvm           -- imports + routine main()
  tokens.lvm          -- tokens {} block
  grammar.lvm         -- grammar {} block + grammar helpers
  semantics.lvm       -- semantics {} block + analysis helpers
  emitters.lvm        -- emitters {} block + codegen helpers
```


### Error Handling

- Use `try/recover` to catch runtime errors in script code
- Use diagnostic builtins (`error`, `warning`, `hint`) in semantic handlers
- Check return values from builtins that can fail
- Use `assert()` liberally in tests



---

<a id="contributing"></a>

## 🤝 Contributing

LangVM is developed by tinyBigGAMES. Whether you are fixing a bug, improving documentation, improving examples, or proposing a feature, contributions are welcome.

| Contribution | Best Way to Help |
|--------------|------------------|
| 🐞 Bug report | Open an issue with a minimal reproduction and the exact command used |
| 💡 Feature idea | Describe the real use case first, then the proposed syntax or behavior |
| 🧾 Documentation fix | Point to the section and explain what was unclear or missing |
| 🧪 Test case | Include the smallest `.lvm` file that proves the behavior |
| 🔧 Pull request | Keep the change focused and explain the before/after behavior |

> [!TIP]
> 🚀 Small, focused contributions are the easiest to review and the fastest to land.

## 💖 Support the Project

If LangVM saves you time, helps you learn, or sparks something useful:

- ⭐ **Star the repo**: it costs nothing and helps others find the project
- 🗣️ **Spread the word**: write a post, mention it in a community, or share a screenshot
- 💬 **Join the community**: show what you are building and help shape what comes next
- 🧪 **Try examples**: real usage finds issues that synthetic tests miss
- 💖 **[Become a sponsor](https://github.com/sponsors/tinyBigGAMES)**: sponsorship directly funds development, examples, and documentation

## 📜 License

LangVM is licensed under the **Apache License, Version 2.0**. See [LICENSE](https://github.com/tinyBigGAMES/LangVM?tab=License-1-ov-file#) for details.

Apache 2.0 is a permissive open source license that lets you use, modify, and distribute LangVM freely in both open source and commercial projects. You are not required to release your own source code. Attribution is required: keep the copyright notice and license file in place.

## 🔗 Links

- 🧑‍💻 [GitHub](https://github.com/tinyBigGAMES/LangVM)
- 💬 [Discord](https://discord.gg/Wb6z8Wam7p)
- 🦋 [Bluesky](https://bsky.app/profile/tinybiggames.com)
- 🎮 [tinyBigGAMES](https://tinybiggames.com)

<div align="center">

**💎 LangVM**

Copyright &copy; 2025-present tinyBigGAMES&trade; LLC<br/>All Rights Reserved.

</div>
