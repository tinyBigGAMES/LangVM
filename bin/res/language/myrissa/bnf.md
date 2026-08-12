<a id="bnf-grammar"></a>

## 🧾 BNF Grammar

### 🧾 Syntax Notation

This section is the formal grammar reference for Myrissa. It is intended for implementers, tooling authors, and anyone who needs exact syntax rules. For an easier language walkthrough, see [Language Reference](#language-reference).

The grammar uses EBNF notation. Brackets `[` and `]` mark optional elements. Braces `{` and `}` mark repetition, zero or more times. Parentheses group alternatives. The vertical bar `|` separates alternatives. Terminal symbols are enclosed in quotes or written as lowercase literal tokens. Non-terminals are written in PascalCase.


> [!NOTE]
> 🧾 This file is intentionally formal. Use it when you need the exact grammar contract. Use the [Language Reference](#language-reference) for explanations and the [How-To Guide](#how-to-guide) for examples.

### 🔎 How to Read This Grammar

| Symbol | Meaning |
|--------|---------|
| `A B` | `A` followed by `B` |
| `A | B` | either `A` or `B` |
| `[ A ]` | optional `A` |
| `{ A }` | zero or more repetitions of `A` |
| `( A | B )` | grouped alternatives |
| `"text"` | literal source text |

> [!TIP]
> 💡 When implementing a parser, treat this file as the external behavior contract, not as a required internal parser architecture. Recursive descent, Pratt parsing, table-driven parsing, or another strategy can all implement the same grammar.


### 🔤 1. Lexical Elements

```
letter     = "A" | ... | "Z" | "a" | ... | "z" | "_" .
digit      = "0" | ... | "9" .
hexDigit   = digit | "A" | ... | "F" | "a" | ... | "f" .
character  = (* any source character except the delimiter *) .
newline    = (* line feed (U+000A) *) .

ident      = letter { letter | digit } .
integer    = digit { digit } | "0" ( "x" | "X" ) hexDigit { hexDigit } .
float_literal = digit { digit } "." { digit } [ exponent ] [ "f" | "F" ] .
exponent      = ( "e" | "E" ) [ "+" | "-" ] digit { digit } .
cstring    = '"' { character | escapeSeq } '"' .
wstring    = "w" '"' { character | escapeSeq } '"' .
escapeSeq  = "\" ( "n" | "t" | "r" | "0" | "\" | "'" | '"' | "x" hexDigit hexDigit ) .
```

#### 🔢 Numeric Literal Type Rules

| Literal         | Suffix | Type      | Example         |
|----------------|--------|-----------|-----------------|
| `42`           | --     | `int32` | integer |
| `1.5`          | --     | contextual | float literal |
| `1.5f`, `1.5F` | `f`/`F` | `float32` | explicit `float32` |

**Float literal resolution without a suffix:**

- Assigned to a `float32` variable or passed to a `float32` parameter: `float32`
- Assigned to a `float64` variable or passed to a `float64` parameter: `float64`
- Ambiguous or unknown context: `float64`

**Float literal resolution with `f` or `F` suffix:**

- Always `float32`, regardless of context

#### 🧵 String Literal Convention

- `"..."` -- String literal. Escape sequences processed. UTF-8 encoded.
- `w"..."` -- Wide string literal. Escape sequences processed. UTF-16 encoded. Prefix is case-sensitive: only lowercase `w`.

#### 🔤 Character Type Assignment Rules

The `char` and `wchar` types have no dedicated literal syntax. Characters are
assigned using string literals, variable-to-variable assignment, or string indexing.
The semantic pass validates type compatibility using the AST.

**Valid `char` assignments:**
- `c := "x";` -- A `cstring` literal of exactly one character. The semantic pass
  verifies `len = 1`; longer literals produce a compile error.
- `c := d;` -- Where `d` is also of type `char`.
- `c := s[i];` -- Indexing a `string` yields a `char`.

**Valid `wchar` assignments:**
- `wc := w"x";` -- A `wstring` literal of exactly one character (semantic-checked).
- `wc := wd;` -- Where `wd` is also of type `wchar`.
- `wc := ws[i];` -- Indexing a `wstring` yields a `wchar`.

**Invalid assignments (compile error):**
- `c := "abc";` -- Multi-character literal assigned to `char`.
- `c := s;` -- `string` variable assigned to `char` (use indexing instead).
- `c := wc;` -- `wchar` assigned to `char` (width mismatch).
- `wc := c;` -- `char` assigned to `wchar` (width mismatch).


### 🚫 2. Reserved Words

The language is **case-sensitive** for keywords and identifiers.

```
address    align      and        array      assert     asserteq
asserteqf  assertfalse assertfail assertnil assertnotnil asserttrue
begin      break      choices    class      clink      const      continue
cpplink    create     cstr       destroy
div        do         downto     else       end        except
exccode    excmsg     external   false      finalize   finally
for        freemem    getmem     guard
if         import     in         initialize is         len
match      method     mod        module
nil        not        of         or         overlay
packed     paramcount paramstr   parent     pointer    print
println    public     record     repeat     resizemem
return     routine    self       set        setlength  shl
shr        size       test       then       throw
throwcode  to         true       type       until      utf8
var        varargs    while      wstr       xor
```

> [!NOTE]
> The identifiers `exe`, `dll`, `lib`, and `unit` are contextual. They have special meaning only in the `ModuleKind` position and may be used as ordinary identifiers elsewhere. Unit modules are `.myr` source files that are compiled inline into the importing module rather than producing separate output.


### 🧱 3. Built-in Types

```
int8       int16      int32      int64
uint8      uint16     uint32     uint64
float32    float64
boolean
char       wchar
string     wstring
pointer
```

#### 📏 Type Sizes

| Type        | Size (bytes) | Description            |
|-------------|-------------|------------------------|
| `int8`      | 1           | Signed 8-bit integer   |
| `int16`     | 2           | Signed 16-bit integer  |
| `int32`     | 4           | Signed 32-bit integer  |
| `int64`     | 8           | Signed 64-bit integer  |
| `uint8`     | 1           | Unsigned 8-bit integer |
| `uint16`    | 2           | Unsigned 16-bit integer|
| `uint32`    | 4           | Unsigned 32-bit integer|
| `uint64`    | 8           | Unsigned 64-bit integer|
| `float32`   | 4           | 32-bit IEEE 754 float  |
| `float64`   | 8           | 64-bit IEEE 754 float  |
| `boolean`   | 1           | Boolean (0 or 1)       |
| `char`      | 1           | 8-bit character        |
| `wchar`     | 2           | 16-bit wide character  |
| `string`    | 8 (pointer) | Managed UTF-8 string   |
| `wstring`   | 8 (pointer) | Managed UTF-16 string  |
| `pointer`   | 8           | Untyped pointer        |


### ⚙️ 4. Operators and Delimiters

```
+    -    *    /    =    <>   <    >    <=   >=
:=   +=   -=   *=   /=
:    ;    ,    .    ..   ...  ^    |    &
(    )    [    ]
```

#### 🧠 Operator Semantics

- `:=` -- Assignment
- `=` -- Equality comparison
- `<>` -- Not equal
- `^` -- Postfix: pointer dereference
- `&` -- Prefix: address-of (see also `address of`)
- `|` -- Reserved token (available for future use)


### 💬 5. Comments

```
Comment    = "//" { character } newline
           | "/*" { character | Comment } "*/" .
```

- `//` -- Line comment.
- `/* ... */` -- Block comment. May be nested.

> [!NOTE]
> `(* *)` and `{ }` are not comment delimiters in Myrissa.


### 🧱 6. Module Structure

```
Module        = "module" ModuleKind ident ";" [ Directives ] [ ImportClause ]
                { Declaration }
                [ "initialize" StatementSeq "end" ";" ]
                [ "finalize" StatementSeq "end" ";" ]
                "begin" StatementSeq "end" "."
                { TestBlock } .

ModuleKind    = "exe" | "dll" | "lib" | "unit" .

Directives    = { Directive } .
Directive     = "@" ident [ DirectiveValue ] ";" .
DirectiveValue = cstring | integer | float_literal | ident .

ImportClause  = "import" ident { "," ident } ";" .

TestBlock     = "test" cstring [ "var" { VarDecl } ]
                "begin" StatementSeq "end" ";" .
```

> [!NOTE]
> **Module lifecycle: `initialize` and `finalize`.** The `initialize` and `finalize`
> blocks are module lifecycle hooks. `initialize` runs at startup (before the
> entry point), `finalize` runs at shutdown. Both are optional and supported on
> all module kinds. They are separate from `begin`, which is the main program
> body for exe/dll modules. For unit modules, `initialize`/`finalize` replace
> the old `begin`/`finalize` embedded syntax. The SSA pass auto-discovers
> these functions by name prefix and wires them into the entry point.

> [!IMPORTANT]
> **Module qualification rule.** All public symbols from an imported module must be
> accessed using full module qualification: `moduleName.symbolName`. Unqualified
> access to imported symbols is a compile error. This applies to routines, types,
> variables, and constants alike. If modules A and B both export a symbol `Foo`,
> they are distinguished as `A.Foo` and `B.Foo` -- there is no ambiguity.

> [!NOTE]
> **Directive termination.** Every directive is terminated by `;` -- with one
> exception: the seven conditional-compilation directives (Section 7:
> `@define`, `@undef`, `@ifdef`, `@ifndef`, `@elseif`, `@else`, `@endif`)
> take **no** terminator.

> [!NOTE]
> **Test blocks.** Test blocks appear after `end.` and are only compiled when
> `@unittestmode on;` is active. Each test block has a string name, optional local
> variables, and a body. When unittest mode is on, the compiler replaces the normal
> entry point with the test runner. Test blocks have access to all module declarations.


### 🔀 7. Conditional Compilation

```
ConditionalDirective = DefineDir | UndefDir | IfdefDir | IfndefDir
                     | ElseIfDir | ElseDir | EndifDir .

DefineDir   = "@define" ident .
UndefDir    = "@undef" ident .
IfdefDir    = "@ifdef" ident .
IfndefDir   = "@ifndef" ident .
ElseIfDir   = "@elseif" ident .
ElseDir     = "@else" .
EndifDir    = "@endif" .
```

#### 📜 Known Directives

All directives below are terminated by `;`. Bare identifiers are the canonical
form for enumerated values; quoted strings are reserved for paths and free text.

**Module-level directives** (appear after `module` header, before or among declarations):

- `@exeicon "path";` -- Sets the application icon (Windows EXE modules only).
- `@resfile "path";` -- Specifies a compiled resource file (.res) to link into the output.
- `@outputpath "path";` -- Sets the output directory for the compiled binary.
- `@copydll "path";` -- Copies a DLL/shared library to the output directory during build.
- `@linklibrary "path";` -- Links an additional static or shared library into the output.
- `@libpath "path";` -- Adds a directory to the library and module search path.
- `@modulepath "path";` -- Adds a directory to the module (unit) search path.
- `@includepath "path";` -- Adds a directory to the include search path.
- `@subsystem console|gui;` -- Sets the application subsystem (bare identifier). Default: `console`. Windows-only: on the linux64 target it produces a warning and is ignored.
- `@target win64|linux64;` -- Sets the compilation target (bare identifier). Default: `win64`. Overrides the API SetTarget for the current compile only; must appear in the root module.
- `@optimize debug|none|basic|full;` -- Sets optimization level (bare identifier).
- `@unittestmode on|off;` -- Enables or disables test block compilation and test runner entry point (bare identifier).

##### Path resolution

Every directive taking a `"path"` resolves it the same way. An absolute path is
used as-is. A relative path resolves against the directory of the module that
declares the directive, so a module and the files it references travel together.

An optional prefix overrides that base:

| Prefix | Base | Use for |
|---|---|---|
| `$P:` | Directory of the running compiler executable | Shipped assets under the compiler's own `res` tree |
| `$D:` | Current working directory | Paths relative to where the compiler was invoked |
| `$S:` | Declaring module's directory -- the default, stated explicitly | Clarity in modules that mix bases |

The prefix is matched case-insensitively and only at the very start of the
string. A path containing `$P:` anywhere else is left alone.

`$P:` is the correct choice for any module meant to be imported from another
folder. A vendor binding that says `@copydll "res/libs/vendor/raylib/win64/raylib.dll"`
resolves against its own directory and fails as soon as the module is used from
elsewhere; the `$P:` form always finds the file shipped beside the compiler:

```
@copydll "$P:res/libs/vendor/raylib/win64/raylib.dll";
@libpath "$P:res/libs/vendor/raylib";
@exeicon "$P:res/assets/icons/myrissa.ico";
```


**Version information directives** (for embedding in the PE executable):

- `@addverinfo on|off;` -- Enables or disables version information embedding (bare identifier).
- `@vimajor number;` -- Major version number.
- `@viminor number;` -- Minor version number.
- `@vipatch number;` -- Patch version number.
- `@viproductname "name";` -- Product name.
- `@videscription "text";` -- File description.
- `@vifilename "name";` -- Original filename.
- `@vicompanyname "name";` -- Company name.
- `@vicopyright "text";` -- Copyright string.

**Statement-level directives:**

- `@breakpoint;` -- Marks a debugger breakpoint location. Takes no value.
- `@message hint|warn|error|fatal "text";` -- Emits a compiler diagnostic at parse time (bare-identifier severity followed by a quoted string).

> [!NOTE]
> **Conditionals in imported units.** The conditional-compilation directives
> (`@define`, `@undef`, `@ifdef`, `@ifndef`, `@elseif`, `@else`, `@endif`)
> take no terminator and also work inside imported unit modules, evaluated
> with the root module's defines (e.g. `TARGET_WIN64`).

#### 🏁 Predefined Symbols

| Symbol               | Defined when                          |
|----------------------|---------------------------------------|
| `MYRISSA`            | Always                                |
| `CPUX64`             | Always (x64-only architecture)        |
| `APPTYPE_CONSOLE`    | Always                                |
| `WINDOWS`            | Target is `win64`                     |
| `MSWINDOWS`          | Target is `win64`                     |
| `WIN64`              | Target is `win64`                     |
| `TARGET_WIN64`       | Target is `win64`                     |
| `LINUX`              | Target is `linux64`                   |
| `TARGET_LINUX64`     | Target is `linux64`                   |
| `DEBUG`              | Optimization level is `none`          |
| `RELEASE`            | Optimization level is not `none`      |
| `BUILD_EXE`          | Module kind is `exe` (or unknown)     |
| `BUILD_DLL`          | Module kind is `dll`                  |
| `BUILD_LIB`          | Module kind is `lib`                  |


### 📦 8. Declarations

```
Declaration     = [ "public" ] ( ConstSection | TypeSection | VarSection | RoutineDecl ) .

ConstSection    = "const" { [ "public" ] ConstDecl } .
ConstDecl       = ident [ ":" TypeExpr ] "=" Expression ";" .

TypeSection     = "type" { [ "public" ] TypeDecl } .
TypeDecl        = ident "=" TypeDef ";" .

VarSection      = "var" { [ "public" ] VarDecl } .
VarDecl         = ident ":" TypeExpr [ "=" Expression ] ";" [ ExternalVarClause ] .
ExternalVarClause = "external" [ cstring | ident ] ";" .
```


### 🔧 9. Routine Declarations

```
RoutineDecl     = "routine" [ LinkageSpec ] ident [ FormalParams ] [ ":" TypeExpr ] ";"
                  ( ExternalClause | RoutineBody ) .

LinkageSpec     = "clink" | "cpplink" .

FormalParams    = "(" [ ParamList ] ")" .
ParamList       = ParamDecl { ";" ParamDecl } [ ";" "..." ] | "..." .
ParamDecl       = [ "var" | "const" ] ident ":" TypeExpr .

ExternalClause  = "external" [ cstring | ident ] ";" .

RoutineBody     = [ "type" { TypeDecl } ]
                  [ "const" { ConstDecl } ]
                  [ "var" { VarDecl } ]
                  "begin" StatementSeq "end" ";" .
```

- **C linkage (`clink`)**: Explicit C calling convention and naming. This is also the default when no linkage spec is given.
- **C++ linkage (`cpplink`)**: Enables Itanium ABI name mangling for C++ interoperability and overloading.

#### 🔗 External Clause Semantics

The optional value after `external` names the library to import from:

- **String literal** -- the library name/path directly: `external "raylib.dll";`
- **Identifier** -- names a module-level string constant declared in the
  enclosing module; the constant's value is used as the library name.
  A compile error is raised if no such string constant exists.

```
public const DLL_NAME: string = "raylib";

routine InitWindow(const width: int32; const height: int32;
  const title: pointer); external DLL_NAME;
```

**Extension resolution rules** for the library name:

- `.lib` / `.a` -- static import library.
- `.dll` / `.so` / `.so.<version>` -- dynamic import.
- **Extensionless** -- the library search paths are probed for a static
  library first; if found, static import. Otherwise dynamic: on linux64 the
  search paths are probed for `lib<name>.so.<version>`, `lib<name>.so`, then
  `<name>.so` (the found filename becomes the runtime dependency); if no
  probe hits, the target's default shared-library extension is appended.


### 🏷️ 10. Type Definitions

```
TypeDef         = RecordType | ClassType | OverlayType | ArrayType
                | PointerType | SetType | ChoicesType | RoutineType | TypeExpr .

RecordType      = "record" [ "packed" ] [ "align" "(" integer ")" ]
                  [ "(" TypeExpr ")" ]
                  { FieldDecl | AnonOverlay } "end" .

ClassType       = "class" [ "(" TypeExpr ")" ] { FieldDecl | MethodDecl } "end" .

OverlayType     = "overlay" { FieldDecl | AnonRecord } "end" .
AnonRecord      = "record" [ "packed" ] { FieldDecl | AnonOverlay } "end" ";" .
AnonOverlay     = "overlay" { FieldDecl | AnonRecord } "end" ";" .

FieldDecl       = ident ":" TypeExpr [ ":" integer ] ";" .

MethodDecl      = "method" ident [ FormalParams ] [ ":" TypeExpr ] ";"
                  [ "var" { VarDecl } ] "begin" StatementSeq "end" ";" .

ArrayType       = "array" [ "[" [ ArrayBounds ] "]" ] "of" TypeExpr .
ArrayBounds     = integer ".." integer .

PointerType     = "pointer" [ "to" [ "const" ] TypeExpr ] .

SetType         = "set" [ "of" ( integer ".." integer | TypeExpr ) ] .

ChoicesType     = "choices" "(" ChoicesValue { "," ChoicesValue } ")" .
ChoicesValue    = ident [ "=" Expression ] .

RoutineType     = "routine" [ LinkageSpec ] "(" [ ParamList ] ")" [ ":" TypeExpr ] .

TypeExpr        = QualIdent
                | "pointer" [ "to" [ "const" ] TypeExpr ]
                | "array" [ "[" [ ArrayBounds ] "]" ] "of" TypeExpr
                | "set" [ "of" ( integer ".." integer | TypeExpr ) ] .

QualIdent       = ident { "." ident } .
```

> [!NOTE]
> `choices` is used instead of `enum`,
> and `overlay` instead of `union`. Anonymous overlays and records can nest
> inside each other for C data interop. Records support single inheritance
> via `record(BaseType)` syntax and bit fields via `fieldname: type : width`.


### 📋 11. Statements

```
StatementSeq    = { Statement } .

Statement       = [ Assignment | CallStmt | IfStmt | WhileStmt | ForStmt
                | RepeatStmt | BreakStmt | ContinueStmt
                | MatchStmt | ReturnStmt | GuardStmt | RaiseStmt
                | CreateStmt | DestroyStmt
                | GetMemStmt | FreeMemStmt | ResizeMemStmt | SetLengthStmt
                | PrintStmt
                | AssertStmt | Directive | ";" ] .

Assignment      = Designator ( ":=" | "+=" | "-=" | "*=" | "/=" ) Expression [ ";" ] .

CallStmt        = Designator [ ";" ] .

IfStmt          = "if" Expression "then" StatementSeq [ "else" StatementSeq ] "end" [ ";" ] .

WhileStmt       = "while" Expression "do" StatementSeq "end" [ ";" ] .

ForStmt         = "for" ident ":=" Expression ( "to" | "downto" ) Expression
                  "do" StatementSeq "end" [ ";" ] .

RepeatStmt      = "repeat" StatementSeq "until" Expression [ ";" ] .

BreakStmt       = "break" [ ";" ] .
ContinueStmt    = "continue" [ ";" ] .

MatchStmt       = "match" Expression "of" { MatchArm } [ "else" StatementSeq ] "end" [ ";" ] .
MatchArm        = MatchLabel { "," MatchLabel } ":" StatementSeq .
MatchLabel      = Expression [ ".." Expression ] .

ReturnStmt      = "return" [ Expression ] [ ";" ] .

GuardStmt       = "guard" StatementSeq
                  ( "except" StatementSeq [ "finally" StatementSeq ]
                  | "finally" StatementSeq ) "end" [ ";" ] .

RaiseStmt       = ( "throw" "(" Expression ")"
                  | "throwcode" "(" Expression "," Expression ")" ) [ ";" ] .

CreateStmt      = "create" "(" Expression ")" [ ";" ] .
DestroyStmt     = "destroy" "(" Expression ")" [ ";" ] .
GetMemStmt      = "getmem" "(" Expression ")" [ ";" ] .
FreeMemStmt     = "freemem" "(" Expression ")" [ ";" ] .
ResizeMemStmt   = "resizemem" "(" Expression "," Expression ")" [ ";" ] .
SetLengthStmt   = "setlength" "(" Expression "," Expression ")" [ ";" ] .
PrintStmt       = ( "print" | "println" ) "(" [ ArgList ] ")" [ ";" ] .
```

> [!NOTE]
> `break` and `continue` are valid only inside a `while`, `for`, or `repeat`
> body (compile error SEM008 otherwise). `break` exits the innermost loop;
> `continue` starts its next iteration. In a `for` loop, `continue` still
> performs the iterator step before re-testing the bound.

#### 🧪 Assert Statements (Unit Testing)

Assert statements are available in all code but are primarily used inside test blocks.
All assertions continue after failure -- failures accumulate and are reported per test.
The compiler handles all test infrastructure automatically. When `@unittestmode on;` is active, test blocks are compiled, registered, and executed by the built-in test runner.
The compiler injects source file and line number automatically.

```
AssertStmt      = ( "assert" "(" Expression ")"
                  | "asserttrue" "(" Expression ")"
                  | "assertfalse" "(" Expression ")"
                  | "asserteq" "(" Expression "," Expression ")"
                  | "asserteqf" "(" Expression "," Expression "," Expression ")"
                  | "assertnil" "(" Expression ")"
                  | "assertnotnil" "(" Expression ")"
                  | "assertfail" "(" Expression ")" ) [ ";" ] .
```

- `assert(expr)` -- Fails if `expr` is false.
- `asserttrue(expr)` -- Fails if `expr` is not true.
- `assertfalse(expr)` -- Fails if `expr` is not false.
- `asserteq(expected, actual)` -- Fails if values are not equal. Type-dispatched: the compiler selects the appropriate comparison (int, uint, float, string, bool, pointer) based on operand types.
- `asserteqf(expected, actual, epsilon)` -- Float equality within a tolerance. Fails if `|expected - actual| > epsilon`. All three operands must be `float32` or `float64`; a non-float operand is a compile error, not an implicit conversion.
- `assertnil(expr)` -- Fails if `expr` is not nil.
- `assertnotnil(expr)` -- Fails if `expr` is nil.
- `assertfail("message")` -- Unconditional failure with a message.


### 🧮 12. Expressions

```
Expression      = SimpleExpr [ RelOp SimpleExpr ] .
RelOp           = "=" | "<>" | "<" | ">" | "<=" | ">=" | "in" .

SimpleExpr      = [ "+" | "-" ] Term { AddOp Term } .
AddOp           = "+" | "-" | "or" | "xor" .

Term            = Factor { MulOp Factor } .
MulOp           = "*" | "/" | "div" | "mod" | "and" | "shl" | "shr" .

Factor          = "not" Factor | "-" Factor | "+" Factor
                | "address" "of" Factor | Primary .

Primary         = integer | float_literal | cstring | wstring
                | "true" | "false" | "nil"
                | SetLiteral | RecordLiteral
                | "(" Expression ")" | Designator | Intrinsic | TypeCast .

Designator      = ( ident | "self" | "parent" | "varargs" ) { Selector } .
Selector        = "." ident | "[" Expression "]" | "^" | "(" [ ArgList ] ")" .

ArgList         = Expression { "," Expression } .

SetLiteral      = "[" [ SetElement { "," SetElement } ] "]" .
SetElement      = Expression [ ".." Expression ] .

RecordLiteral   = ident "(" FieldInit { "," FieldInit } ")" .
FieldInit       = ident ":" Expression .

TypeCast        = TypeExpr "(" Expression ")" .
```

#### 📍 Pointer Operations

- `address of expr` -- Returns a pointer to the operand.
- `expr^` -- Postfix (selector): dereference. Follows the pointer to its target.


### ⚡ 13. Intrinsics

```
Intrinsic       = LenExpr | SizeExpr | Utf8Expr | CStrExpr | WStrExpr
                | ParamCountExpr | ParamStrExpr | ExcCodeExpr | ExcMsgExpr .

LenExpr         = "len" "(" Expression ")" .
SizeExpr        = "size" "(" ( TypeExpr | Expression ) ")" .
Utf8Expr        = "utf8" "(" Expression ")" .
CStrExpr        = "cstr" "(" Expression ")" .
WStrExpr        = "wstr" "(" Expression ")" .
ParamCountExpr  = "paramcount" "(" ")" .
ParamStrExpr    = "paramstr" "(" Expression ")" .
ExcCodeExpr     = "exccode" "(" ")" .
ExcMsgExpr      = "excmsg" "(" ")" .
```

> [!NOTE]
> `len` returns the length of strings, wide strings, and dynamic arrays.
> `size` returns the byte size of a type or expression. `utf8` converts a wide
> string to a newly allocated, raw UTF-8 buffer (`char*`) - NOT a managed
> string; the buffer is owned by the caller. `cstr` returns a BORROWED raw
> UTF-8 `char*` pointing into an existing managed string's own storage - it
> allocates nothing and must never be freed, and the pointer is valid only
> while the owning string is alive. `wstr` is the UTF-16 counterpart of
> `cstr`: it returns a BORROWED `wchar*` that the runtime widens once and
> CACHES on the string itself, so repeat calls are free and the buffer must
> never be freed by the caller. Memory management (`create`/`destroy`/`getmem`/
> `freemem`/`resizemem`/`setlength`) is defined in Statements (Section 11).


### 🧺 14. Variadic Arguments

```
ParamList       = ParamDecl { ";" ParamDecl } [ ";" "..." ] | "..." .

VarArgsAccess   = "varargs" "." "next" "(" TypeExpr ")"
                | "varargs" "." "get" "(" Expression "," TypeExpr ")"
                | "varargs" "." "reset" "(" ")"
                | "varargs" "." "copy" "(" ")"
                | "varargs" "." "count" .
```

- `varargs.next(TypeExpr)` -- Retrieves and consumes the next variadic argument.
- `varargs.get(Expression, TypeExpr)` -- Retrieves the argument at the given index without advancing the cursor.
- `varargs.reset()` -- Resets the cursor back to the first argument.
- `varargs.count` -- Total number of variadic arguments passed.
- `varargs.copy()` -- Returns a new `varargs` object with a copied cursor position.


### 🧪 15. Unit Testing

Test blocks appear after the module's `end.` and are only compiled when the
`@unittestmode on;` directive is active. When `@unittestmode on;` is active:

1. The compiler parses test blocks after `end.`
2. Each test block is compiled as a parameterless routine
3. The normal entry point is replaced with the built-in test runner

```
TestBlock     = "test" cstring [ "var" { VarDecl } ]
                "begin" StatementSeq "end" ";" .
```

#### Example

```
module exe mathlib;

@unittestmode on;

routine add(const a: int32; const b: int32): int32;
begin
  return a + b;
end;

routine mul(const a: int32; const b: int32): int32;
begin
  return a * b;
end;

initialize
  println("Module initialized");
end;

finalize
  println("Module finalized");
end;

end.

test "add returns correct sum"
var
  result: int32;
begin
  result := add(2, 3);
  asserteq(5, result);
end;

test "add handles negative numbers"
begin
  asserteq(-2, add(-5, 3));
  asserteq(-8, add(-5, -3));
end;

test "mul returns correct product"
begin
  asserteq(20, mul(4, 5));
  asserteq(0, mul(0, 100));
end;
```



### 🎚️ 16. Operator Precedence (Highest to Lowest)

| Precedence | Operators                                        |
|------------|--------------------------------------------------|
| 1 (highest)| `not` `-` (unary) `+` (unary) `address of`      |
| 2          | `*` `/` `div` `mod` `and` `shl` `shr`           |
| 3          | `+` `-` `or` `xor`                               |
| 4 (lowest) | `=` `<>` `<` `>` `<=` `>=` `in`                  |

### 🧪 Grammar Validation Checklist

Use this checklist when updating the grammar or adding syntax:

- 🔤 Lexical rules define the token shape before parser rules depend on it
- 🚫 Reserved words are listed before examples rely on them
- 🧱 New type forms appear in both the type grammar and the Language Reference
- 🔧 New routine syntax is reflected in declarations, statements, and examples where applicable
- 🧮 Operator changes update precedence and expression grammar together
- 🧪 Unit-test syntax matches the assertion helper documentation
- 🧭 Any new directive is added to the known directive table and the conditional compilation section

> [!WARNING]
> 🧯 Keep grammar changes synchronized with examples. A grammar rule that accepts syntax not shown anywhere else is hard for users to discover, and an example that violates the grammar is worse than no example at all.

