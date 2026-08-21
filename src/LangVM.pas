{===============================================================================
  LangVM™ - Language Virtual Machine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://langvm.org

  See LICENSE for license information
===============================================================================}

unit LangVM;

{$I StdApp.Defines.inc}

interface

uses
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  System.Character,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.Math,
  System.DateUtils,
  System.TypInfo,
  System.NetEncoding,
  StdApp.Base,
  StdApp.Utils,
  StdApp.Console,
  StdApp.Resources,
  StdApp.VirtualMemory,
  LangVM.ZigBuild,
  Winapi.Windows;

const

  // Version
  LVM_VERSION_MAJOR = '0';
  LVM_VERSION_MINOR = '1';
  LVM_VERSION_PATCH = '0';
  LVM_VERSION       = LVM_VERSION_MAJOR + '.' + LVM_VERSION_MINOR + '.' +
                      LVM_VERSION_PATCH;

  { LVM_FILEEXT }
  LVM_FILEEXT = '.lvm';

  { LVM well-known environment variable names }
  LVM_EXITCODE  = 'ExitCode';
  LVM_RESULT    = 'Result';
  LVM_SRCFILE   = 'SourceFilename';
  LVM_MAIN      = 'Main';
  LVM_AUTORUN   = 'AutoRun';
  LVM_TARGET    = 'Target';
  LVM_OUTPUTPATH = 'OutputPath';
  LVM_SUBSYSTEM = 'Subsystem';
  LVM_OPTLEVEL  = 'OptimizeLevel';

  { LVM well-known routine names }
  LVM_MAINFUNC = 'main';

type
  // Class forwards
  TLangVM = class;
  TLVMListStore = class;
  TLVMMapStore = class;

  { TLVMValueKind }
  TLVMValueKind = (
    vkNil,
    vkInt,
    vkFloat,
    vkBool,
    vkString,
    vkHandle,
    vkList,
    vkMap,
    vkRoutine,
    vkBuffer
  );

  { === ILVMListRef ========================================================= }
  ILVMListRef = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function GetStore(): TLVMListStore;
    property Store: TLVMListStore read GetStore;
  end;

  { === ILVMMapRef ========================================================== }
  ILVMMapRef = interface
    ['{B2C3D4E5-F6A7-8901-BCDE-F12345678901}']
    function GetStore(): TLVMMapStore;
    property Store: TLVMMapStore read GetStore;
  end;

  { === ILVMBufferRef ======================================================= }
  ILVMBufferRef = interface
    ['{C3D4E5F6-A7B8-9012-CDEF-345678901234}']
    function GetStore(): TVirtualMemory<Byte>;
    function GetIsExecutable(): Boolean;
    property Store: TVirtualMemory<Byte> read GetStore;
    property IsExecutable: Boolean read GetIsExecutable;
  end;

  { === TLVMValue =========================================================== }
  TLVMValue = record
  private
    FKind: TLVMValueKind;
    FInt: Int64;
    FFloat: Double;
    FBool: Boolean;
    FStr: string;
    FHandle: Pointer;
    FList: ILVMListRef;
    FMap: ILVMMapRef;
    FRoutine: Pointer;  // AST node pointer for user-defined routines
    FBuffer: ILVMBufferRef;
    FTypeName: string;
  public
    // Creation
    class function Nil_(): TLVMValue; static;
    class function FromInt(const AValue: Int64): TLVMValue; static;
    class function FromFloat(const AValue: Double): TLVMValue; static;
    class function FromBool(const AValue: Boolean): TLVMValue; static;
    class function FromString(const AValue: string): TLVMValue; static;
    class function FromHandle(const AValue: Pointer): TLVMValue; static;
    class function FromList(): TLVMValue; static;
    class function FromArray(const AValues: TArray<TLVMValue>): TLVMValue; static;
    class function FromMap(): TLVMValue; static;
    class function FromRoutine(const ANode: Pointer): TLVMValue; static;
    class function FromBuffer(const ASize: Integer;
      const AExecutable: Boolean = False): TLVMValue; overload; static;
    class function FromBuffer(
      const AStore: TVirtualMemory<Byte>): TLVMValue; overload; static;

    // Extraction (raises on type mismatch)
    function AsInt(): Int64;
    function AsFloat(): Double;
    function AsBool(): Boolean;
    function AsString(): string;
    function AsHandle(): Pointer;
    function AsList(): TLVMListStore;
    function AsMap(): TLVMMapStore;
    function AsRoutine(): Pointer;
    function AsBuffer(): TVirtualMemory<Byte>;

    // Type queries
    function IsNil(): Boolean;
    function IsTrue(): Boolean;
    function ToString(): string;
    function KindName(): string;
    class function IsValidTypeName(const AName: string): Boolean; static;
    class function KindMatchesType(const AValue: TLVMValue;
      const ATypeName: string): Boolean; static;

    // Properties
    property Kind: TLVMValueKind read FKind;
    property TypeName: string read FTypeName write FTypeName;
  end;

  { === TLVMListStore ======================================================= }
  TLVMListStore = class(TList<TLVMValue>)
  end;

  { === TLVMMapStore ======================================================== }
  TLVMMapStore = class(TDictionary<string, TLVMValue>)
  private
    FTypeName: string;
  public
    property TypeName: string read FTypeName write FTypeName;
  end;

  { === TLVMRecordDef ======================================================= }
  TLVMRecordDef = class
  private
    FName: string;
    FFieldNames: TList<string>;
    FFieldDefaults: TDictionary<string, TLVMValue>;
    FIsLayout: Boolean;
    FFieldSizes: TDictionary<string, Integer>;
    FFieldOffsets: TDictionary<string, Integer>;
    FTotalSize: Integer;
  public
    constructor Create(const AName: string);
    destructor Destroy(); override;
    procedure AddField(const AName: string; const ADefault: TLVMValue);
    procedure AddLayoutField(const AName: string; const AByteSize: Integer;
      const ADefault: TLVMValue);
    function HasField(const AName: string): Boolean;
    function CreateInstance(): TLVMValue;
    property RecordName: string read FName;
    property FieldNames: TList<string> read FFieldNames;
    property FieldDefaults: TDictionary<string, TLVMValue> read FFieldDefaults;
    property IsLayout: Boolean read FIsLayout;
    property TotalSize: Integer read FTotalSize;
    property FieldSizes: TDictionary<string, Integer> read FFieldSizes;
    property FieldOffsets: TDictionary<string, Integer> read FFieldOffsets;
  end;

  { === TLVMListRef ========================================================= }
  TLVMListRef = class(TInterfacedObject, ILVMListRef)
  private
    FStore: TLVMListStore;
    function GetStore(): TLVMListStore;
  public
    constructor Create();
    destructor Destroy(); override;
    property Store: TLVMListStore read GetStore;
  end;

  { === TLVMMapRef ========================================================== }
  TLVMMapRef = class(TInterfacedObject, ILVMMapRef)
  private
    FStore: TLVMMapStore;
    function GetStore(): TLVMMapStore;
  public
    constructor Create();
    destructor Destroy(); override;
    property Store: TLVMMapStore read GetStore;
  end;

  { === TLVMBufferRef ======================================================= }
  TLVMBufferRef = class(TInterfacedObject, ILVMBufferRef)
  private
    FStore: TVirtualMemory<Byte>;
    FIsExecutable: Boolean;
    function GetStore(): TVirtualMemory<Byte>;
    function GetIsExecutable(): Boolean;
  public
    constructor Create(const ASize: Integer; const AExecutable: Boolean = False); overload;
    constructor Create(const AStore: TVirtualMemory<Byte>); overload;
    destructor Destroy(); override;
    property Store: TVirtualMemory<Byte> read GetStore;
    property IsExecutable: Boolean read GetIsExecutable;
  end;

  { === TLVMTokenKind ======================================================= }
  TLVMTokenKind = (
    // Keywords -- language structure
    tkLanguage, tkVersion, tkTokens, tkTypes, tkGrammar, tkSemantics,
    tkEmitters, tkMir, tkRule, tkOn, tkToken, tkType, tkMap, tkLiteral,
    tkCompatible, tkDeclKind, tkCallKind, tkCallNameAttr,
    tkPrecedence, tkLeft, tkRight, tkPass, tkSection,

    // Keywords -- control flow
    tkLet, tkConst, tkEnum, tkRoutine, tkFragment, tkImport, tkInclude,
    tkGuard, tkIf, tkElse, tkWhile, tkFor, tkIn, tkBreak, tkContinue,
    tkReturn, tkMatch, tkTry, tkRecover, tkRecord, tkExtends, tkLayout,

    // Keywords -- declarative / pipeline
    tkOptional, tkSync, tkExpect, tkConsume, tkParse, tkMany, tkUntil,
    tkScope, tkDeclare, tkVisit, tkLookup, tkChildren, tkChild,
    tkAs, tkTyped,

    // Keywords -- diagnostics
    tkError, tkWarning, tkHint, tkNote, tkInfo,

    // Keywords -- logical
    tkAnd, tkOr, tkNot,

    // Keywords -- bitwise shift
    tkShl, tkShr,

    // Keywords -- literals
    tkTrue, tkFalse, tkNil,

    // Literal tokens
    tkIntLit, tkFloatLit, tkStringLit, tkTripleStringLit,

    // Identifier
    tkIdentifier,

    // Operators
    tkPlus, tkMinus, tkStar, tkSlash, tkPercent,
    tkEqEq, tkNeq, tkLt, tkGt, tkLe, tkGe,

    // Delimiters
    tkLParen, tkRParen, tkLBracket, tkRBracket, tkLBrace, tkRBrace,
    tkSemicolon, tkComma, tkDot, tkColon, tkAssign, tkArrow, tkFatArrow,
    tkPipe, tkAt, tkDotDot,

    // End of file
    tkEOF
  );

  { === TLVMToken =========================================================== }
  TLVMToken = record
    Kind: TLVMTokenKind;
    Text: string;
    Line: Integer;
    Col: Integer;
  end;

  { === TLVMLexer =========================================================== }
  TLVMLexer = class(TBaseObject)
  private
    FSource: string;
    FFilename: string;
    FPos: Integer;
    FLine: Integer;
    FCol: Integer;
    FTokens: TList<TLVMToken>;
    FKeywords: TDictionary<string, TLVMTokenKind>;
    procedure InitKeywords();
    procedure SkipWhitespace();
    procedure SkipLineComment();
    procedure SkipBlockComment();
    function Peek(): Char;
    function PeekAt(const AOffset: Integer): Char;
    function Advance(): Char;
    function IsAtEnd(): Boolean;
    function IsDigit(const ACh: Char): Boolean;
    function IsAlpha(const ACh: Char): Boolean;
    function IsAlphaNum(const ACh: Char): Boolean;
    procedure ScanNumber();
    procedure ScanString();
    procedure ScanSingleQuoteString();
    procedure ScanTripleQuoteString();
    procedure ScanInterpolationBody();
    procedure ScanIdentifier();
    procedure AddToken(const AKind: TLVMTokenKind; const AText: string;
      const ALine, ACol: Integer);
    {$HINTS OFF}
    procedure LexError(const ALine, ACol: Integer; const AMsg: string); overload;
    procedure LexError(const ALine, ACol: Integer; const AMsg: string;
      const AArgs: array of const); overload;
    {$HINTS ON}
  public
    constructor Create(); override;
    destructor Destroy(); override;
    function Tokenize(const ASource, AFilename: string): TArray<TLVMToken>;
  end;

  { === TLVMASTNode ========================================================= }
  TLVMASTNode = class
  private
    FKind: string;
    FAttrs: TDictionary<string, string>;
    FChildren: TObjectList<TLVMASTNode>;
    FParent: TLVMASTNode;
    FLine: Integer;
    FCol: Integer;
    FFilename: string;
  public
    constructor Create();
    destructor Destroy(); override;
    procedure SetAttr(const AKey, AValue: string);
    function GetAttr(const AKey: string): string;
    function HasAttr(const AKey: string): Boolean;
    function AddChild(const AChild: TLVMASTNode): TLVMASTNode;
    function ChildCount(): Integer;
    property Kind: string read FKind write FKind;
    property Attrs: TDictionary<string, string> read FAttrs;
    property Children: TObjectList<TLVMASTNode> read FChildren;
    property Line: Integer read FLine write FLine;
    property Col: Integer read FCol write FCol;
    property Filename: string read FFilename write FFilename;
  end;

  { === TLVMMirType ========================================================= }
  TLVMMirType = (
    mtI8, mtU8, mtI16, mtU16, mtI32, mtU32, mtI64, mtU64,
    mtF, mtD, mtLD, mtP, mtVoid,
    mtBlk, mtBlk1, mtBlk2, mtBlk3, mtBlk4, mtBlk5, mtRBlk
  );

  { === TLVMMirOpcode ======================================================= }
  TLVMMirOpcode = (
    // Move
    mopMov, mopFmov, mopDmov, mopLdmov,
    // Memory access
    mopLoad, mopStore,
    // Integer arithmetic 64-bit
    mopAdd, mopSub, mopMul, mopDiv, mopMod,
    mopUmul, mopUdiv, mopUmod, mopNeg,
    // Integer arithmetic 32-bit
    mopAdds, mopSubs, mopMuls, mopDivs, mopMods,
    mopUmuls, mopUdivs, mopUmods, mopNegs,
    // Overflow 64-bit
    mopAddo, mopSubo, mopMulo, mopUmulo,
    // Overflow 32-bit
    mopAddos, mopSubos, mopMulos, mopUmulos,
    // Bitwise 64-bit
    mopAnd, mopOr, mopXor, mopLsh, mopRsh, mopUrsh,
    // Bitwise 32-bit
    mopAnds, mopOrs, mopXors, mopLshs, mopRshs, mopUrshs,
    // Comparison 64-bit
    mopEq, mopNe, mopLt, mopLe, mopGt, mopGe,
    mopUlt, mopUle, mopUgt, mopUge,
    // Comparison 32-bit
    mopEqs, mopNes, mopLts, mopLes, mopGts, mopGes,
    mopUlts, mopUles, mopUgts, mopUges,
    // Float arithmetic
    mopFadd, mopFsub, mopFmul, mopFdiv, mopFneg,
    mopDadd, mopDsub, mopDmul, mopDdiv, mopDneg,
    mopLdadd, mopLdsub, mopLdmul, mopLddiv, mopLdneg,
    // Float comparison
    mopFeq, mopFne, mopFlt, mopFle, mopFgt, mopFge,
    mopDeq, mopDne, mopDlt, mopDle, mopDgt, mopDge,
    mopLdeq, mopLdne, mopLdlt, mopLdle, mopLdgt, mopLdge,
    // Conversion
    mopExt8, mopUext8, mopExt16, mopUext16, mopExt32, mopUext32,
    mopI2f, mopI2d, mopI2ld, mopUi2f, mopUi2d, mopUi2ld,
    mopF2i, mopD2i, mopLd2i, mopF2d, mopF2ld,
    mopD2f, mopD2ld, mopLd2f, mopLd2d,
    // Address
    mopAddr, mopAddr8, mopAddr16, mopAddr32,
    // Branch
    mopJmp, mopBt, mopBf, mopBts, mopBfs, mopJmpi,
    // Branch on overflow
    mopBo, mopBno, mopUbo, mopUbno,
    // Compare-and-branch 64-bit
    mopBeq, mopBne, mopBlt, mopBle, mopBgt, mopBge,
    mopUblt, mopUble, mopUbgt, mopUbge,
    // Compare-and-branch 32-bit
    mopBeqs, mopBnes, mopBlts, mopBles, mopBgts, mopBges,
    mopUblts, mopUbles, mopUbgts, mopUbges,
    // Compare-and-branch float
    mopFbeq, mopFbne, mopFblt, mopFble, mopFbgt, mopFbge,
    mopDbeq, mopDbne, mopDblt, mopDble, mopDbgt, mopDbge,
    mopLdbeq, mopLdbne, mopLdblt, mopLdble, mopLdbgt, mopLdbge,
    // Switch
    mopSwitch,
    // Label address
    mopLaddr,
    // Call/return
    mopCall, mopInline, mopRet,
    mopJcall, mopJret,
    // Stack
    mopAlloca, mopBstart, mopBend,
    // Varargs
    mopVaStart, mopVaArg, mopVaBlockArg, mopVaEnd,
    // Properties
    mopPrset, mopPrbeq, mopPrbne
  );

  { === TLVMMirOperandKind ================================================== }
  TLVMMirOperandKind = (
    mokRegister,       // named local variable / register
    mokImmediateInt,   // integer literal
    mokImmediateFloat, // float literal
    mokLabel,          // branch target label
    mokReference,      // function/data/import name reference
    mokMemory,         // memory operand with addressing mode
    mokString          // inline string in call instructions
  );

  { === TLVMMirMemOperand =================================================== }
  TLVMMirMemOperand = record
    MemType: TLVMMirType;
    Displacement: Int64;
    Base: string;
    Index: string;
    Scale: Integer;
  end;

  { === TLVMMirOperand ====================================================== }
  TLVMMirOperand = record
    Kind: TLVMMirOperandKind;
    RegName: string;
    IntValue: Int64;
    FloatValue: Double;
    LabelName: string;
    RefName: string;
    Mem: TLVMMirMemOperand;
    StrValue: string;
    BlockSize: Integer;
    BlockCase: Integer;
  end;

  { === TLVMMirInsn ========================================================= }
  TLVMMirInsn = record
    Opcode: TLVMMirOpcode;
    Operands: TArray<TLVMMirOperand>;
    LabelDef: string;
    IsLabelOnly: Boolean;
    Line: Integer;
    Col: Integer;
  end;

  { === TLVMMirLocal ======================================================== }
  TLVMMirLocal = record
    LocalName: string;
    LocalType: TLVMMirType;
    HardReg: string;
  end;

  { === TLVMMirProto ======================================================== }
  TLVMMirProto = record
    ProtoName: string;
    ResultTypes: TArray<TLVMMirType>;
    ParamTypes: TArray<TLVMMirType>;
    ParamNames: TArray<string>;
    IsVararg: Boolean;
  end;

  { === TLVMMirDataKind ===================================================== }
  TLVMMirDataKind = (
    mdkData, mdkString, mdkBss, mdkRef, mdkExpr, mdkLref
  );

  { === TLVMMirDataItem ===================================================== }
  TLVMMirDataItem = record
    DataKind: TLVMMirDataKind;
    ItemName: string;
    DataType: TLVMMirType;
    IntValues: TArray<Int64>;
    FloatValues: TArray<Double>;
    StrValue: string;
    BssSize: Int64;
    RefTarget: string;
    RefDisp: Int64;
    ExprFunc: string;
    LrefLabel1: string;
    LrefLabel2: string;
    LrefDisp: Int64;
  end;

  { === TLVMMirFunc ========================================================= }
  TLVMMirFunc = class
  private
    FFuncName: string;
    FResultTypes: TArray<TLVMMirType>;
    FParams: TArray<TLVMMirLocal>;
    FLocals: TArray<TLVMMirLocal>;
    FInsns: TArray<TLVMMirInsn>;
    FIsVararg: Boolean;
  public
    constructor Create();
    destructor Destroy(); override;
    property FuncName: string read FFuncName write FFuncName;
    property ResultTypes: TArray<TLVMMirType> read FResultTypes write FResultTypes;
    property Params: TArray<TLVMMirLocal> read FParams write FParams;
    property Locals: TArray<TLVMMirLocal> read FLocals write FLocals;
    property Insns: TArray<TLVMMirInsn> read FInsns write FInsns;
    property IsVararg: Boolean read FIsVararg write FIsVararg;
    procedure AddInsn(const AInsn: TLVMMirInsn);
    procedure AddLocal(const ALocal: TLVMMirLocal);
  end;

  { === TLVMMirModule ======================================================= }
  TLVMMirModule = class
  private
    FModuleName: string;
    FImports: TArray<string>;
    FExportList: TArray<string>;
    FForwards: TArray<string>;
    FProtos: TArray<TLVMMirProto>;
    FFuncs: TObjectList<TLVMMirFunc>;
    FDataItems: TArray<TLVMMirDataItem>;
  public
    constructor Create();
    destructor Destroy(); override;
    property ModuleName: string read FModuleName write FModuleName;
    property Imports: TArray<string> read FImports write FImports;
    property ExportList: TArray<string> read FExportList write FExportList;
    property Forwards: TArray<string> read FForwards write FForwards;
    property Protos: TArray<TLVMMirProto> read FProtos write FProtos;
    property Funcs: TObjectList<TLVMMirFunc> read FFuncs;
    property DataItems: TArray<TLVMMirDataItem> read FDataItems write FDataItems;
    procedure AddImport(const AName: string);
    procedure AddExport(const AName: string);
    procedure AddForward(const AName: string);
    procedure AddProto(const AProto: TLVMMirProto);
    procedure AddFunc(const AFunc: TLVMMirFunc);
    procedure AddDataItem(const AItem: TLVMMirDataItem);
  end;

  { === TLVMMirProgram ====================================================== }
  TLVMMirProgram = class
  private
    FModules: TObjectList<TLVMMirModule>;
    FOptMode: string;
    FDebugInfo: Boolean;
  public
    constructor Create();
    destructor Destroy(); override;
    property Modules: TObjectList<TLVMMirModule> read FModules;
    property OptMode: string read FOptMode write FOptMode;
    property DebugInfo: Boolean read FDebugInfo write FDebugInfo;
    procedure AddModule(const AModule: TLVMMirModule);
    procedure Clear();
  end;

  { === TLVMParser ========================================================== }
  TLVMParser = class(TBaseObject)
  private
    FTokens: TArray<TLVMToken>;
    FPos: Integer;
    FFilename: string;
    FAllNodes: TList<TLVMASTNode>;
    FUserTypeNames: TDictionary<string, Boolean>;

    // Token navigation
    function Peek(): TLVMToken;
    function PeekKind(): TLVMTokenKind;
    function Advance(): TLVMToken;
    {$HINTS OFF}
    function Match(const AKind: TLVMTokenKind): Boolean;
    {$HINTS ON}
    function Check(const AKind: TLVMTokenKind): Boolean;
    function Expect(const AKind: TLVMTokenKind): TLVMToken;
    function ExpectWord(): TLVMToken;
    function IsAtEnd(): Boolean;

    // Type names (accepts identifiers and keywords used as type names)
    function ParseTypeName(): string;

    // Top-level
    function ParseSourceFile(): TLVMASTNode;
    function ParseLanguageDecl(): TLVMASTNode;
    function ParseTopLevelBlock(): TLVMASTNode;

    // Pipeline blocks
    function ParseTokenBlock(): TLVMASTNode;
    function ParseTokenDecl(): TLVMASTNode;
    function ParseTokenConfig(): TLVMASTNode;
    function ParseTypesBlock(): TLVMASTNode;
    function ParseTypeDecl(): TLVMASTNode;
    function ParseGrammarBlock(): TLVMASTNode;
    function ParseRuleDecl(): TLVMASTNode;
    function ParseSemanticsBlock(): TLVMASTNode;
    function ParsePassBlock(): TLVMASTNode;
    function ParseSemanticDecl(): TLVMASTNode;
    function ParseEmitterBlock(): TLVMASTNode;
    function ParseEmitDecl(): TLVMASTNode;
    function IsMirWord(const ATok: TLVMToken): Boolean;
    function ExpectMirWord(): TLVMToken;
    function ParseMirHandlerDecl(): TLVMASTNode;
    function ParseMirBlock(): TLVMASTNode;
    function ParseTargetHandlerDecl(): TLVMASTNode;
    function ParseTargetBlock(): TLVMASTNode;

    // Declarations
    function ParseConstBlock(): TLVMASTNode;
    function ParseEnumDecl(): TLVMASTNode;
    function ParseRoutineDecl(): TLVMASTNode;
    function ParseFragmentDecl(): TLVMASTNode;
    function ParseRecordDecl(): TLVMASTNode;
    function ParseImportStmt(): TLVMASTNode;
    function ParseIncludeStmt(): TLVMASTNode;
    function ParseGuardBlock(): TLVMASTNode;

    // Statements
    function ParseStmt(): TLVMASTNode;
    function ParseLetStmt(): TLVMASTNode;
    function ParseAssignOrExprStmt(): TLVMASTNode;
    function ParseIfStmt(): TLVMASTNode;
    function ParseWhileStmt(): TLVMASTNode;
    function ParseForStmt(): TLVMASTNode;
    function ParseMatchStmt(): TLVMASTNode;
    function ParseGuardStmt(): TLVMASTNode;
    function ParseReturnStmt(): TLVMASTNode;
    function ParseBreakStmt(): TLVMASTNode;
    function ParseContinueStmt(): TLVMASTNode;
    function ParseTryRecover(): TLVMASTNode;
    function ParseDiagStmt(): TLVMASTNode;
    function ParseExpectStmt(): TLVMASTNode;
    function ParseConsumeStmt(): TLVMASTNode;
    function ParseParseDirective(): TLVMASTNode;
    function ParseOptionalBlock(): TLVMASTNode;
    function ParseSyncStmt(): TLVMASTNode;
    function ParseScopeBlock(): TLVMASTNode;
    function ParseDeclareStmt(): TLVMASTNode;
    function ParseVisitStmt(): TLVMASTNode;
    function ParseLookupStmt(): TLVMASTNode;
    function ParseSectionBlock(): TLVMASTNode;
    function ParseStmtBlock(): TLVMASTNode;

    // Token references
    function ParseTokenRef(): string;

    // Expressions
    function ParseExpr(): TLVMASTNode;
    function ParseOrExpr(): TLVMASTNode;
    function ParseAndExpr(): TLVMASTNode;
    function ParseNotExpr(): TLVMASTNode;
    function ParseComparison(): TLVMASTNode;
    function ParseAddition(): TLVMASTNode;
    function ParseShift(): TLVMASTNode;
    function ParseTerm(): TLVMASTNode;
    function ParseFactor(): TLVMASTNode;
    function ParseAtom(): TLVMASTNode;

    // Helpers
    function MakeNode(const AKind: string; const ALine, ACol: Integer): TLVMASTNode;
    function IsTokenConfigKeyword(const AText: string): Boolean;
    {$HINTS OFF}
    function IsTypeKeyword(const AText: string): Boolean;
    {$HINTS ON}
    procedure ParseError(const ATok: TLVMToken; const AMsg: string); overload;
    procedure ParseError(const ATok: TLVMToken; const AMsg: string;
      const AArgs: array of const); overload;
  public
    constructor Create(); override;
    destructor Destroy(); override;
    function Parse(const ATokens: TArray<TLVMToken>;
      const AFilename: string): TLVMASTNode;
    function ParseSingleExpr(const ATokens: TArray<TLVMToken>;
      const AFilename: string): TLVMASTNode;
  end;

  { TLVMVarEntry }
  TLVMVarEntry = record
    Value: TLVMValue;
    TypeName: string;
  end;

  { TLVMScope }
  TLVMScope = class
  private
    FVars: TDictionary<string, TLVMVarEntry>;
    FParent: TLVMScope;
  public
    constructor Create(const AParent: TLVMScope);
    destructor Destroy(); override;
    property Vars: TDictionary<string, TLVMVarEntry> read FVars;
    property Parent: TLVMScope read FParent;
  end;

  { TUpdateVarResult }
  TUpdateVarResult = (uvrOK, uvrNotFound, uvrTypeMismatch);

  { === TLVMEnvironment ===================================================== }
  TLVMEnvironment = class(TBaseObject)
  private
    FCurrent: TLVMScope;
    FScopes: TObjectList<TLVMScope>;
    FScopeStack: TList<TLVMScope>;
  public
    constructor Create(); override;
    destructor Destroy(); override;
    procedure PushScope();
    procedure PopScope();
    procedure EnterGlobalScope();
    procedure LeaveGlobalScope();
    procedure Clear();
    function DeclareVar(const AName: string; const AValue: TLVMValue; const ATypeName: string = 'any'): Boolean;
    procedure ForceSetVar(const AName: string; const AValue: TLVMValue; const ATypeName: string = 'any');
    function UpdateVar(const AName: string; const AValue: TLVMValue): TUpdateVarResult;
    function TryGetVar(const AName: string; out AValue: TLVMValue): Boolean;
    function GetVar(const AName: string): TLVMValue;
    function HasVar(const AName: string): Boolean;
    function CurrentScope(): TLVMScope;
  end;

  { TLVMPrintCallback }
  TLVMPrintCallback = reference to procedure(const AText: string;
    const AUserData: Pointer);

  { TLVMDiagCallback }
  TLVMDiagCallback = reference to procedure(
    const ASeverity: string; const AMessage: string;
    const AFile: string; const ALine: Integer; const ACol: Integer;
    const AUserData: Pointer);

  { TLVMBuiltinFunc }
  TLVMBuiltinFunc = reference to function(
    const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue;

  { TLVMSignal }
  TLVMSignal = (lsNone, lsReturn, lsBreak, lsContinue);

  { TLVMHandlerMap }
  TLVMHandlerMap = TDictionary<string, TLVMASTNode>;

  { TLVMSemanticPassMap }
  TLVMSemanticPassMap = TObjectDictionary<Integer, TLVMHandlerMap>;

  { TLVMUserToken }
  TLVMUserToken = record
    Kind: string;
    Text: string;
    Filename: string;
    Line: Integer;
    Col: Integer;
  end;

  { TLVMInfixEntry }
  TLVMInfixEntry = record
    Power: Integer;
    Assoc: string;
    RuleAST: TLVMASTNode;
  end;

  { TLVMOperatorEntry }
  TLVMOperatorEntry = record
    Text: string;
    Kind: string;
  end;

  { TLVMStringStyleEntry }
  TLVMStringStyleEntry = record
    OpenText: string;
    CloseText: string;
    Kind: string;
    Flags: string;
  end;

  { TLVMLexerConfig }
  TLVMLexerConfig = record
    CaseSensitive: Boolean;
    Terminator: string;
    BlockOpen: string;
    BlockClose: string;
    DirectivePrefix: string;
    HexPrefix: TStringList;
  end;

  { TLVMCompatEntry }
  TLVMCompatEntry = record
    FromType: string;
    ToType: string;
    CoerceExpr: string;
  end;

  { === TLVMSymbol ========================================================== }
  TLVMSymbol = class
  private
    FSymName: string;
    FSymKind: string;
    FTypeName: string;
    FAttrs: TDictionary<string, string>;
    FDeclNode: TObject;
  public
    constructor Create(const AName: string; const ASymKind: string);
    destructor Destroy(); override;
    function GetSymAttr(const AKey: string): string;
    procedure SetSymAttr(const AKey: string; const AValue: string);
    function HasSymAttr(const AKey: string): Boolean;
    property SymName: string read FSymName;
    property SymKind: string read FSymKind;
    property TypeName: string read FTypeName write FTypeName;
    property DeclNode: TObject read FDeclNode write FDeclNode;
  end;

  { === TLVMSemScope ======================================================== }
  TLVMSemScope = class
  private
    FScopeName: string;
    FSymbols: TObjectDictionary<string, TLVMSymbol>;
    FParent: TLVMSemScope;
    FChildren: TObjectList<TLVMSemScope>;
  public
    constructor Create(const AName: string; const AParent: TLVMSemScope);
    destructor Destroy(); override;
    function FindChild(const AName: string): TLVMSemScope;
    procedure DeclareSymbol(const AName: string; const ASymKind: string;
      const ADeclNode: TObject = nil);
    function LookupLocal(const AName: string): TLVMSymbol;
    property ScopeName: string read FScopeName;
    property Parent: TLVMSemScope read FParent;
    property Symbols: TObjectDictionary<string, TLVMSymbol> read FSymbols;
    property Children: TObjectList<TLVMSemScope> read FChildren;
  end;

  { === TLVMScopeManager ==================================================== }
  TLVMScopeManager = class(TBaseObject)
  private
    FRoot: TLVMSemScope;
    FCurrent: TLVMSemScope;
    FScopeStateStack: TList<TLVMSemScope>;
  public
    constructor Create(); override;
    destructor Destroy(); override;
    procedure Push(const AName: string);
    procedure Pop();
    procedure Reset();
    procedure SaveState();
    procedure RestoreState();
    procedure Declare(const AName: string; const ASymKind: string;
      const ADeclNode: TObject = nil);
    function Lookup(const AName: string): TLVMSymbol;
    function LookupGlobal(const AName: string): TLVMSymbol;
    function SymbolExists(const AName: string): Boolean;
    property Current: TLVMSemScope read FCurrent;
    property Root: TLVMSemScope read FRoot;
  end;

  { TCondEntry }
  TCondEntry = record
    ParentSkipping: Boolean;
    BranchTaken: Boolean;
  end;

  { === TLVMGenericLexer ==================================================== }
  TLVMGenericLexer = class(TBaseObject)
  private
    FSource: string;
    FFilename: string;
    FPos: Integer;
    FLine: Integer;
    FCol: Integer;
    FInterp: TLangVM;

    // Conditional compilation state
    FCondStack: TList<TCondEntry>;
    FSkipping: Boolean;
    function AtEnd(): Boolean;
    function Current(): Char;
    function PeekAt(const AOffset: Integer): Char;
    function Advance(): Char;
    function MakeToken(const AKind, AText: string;
      const ALine, ACol: Integer): TLVMUserToken;
    procedure SkipWhitespace();
    function SkipComment(): Boolean;
    function TryOperator(var AToken: TLVMUserToken): Boolean;
    function TryStringLiteral(var AToken: TLVMUserToken): Boolean;
    function TryNumber(var AToken: TLVMUserToken): Boolean;
    function TryIdentifier(var AToken: TLVMUserToken): Boolean;
  public
    constructor Create(); override;
    destructor Destroy(); override;
    procedure Configure(const AInterp: TLangVM);
    function Tokenize(const ASource: string;
      const AFilename: string = ''): TList<TLVMUserToken>;
  end;

  { === TLVMGenericParser =================================================== }
  TLVMGenericParser = class(TBaseObject)
  private
    FTokens: TList<TLVMUserToken>;
    FPos: Integer;
    FFilename: string;
    FInterp: TLangVM;
  public
    constructor Create(); override;
    destructor Destroy(); override;
    procedure Configure(const AInterp: TLangVM);

    // Token navigation
    function Current(): TLVMUserToken;
    function Peek(): TLVMUserToken;
    function PeekAt(const AOffset: Integer): TLVMUserToken;
    function AtEnd(): Boolean;
    function Check(const AKind: string): Boolean;
    function Match(const AKind: string): Boolean;
    procedure DoAdvance();
    procedure Expect(const AKind: string);

    // Position save/restore
    function GetPos(): Integer;
    procedure SetPos(const APos: Integer);

    // Parsing entry points
    function ParseExpression(const AMinPower: Integer): TLVMASTNode;
    function ParseExpressionFrom(const ALeft: TLVMASTNode;
      const AMinPower: Integer): TLVMASTNode;
    function ParseStatement(): TLVMASTNode;
    function ParseProgram(const ATokens: TList<TLVMUserToken>;
      const AFilename: string = ''): TLVMASTNode;
  end;

  { === TLangVM ============================================================= }
  TLangVM = class(TBaseObject)
  private
    FBuiltins: TDictionary<string, TLVMBuiltinFunc>;
    FEnvironment: TLVMEnvironment;
    FLexer: TLVMLexer;
    FParser: TLVMParser;
    FSignal: TLVMSignal;
    FReturnValue: TLVMValue;
    FCurrentRoutineNode: TLVMASTNode;

    // pipeline block walking
    FSemanticHandlers: TLVMSemanticPassMap;
    FEmitterHandlers: TLVMHandlerMap;
    FMirHandlers: TLVMHandlerMap;
    FTargetHandlers: TDictionary<TLVMMirOpcode, TLVMASTNode>;
    FTargetContext: TLVMValue;
    FTargetContextName: string;
    FHasTarget: Boolean;
    FGrammarRules: TLVMHandlerMap;
    FPrefixRules: TDictionary<string, TLVMASTNode>;
    FInfixRules: TDictionary<string, TLVMInfixEntry>;
    FStmtRules: TObjectDictionary<string, TList<TLVMASTNode>>;
    FFragments: TLVMHandlerMap;
    FImported: TDictionary<string, Boolean>;
    FLanguageName: string;
    FLanguageVersion: string;
    FBaseDir: string;
    FImportPaths: TStringList;
    FParsedRoots: TObjectList<TLVMASTNode>;
    FRecordDefs: TObjectDictionary<string, TLVMRecordDef>;

    // Token config (from tokens {} block)
    FTokenKeywords: TDictionary<string, string>;
    FTokenOperators: TList<TLVMOperatorEntry>;
    FTokenStringStyles: TList<TLVMStringStyleEntry>;
    FTokenLineComments: TStringList;
    FTokenBlockComments: TList<TPair<string, string>>;
    FTokenDirectives: TDictionary<string, string>;
    FTokenDirectiveFlags: TDictionary<string, string>;
    FRawBlockEnds: TDictionary<string, string>;  // start kind -> end keyword text
    FTokenKindToText: TDictionary<string, string>;
    FLexerConfig: TLVMLexerConfig;

    // Conditional compilation defines
    FDefines: TDictionary<string, string>;

    // Module resolution
    FModuleExtension: string;

    // Pipeline ownership
    FUserTokenLists: TObjectList<TObject>;
    FUserASTRoots: TObjectList<TLVMASTNode>;

    // Type config (from types {} block)
    FTypeKeywords: TDictionary<string, string>;
    FTypeMappings: TDictionary<string, string>;
    FLiteralTypes: TDictionary<string, string>;
    FCompatRules: TList<TLVMCompatEntry>;
    FDeclKinds: TStringList;
    FCallKinds: TStringList;
    FCallNameAttr: string;

    // Scope manager (from semantics pipeline)
    FScopes: TLVMScopeManager;

    // MIR program (from mir {} sections)
    FMirProgram: TLVMMirProgram;

    // Dynamic MIR construction state
    FCurrentMirModule: TLVMMirModule;
    FCurrentMirFunc: TLVMMirFunc;
    FMirCallArgStack: TStack<TList<TLVMMirOperand>>;

    // Generic parser state (from grammar pipeline)
    FActiveParser: TObject;
    FResultNode: TLVMValue;
    FCurrentInfixPower: Integer;
    FRuleErrorSnapshot: Integer;

    // File I/O handle table
    FFileHandles: TDictionary<Int64, TFileStream>;
    FNextFileHandle: Int64;

    // Zig/Clang build driver
    FZigBuild: TLVMZigBuild;

    // Facade
    FOnPrint: TCallback<TLVMPrintCallback>;
    FOnDiag: TCallback<TLVMDiagCallback>;
    FLastError: string;

    // Compile phase
    FCurrentNode: TLVMValue;
    FCreatedNodes: TObjectList<TLVMASTNode>;
    FHostObjects: TDictionary<string, TObject>;
    FSharedState: TDictionary<string, TLVMValue>;
    FStateStack: TList<string>;  // SourceFilename save/restore stack
    FActiveSemanticDict: TLVMHandlerMap;
    FSemanticDictStack: TList<TLVMHandlerMap>;
    class function ParseIntLiteral(const AText: string): Int64; static;
    procedure RegisterInternalBuiltins();
    procedure RunSemanticHandler(const AUserNode: TLVMValue);
    procedure RunEmitHandler(const AUserNode: TLVMValue);
    procedure RunMirHandler(const AEvent: string; const AVars: TArray<TPair<string, TLVMValue>>);
    procedure RunTargetHandler(const AInsn: TLVMMirInsn);
    function IsMirSideEffect(const AOpcode: TLVMMirOpcode): Boolean;
    procedure MirPassDCE(const AFunc: TLVMMirFunc);
    procedure DoExecVisitStmt(const ANode: TLVMASTNode);

    // Walk helpers
    procedure WalkTokensBlock(const ANode: TLVMASTNode);
    procedure WalkTypesBlock(const ANode: TLVMASTNode);
    procedure WalkGrammarBlock(const ANode: TLVMASTNode);
    function FindTriggerToken(const ARuleAST: TLVMASTNode): string;
    function FindAllTriggerTokens(const ARuleAST: TLVMASTNode): TArray<string>;
    function ExecuteGrammarRule(const ARuleAST: TLVMASTNode;
      const ALeft: TLVMASTNode = nil): TLVMASTNode;
    {$HINTS OFF}
    function ParserCurrentToken(): TLVMUserToken;
    {$HINTS ON}
    procedure WalkSemanticsBlock(const ANode: TLVMASTNode);
    procedure WalkEmittersBlock(const ANode: TLVMASTNode);
    procedure WalkMirBlock(const ANode: TLVMASTNode);
    procedure WalkTargetBlock(const ANode: TLVMASTNode);
    procedure WalkConstBlock(const ANode: TLVMASTNode);
    procedure WalkEnumDecl(const ANode: TLVMASTNode);
    procedure WalkRoutineDecl(const ANode: TLVMASTNode);
    procedure WalkFragmentDecl(const ANode: TLVMASTNode);
    procedure WalkImport(const ANode: TLVMASTNode);
    procedure WalkInclude(const ANode: TLVMASTNode);
    procedure WalkGuardBlock(const ANode: TLVMASTNode);
    procedure WalkRecordDecl(const ANode: TLVMASTNode);

    // Well-known global environment variable accessors
    function GetExitCode(): Int64;
    procedure SetExitCode(const AValue: Int64);
    function GetSourceFilename(): string;
    procedure SetSourceFilename(const AValue: string);
    function GetZigBuild(): TLVMZigBuild;
  public
    constructor Create(); override;
    destructor Destroy(); override;
    procedure SetStatusCallback(const ACallback: TStatusCallback; const AUserData: Pointer = nil); override;
    procedure RegisterBuiltin(const AName: string; const AFunc: TLVMBuiltinFunc);
    function CallBuiltin(const AName: string; const AArgs: TArray<TLVMValue>): TLVMValue;
    function HasBuiltin(const AName: string): Boolean;
    function EvalExpr(const ANode: TLVMASTNode): TLVMValue;
    function Interpolate(const ARawText: string): string;
    function TrimCommonIndent(const AText: string): string;
    procedure ExecStmt(const ANode: TLVMASTNode);
    procedure ExecBlock(const ANode: TLVMASTNode);
    procedure WalkSource(const ARoot: TLVMASTNode);

    // load .lvm language definitions
    procedure LoadScript(const ASource: string; const AFilename: string);
    procedure LoadScriptFile(const AFilename: string);
    procedure AddImportPath(const APath: string);
    procedure Reset();

    // Host <-> VM routines
    function Call(const ARoutineName: string;
      const AArgs: array of TLVMValue): TLVMValue;
    procedure Run(const ARoutineName: string);
    function Eval(const AExpr: string): TLVMValue;
    function GetVar(const AName: string): TLVMValue;
    procedure SetVar(const AName: string; const AValue: TLVMValue);
    function HasRoutine(const AName: string): Boolean;
    function HasVar(const AName: string): Boolean;
    function TryRun(const ARoutineName: string): Boolean;
    function TryCall(const ARoutineName: string;
      const AArgs: array of TLVMValue;
      out AResult: TLVMValue): Boolean;
    procedure SetOnPrint(const ACallback: TLVMPrintCallback;
      const AUserData: Pointer);
    procedure SetOnDiag(const ACallback: TLVMDiagCallback;
      const AUserData: Pointer);
    procedure SetHostObject(const AName: string; const AObj: TObject);
    function GetHostObject(const AName: string): TObject;
    function HasHostObject(const AName: string): Boolean;
    procedure SetShared(const AKey: string; const AValue: string);
    function GetShared(const AKey: string): string;
    function HasShared(const AKey: string): Boolean;
    property LastError: string read FLastError;

    // Well-known global environment variables
    property ExitCode: Int64 read GetExitCode write SetExitCode;
    property SourceFilename: string read GetSourceFilename write SetSourceFilename;
    property ZigBuild: TLVMZigBuild read GetZigBuild;

    // Compile phase entry points
    procedure RunSemantics(const ARoot: TLVMValue);
    procedure RunEmitters(const ARoot: TLVMValue);
    procedure RunMir();
    procedure OptimizeMir();
    procedure RunGrammarRule(const AName: string);
    property CurrentNode: TLVMValue read FCurrentNode write FCurrentNode;
    property Signal: TLVMSignal read FSignal write FSignal;
    property ReturnValue: TLVMValue read FReturnValue write FReturnValue;
    property Environment: TLVMEnvironment read FEnvironment;
    property Lexer: TLVMLexer read FLexer;
    property Parser: TLVMParser read FParser;
    property SemanticHandlers: TLVMSemanticPassMap read FSemanticHandlers;
    property EmitterHandlers: TLVMHandlerMap read FEmitterHandlers;
    property MirHandlers: TLVMHandlerMap read FMirHandlers;
    property GrammarRules: TLVMHandlerMap read FGrammarRules;
    property PrefixRules: TDictionary<string, TLVMASTNode> read FPrefixRules;
    property InfixRules: TDictionary<string, TLVMInfixEntry> read FInfixRules;
    property StmtRules: TObjectDictionary<string, TList<TLVMASTNode>> read FStmtRules;
    property Fragments: TLVMHandlerMap read FFragments;
    property LanguageName: string read FLanguageName;
    property LanguageVersion: string read FLanguageVersion;
    property BaseDir: string read FBaseDir write FBaseDir;
    property ImportPaths: TStringList read FImportPaths;
    property RecordDefs: TObjectDictionary<string, TLVMRecordDef> read FRecordDefs;

    // Token config accessors
    property TokenKeywords: TDictionary<string, string> read FTokenKeywords;
    property TokenOperators: TList<TLVMOperatorEntry> read FTokenOperators;
    property TokenStringStyles: TList<TLVMStringStyleEntry> read FTokenStringStyles;
    property TokenLineComments: TStringList read FTokenLineComments;
    property TokenBlockComments: TList<TPair<string, string>> read FTokenBlockComments;
    property TokenDirectives: TDictionary<string, string> read FTokenDirectives;
    property TokenDirectiveFlags: TDictionary<string, string> read FTokenDirectiveFlags;
    property RawBlockEnds: TDictionary<string, string> read FRawBlockEnds;
    property TokenKindToText: TDictionary<string, string> read FTokenKindToText;
    property LexerConfig: TLVMLexerConfig read FLexerConfig;
    property Defines: TDictionary<string, string> read FDefines;
    property ModuleExtension: string read FModuleExtension write FModuleExtension;

    // Type config accessors
    property TypeKeywords: TDictionary<string, string> read FTypeKeywords;
    property TypeMappings: TDictionary<string, string> read FTypeMappings;
    property LiteralTypes: TDictionary<string, string> read FLiteralTypes;
    property CompatRules: TList<TLVMCompatEntry> read FCompatRules;
    property DeclKinds: TStringList read FDeclKinds;
    property CallKinds: TStringList read FCallKinds;
    property CallNameAttr: string read FCallNameAttr;
    property Scopes: TLVMScopeManager read FScopes;
    property MirProgram: TLVMMirProgram read FMirProgram;
    procedure SetActiveParser(const AParser: TObject);
    function GetActiveParser(): TObject;
    property ResultNode: TLVMValue read FResultNode write FResultNode;
    property CurrentInfixPower: Integer read FCurrentInfixPower write FCurrentInfixPower;
    property RuleErrorSnapshot: Integer read FRuleErrorSnapshot write FRuleErrorSnapshot;
  end;

{ === MIR mapping functions ================================================= }
function MirTypeToStr(const AType: TLVMMirType): string;
function MirStrToType(const AName: string; out AType: TLVMMirType): Boolean;
function MirOpcodeToStr(const AOpcode: TLVMMirOpcode): string;
function MirStrToOpcode(const AName: string; out AOpcode: TLVMMirOpcode): Boolean;
function MirOperandToValue(const AOperand: TLVMMirOperand): TLVMValue;

implementation

const
  // LVM Error Codes
  ERR_LVM_LEX = 'LVM001';
  ERR_LVM_PARSE = 'LVM002';
  ERR_LVM_BUILTIN = 'LVM003';
  ERR_LVM_ASSERT = 'LVM004';
  ERR_LVM_USER = 'LVM005';
  ERR_LVM_CALL = 'LVM006';
  ERR_LVM_TYPE = 'LVM007';
  ERR_LVM_GRAMMAR = 'LVM008';
  ERR_LVM_REDECLARE = 'LVM009';
  ERR_LVM_UNDECLARED = 'LVM010';
  ERR_LVM_ASSIGN = 'LVM011';
  ERR_LVM_FIELD = 'LVM012';
  ERR_LVM_INDEX = 'LVM013';
  ERR_LVM_LIMIT = 'LVM014';
  ERR_LVM_ITERATION = 'LVM015';
  ERR_LVM_RETURN = 'LVM016';
  ERR_LVM_UNDEFINED = 'LVM017';
  ERR_LVM_OPERATOR = 'LVM018';
  ERR_LVM_LAYOUT = 'LVM019';
  ERR_LVM_VISIT = 'LVM020';
  ERR_LVM_IMPORT = 'LVM021';
  ERR_LVM_TOPLEVEL = 'LVM022';
  ERR_LVM_TARGET = 'LVM023';


{ === TLVMValue ============================================================= }
class function TLVMValue.Nil_(): TLVMValue;
begin
  Result := Default(TLVMValue);
  Result.FKind := vkNil;
end;

class function TLVMValue.FromInt(const AValue: Int64): TLVMValue;
begin
  Result := Default(TLVMValue);
  Result.FKind := vkInt;
  Result.FInt := AValue;
end;

class function TLVMValue.FromFloat(const AValue: Double): TLVMValue;
begin
  Result := Default(TLVMValue);
  Result.FKind := vkFloat;
  Result.FFloat := AValue;
end;

class function TLVMValue.FromBool(const AValue: Boolean): TLVMValue;
begin
  Result := Default(TLVMValue);
  Result.FKind := vkBool;
  Result.FBool := AValue;
end;

class function TLVMValue.FromString(const AValue: string): TLVMValue;
begin
  Result := Default(TLVMValue);
  Result.FKind := vkString;
  Result.FStr := AValue;
end;

class function TLVMValue.FromHandle(const AValue: Pointer): TLVMValue;
begin
  Result := Default(TLVMValue);
  Result.FKind := vkHandle;
  Result.FHandle := AValue;
end;

class function TLVMValue.FromList(): TLVMValue;
begin
  Result := Default(TLVMValue);
  Result.FKind := vkList;
  Result.FList := TLVMListRef.Create();
end;

class function TLVMValue.FromArray(const AValues: TArray<TLVMValue>): TLVMValue;
var
  LI: Integer;
begin
  Result := Default(TLVMValue);
  Result.FKind := vkList;
  Result.FList := TLVMListRef.Create();
  for LI := 0 to Length(AValues) - 1 do
    Result.FList.Store.Add(AValues[LI]);
end;

class function TLVMValue.FromMap(): TLVMValue;
begin
  Result := Default(TLVMValue);
  Result.FKind := vkMap;
  Result.FMap := TLVMMapRef.Create();
end;

class function TLVMValue.FromRoutine(const ANode: Pointer): TLVMValue;
begin
  Result := Default(TLVMValue);
  Result.FKind := vkRoutine;
  Result.FRoutine := ANode;
end;

class function TLVMValue.FromBuffer(const ASize: Integer;
  const AExecutable: Boolean): TLVMValue;
begin
  Result := Default(TLVMValue);
  Result.FKind := vkBuffer;
  Result.FBuffer := TLVMBufferRef.Create(ASize, AExecutable);
end;

class function TLVMValue.FromBuffer(
  const AStore: TVirtualMemory<Byte>): TLVMValue;
begin
  Result := Default(TLVMValue);
  Result.FKind := vkBuffer;
  Result.FBuffer := TLVMBufferRef.Create(AStore);
end;

function TLVMValue.AsInt(): Int64;
begin
  if FKind <> vkInt then
    raise Exception.CreateFmt('Expected int, got %s', [KindName()]);
  Result := FInt;
end;

function TLVMValue.AsFloat(): Double;
begin
  if FKind = vkInt then
    Result := FInt
  else if FKind = vkFloat then
    Result := FFloat
  else
    raise Exception.CreateFmt('Expected float, got %s', [KindName()]);
end;

function TLVMValue.AsBool(): Boolean;
begin
  if FKind <> vkBool then
    raise Exception.CreateFmt('Expected bool, got %s', [KindName()]);
  Result := FBool;
end;

function TLVMValue.AsString(): string;
begin
  if FKind <> vkString then
    raise Exception.CreateFmt('Expected string, got %s', [KindName()]);
  Result := FStr;
end;

function TLVMValue.AsHandle(): Pointer;
begin
  if FKind <> vkHandle then
    raise Exception.CreateFmt('Expected handle, got %s', [KindName()]);
  Result := FHandle;
end;

function TLVMValue.AsList(): TLVMListStore;
begin
  if FKind <> vkList then
    raise Exception.CreateFmt('Expected list, got %s', [KindName()]);
  Result := FList.Store;
end;

function TLVMValue.AsMap(): TLVMMapStore;
begin
  if FKind <> vkMap then
    raise Exception.CreateFmt('Expected map, got %s', [KindName()]);
  Result := FMap.Store;
end;

function TLVMValue.AsRoutine(): Pointer;
begin
  if FKind <> vkRoutine then
    raise Exception.CreateFmt('Expected routine, got %s', [KindName()]);
  Result := FRoutine;
end;

function TLVMValue.AsBuffer(): TVirtualMemory<Byte>;
begin
  if FKind <> vkBuffer then
    raise Exception.CreateFmt('Expected buffer, got %s', [KindName()]);
  Result := FBuffer.Store;
end;

function TLVMValue.IsNil(): Boolean;
begin
  Result := FKind = vkNil;
end;

function TLVMValue.IsTrue(): Boolean;
begin
  case FKind of
    vkNil:    Result := False;
    vkBool:   Result := FBool;
    vkInt:    Result := FInt <> 0;
    vkFloat:  Result := FFloat <> 0.0;
    vkString: Result := FStr <> '';
  else
    Result := True;  // handles, lists, maps, routines are truthy
  end;
end;

function TLVMValue.ToString(): string;
begin
  case FKind of
    vkNil:     Result := 'nil';
    vkInt:     Result := IntToStr(FInt);
    vkFloat:   Result := FloatToStr(FFloat);
    vkBool:    if FBool then Result := 'true' else Result := 'false';
    vkString:  Result := FStr;
    vkHandle:  Result := Format('handle(%p)', [FHandle]);
    vkList:    Result := Format('list(%d)', [FList.Store.Count]);
    vkMap:     Result := Format('map(%d)', [FMap.Store.Count]);
    vkRoutine: Result := Format('routine(%p)', [FRoutine]);
    vkBuffer:  Result := Format('<buffer:%d>', [FBuffer.Store.Capacity]);
  else
    Result := '?';
  end;
end;

function TLVMValue.KindName(): string;
begin
  case FKind of
    vkNil:     Result := 'nil';
    vkInt:     Result := 'int';
    vkFloat:   Result := 'float';
    vkBool:    Result := 'bool';
    vkString:  Result := 'string';
    vkHandle:  Result := 'handle';
    vkList:    Result := 'list';
    vkMap:     Result := 'map';
    vkRoutine: Result := 'routine';
    vkBuffer:  Result := 'buffer';
  else
    Result := 'unknown';
  end;
end;

{ TLVMValue.IsValidTypeName }
class function TLVMValue.IsValidTypeName(const AName: string): Boolean;
begin
  Result := (AName = 'int') or (AName = 'float') or (AName = 'bool') or
            (AName = 'string') or (AName = 'handle') or (AName = 'list') or
            (AName = 'map') or (AName = 'routine') or (AName = 'buffer') or
            (AName = 'any');
end;

{ TLVMValue.KindMatchesType }
class function TLVMValue.KindMatchesType(const AValue: TLVMValue;
  const ATypeName: string): Boolean;
begin
  if ATypeName = 'any' then Exit(True);
  if AValue.FKind = vkNil then Exit(True);  // nil is valid for any type
  // Enum values are stored as vkString with FTypeName set to the enum name.
  // Accept if the value's declared type matches the expected type.
  if (AValue.FTypeName <> '') and (AValue.FTypeName = ATypeName) then
    Exit(True);
  case AValue.FKind of
    vkInt:     Result := ATypeName = 'int';
    vkFloat:   Result := ATypeName = 'float';
    vkBool:    Result := ATypeName = 'bool';
    vkString:  Result := ATypeName = 'string';
    vkHandle:  Result := ATypeName = 'handle';
    vkList:    Result := ATypeName = 'list';
    vkMap:     Result := ATypeName = 'map';
    vkRoutine: Result := ATypeName = 'routine';
    vkBuffer:  Result := ATypeName = 'buffer';
  else
    Result := False;
  end;
end;

{ === TLVMListRef =========================================================== }
constructor TLVMListRef.Create();
begin
  inherited Create();
  FStore := TLVMListStore.Create();
end;

destructor TLVMListRef.Destroy();
begin
  FStore.Free();
  inherited Destroy();
end;

function TLVMListRef.GetStore(): TLVMListStore;
begin
  Result := FStore;
end;

{ === TLVMMapRef ============================================================= }

constructor TLVMMapRef.Create();
begin
  inherited Create();
  FStore := TLVMMapStore.Create();
end;

destructor TLVMMapRef.Destroy();
begin
  FStore.Free();
  inherited Destroy();
end;

function TLVMMapRef.GetStore(): TLVMMapStore;
begin
  Result := FStore;
end;

{ === TLVMBufferRef ========================================================= }
constructor TLVMBufferRef.Create(const ASize: Integer;
  const AExecutable: Boolean);
begin
  inherited Create();
  FIsExecutable := AExecutable;
  FStore := TVirtualMemory<Byte>.Create();
  FStore.Allocate(UInt64(ASize), '', AExecutable);
end;

constructor TLVMBufferRef.Create(const AStore: TVirtualMemory<Byte>);
begin
  inherited Create();
  FIsExecutable := False;
  FStore := AStore;
end;

destructor TLVMBufferRef.Destroy();
begin
  FStore.Free();
  inherited Destroy();
end;

function TLVMBufferRef.GetStore(): TVirtualMemory<Byte>;
begin
  Result := FStore;
end;

function TLVMBufferRef.GetIsExecutable(): Boolean;
begin
  Result := FIsExecutable;
end;

{ === TLVMRecordDef ========================================================= }
constructor TLVMRecordDef.Create(const AName: string);
begin
  inherited Create();
  FName := AName;
  FFieldNames := TList<string>.Create();
  FFieldDefaults := TDictionary<string, TLVMValue>.Create();
  FIsLayout := False;
  FFieldSizes := TDictionary<string, Integer>.Create();
  FFieldOffsets := TDictionary<string, Integer>.Create();
  FTotalSize := 0;
end;

destructor TLVMRecordDef.Destroy();
begin
  FFieldOffsets.Free();
  FFieldSizes.Free();
  FFieldDefaults.Free();
  FFieldNames.Free();
  inherited Destroy();
end;

procedure TLVMRecordDef.AddField(const AName: string; const ADefault: TLVMValue);
begin
  FFieldNames.Add(AName);
  FFieldDefaults.AddOrSetValue(AName, ADefault);
end;

procedure TLVMRecordDef.AddLayoutField(const AName: string;
  const AByteSize: Integer; const ADefault: TLVMValue);
begin
  FIsLayout := True;
  FFieldNames.Add(AName);
  FFieldDefaults.AddOrSetValue(AName, ADefault);
  FFieldSizes.AddOrSetValue(AName, AByteSize);
  FFieldOffsets.AddOrSetValue(AName, FTotalSize);
  FTotalSize := FTotalSize + AByteSize;
end;

function TLVMRecordDef.HasField(const AName: string): Boolean;
begin
  Result := FFieldDefaults.ContainsKey(AName);
end;

function TLVMRecordDef.CreateInstance(): TLVMValue;
var
  LI: Integer;
  LFieldName: string;
begin
  Result := TLVMValue.FromMap();
  Result.AsMap().TypeName := FName;
  for LI := 0 to FFieldNames.Count - 1 do
  begin
    LFieldName := FFieldNames[LI];
    Result.AsMap().AddOrSetValue(LFieldName, FFieldDefaults[LFieldName]);
  end;
end;

{ === TLVMLexer ============================================================= }
constructor TLVMLexer.Create();
begin
  inherited Create();
  FTokens := TList<TLVMToken>.Create();
  FKeywords := TDictionary<string, TLVMTokenKind>.Create();
  InitKeywords();
end;

destructor TLVMLexer.Destroy();
begin
  FKeywords.Free();
  FTokens.Free();
  inherited Destroy();
end;

procedure TLVMLexer.InitKeywords();
begin
  // Language structure
  FKeywords.Add('language', tkLanguage);
  FKeywords.Add('version', tkVersion);
  FKeywords.Add('tokens', tkTokens);
  FKeywords.Add('types', tkTypes);
  FKeywords.Add('grammar', tkGrammar);
  FKeywords.Add('semantics', tkSemantics);
  FKeywords.Add('emitters', tkEmitters);
  FKeywords.Add('mir', tkMir);
  FKeywords.Add('rule', tkRule);
  FKeywords.Add('on', tkOn);
  FKeywords.Add('token', tkToken);
  FKeywords.Add('type', tkType);
  FKeywords.Add('map', tkMap);
  FKeywords.Add('literal', tkLiteral);
  FKeywords.Add('compatible', tkCompatible);
  FKeywords.Add('decl_kind', tkDeclKind);
  FKeywords.Add('call_kind', tkCallKind);
  FKeywords.Add('call_name_attr', tkCallNameAttr);
  FKeywords.Add('precedence', tkPrecedence);
  FKeywords.Add('left', tkLeft);
  FKeywords.Add('right', tkRight);
  FKeywords.Add('pass', tkPass);
  FKeywords.Add('section', tkSection);

  // Control flow
  FKeywords.Add('let', tkLet);
  FKeywords.Add('const', tkConst);
  FKeywords.Add('enum', tkEnum);
  FKeywords.Add('routine', tkRoutine);
  FKeywords.Add('fragment', tkFragment);
  FKeywords.Add('record', tkRecord);
  FKeywords.Add('extends', tkExtends);
  FKeywords.Add('layout', tkLayout);
  FKeywords.Add('import', tkImport);
  FKeywords.Add('include', tkInclude);
  FKeywords.Add('guard', tkGuard);
  FKeywords.Add('if', tkIf);
  FKeywords.Add('else', tkElse);
  FKeywords.Add('while', tkWhile);
  FKeywords.Add('for', tkFor);
  FKeywords.Add('in', tkIn);
  FKeywords.Add('break', tkBreak);
  FKeywords.Add('continue', tkContinue);
  FKeywords.Add('return', tkReturn);
  FKeywords.Add('match', tkMatch);
  FKeywords.Add('try', tkTry);
  FKeywords.Add('recover', tkRecover);

  // Declarative / pipeline
  FKeywords.Add('optional', tkOptional);
  FKeywords.Add('sync', tkSync);
  FKeywords.Add('expect', tkExpect);
  FKeywords.Add('consume', tkConsume);
  FKeywords.Add('parse', tkParse);
  FKeywords.Add('many', tkMany);
  FKeywords.Add('until', tkUntil);
  FKeywords.Add('scope', tkScope);
  FKeywords.Add('declare', tkDeclare);
  FKeywords.Add('visit', tkVisit);
  FKeywords.Add('lookup', tkLookup);
  FKeywords.Add('children', tkChildren);
  FKeywords.Add('child', tkChild);
  FKeywords.Add('as', tkAs);
  FKeywords.Add('typed', tkTyped);

  // Diagnostics
  FKeywords.Add('error', tkError);
  FKeywords.Add('warning', tkWarning);
  FKeywords.Add('hint', tkHint);
  FKeywords.Add('note', tkNote);
  FKeywords.Add('info', tkInfo);

  // Logical
  FKeywords.Add('and', tkAnd);
  FKeywords.Add('or', tkOr);
  FKeywords.Add('not', tkNot);

  // Bitwise shift
  FKeywords.Add('shl', tkShl);
  FKeywords.Add('shr', tkShr);

  // Literal keywords
  FKeywords.Add('true', tkTrue);
  FKeywords.Add('false', tkFalse);
  FKeywords.Add('nil', tkNil);
end;

procedure TLVMLexer.AddToken(const AKind: TLVMTokenKind; const AText: string;
  const ALine, ACol: Integer);
var
  LToken: TLVMToken;
begin
  LToken.Kind := AKind;
  LToken.Text := AText;
  LToken.Line := ALine;
  LToken.Col := ACol;
  FTokens.Add(LToken);
end;

procedure TLVMLexer.LexError(const ALine, ACol: Integer; const AMsg: string);
begin
  GetErrors().Add(FFilename, ALine, ACol, esError, ERR_LVM_LEX, AMsg);
end;

procedure TLVMLexer.LexError(const ALine, ACol: Integer; const AMsg: string;
  const AArgs: array of const);
begin
  GetErrors().Add(FFilename, ALine, ACol, esError, ERR_LVM_LEX, AMsg, AArgs);
end;

function TLVMLexer.Peek(): Char;
begin
  if FPos <= Length(FSource) then
    Result := FSource[FPos]
  else
    Result := #0;
end;

function TLVMLexer.PeekAt(const AOffset: Integer): Char;
var
  LIdx: Integer;
begin
  LIdx := FPos + AOffset;
  if (LIdx >= 1) and (LIdx <= Length(FSource)) then
    Result := FSource[LIdx]
  else
    Result := #0;
end;

function TLVMLexer.Advance(): Char;
begin
  Result := Peek();
  if Result = #10 then
  begin
    Inc(FLine);
    FCol := 1;
  end
  else
    Inc(FCol);
  Inc(FPos);
end;

function TLVMLexer.IsAtEnd(): Boolean;
begin
  Result := FPos > Length(FSource);
end;

function TLVMLexer.IsDigit(const ACh: Char): Boolean;
begin
  Result := (ACh >= '0') and (ACh <= '9');
end;

function TLVMLexer.IsAlpha(const ACh: Char): Boolean;
begin
  Result := ((ACh >= 'A') and (ACh <= 'Z'))
         or ((ACh >= 'a') and (ACh <= 'z'))
         or (ACh = '_');
end;

function TLVMLexer.IsAlphaNum(const ACh: Char): Boolean;
begin
  Result := IsAlpha(ACh) or IsDigit(ACh);
end;

procedure TLVMLexer.SkipWhitespace();
begin
  while not IsAtEnd() do
  begin
    case Peek() of
      ' ', #9, #13, #10:
        Advance();
    else
      Break;
    end;
  end;
end;

procedure TLVMLexer.SkipLineComment();
begin
  // Skip past '//'
  Advance();
  Advance();
  while (not IsAtEnd()) and (Peek() <> #10) do
    Advance();
end;

procedure TLVMLexer.SkipBlockComment();
begin
  // Skip past '/*'
  Advance();
  Advance();
  while not IsAtEnd() do
  begin
    if (Peek() = '*') and (PeekAt(1) = '/') then
    begin
      Advance(); // *
      Advance(); // /
      Exit;
    end;
    Advance();
  end;
  // Unterminated block comment -- let parser deal with it
end;

procedure TLVMLexer.ScanNumber();
var
  LStart: Integer;
  LStartCol: Integer;
  LStartLine: Integer;
  LIsFloat: Boolean;
  LText: string;
begin
  LStart := FPos;
  LStartCol := FCol;
  LStartLine := FLine;
  LIsFloat := False;

  // Check for hex prefix
  if (Peek() = '0') and (PeekAt(1) = 'x') then
  begin
    Advance(); // 0
    Advance(); // x
    while (not IsAtEnd()) and (CharInSet(Peek(), ['0'..'9', 'a'..'f', 'A'..'F'])) do
      Advance();
    LText := Copy(FSource, LStart, FPos - LStart);
    AddToken(tkIntLit, LText, LStartLine, LStartCol);
    Exit;
  end;

  // Check for binary prefix
  if (Peek() = '0') and (PeekAt(1) = 'b') then
  begin
    Advance(); // 0
    Advance(); // b
    while (not IsAtEnd()) and CharInSet(Peek(), ['0', '1']) do
      Advance();
    LText := Copy(FSource, LStart, FPos - LStart);
    AddToken(tkIntLit, LText, LStartLine, LStartCol);
    Exit;
  end;

  // Decimal digits
  while (not IsAtEnd()) and IsDigit(Peek()) do
    Advance();

  // Check for float
  if (Peek() = '.') and IsDigit(PeekAt(1)) then
  begin
    LIsFloat := True;
    Advance(); // .
    while (not IsAtEnd()) and IsDigit(Peek()) do
      Advance();
  end;

  LText := Copy(FSource, LStart, FPos - LStart);
  if LIsFloat then
    AddToken(tkFloatLit, LText, LStartLine, LStartCol)
  else
    AddToken(tkIntLit, LText, LStartLine, LStartCol);
end;

procedure TLVMLexer.ScanString();
var
  LStartCol: Integer;
  LStartLine: Integer;
  LBuf: TStringBuilder;
  LCh: Char;
begin
  LStartCol := FCol;
  LStartLine := FLine;

  // Check for triple-quoted string
  if (PeekAt(1) = '"') and (PeekAt(2) = '"') then
  begin
    ScanTripleQuoteString();
    Exit;
  end;

  Advance(); // opening "
  LBuf := TStringBuilder.Create();
  try
    while (not IsAtEnd()) and (Peek() <> '"') do
    begin
      if Peek() = '\' then
      begin
        Advance(); // backslash
        if IsAtEnd() then
          Break;
        LCh := Advance();
        case LCh of
          'n':  LBuf.Append(#10);
          't':  LBuf.Append(#9);
          'r':  LBuf.Append(#13);
          '0':  LBuf.Append(#0);
          '\':  LBuf.Append('\');
          '"':  LBuf.Append('"');
          '{':  LBuf.Append('{');
          '}':  LBuf.Append('}');
        else
          // Unknown escape -- keep as-is
          LBuf.Append('\');
          LBuf.Append(LCh);
        end;
      end
      else if Peek() = '{' then
      begin
        // String interpolation: emit segment so far, then interp tokens
        if LBuf.Length > 0 then
          AddToken(tkStringLit, LBuf.ToString(), LStartLine, LStartCol);
        LBuf.Clear();
        AddToken(tkLBrace, '{', FLine, FCol);
        Advance(); // {

        // Scan tokens inside the interpolation until matching }
        ScanInterpolationBody();

        AddToken(tkRBrace, '}', FLine, FCol);
        Advance(); // }
        LStartCol := FCol;
        LStartLine := FLine;
      end
      else
        LBuf.Append(Advance());
    end;

    if not IsAtEnd() then
      Advance(); // closing "

    // Emit final string segment
    AddToken(tkStringLit, LBuf.ToString(), LStartLine, LStartCol);
  finally
    LBuf.Free();
  end;
end;

procedure TLVMLexer.ScanInterpolationBody();
var
  LDepth: Integer;
  LCh: Char;
  LStartCol: Integer;
  LStartLine: Integer;
begin
  // Scan tokens until we hit the matching } at depth 0
  // This handles nested braces in expressions like {items[0]}
  LDepth := 0;
  while not IsAtEnd() do
  begin
    SkipWhitespace();
    if IsAtEnd() then
      Break;

    LCh := Peek();

    // End of interpolation
    if (LCh = '}') and (LDepth = 0) then
      Exit;

    LStartCol := FCol;
    LStartLine := FLine;

    // Track brace nesting
    if LCh = '{' then
    begin
      Inc(LDepth);
      Advance();
      AddToken(tkLBrace, '{', LStartLine, LStartCol);
      Continue;
    end;

    if LCh = '}' then
    begin
      Dec(LDepth);
      Advance();
      AddToken(tkRBrace, '}', LStartLine, LStartCol);
      Continue;
    end;

    // @ for attribute access
    if LCh = '@' then
    begin
      Advance();
      AddToken(tkAt, '@', LStartLine, LStartCol);
      Continue;
    end;

    // Numbers
    if IsDigit(LCh) then
    begin
      ScanNumber();
      Continue;
    end;

    // Identifiers/keywords
    if IsAlpha(LCh) then
    begin
      ScanIdentifier();
      Continue;
    end;

    // Basic operators inside interpolation
    Advance();
    case LCh of
      '+': AddToken(tkPlus, '+', LStartLine, LStartCol);
      '-': AddToken(tkMinus, '-', LStartLine, LStartCol);
      '*': AddToken(tkStar, '*', LStartLine, LStartCol);
      '/': AddToken(tkSlash, '/', LStartLine, LStartCol);
      '(': AddToken(tkLParen, '(', LStartLine, LStartCol);
      ')': AddToken(tkRParen, ')', LStartLine, LStartCol);
      '[': AddToken(tkLBracket, '[', LStartLine, LStartCol);
      ']': AddToken(tkRBracket, ']', LStartLine, LStartCol);
      ',': AddToken(tkComma, ',', LStartLine, LStartCol);
      '.': AddToken(tkDot, '.', LStartLine, LStartCol);
    end;
  end;
end;

procedure TLVMLexer.ScanSingleQuoteString();
var
  LStartCol: Integer;
  LStartLine: Integer;
  LBuf: TStringBuilder;
begin
  LStartCol := FCol;
  LStartLine := FLine;
  Advance(); // opening '
  LBuf := TStringBuilder.Create();
  try
    while (not IsAtEnd()) and (Peek() <> '''') do
      LBuf.Append(Advance());

    if not IsAtEnd() then
      Advance(); // closing '

    AddToken(tkStringLit, LBuf.ToString(), LStartLine, LStartCol);
  finally
    LBuf.Free();
  end;
end;

procedure TLVMLexer.ScanTripleQuoteString();
var
  LStartCol: Integer;
  LStartLine: Integer;
  LBuf: TStringBuilder;
  LRaw: string;
  LLines: TArray<string>;
  LMinIndent: Integer;
  LI: Integer;
  LJ: Integer;
  LTrimmed: string;
begin
  LStartCol := FCol;
  LStartLine := FLine;

  // Skip opening """
  Advance();
  Advance();
  Advance();

  // Skip optional newline immediately after opening """
  if (not IsAtEnd()) and (Peek() = #13) then
    Advance();
  if (not IsAtEnd()) and (Peek() = #10) then
    Advance();

  LBuf := TStringBuilder.Create();
  try
    while not IsAtEnd() do
    begin
      if (Peek() = '"') and (PeekAt(1) = '"') and (PeekAt(2) = '"') then
      begin
        Advance(); // "
        Advance(); // "
        Advance(); // "
        Break;
      end;
      LBuf.Append(Advance());
    end;

    LRaw := LBuf.ToString();
  finally
    LBuf.Free();
  end;

  // Trim common leading whitespace (indent trimming)
  LLines := LRaw.Split([#10]);

  // Find minimum indent among non-empty lines
  LMinIndent := MaxInt;
  for LI := 0 to High(LLines) do
  begin
    if LLines[LI].Trim() = '' then
      Continue;
    LJ := 0;
    while (LJ < Length(LLines[LI])) and (LLines[LI].Chars[LJ] = ' ') do
      Inc(LJ);
    if LJ < LMinIndent then
      LMinIndent := LJ;
  end;

  if LMinIndent = MaxInt then
    LMinIndent := 0;

  // Remove common indent and rejoin
  LBuf := TStringBuilder.Create();
  try
    for LI := 0 to High(LLines) do
    begin
      if LI > 0 then
        LBuf.Append(#10);
      if LLines[LI].Trim() = '' then
        LBuf.Append('')
      else
      begin
        LTrimmed := Copy(LLines[LI], LMinIndent + 1, Length(LLines[LI]) - LMinIndent);
        LBuf.Append(LTrimmed);
      end;
    end;

    // Remove trailing newline if present
    LRaw := LBuf.ToString();
    if LRaw.EndsWith(#10) then
      LRaw := Copy(LRaw, 1, Length(LRaw) - 1);

    AddToken(tkTripleStringLit, LRaw, LStartLine, LStartCol);
  finally
    LBuf.Free();
  end;
end;

procedure TLVMLexer.ScanIdentifier();
var
  LStart: Integer;
  LStartCol: Integer;
  LStartLine: Integer;
  LText: string;
  LKind: TLVMTokenKind;
begin
  LStart := FPos;
  LStartCol := FCol;
  LStartLine := FLine;

  while (not IsAtEnd()) and IsAlphaNum(Peek()) do
    Advance();

  LText := Copy(FSource, LStart, FPos - LStart);

  if FKeywords.TryGetValue(LText, LKind) then
    AddToken(LKind, LText, LStartLine, LStartCol)
  else
    AddToken(tkIdentifier, LText, LStartLine, LStartCol);
end;

function TLVMLexer.Tokenize(const ASource, AFilename: string): TArray<TLVMToken>;
var
  LCh: Char;
  LStartCol: Integer;
  LStartLine: Integer;
begin
  FSource := ASource;
  FFilename := AFilename;
  FPos := 1;
  FLine := 1;
  FCol := 1;
  FTokens.Clear();

  while not IsAtEnd() do
  begin
    SkipWhitespace();
    if IsAtEnd() then
      Break;

    LStartCol := FCol;
    LStartLine := FLine;
    LCh := Peek();

    // Line comment
    if (LCh = '/') and (PeekAt(1) = '/') then
    begin
      SkipLineComment();
      Continue;
    end;

    // Block comment
    if (LCh = '/') and (PeekAt(1) = '*') then
    begin
      SkipBlockComment();
      Continue;
    end;

    // Numbers
    if IsDigit(LCh) then
    begin
      ScanNumber();
      Continue;
    end;

    // Double-quoted strings (with interpolation and escapes)
    if LCh = '"' then
    begin
      ScanString();
      Continue;
    end;

    // Single-quoted strings (no escapes)
    if LCh = '''' then
    begin
      ScanSingleQuoteString();
      Continue;
    end;

    // Identifiers and keywords
    if IsAlpha(LCh) then
    begin
      ScanIdentifier();
      Continue;
    end;

    // Two-character operators
    case LCh of
      '=':
      begin
        if PeekAt(1) = '=' then
        begin
          Advance(); Advance();
          AddToken(tkEqEq, '==', LStartLine, LStartCol);
          Continue;
        end
        else if PeekAt(1) = '>' then
        begin
          Advance(); Advance();
          AddToken(tkFatArrow, '=>', LStartLine, LStartCol);
          Continue;
        end;
      end;
      '!':
      begin
        if PeekAt(1) = '=' then
        begin
          Advance(); Advance();
          AddToken(tkNeq, '!=', LStartLine, LStartCol);
          Continue;
        end;
      end;
      '<':
      begin
        if PeekAt(1) = '=' then
        begin
          Advance(); Advance();
          AddToken(tkLe, '<=', LStartLine, LStartCol);
          Continue;
        end;
      end;
      '>':
      begin
        if PeekAt(1) = '=' then
        begin
          Advance(); Advance();
          AddToken(tkGe, '>=', LStartLine, LStartCol);
          Continue;
        end;
      end;
      '-':
      begin
        if PeekAt(1) = '>' then
        begin
          Advance(); Advance();
          AddToken(tkArrow, '->', LStartLine, LStartCol);
          Continue;
        end;
      end;
      '.':
      begin
        if PeekAt(1) = '.' then
        begin
          Advance(); Advance();
          AddToken(tkDotDot, '..', LStartLine, LStartCol);
          Continue;
        end;
      end;
    end;

    // Single-character tokens
    Advance();
    case LCh of
      '+': AddToken(tkPlus, '+', LStartLine, LStartCol);
      '-': AddToken(tkMinus, '-', LStartLine, LStartCol);
      '*': AddToken(tkStar, '*', LStartLine, LStartCol);
      '/': AddToken(tkSlash, '/', LStartLine, LStartCol);
      '%': AddToken(tkPercent, '%', LStartLine, LStartCol);
      '<': AddToken(tkLt, '<', LStartLine, LStartCol);
      '>': AddToken(tkGt, '>', LStartLine, LStartCol);
      '=': AddToken(tkAssign, '=', LStartLine, LStartCol);
      '(': AddToken(tkLParen, '(', LStartLine, LStartCol);
      ')': AddToken(tkRParen, ')', LStartLine, LStartCol);
      '[': AddToken(tkLBracket, '[', LStartLine, LStartCol);
      ']': AddToken(tkRBracket, ']', LStartLine, LStartCol);
      '{': AddToken(tkLBrace, '{', LStartLine, LStartCol);
      '}': AddToken(tkRBrace, '}', LStartLine, LStartCol);
      ';': AddToken(tkSemicolon, ';', LStartLine, LStartCol);
      ',': AddToken(tkComma, ',', LStartLine, LStartCol);
      '.': AddToken(tkDot, '.', LStartLine, LStartCol);
      ':': AddToken(tkColon, ':', LStartLine, LStartCol);
      '|': AddToken(tkPipe, '|', LStartLine, LStartCol);
      '@': AddToken(tkAt, '@', LStartLine, LStartCol);
    else
      // Unknown character -- skip silently
    end;
  end;

  AddToken(tkEOF, '', FLine, FCol);
  Result := FTokens.ToArray();
end;

{ === TLVMASTNode =========================================================== }
constructor TLVMASTNode.Create();
begin
  inherited Create();
  FKind := '';
  FAttrs := TDictionary<string, string>.Create();
  FChildren := TObjectList<TLVMASTNode>.Create(True);
  FParent := nil;
  FLine := 0;
  FCol := 0;
  FFilename := '';
end;

destructor TLVMASTNode.Destroy();
begin
  FChildren.Free();
  FAttrs.Free();
  inherited Destroy();
end;

procedure TLVMASTNode.SetAttr(const AKey, AValue: string);
begin
  FAttrs.AddOrSetValue(AKey, AValue);
end;

function TLVMASTNode.GetAttr(const AKey: string): string;
begin
  if not FAttrs.TryGetValue(AKey, Result) then
    Result := '';
end;

function TLVMASTNode.HasAttr(const AKey: string): Boolean;
begin
  Result := FAttrs.ContainsKey(AKey);
end;

function TLVMASTNode.AddChild(const AChild: TLVMASTNode): TLVMASTNode;
begin
  AChild.FParent := Self;
  FChildren.Add(AChild);
  Result := AChild;
end;

function TLVMASTNode.ChildCount(): Integer;
begin
  Result := FChildren.Count;
end;

{ === TLVMParser ============================================================ }
constructor TLVMParser.Create();
begin
  inherited Create();
  FPos := 0;
  FFilename := '';
  FAllNodes := TList<TLVMASTNode>.Create();
  FUserTypeNames := TDictionary<string, Boolean>.Create();
end;

destructor TLVMParser.Destroy();
begin
  FUserTypeNames.Free();
  FAllNodes.Free();
  inherited Destroy();
end;

function TLVMParser.Peek(): TLVMToken;
begin
  Result := FTokens[FPos];
end;

function TLVMParser.PeekKind(): TLVMTokenKind;
begin
  Result := FTokens[FPos].Kind;
end;

function TLVMParser.Advance(): TLVMToken;
begin
  Result := FTokens[FPos];
  if FTokens[FPos].Kind <> tkEOF then
    Inc(FPos);
end;

function TLVMParser.Match(const AKind: TLVMTokenKind): Boolean;
begin
  if FTokens[FPos].Kind = AKind then
  begin
    Advance();
    Result := True;
  end
  else
    Result := False;
end;

function TLVMParser.Check(const AKind: TLVMTokenKind): Boolean;
begin
  Result := FTokens[FPos].Kind = AKind;
end;

function TLVMParser.Expect(const AKind: TLVMTokenKind): TLVMToken;
begin
  if FTokens[FPos].Kind = AKind then
    Result := Advance()
  else
    ParseError(FTokens[FPos], 'Expected %s but found "%s"',
      [GetEnumName(TypeInfo(TLVMTokenKind), Ord(AKind)), FTokens[FPos].Text]);
end;

{ TLVMParser.ExpectWord }
function TLVMParser.ExpectWord(): TLVMToken;
var
  LTok: TLVMToken;
begin
  LTok := Peek();
  // Accept any word token -- identifiers and keywords are all valid
  if (LTok.Kind <= tkIdentifier) and
     (LTok.Kind <> tkIntLit) and (LTok.Kind <> tkFloatLit) and
     (LTok.Kind <> tkStringLit) and (LTok.Kind <> tkTripleStringLit) then
    Result := Advance()
  else
    ParseError(LTok, 'Expected word but found "%s"', [LTok.Text]);
end;

procedure TLVMParser.ParseError(const ATok: TLVMToken; const AMsg: string);
begin
  GetErrors().RaiseOnError := True;
  GetErrors().Add(FFilename, ATok.Line, ATok.Col, esError, ERR_LVM_PARSE, AMsg);
end;

procedure TLVMParser.ParseError(const ATok: TLVMToken; const AMsg: string;
  const AArgs: array of const);
begin
  GetErrors().RaiseOnError := True;
  GetErrors().Add(FFilename, ATok.Line, ATok.Col, esError, ERR_LVM_PARSE,
    AMsg, AArgs);
end;

function TLVMParser.IsAtEnd(): Boolean;
begin
  Result := FTokens[FPos].Kind = tkEOF;
end;

function TLVMParser.ParseTypeName(): string;
var
  LTok: TLVMToken;
begin
  LTok := Peek();
  // Accept any word token -- identifiers and keywords are all valid type names.
  // Keywords come before tkIdentifier in the enum, so <= tkIdentifier covers both.
  // Reject literals which also precede tkIdentifier.
  if (LTok.Kind <= tkIdentifier) and
     (LTok.Kind <> tkIntLit) and (LTok.Kind <> tkFloatLit) and
     (LTok.Kind <> tkStringLit) and (LTok.Kind <> tkTripleStringLit) then
  begin
    Result := LTok.Text;
    Advance();
    if (not TLVMValue.IsValidTypeName(Result)) and
       (not FUserTypeNames.ContainsKey(Result)) then
      ParseError(LTok, 'Unknown type name "%s"', [Result]);
  end
  else
    ParseError(LTok, 'Expected type name but found "%s"', [LTok.Text]);
end;

function TLVMParser.MakeNode(const AKind: string; const ALine, ACol: Integer): TLVMASTNode;
begin
  Result := TLVMASTNode.Create();
  Result.Kind := AKind;
  Result.Line := ALine;
  Result.Col := ACol;
  Result.Filename := FFilename;
  FAllNodes.Add(Result);
end;

function TLVMParser.Parse(const ATokens: TArray<TLVMToken>;
  const AFilename: string): TLVMASTNode;
var
  LI: Integer;
begin
  FAllNodes.Clear();
  FTokens := ATokens;
  FPos := 0;
  FFilename := AFilename;
  try
    Result := ParseSourceFile();
    // Success -- caller owns the tree via root. Clear tracking.
    FAllNodes.Clear();
  except
    // Free orphan nodes that have no parent (not attached to any tree)
    for LI := FAllNodes.Count - 1 downto 0 do
    begin
      if FAllNodes[LI].FParent = nil then
        FAllNodes[LI].Free();
    end;
    FAllNodes.Clear();
    raise;
  end;
end;

function TLVMParser.ParseSingleExpr(const ATokens: TArray<TLVMToken>;
  const AFilename: string): TLVMASTNode;
begin
  FTokens := ATokens;
  FPos := 0;
  FFilename := AFilename;
  Result := ParseExpr();
end;

function TLVMParser.ParseSourceFile(): TLVMASTNode;
var
  LChild: TLVMASTNode;
begin
  Result := MakeNode('source_file', Peek().Line, Peek().Col);

  // Optional language declaration
  if Check(tkLanguage) then
    Result.AddChild(ParseLanguageDecl());

  // Top-level blocks until EOF
  while not IsAtEnd() do
  begin
    LChild := ParseTopLevelBlock();
    if LChild <> nil then
      Result.AddChild(LChild);
  end;
end;

function TLVMParser.ParseLanguageDecl(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkLanguage);
  Result := MakeNode('language_decl', LTok.Line, LTok.Col);
  Result.SetAttr('name', Expect(tkIdentifier).Text);
  Expect(tkVersion);
  Result.SetAttr('version', Expect(tkStringLit).Text);
  Expect(tkSemicolon);
end;

function TLVMParser.ParseTopLevelBlock(): TLVMASTNode;
begin
  Result := nil;

  case PeekKind() of
    tkTokens:    Result := ParseTokenBlock();
    tkTypes:     Result := ParseTypesBlock();
    tkGrammar:   Result := ParseGrammarBlock();
    tkSemantics: Result := ParseSemanticsBlock();
    tkEmitters:  Result := ParseEmitterBlock();
    tkMir:       Result := ParseMirBlock();
    tkConst:     Result := ParseConstBlock();
    tkEnum:      Result := ParseEnumDecl();
    tkRoutine:   Result := ParseRoutineDecl();
    tkFragment:  Result := ParseFragmentDecl();
    tkRecord:    Result := ParseRecordDecl();
    tkImport:    Result := ParseImportStmt();
    tkInclude:   Result := ParseIncludeStmt();
    tkGuard:     Result := ParseGuardBlock();
    tkLet:       Result := ParseLetStmt();
    tkIdentifier:
      if Peek().Text = 'target' then
        Result := ParseTargetBlock()
      else
        Result := ParseStmt();
  else
    ParseError(Peek(), 'Unexpected token "%s" at top level', [Peek().Text]);
  end;
end;

function TLVMParser.ParseTokenBlock(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkTokens);
  Result := MakeNode('tokens_block', LTok.Line, LTok.Col);
  Expect(tkLBrace);
  while (not Check(tkRBrace)) and (not IsAtEnd()) do
  begin
    if Check(tkToken) then
      Result.AddChild(ParseTokenDecl())
    else if Check(tkInclude) then
      Result.AddChild(ParseIncludeStmt())
    else if Check(tkGuard) then
      Result.AddChild(ParseGuardBlock())
    else if IsTokenConfigKeyword(Peek().Text) then
      Result.AddChild(ParseTokenConfig())
    else
      ParseError(Peek(), 'Unexpected token "%s" in tokens block', [Peek().Text]);
  end;
  Expect(tkRBrace);
end;

function TLVMParser.IsTokenConfigKeyword(const AText: string): Boolean;
begin
  Result := (AText = 'casesensitive') or (AText = 'terminator') or
    (AText = 'block_open') or (AText = 'block_close') or
    (AText = 'hex_prefix') or (AText = 'binary_prefix') or
    (AText = 'directive_prefix') or (AText = 'identifier_start') or
    (AText = 'identifier_part');
end;

function TLVMParser.ParseTokenDecl(): TLVMASTNode;
var
  LTok: TLVMToken;
  LFlag: TLVMASTNode;
begin
  LTok := Expect(tkToken);
  Result := MakeNode('token_decl', LTok.Line, LTok.Col);
  // TokenKind = word.word (keywords allowed in both positions)
  Result.SetAttr('category', ExpectWord().Text);
  Expect(tkDot);
  Result.SetAttr('name', ExpectWord().Text);
  Expect(tkAssign);
  Result.SetAttr('pattern', Expect(tkStringLit).Text);
  // Optional flags: [ flag, flag, ... ]
  if Check(tkLBracket) then
  begin
    Advance();
    while (not Check(tkRBracket)) and (not IsAtEnd()) do
    begin
      LFlag := MakeNode('token_flag', Peek().Line, Peek().Col);
      LFlag.SetAttr('flag', ExpectWord().Text);
      // Some flags take a string argument (e.g., "close" string)
      if Check(tkStringLit) then
        LFlag.SetAttr('arg', Advance().Text);
      Result.AddChild(LFlag);
      if not Check(tkRBracket) then
        Expect(tkComma);
    end;
    Expect(tkRBracket);
  end;
  Expect(tkSemicolon);
end;

function TLVMParser.ParseTokenConfig(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Advance(); // consume the config keyword (it's an identifier)
  Result := MakeNode('token_config', LTok.Line, LTok.Col);
  Result.SetAttr('key', LTok.Text);
  Expect(tkAssign);
  // Value can be string, ident.ident, true, false
  if Check(tkStringLit) then
    Result.SetAttr('value', Advance().Text)
  else if Check(tkTrue) then
  begin
    Result.SetAttr('value', 'true');
    Advance();
  end
  else if Check(tkFalse) then
  begin
    Result.SetAttr('value', 'false');
    Advance();
  end
  else
  begin
    // ident.ident (TokenKind reference)
    Result.SetAttr('value', Expect(tkIdentifier).Text);
    Expect(tkDot);
    Result.SetAttr('value', Result.GetAttr('value') + '.' + Expect(tkIdentifier).Text);
  end;
  Expect(tkSemicolon);
end;

function TLVMParser.ParseTypesBlock(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkTypes);
  Result := MakeNode('types_block', LTok.Line, LTok.Col);
  Expect(tkLBrace);
  while (not Check(tkRBrace)) and (not IsAtEnd()) do
  begin
    if Check(tkInclude) then
      Result.AddChild(ParseIncludeStmt())
    else if Check(tkGuard) then
      Result.AddChild(ParseGuardBlock())
    else
      Result.AddChild(ParseTypeDecl());
  end;
  Expect(tkRBrace);
end;

function TLVMParser.IsTypeKeyword(const AText: string): Boolean;
begin
  Result := (AText = 'map') or (AText = 'literal') or (AText = 'compatible') or
    (AText = 'decl_kind') or (AText = 'call_kind') or (AText = 'call_name_attr');
end;

function TLVMParser.ParseTypeDecl(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Peek();

  if Check(tkType) then
  begin
    // type ident = string ;
    Advance();
    Result := MakeNode('type_keyword_decl', LTok.Line, LTok.Col);
    Result.SetAttr('name', Expect(tkIdentifier).Text);
    Expect(tkAssign);
    Result.SetAttr('value', Expect(tkStringLit).Text);
    Expect(tkSemicolon);
  end
  else
  begin
    // map/literal/compatible/decl_kind/call_kind/call_name_attr
    LTok := Advance();
    Result := MakeNode('type_' + LTok.Text, LTok.Line, LTok.Col);

    if LTok.Text = 'map' then
    begin
      // map string -> string ;
      Result.SetAttr('from', Expect(tkStringLit).Text);
      Expect(tkArrow);
      Result.SetAttr('to', Expect(tkStringLit).Text);
      Expect(tkSemicolon);
    end
    else if LTok.Text = 'literal' then
    begin
      // literal string = string ;
      Result.SetAttr('pattern', Expect(tkStringLit).Text);
      Expect(tkAssign);
      Result.SetAttr('type', Expect(tkStringLit).Text);
      Expect(tkSemicolon);
    end
    else if LTok.Text = 'compatible' then
    begin
      // compatible string , string [ -> string ] ;
      Result.SetAttr('from', Expect(tkStringLit).Text);
      Expect(tkComma);
      Result.SetAttr('to', Expect(tkStringLit).Text);
      if Check(tkArrow) then
      begin
        Advance();
        Result.SetAttr('via', Expect(tkStringLit).Text);
      end;
      Expect(tkSemicolon);
    end
    else if (LTok.Text = 'decl_kind') or (LTok.Text = 'call_kind') then
    begin
      Result.SetAttr('value', Expect(tkStringLit).Text);
      Expect(tkSemicolon);
    end
    else if LTok.Text = 'call_name_attr' then
    begin
      Expect(tkAssign);
      Result.SetAttr('value', Expect(tkStringLit).Text);
      Expect(tkSemicolon);
    end
    else
      ParseError(LTok, 'Unexpected type declaration "%s"', [LTok.Text]);
  end;
end;

function TLVMParser.ParseGrammarBlock(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkGrammar);
  Result := MakeNode('grammar_block', LTok.Line, LTok.Col);
  Expect(tkLBrace);
  while (not Check(tkRBrace)) and (not IsAtEnd()) do
    Result.AddChild(ParseRuleDecl());
  Expect(tkRBrace);
end;

function TLVMParser.ParseRuleDecl(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkRule);
  Result := MakeNode('rule_decl', LTok.Line, LTok.Col);
  // NodeKind = word.word (keywords like 'nil', 'string' are valid rule names)
  Result.SetAttr('category', ExpectWord().Text);
  Expect(tkDot);
  Result.SetAttr('name', ExpectWord().Text);
  // Optional: precedence left|right integer
  if Check(tkPrecedence) then
  begin
    Advance();
    if Check(tkLeft) then
    begin
      Result.SetAttr('assoc', 'left');
      Advance();
    end
    else if Check(tkRight) then
    begin
      Result.SetAttr('assoc', 'right');
      Advance();
    end;
    Result.SetAttr('prec', Expect(tkIntLit).Text);
  end;
  Expect(tkLBrace);
  while (not Check(tkRBrace)) and (not IsAtEnd()) do
    Result.AddChild(ParseStmt());
  Expect(tkRBrace);
end;

function TLVMParser.ParseSemanticsBlock(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkSemantics);
  Result := MakeNode('semantics_block', LTok.Line, LTok.Col);
  Expect(tkLBrace);
  while (not Check(tkRBrace)) and (not IsAtEnd()) do
  begin
    if Check(tkPass) then
      Result.AddChild(ParsePassBlock())
    else if Check(tkOn) then
      Result.AddChild(ParseSemanticDecl())
    else
      ParseError(Peek(), 'Expected "on" or "pass" in semantics block, found "%s"', [Peek().Text]);
  end;
  Expect(tkRBrace);
end;

function TLVMParser.ParsePassBlock(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkPass);
  Result := MakeNode('pass_block', LTok.Line, LTok.Col);
  Result.SetAttr('number', Expect(tkIntLit).Text);
  Result.SetAttr('label', Expect(tkStringLit).Text);
  Expect(tkLBrace);
  while (not Check(tkRBrace)) and (not IsAtEnd()) do
    Result.AddChild(ParseSemanticDecl());
  Expect(tkRBrace);
end;

function TLVMParser.ParseSemanticDecl(): TLVMASTNode;
var
  LTok: TLVMToken;
  LFirst: string;
begin
  LTok := Expect(tkOn);
  Result := MakeNode('semantic_handler', LTok.Line, LTok.Col);
  LFirst := ExpectWord().Text;
  if Check(tkDot) then
  begin
    Advance();
    Result.SetAttr('category', LFirst);
    Result.SetAttr('name', ExpectWord().Text);
  end
  else
  begin
    Result.SetAttr('category', '');
    Result.SetAttr('name', LFirst);
  end;
  Expect(tkLBrace);
  while (not Check(tkRBrace)) and (not IsAtEnd()) do
    Result.AddChild(ParseStmt());
  Expect(tkRBrace);
end;

function TLVMParser.ParseEmitterBlock(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkEmitters);
  Result := MakeNode('emitters_block', LTok.Line, LTok.Col);
  Expect(tkLBrace);
  while (not Check(tkRBrace)) and (not IsAtEnd()) do
    Result.AddChild(ParseEmitDecl());
  Expect(tkRBrace);
end;

function TLVMParser.ParseEmitDecl(): TLVMASTNode;
var
  LTok: TLVMToken;
  LFirst: string;
begin
  LTok := Expect(tkOn);
  Result := MakeNode('emitter_handler', LTok.Line, LTok.Col);
  LFirst := ExpectWord().Text;
  if Check(tkDot) then
  begin
    Advance();
    Result.SetAttr('category', LFirst);
    Result.SetAttr('name', ExpectWord().Text);
  end
  else
  begin
    Result.SetAttr('category', '');
    Result.SetAttr('name', LFirst);
  end;
  Expect(tkLBrace);
  while (not Check(tkRBrace)) and (not IsAtEnd()) do
    Result.AddChild(ParseStmt());
  Expect(tkRBrace);
end;

function TLVMParser.IsMirWord(const ATok: TLVMToken): Boolean;
begin
  // A MIR word is any identifier or any LVM keyword -- MIR uses keywords
  // like "module", "import", "string" as plain identifiers
  Result := (ATok.Kind = tkIdentifier) or (ATok.Kind in [tkLanguage..tkNil]);
end;

function TLVMParser.ExpectMirWord(): TLVMToken;
begin
  Result := Peek();
  if not IsMirWord(Result) then
  begin
    ParseError(Result, 'Expected identifier but found "%s"', [Result.Text]);
    Exit;
  end;
  Advance();
end;

function TLVMParser.ParseMirHandlerDecl(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkOn);
  Result := MakeNode('mir_handler', LTok.Line, LTok.Col);
  Result.SetAttr('event', ExpectMirWord().Text);
  Expect(tkLBrace);
  while (not Check(tkRBrace)) and (not IsAtEnd()) do
    Result.AddChild(ParseStmt());
  Expect(tkRBrace);
end;

function TLVMParser.ParseMirBlock(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkMir);
  Result := MakeNode('mir_block', LTok.Line, LTok.Col);
  Expect(tkLBrace);

  // Parse MIR content: on-handlers only (mirXXX builtins build MIR data)
  while (not Check(tkRBrace)) and (not IsAtEnd()) do
  begin
    if Check(tkOn) then
      Result.AddChild(ParseMirHandlerDecl())
    else
    begin
      ParseError(Peek(), 'Expected "on" handler in mir block, found "%s"', [Peek().Text]);
      Advance();
    end;
  end;

  Expect(tkRBrace);
end;

function TLVMParser.ParseTargetHandlerDecl(): TLVMASTNode;
var
  LTok: TLVMToken;
  LParams: string;
begin
  LTok := Expect(tkOn);
  Result := MakeNode('target_handler', LTok.Line, LTok.Col);
  Result.SetAttr('name', ExpectMirWord().Text);

  // Optional parameter list -- simple identifiers, no types
  if Check(tkLParen) then
  begin
    Advance();
    LParams := '';
    if not Check(tkRParen) then
    begin
      LParams := Expect(tkIdentifier).Text;
      while Check(tkComma) do
      begin
        Advance();
        LParams := LParams + ',' + Expect(tkIdentifier).Text;
      end;
    end;
    Expect(tkRParen);
    Result.SetAttr('params', LParams);
  end;

  Expect(tkLBrace);
  while (not Check(tkRBrace)) and (not IsAtEnd()) do
    Result.AddChild(ParseStmt());
  Expect(tkRBrace);
end;

function TLVMParser.ParseTargetBlock(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkIdentifier);  // 'target' is a contextual keyword
  Result := MakeNode('target_block', LTok.Line, LTok.Col);

  // Optional context expression before the brace
  if not Check(tkLBrace) then
  begin
    Result.SetAttr('context', Expect(tkIdentifier).Text);
  end;

  Expect(tkLBrace);

  // Parse target handlers: on <opcode>(params) { body }
  while (not Check(tkRBrace)) and (not IsAtEnd()) do
  begin
    if Check(tkOn) then
      Result.AddChild(ParseTargetHandlerDecl())
    else
    begin
      ParseError(Peek(), 'Expected "on" handler in target block, found "%s"', [Peek().Text]);
      Advance();
    end;
  end;

  Expect(tkRBrace);
end;

function TLVMParser.ParseConstBlock(): TLVMASTNode;
var
  LTok: TLVMToken;
  LConst: TLVMASTNode;
begin
  LTok := Expect(tkConst);
  Result := MakeNode('const_block', LTok.Line, LTok.Col);
  Expect(tkLBrace);
  while (not Check(tkRBrace)) and (not IsAtEnd()) do
  begin
    LConst := MakeNode('const_decl', Peek().Line, Peek().Col);
    LConst.SetAttr('name', Expect(tkIdentifier).Text);
    Expect(tkAssign);
    LConst.AddChild(ParseExpr());
    Expect(tkSemicolon);
    Result.AddChild(LConst);
  end;
  Expect(tkRBrace);
end;

function TLVMParser.ParseEnumDecl(): TLVMASTNode;
var
  LTok: TLVMToken;
  LMemberIdx: Integer;
begin
  LTok := Expect(tkEnum);
  Result := MakeNode('enum_decl', LTok.Line, LTok.Col);
  Result.SetAttr('name', Expect(tkIdentifier).Text);
  FUserTypeNames.AddOrSetValue(Result.GetAttr('name'), True);
  Expect(tkLBrace);
  LMemberIdx := 0;
  while (not Check(tkRBrace)) and (not IsAtEnd()) do
  begin
    Result.SetAttr('member_' + IntToStr(LMemberIdx), Expect(tkIdentifier).Text);
    Inc(LMemberIdx);
    if not Check(tkRBrace) then
      Expect(tkComma);
  end;
  Result.SetAttr('member_count', IntToStr(LMemberIdx));
  Expect(tkRBrace);
end;

function TLVMParser.ParseRoutineDecl(): TLVMASTNode;
var
  LTok: TLVMToken;
  LParam: TLVMASTNode;
begin
  LTok := Expect(tkRoutine);
  Result := MakeNode('routine_decl', LTok.Line, LTok.Col);
  Result.SetAttr('name', Expect(tkIdentifier).Text);
  Expect(tkLParen);
  // Parameters
  if not Check(tkRParen) then
  begin
    LParam := MakeNode('param', Peek().Line, Peek().Col);
    LParam.SetAttr('name', Expect(tkIdentifier).Text);
    Expect(tkColon);
    LParam.SetAttr('type', ParseTypeName());
    Result.AddChild(LParam);
    while Check(tkComma) do
    begin
      Advance();
      LParam := MakeNode('param', Peek().Line, Peek().Col);
      LParam.SetAttr('name', Expect(tkIdentifier).Text);
      Expect(tkColon);
      LParam.SetAttr('type', ParseTypeName());
      Result.AddChild(LParam);
    end;
  end;
  Expect(tkRParen);
  // Optional return type
  if Check(tkArrow) then
  begin
    Advance();
    Result.SetAttr('return_type', ParseTypeName());
  end;
  // Body -- store as a stmt_block child
  Result.AddChild(ParseStmtBlock());
end;

function TLVMParser.ParseFragmentDecl(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkFragment);
  Result := MakeNode('fragment_decl', LTok.Line, LTok.Col);
  Result.SetAttr('name', Expect(tkIdentifier).Text);
  Expect(tkLBrace);
  while (not Check(tkRBrace)) and (not IsAtEnd()) do
    Result.AddChild(ParseTopLevelBlock());
  Expect(tkRBrace);
end;

function TLVMParser.ParseRecordDecl(): TLVMASTNode;
var
  LTok: TLVMToken;
  LField: TLVMASTNode;
  LIsLayout: Boolean;
begin
  LTok := Expect(tkRecord);
  Result := MakeNode('record_decl', LTok.Line, LTok.Col);
  Result.SetAttr('name', Expect(tkIdentifier).Text);
  FUserTypeNames.AddOrSetValue(Result.GetAttr('name'), True);

  // Detect optional 'extends ParentName' clause
  if Check(tkExtends) then
  begin
    Advance();
    Result.SetAttr('extends', Expect(tkIdentifier).Text);
  end;

  // Detect optional 'layout' modifier
  LIsLayout := Check(tkLayout);
  if LIsLayout then
  begin
    Advance();
    Result.SetAttr('layout', 'true');
  end;

  // extends + layout is an error (byte offset ambiguity)
  if (Result.GetAttr('extends') <> '') and LIsLayout then
  begin
    GetErrors().RaiseOnError := True;
    GetErrors().Add(FFilename, LTok.Line, LTok.Col, esError,
      ERR_LVM_PARSE, 'Layout records cannot use extends');
  end;

  Expect(tkLBrace);
  while (not Check(tkRBrace)) and (not IsAtEnd()) do
  begin
    LField := MakeNode('record_field', Peek().Line, Peek().Col);
    LField.SetAttr('name', Expect(tkIdentifier).Text);
    Expect(tkColon);
    if LIsLayout then
    begin
      // Layout fields: name: sizeType = default;
      LField.SetAttr('size_type', Expect(tkIdentifier).Text);
      Expect(tkAssign);
      LField.AddChild(ParseExpr());
    end
    else
    begin
      // Normal fields: name: default;
      LField.AddChild(ParseExpr());
    end;
    Expect(tkSemicolon);
    Result.AddChild(LField);
  end;
  Expect(tkRBrace);
end;

function TLVMParser.ParseImportStmt(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkImport);
  Result := MakeNode('import_stmt', LTok.Line, LTok.Col);
  Result.SetAttr('path', Expect(tkStringLit).Text);
  Expect(tkSemicolon);
end;

function TLVMParser.ParseIncludeStmt(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkInclude);
  Result := MakeNode('include_stmt', LTok.Line, LTok.Col);
  Result.SetAttr('name', Expect(tkIdentifier).Text);
  Expect(tkSemicolon);
end;

function TLVMParser.ParseGuardBlock(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkGuard);
  Result := MakeNode('guard_block', LTok.Line, LTok.Col);
  Result.AddChild(ParseExpr());
  Expect(tkLBrace);
  while (not Check(tkRBrace)) and (not IsAtEnd()) do
    Result.AddChild(ParseTopLevelBlock());
  Expect(tkRBrace);
end;

function TLVMParser.ParseStmtBlock(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkLBrace);
  Result := MakeNode('stmt_block', LTok.Line, LTok.Col);
  while (not Check(tkRBrace)) and (not IsAtEnd()) do
    Result.AddChild(ParseStmt());
  Expect(tkRBrace);
end;

function TLVMParser.ParseStmt(): TLVMASTNode;
begin
  case PeekKind() of
    tkLet:       Result := ParseLetStmt();
    tkImport:    Result := ParseImportStmt();
    tkIf:        Result := ParseIfStmt();
    tkWhile:     Result := ParseWhileStmt();
    tkFor:       Result := ParseForStmt();
    tkMatch:     Result := ParseMatchStmt();
    tkGuard:     Result := ParseGuardStmt();
    tkReturn:    Result := ParseReturnStmt();
    tkBreak:     Result := ParseBreakStmt();
    tkContinue:  Result := ParseContinueStmt();
    tkTry:       Result := ParseTryRecover();
    tkExpect:    Result := ParseExpectStmt();
    tkConsume:   Result := ParseConsumeStmt();
    tkParse:     Result := ParseParseDirective();
    tkOptional:  Result := ParseOptionalBlock();
    tkSync:      Result := ParseSyncStmt();
    tkScope:     Result := ParseScopeBlock();
    tkDeclare:   Result := ParseDeclareStmt();
    tkVisit:     Result := ParseVisitStmt();
    tkLookup:    Result := ParseLookupStmt();
    tkSection:   Result := ParseSectionBlock();
    tkError, tkWarning, tkHint, tkNote, tkInfo:
                 Result := ParseDiagStmt();
  else
    // Assignment or expression statement
    Result := ParseAssignOrExprStmt();
  end;
end;

function TLVMParser.ParseLetStmt(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkLet);
  Result := MakeNode('let_stmt', LTok.Line, LTok.Col);
  Result.SetAttr('name', ExpectWord().Text);
  Expect(tkColon);
  Result.SetAttr('type', ParseTypeName());
  Expect(tkAssign);
  Result.AddChild(ParseExpr());
  Expect(tkSemicolon);
end;

function TLVMParser.ParseAssignOrExprStmt(): TLVMASTNode;
var
  LTok: TLVMToken;
  LExpr: TLVMASTNode;
begin
  LTok := Peek();

  // If identifier, check for assignment patterns
  if Check(tkIdentifier) then
  begin
    // Simple assignment: ident = expr
    if (FPos + 1 < Length(FTokens)) and (FTokens[FPos + 1].Kind = tkAssign) then
    begin
      Result := MakeNode('assign_stmt', LTok.Line, LTok.Col);
      Result.SetAttr('name', Advance().Text);
      Expect(tkAssign);
      Result.AddChild(ParseExpr());
      Expect(tkSemicolon);
      Exit;
    end;

    // Dot/index assignment: expr.dot = value or expr.index = value
    if (FPos + 1 < Length(FTokens)) and
       ((FTokens[FPos + 1].Kind = tkDot) or (FTokens[FPos + 1].Kind = tkLBracket)) then
    begin
      // Parse the LHS as an expression (handles chained dot/index)
      LExpr := ParseExpr();
      // Check if followed by = (assignment)
      if Check(tkAssign) then
      begin
        Expect(tkAssign);
        Result := MakeNode('assign_expr_stmt', LExpr.Line, LExpr.Col);
        Result.AddChild(LExpr); // LHS target (expr.dot or expr.index)
        Result.AddChild(ParseExpr()); // RHS value
        Expect(tkSemicolon);
        Exit;
      end;
      // Not an assignment -- wrap as expr_stmt
      Result := MakeNode('expr_stmt', LExpr.Line, LExpr.Col);
      Result.AddChild(LExpr);
      Expect(tkSemicolon);
      Exit;
    end;
  end;

  // Otherwise it's an expression statement (bare function call)
  LExpr := ParseExpr();
  Result := MakeNode('expr_stmt', LExpr.Line, LExpr.Col);
  Result.AddChild(LExpr);
  Expect(tkSemicolon);
end;

function TLVMParser.ParseIfStmt(): TLVMASTNode;
var
  LTok: TLVMToken;
  LBranch: TLVMASTNode;
begin
  LTok := Expect(tkIf);
  Result := MakeNode('if_stmt', LTok.Line, LTok.Col);

  // if condition { body }
  LBranch := MakeNode('if_branch', LTok.Line, LTok.Col);
  LBranch.AddChild(ParseExpr());
  LBranch.AddChild(ParseStmtBlock());
  Result.AddChild(LBranch);

  // else if ...
  while Check(tkElse) do
  begin
    Advance();
    if Check(tkIf) then
    begin
      LTok := Advance();
      LBranch := MakeNode('elseif_branch', LTok.Line, LTok.Col);
      LBranch.AddChild(ParseExpr());
      LBranch.AddChild(ParseStmtBlock());
      Result.AddChild(LBranch);
    end
    else
    begin
      // else { body }
      LBranch := MakeNode('else_branch', Peek().Line, Peek().Col);
      LBranch.AddChild(ParseStmtBlock());
      Result.AddChild(LBranch);
      Break;
    end;
  end;
end;

function TLVMParser.ParseWhileStmt(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkWhile);
  Result := MakeNode('while_stmt', LTok.Line, LTok.Col);
  Result.AddChild(ParseExpr());
  Result.AddChild(ParseStmtBlock());
end;

function TLVMParser.ParseForStmt(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkFor);
  Result := MakeNode('for_stmt', LTok.Line, LTok.Col);
  Result.SetAttr('var', Expect(tkIdentifier).Text);
  Expect(tkIn);
  Result.AddChild(ParseExpr());
  Result.AddChild(ParseStmtBlock());
end;

function TLVMParser.ParseMatchStmt(): TLVMASTNode;
var
  LTok: TLVMToken;
  LArm: TLVMASTNode;
  LPattern: TLVMASTNode;
begin
  LTok := Expect(tkMatch);
  Result := MakeNode('match_stmt', LTok.Line, LTok.Col);
  Result.AddChild(ParseExpr());
  Expect(tkLBrace);

  while (not Check(tkRBrace)) and (not IsAtEnd()) do
  begin
    if Check(tkElse) then
    begin
      // else => { stmts }
      LArm := MakeNode('match_else', Peek().Line, Peek().Col);
      Advance(); // else
      Expect(tkFatArrow);
      LArm.AddChild(ParseStmtBlock());
      Result.AddChild(LArm);
      Break;
    end
    else
    begin
      // Pattern { | Pattern } => { stmts }
      LArm := MakeNode('match_arm', Peek().Line, Peek().Col);
      // First pattern
      LPattern := ParseExpr();
      LArm.AddChild(LPattern);
      // Additional patterns separated by |
      while Check(tkPipe) do
      begin
        Advance();
        LArm.AddChild(ParseExpr());
      end;
      Expect(tkFatArrow);
      LArm.AddChild(ParseStmtBlock());
      Result.AddChild(LArm);
    end;
  end;
  Expect(tkRBrace);
end;

function TLVMParser.ParseGuardStmt(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkGuard);
  Result := MakeNode('guard_stmt', LTok.Line, LTok.Col);
  Result.AddChild(ParseExpr());
  Result.AddChild(ParseStmtBlock());
end;

function TLVMParser.ParseReturnStmt(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkReturn);
  Result := MakeNode('return_stmt', LTok.Line, LTok.Col);
  if not Check(tkSemicolon) then
    Result.AddChild(ParseExpr());
  Expect(tkSemicolon);
end;

function TLVMParser.ParseBreakStmt(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkBreak);
  Result := MakeNode('break_stmt', LTok.Line, LTok.Col);
  Expect(tkSemicolon);
end;

function TLVMParser.ParseContinueStmt(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkContinue);
  Result := MakeNode('continue_stmt', LTok.Line, LTok.Col);
  Expect(tkSemicolon);
end;

function TLVMParser.ParseTryRecover(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkTry);
  Result := MakeNode('try_recover', LTok.Line, LTok.Col);
  Result.AddChild(ParseStmtBlock());
  Expect(tkRecover);
  Result.AddChild(ParseStmtBlock());
end;

function TLVMParser.ParseDiagStmt(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Advance(); // error/warning/hint/note/info
  Result := MakeNode('diag_stmt', LTok.Line, LTok.Col);
  Result.SetAttr('severity', LTok.Text);
  Result.AddChild(ParseExpr());
  Expect(tkSemicolon);
end;

function TLVMParser.ParseExpectStmt(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkExpect);
  Result := MakeNode('expect_stmt', LTok.Line, LTok.Col);
  Result.SetAttr('token_ref', ParseTokenRef());
  Expect(tkSemicolon);
end;

function TLVMParser.ParseConsumeStmt(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkConsume);
  Result := MakeNode('consume_stmt', LTok.Line, LTok.Col);
  Result.SetAttr('token_ref', ParseTokenRef());
  Expect(tkArrow);
  Expect(tkAt);
  Result.SetAttr('target', ExpectWord().Text);
  Expect(tkSemicolon);
end;

function TLVMParser.ParseParseDirective(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkParse);
  Result := MakeNode('parse_directive', LTok.Line, LTok.Col);

  // parse expr | stmt | many stmt until TokenRef
  if Peek().Text = 'expr' then
  begin
    Result.SetAttr('mode', 'expr');
    Advance();
  end
  else if Peek().Text = 'stmt' then
  begin
    Result.SetAttr('mode', 'stmt');
    Advance();
  end
  else if Peek().Text = 'many' then
  begin
    Advance();
    // 'stmt' is an identifier in this context, not a keyword
    if (PeekKind() = tkIdentifier) and (Peek().Text = 'stmt') then
      Advance()
    else
      ParseError(Peek(), 'Expected "stmt" after "many"');
    Result.SetAttr('mode', 'many_stmt');
    Expect(tkUntil);
    Result.SetAttr('until_ref', ParseTokenRef());
  end
  else
    ParseError(Peek(), 'Expected parse mode (expr, stmt, many), found "%s"', [Peek().Text]);

  Expect(tkArrow);
  Expect(tkAt);
  Result.SetAttr('target', ExpectWord().Text);
  Expect(tkSemicolon);
end;

function TLVMParser.ParseOptionalBlock(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkOptional);
  Result := MakeNode('optional_block', LTok.Line, LTok.Col);
  Result.AddChild(ParseStmtBlock());
end;

function TLVMParser.ParseSyncStmt(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkSync);
  Result := MakeNode('sync_stmt', LTok.Line, LTok.Col);
  Result.SetAttr('token_ref', ParseTokenRef());
  Expect(tkSemicolon);
end;

function TLVMParser.ParseTokenRef(): string;
var
  LPart: string;
begin
  if Check(tkLBracket) then
  begin
    // [ ident.ident { , ident.ident } ]
    Advance();
    Result := ExpectWord().Text;
    Expect(tkDot);
    Result := Result + '.' + ExpectWord().Text;
    while Check(tkComma) do
    begin
      Advance();
      LPart := ExpectWord().Text;
      Expect(tkDot);
      LPart := LPart + '.' + ExpectWord().Text;
      Result := Result + ',' + LPart;
    end;
    Expect(tkRBracket);
  end
  else if (PeekKind() = tkIdentifier) and (Peek().Text = 'identifier') then
  begin
    Advance();
    Result := 'identifier';
  end
  else
  begin
    // Single word.word (keywords like 'literal', 'string' are valid category names)
    Result := ExpectWord().Text;
    Expect(tkDot);
    Result := Result + '.' + ExpectWord().Text;
  end;
end;

function TLVMParser.ParseScopeBlock(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkScope);
  Result := MakeNode('scope_block', LTok.Line, LTok.Col);
  // scope ( string | @ident ) { stmts }
  if Check(tkStringLit) then
    Result.SetAttr('scope_name', Advance().Text)
  else if Check(tkAt) then
  begin
    Advance();
    Result.SetAttr('scope_attr', ExpectWord().Text);
  end
  else
    ParseError(Peek(), 'Expected string or @attr after scope');
  Result.AddChild(ParseStmtBlock());
end;

function TLVMParser.ParseDeclareStmt(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkDeclare);
  Result := MakeNode('declare_stmt', LTok.Line, LTok.Col);
  Expect(tkAt);
  Result.SetAttr('attr', ExpectWord().Text);
  Expect(tkAs);
  Result.SetAttr('symbol_kind', ExpectWord().Text);
  // Optional: typed @word
  if Check(tkTyped) then
  begin
    Advance();
    Expect(tkAt);
    Result.SetAttr('typed_attr', ExpectWord().Text);
  end;
  Expect(tkSemicolon);
end;

function TLVMParser.ParseVisitStmt(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkVisit);
  Result := MakeNode('visit_stmt', LTok.Line, LTok.Col);

  if Check(tkChildren) then
  begin
    Result.SetAttr('mode', 'children');
    Advance();
  end
  else if Check(tkChild) then
  begin
    Result.SetAttr('mode', 'child');
    Advance();
    Expect(tkLBracket);
    Result.AddChild(ParseExpr());
    Expect(tkRBracket);
  end
  else if Check(tkAt) then
  begin
    Result.SetAttr('mode', 'attr');
    Advance();
    Result.SetAttr('attr', ExpectWord().Text);
  end
  else
    ParseError(Peek(), 'Expected children, child, or @attr after visit');
  Expect(tkSemicolon);
end;

function TLVMParser.ParseLookupStmt(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkLookup);
  Result := MakeNode('lookup_stmt', LTok.Line, LTok.Col);
  Expect(tkAt);
  Result.SetAttr('attr', ExpectWord().Text);

  if Check(tkArrow) then
  begin
    // -> let word
    Advance();
    Expect(tkLet);
    Result.SetAttr('bind', ExpectWord().Text);
  end
  else if Check(tkOr) then
  begin
    // or { stmts }
    Advance();
    Result.AddChild(ParseStmtBlock());
  end
  else
    ParseError(Peek(), 'Expected -> or "or" after lookup');
  Expect(tkSemicolon);
end;

function TLVMParser.ParseSectionBlock(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  LTok := Expect(tkSection);
  Result := MakeNode('section_block', LTok.Line, LTok.Col);
  Result.SetAttr('name', Expect(tkIdentifier).Text);
  Result.AddChild(ParseStmtBlock());
end;

function TLVMParser.ParseExpr(): TLVMASTNode;
begin
  Result := ParseOrExpr();
end;

function TLVMParser.ParseOrExpr(): TLVMASTNode;
var
  LRight: TLVMASTNode;
  LOp: TLVMASTNode;
begin
  Result := ParseAndExpr();
  while Check(tkOr) do
  begin
    Advance();
    LRight := ParseAndExpr();
    LOp := MakeNode('expr.binary', Result.Line, Result.Col);
    LOp.SetAttr('op', 'or');
    LOp.AddChild(Result);
    LOp.AddChild(LRight);
    Result := LOp;
  end;
end;

function TLVMParser.ParseAndExpr(): TLVMASTNode;
var
  LRight: TLVMASTNode;
  LOp: TLVMASTNode;
begin
  Result := ParseNotExpr();
  while Check(tkAnd) do
  begin
    Advance();
    LRight := ParseNotExpr();
    LOp := MakeNode('expr.binary', Result.Line, Result.Col);
    LOp.SetAttr('op', 'and');
    LOp.AddChild(Result);
    LOp.AddChild(LRight);
    Result := LOp;
  end;
end;

function TLVMParser.ParseNotExpr(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  if Check(tkNot) then
  begin
    LTok := Advance();
    Result := MakeNode('expr.unary', LTok.Line, LTok.Col);
    Result.SetAttr('op', 'not');
    Result.AddChild(ParseComparison());
  end
  else
    Result := ParseComparison();
end;

function TLVMParser.ParseComparison(): TLVMASTNode;
var
  LTok: TLVMToken;
  LOp: TLVMASTNode;
  LOpText: string;
begin
  Result := ParseAddition();
  if Check(tkEqEq) or Check(tkNeq) or Check(tkLt) or Check(tkGt) or
     Check(tkLe) or Check(tkGe) then
  begin
    LTok := Advance();
    LOpText := LTok.Text;
    LOp := MakeNode('expr.binary', Result.Line, Result.Col);
    LOp.SetAttr('op', LOpText);
    LOp.AddChild(Result);
    LOp.AddChild(ParseAddition());
    Result := LOp;
  end;
end;

function TLVMParser.ParseAddition(): TLVMASTNode;
var
  LTok: TLVMToken;
  LOp: TLVMASTNode;
begin
  Result := ParseShift();
  while Check(tkPlus) or Check(tkMinus) do
  begin
    LTok := Advance();
    LOp := MakeNode('expr.binary', Result.Line, Result.Col);
    LOp.SetAttr('op', LTok.Text);
    LOp.AddChild(Result);
    LOp.AddChild(ParseShift());
    Result := LOp;
  end;
end;

function TLVMParser.ParseShift(): TLVMASTNode;
var
  LTok: TLVMToken;
  LOp: TLVMASTNode;
begin
  Result := ParseTerm();
  while Check(tkShl) or Check(tkShr) do
  begin
    LTok := Advance();
    LOp := MakeNode('expr.binary', Result.Line, Result.Col);
    LOp.SetAttr('op', LTok.Text);
    LOp.AddChild(Result);
    LOp.AddChild(ParseTerm());
    Result := LOp;
  end;
end;

function TLVMParser.ParseTerm(): TLVMASTNode;
var
  LTok: TLVMToken;
  LOp: TLVMASTNode;
begin
  Result := ParseFactor();
  while Check(tkStar) or Check(tkSlash) or Check(tkPercent) do
  begin
    LTok := Advance();
    LOp := MakeNode('expr.binary', Result.Line, Result.Col);
    LOp.SetAttr('op', LTok.Text);
    LOp.AddChild(Result);
    LOp.AddChild(ParseFactor());
    Result := LOp;
  end;
end;

function TLVMParser.ParseFactor(): TLVMASTNode;
var
  LTok: TLVMToken;
begin
  if Check(tkMinus) then
  begin
    LTok := Advance();
    Result := MakeNode('expr.unary', LTok.Line, LTok.Col);
    Result.SetAttr('op', '-');
    Result.AddChild(ParseAtom());
  end
  else
    Result := ParseAtom();
end;

function TLVMParser.ParseAtom(): TLVMASTNode;
var
  LTok: TLVMToken;
  LBase: TLVMASTNode;
begin
  Result := nil;
  LTok := Peek();

  case PeekKind() of
    tkIntLit:
    begin
      Advance();
      Result := MakeNode('expr.int', LTok.Line, LTok.Col);
      Result.SetAttr('value', LTok.Text);
    end;

    tkFloatLit:
    begin
      Advance();
      Result := MakeNode('expr.float', LTok.Line, LTok.Col);
      Result.SetAttr('value', LTok.Text);
    end;

    tkStringLit:
    begin
      Advance();
      Result := MakeNode('expr.string', LTok.Line, LTok.Col);
      Result.SetAttr('value', LTok.Text);
    end;

    tkTripleStringLit:
    begin
      Advance();
      Result := MakeNode('expr.triplestring', LTok.Line, LTok.Col);
      Result.SetAttr('value', LTok.Text);
    end;

    tkTrue:
    begin
      Advance();
      Result := MakeNode('expr.bool', LTok.Line, LTok.Col);
      Result.SetAttr('value', 'true');
    end;

    tkFalse:
    begin
      Advance();
      Result := MakeNode('expr.bool', LTok.Line, LTok.Col);
      Result.SetAttr('value', 'false');
    end;

    tkNil:
    begin
      Advance();
      Result := MakeNode('expr.nil', LTok.Line, LTok.Col);
    end;

    tkAt:
    begin
      // @word -- attribute access (keywords valid as attr names)
      Advance();
      Result := MakeNode('expr.attr', LTok.Line, LTok.Col);
      Result.SetAttr('name', ExpectWord().Text);
    end;

    tkIdentifier:
    begin
      Advance();
      Result := MakeNode('expr.ident', LTok.Line, LTok.Col);
      Result.SetAttr('name', LTok.Text);
    end;

    tkLParen:
    begin
      // Grouped expression
      Advance();
      Result := ParseExpr();
      Expect(tkRParen);
    end;

    tkLBracket:
    begin
      // List literal: [ expr, expr, ... ]
      Advance();
      Result := MakeNode('expr.list', LTok.Line, LTok.Col);
      if not Check(tkRBracket) then
      begin
        Result.AddChild(ParseExpr());
        while Check(tkComma) do
        begin
          Advance();
          Result.AddChild(ParseExpr());
        end;
      end;
      Expect(tkRBracket);
    end;

    tkLBrace:
    begin
      // Map literal: { "key": expr, ... }
      Advance();
      Result := MakeNode('expr.map', LTok.Line, LTok.Col);
      if not Check(tkRBrace) then
      begin
        Result.SetAttr('key_' + IntToStr(Result.ChildCount()), Expect(tkStringLit).Text);
        Expect(tkColon);
        Result.AddChild(ParseExpr());
        while Check(tkComma) do
        begin
          Advance();
          Result.SetAttr('key_' + IntToStr(Result.ChildCount()), Expect(tkStringLit).Text);
          Expect(tkColon);
          Result.AddChild(ParseExpr());
        end;
      end;
      Expect(tkRBrace);
    end;

  else
    // Context-sensitive: treat keywords as identifiers in expression position
    // (matches ref ParsePrefix fallback for kw.* tokens)
    if LTok.Kind <> tkEOF then
    begin
      Advance();
      Result := MakeNode('expr.ident', LTok.Line, LTok.Col);
      Result.SetAttr('name', LTok.Text);
    end
    else
      ParseError(LTok, 'Unexpected token "%s" in expression', [LTok.Text]);
  end;

  // Post-fix: call (args), dot .ident, and index [expr]
  while Check(tkLParen) or Check(tkDot) or Check(tkLBracket) do
  begin
    LTok := Peek();
    LBase := Result;
    if Check(tkLParen) then
    begin
      Advance(); // consume (
      Result := MakeNode('expr.call', LTok.Line, LTok.Col);
      Result.AddChild(LBase); // child 0 = callee
      if not Check(tkRParen) then
      begin
        Result.AddChild(ParseExpr()); // children 1+ = args
        while Check(tkComma) do
        begin
          Advance();
          Result.AddChild(ParseExpr());
        end;
      end;
      Expect(tkRParen);
    end
    else if Check(tkDot) then
    begin
      Advance(); // consume .
      Result := MakeNode('expr.dot', LTok.Line, LTok.Col);
      Result.SetAttr('name', Expect(tkIdentifier).Text);
      Result.AddChild(LBase);
    end
    else
    begin
      Advance(); // consume [
      Result := MakeNode('expr.index', LTok.Line, LTok.Col);
      Result.AddChild(LBase);
      Result.AddChild(ParseExpr());
      Expect(tkRBracket);
    end;
  end;
end;

{ === TLVMScope ============================================================= }
constructor TLVMScope.Create(const AParent: TLVMScope);
begin
  inherited Create();
  FVars := TDictionary<string, TLVMVarEntry>.Create();
  FParent := AParent;
end;

destructor TLVMScope.Destroy();
begin
  FVars.Free();
  inherited Destroy();
end;

{ === TLVMEnvironment ======================================================= }
constructor TLVMEnvironment.Create();
begin
  inherited Create();
  FScopes := TObjectList<TLVMScope>.Create(True);
  FScopeStack := TList<TLVMScope>.Create();
  // Create global scope
  FCurrent := TLVMScope.Create(nil);
  FScopes.Add(FCurrent);
end;

destructor TLVMEnvironment.Destroy();
begin
  FScopeStack.Free();
  FScopes.Free();
  inherited Destroy();
end;

procedure TLVMEnvironment.PushScope();
var
  LScope: TLVMScope;
begin
  LScope := TLVMScope.Create(FCurrent);
  FScopes.Add(LScope);
  FCurrent := LScope;
end;

procedure TLVMEnvironment.PopScope();
begin
  if FCurrent.Parent = nil then
    raise Exception.Create('Cannot pop global scope');
  FCurrent := FCurrent.Parent;
  // Remove the dead scope from the list (OwnsObjects frees it)
  FScopes.Delete(FScopes.Count - 1);
end;

procedure TLVMEnvironment.EnterGlobalScope();
begin
  // Save current scope and switch to global (FScopes[0])
  FScopeStack.Add(FCurrent);
  FCurrent := TLVMScope(FScopes[0]);
end;

procedure TLVMEnvironment.LeaveGlobalScope();
begin
  if FScopeStack.Count = 0 then
    raise Exception.Create('LeaveGlobalScope without matching EnterGlobalScope');
  FCurrent := FScopeStack[FScopeStack.Count - 1];
  FScopeStack.Delete(FScopeStack.Count - 1);
end;

procedure TLVMEnvironment.Clear();
begin
  FScopes.Clear();
  FCurrent := TLVMScope.Create(nil);
  FScopes.Add(FCurrent);
end;

function TLVMEnvironment.DeclareVar(const AName: string; const AValue: TLVMValue; const ATypeName: string): Boolean;
var
  LEntry: TLVMVarEntry;
begin
  // Declare in current scope -- fails if already declared in this scope
  if FCurrent.Vars.ContainsKey(AName) then
    Exit(False);
  LEntry.Value := AValue;
  LEntry.TypeName := ATypeName;
  FCurrent.Vars.Add(AName, LEntry);
  Result := True;
end;

procedure TLVMEnvironment.ForceSetVar(const AName: string; const AValue: TLVMValue; const ATypeName: string);
var
  LEntry: TLVMVarEntry;
begin
  // Engine-controlled: declares or overwrites in current scope without checks
  LEntry.Value := AValue;
  LEntry.TypeName := ATypeName;
  FCurrent.Vars.AddOrSetValue(AName, LEntry);
end;

function TLVMEnvironment.UpdateVar(const AName: string; const AValue: TLVMValue): TUpdateVarResult;
var
  LScope: TLVMScope;
  LEntry: TLVMVarEntry;
begin
  // Walk up scope chain to find existing variable and update it
  LScope := FCurrent;
  while LScope <> nil do
  begin
    if LScope.Vars.TryGetValue(AName, LEntry) then
    begin
      // Type check: ensure new value matches declared type
      if (LEntry.TypeName <> 'any') and (AValue.Kind <> vkNil) and
         (not TLVMValue.KindMatchesType(AValue, LEntry.TypeName)) then
        Exit(uvrTypeMismatch);
      LEntry.Value := AValue;
      LScope.Vars.AddOrSetValue(AName, LEntry);
      Exit(uvrOK);
    end;
    LScope := LScope.Parent;
  end;
  // Not found -- caller must handle
  Result := uvrNotFound;
end;

function TLVMEnvironment.TryGetVar(const AName: string; out AValue: TLVMValue): Boolean;
var
  LScope: TLVMScope;
  LEntry: TLVMVarEntry;
begin
  LScope := FCurrent;
  while LScope <> nil do
  begin
    if LScope.Vars.TryGetValue(AName, LEntry) then
    begin
      AValue := LEntry.Value;
      Exit(True);
    end;
    LScope := LScope.Parent;
  end;
  AValue := TLVMValue.Nil_();
  Result := False;
end;

function TLVMEnvironment.GetVar(const AName: string): TLVMValue;
begin
  if not TryGetVar(AName, Result) then
    Result := TLVMValue.Nil_();
end;

function TLVMEnvironment.HasVar(const AName: string): Boolean;
var
  LScope: TLVMScope;
  LDummy: TLVMVarEntry;
begin
  LScope := FCurrent;
  while LScope <> nil do
  begin
    if LScope.Vars.TryGetValue(AName, LDummy) then
      Exit(True);
    LScope := LScope.Parent;
  end;
  Result := False;
end;

function TLVMEnvironment.CurrentScope(): TLVMScope;
begin
  Result := FCurrent;
end;

{ === TLVMMirFunc =========================================================== }
constructor TLVMMirFunc.Create();
begin
  inherited Create();
  FIsVararg := False;
end;

destructor TLVMMirFunc.Destroy();
begin
  inherited;
end;

procedure TLVMMirFunc.AddInsn(const AInsn: TLVMMirInsn);
begin
  FInsns := FInsns + [AInsn];
end;

procedure TLVMMirFunc.AddLocal(const ALocal: TLVMMirLocal);
begin
  FLocals := FLocals + [ALocal];
end;

{ === TLVMMirModule ========================================================= }
constructor TLVMMirModule.Create();
begin
  inherited Create();
  FFuncs := TObjectList<TLVMMirFunc>.Create(True);
end;

destructor TLVMMirModule.Destroy();
begin
  FFuncs.Free();
  inherited;
end;

procedure TLVMMirModule.AddImport(const AName: string);
begin
  FImports := FImports + [AName];
end;

procedure TLVMMirModule.AddExport(const AName: string);
begin
  FExportList := FExportList + [AName];
end;

procedure TLVMMirModule.AddForward(const AName: string);
begin
  FForwards := FForwards + [AName];
end;

procedure TLVMMirModule.AddProto(const AProto: TLVMMirProto);
begin
  FProtos := FProtos + [AProto];
end;

procedure TLVMMirModule.AddFunc(const AFunc: TLVMMirFunc);
begin
  FFuncs.Add(AFunc);
end;

procedure TLVMMirModule.AddDataItem(const AItem: TLVMMirDataItem);
begin
  FDataItems := FDataItems + [AItem];
end;

{ === TLVMMirProgram ======================================================== }
constructor TLVMMirProgram.Create();
begin
  inherited Create();
  FModules := TObjectList<TLVMMirModule>.Create(True);
  FOptMode := 'debug';
  FDebugInfo := False;
end;

destructor TLVMMirProgram.Destroy();
begin
  FModules.Free();
  inherited;
end;

procedure TLVMMirProgram.AddModule(const AModule: TLVMMirModule);
begin
  FModules.Add(AModule);
end;

procedure TLVMMirProgram.Clear();
begin
  FModules.Clear();
end;

{ === MIR Routines ========================================================== }
const
  { CMirTypeNames }
  CMirTypeNames: array[TLVMMirType] of string = (
    'i8', 'u8', 'i16', 'u16', 'i32', 'u32', 'i64', 'u64',
    'f', 'd', 'ld', 'p', 'void',
    'blk', 'blk1', 'blk2', 'blk3', 'blk4', 'blk5', 'rblk'
  );

  { CMirOpcodeNames }
  CMirOpcodeNames: array[TLVMMirOpcode] of string = (
    // Move
    'mov', 'fmov', 'dmov', 'ldmov',
    // Memory access
    'load', 'store',
    // Integer arithmetic 64-bit
    'add', 'sub', 'mul', 'div', 'mod',
    'umul', 'udiv', 'umod', 'neg',
    // Integer arithmetic 32-bit
    'adds', 'subs', 'muls', 'divs', 'mods',
    'umuls', 'udivs', 'umods', 'negs',
    // Overflow 64-bit
    'addo', 'subo', 'mulo', 'umulo',
    // Overflow 32-bit
    'addos', 'subos', 'mulos', 'umulos',
    // Bitwise 64-bit
    'and', 'or', 'xor', 'lsh', 'rsh', 'ursh',
    // Bitwise 32-bit
    'ands', 'ors', 'xors', 'lshs', 'rshs', 'urshs',
    // Comparison 64-bit
    'eq', 'ne', 'lt', 'le', 'gt', 'ge',
    'ult', 'ule', 'ugt', 'uge',
    // Comparison 32-bit
    'eqs', 'nes', 'lts', 'les', 'gts', 'ges',
    'ults', 'ules', 'ugts', 'uges',
    // Float arithmetic
    'fadd', 'fsub', 'fmul', 'fdiv', 'fneg',
    'dadd', 'dsub', 'dmul', 'ddiv', 'dneg',
    'ldadd', 'ldsub', 'ldmul', 'lddiv', 'ldneg',
    // Float comparison
    'feq', 'fne', 'flt', 'fle', 'fgt', 'fge',
    'deq', 'dne', 'dlt', 'dle', 'dgt', 'dge',
    'ldeq', 'ldne', 'ldlt', 'ldle', 'ldgt', 'ldge',
    // Conversion
    'ext8', 'uext8', 'ext16', 'uext16', 'ext32', 'uext32',
    'i2f', 'i2d', 'i2ld', 'ui2f', 'ui2d', 'ui2ld',
    'f2i', 'd2i', 'ld2i', 'f2d', 'f2ld',
    'd2f', 'd2ld', 'ld2f', 'ld2d',
    // Address
    'addr', 'addr8', 'addr16', 'addr32',
    // Branch
    'jmp', 'bt', 'bf', 'bts', 'bfs', 'jmpi',
    // Branch on overflow
    'bo', 'bno', 'ubo', 'ubno',
    // Compare-and-branch 64-bit
    'beq', 'bne', 'blt', 'ble', 'bgt', 'bge',
    'ublt', 'uble', 'ubgt', 'ubge',
    // Compare-and-branch 32-bit
    'beqs', 'bnes', 'blts', 'bles', 'bgts', 'bges',
    'ublts', 'ubles', 'ubgts', 'ubges',
    // Compare-and-branch float
    'fbeq', 'fbne', 'fblt', 'fble', 'fbgt', 'fbge',
    'dbeq', 'dbne', 'dblt', 'dble', 'dbgt', 'dbge',
    'ldbeq', 'ldbne', 'ldblt', 'ldble', 'ldbgt', 'ldbge',
    // Switch
    'switch',
    // Label address
    'laddr',
    // Call/return
    'call', 'inline', 'ret',
    'jcall', 'jret',
    // Stack
    'alloca', 'bstart', 'bend',
    // Varargs
    'va_start', 'va_arg', 'va_block_arg', 'va_end',
    // Properties
    'prset', 'prbeq', 'prbne'
  );

function MirTypeToStr(const AType: TLVMMirType): string;
begin
  Result := CMirTypeNames[AType];
end;

function MirStrToType(const AName: string; out AType: TLVMMirType): Boolean;
var
  LType: TLVMMirType;
begin
  for LType := Low(TLVMMirType) to High(TLVMMirType) do
  begin
    if CMirTypeNames[LType] = AName then
    begin
      AType := LType;
      Exit(True);
    end;
  end;
  Result := False;
end;

function MirOpcodeToStr(const AOpcode: TLVMMirOpcode): string;
begin
  Result := CMirOpcodeNames[AOpcode];
end;

function MirStrToOpcode(const AName: string; out AOpcode: TLVMMirOpcode): Boolean;
var
  LOpcode: TLVMMirOpcode;
begin
  for LOpcode := Low(TLVMMirOpcode) to High(TLVMMirOpcode) do
  begin
    if CMirOpcodeNames[LOpcode] = AName then
    begin
      AOpcode := LOpcode;
      Exit(True);
    end;
  end;
  Result := False;
end;

function MirOperandToValue(const AOperand: TLVMMirOperand): TLVMValue;
begin
  case AOperand.Kind of
    mokRegister:
      Result := TLVMValue.FromString(AOperand.RegName);
    mokImmediateInt:
      Result := TLVMValue.FromInt(AOperand.IntValue);
    mokImmediateFloat:
      Result := TLVMValue.FromFloat(AOperand.FloatValue);
    mokLabel:
      Result := TLVMValue.FromString(AOperand.LabelName);
    mokReference:
      Result := TLVMValue.FromString(AOperand.RefName);
    mokString:
      Result := TLVMValue.FromString(AOperand.StrValue);
    mokMemory:
    begin
      // Return structured map for memory operand: {kind, base, disp, index, scale}
      Result := TLVMValue.FromMap();
      Result.AsMap().AddOrSetValue('kind', TLVMValue.FromString('mem'));
      Result.AsMap().AddOrSetValue('base', TLVMValue.FromString(AOperand.Mem.Base));
      Result.AsMap().AddOrSetValue('disp', TLVMValue.FromInt(AOperand.Mem.Displacement));
      Result.AsMap().AddOrSetValue('index', TLVMValue.FromString(AOperand.Mem.Index));
      Result.AsMap().AddOrSetValue('scale', TLVMValue.FromInt(AOperand.Mem.Scale));
    end;
  else
    Result := TLVMValue.FromString('?');
  end;
end;

{ === TLVMSymbol ============================================================ }
constructor TLVMSymbol.Create(const AName: string; const ASymKind: string);
begin
  inherited Create();
  FSymName := AName;
  FSymKind := ASymKind;
  FTypeName := '';
  FAttrs := TDictionary<string, string>.Create();
  FDeclNode := nil;
end;

destructor TLVMSymbol.Destroy();
begin
  FreeAndNil(FAttrs);
  inherited;
end;

function TLVMSymbol.GetSymAttr(const AKey: string): string;
begin
  if not FAttrs.TryGetValue(AKey, Result) then
    Result := '';
end;

procedure TLVMSymbol.SetSymAttr(const AKey: string; const AValue: string);
begin
  FAttrs.AddOrSetValue(AKey, AValue);
end;

function TLVMSymbol.HasSymAttr(const AKey: string): Boolean;
begin
  Result := FAttrs.ContainsKey(AKey);
end;

{ === TLVMSemScope ========================================================== }
constructor TLVMSemScope.Create(const AName: string; const AParent: TLVMSemScope);
begin
  inherited Create();
  FScopeName := AName;
  FParent := AParent;
  FSymbols := TObjectDictionary<string, TLVMSymbol>.Create([doOwnsValues]);
  FChildren := TObjectList<TLVMSemScope>.Create(True);
  if Assigned(AParent) then
    AParent.FChildren.Add(Self);
end;

destructor TLVMSemScope.Destroy();
begin
  FreeAndNil(FChildren);
  FreeAndNil(FSymbols);
  inherited;
end;

function TLVMSemScope.FindChild(const AName: string): TLVMSemScope;
var
  LI: Integer;
begin
  for LI := 0 to FChildren.Count - 1 do
  begin
    if FChildren[LI].FScopeName = AName then
      Exit(FChildren[LI]);
  end;
  Result := nil;
end;

procedure TLVMSemScope.DeclareSymbol(const AName: string; const ASymKind: string;
  const ADeclNode: TObject);
var
  LSym: TLVMSymbol;
begin
  LSym := TLVMSymbol.Create(AName, ASymKind);
  LSym.DeclNode := ADeclNode;
  FSymbols.AddOrSetValue(AName, LSym);
end;

function TLVMSemScope.LookupLocal(const AName: string): TLVMSymbol;
begin
  if not FSymbols.TryGetValue(AName, Result) then
    Result := nil;
end;

{ === TLVMScopeManager ====================================================== }
constructor TLVMScopeManager.Create();
begin
  inherited Create();
  FRoot := TLVMSemScope.Create('global', nil);
  FCurrent := FRoot;
  FScopeStateStack := TList<TLVMSemScope>.Create();
end;

destructor TLVMScopeManager.Destroy();
begin
  FCurrent := nil;
  FreeAndNil(FScopeStateStack);
  FreeAndNil(FRoot);
  inherited;
end;

procedure TLVMScopeManager.Push(const AName: string);
var
  LExisting: TLVMSemScope;
  LNewScope: TLVMSemScope;
begin
  // Reuse existing child scope if found (for multi-pass re-entry)
  LExisting := FCurrent.FindChild(AName);
  if Assigned(LExisting) then
    FCurrent := LExisting
  else
  begin
    LNewScope := TLVMSemScope.Create(AName, FCurrent);
    FCurrent := LNewScope;
  end;
end;

procedure TLVMScopeManager.Pop();
begin
  if FCurrent = FRoot then
    Exit;
  FCurrent := FCurrent.Parent;
end;

procedure TLVMScopeManager.Reset();
begin
  FCurrent := FRoot;
end;

{ SaveState }
procedure TLVMScopeManager.SaveState();
begin
  FScopeStateStack.Add(FCurrent);
  FCurrent := FRoot;
end;

{ RestoreState }
procedure TLVMScopeManager.RestoreState();
begin
  if FScopeStateStack.Count = 0 then
    Exit;
  FCurrent := FScopeStateStack[FScopeStateStack.Count - 1];
  FScopeStateStack.Delete(FScopeStateStack.Count - 1);
end;

procedure TLVMScopeManager.Declare(const AName: string; const ASymKind: string;
  const ADeclNode: TObject);
begin
  if FCurrent <> nil then
    FCurrent.DeclareSymbol(AName, ASymKind, ADeclNode);
end;

function TLVMScopeManager.Lookup(const AName: string): TLVMSymbol;
var
  LScope: TLVMSemScope;
begin
  LScope := FCurrent;
  while LScope <> nil do
  begin
    Result := LScope.LookupLocal(AName);
    if Result <> nil then
      Exit;
    LScope := LScope.Parent;
  end;
  Result := nil;
end;

function TLVMScopeManager.LookupGlobal(const AName: string): TLVMSymbol;

  function SearchScope(const AScope: TLVMSemScope): TLVMSymbol;
  var
    LI: Integer;
  begin
    Result := AScope.LookupLocal(AName);
    if Result <> nil then Exit;
    for LI := 0 to AScope.Children.Count - 1 do
    begin
      Result := SearchScope(AScope.Children[LI]);
      if Result <> nil then Exit;
    end;
  end;

begin
  if FRoot <> nil then
    Result := SearchScope(FRoot)
  else
    Result := nil;
end;

function TLVMScopeManager.SymbolExists(const AName: string): Boolean;
begin
  Result := Lookup(AName) <> nil;
end;

{ === TLVMGenericLexer ====================================================== }
constructor TLVMGenericLexer.Create();
begin
  inherited Create();
  FInterp := nil;
  FCondStack := TList<TCondEntry>.Create();
  FSkipping := False;
end;

destructor TLVMGenericLexer.Destroy();
begin
  FreeAndNil(FCondStack);
  inherited;
end;

procedure TLVMGenericLexer.Configure(const AInterp: TLangVM);
begin
  FInterp := AInterp;
end;

function TLVMGenericLexer.AtEnd(): Boolean;
begin
  Result := FPos > Length(FSource);
end;

function TLVMGenericLexer.Current(): Char;
begin
  if AtEnd() then
    Result := #0
  else
    Result := FSource[FPos];
end;

function TLVMGenericLexer.PeekAt(const AOffset: Integer): Char;
var
  LIdx: Integer;
begin
  LIdx := FPos + AOffset;
  if (LIdx < 1) or (LIdx > Length(FSource)) then
    Result := #0
  else
    Result := FSource[LIdx];
end;

function TLVMGenericLexer.Advance(): Char;
begin
  Result := Current();
  if not AtEnd() then
  begin
    if FSource[FPos] = #10 then
    begin
      Inc(FLine);
      FCol := 1;
    end
    else
      Inc(FCol);
    Inc(FPos);
  end;
end;

function TLVMGenericLexer.MakeToken(const AKind, AText: string;
  const ALine, ACol: Integer): TLVMUserToken;
begin
  Result.Kind := AKind;
  Result.Text := AText;
  Result.Filename := FFilename;
  Result.Line := ALine;
  Result.Col := ACol;
end;

procedure TLVMGenericLexer.SkipWhitespace();
begin
  while not AtEnd() and Current().IsWhiteSpace do
    Advance();
end;

function TLVMGenericLexer.SkipComment(): Boolean;
var
  LI: Integer;
  LOpen: string;
  LClose: string;
  LLen: Integer;
  LMatch: Boolean;
  LJ: Integer;
begin
  Result := False;

  // Try line comments
  for LI := 0 to FInterp.TokenLineComments.Count - 1 do
  begin
    LOpen := FInterp.TokenLineComments[LI];
    LLen := Length(LOpen);
    LMatch := True;
    if FPos + LLen - 1 > Length(FSource) then Continue;
    for LJ := 1 to LLen do
    begin
      if FSource[FPos + LJ - 1] <> LOpen[LJ] then
      begin
        LMatch := False;
        Break;
      end;
    end;
    if LMatch then
    begin
      while not AtEnd() and (Current() <> #10) do
        Advance();
      Exit(True);
    end;
  end;

  // Try block comments
  for LI := 0 to FInterp.TokenBlockComments.Count - 1 do
  begin
    LOpen := FInterp.TokenBlockComments[LI].Key;
    LClose := FInterp.TokenBlockComments[LI].Value;
    LLen := Length(LOpen);
    LMatch := True;
    if FPos + LLen - 1 > Length(FSource) then Continue;
    for LJ := 1 to LLen do
    begin
      if FSource[FPos + LJ - 1] <> LOpen[LJ] then
      begin
        LMatch := False;
        Break;
      end;
    end;
    if LMatch then
    begin
      // Skip past the opening
      for LJ := 1 to LLen do Advance();
      // Find closing
      while not AtEnd() do
      begin
        LMatch := True;
        if FPos + Length(LClose) - 1 > Length(FSource) then
        begin
          Advance();
          Continue;
        end;
        for LJ := 1 to Length(LClose) do
        begin
          if FSource[FPos + LJ - 1] <> LClose[LJ] then
          begin
            LMatch := False;
            Break;
          end;
        end;
        if LMatch then
        begin
          for LJ := 1 to Length(LClose) do Advance();
          Exit(True);
        end;
        Advance();
      end;
      // Unterminated block comment
      GetErrors().Add(FFilename, FLine, FCol, esError, ERR_LVM_LEX,
        'Unterminated block comment');
      Exit(False);
    end;
  end;
end;

function TLVMGenericLexer.TryOperator(var AToken: TLVMUserToken): Boolean;
var
  LI: Integer;
  LEntry: TLVMOperatorEntry;
  LLen: Integer;
  LStartLine: Integer;
  LStartCol: Integer;
  LMatch: Boolean;
  LJ: Integer;
begin
  Result := False;
  LStartLine := FLine;
  LStartCol := FCol;

  for LI := 0 to FInterp.TokenOperators.Count - 1 do
  begin
    LEntry := FInterp.TokenOperators[LI];
    LLen := Length(LEntry.Text);
    if FPos + LLen - 1 > Length(FSource) then Continue;

    LMatch := True;
    for LJ := 1 to LLen do
    begin
      if FSource[FPos + LJ - 1] <> LEntry.Text[LJ] then
      begin
        LMatch := False;
        Break;
      end;
    end;

    if LMatch then
    begin
      for LJ := 1 to LLen do Advance();
      AToken := MakeToken(LEntry.Kind, LEntry.Text, LStartLine, LStartCol);
      Result := True;
      Exit;
    end;
  end;
end;

function TLVMGenericLexer.TryStringLiteral(var AToken: TLVMUserToken): Boolean;
var
  LI: Integer;
  LStyle: TLVMStringStyleEntry;
  LOpenLen: Integer;
  LStartLine: Integer;
  LStartCol: Integer;
  LText: string;
  LMatch: Boolean;
  LJ: Integer;
  LNoEscape: Boolean;
begin
  Result := False;

  for LI := 0 to FInterp.TokenStringStyles.Count - 1 do
  begin
    LStyle := FInterp.TokenStringStyles[LI];
    LOpenLen := Length(LStyle.OpenText);
    if FPos + LOpenLen - 1 > Length(FSource) then Continue;

    LMatch := True;
    for LJ := 1 to LOpenLen do
    begin
      if FSource[FPos + LJ - 1] <> LStyle.OpenText[LJ] then
      begin
        LMatch := False;
        Break;
      end;
    end;

    if LMatch then
    begin
      LStartLine := FLine;
      LStartCol := FCol;
      LNoEscape := LStyle.Flags.Contains('noescape');

      // Skip opening delimiter
      for LJ := 1 to LOpenLen do Advance();

      // Collect string content until closing delimiter
      LText := '';
      while not AtEnd() do
      begin
        // Check for closing delimiter
        if (LStyle.CloseText <> '') and (Current() = LStyle.CloseText[1]) then
        begin
          if (not LNoEscape) or (LText = '') or (LText[Length(LText)] <> LStyle.CloseText[1]) then
          begin
            Advance();
            AToken := MakeToken(LStyle.Kind, LText, LStartLine, LStartCol);
            Result := True;
            Exit;
          end;
          // Doubled delimiter = literal
          LText := LText + Current();
          Advance();
        end
        else if (not LNoEscape) and (Current() = '\') then
        begin
          // Escape sequence: preserve backslash
          LText := LText + '\';
          Advance();
          if not AtEnd() then
          begin
            LText := LText + Current();
            Advance();
          end;
        end
        else
        begin
          LText := LText + Current();
          Advance();
        end;
      end;
      // Unterminated string
      GetErrors().Add(FFilename, LStartLine, LStartCol, esError, ERR_LVM_LEX,
        'Unterminated string literal');
      Exit(False);
    end;
  end;
end;

function TLVMGenericLexer.TryNumber(var AToken: TLVMUserToken): Boolean;
var
  LStartLine: Integer;
  LStartCol: Integer;
  LText: string;
  LIsFloat: Boolean;
  LI: Integer;
  LPrefix: string;
  LPrefixLen: Integer;
  LMatch: Boolean;
  LJ: Integer;
begin
  Result := False;

  // Try hex prefixes first
  for LI := 0 to FInterp.LexerConfig.HexPrefix.Count - 1 do
  begin
    LPrefix := FInterp.LexerConfig.HexPrefix[LI];
    LPrefixLen := Length(LPrefix);
    if FPos + LPrefixLen - 1 > Length(FSource) then Continue;
    LMatch := True;
    for LJ := 1 to LPrefixLen do
    begin
      if FSource[FPos + LJ - 1] <> LPrefix[LJ] then
      begin
        LMatch := False;
        Break;
      end;
    end;
    if LMatch then
    begin
      LStartLine := FLine;
      LStartCol := FCol;
      LText := '';
      for LJ := 1 to LPrefixLen do
      begin
        LText := LText + Current();
        Advance();
      end;
      while not AtEnd() and (Current().IsDigit or
            ((Current() >= 'a') and (Current() <= 'f')) or
            ((Current() >= 'A') and (Current() <= 'F'))) do
      begin
        LText := LText + Current();
        Advance();
      end;
      AToken := MakeToken('literal.integer', LText, LStartLine, LStartCol);
      Result := True;
      Exit;
    end;
  end;

  if not Current().IsDigit then Exit;

  Result := True;
  LStartLine := FLine;
  LStartCol := FCol;
  LText := '';
  LIsFloat := False;

  while not AtEnd() and Current().IsDigit do
  begin
    LText := LText + Current();
    Advance();
  end;

  // Decimal point
  if not AtEnd() and (Current() = '.') and PeekAt(1).IsDigit then
  begin
    LIsFloat := True;
    LText := LText + Current();
    Advance();
    while not AtEnd() and Current().IsDigit do
    begin
      LText := LText + Current();
      Advance();
    end;
  end;

  if LIsFloat then
    AToken := MakeToken('literal.float', LText, LStartLine, LStartCol)
  else
    AToken := MakeToken('literal.integer', LText, LStartLine, LStartCol);
end;

function TLVMGenericLexer.TryIdentifier(var AToken: TLVMUserToken): Boolean;
var
  LStartLine: Integer;
  LStartCol: Integer;
  LText: string;
  LKind: string;
begin
  Result := False;
  if not (Current().IsLetter or (Current() = '_')) then Exit;

  Result := True;
  LStartLine := FLine;
  LStartCol := FCol;
  LText := '';

  while not AtEnd() and (Current().IsLetterOrDigit or (Current() = '_')) do
  begin
    LText := LText + Current();
    Advance();
  end;

  // Bang-suffix keyword attach: word immediately followed by '!' becomes one
  // keyword lexeme when "<word>!" is registered (e.g. set!)
  if not AtEnd() and (Current() = '!') then
  begin
    if FInterp.LexerConfig.CaseSensitive then
    begin
      if FInterp.TokenKeywords.ContainsKey(LText + '!') then
      begin
        LText := LText + '!';
        Advance();
      end;
    end
    else if FInterp.TokenKeywords.ContainsKey(LowerCase(LText) + '!') then
    begin
      LText := LText + '!';
      Advance();
    end;
  end;

  // Keyword promotion (case-sensitive or insensitive based on config)
  if FInterp.LexerConfig.CaseSensitive then
  begin
    if FInterp.TokenKeywords.TryGetValue(LText, LKind) then
      AToken := MakeToken(LKind, LText, LStartLine, LStartCol)
    else
      AToken := MakeToken('identifier', LText, LStartLine, LStartCol);
  end
  else
  begin
    if FInterp.TokenKeywords.TryGetValue(LowerCase(LText), LKind) then
      AToken := MakeToken(LKind, LText, LStartLine, LStartCol)
    else
      AToken := MakeToken('identifier', LText, LStartLine, LStartCol);
  end;
end;

function TLVMGenericLexer.Tokenize(const ASource: string;
  const AFilename: string): TList<TLVMUserToken>;
var
  LToken: TLVMUserToken;
  LIdent: TLVMUserToken;
  LFlag: string;
  LSymbol: string;
  LEntry: TCondEntry;
  LDirectivePrefix: string;
  LEndWord: string;
  LEndKind: string;
  LRawBuf: string;
  LRawStartLine: Integer;
  LRawStartCol: Integer;
  LEndLen: Integer;
  LEndKwLine: Integer;
  LEndKwCol: Integer;
  LRawI: Integer;
  LFoundEnd: Boolean;
  LAfterEnd: Char;
begin
  FSource := ASource;
  FFilename := AFilename;
  FPos := 1;
  FLine := 1;
  FCol := 1;

  // Reset conditional compilation state
  FCondStack.Clear();
  FSkipping := False;

  LDirectivePrefix := FInterp.LexerConfig.DirectivePrefix;

  Result := TList<TLVMUserToken>.Create();

  while not AtEnd() do
  begin
    SkipWhitespace();
    if AtEnd() then Break;

    if SkipComment() then Continue;
    if AtEnd() then Break;
    if Current().IsWhiteSpace then Continue;

    // Try directive FIRST (must be processed even when skipping, for nesting)
    if (LDirectivePrefix <> '') and (Current() = LDirectivePrefix[1]) then
    begin
      LToken.Filename := FFilename;
      LToken.Line := FLine;
      LToken.Col := FCol;
      Advance(); // skip prefix char
      // Read the directive word
      LToken.Text := '';
      while not AtEnd() and (Current().IsLetterOrDigit or (Current() = '_')) do
      begin
        LToken.Text := LToken.Text + Current();
        Advance();
      end;
      if FInterp.TokenDirectives.TryGetValue(LToken.Text, LToken.Kind) then
      begin
        // Check if this is a conditional compilation directive
        if FInterp.TokenDirectiveFlags.TryGetValue(LToken.Text, LFlag) then
        begin
          // Read symbol name for directives that need one
          if (LFlag = 'define') or (LFlag = 'undef') or
             (LFlag = 'ifdef') or (LFlag = 'ifndef') or
             (LFlag = 'elseif') or
             (LFlag = 'settarget') or (LFlag = 'setoptimize') then
          begin
            // Skip whitespace to the symbol
            while not AtEnd() and Current().IsWhiteSpace and
                  (Current() <> #10) do
              Advance();
            LSymbol := '';
            while not AtEnd() and
                  (Current().IsLetterOrDigit or (Current() = '_')) do
            begin
              LSymbol := LSymbol + Current();
              Advance();
            end;
          end;

          if LFlag = 'define' then
          begin
            if not FSkipping then
              FInterp.Defines.AddOrSetValue(LSymbol, '');
          end
          else if LFlag = 'undef' then
          begin
            if not FSkipping then
              FInterp.Defines.Remove(LSymbol);
          end
          else if LFlag = 'ifdef' then
          begin
            LEntry.ParentSkipping := FSkipping;
            LEntry.BranchTaken := False;
            if not FSkipping then
            begin
              if FInterp.Defines.ContainsKey(LSymbol) then
                LEntry.BranchTaken := True
              else
                FSkipping := True;
            end;
            FCondStack.Add(LEntry);
          end
          else if LFlag = 'ifndef' then
          begin
            LEntry.ParentSkipping := FSkipping;
            LEntry.BranchTaken := False;
            if not FSkipping then
            begin
              if not FInterp.Defines.ContainsKey(LSymbol) then
                LEntry.BranchTaken := True
              else
                FSkipping := True;
            end;
            FCondStack.Add(LEntry);
          end
          else if LFlag = 'elseif' then
          begin
            if FCondStack.Count > 0 then
            begin
              LEntry := FCondStack[FCondStack.Count - 1];
              if LEntry.ParentSkipping then
              begin
                FSkipping := True;
              end
              else if LEntry.BranchTaken then
              begin
                FSkipping := True;
              end
              else if FInterp.Defines.ContainsKey(LSymbol) then
              begin
                FSkipping := False;
                LEntry.BranchTaken := True;
                FCondStack[FCondStack.Count - 1] := LEntry;
              end
              else
                FSkipping := True;
            end;
          end
          else if LFlag = 'else' then
          begin
            if FCondStack.Count > 0 then
            begin
              LEntry := FCondStack[FCondStack.Count - 1];
              if LEntry.ParentSkipping then
                FSkipping := True
              else if LEntry.BranchTaken then
                FSkipping := True
              else
              begin
                FSkipping := False;
                LEntry.BranchTaken := True;
                FCondStack[FCondStack.Count - 1] := LEntry;
              end;
            end;
          end
          else if LFlag = 'endif' then
          begin
            if FCondStack.Count > 0 then
            begin
              LEntry := FCondStack[FCondStack.Count - 1];
              FSkipping := LEntry.ParentSkipping;
              FCondStack.Delete(FCondStack.Count - 1);
            end;
          end
          else if (LFlag = 'settarget') or (LFlag = 'setoptimize') then
          begin
            // Language-specific directives -- emit as directive + identifier tokens
            if not FSkipping then
            begin
              Result.Add(LToken);
              LIdent.Kind := 'identifier';
              LIdent.Text := LSymbol;
              LIdent.Line := LToken.Line;
              LIdent.Col := LToken.Col;
              LIdent.Filename := LToken.Filename;
              Result.Add(LIdent);
            end;
            Continue;
          end;
          // Conditional directives are consumed, not emitted
          Continue;
        end;

        // Regular directive (non-conditional) -- emit if not skipping
        if not FSkipping then
          Result.Add(LToken);
        Continue;
      end;
      // Not a registered directive -- report as error
      if not FSkipping then
      begin
        GetErrors().Add(FFilename, LToken.Line, LToken.Col, esError, ERR_LVM_LEX,
          'Unknown directive ''%s''', [LToken.Text]);
        Exit;
      end;
      Continue;
    end;

    // When skipping, consume but don't emit non-directive tokens
    if FSkipping then
    begin
      Advance();
      Continue;
    end;

    // Try string literal first (before operators, since quote might be both)
    if TryStringLiteral(LToken) then
    begin
      Result.Add(LToken);
      Continue;
    end;

    if TryNumber(LToken) then
    begin
      Result.Add(LToken);
      Continue;
    end;

    if TryOperator(LToken) then
    begin
      Result.Add(LToken);
      Continue;
    end;

    if TryIdentifier(LToken) then
    begin
      Result.Add(LToken);

      // Raw block handling: if this keyword starts a raw block, collect
      // verbatim text until the end keyword appears as a standalone word
      if FInterp.RawBlockEnds.TryGetValue(LToken.Kind, LEndWord) then
      begin
        // Skip whitespace before raw content
        SkipWhitespace();
        LRawBuf := '';
        LRawStartLine := FLine;
        LRawStartCol := FCol;
        LEndLen := Length(LEndWord);
        while not AtEnd() do
        begin
          // Check if current position starts with the end keyword
          LFoundEnd := True;
          for LRawI := 0 to LEndLen - 1 do
          begin
            if PeekAt(LRawI) <> LEndWord[LRawI + 1] then
            begin
              LFoundEnd := False;
              Break;
            end;
          end;
          // Verify end keyword is a standalone word (not part of a longer identifier)
          if LFoundEnd then
          begin
            LAfterEnd := PeekAt(LEndLen);
            if not (LAfterEnd.IsLetterOrDigit or (LAfterEnd = '_')) then
            begin
              // Trim trailing whitespace from collected text
              LRawBuf := LRawBuf.TrimRight();
              // Emit the raw block token
              Result.Add(MakeToken('rawblock', LRawBuf, LRawStartLine, LRawStartCol));
              // Emit the end keyword token
              LEndKwLine := FLine;
              LEndKwCol := FCol;
              for LRawI := 1 to LEndLen do
                Advance();
              if FInterp.TokenKeywords.TryGetValue(LEndWord, LEndKind) then
                Result.Add(MakeToken(LEndKind, LEndWord, LEndKwLine, LEndKwCol))
              else
                Result.Add(MakeToken('identifier', LEndWord, LEndKwLine, LEndKwCol));
              Break;
            end;
          end;
          LRawBuf := LRawBuf + Current();
          Advance();
        end;
      end;

      Continue;
    end;

    // Unexpected character
    GetErrors().Add(FFilename, FLine, FCol, esError, ERR_LVM_LEX,
      'Unexpected character ''%s''', [Current()]);
    Exit;
  end;

  Result.Add(MakeToken('eof', '', FLine, FCol));
end;

{ === TLVMGenericParser ===================================================== }
constructor TLVMGenericParser.Create();
begin
  inherited Create();
  FTokens := nil;
  FPos := 0;
  FFilename := '';
  FInterp := nil;
end;

destructor TLVMGenericParser.Destroy();
begin
  inherited;
end;

procedure TLVMGenericParser.Configure(const AInterp: TLangVM);
begin
  FInterp := AInterp;
end;

function TLVMGenericParser.Current(): TLVMUserToken;
begin
  if (FPos >= 0) and (FPos < FTokens.Count) then
    Result := FTokens[FPos]
  else
  begin
    Result.Kind := 'eof';
    Result.Text := '';
    Result.Line := 0;
    Result.Col := 0;
  end;
end;

function TLVMGenericParser.Peek(): TLVMUserToken;
begin
  if (FPos + 1 >= 0) and (FPos + 1 < FTokens.Count) then
    Result := FTokens[FPos + 1]
  else
  begin
    Result.Kind := 'eof';
    Result.Text := '';
    Result.Line := 0;
    Result.Col := 0;
  end;
end;

function TLVMGenericParser.PeekAt(const AOffset: Integer): TLVMUserToken;
var
  LIndex: Integer;
begin
  LIndex := FPos + AOffset;
  if (LIndex >= 0) and (LIndex < FTokens.Count) then
    Result := FTokens[LIndex]
  else
  begin
    Result.Kind := 'eof';
    Result.Text := '';
    Result.Line := 0;
    Result.Col := 0;
  end;
end;

function TLVMGenericParser.AtEnd(): Boolean;
begin
  Result := Current().Kind = 'eof';
end;

function TLVMGenericParser.Check(const AKind: string): Boolean;
begin
  Result := Current().Kind = AKind;
end;

function TLVMGenericParser.Match(const AKind: string): Boolean;
begin
  if Current().Kind = AKind then
  begin
    DoAdvance();
    Result := True;
  end
  else
    Result := False;
end;

procedure TLVMGenericParser.DoAdvance();
begin
  if FPos < FTokens.Count then
    Inc(FPos);
end;

procedure TLVMGenericParser.Expect(const AKind: string);
var
  LExpected: string;
begin
  if Current().Kind = AKind then
    DoAdvance()
  else if Assigned(FInterp) and Assigned(FInterp.GetErrors()) then
  begin
    if FInterp.TokenKindToText.TryGetValue(AKind, LExpected) then
      LExpected := '''' + LExpected + ''''
    else
      LExpected := AKind;
    FInterp.GetErrors().Add(FFilename, Current().Line, Current().Col,
      esError, 'UP001',
      'Expected %s but found ''%s''', [LExpected, Current().Text], nil);
  end;
end;

function TLVMGenericParser.GetPos(): Integer;
begin
  Result := FPos;
end;

procedure TLVMGenericParser.SetPos(const APos: Integer);
begin
  FPos := APos;
end;

function TLVMGenericParser.ParseExpression(const AMinPower: Integer): TLVMASTNode;
var
  LPrefixRule: TLVMASTNode;
  LInfixEntry: TLVMInfixEntry;
  LLeft: TLVMASTNode;
  LPrefixRules: TDictionary<string, TLVMASTNode>;
  LInfixRules: TDictionary<string, TLVMInfixEntry>;
  LCurrentKind: string;
  LSavedParser: TObject;
  LSavedPos: Integer;
  LSavedPower: Integer;
begin
  LPrefixRules := FInterp.PrefixRules;
  LInfixRules := FInterp.InfixRules;

  // Set active parser so interpreter can access us
  LSavedParser := FInterp.GetActiveParser();
  FInterp.SetActiveParser(Self);
  try
    // Prefix dispatch
    LCurrentKind := Current().Kind;

    if LPrefixRules.TryGetValue(LCurrentKind, LPrefixRule) then
    begin
      // Prefix rules (nud) parse at binding power 0
      LSavedPower := FInterp.CurrentInfixPower;
      FInterp.CurrentInfixPower := 0;
      LLeft := FInterp.ExecuteGrammarRule(LPrefixRule);
      FInterp.CurrentInfixPower := LSavedPower;
    end
    else
    begin
      if Assigned(FInterp.GetErrors()) then
        FInterp.GetErrors().Add(FFilename, Current().Line, Current().Col,
          esError, 'UP002',
          'No prefix handler for ''%s''', [Current().Text], nil);
      LLeft := TLVMASTNode.Create();
      LLeft.Kind := 'error';
      FInterp.FCreatedNodes.Add(LLeft);
      DoAdvance();
      Result := LLeft;
      Exit;
    end;

    // Infix loop
    while not AtEnd() do
    begin
      LCurrentKind := Current().Kind;

      if LInfixRules.TryGetValue(LCurrentKind, LInfixEntry) then
      begin
        // Power check
        if LInfixEntry.Assoc = 'right' then
        begin
          if LInfixEntry.Power < AMinPower then Break;
        end
        else
        begin
          if LInfixEntry.Power <= AMinPower then Break;
        end;
        LSavedPos := FPos;
        FInterp.CurrentInfixPower := LInfixEntry.Power;
        LLeft := FInterp.ExecuteGrammarRule(LInfixEntry.RuleAST, LLeft);
        FInterp.CurrentInfixPower := 0;
        if FPos = LSavedPos then Break; // stuck protection
      end
      else
        Break;
    end;

    Result := LLeft;
  finally
    FInterp.SetActiveParser(LSavedParser);
  end;
end;

function TLVMGenericParser.ParseExpressionFrom(const ALeft: TLVMASTNode;
  const AMinPower: Integer): TLVMASTNode;
var
  LInfixEntry: TLVMInfixEntry;
  LLeft: TLVMASTNode;
  LInfixRules: TDictionary<string, TLVMInfixEntry>;
  LCurrentKind: string;
  LSavedParser: TObject;
  LSavedPos: Integer;
begin
  LInfixRules := FInterp.InfixRules;
  LLeft := ALeft;

  LSavedParser := FInterp.GetActiveParser();
  FInterp.SetActiveParser(Self);
  try
    while not AtEnd() do
    begin
      LCurrentKind := Current().Kind;

      if LInfixRules.TryGetValue(LCurrentKind, LInfixEntry) then
      begin
        if LInfixEntry.Assoc = 'right' then
        begin
          if LInfixEntry.Power < AMinPower then Break;
        end
        else
        begin
          if LInfixEntry.Power <= AMinPower then Break;
        end;
        LSavedPos := FPos;
        FInterp.CurrentInfixPower := LInfixEntry.Power;
        LLeft := FInterp.ExecuteGrammarRule(LInfixEntry.RuleAST, LLeft);
        FInterp.CurrentInfixPower := 0;
        if FPos = LSavedPos then Break;
      end
      else
        Break;
    end;

    Result := LLeft;
  finally
    FInterp.SetActiveParser(LSavedParser);
  end;
end;

function TLVMGenericParser.ParseStatement(): TLVMASTNode;
var
  LStmtRules: TObjectDictionary<string, TList<TLVMASTNode>>;
  LStmtRuleList: TList<TLVMASTNode>;
  LCurrentKind: string;
  LSavedParser: TObject;
  LI: Integer;
  LSavedPos: Integer;
  LSavedItemCount: Integer;
  LSavedErrorCount: Integer;
begin
  LStmtRules := FInterp.StmtRules;
  LCurrentKind := Current().Kind;

  LSavedParser := FInterp.GetActiveParser();
  FInterp.SetActiveParser(Self);
  try
    if LStmtRules.TryGetValue(LCurrentKind, LStmtRuleList) then
    begin
      if LStmtRuleList.Count = 1 then
        Result := FInterp.ExecuteGrammarRule(LStmtRuleList[0])
      else
      begin
        // Try each rule in registration order, restore on failure
        Result := nil;
        for LI := 0 to LStmtRuleList.Count - 1 do
        begin
          LSavedPos := GetPos();
          LSavedItemCount := FInterp.GetErrors().Count();
          LSavedErrorCount := FInterp.GetErrors().ErrorCount();
          Result := FInterp.ExecuteGrammarRule(LStmtRuleList[LI]);
          if FInterp.GetErrors().ErrorCount() = LSavedErrorCount then
            Break;
          // Failed: restore position, remove items from failed attempt
          SetPos(LSavedPos);
          FInterp.GetErrors().TruncateTo(LSavedItemCount);
          Result.Free();
          Result := nil;
        end;
        // All failed: re-run last to produce the error naturally
        if Result = nil then
          Result := FInterp.ExecuteGrammarRule(
            LStmtRuleList[LStmtRuleList.Count - 1]);
      end;
    end
    else
    begin
      // Fall through to expression statement
      Result := ParseExpression(0);
      // Consume optional trailing semicolon (e.g. bare call: greet();)
      Match('delimiter.semicolon');
    end;
  finally
    FInterp.SetActiveParser(LSavedParser);
  end;
end;

function TLVMGenericParser.ParseProgram(const ATokens: TList<TLVMUserToken>;
  const AFilename: string): TLVMASTNode;
var
  LRoot: TLVMASTNode;
  LSavedPos: Integer;
begin
  FTokens := ATokens;
  FPos := 0;
  FFilename := AFilename;

  LRoot := TLVMASTNode.Create();
  LRoot.Kind := 'program.root';

  try
    while not AtEnd() do
    begin
      if Assigned(FInterp.GetErrors()) and FInterp.GetErrors().ReachedMaxErrors() then
        Break;
      LSavedPos := FPos;
      LRoot.AddChild(ParseStatement());
      // Safety: if no tokens were consumed, skip one to prevent infinite loop
      if FPos = LSavedPos then
      begin
        if Assigned(FInterp.GetErrors()) then
          FInterp.GetErrors().Add(FFilename, Current().Line, Current().Col,
            esError, 'UP004',
            'Parser stuck at token: ''%s''', [Current().Text], nil);
        DoAdvance();
      end;
    end;
  except
    on E: EStdAppException do
      ; // error already recorded, stop parsing
  end;

  Result := LRoot;
end;

{ === TLangVM =============================================================== }
class function TLangVM.ParseIntLiteral(const AText: string): Int64;
var
  LText: string;
  LI: Integer;
begin
  LText := AText;
  if LText.StartsWith('0x') or LText.StartsWith('0X') then
  begin
    LText := '$' + Copy(LText, 3, MaxInt);
    Result := StrToInt64(LText);
    Exit;
  end;
  if LText.StartsWith('0b') or LText.StartsWith('0B') then
  begin
    Result := 0;
    for LI := 3 to Length(AText) do
    begin
      Result := Result shl 1;
      if AText[LI] = '1' then
        Result := Result or 1;
    end;
    Exit;
  end;
  Result := StrToInt64(LText);
end;

constructor TLangVM.Create();
begin
  inherited;

  FBuiltins := TDictionary<string, TLVMBuiltinFunc>.Create();
  FEnvironment := TLVMEnvironment.Create();
  FEnvironment.SetErrors(FErrors);
  FLexer := TLVMLexer.Create();
  FLexer.SetErrors(FErrors);
  FParser := TLVMParser.Create();
  FParser.SetErrors(FErrors);
  FSignal := lsNone;
  FReturnValue := TLVMValue.Nil_();
  FCurrentRoutineNode := nil;

  // pipeline dispatch tables
  FSemanticHandlers := TLVMSemanticPassMap.Create([doOwnsValues]);
  FEmitterHandlers := TLVMHandlerMap.Create();
  FMirHandlers := TLVMHandlerMap.Create();
  FTargetHandlers := TDictionary<TLVMMirOpcode, TLVMASTNode>.Create();
  FTargetContext := TLVMValue.Nil_();
  FTargetContextName := '';
  FHasTarget := False;
  FGrammarRules := TLVMHandlerMap.Create();
  FPrefixRules := TDictionary<string, TLVMASTNode>.Create();
  FInfixRules := TDictionary<string, TLVMInfixEntry>.Create();
  FStmtRules := TObjectDictionary<string, TList<TLVMASTNode>>.Create([doOwnsValues]);
  FFragments := TLVMHandlerMap.Create();
  FImported := TDictionary<string, Boolean>.Create();
  FImportPaths := TStringList.Create();
  FLanguageName := '';
  FLanguageVersion := '';
  FParsedRoots := TObjectList<TLVMASTNode>.Create(True);
  FRecordDefs := TObjectDictionary<string, TLVMRecordDef>.Create([doOwnsValues]);

  // Token config
  FTokenKeywords := TDictionary<string, string>.Create();
  FTokenOperators := TList<TLVMOperatorEntry>.Create();
  FTokenStringStyles := TList<TLVMStringStyleEntry>.Create();
  FTokenLineComments := TStringList.Create();
  FTokenBlockComments := TList<TPair<string, string>>.Create();
  FTokenDirectives := TDictionary<string, string>.Create();
  FTokenDirectiveFlags := TDictionary<string, string>.Create();
  FRawBlockEnds := TDictionary<string, string>.Create();
  FTokenKindToText := TDictionary<string, string>.Create();
  FDefines := TDictionary<string, string>.Create();
  FModuleExtension := '';
  FLexerConfig.HexPrefix := TStringList.Create();
  FUserTokenLists := TObjectList<TObject>.Create(True);
  FUserASTRoots := TObjectList<TLVMASTNode>.Create(True);

  // Type config
  FTypeKeywords := TDictionary<string, string>.Create();
  FTypeMappings := TDictionary<string, string>.Create();
  FLiteralTypes := TDictionary<string, string>.Create();
  FCompatRules := TList<TLVMCompatEntry>.Create();
  FDeclKinds := TStringList.Create();
  FCallKinds := TStringList.Create();
  FCallNameAttr := '';
  FScopes := TLVMScopeManager.Create();
  FScopes.SetErrors(FErrors);
  FMirProgram := TLVMMirProgram.Create();
  FCurrentMirModule := nil;
  FCurrentMirFunc := nil;
  FMirCallArgStack := TStack<TList<TLVMMirOperand>>.Create();
  FActiveParser := nil;
  FResultNode := TLVMValue.Nil_();
  FCurrentInfixPower := 0;
  FRuleErrorSnapshot := 0;
  FFileHandles := TDictionary<Int64, TFileStream>.Create();
  FNextFileHandle := 1;
  FCreatedNodes := TObjectList<TLVMASTNode>.Create(True);
  FHostObjects := TDictionary<string, TObject>.Create();
  FSharedState := TDictionary<string, TLVMValue>.Create();
  FStateStack := TList<string>.Create();
  FSemanticDictStack := TList<TLVMHandlerMap>.Create();
  FZigBuild := TLVMZigBuild.Create();
  FZigBuild.SetErrors(FErrors);
  RegisterInternalBuiltins();

  // Well-known global environment variables
  FEnvironment.DeclareVar(LVM_EXITCODE, TLVMValue.FromInt(0), 'int');
  FEnvironment.DeclareVar(LVM_RESULT, TLVMValue.Nil_(), 'any');
  FEnvironment.DeclareVar(LVM_SRCFILE, TLVMValue.FromString(''), 'string');
  FEnvironment.DeclareVar(LVM_MAIN, TLVMValue.FromString(LVM_MAINFUNC), 'string');
  FEnvironment.DeclareVar(LVM_AUTORUN, TLVMValue.FromBool(False), 'bool');
  FEnvironment.DeclareVar(LVM_TARGET, TLVMValue.FromString(''), 'string');
  FEnvironment.DeclareVar(LVM_OUTPUTPATH, TLVMValue.FromString(''), 'string');
  FEnvironment.DeclareVar(LVM_SUBSYSTEM, TLVMValue.FromString(''), 'string');
  FEnvironment.DeclareVar(LVM_OPTLEVEL, TLVMValue.FromString(''), 'string');
end;

procedure TLangVM.SetStatusCallback(const ACallback: TStatusCallback;
  const AUserData: Pointer);
begin
  //inherited SetStatusCallback(ACallback, AUserData);
  inherited;
  if Assigned(FLexer) then FLexer.SetStatusCallback(ACallback, AUserData);
  if Assigned(FParser) then FParser.SetStatusCallback(ACallback, AUserData);
  if Assigned(FEnvironment) then FEnvironment.SetStatusCallback(ACallback, AUserData);
  if Assigned(FScopes) then FScopes.SetStatusCallback(ACallback, AUserData);
  if Assigned(FZigBuild) then FZigBuild.SetStatusCallback(ACallback, AUserData);
end;

destructor TLangVM.Destroy();
var
  LStream: TFileStream;
begin
  for LStream in FFileHandles.Values do
    LStream.Free();
  FFileHandles.Free();
  FImported.Free();
  FImportPaths.Free();
  FFragments.Free();
  FStmtRules.Free();
  FInfixRules.Free();
  FPrefixRules.Free();
  FGrammarRules.Free();
  FMirHandlers.Free();
  FTargetHandlers.Free();
  FEmitterHandlers.Free();
  FSemanticHandlers.Free();
  FRecordDefs.Free();

  // Token config
  FTokenKeywords.Free();
  FTokenOperators.Free();
  FTokenStringStyles.Free();
  FTokenLineComments.Free();
  FTokenBlockComments.Free();
  FTokenDirectives.Free();
  FTokenDirectiveFlags.Free();
  FRawBlockEnds.Free();
  FTokenKindToText.Free();
  FDefines.Free();
  FLexerConfig.HexPrefix.Free();
  FUserTokenLists.Free();
  FUserASTRoots.Free();

  // Type config
  FTypeKeywords.Free();
  FTypeMappings.Free();
  FLiteralTypes.Free();
  FCompatRules.Free();
  FDeclKinds.Free();
  FCallKinds.Free();
  FScopes.Free();
  FMirProgram.Free();
  FMirCallArgStack.Free();
  FCreatedNodes.Free();
  FHostObjects.Free();
  FZigBuild.Free();
  FSharedState.Free();
  FStateStack.Free();
  FSemanticDictStack.Free();
  FParsedRoots.Free();
  FParser.Free();
  FLexer.Free();
  FEnvironment.Free();
  FBuiltins.Free();
  inherited Destroy();
end;

procedure TLangVM.RegisterBuiltin(const AName: string; const AFunc: TLVMBuiltinFunc);
begin
  FBuiltins.AddOrSetValue(AName, AFunc);
end;

function TLangVM.CallBuiltin(const AName: string; const AArgs: TArray<TLVMValue>): TLVMValue;
var
  LFunc: TLVMBuiltinFunc;
  LErrorCount: Integer;
begin
  if FBuiltins.TryGetValue(AName, LFunc) then
  begin
    LErrorCount := GetErrors().GetItems().Count;
    Result := LFunc(AArgs, Self);
    // If the builtin added errors via FErrors.Add()+Exit, raise so
    // try/recover can catch it
    if GetErrors().GetItems().Count > LErrorCount then
      raise EStdAppException.Create(GetErrors().GetItems().Last);
  end
  else
    raise Exception.CreateFmt('Unknown builtin: %s', [AName]);
end;

function TLangVM.HasBuiltin(const AName: string): Boolean;
begin
  Result := FBuiltins.ContainsKey(AName);
end;

procedure TLangVM.ExecBlock(const ANode: TLVMASTNode);
var
  LI: Integer;
begin
  if ANode = nil then
    Exit;

  for LI := 0 to ANode.ChildCount() - 1 do
  begin
    if FSignal <> lsNone then
      Exit;
    if GetErrors().HasErrors() then
      Exit;
    ExecStmt(TLVMASTNode(ANode.Children[LI]));
  end;
end;

procedure TLangVM.ExecStmt(const ANode: TLVMASTNode);
var
  LKind: string;
  LName: string;
  LVal: TLVMValue;
  LCond: TLVMValue;
  LIter: TLVMValue;
  LList: TLVMListStore;
  LMap: TLVMMapStore;
  LBranch: TLVMASTNode;
  LArm: TLVMASTNode;
  LSubject: TLVMValue;
  LPattern: TLVMValue;
  LMatched: Boolean;
  LI: Integer;
  LJ: Integer;
  LIterCount: Integer;
  LKey: string;
  LKeys: TArray<string>;
  LResult: TLVMValue;
  LScopeName: string;
  LSym: TLVMSymbol;
  LTarget: TLVMValue;
  LIndex: TLVMValue;
  LIdx: Integer;
  LSeverity: string;
  LMessage: string;
  LTokenKind: string;
  LAttrName: string;
  LKindsArr: TArray<string>;
  LFound: Boolean;
  LSavedPos: Integer;
  LUpdateResult: TUpdateVarResult;
begin
  if (ANode = nil) or (FSignal <> lsNone) then
    Exit;

  LKind := ANode.Kind;

  // -- let: declare variable in current scope --
  if LKind = 'let_stmt' then
  begin
    LName := ANode.GetAttr('name');
    LVal := EvalExpr(TLVMASTNode(ANode.Children[0]));
    if not FEnvironment.DeclareVar(LName, LVal, ANode.GetAttr('type')) then
    begin
      GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
        ERR_LVM_REDECLARE, RSLVMVarRedeclared,
        [LName]);
      Exit;
    end;
    Exit;
  end;

  // -- assign: update existing variable --
  if LKind = 'assign_stmt' then
  begin
    LName := ANode.GetAttr('name');
    LVal := EvalExpr(TLVMASTNode(ANode.Children[0]));
    LUpdateResult := FEnvironment.UpdateVar(LName, LVal);
    if LUpdateResult = uvrNotFound then
    begin
      GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
        ERR_LVM_UNDECLARED, RSLVMVarUndeclared, [LName]);
      Exit;
    end
    else if LUpdateResult = uvrTypeMismatch then
    begin
      GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
        ERR_LVM_TYPE, RSLVMTypeMismatch,
        [LName]);
      Exit;
    end;
    Exit;
  end;

  // -- expression-based assignment: target.field = value or target[index] = value --
  if LKind = 'assign_expr_stmt' then
  begin
    LVal := EvalExpr(TLVMASTNode(ANode.Children[1])); // RHS value
    // Walk the LHS to find assignment target
    LBranch := TLVMASTNode(ANode.Children[0]);
    if LBranch.Kind = 'expr.dot' then
    begin
      LTarget := EvalExpr(TLVMASTNode(LBranch.Children[0]));
      LName := LBranch.GetAttr('name');
      if LTarget.Kind <> vkMap then
      begin
        GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
          ERR_LVM_ASSIGN, RSLVMCannotAssignField,
          [LName, LTarget.KindName()]);
        Exit;
      end;
      LMap := LTarget.AsMap();
      if (LMap.TypeName <> '') and (FRecordDefs.ContainsKey(LMap.TypeName)) then
      begin
        if not FRecordDefs[LMap.TypeName].HasField(LName) then
        begin
          GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
            ERR_LVM_FIELD, RSLVMNoSuchField,
            [LMap.TypeName, LName]);
          Exit;
        end;
      end;
      LMap.AddOrSetValue(LName, LVal);
      Exit;
    end
    else if LBranch.Kind = 'expr.index' then
    begin
      LTarget := EvalExpr(TLVMASTNode(LBranch.Children[0]));
      LIndex := EvalExpr(TLVMASTNode(LBranch.Children[1]));
      if LTarget.Kind = vkList then
      begin
        LIdx := Integer(LIndex.AsInt());
        LList := LTarget.AsList();
        if (LIdx < 0) or (LIdx >= LList.Count) then
        begin
          GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
            ERR_LVM_INDEX, RSLVMListIndexBounds, [LIdx]);
          Exit;
        end;
        LList[LIdx] := LVal;
        Exit;
      end;
      if LTarget.Kind = vkMap then
      begin
        LTarget.AsMap().AddOrSetValue(LIndex.AsString(), LVal);
        Exit;
      end;
      GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
        ERR_LVM_ASSIGN, RSLVMCannotAssignIndex,
        [LTarget.KindName()]);
      Exit;
    end;
    GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
      ERR_LVM_ASSIGN, RSLVMInvalidAssignTarget,
      [LBranch.Kind]);
    Exit;
  end;

  // -- expression statement (bare call) --
  if LKind = 'expr_stmt' then
  begin
    EvalExpr(TLVMASTNode(ANode.Children[0]));
    Exit;
  end;

  // -- if / else if / else --
  if LKind = 'if_stmt' then
  begin
    for LI := 0 to ANode.ChildCount() - 1 do
    begin
      LBranch := TLVMASTNode(ANode.Children[LI]);

      if LBranch.Kind = 'else_branch' then
      begin
        // Else has only body as child[0]
        FEnvironment.PushScope();
        try
          ExecBlock(TLVMASTNode(LBranch.Children[0]));
        finally
          FEnvironment.PopScope();
        end;
        Exit;
      end;

      // if_branch or elseif_branch: child[0]=condition, child[1]=body
      LCond := EvalExpr(TLVMASTNode(LBranch.Children[0]));
      if LCond.IsTrue() then
      begin
        FEnvironment.PushScope();
        try
          ExecBlock(TLVMASTNode(LBranch.Children[1]));
        finally
          FEnvironment.PopScope();
        end;
        Exit;
      end;
    end;
    Exit;
  end;

  // -- while --
  if LKind = 'while_stmt' then
  begin
    LIterCount := 0;
    while True do
    begin
      LCond := EvalExpr(TLVMASTNode(ANode.Children[0]));
      if not LCond.IsTrue() then
        Break;

      FEnvironment.PushScope();
      try
        ExecBlock(TLVMASTNode(ANode.Children[1]));
      finally
        FEnvironment.PopScope();
      end;

      if FSignal = lsBreak then
      begin
        FSignal := lsNone;
        Break;
      end;
      if FSignal = lsContinue then
        FSignal := lsNone;
      if FSignal = lsReturn then
        Exit;

      Inc(LIterCount);
      if LIterCount > 1000000 then
      begin
        GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
          ERR_LVM_LIMIT, RSLVMWhileLimit);
        Exit;
      end;
    end;
    Exit;
  end;

  // -- for var in iterable --
  if LKind = 'for_stmt' then
  begin
    LName := ANode.GetAttr('var');
    LIter := EvalExpr(TLVMASTNode(ANode.Children[0]));

    if LIter.Kind = vkList then
    begin
      LList := LIter.AsList();
      for LI := 0 to LList.Count - 1 do
      begin
        FEnvironment.ForceSetVar(LName, LList[LI]);
        FEnvironment.PushScope();
        try
          ExecBlock(TLVMASTNode(ANode.Children[1]));
        finally
          FEnvironment.PopScope();
        end;

        if FSignal = lsBreak then
        begin
          FSignal := lsNone;
          Break;
        end;
        if FSignal = lsContinue then
          FSignal := lsNone;
        if FSignal = lsReturn then
          Exit;
      end;
    end
    else if LIter.Kind = vkMap then
    begin
      LMap := LIter.AsMap();
      LKeys := LMap.Keys.ToArray();
      for LI := 0 to Length(LKeys) - 1 do
      begin
        FEnvironment.ForceSetVar(LName, TLVMValue.FromString(LKeys[LI]));
        FEnvironment.PushScope();
        try
          ExecBlock(TLVMASTNode(ANode.Children[1]));
        finally
          FEnvironment.PopScope();
        end;

        if FSignal = lsBreak then
        begin
          FSignal := lsNone;
          Break;
        end;
        if FSignal = lsContinue then
          FSignal := lsNone;
        if FSignal = lsReturn then
          Exit;
      end;
    end
    else if LIter.Kind = vkString then
    begin
      LKey := LIter.AsString();
      for LI := 1 to Length(LKey) do
      begin
        FEnvironment.ForceSetVar(LName, TLVMValue.FromString(LKey[LI]));
        FEnvironment.PushScope();
        try
          ExecBlock(TLVMASTNode(ANode.Children[1]));
        finally
          FEnvironment.PopScope();
        end;

        if FSignal = lsBreak then
        begin
          FSignal := lsNone;
          Break;
        end;
        if FSignal = lsContinue then
          FSignal := lsNone;
        if FSignal = lsReturn then
          Exit;
      end;
    end
    else
    begin
      GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
        ERR_LVM_ITERATION, RSLVMCannotIterate,
        [LIter.KindName()]);
      Exit;
    end;
    Exit;
  end;

  // -- match --
  if LKind = 'match_stmt' then
  begin
    LSubject := EvalExpr(TLVMASTNode(ANode.Children[0]));
    LMatched := False;

    // Arms start at child index 1
    for LI := 1 to ANode.ChildCount() - 1 do
    begin
      LArm := TLVMASTNode(ANode.Children[LI]);

      if LArm.Kind = 'match_else' then
      begin
        FEnvironment.PushScope();
        try
          ExecBlock(TLVMASTNode(LArm.Children[0]));
        finally
          FEnvironment.PopScope();
        end;
        Break;
      end;

      // match_arm: patterns are all children except the last (which is body)
      for LJ := 0 to LArm.ChildCount() - 2 do
      begin
        LPattern := EvalExpr(TLVMASTNode(LArm.Children[LJ]));
        if LSubject.ToString() = LPattern.ToString() then
        begin
          LMatched := True;
          Break;
        end;
      end;

      if LMatched then
      begin
        // Body is the last child
        FEnvironment.PushScope();
        try
          ExecBlock(TLVMASTNode(LArm.Children[LArm.ChildCount() - 1]));
        finally
          FEnvironment.PopScope();
        end;
        Break;
      end;
    end;
    Exit;
  end;

  // -- guard: if condition fails, execute body (early exit pattern) --
  if LKind = 'guard_stmt' then
  begin
    LCond := EvalExpr(TLVMASTNode(ANode.Children[0]));
    if not LCond.IsTrue() then
    begin
      FEnvironment.PushScope();
      try
        ExecBlock(TLVMASTNode(ANode.Children[1]));
      finally
        FEnvironment.PopScope();
      end;
    end;
    Exit;
  end;

  // -- return --
  if LKind = 'return_stmt' then
  begin
    if ANode.ChildCount() > 0 then
    begin
      // Returning a value -- routine must declare a return type
      if Assigned(FCurrentRoutineNode) and
         (FCurrentRoutineNode.GetAttr('return_type') = '') then
      begin
        GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
          ERR_LVM_RETURN, RSLVMReturnWithValue,
          [FCurrentRoutineNode.GetAttr('name')]);
        Exit;
      end;
      FReturnValue := EvalExpr(TLVMASTNode(ANode.Children[0]));
    end
    else
    begin
      // Bare return -- routine must NOT declare a return type
      if Assigned(FCurrentRoutineNode) and
         (FCurrentRoutineNode.GetAttr('return_type') <> '') then
      begin
        GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
          ERR_LVM_RETURN, RSLVMBareReturn,
          [FCurrentRoutineNode.GetAttr('name'),
           FCurrentRoutineNode.GetAttr('return_type')]);
        Exit;
      end;
      FReturnValue := TLVMValue.Nil_();
    end;
    FSignal := lsReturn;
    Exit;
  end;

  // -- break --
  if LKind = 'break_stmt' then
  begin
    FSignal := lsBreak;
    Exit;
  end;

  // -- continue --
  if LKind = 'continue_stmt' then
  begin
    FSignal := lsContinue;
    Exit;
  end;

  // -- try / recover --
  if LKind = 'try_recover' then
  begin
    FEnvironment.PushScope();
    try
      try
        ExecBlock(TLVMASTNode(ANode.Children[0]));
      except
        on E: Exception do
        begin
          if E is EStdAppException then
            GetErrors().RaiseOnError := False;
          // Error was recovered -- clear FErrors so HasErrors is clean
          GetErrors().Clear();
          // Reset signal on recover
          FSignal := lsNone;
          // Make error message available as 'error' variable
          FEnvironment.ForceSetVar('error', TLVMValue.FromString(E.Message));
          FEnvironment.PushScope();
          try
            ExecBlock(TLVMASTNode(ANode.Children[1]));
          finally
            FEnvironment.PopScope();
          end;
        end;
      end;
    finally
      FEnvironment.PopScope();
    end;
    Exit;
  end;

  // -- diag (error/warning/hint/note/info) --
  if LKind = 'diag_stmt' then
  begin
    LSeverity := ANode.GetAttr('severity');
    if ANode.ChildCount() > 0 then
      LMessage := EvalExpr(TLVMASTNode(ANode.Children[0])).ToString()
    else
      LMessage := '';
    if FOnDiag.IsAssigned() then
      FOnDiag.Callback(LSeverity, LMessage, ANode.Filename, ANode.Line,
        ANode.Col, FOnDiag.UserData)
    else if LSeverity = 'error' then
    begin
      GetErrors().RaiseOnError := True;
      GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
        ERR_LVM_USER, LMessage);
      // Never reaches here -- Add raised EStdAppException
    end;
    Exit;
  end;

  // -- stmt_block (nested block) --
  if LKind = 'stmt_block' then
  begin
    ExecBlock(ANode);
    Exit;
  end;

  // -- Declarative forms (Atom 12) --
  // Each form delegates to host-registered builtins. The host wires these
  // builtins when it sets up the LVM for a particular language.

  if LKind = 'expect_stmt' then
  begin
    // expect token_ref; -- verify current token matches and advance
    LTokenKind := ANode.GetAttr('token_ref');
    if LTokenKind.Contains(',') then
    begin
      // Multiple acceptable kinds: check each
      LKindsArr := LTokenKind.Split([',']);
      LFound := False;
      for LJ := 0 to Length(LKindsArr) - 1 do
      begin
        if CallBuiltin('checkToken',
             [TLVMValue.FromString(Trim(LKindsArr[LJ]))]).IsTrue() then
        begin
          LFound := True;
          Break;
        end;
      end;
      if LFound then
        CallBuiltin('advance', [])
      else
        CallBuiltin('requireToken', [TLVMValue.FromString(Trim(LKindsArr[0]))]);
    end
    else
      CallBuiltin('requireToken', [TLVMValue.FromString(LTokenKind)]);
    Exit;
  end;

  if LKind = 'consume_stmt' then
  begin
    // consume token_ref -> @target; -- capture text, store on result node
    LTokenKind := ANode.GetAttr('token_ref');
    LAttrName := ANode.GetAttr('target');
    if LTokenKind.Contains(',') then
    begin
      // Multiple acceptable kinds
      LKindsArr := LTokenKind.Split([',']);
      LFound := False;
      for LJ := 0 to Length(LKindsArr) - 1 do
      begin
        if CallBuiltin('checkToken',
             [TLVMValue.FromString(Trim(LKindsArr[LJ]))]).IsTrue() then
        begin
          LFound := True;
          Break;
        end;
      end;
      if LFound then
      begin
        LResult := CallBuiltin('currentText', []);
        CallBuiltin('advance', []);
        if not FResultNode.IsNil() then
          TLVMASTNode(FResultNode.AsHandle()).SetAttr(LAttrName, LResult.AsString());
      end;
    end
    else
    begin
      if CallBuiltin('checkToken',
           [TLVMValue.FromString(LTokenKind)]).IsTrue() then
      begin
        LResult := CallBuiltin('currentText', []);
        CallBuiltin('advance', []);
        if not FResultNode.IsNil() then
          TLVMASTNode(FResultNode.AsHandle()).SetAttr(LAttrName, LResult.AsString());
      end;
    end;
    Exit;
  end;

  if LKind = 'parse_directive' then
  begin
    LResult := CallBuiltin('parseDirective', [
      TLVMValue.FromString(ANode.GetAttr('mode')),
      TLVMValue.FromString(ANode.GetAttr('until_ref')),
      TLVMValue.FromString(ANode.GetAttr('target'))]);
    // Store parsed result as attribute on current node
    if FCurrentNode.Kind <> vkNil then
      CallBuiltin('setAttr', [FCurrentNode,
        TLVMValue.FromString(ANode.GetAttr('target')), LResult]);
    Exit;
  end;

  if LKind = 'optional_block' then
  begin
    if Assigned(FActiveParser) then
    begin
      LSavedPos := TLVMGenericParser(FActiveParser).GetPos();
      try
        if ANode.ChildCount() > 0 then
          ExecBlock(TLVMASTNode(ANode.Children[0]));
      except
        on E: Exception do
        begin
          // Parse failed, restore parser position and silently ignore
          TLVMGenericParser(FActiveParser).SetPos(LSavedPos);
          // Re-propagate signal-driven control flow
          if FSignal <> lsNone then
            raise;
        end;
      end;
    end
    else if ANode.ChildCount() > 0 then
    begin
      try
        ExecBlock(TLVMASTNode(ANode.Children[0]));
      except
        on E: Exception do
        begin
          if FSignal <> lsNone then
            raise;
          // Optional block failed without parser, silently ignore
        end;
      end;
    end;
    Exit;
  end;

  if LKind = 'sync_stmt' then
  begin
    // Error recovery: skip tokens until sync point when errors occurred
    if Assigned(FActiveParser) and Assigned(GetErrors()) and
       (GetErrors().ErrorCount() > FRuleErrorSnapshot) then
    begin
      LTokenKind := ANode.GetAttr('token_ref');
      // Skip tokens until we find the sync point
      while not TLVMGenericParser(FActiveParser).AtEnd() do
      begin
        if TLVMGenericParser(FActiveParser).Check(LTokenKind) then Break;
        TLVMGenericParser(FActiveParser).DoAdvance();
      end;
      // Consume the sync token itself
      if not TLVMGenericParser(FActiveParser).AtEnd() then
        TLVMGenericParser(FActiveParser).DoAdvance();
    end;
    if ANode.ChildCount() > 0 then
      ExecBlock(TLVMASTNode(ANode.Children[0]));
    Exit;
  end;

  if LKind = 'scope_block' then
  begin
    // Push scope with name from literal attr or from current node's attr
    if ANode.HasAttr('scope_name') then
      FScopes.Push(ANode.GetAttr('scope_name'))
    else if ANode.HasAttr('scope_attr') then
      FScopes.Push(TLVMASTNode(FCurrentNode.AsHandle()).GetAttr(
        ANode.GetAttr('scope_attr')))
    else
      FScopes.Push('');
    try
      ExecBlock(TLVMASTNode(ANode.Children[0]));
    finally
      FScopes.Pop();
    end;
    Exit;
  end;

  if LKind = 'declare_stmt' then
  begin
    // declare @attr as kind [typed @typed_attr]
    LScopeName := TLVMASTNode(FCurrentNode.AsHandle()).GetAttr(
      ANode.GetAttr('attr'));
    FScopes.Declare(LScopeName, ANode.GetAttr('symbol_kind'),
      TLVMASTNode(FCurrentNode.AsHandle()));
    // Set type name if typed_attr specified
    if ANode.HasAttr('typed_attr') then
    begin
      LSym := FScopes.Lookup(LScopeName);
      if LSym <> nil then
        LSym.TypeName := TLVMASTNode(FCurrentNode.AsHandle()).GetAttr(
          ANode.GetAttr('typed_attr'));
    end;
    Exit;
  end;

  if LKind = 'visit_stmt' then
  begin
    DoExecVisitStmt(ANode);
    Exit;
  end;

  if LKind = 'lookup_stmt' then
  begin
    LScopeName := TLVMASTNode(FCurrentNode.AsHandle()).GetAttr(
      ANode.GetAttr('attr'));
    LSym := FScopes.Lookup(LScopeName);
    if LSym <> nil then
    begin
      // Build a map with symbol info
      LResult := TLVMValue.FromMap();
      LResult.AsMap().AddOrSetValue('name', TLVMValue.FromString(LSym.SymName));
      LResult.AsMap().AddOrSetValue('kind', TLVMValue.FromString(LSym.SymKind));
      LResult.AsMap().AddOrSetValue('type', TLVMValue.FromString(LSym.TypeName));
      if LSym.DeclNode <> nil then
        LResult.AsMap().AddOrSetValue('node', TLVMValue.FromHandle(LSym.DeclNode));
    end
    else
      LResult := TLVMValue.Nil_();
    if ANode.HasAttr('bind') then
    begin
      // lookup @attr -> let varname
      FEnvironment.ForceSetVar(ANode.GetAttr('bind'), LResult);
    end
    else if (LResult.Kind = vkNil) and (ANode.ChildCount() > 0) then
    begin
      // lookup @attr or { fallback block }
      ExecBlock(TLVMASTNode(ANode.Children[0]));
    end;
    Exit;
  end;

  if LKind = 'section_block' then
  begin
    CallBuiltin('beginSection', [TLVMValue.FromString(ANode.GetAttr('name'))]);
    try
      ExecBlock(TLVMASTNode(ANode.Children[0]));
    finally
      CallBuiltin('endSection', []);
    end;
    Exit;
  end;

  if LKind = 'import_stmt' then
  begin
    WalkImport(ANode);
    Exit;
  end;

  raise Exception.CreateFmt('ExecStmt: unknown node kind "%s" at %s(%d:%d)',
    [LKind, ANode.Filename, ANode.Line, ANode.Col]);
end;

function TLangVM.EvalExpr(const ANode: TLVMASTNode): TLVMValue;
var
  LKind: string;
  LOp: string;
  LLeft: TLVMValue;
  LRight: TLVMValue;
  LOperand: TLVMValue;
  LTarget: TLVMValue;
  LIndex: TLVMValue;
  LArgs: TArray<TLVMValue>;
  LList: TLVMListStore;
  LMap: TLVMMapStore;
  LName: string;
  LIdx: Integer;
  LI: Integer;
  LCallee: TLVMASTNode;
  LRoutineNode: TLVMASTNode;
  LParamNode: TLVMASTNode;
  LParamType: string;
  LBodyIdx: Integer;
  LRecordDef: TLVMRecordDef;
  LSavedRoutineNode: TLVMASTNode;
begin
  if ANode = nil then
  begin
    Result := TLVMValue.Nil_();
    Exit;
  end;

  LKind := ANode.Kind;

  // Literals
  if LKind = 'expr.int' then
  begin
    Result := TLVMValue.FromInt(ParseIntLiteral(ANode.GetAttr('value')));
    Exit;
  end;

  if LKind = 'expr.float' then
  begin
    Result := TLVMValue.FromFloat(StrToFloat(ANode.GetAttr('value')));
    Exit;
  end;

  if LKind = 'expr.string' then
  begin
    Result := TLVMValue.FromString(Interpolate(ANode.GetAttr('value')));
    Exit;
  end;

  if LKind = 'expr.triplestring' then
  begin
    Result := TLVMValue.FromString(TrimCommonIndent(ANode.GetAttr('value')));
    Exit;
  end;

  if LKind = 'expr.bool' then
  begin
    Result := TLVMValue.FromBool(ANode.GetAttr('value') = 'true');
    Exit;
  end;

  if LKind = 'expr.nil' then
  begin
    Result := TLVMValue.Nil_();
    Exit;
  end;

  // Identifier (variable lookup)
  if LKind = 'expr.ident' then
  begin
    LName := ANode.GetAttr('name');
    if not FEnvironment.TryGetVar(LName, Result) then
    begin
      GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
        ERR_LVM_UNDEFINED, RSLVMUndefVar, [LName]);
      Result := TLVMValue.Nil_();
      Exit;
    end;
    Exit;
  end;

  // Attribute access (@name)
  if LKind = 'expr.attr' then
  begin
    Result := TLVMValue.FromString(ANode.GetAttr('name'));
    Exit;
  end;

  // Unary operators
  if LKind = 'expr.unary' then
  begin
    LOp := ANode.GetAttr('op');
    LOperand := EvalExpr(TLVMASTNode(ANode.Children[0]));

    if LOp = 'not' then
    begin
      Result := TLVMValue.FromBool(not LOperand.IsTrue());
      Exit;
    end;

    if LOp = '-' then
    begin
      if LOperand.Kind = vkFloat then
        Result := TLVMValue.FromFloat(-LOperand.AsFloat())
      else
        Result := TLVMValue.FromInt(-LOperand.AsInt());
      Exit;
    end;

    GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
      ERR_LVM_OPERATOR, RSLVMUnknownUnaryOp, [LOp]);
    Result := TLVMValue.Nil_();
    Exit;
  end;

  // Binary operators
  if LKind = 'expr.binary' then
  begin
    LOp := ANode.GetAttr('op');

    // Short-circuit for logical operators
    if LOp = 'and' then
    begin
      LLeft := EvalExpr(TLVMASTNode(ANode.Children[0]));
      if not LLeft.IsTrue() then
        Result := TLVMValue.FromBool(False)
      else
        Result := TLVMValue.FromBool(EvalExpr(TLVMASTNode(ANode.Children[1])).IsTrue());
      Exit;
    end;

    if LOp = 'or' then
    begin
      LLeft := EvalExpr(TLVMASTNode(ANode.Children[0]));
      if LLeft.IsTrue() then
        Result := TLVMValue.FromBool(True)
      else
        Result := TLVMValue.FromBool(EvalExpr(TLVMASTNode(ANode.Children[1])).IsTrue());
      Exit;
    end;

    // Evaluate both sides for non-short-circuit ops
    LLeft := EvalExpr(TLVMASTNode(ANode.Children[0]));
    LRight := EvalExpr(TLVMASTNode(ANode.Children[1]));

    // String concatenation
    if (LOp = '+') and ((LLeft.Kind = vkString) or (LRight.Kind = vkString)) then
    begin
      Result := TLVMValue.FromString(LLeft.ToString() + LRight.ToString());
      Exit;
    end;

    // List concatenation
    if (LOp = '+') and (LLeft.Kind = vkList) and (LRight.Kind = vkList) then
    begin
      Result := TLVMValue.FromList();
      LList := Result.AsList();
      for LI := 0 to LLeft.AsList().Count - 1 do
        LList.Add(LLeft.AsList()[LI]);
      for LI := 0 to LRight.AsList().Count - 1 do
        LList.Add(LRight.AsList()[LI]);
      Exit;
    end;

    // Float arithmetic if either side is float
    if (LLeft.Kind = vkFloat) or (LRight.Kind = vkFloat) then
    begin
      if LOp = '+' then begin Result := TLVMValue.FromFloat(LLeft.AsFloat() + LRight.AsFloat()); Exit; end;
      if LOp = '-' then begin Result := TLVMValue.FromFloat(LLeft.AsFloat() - LRight.AsFloat()); Exit; end;
      if LOp = '*' then begin Result := TLVMValue.FromFloat(LLeft.AsFloat() * LRight.AsFloat()); Exit; end;
      if LOp = '/' then begin Result := TLVMValue.FromFloat(LLeft.AsFloat() / LRight.AsFloat()); Exit; end;
      if LOp = '==' then begin Result := TLVMValue.FromBool(LLeft.AsFloat() = LRight.AsFloat()); Exit; end;
      if LOp = '!=' then begin Result := TLVMValue.FromBool(LLeft.AsFloat() <> LRight.AsFloat()); Exit; end;
      if LOp = '<' then begin Result := TLVMValue.FromBool(LLeft.AsFloat() < LRight.AsFloat()); Exit; end;
      if LOp = '>' then begin Result := TLVMValue.FromBool(LLeft.AsFloat() > LRight.AsFloat()); Exit; end;
      if LOp = '<=' then begin Result := TLVMValue.FromBool(LLeft.AsFloat() <= LRight.AsFloat()); Exit; end;
      if LOp = '>=' then begin Result := TLVMValue.FromBool(LLeft.AsFloat() >= LRight.AsFloat()); Exit; end;
    end;

    // Integer arithmetic
    if LOp = '+' then begin Result := TLVMValue.FromInt(LLeft.AsInt() + LRight.AsInt()); Exit; end;
    if LOp = '-' then begin Result := TLVMValue.FromInt(LLeft.AsInt() - LRight.AsInt()); Exit; end;
    if LOp = '*' then begin Result := TLVMValue.FromInt(LLeft.AsInt() * LRight.AsInt()); Exit; end;
    if LOp = '/' then begin Result := TLVMValue.FromInt(LLeft.AsInt() div LRight.AsInt()); Exit; end;
    if LOp = '%' then begin Result := TLVMValue.FromInt(LLeft.AsInt() mod LRight.AsInt()); Exit; end;
    if LOp = 'shl' then begin Result := TLVMValue.FromInt(LLeft.AsInt() shl Integer(LRight.AsInt())); Exit; end;
    if LOp = 'shr' then begin Result := TLVMValue.FromInt(LLeft.AsInt() shr Integer(LRight.AsInt())); Exit; end;

    // Comparison -- works for int, string, bool via ToString
    if LOp = '==' then begin Result := TLVMValue.FromBool(LLeft.ToString() = LRight.ToString()); Exit; end;
    if LOp = '!=' then begin Result := TLVMValue.FromBool(LLeft.ToString() <> LRight.ToString()); Exit; end;

    // Ordered comparison -- string-aware fallback
    if (LLeft.Kind = vkString) or (LRight.Kind = vkString) then
    begin
      if LOp = '<' then begin Result := TLVMValue.FromBool(LLeft.ToString() < LRight.ToString()); Exit; end;
      if LOp = '>' then begin Result := TLVMValue.FromBool(LLeft.ToString() > LRight.ToString()); Exit; end;
      if LOp = '<=' then begin Result := TLVMValue.FromBool(LLeft.ToString() <= LRight.ToString()); Exit; end;
      if LOp = '>=' then begin Result := TLVMValue.FromBool(LLeft.ToString() >= LRight.ToString()); Exit; end;
    end;

    if LOp = '<' then begin Result := TLVMValue.FromBool(LLeft.AsInt() < LRight.AsInt()); Exit; end;
    if LOp = '>' then begin Result := TLVMValue.FromBool(LLeft.AsInt() > LRight.AsInt()); Exit; end;
    if LOp = '<=' then begin Result := TLVMValue.FromBool(LLeft.AsInt() <= LRight.AsInt()); Exit; end;
    if LOp = '>=' then begin Result := TLVMValue.FromBool(LLeft.AsInt() >= LRight.AsInt()); Exit; end;

    GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
      ERR_LVM_OPERATOR, RSLVMUnknownBinaryOp, [LOp]);
    Result := TLVMValue.Nil_();
    Exit;
  end;

  // Function/builtin call
  if LKind = 'expr.call' then
  begin
    // Child 0 = callee expression, children 1+ = arguments
    LCallee := TLVMASTNode(ANode.Children[0]);

    // Evaluate arguments (children 1+)
    SetLength(LArgs, ANode.ChildCount() - 1);
    for LI := 1 to ANode.ChildCount() - 1 do
      LArgs[LI - 1] := EvalExpr(TLVMASTNode(ANode.Children[LI]));

    // Resolve callee by kind
    if LCallee.Kind = 'expr.ident' then
    begin
      LName := LCallee.GetAttr('name');

      // Try record construction first
      if FRecordDefs.TryGetValue(LName, LRecordDef) then
      begin
        Result := LRecordDef.CreateInstance();
        Exit;
      end;

      // Try builtin
      if HasBuiltin(LName) then
      begin
        Result := CallBuiltin(LName, LArgs);
        Exit;
      end;

      // Try user-defined routine variable
      if FEnvironment.TryGetVar(LName, LTarget) then
      begin
        if LTarget.Kind = vkRoutine then
        begin
          LRoutineNode := TLVMASTNode(LTarget.AsRoutine());
          LBodyIdx := LRoutineNode.ChildCount() - 1;
          FEnvironment.PushScope();
          try
            for LI := 0 to LBodyIdx - 1 do
            begin
              LParamNode := TLVMASTNode(LRoutineNode.Children[LI]);
              LParamType := LParamNode.GetAttr('type');
              if LI < Length(LArgs) then
              begin
                if (LParamType <> '') and (LParamType <> 'any') and (LArgs[LI].Kind <> vkNil) and
                   (not TLVMValue.KindMatchesType(LArgs[LI], LParamType)) then
                begin
                  GetErrors().RaiseOnError := True;
                  GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
                    ERR_LVM_TYPE, RSLVMArgTypeMismatch,
                    [LI + 1, LParamType, LArgs[LI].KindName()]);
                end;
                FEnvironment.ForceSetVar(LParamNode.GetAttr('name'), LArgs[LI], LParamType);
              end
              else
                FEnvironment.ForceSetVar(LParamNode.GetAttr('name'), TLVMValue.Nil_(), LParamType);
            end;
            LSavedRoutineNode := FCurrentRoutineNode;
            FCurrentRoutineNode := LRoutineNode;
            FSignal := lsNone;
            ExecBlock(TLVMASTNode(LRoutineNode.Children[LBodyIdx]));
            FCurrentRoutineNode := LSavedRoutineNode;
            if FSignal = lsReturn then
            begin
              Result := FReturnValue;
              FSignal := lsNone;
              FReturnValue := TLVMValue.Nil_();
            end
            else
              Result := TLVMValue.Nil_();
          finally
            FEnvironment.PopScope();
          end;
          Exit;
        end
        else
        begin
          GetErrors().RaiseOnError := True;
          GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
            ERR_LVM_CALL, RSLVMNotCallable, [LName]);
        end;
      end;

      GetErrors().RaiseOnError := True;
      GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
        ERR_LVM_CALL, RSLVMUnknownFunc, [LName]);
    end
    else
    begin
      // Expression-based callee (e.g. obj.method(), list[0](), etc.)
      LTarget := EvalExpr(LCallee);
      if LTarget.Kind = vkRoutine then
      begin
        LRoutineNode := TLVMASTNode(LTarget.AsRoutine());
        LBodyIdx := LRoutineNode.ChildCount() - 1;
        FEnvironment.PushScope();
        try
          for LI := 0 to LBodyIdx - 1 do
          begin
            LParamNode := TLVMASTNode(LRoutineNode.Children[LI]);
            LParamType := LParamNode.GetAttr('type');
            if LI < Length(LArgs) then
            begin
              if (LParamType <> '') and (LParamType <> 'any') and (LArgs[LI].Kind <> vkNil) and
                 (not TLVMValue.KindMatchesType(LArgs[LI], LParamType)) then
              begin
                GetErrors().RaiseOnError := True;
                GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
                  ERR_LVM_TYPE, RSLVMArgTypeMismatch,
                  [LI + 1, LParamType, LArgs[LI].KindName()]);
              end;
              FEnvironment.ForceSetVar(LParamNode.GetAttr('name'), LArgs[LI], LParamType);
            end
            else
              FEnvironment.ForceSetVar(LParamNode.GetAttr('name'), TLVMValue.Nil_(), LParamType);
          end;
          LSavedRoutineNode := FCurrentRoutineNode;
          FCurrentRoutineNode := LRoutineNode;
          FSignal := lsNone;
          ExecBlock(TLVMASTNode(LRoutineNode.Children[LBodyIdx]));
          FCurrentRoutineNode := LSavedRoutineNode;
          if FSignal = lsReturn then
          begin
            Result := FReturnValue;
            FSignal := lsNone;
            FReturnValue := TLVMValue.Nil_();
          end
          else
            Result := TLVMValue.Nil_();
        finally
          FEnvironment.PopScope();
        end;
        Exit;
      end
      else
      begin
        GetErrors().RaiseOnError := True;
        GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
          ERR_LVM_CALL, RSLVMCannotCallExpr);
      end;
    end;
  end;

  // List literal
  if LKind = 'expr.list' then
  begin
    Result := TLVMValue.FromList();
    LList := Result.AsList();
    for LI := 0 to ANode.ChildCount() - 1 do
      LList.Add(EvalExpr(TLVMASTNode(ANode.Children[LI])));
    Exit;
  end;

  // Map literal
  if LKind = 'expr.map' then
  begin
    Result := TLVMValue.FromMap();
    LMap := Result.AsMap();
    for LI := 0 to ANode.ChildCount() - 1 do
    begin
      LName := ANode.GetAttr('key_' + IntToStr(LI));
      LMap.AddOrSetValue(LName, EvalExpr(TLVMASTNode(ANode.Children[LI])));
    end;
    Exit;
  end;

  // Indexing
  if LKind = 'expr.index' then
  begin
    LTarget := EvalExpr(TLVMASTNode(ANode.Children[0]));
    LIndex := EvalExpr(TLVMASTNode(ANode.Children[1]));

    if LTarget.Kind = vkList then
    begin
      LIdx := Integer(LIndex.AsInt());
      LList := LTarget.AsList();
      if (LIdx < 0) or (LIdx >= LList.Count) then
      begin
        GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
          ERR_LVM_INDEX, RSLVMListIndexBounds, [LIdx]);
        Result := TLVMValue.Nil_();
        Exit;
      end;
      Result := LList[LIdx];
      Exit;
    end;

    if LTarget.Kind = vkMap then
    begin
      LMap := LTarget.AsMap();
      LName := LIndex.AsString();
      if not LMap.TryGetValue(LName, Result) then
        Result := TLVMValue.Nil_();
      Exit;
    end;

    if LTarget.Kind = vkString then
    begin
      LIdx := Integer(LIndex.AsInt());
      LName := LTarget.AsString();
      if (LIdx < 1) or (LIdx > Length(LName)) then
      begin
        GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
          ERR_LVM_INDEX, RSLVMStrIndexBounds, [LIdx]);
        Result := TLVMValue.Nil_();
        Exit;
      end;
      Result := TLVMValue.FromString(LName[LIdx]);
      Exit;
    end;

    GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
      ERR_LVM_INDEX, RSLVMCannotIndex,
      [LTarget.KindName()]);
    Result := TLVMValue.Nil_();
    Exit;
  end;

  // Dot access
  if LKind = 'expr.dot' then
  begin
    LTarget := EvalExpr(TLVMASTNode(ANode.Children[0]));
    LName := ANode.GetAttr('name');
    if LTarget.Kind = vkMap then
    begin
      LMap := LTarget.AsMap();
      // For typed records, validate field name
      if (LMap.TypeName <> '') and (FRecordDefs.ContainsKey(LMap.TypeName)) then
      begin
        if not FRecordDefs[LMap.TypeName].HasField(LName) then
        begin
          GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
            ERR_LVM_FIELD, RSLVMNoSuchField,
            [LMap.TypeName, LName]);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      end;
      if not LMap.TryGetValue(LName, Result) then
        Result := TLVMValue.Nil_();
      Exit;
    end;
    GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
      ERR_LVM_FIELD, RSLVMCannotAccessField,
      [LName, LTarget.KindName()]);
    Result := TLVMValue.Nil_();
    Exit;
  end;

  // Expression statement wrapper
  if LKind = 'expr_stmt' then
  begin
    Result := EvalExpr(TLVMASTNode(ANode.Children[0]));
    Exit;
  end;

  raise Exception.CreateFmt('EvalExpr: unknown node kind "%s" at %s(%d:%d)',
    [LKind, ANode.Filename, ANode.Line, ANode.Col]);
end;

function TLangVM.Interpolate(const ARawText: string): string;
var
  LI: Integer;
  LLen: Integer;
  LCh: Char;
  LExprText: string;
  LDepth: Integer;
  LLexer: TLVMLexer;
  LParser: TLVMParser;
  LTokens: TArray<TLVMToken>;
  LExprNode: TLVMASTNode;
  LVal: TLVMValue;
begin
  Result := '';
  LI := 1;
  LLen := Length(ARawText);

  while LI <= LLen do
  begin
    LCh := ARawText[LI];

    // Escaped brace
    if (LCh = '\') and (LI + 1 <= LLen) and (ARawText[LI + 1] = '{') then
    begin
      Result := Result + '{';
      Inc(LI, 2);
      Continue;
    end;

    // Interpolation start
    if (LCh = '{') then
    begin
      Inc(LI); // skip {

      // Collect expression text until matching }
      LExprText := '';
      LDepth := 1;
      while (LI <= LLen) and (LDepth > 0) do
      begin
        if ARawText[LI] = '{' then
          Inc(LDepth)
        else if ARawText[LI] = '}' then
        begin
          Dec(LDepth);
          if LDepth = 0 then
          begin
            Inc(LI); // skip closing }
            Break;
          end;
        end;
        if LDepth > 0 then
          LExprText := LExprText + ARawText[LI];
        Inc(LI);
      end;

      // Try to evaluate the expression
      try
        LLexer := TLVMLexer.Create();
        LLexer.SetErrors(FErrors);
        LLexer.SetStatusCallback(FStatusCallback.Callback, FStatusCallback.UserData);
        try
          LTokens := LLexer.Tokenize(LExprText, '<interp>');
          LParser := TLVMParser.Create();
          LParser.SetErrors(FErrors);
          LParser.SetStatusCallback(FStatusCallback.Callback, FStatusCallback.UserData);
          try
            LExprNode := LParser.ParseSingleExpr(LTokens, '<interp>');
            LVal := EvalExpr(LExprNode);
            Result := Result + LVal.ToString();
          finally
            LParser.Free();
          end;
        finally
          LLexer.Free();
        end;
      except
        // Fallback: try simple variable lookup
        if FEnvironment.TryGetVar(LExprText.Trim(), LVal) then
          Result := Result + LVal.ToString()
        else
          Result := Result + '{' + LExprText + '}';
      end;
      Continue;
    end;

    // Regular character
    Result := Result + LCh;
    Inc(LI);
  end;
end;

{ TrimCommonIndent }
function TLangVM.TrimCommonIndent(const AText: string): string;
var
  LLines: TArray<string>;
  LMinIndent: Integer;
  LI: Integer;
  LJ: Integer;
  LIndent: Integer;
  LLine: string;
begin
  LLines := AText.Split([#10]);

  // Find minimum indent of non-empty lines
  LMinIndent := MaxInt;
  for LI := 0 to Length(LLines) - 1 do
  begin
    LLine := LLines[LI];
    if LLine.Trim() = '' then
      Continue;
    LIndent := 0;
    for LJ := 1 to Length(LLine) do
    begin
      if LLine[LJ] = ' ' then
        Inc(LIndent)
      else
        Break;
    end;
    if LIndent < LMinIndent then
      LMinIndent := LIndent;
  end;

  if LMinIndent = MaxInt then
    LMinIndent := 0;

  // Remove common indent from each line
  Result := '';
  for LI := 0 to Length(LLines) - 1 do
  begin
    if LI > 0 then
      Result := Result + #10;
    LLine := LLines[LI];
    if Length(LLine) > LMinIndent then
      Result := Result + Copy(LLine, LMinIndent + 1, Length(LLine) - LMinIndent)
    else if LLine.Trim() <> '' then
      Result := Result + LLine;
  end;
end;

// ----------------------------------------------------------------------------
//  Internal Builtins -- String Operations
// ----------------------------------------------------------------------------
procedure LVMBufWriteU16(const ABuf: TVirtualMemory<Byte>;
  const AOffset: Integer; const AValue: UInt16);
begin
  ABuf[UInt64(AOffset)]     := Byte(AValue);
  ABuf[UInt64(AOffset + 1)] := Byte(AValue shr 8);
end;

procedure LVMBufWriteU32(const ABuf: TVirtualMemory<Byte>;
  const AOffset: Integer; const AValue: UInt32);
begin
  ABuf[UInt64(AOffset)]     := Byte(AValue);
  ABuf[UInt64(AOffset + 1)] := Byte(AValue shr 8);
  ABuf[UInt64(AOffset + 2)] := Byte(AValue shr 16);
  ABuf[UInt64(AOffset + 3)] := Byte(AValue shr 24);
end;

procedure LVMBufWriteU64(const ABuf: TVirtualMemory<Byte>;
  const AOffset: Integer; const AValue: UInt64);
begin
  ABuf[UInt64(AOffset)]     := Byte(AValue);
  ABuf[UInt64(AOffset + 1)] := Byte(AValue shr 8);
  ABuf[UInt64(AOffset + 2)] := Byte(AValue shr 16);
  ABuf[UInt64(AOffset + 3)] := Byte(AValue shr 24);
  ABuf[UInt64(AOffset + 4)] := Byte(AValue shr 32);
  ABuf[UInt64(AOffset + 5)] := Byte(AValue shr 40);
  ABuf[UInt64(AOffset + 6)] := Byte(AValue shr 48);
  ABuf[UInt64(AOffset + 7)] := Byte(AValue shr 56);
end;

function LVMBufReadU16(const ABuf: TVirtualMemory<Byte>;
  const AOffset: Integer): UInt16;
begin
  Result := UInt16(ABuf[UInt64(AOffset)])
    or (UInt16(ABuf[UInt64(AOffset + 1)]) shl 8);
end;

function LVMBufReadU32(const ABuf: TVirtualMemory<Byte>;
  const AOffset: Integer): UInt32;
begin
  Result := UInt32(ABuf[UInt64(AOffset)])
    or (UInt32(ABuf[UInt64(AOffset + 1)]) shl 8)
    or (UInt32(ABuf[UInt64(AOffset + 2)]) shl 16)
    or (UInt32(ABuf[UInt64(AOffset + 3)]) shl 24);
end;

function LVMBufReadU64(const ABuf: TVirtualMemory<Byte>;
  const AOffset: Integer): UInt64;
begin
  Result := UInt64(ABuf[UInt64(AOffset)])
    or (UInt64(ABuf[UInt64(AOffset + 1)]) shl 8)
    or (UInt64(ABuf[UInt64(AOffset + 2)]) shl 16)
    or (UInt64(ABuf[UInt64(AOffset + 3)]) shl 24)
    or (UInt64(ABuf[UInt64(AOffset + 4)]) shl 32)
    or (UInt64(ABuf[UInt64(AOffset + 5)]) shl 40)
    or (UInt64(ABuf[UInt64(AOffset + 6)]) shl 48)
    or (UInt64(ABuf[UInt64(AOffset + 7)]) shl 56);
end;

procedure LVMBufCopyBytes(const ADst: TVirtualMemory<Byte>;
  const ADstOff: Integer; const ASrc: TVirtualMemory<Byte>;
  const ASrcOff: Integer; const ALen: Integer);
var
  LI: Integer;
begin
  for LI := 0 to ALen - 1 do
    ADst[UInt64(ADstOff + LI)] := ASrc[UInt64(ASrcOff + LI)];
end;

procedure TLangVM.RegisterInternalBuiltins();
begin
  // len(value) -- string length in UTF-16 code units, or list/map count
  RegisterBuiltin('len',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        Exit(TLVMValue.FromInt(0));
      if AArgs[0].Kind = vkString then
        Result := TLVMValue.FromInt(Length(AArgs[0].AsString()))
      else if AArgs[0].Kind = vkList then
        Result := TLVMValue.FromInt(AArgs[0].AsList().Count)
      else if AArgs[0].Kind = vkMap then
        Result := TLVMValue.FromInt(AArgs[0].AsMap().Count)
      else
        Result := TLVMValue.FromInt(0);
    end);

  // upper(s) -- uppercase
  RegisterBuiltin('upper',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if (Length(AArgs) < 1) then
        Exit(TLVMValue.FromString(''));
      Result := TLVMValue.FromString(UpperCase(AArgs[0].AsString()));
    end);

  // lower(s) -- lowercase
  RegisterBuiltin('lower',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if (Length(AArgs) < 1) then
        Exit(TLVMValue.FromString(''));
      Result := TLVMValue.FromString(LowerCase(AArgs[0].AsString()));
    end);

  // trim(s) -- strip leading/trailing whitespace
  RegisterBuiltin('trim',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if (Length(AArgs) < 1) then
        Exit(TLVMValue.FromString(''));
      Result := TLVMValue.FromString(Trim(AArgs[0].AsString()));
    end);

  // replace(s, old, new) -- replace all occurrences
  RegisterBuiltin('replace',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if (Length(AArgs) < 3) then
        Exit(TLVMValue.FromString(''));
      Result := TLVMValue.FromString(
        StringReplace(AArgs[0].AsString(), AArgs[1].AsString(),
          AArgs[2].AsString(), [rfReplaceAll]));
    end);

  // substr(s, start, length) -- substring (0-based start)
  RegisterBuiltin('substr',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LStr: string;
      LStart: Int64;
      LLen: Int64;
    begin
      if (Length(AArgs) < 2) then
        Exit(TLVMValue.FromString(''));
      LStr := AArgs[0].AsString();
      LStart := AArgs[1].AsInt();
      if Length(AArgs) >= 3 then
        LLen := AArgs[2].AsInt()
      else
        LLen := Length(LStr) - LStart;
      // Convert 0-based to 1-based for Delphi Copy
      Result := TLVMValue.FromString(Copy(LStr, LStart + 1, LLen));
    end);

  // startsWith(s, prefix) -- true if s starts with prefix
  RegisterBuiltin('startsWith',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if (Length(AArgs) < 2) then
        Exit(TLVMValue.FromBool(False));
      Result := TLVMValue.FromBool(
        AArgs[0].AsString().StartsWith(AArgs[1].AsString()));
    end);

  // endsWith(s, suffix) -- true if s ends with suffix
  RegisterBuiltin('endsWith',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if (Length(AArgs) < 2) then
        Exit(TLVMValue.FromBool(False));
      Result := TLVMValue.FromBool(
        AArgs[0].AsString().EndsWith(AArgs[1].AsString()));
    end);

  // contains(s, sub) -- true if s contains sub
  RegisterBuiltin('contains',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if (Length(AArgs) < 2) then
        Exit(TLVMValue.FromBool(False));
      Result := TLVMValue.FromBool(
        AArgs[0].AsString().Contains(AArgs[1].AsString()));
    end);

  // concat(a, b, ...) -- concatenate all args as strings
  RegisterBuiltin('concat',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LResult: string;
      LI: Integer;
    begin
      LResult := '';
      for LI := 0 to Length(AArgs) - 1 do
        LResult := LResult + AArgs[LI].ToString();
      Result := TLVMValue.FromString(LResult);
    end);

  // intToStr(n) -- integer to string
  RegisterBuiltin('intToStr',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if (Length(AArgs) < 1) then
        Exit(TLVMValue.FromString(''));
      Result := TLVMValue.FromString(IntToStr(AArgs[0].AsInt()));
    end);

  // floatToStr(f) -- float to string
  RegisterBuiltin('floatToStr',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if (Length(AArgs) < 1) then
        Exit(TLVMValue.FromString(''));
      Result := TLVMValue.FromString(FloatToStr(AArgs[0].AsFloat()));
    end);

  // strToInt(s) -- string to integer, 0 on failure
  RegisterBuiltin('strToInt',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if (Length(AArgs) < 1) then
        Exit(TLVMValue.FromInt(0));
      Result := TLVMValue.FromInt(StrToInt64Def(AArgs[0].AsString(), 0));
    end);

  // strToFloat(s) -- string to float, 0.0 on failure
  RegisterBuiltin('strToFloat',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LVal: Double;
    begin
      if (Length(AArgs) < 1) then
        Exit(TLVMValue.FromFloat(0.0));
      if TryStrToFloat(AArgs[0].AsString(), LVal) then
        Result := TLVMValue.FromFloat(LVal)
      else
        Result := TLVMValue.FromFloat(0.0);
    end);

  // utf8Len(s) -- length of string in UTF-8 bytes
  RegisterBuiltin('utf8Len',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if (Length(AArgs) < 1) then
        Exit(TLVMValue.FromInt(0));
      try
        Result := TLVMValue.FromInt(
          Length(TEncoding.UTF8.GetBytes(AArgs[0].AsString())));
      except
        on E: Exception do
          begin
            AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
              RSLVMBuiltinFailed, ['utf8Len', E.Message]);
            Result := TLVMValue.FromInt(0);
          end;
      end;
    end);

  // charOrd(s) -- ordinal value of first character
  RegisterBuiltin('charOrd',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LStr: string;
    begin
      if (Length(AArgs) < 1) then
        Exit(TLVMValue.FromInt(0));
      LStr := AArgs[0].AsString();
      if Length(LStr) > 0 then
        Result := TLVMValue.FromInt(Ord(LStr[1]))
      else
        Result := TLVMValue.FromInt(0);
    end);

  // charToInt(s) -- same as charOrd (alias)
  RegisterBuiltin('charToInt',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LStr: string;
    begin
      if (Length(AArgs) < 1) then
        Exit(TLVMValue.FromInt(0));
      LStr := AArgs[0].AsString();
      if Length(LStr) > 0 then
        Result := TLVMValue.FromInt(Ord(LStr[1]))
      else
        Result := TLVMValue.FromInt(0);
    end);

  // chr(n) -- convert integer code point to single-character string
  RegisterBuiltin('chr',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if (Length(AArgs) < 1) then
        Exit(TLVMValue.FromString(''));
      Result := TLVMValue.FromString(Char(AArgs[0].AsInt()));
    end);

  // fmtEscape(s) -- escape special chars for formatted output
  // Converts \n, \t, \r, \, " to their escaped forms
  RegisterBuiltin('fmtEscape',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LStr: string;
    begin
      if (Length(AArgs) < 1) then
        Exit(TLVMValue.FromString(''));
      LStr := AArgs[0].AsString();
      LStr := StringReplace(LStr, '\', '\\', [rfReplaceAll]);
      LStr := StringReplace(LStr, '"', '\"', [rfReplaceAll]);
      LStr := StringReplace(LStr, #10, '\n', [rfReplaceAll]);
      LStr := StringReplace(LStr, #13, '\r', [rfReplaceAll]);
      LStr := StringReplace(LStr, #9, '\t', [rfReplaceAll]);
      Result := TLVMValue.FromString(LStr);
    end);

  // unescapeStr(s) -- process escape sequences in a string
  // Converts \n, \t, \r, \\, \" back to their literal forms
  RegisterBuiltin('unescapeStr',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LStr: string;
    begin
      if (Length(AArgs) < 1) then
        Exit(TLVMValue.FromString(''));
      LStr := AArgs[0].AsString();
      LStr := StringReplace(LStr, '\\', #1, [rfReplaceAll]);
      LStr := StringReplace(LStr, '\n', #10, [rfReplaceAll]);
      LStr := StringReplace(LStr, '\r', #13, [rfReplaceAll]);
      LStr := StringReplace(LStr, '\t', #9, [rfReplaceAll]);
      LStr := StringReplace(LStr, '\"', '"', [rfReplaceAll]);
      LStr := StringReplace(LStr, #1, '\', [rfReplaceAll]);
      Result := TLVMValue.FromString(LStr);
    end);

  // typeOf(value) -- returns type name as string
  RegisterBuiltin('typeOf',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        Exit(TLVMValue.FromString('nil'));
      case AArgs[0].Kind of
        vkNil:     Result := TLVMValue.FromString('nil');
        vkInt:     Result := TLVMValue.FromString('int');
        vkFloat:   Result := TLVMValue.FromString('float');
        vkBool:    Result := TLVMValue.FromString('bool');
        vkString:  Result := TLVMValue.FromString('string');
        vkHandle:  Result := TLVMValue.FromString('handle');
        vkList:    Result := TLVMValue.FromString('list');
        vkRoutine: Result := TLVMValue.FromString('routine');
        vkBuffer:  Result := TLVMValue.FromString('buffer');
        vkMap:
        begin
          if AArgs[0].AsMap().TypeName <> '' then
            Result := TLVMValue.FromString(AArgs[0].AsMap().TypeName)
          else
            Result := TLVMValue.FromString('map');
        end;
      else
        Result := TLVMValue.FromString('unknown');
      end;
    end);

  // sizeof(recordName) -- returns total byte size for layout records, field count otherwise
  RegisterBuiltin('sizeof',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LRecName: string;
      LDef: TLVMRecordDef;
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['sizeof', 'expected record name argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LRecName := AArgs[0].AsString();
      if not AVM.RecordDefs.TryGetValue(LRecName, LDef) then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
            RSLVMBuiltinFailed, ['sizeof', LRecName]);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if LDef.IsLayout then
        Result := TLVMValue.FromInt(LDef.TotalSize)
      else
        Result := TLVMValue.FromInt(LDef.FieldNames.Count);
    end);

  // Console builtins
  RegisterBuiltin('print',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LI: Integer;
      LText: string;
    begin
      LText := '';
      for LI := 0 to Length(AArgs) - 1 do
        LText := LText + AArgs[LI].ToString();
      if AVM.FOnPrint.IsAssigned() then
        AVM.FOnPrint.Callback(LText, AVM.FOnPrint.UserData)
      else
        TConsole.Print(LText);
      Result := TLVMValue.Nil_();
    end);

  RegisterBuiltin('println',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LI: Integer;
      LText: string;
    begin
      LText := '';
      for LI := 0 to Length(AArgs) - 1 do
        LText := LText + AArgs[LI].ToString();
      if AVM.FOnPrint.IsAssigned() then
        AVM.FOnPrint.Callback(LText + sLineBreak, AVM.FOnPrint.UserData)
      else
        TConsole.PrintLn(LText);
      Result := TLVMValue.Nil_();
    end);

  // status(text, ...) -- send status message to host via TBaseObject.Status
  RegisterBuiltin('status',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LI: Integer;
      LText: string;
    begin
      LText := '';
      for LI := 0 to Length(AArgs) - 1 do
        LText := LText + AArgs[LI].ToString();
      AVM.Status(LText);
      Result := TLVMValue.Nil_();
    end);

  RegisterBuiltin('readln',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LLine: string;
    begin
      ReadLn(LLine);
      Result := TLVMValue.FromString(LLine);
    end);

  // Buffer builtins
  RegisterBuiltin('buffer',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LExec: Boolean;
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['buffer', 'a size argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LExec := (Length(AArgs) >= 2) and AArgs[1].AsBool();
      Result := TLVMValue.FromBuffer(Integer(AArgs[0].AsInt()), LExec);
    end);

  RegisterBuiltin('bufSize',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['bufSize', 'a buffer argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromInt(AArgs[0].AsBuffer().Capacity);
    end);

  RegisterBuiltin('bufGrow',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['bufGrow', 'buffer and newSize']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      AArgs[0].AsBuffer().Grow(UInt64(AArgs[1].AsInt()));
      Result := TLVMValue.Nil_();
    end);

  RegisterBuiltin('bufWriteU8',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 3 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['bufWriteU8', 'buffer, offset, value']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      AArgs[0].AsBuffer()[UInt64(AArgs[1].AsInt())] := Byte(AArgs[2].AsInt() and $FF);
      Result := TLVMValue.Nil_();
    end);

  RegisterBuiltin('bufWriteU16',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 3 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['bufWriteU16', 'buffer, offset, value']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LVMBufWriteU16(AArgs[0].AsBuffer(), Integer(AArgs[1].AsInt()), UInt16(AArgs[2].AsInt() and $FFFF));
      Result := TLVMValue.Nil_();
    end);

  RegisterBuiltin('bufWriteU32',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 3 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['bufWriteU32', 'buffer, offset, value']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LVMBufWriteU32(AArgs[0].AsBuffer(), Integer(AArgs[1].AsInt()), UInt32(AArgs[2].AsInt() and $FFFFFFFF));
      Result := TLVMValue.Nil_();
    end);

  RegisterBuiltin('bufWriteU64',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 3 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['bufWriteU64', 'buffer, offset, value']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LVMBufWriteU64(AArgs[0].AsBuffer(), Integer(AArgs[1].AsInt()), UInt64(AArgs[2].AsInt()));
      Result := TLVMValue.Nil_();
    end);

  RegisterBuiltin('bufReadU8',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['bufReadU8', 'buffer, offset']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromInt(AArgs[0].AsBuffer()[UInt64(AArgs[1].AsInt())]);
    end);

  RegisterBuiltin('bufReadU16',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['bufReadU16', 'buffer, offset']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromInt(LVMBufReadU16(AArgs[0].AsBuffer(), Integer(AArgs[1].AsInt())));
    end);

  RegisterBuiltin('bufReadU32',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['bufReadU32', 'buffer, offset']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromInt(LVMBufReadU32(AArgs[0].AsBuffer(), Integer(AArgs[1].AsInt())));
    end);

  RegisterBuiltin('bufReadU64',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['bufReadU64', 'buffer, offset']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromInt(Int64(LVMBufReadU64(AArgs[0].AsBuffer(), Integer(AArgs[1].AsInt()))));
    end);

  RegisterBuiltin('bufWriteBytes',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 5 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['bufWriteBytes', 'dst, dstOff, src, srcOff, len']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LVMBufCopyBytes(
        AArgs[0].AsBuffer(), Integer(AArgs[1].AsInt()),
        AArgs[2].AsBuffer(), Integer(AArgs[3].AsInt()),
        Integer(AArgs[4].AsInt()));
      Result := TLVMValue.Nil_();
    end);

  RegisterBuiltin('bufWriteString',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LBytes: TBytes;
      LBuf: TVirtualMemory<Byte>;
      LOff: Integer;
      LI: Integer;
    begin
      if Length(AArgs) < 3 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['bufWriteString', 'buffer, offset, string']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LBuf := AArgs[0].AsBuffer();
      LOff := Integer(AArgs[1].AsInt());
      try
        LBytes := TEncoding.UTF8.GetBytes(AArgs[2].AsString());
      except
        on E: Exception do
          begin
            AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
              RSLVMBuiltinFailed, ['bufWriteString', E.Message]);
            Result := TLVMValue.Nil_();
            Exit;
          end;
      end;
      for LI := 0 to Length(LBytes) - 1 do
        LBuf[UInt64(LOff + LI)] := LBytes[LI];
      Result := TLVMValue.FromInt(Length(LBytes));
    end);

  RegisterBuiltin('bufToBytes',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LBuf: TVirtualMemory<Byte>;
      LOff: Integer;
      LLen: Integer;
      LResult: TLVMValue;
      LI: Integer;
    begin
      if Length(AArgs) < 3 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['bufToBytes', 'buffer, offset, len']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LBuf := AArgs[0].AsBuffer();
      LOff := Integer(AArgs[1].AsInt());
      LLen := Integer(AArgs[2].AsInt());
      LResult := TLVMValue.FromList();
      for LI := 0 to LLen - 1 do
        LResult.AsList().Add(TLVMValue.FromInt(LBuf[UInt64(LOff + LI)]));
      Result := LResult;
    end);

  // bufWriteRecord(buf, off, rec) -- pack layout record fields into buffer
  RegisterBuiltin('bufWriteRecord',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LBuf: TVirtualMemory<Byte>;
      LOff: Integer;
      LMap: TLVMMapStore;
      LDef: TLVMRecordDef;
      LI: Integer;
      LFieldName: string;
      LFieldOff: Integer;
      LFieldSize: Integer;
      LVal: Int64;
    begin
      if Length(AArgs) < 3 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['bufWriteRecord', 'buffer, offset, record']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LBuf := AArgs[0].AsBuffer();
      LOff := Integer(AArgs[1].AsInt());
      if AArgs[2].Kind <> vkMap then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgType, ['bufWriteRecord', 'third arg', 'record instance']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LMap := AArgs[2].AsMap();
      if not AVM.RecordDefs.TryGetValue(LMap.TypeName, LDef) then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
            RSLVMBuiltinFailed, ['bufWriteRecord', LMap.TypeName]);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if not LDef.IsLayout then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
            RSLVMBuiltinFailed, ['bufWriteRecord', LMap.TypeName]);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      for LI := 0 to LDef.FieldNames.Count - 1 do
      begin
        LFieldName := LDef.FieldNames[LI];
        LFieldOff := LDef.FieldOffsets[LFieldName];
        LFieldSize := LDef.FieldSizes[LFieldName];
        LVal := LMap[LFieldName].AsInt();
        case LFieldSize of
          1: LBuf[UInt64(LOff + LFieldOff)] := Byte(LVal and $FF);
          2: LVMBufWriteU16(LBuf, LOff + LFieldOff, UInt16(LVal and $FFFF));
          4: LVMBufWriteU32(LBuf, LOff + LFieldOff, UInt32(LVal and $FFFFFFFF));
          8: LVMBufWriteU64(LBuf, LOff + LFieldOff, UInt64(LVal));
        end;
      end;
      Result := TLVMValue.Nil_();
    end);

  // bufReadRecord(buf, off, recordName) -- unpack layout record from buffer
  RegisterBuiltin('bufReadRecord',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LBuf: TVirtualMemory<Byte>;
      LOff: Integer;
      LRecName: string;
      LDef: TLVMRecordDef;
      LI: Integer;
      LFieldName: string;
      LFieldOff: Integer;
      LFieldSize: Integer;
      LVal: Int64;
    begin
      if Length(AArgs) < 3 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['bufReadRecord', 'buffer, offset, recordName']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LBuf := AArgs[0].AsBuffer();
      LOff := Integer(AArgs[1].AsInt());
      LRecName := AArgs[2].AsString();
      if not AVM.RecordDefs.TryGetValue(LRecName, LDef) then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
            RSLVMBuiltinFailed, ['bufReadRecord', LRecName]);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if not LDef.IsLayout then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
            RSLVMBuiltinFailed, ['bufReadRecord', LRecName]);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := LDef.CreateInstance();
      for LI := 0 to LDef.FieldNames.Count - 1 do
      begin
        LFieldName := LDef.FieldNames[LI];
        LFieldOff := LDef.FieldOffsets[LFieldName];
        LFieldSize := LDef.FieldSizes[LFieldName];
        case LFieldSize of
          1: LVal := LBuf[UInt64(LOff + LFieldOff)];
          2: LVal := LVMBufReadU16(LBuf, LOff + LFieldOff);
          4: LVal := LVMBufReadU32(LBuf, LOff + LFieldOff);
          8: LVal := Int64(LVMBufReadU64(LBuf, LOff + LFieldOff));
        else
          LVal := 0;
        end;
        Result.AsMap().AddOrSetValue(LFieldName, TLVMValue.FromInt(LVal));
      end;
    end);

  // JIT execution builtins
  RegisterBuiltin('bufIsExec',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['bufIsExec', 'a buffer argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if AArgs[0].Kind <> vkBuffer then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['bufIsExec', 'a buffer argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromBool(AArgs[0].FBuffer.IsExecutable);
    end);

  RegisterBuiltin('bufFlush',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['bufFlush', 'a buffer argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if not AArgs[0].FBuffer.IsExecutable then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['bufFlush', 'an executable buffer']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      try
        AArgs[0].AsBuffer().FlushInstructionCacheRegion();
      except
        on E: Exception do
          begin
            AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
              RSLVMBuiltinFailed, ['bufFlush', E.Message]);
            Result := TLVMValue.Nil_();
            Exit;
          end;
      end;
      Result := TLVMValue.Nil_();
    end);

  RegisterBuiltin('bufCall',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    type
      TJitFunc = function(): Int64;
    var
      LBuf: TVirtualMemory<Byte>;
      LFn: TJitFunc;
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['bufCall', 'buffer and offset']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if not AArgs[0].FBuffer.IsExecutable then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['bufCall', 'an executable buffer']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LBuf := AArgs[0].AsBuffer();
      try
        LBuf.FlushInstructionCacheRegion();
        LFn := TJitFunc(Pointer(UIntPtr(LBuf.Memory) + UIntPtr(AArgs[1].AsInt())));
        Result := TLVMValue.FromInt(LFn());
      except
        on E: Exception do
          begin
            AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
              RSLVMBuiltinFailed, ['bufCall', E.Message]);
            Result := TLVMValue.Nil_();
          end;
      end;
    end);

  RegisterBuiltin('bufSave',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['bufSave', 'buffer and path']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      try
        AArgs[0].AsBuffer().SaveToFile(AArgs[1].AsString());
      except
        on E: Exception do
          begin
            AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
              RSLVMBuiltinFailed, ['bufSave', E.Message]);
            Result := TLVMValue.Nil_();
            Exit;
          end;
      end;
      Result := TLVMValue.Nil_();
    end);

  // bufToBase64(buffer) -> string -- encode buffer contents as base64
  RegisterBuiltin('bufToBase64',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LBuf: TVirtualMemory<Byte>;
      LBytes: TBytes;
      LI: Integer;
      LSize: Integer;
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs,
            ['bufToBase64', 'buffer']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LBuf := AArgs[0].AsBuffer();
      LSize := Integer(LBuf.Size);
      SetLength(LBytes, LSize);
      for LI := 0 to LSize - 1 do
        LBytes[LI] := LBuf[UInt64(LI)];
      Result := TLVMValue.FromString(
        TNetEncoding.Base64String.EncodeBytesToString(LBytes));
    end);

  // shellOpen(path) -> bool -- open file with registered application
  RegisterBuiltin('shellOpen',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs,
            ['shellOpen', 'a path argument']);
          Result := TLVMValue.FromBool(False);
          Exit;
        end;
      Result := TLVMValue.FromBool(
        TUtils.ShellOpen(AArgs[0].AsString()));
    end);

  // bufLoadFile(path) -> buffer -- load entire file into a new buffer
  RegisterBuiltin('bufLoadFile',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LBuf: TVirtualMemory<Byte>;
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
            RSLVMBuiltinArgs, ['bufLoadFile', 'a path argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      try
        LBuf := TVirtualMemory<Byte>.LoadFromFile(AArgs[0].AsString());
        Result := TLVMValue.FromBuffer(LBuf);
      except
        on E: Exception do
          begin
            AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
              RSLVMBuiltinFailed, ['bufLoadFile', E.Message]);
            Result := TLVMValue.Nil_();
          end;
      end;
    end);

  // bufReadString(buf, off, len) -> string -- read bytes as UTF-8 string
  RegisterBuiltin('bufReadString',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LBuf: TVirtualMemory<Byte>;
      LOff: Integer;
      LLen: Integer;
      LBytes: TBytes;
      LI: Integer;
    begin
      if Length(AArgs) < 3 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
            RSLVMBuiltinArgs, ['bufReadString', 'buffer, offset, length']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      try
        LBuf := AArgs[0].AsBuffer();
        LOff := Integer(AArgs[1].AsInt());
        LLen := Integer(AArgs[2].AsInt());
        SetLength(LBytes, LLen);
        for LI := 0 to LLen - 1 do
          LBytes[LI] := LBuf[UInt64(LOff + LI)];
        Result := TLVMValue.FromString(TEncoding.UTF8.GetString(LBytes));
      except
        on E: Exception do
          begin
            AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
              RSLVMBuiltinFailed, ['bufReadString', E.Message]);
            Result := TLVMValue.Nil_();
          end;
      end;
    end);

  // loadTextFile(path) -> string -- read entire text file as UTF-8 string
  RegisterBuiltin('loadTextFile',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
            RSLVMBuiltinArgs, ['loadTextFile', 'a path argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      try
        Result := TLVMValue.FromString(
          TFile.ReadAllText(TUtils.ResolvePath(AArgs[0].AsString(), AVM.FBaseDir), TEncoding.UTF8));
      except
        on E: Exception do
          begin
            AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
              RSLVMBuiltinFailed, ['loadTextFile', E.Message]);
            Result := TLVMValue.Nil_();
          end;
      end;
    end);

  // saveTextFile(path, content [, bom]) -> bool -- write string to file as UTF-8
  // Optional 3rd arg: bom (bool, default true). When false, writes without BOM.
  RegisterBuiltin('saveTextFile',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LEnc: TEncoding;
      LOwnsEnc: Boolean;
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
            RSLVMBuiltinArgs, ['saveTextFile', 'path and content arguments']);
          Result := TLVMValue.FromBool(False);
          Exit;
        end;
      // Default: UTF-8 with BOM. Optional 3rd arg false = no BOM.
      LOwnsEnc := False;
      if (Length(AArgs) >= 3) and (not AArgs[2].AsBool()) then
        begin
          LEnc := TUTF8Encoding.Create(False);
          LOwnsEnc := True;
        end
      else
        LEnc := TEncoding.UTF8;
      try
        TFile.WriteAllText(TUtils.ResolvePath(AArgs[0].AsString(), AVM.FBaseDir), AArgs[1].AsString(),
          LEnc);
        Result := TLVMValue.FromBool(True);
      except
        on E: Exception do
          begin
            AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
              RSLVMBuiltinFailed, ['saveTextFile', E.Message]);
            Result := TLVMValue.FromBool(False);
          end;
      end;
      if LOwnsEnc then
        LEnc.Free();
    end);

  // createDirsInPath(path) -- create all directories along the path
  RegisterBuiltin('createDirsInPath',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['createDirsInPath', 'a path argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      try
        Result := TLVMValue.FromBool(TUtils.CreateDirInPath(AArgs[0].AsString()));
      except
        on E: Exception do
          begin
            AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
              RSLVMBuiltinFailed, ['createDirsInPath', E.Message]);
            Result := TLVMValue.FromBool(False);
          end;
      end;
    end);

  // runPE(exe_path, params, workdir) -- run a PE executable, return exit code
  RegisterBuiltin('runPE',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LParams: string;
      LWorkDir: string;
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['runPE', 'at least an exe path']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LParams := '';
      LWorkDir := '';
      if Length(AArgs) >= 2 then
        LParams := AArgs[1].AsString();
      if Length(AArgs) >= 3 then
        LWorkDir := AArgs[2].AsString();
      try
        Result := TLVMValue.FromInt(Int64(TUtils.RunPE(AArgs[0].AsString(),
          LParams, LWorkDir, True, 0)));  // 0 = SW_HIDE
      except
        on E: Exception do
          begin
            AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
              RSLVMBuiltinFailed, ['runPE', E.Message]);
            Result := TLVMValue.Nil_();
          end;
      end;
    end);

  // runELF(elf_path, workdir) -- run an ELF binary via WSL, return exit code
  RegisterBuiltin('runELF',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LWorkDir: string;
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['runELF', 'at least an ELF path']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LWorkDir := '';
      if Length(AArgs) >= 2 then
        LWorkDir := AArgs[1].AsString();
      try
        Result := TLVMValue.FromInt(Int64(TUtils.RunElf(AArgs[0].AsString(),
          LWorkDir)));
      except
        on E: Exception do
          begin
            AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
              RSLVMBuiltinFailed, ['runELF', E.Message]);
            Result := TLVMValue.Nil_();
          end;
      end;
    end);

  RegisterBuiltin('bufPtr',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['bufPtr', 'a buffer argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromInt(Int64(UIntPtr(AArgs[0].AsBuffer().Memory)));
    end);

  RegisterBuiltin('bufCopyBytes',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LSrc, LDst: TVirtualMemory<Byte>;
      LSrcOff, LDstOff, LLen: Integer;
    begin
      if Length(AArgs) <> 5 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, 'bufCopyBytes(src, srcOff, dst, dstOff, len) requires 5 arguments');
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LSrc := AArgs[0].AsBuffer();
      LSrcOff := AArgs[1].AsInt();
      LDst := AArgs[2].AsBuffer();
      LDstOff := AArgs[3].AsInt();
      LLen := AArgs[4].AsInt();
      LVMBufCopyBytes(LDst, LDstOff, LSrc, LSrcOff, LLen);
      Result := TLVMValue.Nil_();
    end);

  RegisterBuiltin('bufWriteF32',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LBuf: TVirtualMemory<Byte>;
      LOff: Integer;
      LVal: Single;
      LBytes: array[0..3] of Byte;
    begin
      if Length(AArgs) <> 3 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, 'bufWriteF32(buf, offset, value) requires 3 arguments');
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LBuf := AArgs[0].AsBuffer();
      LOff := AArgs[1].AsInt();
      LVal := Single(AArgs[2].AsFloat());
      Move(LVal, LBytes[0], 4);
      LBuf[UInt64(LOff + 0)] := LBytes[0];
      LBuf[UInt64(LOff + 1)] := LBytes[1];
      LBuf[UInt64(LOff + 2)] := LBytes[2];
      LBuf[UInt64(LOff + 3)] := LBytes[3];
      Result := TLVMValue.Nil_();
    end);

  RegisterBuiltin('bufWriteF64',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LBuf: TVirtualMemory<Byte>;
      LOff, LI: Integer;
      LVal: Double;
      LBytes: array[0..7] of Byte;
    begin
      if Length(AArgs) <> 3 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, 'bufWriteF64(buf, offset, value) requires 3 arguments');
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LBuf := AArgs[0].AsBuffer();
      LOff := AArgs[1].AsInt();
      LVal := AArgs[2].AsFloat();
      Move(LVal, LBytes[0], 8);
      for LI := 0 to 7 do
        LBuf[UInt64(LOff + LI)] := LBytes[LI];
      Result := TLVMValue.Nil_();
    end);

  RegisterBuiltin('bufReadF32',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LBuf: TVirtualMemory<Byte>;
      LOff: Integer;
      LVal: Single;
      LBytes: array[0..3] of Byte;
    begin
      if Length(AArgs) <> 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, 'bufReadF32(buf, offset) requires 2 arguments');
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LBuf := AArgs[0].AsBuffer();
      LOff := AArgs[1].AsInt();
      LBytes[0] := LBuf[UInt64(LOff + 0)];
      LBytes[1] := LBuf[UInt64(LOff + 1)];
      LBytes[2] := LBuf[UInt64(LOff + 2)];
      LBytes[3] := LBuf[UInt64(LOff + 3)];
      Move(LBytes[0], LVal, 4);
      Result := TLVMValue.FromFloat(LVal);
    end);

  RegisterBuiltin('bufReadF64',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LBuf: TVirtualMemory<Byte>;
      LOff, LI: Integer;
      LVal: Double;
      LBytes: array[0..7] of Byte;
    begin
      if Length(AArgs) <> 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, 'bufReadF64(buf, offset) requires 2 arguments');
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LBuf := AArgs[0].AsBuffer();
      LOff := AArgs[1].AsInt();
      for LI := 0 to 7 do
        LBytes[LI] := LBuf[UInt64(LOff + LI)];
      Move(LBytes[0], LVal, 8);
      Result := TLVMValue.FromFloat(LVal);
    end);

  //AST node inspection builtins
  RegisterBuiltin('getAttr',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LNode: TLVMASTNode;
      LName: string;
    begin
      if (Length(AArgs) = 2) and (AArgs[0].Kind = vkHandle) then
      begin
        LNode := TLVMASTNode(AArgs[0].AsHandle());
        LName := AArgs[1].AsString();
      end
      else if Length(AArgs) >= 1 then
      begin
        LNode := TLVMASTNode(AVM.FCurrentNode.AsHandle());
        LName := AArgs[0].AsString();
      end
      else
        Exit(TLVMValue.FromString(''));
      Result := TLVMValue.FromString(LNode.GetAttr(LName));
    end);

  RegisterBuiltin('setAttr',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LNode: TLVMASTNode;
      LName, LValue: string;
    begin
      if (Length(AArgs) = 3) and (AArgs[0].Kind = vkHandle) then
      begin
        LNode := TLVMASTNode(AArgs[0].AsHandle());
        LName := AArgs[1].AsString();
        LValue := AArgs[2].AsString();
      end
      else if Length(AArgs) >= 2 then
      begin
        LNode := TLVMASTNode(AVM.FCurrentNode.AsHandle());
        LName := AArgs[0].AsString();
        LValue := AArgs[1].AsString();
      end
      else
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['setAttr', '(name, value) or (node, name, value)']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LNode.SetAttr(LName, LValue);
      Result := TLVMValue.Nil_();
    end);

  RegisterBuiltin('hasAttr',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LNode: TLVMASTNode;
      LName: string;
    begin
      if (Length(AArgs) = 2) and (AArgs[0].Kind = vkHandle) then
      begin
        LNode := TLVMASTNode(AArgs[0].AsHandle());
        LName := AArgs[1].AsString();
      end
      else if Length(AArgs) >= 1 then
      begin
        LNode := TLVMASTNode(AVM.FCurrentNode.AsHandle());
        LName := AArgs[0].AsString();
      end
      else
        Exit(TLVMValue.FromBool(False));
      Result := TLVMValue.FromBool(LNode.HasAttr(LName));
    end);

  RegisterBuiltin('childCount',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LNode: TLVMASTNode;
    begin
      if (Length(AArgs) >= 1) and (AArgs[0].Kind = vkHandle) then
        LNode := TLVMASTNode(AArgs[0].AsHandle())
      else
        LNode := TLVMASTNode(AVM.FCurrentNode.AsHandle());
      Result := TLVMValue.FromInt(LNode.ChildCount());
    end);

  RegisterBuiltin('getChild',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LNode: TLVMASTNode;
      LIdx: Integer;
    begin
      if (Length(AArgs) = 2) and (AArgs[0].Kind = vkHandle) then
      begin
        LNode := TLVMASTNode(AArgs[0].AsHandle());
        LIdx := AArgs[1].AsInt();
      end
      else if Length(AArgs) >= 1 then
      begin
        LNode := TLVMASTNode(AVM.FCurrentNode.AsHandle());
        LIdx := AArgs[0].AsInt();
      end
      else
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['getChild', 'an index']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if (LIdx < 0) or (LIdx >= LNode.ChildCount()) then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['getChild', LIdx, LNode.ChildCount()]);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromHandle(LNode.Children[LIdx]);
    end);

  RegisterBuiltin('nodeKind',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LNode: TLVMASTNode;
    begin
      if (Length(AArgs) >= 1) and (AArgs[0].Kind = vkHandle) then
        LNode := TLVMASTNode(AArgs[0].AsHandle())
      else
        LNode := TLVMASTNode(AVM.FCurrentNode.AsHandle());
      Result := TLVMValue.FromString(LNode.Kind);
    end);

  // getNodeKind -- alias used by RunSemantics/RunEmitters walkers (mockable)
  RegisterBuiltin('getNodeKind',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LNode: TLVMASTNode;
    begin
      if (Length(AArgs) >= 1) and (AArgs[0].Kind = vkHandle) then
        LNode := TLVMASTNode(AArgs[0].AsHandle())
      else
        LNode := TLVMASTNode(AVM.FCurrentNode.AsHandle());
      Result := TLVMValue.FromString(LNode.Kind);
    end);

  RegisterBuiltin('nodeFile',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LNode: TLVMASTNode;
    begin
      if (Length(AArgs) >= 1) and (AArgs[0].Kind = vkHandle) then
        LNode := TLVMASTNode(AArgs[0].AsHandle())
      else
        LNode := TLVMASTNode(AVM.FCurrentNode.AsHandle());
      Result := TLVMValue.FromString(LNode.Filename);
    end);

  RegisterBuiltin('nodeLine',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LNode: TLVMASTNode;
    begin
      if (Length(AArgs) >= 1) and (AArgs[0].Kind = vkHandle) then
        LNode := TLVMASTNode(AArgs[0].AsHandle())
      else
        LNode := TLVMASTNode(AVM.FCurrentNode.AsHandle());
      Result := TLVMValue.FromInt(LNode.Line);
    end);

  RegisterBuiltin('nodeCol',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LNode: TLVMASTNode;
    begin
      if (Length(AArgs) >= 1) and (AArgs[0].Kind = vkHandle) then
        LNode := TLVMASTNode(AArgs[0].AsHandle())
      else
        LNode := TLVMASTNode(AVM.FCurrentNode.AsHandle());
      Result := TLVMValue.FromInt(LNode.Col);
    end);

  RegisterBuiltin('createNode',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LNode: TLVMASTNode;
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, 'createNode(kind) requires a kind string');
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LNode := TLVMASTNode.Create();
      LNode.Kind := AArgs[0].AsString();
      AVM.FCreatedNodes.Add(LNode);
      Result := TLVMValue.FromHandle(LNode);
    end);

  RegisterBuiltin('addChild',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LParent, LChild: TLVMASTNode;
      LIdx: Integer;
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, 'addChild(parent, child) requires 2 arguments');
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LParent := TLVMASTNode(AArgs[0].AsHandle());
      LChild := TLVMASTNode(AArgs[1].AsHandle());
      // Transfer ownership from FCreatedNodes if present
      LIdx := AVM.FCreatedNodes.IndexOf(LChild);
      if LIdx >= 0 then
        AVM.FCreatedNodes.Extract(LChild);
      LParent.AddChild(LChild);
      Result := TLVMValue.Nil_();
    end);

  RegisterBuiltin('setChild',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LNode, LChild: TLVMASTNode;
      LIdx: Integer;
    begin
      if Length(AArgs) < 3 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, 'setChild(node, index, child) requires 3 arguments');
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LNode := TLVMASTNode(AArgs[0].AsHandle());
      LIdx := AArgs[1].AsInt();
      LChild := TLVMASTNode(AArgs[2].AsHandle());
      if (LIdx < 0) or (LIdx >= LNode.ChildCount()) then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['setChild', LIdx, LNode.ChildCount()]);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LNode.Children[LIdx] := LChild;
      Result := TLVMValue.Nil_();
    end);

  RegisterBuiltin('removeChild',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LNode: TLVMASTNode;
      LIdx: Integer;
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, 'removeChild(node, index) requires 2 arguments');
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LNode := TLVMASTNode(AArgs[0].AsHandle());
      LIdx := AArgs[1].AsInt();
      if (LIdx < 0) or (LIdx >= LNode.ChildCount()) then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['removeChild', LIdx, LNode.ChildCount()]);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LNode.Children.Delete(LIdx);
      Result := TLVMValue.Nil_();
    end);

  RegisterBuiltin('cloneNode',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LClone: TLVMASTNode;

      function DoClone(const ASrc: TLVMASTNode): TLVMASTNode;
      var
        LPair: TPair<string, string>;
        LI: Integer;
      begin
        Result := TLVMASTNode.Create();
        Result.Kind := ASrc.Kind;
        Result.Line := ASrc.Line;
        Result.Col := ASrc.Col;
        Result.Filename := ASrc.Filename;
        for LPair in ASrc.Attrs do
          Result.SetAttr(LPair.Key, LPair.Value);
        for LI := 0 to ASrc.ChildCount() - 1 do
          Result.AddChild(DoClone(ASrc.Children[LI]));
      end;

    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, 'cloneNode(node) requires a node argument');
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LClone := DoClone(TLVMASTNode(AArgs[0].AsHandle()));
      AVM.FCreatedNodes.Add(LClone);
      Result := TLVMValue.FromHandle(LClone);
    end);

  // Shared state builtins
  RegisterBuiltin('setShared',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) <> 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, 'setShared(key, value) requires 2 arguments');
          Result := TLVMValue.Nil_();
          Exit;
        end;
      AVM.FSharedState.AddOrSetValue(AArgs[0].AsString(), AArgs[1]);
      Result := TLVMValue.Nil_();
    end);

  RegisterBuiltin('getShared',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) <> 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, 'getShared(key) requires 1 argument');
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if not AVM.FSharedState.TryGetValue(AArgs[0].AsString(), Result) then
        Result := TLVMValue.Nil_();
    end);

  RegisterBuiltin('hasShared',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) <> 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, 'hasShared(key) requires 1 argument');
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromBool(
        AVM.FSharedState.ContainsKey(AArgs[0].AsString()));
    end);

  RegisterBuiltin('clearShared',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      AVM.FSharedState.Clear();
      Result := TLVMValue.Nil_();
    end);

  // Bitwise builtins
  RegisterBuiltin('band',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['band', 'two arguments']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromInt(AArgs[0].AsInt() and AArgs[1].AsInt());
    end);

  RegisterBuiltin('bor',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['bor', 'two arguments']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromInt(AArgs[0].AsInt() or AArgs[1].AsInt());
    end);

  RegisterBuiltin('bxor',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['bxor', 'two arguments']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromInt(AArgs[0].AsInt() xor AArgs[1].AsInt());
    end);

  RegisterBuiltin('bnot',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['bnot', 'one argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromInt(not AArgs[0].AsInt());
    end);

  RegisterBuiltin('shl',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['shl', 'two arguments']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromInt(AArgs[0].AsInt() shl Integer(AArgs[1].AsInt()));
    end);

  RegisterBuiltin('shr',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['shr', 'two arguments']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      // Logical (unsigned) shift right
      Result := TLVMValue.FromInt(Int64(UInt64(AArgs[0].AsInt()) shr Integer(AArgs[1].AsInt())));
    end);

  // File I/O builtins
  RegisterBuiltin('fileCreate',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LVM: TLangVM;
      LHandle: Int64;
      LStream: TFileStream;
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['fileCreate', 'a path argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LVM := AVM;
      try
        LStream := TFileStream.Create(AArgs[0].AsString(), fmCreate or fmShareDenyWrite);
      except
        on E: Exception do
          begin
            AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
              RSLVMBuiltinFailed, ['fileCreate', E.Message]);
            Result := TLVMValue.Nil_();
            Exit;
          end;
      end;
      LHandle := LVM.FNextFileHandle;
      Inc(LVM.FNextFileHandle);
      LVM.FFileHandles.Add(LHandle, LStream);
      Result := TLVMValue.FromInt(LHandle);
    end);

  RegisterBuiltin('fileOpen',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LVM: TLangVM;
      LHandle: Int64;
      LStream: TFileStream;
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['fileOpen', 'a path argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LVM := AVM;
      try
        LStream := TFileStream.Create(AArgs[0].AsString(), fmOpenRead or fmShareDenyNone);
      except
        on E: Exception do
          begin
            AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
              RSLVMBuiltinFailed, ['fileOpen', E.Message]);
            Result := TLVMValue.Nil_();
            Exit;
          end;
      end;
      LHandle := LVM.FNextFileHandle;
      Inc(LVM.FNextFileHandle);
      LVM.FFileHandles.Add(LHandle, LStream);
      Result := TLVMValue.FromInt(LHandle);
    end);

  RegisterBuiltin('fileClose',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LVM: TLangVM;
      LHandle: Int64;
      LStream: TFileStream;
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['fileClose', 'a handle argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LVM := AVM;
      LHandle := AArgs[0].AsInt();
      if not LVM.FFileHandles.TryGetValue(LHandle, LStream) then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
            RSLVMBuiltinInvHandle, ['fileClose', LHandle]);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      try
        LStream.Free();
      except
        on E: Exception do
          begin
            AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
              RSLVMBuiltinFailed, ['fileClose', E.Message]);
          end;
      end;
      LVM.FFileHandles.Remove(LHandle);
      Result := TLVMValue.Nil_();
    end);

  RegisterBuiltin('fileWrite',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LVM: TLangVM;
      LStream: TFileStream;
      LBuf: TVirtualMemory<Byte>;
      LOff: Integer;
      LLen: Integer;
    begin
      if Length(AArgs) < 4 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, 'fileWrite(handle, buf, off, len) requires 4 arguments');
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LVM := AVM;
      if not LVM.FFileHandles.TryGetValue(AArgs[0].AsInt(), LStream) then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
            RSLVMBuiltinInvHandle, ['fileWrite', AArgs[0].AsInt()]);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LBuf := AArgs[1].AsBuffer();
      LOff := Integer(AArgs[2].AsInt());
      LLen := Integer(AArgs[3].AsInt());
      if (LOff < 0) or (UInt64(LOff + LLen) > LBuf.Capacity) then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['fileWrite', LOff, LOff + LLen, LBuf.Capacity]);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      try
        LStream.WriteBuffer(Pointer(UIntPtr(LBuf.Memory) + UIntPtr(LOff))^, LLen);
      except
        on E: Exception do
          begin
            AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
              RSLVMBuiltinFailed, ['fileWrite', E.Message]);
            Result := TLVMValue.Nil_();
            Exit;
          end;
      end;
      Result := TLVMValue.Nil_();
    end);

  RegisterBuiltin('fileRead',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LVM: TLangVM;
      LStream: TFileStream;
      LBuf: TVirtualMemory<Byte>;
      LOff: Integer;
      LLen: Integer;
      LBytesRead: Integer;
    begin
      if Length(AArgs) < 4 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, 'fileRead(handle, buf, off, len) requires 4 arguments');
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LVM := AVM;
      if not LVM.FFileHandles.TryGetValue(AArgs[0].AsInt(), LStream) then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
            RSLVMBuiltinInvHandle, ['fileRead', AArgs[0].AsInt()]);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LBuf := AArgs[1].AsBuffer();
      LOff := Integer(AArgs[2].AsInt());
      LLen := Integer(AArgs[3].AsInt());
      if (LOff < 0) or (UInt64(LOff + LLen) > LBuf.Capacity) then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['fileRead', LOff, LOff + LLen, LBuf.Capacity]);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      try
        LBytesRead := LStream.Read(Pointer(UIntPtr(LBuf.Memory) + UIntPtr(LOff))^, LLen);
      except
        on E: Exception do
          begin
            AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
              RSLVMBuiltinFailed, ['fileRead', E.Message]);
            Result := TLVMValue.Nil_();
            Exit;
          end;
      end;
      Result := TLVMValue.FromInt(LBytesRead);
    end);

  RegisterBuiltin('fileSize',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LVM: TLangVM;
      LStream: TFileStream;
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['fileSize', 'a handle argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LVM := AVM;
      if not LVM.FFileHandles.TryGetValue(AArgs[0].AsInt(), LStream) then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
            RSLVMBuiltinInvHandle, ['fileSize', AArgs[0].AsInt()]);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      try
        Result := TLVMValue.FromInt(LStream.Size);
      except
        on E: Exception do
          begin
            AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
              RSLVMBuiltinFailed, ['fileSize', E.Message]);
            Result := TLVMValue.Nil_();
          end;
      end;
    end);

  RegisterBuiltin('fileSeek',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LVM: TLangVM;
      LStream: TFileStream;
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, 'fileSeek(handle, pos) requires 2 arguments');
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LVM := AVM;
      if not LVM.FFileHandles.TryGetValue(AArgs[0].AsInt(), LStream) then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
            RSLVMBuiltinInvHandle, ['fileSeek', AArgs[0].AsInt()]);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      try
        LStream.Position := AArgs[1].AsInt();
      except
        on E: Exception do
          begin
            AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
              RSLVMBuiltinFailed, ['fileSeek', E.Message]);
            Result := TLVMValue.Nil_();
            Exit;
          end;
      end;
      Result := TLVMValue.Nil_();
    end);

  RegisterBuiltin('filePos',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LVM: TLangVM;
      LStream: TFileStream;
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['filePos', 'a handle argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LVM := AVM;
      if not LVM.FFileHandles.TryGetValue(AArgs[0].AsInt(), LStream) then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
            RSLVMBuiltinInvHandle, ['filePos', AArgs[0].AsInt()]);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      try
        Result := TLVMValue.FromInt(LStream.Position);
      except
        on E: Exception do
          begin
            AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
              RSLVMBuiltinFailed, ['filePos', E.Message]);
            Result := TLVMValue.Nil_();
          end;
      end;
    end);

  // listAppend(list, value) -- appends value to list, returns nil
  RegisterBuiltin('listAppend',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['listAppend', '(list, value)']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if AArgs[0].Kind <> vkList then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgType, ['listAppend', 'first argument', 'list']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      AArgs[0].AsList().Add(AArgs[1]);
      Result := TLVMValue.Nil_();
    end);

  // listInsert(list, index, value) -- inserts at index, returns nil
  RegisterBuiltin('listInsert',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 3 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['listInsert', '(list, index, value)']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if AArgs[0].Kind <> vkList then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgType, ['listInsert', 'first argument', 'list']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      AArgs[0].AsList().Insert(Integer(AArgs[1].AsInt()), AArgs[2]);
      Result := TLVMValue.Nil_();
    end);

  // listRemove(list, index) -- removes item at index, returns the removed value
  RegisterBuiltin('listRemove',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LList: TLVMListStore;
      LIdx: Integer;
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['listRemove', '(list, index)']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if AArgs[0].Kind <> vkList then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgType, ['listRemove', 'first argument', 'list']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LList := AArgs[0].AsList();
      LIdx := Integer(AArgs[1].AsInt());
      if (LIdx < 0) or (LIdx >= LList.Count) then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
            'listRemove() index %d out of range', [LIdx]);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := LList[LIdx];
      LList.Delete(LIdx);
    end);

  // listIndexOf(list, value) -- returns index of first match or -1
  RegisterBuiltin('listIndexOf',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LList: TLVMListStore;
      LI: Integer;
      LTarget: string;
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['listIndexOf', '(list, value)']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if AArgs[0].Kind <> vkList then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgType, ['listIndexOf', 'first argument', 'list']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LList := AArgs[0].AsList();
      // Compare by string representation for simplicity
      LTarget := AArgs[1].ToString();
      for LI := 0 to LList.Count - 1 do
      begin
        if LList[LI].ToString() = LTarget then
          Exit(TLVMValue.FromInt(LI));
      end;
      Result := TLVMValue.FromInt(-1);
    end);

  // listReverse(list) -- reverses in place, returns nil
  RegisterBuiltin('listReverse',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LList: TLVMListStore;
      LI, LJ: Integer;
      LTmp: TLVMValue;
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['listReverse', 'a list argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if AArgs[0].Kind <> vkList then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgType, ['listReverse', 'argument', 'list']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LList := AArgs[0].AsList();
      LI := 0;
      LJ := LList.Count - 1;
      while LI < LJ do
      begin
        LTmp := LList[LI];
        LList[LI] := LList[LJ];
        LList[LJ] := LTmp;
        Inc(LI);
        Dec(LJ);
      end;
      Result := TLVMValue.Nil_();
    end);

  // listSort(list) -- sorts in place (int/float/string comparison), returns nil
  RegisterBuiltin('listSort',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['listSort', 'a list argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if AArgs[0].Kind <> vkList then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgType, ['listSort', 'argument', 'list']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      AArgs[0].AsList().Sort(TComparer<TLVMValue>.Construct(
        function(const ALeft, ARight: TLVMValue): Integer
        begin
          // Compare by kind priority, then by value
          if (ALeft.Kind = vkInt) and (ARight.Kind = vkInt) then
          begin
            if ALeft.AsInt() < ARight.AsInt() then Result := -1
            else if ALeft.AsInt() > ARight.AsInt() then Result := 1
            else Result := 0;
          end
          else if (ALeft.Kind = vkFloat) and (ARight.Kind = vkFloat) then
          begin
            if ALeft.AsFloat() < ARight.AsFloat() then Result := -1
            else if ALeft.AsFloat() > ARight.AsFloat() then Result := 1
            else Result := 0;
          end
          else
            Result := CompareStr(ALeft.ToString(), ARight.ToString());
        end));
      Result := TLVMValue.Nil_();
    end);

  // listClear(list) -- removes all items, returns nil
  RegisterBuiltin('listClear',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['listClear', 'a list argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if AArgs[0].Kind <> vkList then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgType, ['listClear', 'argument', 'list']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      AArgs[0].AsList().Clear();
      Result := TLVMValue.Nil_();
    end);

  // listSlice(list, from, to) -- returns NEW list with elements [from..to)
  RegisterBuiltin('listSlice',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LList: TLVMListStore;
      LFrom, LTo, LI: Integer;
    begin
      if Length(AArgs) < 3 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['listSlice', '(list, from, to)']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if AArgs[0].Kind <> vkList then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgType, ['listSlice', 'first argument', 'list']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LList := AArgs[0].AsList();
      LFrom := Integer(AArgs[1].AsInt());
      LTo := Integer(AArgs[2].AsInt());
      if LFrom < 0 then LFrom := 0;
      if LTo > LList.Count then LTo := LList.Count;
      Result := TLVMValue.FromList();
      for LI := LFrom to LTo - 1 do
        Result.AsList().Add(LList[LI]);
    end);

  // listJoin(list, sep) -- joins list elements as strings with separator
  RegisterBuiltin('listJoin',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LList: TLVMListStore;
      LSep: string;
      LI: Integer;
      LResult: string;
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['listJoin', '(list, sep)']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if AArgs[0].Kind <> vkList then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgType, ['listJoin', 'first argument', 'list']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LList := AArgs[0].AsList();
      LSep := AArgs[1].AsString();
      LResult := '';
      for LI := 0 to LList.Count - 1 do
      begin
        if LI > 0 then
          LResult := LResult + LSep;
        LResult := LResult + LList[LI].ToString();
      end;
      Result := TLVMValue.FromString(LResult);
    end);

  // listCopy(list) -- returns a shallow copy (new list, same values)
  RegisterBuiltin('listCopy',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LList: TLVMListStore;
      LI: Integer;
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['listCopy', 'a list argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if AArgs[0].Kind <> vkList then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgType, ['listCopy', 'argument', 'list']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LList := AArgs[0].AsList();
      Result := TLVMValue.FromList();
      for LI := 0 to LList.Count - 1 do
        Result.AsList().Add(LList[LI]);
    end);

  // mapKeys(map) -- returns list of all keys (as strings)
  RegisterBuiltin('mapKeys',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LKey: string;
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['mapKeys', 'a map argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if AArgs[0].Kind <> vkMap then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgType, ['mapKeys', 'argument', 'map']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromList();
      for LKey in AArgs[0].AsMap().Keys do
        Result.AsList().Add(TLVMValue.FromString(LKey));
    end);

  // mapValues(map) -- returns list of all values
  RegisterBuiltin('mapValues',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LVal: TLVMValue;
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['mapValues', 'a map argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if AArgs[0].Kind <> vkMap then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgType, ['mapValues', 'argument', 'map']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromList();
      for LVal in AArgs[0].AsMap().Values do
        Result.AsList().Add(LVal);
    end);

  // mapHas(map, key) -- returns bool
  RegisterBuiltin('mapHas',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['mapHas', '(map, key)']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if AArgs[0].Kind <> vkMap then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgType, ['mapHas', 'first argument', 'map']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromBool(AArgs[0].AsMap().ContainsKey(AArgs[1].AsString()));
    end);

  // mapRemove(map, key) -- removes key, returns removed value (or nil)
  RegisterBuiltin('mapRemove',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LMap: TLVMMapStore;
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['mapRemove', '(map, key)']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if AArgs[0].Kind <> vkMap then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgType, ['mapRemove', 'first argument', 'map']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LMap := AArgs[0].AsMap();
      if LMap.TryGetValue(AArgs[1].AsString(), Result) then
        LMap.Remove(AArgs[1].AsString())
      else
        Result := TLVMValue.Nil_();
    end);

  // mapClear(map) -- removes all entries, returns nil
  RegisterBuiltin('mapClear',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['mapClear', 'a map argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if AArgs[0].Kind <> vkMap then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgType, ['mapClear', 'argument', 'map']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      AArgs[0].AsMap().Clear();
      Result := TLVMValue.Nil_();
    end);

  // mapCopy(map) -- returns a shallow copy (new map, same values, preserves TypeName)
  RegisterBuiltin('mapCopy',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LMap: TLVMMapStore;
      LPair: TPair<string, TLVMValue>;
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['mapCopy', 'a map argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if AArgs[0].Kind <> vkMap then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgType, ['mapCopy', 'argument', 'map']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LMap := AArgs[0].AsMap();
      Result := TLVMValue.FromMap();
      Result.AsMap().TypeName := LMap.TypeName;
      for LPair in LMap do
        Result.AsMap().AddOrSetValue(LPair.Key, LPair.Value);
    end);

  // abs(x) -- absolute value (int or float)
  RegisterBuiltin('abs',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['abs', 'an argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if AArgs[0].Kind = vkFloat then
        Result := TLVMValue.FromFloat(System.Abs(AArgs[0].AsFloat()))
      else
        Result := TLVMValue.FromInt(System.Abs(AArgs[0].AsInt()));
    end);

  // min(a, b) -- minimum of two values
  RegisterBuiltin('min',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['min', 'two arguments']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if (AArgs[0].Kind = vkFloat) or (AArgs[1].Kind = vkFloat) then
        Result := TLVMValue.FromFloat(System.Math.Min(AArgs[0].AsFloat(), AArgs[1].AsFloat()))
      else
        Result := TLVMValue.FromInt(System.Math.Min(AArgs[0].AsInt(), AArgs[1].AsInt()));
    end);

  // max(a, b) -- maximum of two values
  RegisterBuiltin('max',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['max', 'two arguments']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if (AArgs[0].Kind = vkFloat) or (AArgs[1].Kind = vkFloat) then
        Result := TLVMValue.FromFloat(System.Math.Max(AArgs[0].AsFloat(), AArgs[1].AsFloat()))
      else
        Result := TLVMValue.FromInt(System.Math.Max(AArgs[0].AsInt(), AArgs[1].AsInt()));
    end);

  // clamp(x, lo, hi) -- clamp x between lo and hi
  RegisterBuiltin('clamp',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 3 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['clamp', '(x, lo, hi)']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if (AArgs[0].Kind = vkFloat) or (AArgs[1].Kind = vkFloat) or (AArgs[2].Kind = vkFloat) then
        Result := TLVMValue.FromFloat(
          System.Math.Max(AArgs[1].AsFloat(),
            System.Math.Min(AArgs[0].AsFloat(), AArgs[2].AsFloat())))
      else
        Result := TLVMValue.FromInt(
          System.Math.Max(AArgs[1].AsInt(),
            System.Math.Min(AArgs[0].AsInt(), AArgs[2].AsInt())));
    end);

  // floor(x) -- float->int, round toward negative infinity
  RegisterBuiltin('floor',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['floor', 'an argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromInt(System.Math.Floor(AArgs[0].AsFloat()));
    end);

  // ceil(x) -- float->int, round toward positive infinity
  RegisterBuiltin('ceil',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['ceil', 'an argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromInt(System.Math.Ceil(AArgs[0].AsFloat()));
    end);

  // round(x) -- float->int, round to nearest
  RegisterBuiltin('round',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['round', 'an argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromInt(System.Round(AArgs[0].AsFloat()));
    end);

  // toFloat(x) -- int->float conversion
  RegisterBuiltin('toFloat',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['toFloat', 'an argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if AArgs[0].Kind = vkFloat then
        Result := AArgs[0]
      else
        Result := TLVMValue.FromFloat(AArgs[0].AsInt() * 1.0);
    end);

  // toInt(x) -- float->int truncation, or string->int
  RegisterBuiltin('toInt',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['toInt', 'an argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if AArgs[0].Kind = vkFloat then
        Result := TLVMValue.FromInt(Trunc(AArgs[0].AsFloat()))
      else if AArgs[0].Kind = vkString then
        Result := TLVMValue.FromInt(StrToInt64Def(AArgs[0].AsString(), 0))
      else if AArgs[0].Kind = vkBool then
        Result := TLVMValue.FromInt(Ord(AArgs[0].AsBool()))
      else
        Result := TLVMValue.FromInt(AArgs[0].AsInt());
    end);

  // pow(base, exp) -- power
  RegisterBuiltin('pow',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['pow', '(base, exp)']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if (AArgs[0].Kind = vkFloat) or (AArgs[1].Kind = vkFloat) then
        Result := TLVMValue.FromFloat(Power(AArgs[0].AsFloat(), AArgs[1].AsFloat()))
      else
        Result := TLVMValue.FromInt(Round(Power(AArgs[0].AsInt(), AArgs[1].AsInt())));
    end);

  // log2(x) -- integer log2 (highest set bit position)
  RegisterBuiltin('log2',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LVal: Int64;
      LBit: Integer;
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['log2', 'an argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LVal := AArgs[0].AsInt();
      if LVal <= 0 then
        Exit(TLVMValue.FromInt(-1));
      LBit := 0;
      while LVal > 1 do
      begin
        LVal := LVal shr 1;
        Inc(LBit);
      end;
      Result := TLVMValue.FromInt(LBit);
    end);

  // isInt(x) -- returns bool
  RegisterBuiltin('isInt',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then Exit(TLVMValue.FromBool(False));
      Result := TLVMValue.FromBool(AArgs[0].Kind = vkInt);
    end);

  // isFloat(x) -- returns bool
  RegisterBuiltin('isFloat',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then Exit(TLVMValue.FromBool(False));
      Result := TLVMValue.FromBool(AArgs[0].Kind = vkFloat);
    end);

  // floatBitsToInt(x) -- reinterpret float bits as int64
  RegisterBuiltin('floatBitsToInt',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LFloat: Double;
    begin
      if Length(AArgs) < 1 then Exit(TLVMValue.FromInt(0));
      LFloat := AArgs[0].AsFloat();
      Result := TLVMValue.FromInt(PInt64(@LFloat)^);
    end);

  // isString(x) -- returns bool
  RegisterBuiltin('isString',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then Exit(TLVMValue.FromBool(False));
      Result := TLVMValue.FromBool(AArgs[0].Kind = vkString);
    end);

  // isBool(x) -- returns bool
  RegisterBuiltin('isBool',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then Exit(TLVMValue.FromBool(False));
      Result := TLVMValue.FromBool(AArgs[0].Kind = vkBool);
    end);

  // isList(x) -- returns bool
  RegisterBuiltin('isList',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then Exit(TLVMValue.FromBool(False));
      Result := TLVMValue.FromBool(AArgs[0].Kind = vkList);
    end);

  // isMap(x) -- returns bool
  RegisterBuiltin('isMap',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then Exit(TLVMValue.FromBool(False));
      Result := TLVMValue.FromBool(AArgs[0].Kind = vkMap);
    end);

  // isNil(x) -- returns bool
  RegisterBuiltin('isNil',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then Exit(TLVMValue.FromBool(True));
      Result := TLVMValue.FromBool(AArgs[0].Kind = vkNil);
    end);

  // isBuffer(x) -- returns bool
  RegisterBuiltin('isBuffer',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then Exit(TLVMValue.FromBool(False));
      Result := TLVMValue.FromBool(AArgs[0].Kind = vkBuffer);
    end);

  // -- String extras --

  // split(s, delim) -- returns list of substrings
  RegisterBuiltin('split',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LParts: TArray<string>;
      LI: Integer;
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['split', '(s, delim)']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LParts := AArgs[0].AsString().Split([AArgs[1].AsString()]);
      Result := TLVMValue.FromList();
      for LI := 0 to Length(LParts) - 1 do
        Result.AsList().Add(TLVMValue.FromString(LParts[LI]));
    end);

  // charAt(s, index) -- returns single character as string (0-based)
  RegisterBuiltin('charAt',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LStr: string;
      LIdx: Integer;
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['charAt', '(s, index)']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LStr := AArgs[0].AsString();
      LIdx := Integer(AArgs[1].AsInt());
      // 0-based index for the LVM, 1-based for Delphi
      if (LIdx < 0) or (LIdx >= Length(LStr)) then
        Result := TLVMValue.FromString('')
      else
        Result := TLVMValue.FromString(LStr[LIdx + 1]);
    end);

  // padLeft(s, width, ch) -- pad string on left to width with ch
  RegisterBuiltin('padLeft',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LStr, LCh: string;
      LWidth: Integer;
    begin
      if Length(AArgs) < 3 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['padLeft', '(s, width, ch)']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LStr := AArgs[0].AsString();
      LWidth := Integer(AArgs[1].AsInt());
      LCh := AArgs[2].AsString();
      if LCh = '' then LCh := ' ';
      while Length(LStr) < LWidth do
        LStr := LCh[1] + LStr;
      Result := TLVMValue.FromString(LStr);
    end);

  // padRight(s, width, ch) -- pad string on right to width with ch
  RegisterBuiltin('padRight',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LStr, LCh: string;
      LWidth: Integer;
    begin
      if Length(AArgs) < 3 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['padRight', '(s, width, ch)']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LStr := AArgs[0].AsString();
      LWidth := Integer(AArgs[1].AsInt());
      LCh := AArgs[2].AsString();
      if LCh = '' then LCh := ' ';
      while Length(LStr) < LWidth do
        LStr := LStr + LCh[1];
      Result := TLVMValue.FromString(LStr);
    end);

  // repeat(s, count) -- repeat string N times
  RegisterBuiltin('repeat',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LResult: string;
      LI, LCount: Integer;
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['repeat', '(s, count)']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LResult := '';
      LCount := Integer(AArgs[1].AsInt());
      for LI := 1 to LCount do
        LResult := LResult + AArgs[0].AsString();
      Result := TLVMValue.FromString(LResult);
    end);

  // indexOf(s, sub) -- returns position of sub in s (0-based) or -1
  RegisterBuiltin('indexOf',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LPos: Integer;
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['indexOf', '(s, sub)']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LPos := Pos(AArgs[1].AsString(), AArgs[0].AsString());
      if LPos > 0 then
        Result := TLVMValue.FromInt(LPos - 1)  // 0-based
      else
        Result := TLVMValue.FromInt(-1);
    end);

  // toBool(x) -- any value to bool (truthy check)
  RegisterBuiltin('toBool',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['toBool', 'an argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromBool(AArgs[0].IsTrue());
    end);

  // toString(x) -- any value to its string representation
  RegisterBuiltin('toString',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['toString', 'an argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromString(AArgs[0].ToString());
    end);

  // hexToInt(s) -- parse hex string (with or without 0x) to int
  RegisterBuiltin('hexToInt',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LStr: string;
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['hexToInt', 'a string argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LStr := AArgs[0].AsString();
      if LStr.StartsWith('0x') or LStr.StartsWith('0X') then
        LStr := '$' + Copy(LStr, 3)
      else
        LStr := '$' + LStr;
      Result := TLVMValue.FromInt(StrToInt64Def(LStr, 0));
    end);

  // intToHex(n, digits) -- int to hex string with minimum digits
  RegisterBuiltin('intToHex',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['intToHex', '(n, digits)']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromString(IntToHex(AArgs[0].AsInt(), Integer(AArgs[1].AsInt())));
    end);

  // -- Utility builtins --

  // assert(cond, msg) -- if cond is falsy, raise with msg
  RegisterBuiltin('assert',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['assert', '(cond, msg)']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if not AArgs[0].IsTrue() then
        begin
          AVM.GetErrors().RaiseOnError := True;
          AVM.GetErrors().Add(esError, ERR_LVM_ASSERT,
            'Assertion failed: %s', [AArgs[1].AsString()]);
        end;
      Result := TLVMValue.Nil_();
    end);

  // error(msg) -- unconditional raise with msg
  RegisterBuiltin('error',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['error', 'a message argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      begin
        AVM.GetErrors().RaiseOnError := True;
        AVM.GetErrors().Add(esError, ERR_LVM_USER, AArgs[0].AsString());
      end;
    end);

  // errorAt(node, msg) -- report error at a user AST node's source location
  RegisterBuiltin('errorAt',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LNode: TLVMASTNode;
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['errorAt', 'node and message']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      AVM.GetErrors().RaiseOnError := True;
      if (AArgs[0].Kind = vkHandle) and (AArgs[0].AsHandle() <> nil) and
         (TObject(AArgs[0].AsHandle()) is TLVMASTNode) then
      begin
        LNode := TLVMASTNode(AArgs[0].AsHandle());
        AVM.GetErrors().Add(LNode.Filename, LNode.Line, LNode.Col,
          esError, ERR_LVM_USER, AArgs[1].AsString());
      end
      else
        AVM.GetErrors().Add(esError, ERR_LVM_USER, AArgs[1].AsString());
    end);

  // errorEx(filename, line, col, msg) -- report error with explicit location
  RegisterBuiltin('errorEx',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 4 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs,
            ['errorEx', 'filename, line, col, message']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      AVM.GetErrors().RaiseOnError := True;
      AVM.GetErrors().Add(AArgs[0].AsString(), AArgs[1].AsInt(),
        AArgs[2].AsInt(), esError, ERR_LVM_USER, AArgs[3].AsString());
    end);

  // range(start, end) or range(end) -- returns list of ints
  RegisterBuiltin('range',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LStart, LEnd, LI: Int64;
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['range', 'at least one argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if Length(AArgs) >= 2 then
      begin
        LStart := AArgs[0].AsInt();
        LEnd := AArgs[1].AsInt();
      end
      else
      begin
        LStart := 0;
        LEnd := AArgs[0].AsInt();
      end;
      Result := TLVMValue.FromList();
      for LI := LStart to LEnd - 1 do
        Result.AsList().Add(TLVMValue.FromInt(LI));
    end);

  // time() -- returns current timestamp as float (seconds from GetTickCount64)
  RegisterBuiltin('time',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      Result := TLVMValue.FromFloat(Now() * 86400.0);
    end);

  // random(n) -- returns random int in [0..n-1]
  RegisterBuiltin('random',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['random', 'an argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromInt(System.Random(Integer(AArgs[0].AsInt())));
    end);

  // randomFloat() -- returns random float in [0.0..1.0)
  RegisterBuiltin('randomFloat',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      Result := TLVMValue.FromFloat(System.Random());
    end);

  // environ(name) -- read environment variable, returns string or nil
  RegisterBuiltin('environ',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LVal: string;
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['environ', 'a name argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LVal := GetEnvironmentVariable(AArgs[0].AsString());
      if LVal = '' then
        Result := TLVMValue.Nil_()
      else
        Result := TLVMValue.FromString(LVal);
    end);

  // pathJoin(a, b) -- join path components
  RegisterBuiltin('pathJoin',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['pathJoin', '(a, b)']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromString(
        TPath.Combine(AArgs[0].AsString(), AArgs[1].AsString()));
    end);

  // pathDir(path) -- extract directory from path
  RegisterBuiltin('pathDir',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['pathDir', 'a path argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromString(
        TPath.GetDirectoryName(AArgs[0].AsString()));
    end);

  // pathFile(path) -- extract filename from path
  RegisterBuiltin('pathFile',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['pathFile', 'a path argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromString(
        TPath.GetFileName(AArgs[0].AsString()));
    end);

  // pathExt(path) -- extract extension from path
  RegisterBuiltin('pathExt',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['pathExt', 'a path argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromString(
        TPath.GetExtension(AArgs[0].AsString()));
    end);

  // resolvePath(path) -- resolve VFS path ($P: etc.) to absolute path
  RegisterBuiltin('resolvePath',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['resolvePath', 'a path argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromString(
        TUtils.ResolvePath(AArgs[0].AsString(), AVM.FBaseDir));
    end);

  // pathChangeExt(path, ext) -- change file extension
  RegisterBuiltin('pathChangeExt',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['pathChangeExt', '(path, ext)']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromString(
        TPath.ChangeExtension(AArgs[0].AsString(), AArgs[1].AsString()));
    end);

  // pathBaseName(path) -- filename without extension
  RegisterBuiltin('pathBaseName',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['pathBaseName', 'a path argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromString(
        TPath.GetFileNameWithoutExtension(AArgs[0].AsString()));
    end);

  // unixTime() -- returns current Unix epoch timestamp (seconds since 1970)
  RegisterBuiltin('unixTime',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      Result := TLVMValue.FromInt(DateTimeToUnix(Now(), False));
    end);

  // fileExists(path) -- returns bool
  RegisterBuiltin('fileExists',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['fileExists', 'a path argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromBool(TFile.Exists(AArgs[0].AsString()));
    end);

  // dirExists(path) -- returns bool
  RegisterBuiltin('dirExists',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['dirExists', 'a path argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromBool(TDirectory.Exists(AArgs[0].AsString()));
    end);

  // addImportPath(path) -- add a search path for import resolution
  RegisterBuiltin('addImportPath',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['addImportPath', 'a path argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      AVM.AddImportPath(AArgs[0].AsString());
      Result := TLVMValue.Nil_();
    end);

  // loadDll(path) -- load a DLL via LoadLibraryW, return handle as int
  RegisterBuiltin('loadDll',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LHandle: THandle;
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['loadDll', 'a path argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LHandle := LoadLibraryW(PWideChar(AArgs[0].AsString()));
      if LHandle = 0 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['loadDll', AArgs[0].AsString(), GetLastError()]);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromInt(Int64(LHandle));
    end);

  // freeDll(handle) -- free a loaded DLL via FreeLibrary
  RegisterBuiltin('freeDll',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['freeDll', 'a handle argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      try
        FreeLibrary(THandle(AArgs[0].AsInt()));
      except
        on E: Exception do
          begin
            AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
              RSLVMBuiltinFailed, ['freeDll', E.Message]);
          end;
      end;
      Result := TLVMValue.Nil_();
    end);

  // getDllProc(handle, name) -- get function address via GetProcAddress, return as int
  RegisterBuiltin('getDllProc',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LProc: Pointer;
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['getDllProc', 'handle and name arguments']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LProc := GetProcAddress(THandle(AArgs[0].AsInt()),
        PAnsiChar(AnsiString(AArgs[1].AsString())));
      if LProc = nil then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['getDllProc', AArgs[1].AsString(), GetLastError()]);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromInt(Int64(UIntPtr(LProc)));
    end);

  // callDllProc(proc) -- call a no-arg stdcall function returning int64
  RegisterBuiltin('callDllProc',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    type
      TNoArgFunc = function: Int64; stdcall;
    var
      LFunc: TNoArgFunc;
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['callDllProc', 'a function pointer argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LFunc := TNoArgFunc(Pointer(UIntPtr(AArgs[0].AsInt())));
      try
        Result := TLVMValue.FromInt(LFunc());
      except
        on E: Exception do
          begin
            AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN,
              RSLVMBuiltinFailed, ['callDllProc', E.Message]);
            Result := TLVMValue.Nil_();
          end;
      end;
    end);

  // symbolExists(name) -> bool
  RegisterBuiltin('symbolExists',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        Exit(TLVMValue.FromBool(False));
      Result := TLVMValue.FromBool(AVM.FScopes.SymbolExists(AArgs[0].AsString()));
    end);

  // declareSymbol(name, kind) or declareSymbol(name, kind, type)
  // Programmatically declare a symbol in the current semantic scope
  RegisterBuiltin('declareSymbol',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LSym: TLVMSymbol;
    begin
      Result := TLVMValue.Nil_();
      if Length(AArgs) < 2 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs,
          ['declareSymbol', '(name, kind[, type])']);
        Exit;
      end;
      AVM.FScopes.Declare(AArgs[0].AsString(), AArgs[1].AsString());
      if Length(AArgs) >= 3 then
      begin
        LSym := AVM.FScopes.Lookup(AArgs[0].AsString());
        if LSym <> nil then
          LSym.TypeName := AArgs[2].AsString();
      end;
    end);

  // lookupSymbol(name) -> map{name,kind,type,node} or nil
  RegisterBuiltin('lookupSymbol',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LSym: TLVMSymbol;
    begin
      if Length(AArgs) < 1 then
        Exit(TLVMValue.Nil_());
      LSym := AVM.FScopes.Lookup(AArgs[0].AsString());
      if LSym = nil then
        Exit(TLVMValue.Nil_());
      Result := TLVMValue.FromMap();
      Result.AsMap().AddOrSetValue('name', TLVMValue.FromString(LSym.SymName));
      Result.AsMap().AddOrSetValue('kind', TLVMValue.FromString(LSym.SymKind));
      Result.AsMap().AddOrSetValue('type', TLVMValue.FromString(LSym.TypeName));
      if LSym.DeclNode <> nil then
        Result.AsMap().AddOrSetValue('node', TLVMValue.FromHandle(LSym.DeclNode));
    end);

  // lookupGlobal(name) -> map{name,kind,type,node} or nil
  RegisterBuiltin('lookupGlobal',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LSym: TLVMSymbol;
    begin
      if Length(AArgs) < 1 then
        Exit(TLVMValue.Nil_());
      LSym := AVM.FScopes.LookupGlobal(AArgs[0].AsString());
      if LSym = nil then
        Exit(TLVMValue.Nil_());
      Result := TLVMValue.FromMap();
      Result.AsMap().AddOrSetValue('name', TLVMValue.FromString(LSym.SymName));
      Result.AsMap().AddOrSetValue('kind', TLVMValue.FromString(LSym.SymKind));
      Result.AsMap().AddOrSetValue('type', TLVMValue.FromString(LSym.TypeName));
      if LSym.DeclNode <> nil then
        Result.AsMap().AddOrSetValue('node', TLVMValue.FromHandle(LSym.DeclNode));
    end);

  // saveScopeState() -- save current scope position and semantic pass state, reset to root
  RegisterBuiltin('saveScopeState',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      AVM.FScopes.SaveState();
      AVM.FSemanticDictStack.Add(AVM.FActiveSemanticDict);
      Result := TLVMValue.Nil_();
    end);

  // restoreScopeState() -- restore previously saved scope position and semantic pass state
  RegisterBuiltin('restoreScopeState',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      AVM.FScopes.RestoreState();
      if AVM.FSemanticDictStack.Count > 0 then
      begin
        AVM.FActiveSemanticDict := AVM.FSemanticDictStack[AVM.FSemanticDictStack.Count - 1];
        AVM.FSemanticDictStack.Delete(AVM.FSemanticDictStack.Count - 1);
      end;
      Result := TLVMValue.Nil_();
    end);

  // pushState(newSourceFilename?) -- save SourceFilename and optionally set a new one
  RegisterBuiltin('pushState',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      AVM.FStateStack.Add(AVM.GetSourceFilename());
      if Length(AArgs) > 0 then
      begin
        AVM.FEnvironment.EnterGlobalScope();
        try
          AVM.SetSourceFilename(AArgs[0].AsString());
        finally
          AVM.FEnvironment.LeaveGlobalScope();
        end;
      end;
      Result := TLVMValue.Nil_();
    end);

  // popState() -- restore previously saved SourceFilename
  RegisterBuiltin('popState',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if AVM.FStateStack.Count > 0 then
      begin
        AVM.FEnvironment.EnterGlobalScope();
        try
          AVM.SetSourceFilename(AVM.FStateStack[AVM.FStateStack.Count - 1]);
        finally
          AVM.FEnvironment.LeaveGlobalScope();
        end;
        AVM.FStateStack.Delete(AVM.FStateStack.Count - 1);
      end;
      Result := TLVMValue.Nil_();
    end);

  // checkToken(kind) -> bool
  RegisterBuiltin('checkToken',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if (AVM.FActiveParser = nil) or (Length(AArgs) < 1) then
        Exit(TLVMValue.FromBool(False));
      Result := TLVMValue.FromBool(
        TLVMGenericParser(AVM.FActiveParser).Check(AArgs[0].AsString()));
    end);

  // matchToken(kind) -> bool
  RegisterBuiltin('matchToken',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if (AVM.FActiveParser = nil) or (Length(AArgs) < 1) then
        Exit(TLVMValue.FromBool(False));
      Result := TLVMValue.FromBool(
        TLVMGenericParser(AVM.FActiveParser).Match(AArgs[0].AsString()));
    end);

  // advance() -> string
  RegisterBuiltin('advance',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LText: string;
    begin
      if AVM.FActiveParser = nil then
        Exit(TLVMValue.FromString(''));
      LText := TLVMGenericParser(AVM.FActiveParser).Current().Text;
      TLVMGenericParser(AVM.FActiveParser).DoAdvance();
      Result := TLVMValue.FromString(LText);
    end);

  // requireToken(kind)
  RegisterBuiltin('requireToken',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if (AVM.FActiveParser = nil) or (Length(AArgs) < 1) then
        Exit(TLVMValue.Nil_());
      TLVMGenericParser(AVM.FActiveParser).Expect(AArgs[0].AsString());
      Result := TLVMValue.Nil_();
    end);

  // currentText() -> string
  RegisterBuiltin('currentText',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if AVM.FActiveParser = nil then
        Exit(TLVMValue.FromString(''));
      Result := TLVMValue.FromString(
        TLVMGenericParser(AVM.FActiveParser).Current().Text);
    end);

  // currentKind() -> string
  RegisterBuiltin('currentKind',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if AVM.FActiveParser = nil then
        Exit(TLVMValue.FromString(''));
      Result := TLVMValue.FromString(
        TLVMGenericParser(AVM.FActiveParser).Current().Kind);
    end);

  // peekKind() -> string
  RegisterBuiltin('peekKind',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if AVM.FActiveParser = nil then
        Exit(TLVMValue.FromString(''));
      Result := TLVMValue.FromString(
        TLVMGenericParser(AVM.FActiveParser).Peek().Kind);
    end);

  // peekKindAt(offset) -> string
  RegisterBuiltin('peekKindAt',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if (AVM.FActiveParser = nil) or (Length(AArgs) < 1) then
        Exit(TLVMValue.FromString(''));
      Result := TLVMValue.FromString(
        TLVMGenericParser(AVM.FActiveParser).PeekAt(AArgs[0].AsInt()).Kind);
    end);

  // getResultNode() -> node
  RegisterBuiltin('getResultNode',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      Result := AVM.FResultNode;
    end);

  // parseExpr(power?) -> node
  RegisterBuiltin('parseExpr',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LPower: Integer;
      LNode: TLVMASTNode;
    begin
      if AVM.FActiveParser = nil then
        Exit(TLVMValue.Nil_());
      if Length(AArgs) >= 1 then
        LPower := AArgs[0].AsInt()
      else
        LPower := 0;
      LNode := TLVMGenericParser(AVM.FActiveParser).ParseExpression(LPower);
      if Assigned(LNode) then
        Result := TLVMValue.FromHandle(LNode)
      else
        Result := TLVMValue.Nil_();
    end);

  // parseExprFrom(left, power) -> node
  RegisterBuiltin('parseExprFrom',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LLeft: TLVMASTNode;
      LNode: TLVMASTNode;
    begin
      if (AVM.FActiveParser = nil) or (Length(AArgs) < 2) then
        Exit(TLVMValue.Nil_());
      LLeft := TLVMASTNode(AArgs[0].AsHandle());
      LNode := TLVMGenericParser(AVM.FActiveParser).ParseExpressionFrom(
        LLeft, AArgs[1].AsInt());
      if Assigned(LNode) then
        Result := TLVMValue.FromHandle(LNode)
      else
        Result := TLVMValue.Nil_();
    end);

  // parseStmt() -> node
  RegisterBuiltin('parseStmt',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LNode: TLVMASTNode;
    begin
      if AVM.FActiveParser = nil then
        Exit(TLVMValue.Nil_());
      LNode := TLVMGenericParser(AVM.FActiveParser).ParseStatement();
      if Assigned(LNode) then
        Result := TLVMValue.FromHandle(LNode)
      else
        Result := TLVMValue.Nil_();
    end);

  // collectUntil(kind) -> string
  RegisterBuiltin('collectUntil',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LParser: TLVMGenericParser;
      LResult: string;
    begin
      if (AVM.FActiveParser = nil) or (Length(AArgs) < 1) then
        Exit(TLVMValue.FromString(''));
      LParser := TLVMGenericParser(AVM.FActiveParser);
      LResult := '';
      while (not LParser.AtEnd()) and
            (LParser.Current().Kind <> AArgs[0].AsString()) do
      begin
        if LResult <> '' then
          LResult := LResult + ' ';
        LResult := LResult + LParser.Current().Text;
        LParser.DoAdvance();
      end;
      Result := TLVMValue.FromString(LResult);
    end);

  // collectRaw() -> string
  RegisterBuiltin('collectRaw',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LParser: TLVMGenericParser;
      LResult: string;
    begin
      if AVM.FActiveParser = nil then
        Exit(TLVMValue.FromString(''));
      LParser := TLVMGenericParser(AVM.FActiveParser);
      LResult := '';
      while not LParser.AtEnd() do
      begin
        if LResult <> '' then
          LResult := LResult + ' ';
        LResult := LResult + LParser.Current().Text;
        LParser.DoAdvance();
      end;
      Result := TLVMValue.FromString(LResult);
    end);

  // setDefine(name) or setDefine(name, value) -- add conditional define
  RegisterBuiltin('setDefine',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['setDefine', 'a name argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      if Length(AArgs) >= 2 then
        AVM.FDefines.AddOrSetValue(AArgs[0].AsString(), AArgs[1].AsString())
      else
        AVM.FDefines.AddOrSetValue(AArgs[0].AsString(), '');
      Result := TLVMValue.Nil_();
    end);

  // removeDefine(name) -- remove conditional define
  RegisterBuiltin('removeDefine',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['removeDefine', 'a name argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      AVM.FDefines.Remove(AArgs[0].AsString());
      Result := TLVMValue.Nil_();
    end);

  // hasDefine(name) -> bool -- check if define exists
  RegisterBuiltin('hasDefine',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['hasDefine', 'a name argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      Result := TLVMValue.FromBool(AVM.FDefines.ContainsKey(AArgs[0].AsString()));
    end);

  // clearDefines() -- clear all defines
  RegisterBuiltin('clearDefines',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      AVM.FDefines.Clear();
      Result := TLVMValue.Nil_();
    end);

  // setModuleExtension(ext) -- set the file extension for module resolution
  RegisterBuiltin('setModuleExtension',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['setModuleExtension', 'an extension argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      AVM.FModuleExtension := AArgs[0].AsString();
      Result := TLVMValue.Nil_();
    end);

  // getModuleExtension() -- get the file extension for module resolution
  RegisterBuiltin('getModuleExtension',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      Result := TLVMValue.FromString(AVM.FModuleExtension);
    end);

  // addModulePath(path) -- add a module search path (resolves $P: etc.)
  RegisterBuiltin('addModulePath',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['addModulePath', 'a path argument']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      AVM.AddImportPath(AArgs[0].AsString());
      Result := TLVMValue.Nil_();
    end);

  // lexSource(source, filename) -> handle to token list
  RegisterBuiltin('lexSource',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LLexer: TLVMGenericLexer;
      LTokens: TList<TLVMUserToken>;
    begin
      if Length(AArgs) < 2 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['lexSource', 'source and filename arguments']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LLexer := TLVMGenericLexer.Create();
      LLexer.SetErrors(AVM.GetErrors());
      LLexer.SetStatusCallback(AVM.GetStatusCallback(), AVM.FStatusCallback.UserData);
      try
        LLexer.Configure(AVM);
        LTokens := LLexer.Tokenize(AArgs[0].AsString(), AArgs[1].AsString());
        AVM.FUserTokenLists.Add(LTokens);
        Result := TLVMValue.FromHandle(Pointer(LTokens));
      finally
        LLexer.Free();
      end;
    end);

  // parseProgram(tokenListHandle, filename) -> handle to AST root
  RegisterBuiltin('parseProgram',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LParser: TLVMGenericParser;
      LTokens: TList<TLVMUserToken>;
      LRoot: TLVMASTNode;
      LFilename: string;
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['parseProgram', 'a token list handle']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      LTokens := TList<TLVMUserToken>(AArgs[0].AsHandle());
      if Length(AArgs) >= 2 then
        LFilename := AArgs[1].AsString()
      else
        LFilename := '';
      LRoot := nil;
      LParser := TLVMGenericParser.Create();
      LParser.SetErrors(AVM.GetErrors());
      LParser.SetStatusCallback(AVM.GetStatusCallback(), AVM.FStatusCallback.UserData);
      try
        LParser.Configure(AVM);
        LRoot := LParser.ParseProgram(LTokens, LFilename);
        AVM.FUserASTRoots.Add(LRoot);
        Result := TLVMValue.FromHandle(Pointer(LRoot));
      finally
        // Track root even on exception so it gets freed with the VM
        if (LRoot <> nil) and (AVM.FUserASTRoots.IndexOf(LRoot) < 0) then
          AVM.FUserASTRoots.Add(LRoot);
        LParser.Free();
      end;
    end);

  // runSemantics(astRootHandle) -- run semantic pass handlers on user AST
  RegisterBuiltin('runSemantics',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['runSemantics', 'an AST root handle']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      AVM.RunSemantics(AArgs[0]);
      Result := TLVMValue.Nil_();
    end);

  // runEmitters(astRootHandle) -- run emitter handlers on user AST
  RegisterBuiltin('runEmitters',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['runEmitters', 'an AST root handle']);
          Result := TLVMValue.Nil_();
          Exit;
        end;
      AVM.RunEmitters(AArgs[0]);
      Result := TLVMValue.Nil_();
    end);

  // runMir() -- walk MIR program and fire on-handlers
  RegisterBuiltin('runMir',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      AVM.RunMir();
      Result := TLVMValue.Nil_();
    end);

  // mirOptimize() -- run optimization passes on MIR program
  RegisterBuiltin('mirOptimize',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      AVM.OptimizeMir();
      Result := TLVMValue.Nil_();
    end);

  // mirBeginModule(name: string)
  RegisterBuiltin('mirBeginModule',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LMod: TLVMMirModule;
    begin
      if Length(AArgs) < 1 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['mirBeginModule', 'a name argument']);
        Exit(TLVMValue.Nil_());
      end;
      if AVM.FCurrentMirModule <> nil then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirBeginModule', 'nested modules not allowed']);
        Exit(TLVMValue.Nil_());
      end;
      LMod := TLVMMirModule.Create();
      LMod.ModuleName := AArgs[0].AsString();
      AVM.FCurrentMirModule := LMod;
      Result := TLVMValue.Nil_();
    end);

  // mirEndModule()
  RegisterBuiltin('mirEndModule',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if AVM.FCurrentMirModule = nil then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirEndModule', 'no module in progress']);
        Exit(TLVMValue.Nil_());
      end;
      AVM.FMirProgram.AddModule(AVM.FCurrentMirModule);
      AVM.FCurrentMirModule := nil;
      Result := TLVMValue.Nil_();
    end);

  // mirImport(name: string)
  RegisterBuiltin('mirImport',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['mirImport', 'a name argument']);
        Exit(TLVMValue.Nil_());
      end;
      if AVM.FCurrentMirModule = nil then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirImport', 'no module in progress']);
        Exit(TLVMValue.Nil_());
      end;
      AVM.FCurrentMirModule.AddImport(AArgs[0].AsString());
      Result := TLVMValue.Nil_();
    end);

  // mirExport(name: string)
  RegisterBuiltin('mirExport',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['mirExport', 'a name argument']);
        Exit(TLVMValue.Nil_());
      end;
      if AVM.FCurrentMirModule = nil then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirExport', 'no module in progress']);
        Exit(TLVMValue.Nil_());
      end;
      AVM.FCurrentMirModule.AddExport(AArgs[0].AsString());
      Result := TLVMValue.Nil_();
    end);

  // mirForward(name: string)
  RegisterBuiltin('mirForward',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['mirForward', 'a name argument']);
        Exit(TLVMValue.Nil_());
      end;
      if AVM.FCurrentMirModule = nil then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirForward', 'no module in progress']);
        Exit(TLVMValue.Nil_());
      end;
      AVM.FCurrentMirModule.AddForward(AArgs[0].AsString());
      Result := TLVMValue.Nil_();
    end);

  // mirProto(name: string, resultTypes: list<string>, paramTypes: list<string>)
  RegisterBuiltin('mirProto',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LProto: TLVMMirProto;
      LList: TLVMListStore;
      LI: Integer;
      LT: TLVMMirType;
      LStr: string;
    begin
      if Length(AArgs) < 3 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['mirProto', '(name, resultTypes, paramTypes)']);
        Exit(TLVMValue.Nil_());
      end;
      if AVM.FCurrentMirModule = nil then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirProto', 'no module in progress']);
        Exit(TLVMValue.Nil_());
      end;
      LProto := Default(TLVMMirProto);
      LProto.ProtoName := AArgs[0].AsString();
      // Result types
      LList := AArgs[1].AsList();
      SetLength(LProto.ResultTypes, LList.Count);
      for LI := 0 to LList.Count - 1 do
      begin
        if not MirStrToType(LList[LI].AsString(), LT) then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirProto', LList[LI].AsString()]);
          Exit(TLVMValue.Nil_());
        end;
        LProto.ResultTypes[LI] := LT;
      end;
      // Param types (format: "type:name" or "...")
      LList := AArgs[2].AsList();
      SetLength(LProto.ParamTypes, LList.Count);
      SetLength(LProto.ParamNames, LList.Count);
      for LI := 0 to LList.Count - 1 do
      begin
        LStr := LList[LI].AsString();
        if LStr = '...' then
        begin
          LProto.IsVararg := True;
          SetLength(LProto.ParamTypes, LI);
          SetLength(LProto.ParamNames, LI);
          Break;
        end;
        if Pos(':', LStr) > 0 then
        begin
          if not MirStrToType(Copy(LStr, 1, Pos(':', LStr) - 1), LT) then
          begin
            AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirProto', LStr]);
            Exit(TLVMValue.Nil_());
          end;
          LProto.ParamTypes[LI] := LT;
          LProto.ParamNames[LI] := Copy(LStr, Pos(':', LStr) + 1, MaxInt);
        end
        else
        begin
          if not MirStrToType(LStr, LT) then
          begin
            AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirProto', LStr]);
            Exit(TLVMValue.Nil_());
          end;
          LProto.ParamTypes[LI] := LT;
          LProto.ParamNames[LI] := '';
        end;
      end;
      AVM.FCurrentMirModule.AddProto(LProto);
      Result := TLVMValue.Nil_();
    end);

  // mirLocal(name: string, typeName: string [, hardReg: string])
  RegisterBuiltin('mirLocal',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LLocal: TLVMMirLocal;
      LT: TLVMMirType;
    begin
      if Length(AArgs) < 2 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['mirLocal', '(name, typeName)']);
        Exit(TLVMValue.Nil_());
      end;
      if AVM.FCurrentMirFunc = nil then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirLocal', 'no function in progress']);
        Exit(TLVMValue.Nil_());
      end;
      if not MirStrToType(AArgs[1].AsString(), LT) then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirLocal', AArgs[1].AsString()]);
        Exit(TLVMValue.Nil_());
      end;
      LLocal := Default(TLVMMirLocal);
      LLocal.LocalName := AArgs[0].AsString();
      LLocal.LocalType := LT;
      if Length(AArgs) >= 3 then
        LLocal.HardReg := AArgs[2].AsString();
      AVM.FCurrentMirFunc.AddLocal(LLocal);
      Result := TLVMValue.Nil_();
    end);

  // mirString(name: string, value: string)
  RegisterBuiltin('mirString',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LItem: TLVMMirDataItem;
    begin
      if Length(AArgs) < 2 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['mirString', '(name, value)']);
        Exit(TLVMValue.Nil_());
      end;
      if AVM.FCurrentMirModule = nil then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirString', 'no module in progress']);
        Exit(TLVMValue.Nil_());
      end;
      LItem := Default(TLVMMirDataItem);
      LItem.DataKind := mdkString;
      LItem.ItemName := AArgs[0].AsString();
      LItem.StrValue := AArgs[1].AsString();
      AVM.FCurrentMirModule.AddDataItem(LItem);
      Result := TLVMValue.Nil_();
    end);

  // mirData(name: string, dataType: string, values: list)
  RegisterBuiltin('mirData',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LItem: TLVMMirDataItem;
      LT: TLVMMirType;
      LList: TLVMListStore;
      LI: Integer;
    begin
      if Length(AArgs) < 3 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['mirData', '(name, dataType, values)']);
        Exit(TLVMValue.Nil_());
      end;
      if AVM.FCurrentMirModule = nil then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirData', 'no module in progress']);
        Exit(TLVMValue.Nil_());
      end;
      if not MirStrToType(AArgs[1].AsString(), LT) then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirData', AArgs[1].AsString()]);
        Exit(TLVMValue.Nil_());
      end;
      LItem := Default(TLVMMirDataItem);
      LItem.DataKind := mdkData;
      LItem.ItemName := AArgs[0].AsString();
      LItem.DataType := LT;
      LList := AArgs[2].AsList();
      if (LT = mtF) or (LT = mtD) then
      begin
        SetLength(LItem.FloatValues, LList.Count);
        for LI := 0 to LList.Count - 1 do
          LItem.FloatValues[LI] := LList[LI].AsFloat();
      end
      else
      begin
        SetLength(LItem.IntValues, LList.Count);
        for LI := 0 to LList.Count - 1 do
          LItem.IntValues[LI] := LList[LI].AsInt();
      end;
      AVM.FCurrentMirModule.AddDataItem(LItem);
      Result := TLVMValue.Nil_();
    end);

  // mirBss(name: string, size: int)
  RegisterBuiltin('mirBss',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LItem: TLVMMirDataItem;
    begin
      if Length(AArgs) < 2 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['mirBss', '(name, size)']);
        Exit(TLVMValue.Nil_());
      end;
      if AVM.FCurrentMirModule = nil then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirBss', 'no module in progress']);
        Exit(TLVMValue.Nil_());
      end;
      LItem := Default(TLVMMirDataItem);
      LItem.DataKind := mdkBss;
      LItem.ItemName := AArgs[0].AsString();
      LItem.BssSize := AArgs[1].AsInt();
      AVM.FCurrentMirModule.AddDataItem(LItem);
      Result := TLVMValue.Nil_();
    end);

  // mirRef(name: string, target: string, disp: int)
  RegisterBuiltin('mirRef',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LItem: TLVMMirDataItem;
    begin
      if Length(AArgs) < 3 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['mirRef', '(name, target, disp)']);
        Exit(TLVMValue.Nil_());
      end;
      if AVM.FCurrentMirModule = nil then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirRef', 'no module in progress']);
        Exit(TLVMValue.Nil_());
      end;
      LItem := Default(TLVMMirDataItem);
      LItem.DataKind := mdkRef;
      LItem.ItemName := AArgs[0].AsString();
      LItem.RefTarget := AArgs[1].AsString();
      LItem.RefDisp := AArgs[2].AsInt();
      AVM.FCurrentMirModule.AddDataItem(LItem);
      Result := TLVMValue.Nil_();
    end);

  // mirExpr(name: string, funcName: string)
  RegisterBuiltin('mirExpr',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LItem: TLVMMirDataItem;
    begin
      if Length(AArgs) < 2 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['mirExpr', '(name, funcName)']);
        Exit(TLVMValue.Nil_());
      end;
      if AVM.FCurrentMirModule = nil then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirExpr', 'no module in progress']);
        Exit(TLVMValue.Nil_());
      end;
      LItem := Default(TLVMMirDataItem);
      LItem.DataKind := mdkExpr;
      LItem.ItemName := AArgs[0].AsString();
      LItem.ExprFunc := AArgs[1].AsString();
      AVM.FCurrentMirModule.AddDataItem(LItem);
      Result := TLVMValue.Nil_();
    end);

  // mirLref(name: string, label1: string, label2: string, disp: int)
  RegisterBuiltin('mirLref',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LItem: TLVMMirDataItem;
    begin
      if Length(AArgs) < 4 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['mirLref', '(name, label1, label2, disp)']);
        Exit(TLVMValue.Nil_());
      end;
      if AVM.FCurrentMirModule = nil then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirLref', 'no module in progress']);
        Exit(TLVMValue.Nil_());
      end;
      LItem := Default(TLVMMirDataItem);
      LItem.DataKind := mdkLref;
      LItem.ItemName := AArgs[0].AsString();
      LItem.LrefLabel1 := AArgs[1].AsString();
      LItem.LrefLabel2 := AArgs[2].AsString();
      LItem.LrefDisp := AArgs[3].AsInt();
      AVM.FCurrentMirModule.AddDataItem(LItem);
      Result := TLVMValue.Nil_();
    end);

  // mirBeginFunc(name: string, resultTypes: list<string>, params: list<string>)
  RegisterBuiltin('mirBeginFunc',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LFunc: TLVMMirFunc;
      LList: TLVMListStore;
      LI: Integer;
      LT: TLVMMirType;
      LStr: string;
      LLocal: TLVMMirLocal;
      LParams: TArray<TLVMMirLocal>;
      LResultTypes: TArray<TLVMMirType>;
    begin
      if Length(AArgs) < 3 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['mirBeginFunc', '(name, resultTypes, params)']);
        Exit(TLVMValue.Nil_());
      end;
      if AVM.FCurrentMirModule = nil then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirBeginFunc', 'no module in progress']);
        Exit(TLVMValue.Nil_());
      end;
      if AVM.FCurrentMirFunc <> nil then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirBeginFunc', 'nested functions not allowed']);
        Exit(TLVMValue.Nil_());
      end;
      LFunc := TLVMMirFunc.Create();
      LFunc.FuncName := AArgs[0].AsString();
      // Result types
      LList := AArgs[1].AsList();
      SetLength(LResultTypes, LList.Count);
      for LI := 0 to LList.Count - 1 do
      begin
        if not MirStrToType(LList[LI].AsString(), LT) then
        begin
          AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirBeginFunc', LList[LI].AsString()]);
          LFunc.Free();
          Exit(TLVMValue.Nil_());
        end;
        LResultTypes[LI] := LT;
      end;
      LFunc.ResultTypes := LResultTypes;
      // Params (format: "type:name" or "...")
      LList := AArgs[2].AsList();
      SetLength(LParams, LList.Count);
      for LI := 0 to LList.Count - 1 do
      begin
        LStr := LList[LI].AsString();
        if LStr = '...' then
        begin
          LFunc.IsVararg := True;
          SetLength(LParams, LI);
          Break;
        end;
        LLocal := Default(TLVMMirLocal);
        if Pos(':', LStr) > 0 then
        begin
          if not MirStrToType(Copy(LStr, 1, Pos(':', LStr) - 1), LT) then
          begin
            AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirBeginFunc', LStr]);
            LFunc.Free();
            Exit(TLVMValue.Nil_());
          end;
          LLocal.LocalType := LT;
          LLocal.LocalName := Copy(LStr, Pos(':', LStr) + 1, MaxInt);
        end
        else
        begin
          if not MirStrToType(LStr, LT) then
          begin
            AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirBeginFunc', LStr]);
            LFunc.Free();
            Exit(TLVMValue.Nil_());
          end;
          LLocal.LocalType := LT;
          LLocal.LocalName := '';
        end;
        LParams[LI] := LLocal;
      end;
      LFunc.Params := LParams;
      AVM.FCurrentMirFunc := LFunc;
      Result := TLVMValue.Nil_();
    end);

  // mirEndFunc()
  RegisterBuiltin('mirEndFunc',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if AVM.FCurrentMirFunc = nil then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirEndFunc', 'no function in progress']);
        Exit(TLVMValue.Nil_());
      end;
      AVM.FCurrentMirModule.AddFunc(AVM.FCurrentMirFunc);
      AVM.FCurrentMirFunc := nil;
      Result := TLVMValue.Nil_();
    end);

  // mirLabel(name: string)
  RegisterBuiltin('mirLabel',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LInsn: TLVMMirInsn;
    begin
      if Length(AArgs) < 1 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['mirLabel', 'a name argument']);
        Exit(TLVMValue.Nil_());
      end;
      if AVM.FCurrentMirFunc = nil then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirLabel', 'no function in progress']);
        Exit(TLVMValue.Nil_());
      end;
      LInsn := Default(TLVMMirInsn);
      LInsn.LabelDef := AArgs[0].AsString();
      LInsn.IsLabelOnly := True;
      AVM.FCurrentMirFunc.AddInsn(LInsn);
      Result := TLVMValue.Nil_();
    end);

  // mirInsn(opcode: string, operands...: variadic)
  RegisterBuiltin('mirInsn',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LInsn: TLVMMirInsn;
      LOp: TLVMMirOpcode;
      LI: Integer;
      LOperand: TLVMMirOperand;
    begin
      if Length(AArgs) < 1 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['mirInsn', 'at least an opcode']);
        Exit(TLVMValue.Nil_());
      end;
      if AVM.FCurrentMirFunc = nil then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirInsn', 'no function in progress']);
        Exit(TLVMValue.Nil_());
      end;
      if not MirStrToOpcode(AArgs[0].AsString(), LOp) then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirInsn', AArgs[0].AsString()]);
        Exit(TLVMValue.Nil_());
      end;
      LInsn := Default(TLVMMirInsn);
      LInsn.Opcode := LOp;
      SetLength(LInsn.Operands, Length(AArgs) - 1);
      for LI := 1 to Length(AArgs) - 1 do
      begin
        LOperand := Default(TLVMMirOperand);
        case AArgs[LI].Kind of
          vkInt:
          begin
            LOperand.Kind := mokImmediateInt;
            LOperand.IntValue := AArgs[LI].AsInt();
          end;
          vkFloat:
          begin
            LOperand.Kind := mokImmediateFloat;
            LOperand.FloatValue := AArgs[LI].AsFloat();
          end;
        else
          // String -> reference (symbol name)
          LOperand.Kind := mokReference;
          LOperand.RefName := AArgs[LI].AsString();
        end;
        LInsn.Operands[LI - 1] := LOperand;
      end;
      AVM.FCurrentMirFunc.AddInsn(LInsn);
      Result := TLVMValue.Nil_();
    end);

  // mirCallBegin() -- push new arg accumulator for streaming call construction
  RegisterBuiltin('mirCallBegin',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if AVM.FCurrentMirFunc = nil then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirCallBegin', 'no function in progress']);
        Exit(TLVMValue.Nil_());
      end;
      AVM.FMirCallArgStack.Push(TList<TLVMMirOperand>.Create());
      Result := TLVMValue.Nil_();
    end);

  // mirCallArg(val) -- add operand to current call accumulator
  RegisterBuiltin('mirCallArg',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LOperand: TLVMMirOperand;
      LArgList: TList<TLVMMirOperand>;
    begin
      if Length(AArgs) < 1 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['mirCallArg', 'a value argument']);
        Exit(TLVMValue.Nil_());
      end;
      if AVM.FMirCallArgStack.Count = 0 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirCallArg', 'no mirCallBegin in progress']);
        Exit(TLVMValue.Nil_());
      end;
      LOperand := Default(TLVMMirOperand);
      case AArgs[0].Kind of
        vkInt:
        begin
          LOperand.Kind := mokImmediateInt;
          LOperand.IntValue := AArgs[0].AsInt();
        end;
        vkFloat:
        begin
          LOperand.Kind := mokImmediateFloat;
          LOperand.FloatValue := AArgs[0].AsFloat();
        end;
      else
        LOperand.Kind := mokReference;
        LOperand.RefName := AArgs[0].AsString();
      end;
      LArgList := AVM.FMirCallArgStack.Peek();
      LArgList.Add(LOperand);
      Result := TLVMValue.Nil_();
    end);

  // mirCallVoid(funcName) -- pop accumulator, emit call insn with all args
  RegisterBuiltin('mirCallVoid',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LInsn: TLVMMirInsn;
      LArgList: TList<TLVMMirOperand>;
      LFuncOp: TLVMMirOperand;
      LI: Integer;
    begin
      if Length(AArgs) < 1 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['mirCallVoid', 'a function name']);
        Exit(TLVMValue.Nil_());
      end;
      if AVM.FCurrentMirFunc = nil then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirCallVoid', 'no function in progress']);
        Exit(TLVMValue.Nil_());
      end;
      if AVM.FMirCallArgStack.Count = 0 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirCallVoid', 'no mirCallBegin in progress']);
        Exit(TLVMValue.Nil_());
      end;
      LArgList := AVM.FMirCallArgStack.Pop();
      LInsn := Default(TLVMMirInsn);
      LInsn.Opcode := mopCall;
      // Operands layout matches mirInsn("call",...): [proto, func, result, args...]
      // proto = "p_" + funcName, func = funcName, result = unused placeholder
      SetLength(LInsn.Operands, 3 + LArgList.Count);
      LFuncOp := Default(TLVMMirOperand);
      LFuncOp.Kind := mokReference;
      LFuncOp.RefName := 'p_' + AArgs[0].AsString();
      LInsn.Operands[0] := LFuncOp;
      LFuncOp.RefName := AArgs[0].AsString();
      LInsn.Operands[1] := LFuncOp;
      LFuncOp.RefName := '';
      LInsn.Operands[2] := LFuncOp;
      for LI := 0 to LArgList.Count - 1 do
        LInsn.Operands[3 + LI] := LArgList[LI];
      AVM.FCurrentMirFunc.AddInsn(LInsn);
      LArgList.Free();
      Result := TLVMValue.Nil_();
    end);

  // mirLoad(dest: string, base: string, displacement: int) -- load [base+disp] into dest
  RegisterBuiltin('mirLoad',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LInsn: TLVMMirInsn;
    begin
      if Length(AArgs) < 3 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['mirLoad', 'dest, base, displacement']);
        Exit(TLVMValue.Nil_());
      end;
      if AVM.FCurrentMirFunc = nil then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirLoad', 'no function in progress']);
        Exit(TLVMValue.Nil_());
      end;
      // Emit mopLoad with 3 flat operands: [dst, base, displacement]
      // Matches on-handler: "load" => operands[0]=dst, [1]=ptr, [2]=offset
      LInsn := Default(TLVMMirInsn);
      LInsn.Opcode := mopLoad;
      SetLength(LInsn.Operands, 3);
      LInsn.Operands[0].Kind := mokReference;
      LInsn.Operands[0].RefName := AArgs[0].AsString();
      LInsn.Operands[1].Kind := mokReference;
      LInsn.Operands[1].RefName := AArgs[1].AsString();
      LInsn.Operands[2].Kind := mokImmediateInt;
      LInsn.Operands[2].IntValue := AArgs[2].AsInt();
      AVM.FCurrentMirFunc.AddInsn(LInsn);
      Result := TLVMValue.Nil_();
    end);

  // mirStore(base: string, displacement: int, src: string|int) -- store src into [base+disp]
  RegisterBuiltin('mirStore',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LInsn: TLVMMirInsn;
    begin
      if Length(AArgs) < 3 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['mirStore', 'base, displacement, src']);
        Exit(TLVMValue.Nil_());
      end;
      if AVM.FCurrentMirFunc = nil then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinFailed, ['mirStore', 'no function in progress']);
        Exit(TLVMValue.Nil_());
      end;
      // Emit mopStore with 3 flat operands: [base, displacement, val]
      // Matches on-handler: "store" => operands[0]=ptr, [1]=offset, [2]=val
      LInsn := Default(TLVMMirInsn);
      LInsn.Opcode := mopStore;
      SetLength(LInsn.Operands, 3);
      LInsn.Operands[0].Kind := mokReference;
      LInsn.Operands[0].RefName := AArgs[0].AsString();
      LInsn.Operands[1].Kind := mokImmediateInt;
      LInsn.Operands[1].IntValue := AArgs[1].AsInt();
      if AArgs[2].Kind = vkInt then
      begin
        LInsn.Operands[2].Kind := mokImmediateInt;
        LInsn.Operands[2].IntValue := AArgs[2].AsInt();
      end
      else
      begin
        LInsn.Operands[2].Kind := mokReference;
        LInsn.Operands[2].RefName := AArgs[2].AsString();
      end;
      AVM.FCurrentMirFunc.AddInsn(LInsn);
      Result := TLVMValue.Nil_();
    end);

  // hasErrors() -- returns true if any diagnostic errors have been recorded
  RegisterBuiltin('hasErrors',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Assigned(AVM.GetErrors()) then
        Result := TLVMValue.FromBool(AVM.GetErrors().HasErrors())
      else
        Result := TLVMValue.FromBool(False);
    end);

  //--------------------------------------------------------------------------
  // Zig Build builtins (zb prefix)
  //--------------------------------------------------------------------------

  // zbSetOutputPath(path)
  RegisterBuiltin('zbSetOutputPath',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['zbSetOutputPath', 'a path']);
        Result := TLVMValue.Nil_();
        Exit;
      end;
      AVM.FZigBuild.SetOutputPath(AArgs[0].AsString());
      Result := TLVMValue.Nil_();
    end);

  // zbSetProjectName(name)
  RegisterBuiltin('zbSetProjectName',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['zbSetProjectName', 'a name']);
        Result := TLVMValue.Nil_();
        Exit;
      end;
      AVM.FZigBuild.SetProjectName(AArgs[0].AsString());
      Result := TLVMValue.Nil_();
    end);

  // zbSetTarget(triple)
  RegisterBuiltin('zbSetTarget',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['zbSetTarget', 'a target triple']);
        Result := TLVMValue.Nil_();
        Exit;
      end;
      AVM.FZigBuild.SetTarget(AArgs[0].AsString());
      Result := TLVMValue.Nil_();
    end);

  // zbSetBuildMode(mode) -- "exe", "lib", "dll"
  RegisterBuiltin('zbSetBuildMode',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LMode: string;
    begin
      if Length(AArgs) < 1 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['zbSetBuildMode', 'a mode string']);
        Result := TLVMValue.Nil_();
        Exit;
      end;
      LMode := AArgs[0].AsString().ToLower();
      if LMode = 'exe' then
        AVM.FZigBuild.SetBuildMode(bmExe)
      else if LMode = 'lib' then
        AVM.FZigBuild.SetBuildMode(bmLib)
      else if LMode = 'dll' then
        AVM.FZigBuild.SetBuildMode(bmDll)
      else
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, 'zbSetBuildMode: unknown mode "%s" (use exe/lib/dll)', [LMode]);
      Result := TLVMValue.Nil_();
    end);

  // zbSetOptimizeLevel(level) -- "debug", "release_safe", "release_fast", "release_small"
  RegisterBuiltin('zbSetOptimizeLevel',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LLevel: string;
    begin
      if Length(AArgs) < 1 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['zbSetOptimizeLevel', 'a level string']);
        Result := TLVMValue.Nil_();
        Exit;
      end;
      LLevel := AArgs[0].AsString().ToLower();
      if LLevel = 'debug' then
        AVM.FZigBuild.SetOptimizeLevel(olDebug)
      else if LLevel = 'release_safe' then
        AVM.FZigBuild.SetOptimizeLevel(olReleaseSafe)
      else if LLevel = 'release_fast' then
        AVM.FZigBuild.SetOptimizeLevel(olReleaseFast)
      else if LLevel = 'release_small' then
        AVM.FZigBuild.SetOptimizeLevel(olReleaseSmall)
      else
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, 'zbSetOptimizeLevel: unknown level "%s"', [LLevel]);
      Result := TLVMValue.Nil_();
    end);

  // zbSetSubsystem(subsystem) -- "console", "gui"
  RegisterBuiltin('zbSetSubsystem',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LSub: string;
    begin
      if Length(AArgs) < 1 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['zbSetSubsystem', 'a subsystem string']);
        Result := TLVMValue.Nil_();
        Exit;
      end;
      LSub := AArgs[0].AsString().ToLower();
      if LSub = 'console' then
        AVM.FZigBuild.SetSubsystem(stConsole)
      else if LSub = 'gui' then
        AVM.FZigBuild.SetSubsystem(stGUI)
      else
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, 'zbSetSubsystem: unknown subsystem "%s"', [LSub]);
      Result := TLVMValue.Nil_();
    end);

  // zbAddSourceFile(path)
  RegisterBuiltin('zbAddSourceFile',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['zbAddSourceFile', 'a file path']);
        Result := TLVMValue.Nil_();
        Exit;
      end;
      AVM.FZigBuild.AddSourceFile(AArgs[0].AsString());
      Result := TLVMValue.Nil_();
    end);

  // zbAddIncludePath(path)
  RegisterBuiltin('zbAddIncludePath',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['zbAddIncludePath', 'a path']);
        Result := TLVMValue.Nil_();
        Exit;
      end;
      AVM.FZigBuild.AddIncludePath(AArgs[0].AsString());
      Result := TLVMValue.Nil_();
    end);

  // zbAddLibraryPath(path)
  RegisterBuiltin('zbAddLibraryPath',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['zbAddLibraryPath', 'a path']);
        Result := TLVMValue.Nil_();
        Exit;
      end;
      AVM.FZigBuild.AddLibraryPath(AArgs[0].AsString());
      Result := TLVMValue.Nil_();
    end);

  // zbAddLinkLibrary(name)
  RegisterBuiltin('zbAddLinkLibrary',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['zbAddLinkLibrary', 'a library name']);
        Result := TLVMValue.Nil_();
        Exit;
      end;
      AVM.FZigBuild.AddLinkLibrary(AArgs[0].AsString());
      Result := TLVMValue.Nil_();
    end);

  // zbSetDefine(name) or zbSetDefine(name, value)
  RegisterBuiltin('zbSetDefine',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['zbSetDefine', 'a define name']);
        Result := TLVMValue.Nil_();
        Exit;
      end;
      if Length(AArgs) >= 2 then
        AVM.FZigBuild.SetDefine(AArgs[0].AsString(), AArgs[1].AsString())
      else
        AVM.FZigBuild.SetDefine(AArgs[0].AsString());
      Result := TLVMValue.Nil_();
    end);

  // zbProcess(autorun) -> bool
  RegisterBuiltin('zbProcess',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    var
      LAutoRun: Boolean;
    begin
      LAutoRun := True;
      if (Length(AArgs) >= 1) and (AArgs[0].Kind = vkBool) then
        LAutoRun := AArgs[0].AsBool();
      Result := TLVMValue.FromBool(AVM.FZigBuild.Process(LAutoRun));
    end);

  // zbRun() -> bool
  RegisterBuiltin('zbRun',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      Result := TLVMValue.FromBool(AVM.FZigBuild.Run());
    end);

  // zbClear()
  RegisterBuiltin('zbClear',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      AVM.FZigBuild.Clear();
      Result := TLVMValue.Nil_();
    end);

  // zbGetLastExitCode() -> int
  RegisterBuiltin('zbGetLastExitCode',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      Result := TLVMValue.FromInt(AVM.FZigBuild.GetLastExitCode());
    end);

  // zbSetToolchainPath(path)
  RegisterBuiltin('zbSetToolchainPath',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
      begin
        AVM.GetErrors().Add(esError, ERR_LVM_BUILTIN, RSLVMBuiltinArgs, ['zbSetToolchainPath', 'a path']);
        Result := TLVMValue.Nil_();
        Exit;
      end;
      AVM.FZigBuild.SetToolchainPath(AArgs[0].AsString());
      Result := TLVMValue.Nil_();
    end);

  // zbSetRunArguments(args)
  RegisterBuiltin('zbSetRunArguments',
    function(const AArgs: TArray<TLVMValue>; const AVM: TLangVM): TLVMValue
    begin
      if Length(AArgs) < 1 then
        AVM.FZigBuild.SetRunArguments('')
      else
        AVM.FZigBuild.SetRunArguments(AArgs[0].AsString());
      Result := TLVMValue.Nil_();
    end);

end;

procedure TLangVM.WalkSource(const ARoot: TLVMASTNode);
var
  LI: Integer;
  LChild: TLVMASTNode;
  LKind: string;
begin
  if ARoot = nil then
    Exit;

  // Handle language_decl if present
  for LI := 0 to ARoot.ChildCount() - 1 do
  begin
    LChild := TLVMASTNode(ARoot.Children[LI]);
    LKind := LChild.Kind;

    if LKind = 'language_decl' then
    begin
      FLanguageName := LChild.GetAttr('name');
      FLanguageVersion := LChild.GetAttr('version');
    end
    else if LKind = 'tokens_block' then
      WalkTokensBlock(LChild)
    else if LKind = 'types_block' then
      WalkTypesBlock(LChild)
    else if LKind = 'grammar_block' then
      WalkGrammarBlock(LChild)
    else if LKind = 'semantics_block' then
      WalkSemanticsBlock(LChild)
    else if LKind = 'emitters_block' then
      WalkEmittersBlock(LChild)
    else if LKind = 'mir_block' then
      WalkMirBlock(LChild)
    else if LKind = 'target_block' then
      WalkTargetBlock(LChild)
    else if LKind = 'const_block' then
      WalkConstBlock(LChild)
    else if LKind = 'enum_decl' then
      WalkEnumDecl(LChild)
    else if LKind = 'routine_decl' then
      WalkRoutineDecl(LChild)
    else if LKind = 'fragment_decl' then
      WalkFragmentDecl(LChild)
    else if LKind = 'import_stmt' then
      WalkImport(LChild)
    else if LKind = 'include_stmt' then
      WalkInclude(LChild)
    else if LKind = 'guard_block' then
      WalkGuardBlock(LChild)
    else if LKind = 'record_decl' then
      WalkRecordDecl(LChild)
    else if LKind = 'let_stmt' then
      ExecStmt(LChild)
    else if LKind = 'expr_stmt' then
      EvalExpr(TLVMASTNode(LChild.Children[0]))
    else
    begin
      GetErrors().RaiseOnError := True;
      GetErrors().Add(LChild.Filename, LChild.Line, LChild.Col, esError,
        ERR_LVM_TOPLEVEL, 'Unknown top-level construct ''%s''', [LKind]);
    end;
  end;
end;

procedure TLangVM.WalkTokensBlock(const ANode: TLVMASTNode);
var
  LI: Integer;
  LChild: TLVMASTNode;
  LKind: string;
  LTokenKind: string;
  LText: string;
  LFlags: string;
  LEntry: TLVMOperatorEntry;
  LStyle: TLVMStringStyleEntry;
  LJ: Integer;
  LFlag: TLVMASTNode;
begin
  for LI := 0 to ANode.ChildCount() - 1 do
  begin
    LChild := TLVMASTNode(ANode.Children[LI]);
    LKind := LChild.Kind;

    if LKind = 'token_decl' then
    begin
      // Build full kind: category.name (e.g. keyword.if, op.plus)
      LTokenKind := LChild.GetAttr('category') + '.' + LChild.GetAttr('name');
      LText := LChild.GetAttr('pattern');

      // Collect flags from child nodes
      LFlags := '';
      for LJ := 0 to LChild.ChildCount() - 1 do
      begin
        LFlag := TLVMASTNode(LChild.Children[LJ]);
        if LFlag.Kind = 'token_flag' then
        begin
          if LFlags <> '' then
            LFlags := LFlags + ',';
          LFlags := LFlags + LFlag.GetAttr('flag');
        end;
      end;

      // Route by kind prefix
      // Build reverse map: internal kind -> display text
      FTokenKindToText.AddOrSetValue(LTokenKind, LText);

      if LTokenKind.StartsWith('keyword.') then
      begin
        FTokenKeywords.AddOrSetValue(LText, LTokenKind);
        // Check for raw_block_end flag: maps start kind -> end keyword text
        for LJ := 0 to LChild.ChildCount() - 1 do
        begin
          LFlag := TLVMASTNode(LChild.Children[LJ]);
          if (LFlag.Kind = 'token_flag') and (LFlag.GetAttr('flag') = 'raw_block_end') then
            FRawBlockEnds.AddOrSetValue(LTokenKind, LFlag.GetAttr('arg'));
        end;
      end
      else if LTokenKind.StartsWith('op.') or LTokenKind.StartsWith('delimiter.') then
      begin
        LEntry.Text := LText;
        LEntry.Kind := LTokenKind;
        FTokenOperators.Add(LEntry);
      end
      else if LTokenKind.StartsWith('comment.line') then
        FTokenLineComments.Add(LText)
      else if LTokenKind.StartsWith('comment.block_open') then
        FTokenBlockComments.Add(TPair<string, string>.Create(LText, ''))
      else if LTokenKind.StartsWith('comment.block_close') then
      begin
        // Pair with last block_open
        if FTokenBlockComments.Count > 0 then
          FTokenBlockComments[FTokenBlockComments.Count - 1] :=
            TPair<string, string>.Create(
              FTokenBlockComments[FTokenBlockComments.Count - 1].Key, LText);
      end
      else if LTokenKind.StartsWith('string.') then
      begin
        LStyle.OpenText := LText;
        LStyle.Kind := LTokenKind;
        LStyle.Flags := LFlags;
        // Close delimiter: check for explicit 'close' flag with arg
        LStyle.CloseText := '';
        for LJ := 0 to LChild.ChildCount() - 1 do
        begin
          LFlag := TLVMASTNode(LChild.Children[LJ]);
          if (LFlag.Kind = 'token_flag') and (LFlag.GetAttr('flag') = 'close') then
            LStyle.CloseText := LFlag.GetAttr('arg');
        end;
        // Default close to last char of open text
        if (LStyle.CloseText = '') and (Length(LText) > 0) then
          LStyle.CloseText := LText[Length(LText)];
        FTokenStringStyles.Add(LStyle);
      end
      else if LTokenKind.StartsWith('directive.') then
      begin
        FTokenDirectives.AddOrSetValue(LText, LTokenKind);
        if LFlags <> '' then
          FTokenDirectiveFlags.AddOrSetValue(LText, LFlags);
      end;
    end
    else if LKind = 'token_config' then
    begin
      // Store lexer config entries directly
      if LChild.GetAttr('key') = 'casesensitive' then
        FLexerConfig.CaseSensitive := LChild.GetAttr('value') = 'true'
      else if LChild.GetAttr('key') = 'terminator' then
        FLexerConfig.Terminator := LChild.GetAttr('value')
      else if LChild.GetAttr('key') = 'block_open' then
        FLexerConfig.BlockOpen := LChild.GetAttr('value')
      else if LChild.GetAttr('key') = 'block_close' then
        FLexerConfig.BlockClose := LChild.GetAttr('value')
      else if LChild.GetAttr('key') = 'directive_prefix' then
        FLexerConfig.DirectivePrefix := LChild.GetAttr('value')
      else if LChild.GetAttr('key') = 'hex_prefix' then
        FLexerConfig.HexPrefix.Add(LChild.GetAttr('value'));
    end;
  end;

  // Sort operators longest-first for correct matching
  FTokenOperators.Sort(TComparer<TLVMOperatorEntry>.Construct(
    function(const ALeft, ARight: TLVMOperatorEntry): Integer
    begin
      Result := Length(ARight.Text) - Length(ALeft.Text);
    end));
end;

procedure TLangVM.WalkTypesBlock(const ANode: TLVMASTNode);
var
  LI: Integer;
  LChild: TLVMASTNode;
  LKind: string;
  LEntry: TLVMCompatEntry;
begin
  for LI := 0 to ANode.ChildCount() - 1 do
  begin
    LChild := TLVMASTNode(ANode.Children[LI]);
    LKind := LChild.Kind;

    if LKind = 'type_keyword_decl' then
      FTypeKeywords.AddOrSetValue(LChild.GetAttr('name'), LChild.GetAttr('value'))
    else if LKind = 'type_map' then
      FTypeMappings.AddOrSetValue(LChild.GetAttr('from'), LChild.GetAttr('to'))
    else if LKind = 'type_literal' then
      FLiteralTypes.AddOrSetValue(LChild.GetAttr('pattern'), LChild.GetAttr('type'))
    else if LKind = 'type_compatible' then
    begin
      LEntry.FromType := LChild.GetAttr('from');
      LEntry.ToType := LChild.GetAttr('to');
      LEntry.CoerceExpr := LChild.GetAttr('via');
      FCompatRules.Add(LEntry);
    end
    else if LKind = 'type_decl_kind' then
      FDeclKinds.Add(LChild.GetAttr('value'))
    else if LKind = 'type_call_kind' then
      FCallKinds.Add(LChild.GetAttr('value'))
    else if LKind = 'type_call_name_attr' then
      FCallNameAttr := LChild.GetAttr('value');
  end;
end;

procedure TLangVM.WalkGrammarBlock(const ANode: TLVMASTNode);
var
  LI: Integer;
  LChild: TLVMASTNode;
  LKey: string;
  LNodeKind: string;
  LTrigger: string;
  LTriggers: TArray<string>;
  LTriggerItem: string;
  LInfix: TLVMInfixEntry;
  LRuleList: TList<TLVMASTNode>;
  LFragAST: TLVMASTNode;
begin
  for LI := 0 to ANode.ChildCount() - 1 do
  begin
    LChild := TLVMASTNode(ANode.Children[LI]);

    // Handle included fragments
    if LChild.Kind = 'meta.include' then
    begin
      if FFragments.TryGetValue(LChild.GetAttr('path'), LFragAST) then
        if LFragAST.ChildCount() > 0 then
          WalkGrammarBlock(TLVMASTNode(LFragAST.Children[0]));
      Continue;
    end;

    if LChild.Kind <> 'rule_decl' then
      Continue;

    // Store in FGrammarRules keyed by category.name (existing behavior)
    LKey := LChild.GetAttr('category') + '.' + LChild.GetAttr('name');
    FGrammarRules.AddOrSetValue(LKey, LChild);

    // Compute node_kind from category.name if not already set
    if not LChild.HasAttr('node_kind') then
      LChild.SetAttr('node_kind', LKey);

    // Classify into prefix/infix/stmt rule dictionaries
    LNodeKind := LChild.GetAttr('node_kind');
    LTrigger := FindTriggerToken(LChild);

    // Default to 'identifier' for stmt rules with no real trigger
    if (LTrigger = LNodeKind) and LNodeKind.StartsWith('stmt.') then
      LTrigger := 'identifier';

    if LChild.HasAttr('prec') then
    begin
      // Infix rule -- register for ALL trigger tokens
      LInfix.Power := StrToIntDef(LChild.GetAttr('prec'), 0);
      LInfix.Assoc := LChild.GetAttr('assoc');
      LInfix.RuleAST := LChild;
      LTriggers := FindAllTriggerTokens(LChild);
      for LTriggerItem in LTriggers do
        FInfixRules.AddOrSetValue(LTriggerItem, LInfix);
    end
    else if LNodeKind.StartsWith('stmt.') then
    begin
      // Stmt rule -- register for ALL trigger tokens (same as infix)
      LTriggers := FindAllTriggerTokens(LChild);
      if (Length(LTriggers) = 1) and (LTriggers[0] = LNodeKind) then
        LTriggers := TArray<string>.Create('identifier');
      for LTriggerItem in LTriggers do
      begin
        if not FStmtRules.TryGetValue(LTriggerItem, LRuleList) then
        begin
          LRuleList := TList<TLVMASTNode>.Create();
          FStmtRules.Add(LTriggerItem, LRuleList);
        end;
        LRuleList.Add(LChild);
      end;
    end
    else
      FPrefixRules.AddOrSetValue(LTrigger, LChild);
  end;
end;

function TLangVM.FindTriggerToken(const ARuleAST: TLVMASTNode): string;
var
  LI: Integer;
  LChild: TLVMASTNode;
  LKind: string;
  LKinds: string;
begin
  // Scan rule body for first expect or consume node to determine trigger token
  for LI := 0 to ARuleAST.ChildCount() - 1 do
  begin
    LChild := TLVMASTNode(ARuleAST.Children[LI]);
    LKind := LChild.Kind;

    if LKind = 'expect_stmt' then
      Exit(LChild.GetAttr('token_ref'));

    if LKind = 'consume_stmt' then
    begin
      LKinds := LChild.GetAttr('token_ref');
      if Pos(',', LKinds) > 0 then
        Exit(Copy(LKinds, 1, Pos(',', LKinds) - 1))
      else
        Exit(LKinds);
    end;
  end;

  // Fallback: use node_kind as trigger
  Result := ARuleAST.GetAttr('node_kind');
end;

function TLangVM.FindAllTriggerTokens(const ARuleAST: TLVMASTNode): TArray<string>;
var
  LI: Integer;
  LChild: TLVMASTNode;
  LKind: string;
  LKinds: string;
  LParts: TArray<string>;
  LJ: Integer;
begin
  for LI := 0 to ARuleAST.ChildCount() - 1 do
  begin
    LChild := TLVMASTNode(ARuleAST.Children[LI]);
    LKind := LChild.Kind;

    if LKind = 'expect_stmt' then
      Exit(TArray<string>.Create(LChild.GetAttr('token_ref')));

    if LKind = 'consume_stmt' then
    begin
      LKinds := LChild.GetAttr('token_ref');
      LParts := LKinds.Split([',']);
      for LJ := 0 to Length(LParts) - 1 do
        LParts[LJ] := Trim(LParts[LJ]);
      Exit(LParts);
    end;
  end;

  Result := TArray<string>.Create(ARuleAST.GetAttr('node_kind'));
end;

function TLangVM.ExecuteGrammarRule(const ARuleAST: TLVMASTNode;
  const ALeft: TLVMASTNode): TLVMASTNode;
var
  LNodeKind: string;
  LSavedResultNode: TLVMValue;
  LSavedSnapshot: Integer;
  LI: Integer;
begin
  LNodeKind := ARuleAST.GetAttr('node_kind');

  // Create the user AST node this rule will build
  Result := TLVMASTNode.Create();
  Result.Kind := LNodeKind;

  // Set source location from current parser token
  if Assigned(FActiveParser) and not TLVMGenericParser(FActiveParser).AtEnd() then
  begin
    Result.Filename := TLVMGenericParser(FActiveParser).Current().Filename;
    Result.Line := TLVMGenericParser(FActiveParser).Current().Line;
    Result.Col := TLVMGenericParser(FActiveParser).Current().Col;
  end;

  // Save and set context
  LSavedResultNode := FResultNode;
  LSavedSnapshot := FRuleErrorSnapshot;
  FResultNode := TLVMValue.FromHandle(Result);
  if Assigned(GetErrors()) then
    FRuleErrorSnapshot := GetErrors().ErrorCount()
  else
    FRuleErrorSnapshot := 0;

  // If this is an infix rule, the left operand is child 0
  if Assigned(ALeft) then
    Result.AddChild(ALeft);

  // Execute the rule body
  FEnvironment.PushScope();
  try
    try
      for LI := 0 to ARuleAST.ChildCount() - 1 do
      begin
        if Assigned(GetErrors()) and GetErrors().ReachedMaxErrors() then Break;
        ExecStmt(TLVMASTNode(ARuleAST.Children[LI]));
      end;
    except
      on E: EStdAppException do
        ; // error already recorded, return partial node
    end;
  finally
    FEnvironment.PopScope();
    FResultNode := LSavedResultNode;
    FRuleErrorSnapshot := LSavedSnapshot;
  end;
end;

function TLangVM.ParserCurrentToken(): TLVMUserToken;
begin
  if Assigned(FActiveParser) then
    Result := TLVMGenericParser(FActiveParser).Current()
  else
  begin
    Result.Kind := '';
    Result.Text := '';
    Result.Filename := '';
    Result.Line := 0;
    Result.Col := 0;
  end;
end;

procedure TLangVM.WalkSemanticsBlock(const ANode: TLVMASTNode);
var
  LI: Integer;
  LJ: Integer;
  LChild: TLVMASTNode;
  LHandler: TLVMASTNode;
  LPassNum: Integer;
  LPassDict: TLVMHandlerMap;
  LKey: string;
begin
  // Each child is a pass_block containing semantic_handler nodes
  for LI := 0 to ANode.ChildCount() - 1 do
  begin
    LChild := TLVMASTNode(ANode.Children[LI]);
    if LChild.Kind = 'pass_block' then
    begin
      LPassNum := StrToIntDef(LChild.GetAttr('number'), 0);
      if not FSemanticHandlers.TryGetValue(LPassNum, LPassDict) then
      begin
        LPassDict := TLVMHandlerMap.Create();
        FSemanticHandlers.Add(LPassNum, LPassDict);
      end;

      for LJ := 0 to LChild.ChildCount() - 1 do
      begin
        LHandler := TLVMASTNode(LChild.Children[LJ]);
        if LHandler.Kind = 'semantic_handler' then
        begin
          if LHandler.GetAttr('category') <> '' then
            LKey := LHandler.GetAttr('category') + '.' + LHandler.GetAttr('name')
          else
            LKey := LHandler.GetAttr('name');
          LPassDict.AddOrSetValue(LKey, LHandler);
        end;
      end;
    end
    else if LChild.Kind = 'semantic_handler' then
    begin
      // Bare on-handler (no pass wrapper) -- register into default pass 0
      if not FSemanticHandlers.TryGetValue(0, LPassDict) then
      begin
        LPassDict := TLVMHandlerMap.Create();
        FSemanticHandlers.Add(0, LPassDict);
      end;
      if LChild.GetAttr('category') <> '' then
        LKey := LChild.GetAttr('category') + '.' + LChild.GetAttr('name')
      else
        LKey := LChild.GetAttr('name');
      LPassDict.AddOrSetValue(LKey, LChild);
    end;
  end;
end;

procedure TLangVM.WalkEmittersBlock(const ANode: TLVMASTNode);
var
  LI: Integer;
  LChild: TLVMASTNode;
  LKey: string;
begin
  // Each child is an emitter_handler -- store keyed by category.name
  for LI := 0 to ANode.ChildCount() - 1 do
  begin
    LChild := TLVMASTNode(ANode.Children[LI]);
    if LChild.Kind = 'emitter_handler' then
    begin
      if LChild.GetAttr('category') <> '' then
        LKey := LChild.GetAttr('category') + '.' + LChild.GetAttr('name')
      else
        LKey := LChild.GetAttr('name');
      FEmitterHandlers.AddOrSetValue(LKey, LChild);
    end;
  end;
end;

{ TLVM.WalkMirBlock }
procedure TLangVM.WalkMirBlock(const ANode: TLVMASTNode);
var
  LI: Integer;
  LChild: TLVMASTNode;
  LKey: string;
begin
  // Register on-handlers from mir_block children
  for LI := 0 to ANode.ChildCount() - 1 do
  begin
    LChild := TLVMASTNode(ANode.Children[LI]);
    if LChild.Kind = 'mir_handler' then
    begin
      LKey := LChild.GetAttr('event');
      FMirHandlers.AddOrSetValue(LKey, LChild);
    end;
  end;

end;

{ TLVM.WalkTargetBlock }
procedure TLangVM.WalkTargetBlock(const ANode: TLVMASTNode);
var
  LI: Integer;
  LChild: TLVMASTNode;
  LHandlerName: string;
  LOpcode: TLVMMirOpcode;
  LContextAttr: string;
begin
  // Capture optional context identifier
  LContextAttr := ANode.GetAttr('context');
  if LContextAttr <> '' then
  begin
    FTargetContextName := LContextAttr;
    FTargetContext := FEnvironment.GetVar(LContextAttr);
  end;

  // Register handlers
  for LI := 0 to ANode.ChildCount() - 1 do
  begin
    LChild := TLVMASTNode(ANode.Children[LI]);
    if LChild.Kind <> 'target_handler' then
      Continue;

    LHandlerName := LChild.GetAttr('name');

    // Check if it's a structural event name -- route to FMirHandlers
    if (LHandlerName = 'module') or (LHandlerName = 'endmodule') or
       (LHandlerName = 'proto') or (LHandlerName = 'func') or
       (LHandlerName = 'endfunc') or (LHandlerName = 'label') or
       (LHandlerName = 'string') or (LHandlerName = 'bss') or
       (LHandlerName = 'ref') or (LHandlerName = 'data') or
       (LHandlerName = 'expr') or (LHandlerName = 'lref') then
    begin
      FMirHandlers.AddOrSetValue(LHandlerName, LChild);
    end
    else
    begin
      // Must be a MIR opcode
      if not MirStrToOpcode(LHandlerName, LOpcode) then
      begin
        FErrors.Add(esError, ERR_LVM_TARGET, 'Unknown MIR opcode "%s" in target block', [LHandlerName]);
        Continue;
      end;

      if FTargetHandlers.ContainsKey(LOpcode) then
      begin
        FErrors.Add(esError, ERR_LVM_TARGET, 'Duplicate target handler for opcode "%s"', [LHandlerName]);
        Continue;
      end;

      FTargetHandlers.Add(LOpcode, LChild);
    end;
  end;

  // No walk-time completeness check -- RunTargetHandler errors at runtime
  // if a needed opcode has no handler, which supports incremental development

  FHasTarget := True;
end;

procedure TLangVM.WalkConstBlock(const ANode: TLVMASTNode);
var
  LI: Integer;
  LChild: TLVMASTNode;
  LName: string;
  LVal: TLVMValue;
begin
  // Each child is a const_decl with name attr and one expression child
  for LI := 0 to ANode.ChildCount() - 1 do
  begin
    LChild := TLVMASTNode(ANode.Children[LI]);
    if LChild.Kind = 'const_decl' then
    begin
      LName := LChild.GetAttr('name');
      if LChild.ChildCount() > 0 then
        LVal := EvalExpr(TLVMASTNode(LChild.Children[0]))
      else
        LVal := TLVMValue.Nil_();
      if not FEnvironment.DeclareVar(LName, LVal) then
      begin
        GetErrors().Add(LChild.Filename, LChild.Line, LChild.Col, esError,
          ERR_LVM_REDECLARE, RSLVMVarRedeclared, [LName]);
        Exit;
      end;
    end;
  end;
end;

procedure TLangVM.WalkEnumDecl(const ANode: TLVMASTNode);
var
  LI: Integer;
  LCount: Integer;
  LMember: string;
  LEnumName: string;
  LValue: TLVMValue;
begin
  LEnumName := ANode.GetAttr('name');
  // Enum members stored as member_0..member_N attrs, member_count attr
  LCount := StrToIntDef(ANode.GetAttr('member_count'), 0);
  for LI := 0 to LCount - 1 do
  begin
    LMember := ANode.GetAttr('member_' + IntToStr(LI));
    if LMember <> '' then
    begin
      LValue := TLVMValue.FromString(LMember);
      LValue.TypeName := LEnumName;
      if not FEnvironment.DeclareVar(LMember, LValue, LEnumName) then
      begin
        GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
          ERR_LVM_REDECLARE, RSLVMVarRedeclared, [LMember]);
        Exit;
      end;
    end;
  end;
end;

procedure TLangVM.WalkRoutineDecl(const ANode: TLVMASTNode);
var
  LName: string;
begin
  // Store the routine AST node as a routine value in the environment
  LName := ANode.GetAttr('name');
  if not FEnvironment.DeclareVar(LName, TLVMValue.FromRoutine(ANode)) then
  begin
    GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
      ERR_LVM_REDECLARE, RSLVMVarRedeclared, [LName]);
  end;
end;

procedure TLangVM.WalkFragmentDecl(const ANode: TLVMASTNode);
var
  LName: string;
begin
  // Store fragment node for later include expansion
  LName := ANode.GetAttr('name');
  FFragments.AddOrSetValue(LName, ANode);
end;

procedure TLangVM.WalkImport(const ANode: TLVMASTNode);
var
  LRawPath: string;
  LPath: string;
  LSource: string;
  LTokens: TArray<TLVMToken>;
  LRoot: TLVMASTNode;
  LSavedBaseDir: string;
  LI: Integer;
begin
  LRawPath := ANode.GetAttr('path');
  if LRawPath = '' then
    Exit;

  // Force .lvm extension
  LRawPath := TPath.ChangeExtension(LRawPath, LVM_FILEEXT);

  // Try importing file's own directory first (FBaseDir)
  LPath := TUtils.ResolvePath(LRawPath, FBaseDir);

  // If not found, search import paths
  if not TFile.Exists(LPath) then
  begin
    for LI := 0 to FImportPaths.Count - 1 do
    begin
      LPath := TUtils.ResolvePath(LRawPath, FImportPaths[LI]);
      if TFile.Exists(LPath) then
        Break;
    end;
  end;

  // Cycle detection -- uses resolved absolute path so the same file
  // reached via different paths is recognized as already imported
  if FImported.ContainsKey(LPath) then
    Exit;
  FImported.Add(LPath, True);

  if not TFile.Exists(LPath) then
  begin
    GetErrors().Add(esError, ERR_LVM_IMPORT, RSLVMImportNotFound,
      [LRawPath], nil);
    Exit;
  end;

  LSource := TFile.ReadAllText(LPath);
  LTokens := FLexer.Tokenize(LSource, LPath);
  LRoot := FParser.Parse(LTokens, LPath);
  // Keep AST alive -- handlers reference nodes in this tree
  FParsedRoots.Add(LRoot);

  // Set FBaseDir to the imported file's directory so its own imports
  // resolve relative to itself, then restore after walking.
  // Enter global scope so imported declarations land at module level
  // regardless of where the import statement appears (e.g. inside an if block).
  LSavedBaseDir := FBaseDir;
  FBaseDir := TPath.GetDirectoryName(LPath);
  FEnvironment.EnterGlobalScope();
  try
    WalkSource(LRoot);
  finally
    FEnvironment.LeaveGlobalScope();
    FBaseDir := LSavedBaseDir;
  end;
end;

procedure TLangVM.WalkInclude(const ANode: TLVMASTNode);
var
  LName: string;
  LFragment: TLVMASTNode;
  LI: Integer;
  LChild: TLVMASTNode;
begin
  LName := ANode.GetAttr('name');
  if not FFragments.TryGetValue(LName, LFragment) then
  begin
    GetErrors().Add(esError, ERR_LVM_IMPORT, RSLVMFragmentNotFound,
      [LName], nil);
    Exit;
  end;

  // Walk the fragment's children as if they were top-level blocks
  for LI := 0 to LFragment.ChildCount() - 1 do
  begin
    LChild := TLVMASTNode(LFragment.Children[LI]);
    // Re-dispatch each child through WalkSource-style dispatch
    if LChild.Kind = 'tokens_block' then
      WalkTokensBlock(LChild)
    else if LChild.Kind = 'types_block' then
      WalkTypesBlock(LChild)
    else if LChild.Kind = 'grammar_block' then
      WalkGrammarBlock(LChild)
    else if LChild.Kind = 'semantics_block' then
      WalkSemanticsBlock(LChild)
    else if LChild.Kind = 'emitters_block' then
      WalkEmittersBlock(LChild)
    else if LChild.Kind = 'mir_block' then
      WalkMirBlock(LChild)
    else if LChild.Kind = 'const_block' then
      WalkConstBlock(LChild)
    else if LChild.Kind = 'enum_decl' then
      WalkEnumDecl(LChild)
    else if LChild.Kind = 'routine_decl' then
      WalkRoutineDecl(LChild)
    else if LChild.Kind = 'fragment_decl' then
      WalkFragmentDecl(LChild)
    else if LChild.Kind = 'import_stmt' then
      WalkImport(LChild)
    else if LChild.Kind = 'include_stmt' then
      WalkInclude(LChild)
    else if LChild.Kind = 'guard_block' then
      WalkGuardBlock(LChild)
    else if LChild.Kind = 'record_decl' then
      WalkRecordDecl(LChild)
    else if LChild.Kind = 'expr_stmt' then
      EvalExpr(TLVMASTNode(LChild.Children[0]));
  end;
end;

procedure TLangVM.WalkGuardBlock(const ANode: TLVMASTNode);
var
  LCond: TLVMValue;
  LI: Integer;
  LChild: TLVMASTNode;
begin
  // First child is the condition expression, rest are guarded blocks
  if ANode.ChildCount() < 2 then
    Exit;

  LCond := EvalExpr(TLVMASTNode(ANode.Children[0]));
  if not LCond.IsTrue() then
    Exit;

  // Walk remaining children as top-level blocks
  for LI := 1 to ANode.ChildCount() - 1 do
  begin
    LChild := TLVMASTNode(ANode.Children[LI]);
    if LChild.Kind = 'tokens_block' then
      WalkTokensBlock(LChild)
    else if LChild.Kind = 'types_block' then
      WalkTypesBlock(LChild)
    else if LChild.Kind = 'grammar_block' then
      WalkGrammarBlock(LChild)
    else if LChild.Kind = 'semantics_block' then
      WalkSemanticsBlock(LChild)
    else if LChild.Kind = 'emitters_block' then
      WalkEmittersBlock(LChild)
    else if LChild.Kind = 'mir_block' then
      WalkMirBlock(LChild)
    else if LChild.Kind = 'const_block' then
      WalkConstBlock(LChild)
    else if LChild.Kind = 'enum_decl' then
      WalkEnumDecl(LChild)
    else if LChild.Kind = 'routine_decl' then
      WalkRoutineDecl(LChild)
    else if LChild.Kind = 'fragment_decl' then
      WalkFragmentDecl(LChild)
    else if LChild.Kind = 'import_stmt' then
      WalkImport(LChild)
    else if LChild.Kind = 'include_stmt' then
      WalkInclude(LChild)
    else if LChild.Kind = 'guard_block' then
      WalkGuardBlock(LChild)
    else if LChild.Kind = 'record_decl' then
      WalkRecordDecl(LChild)
    else if LChild.Kind = 'expr_stmt' then
      EvalExpr(TLVMASTNode(LChild.Children[0]));
  end;
end;

procedure TLangVM.WalkRecordDecl(const ANode: TLVMASTNode);
var
  LI: Integer;
  LField: TLVMASTNode;
  LDef: TLVMRecordDef;
  LParentDef: TLVMRecordDef;
  LName: string;
  LParentName: string;
  LIsLayout: Boolean;
  LSizeType: string;
  LByteSize: Integer;
begin
  LName := ANode.GetAttr('name');
  LDef := TLVMRecordDef.Create(LName);

  // Inherit parent fields if extends clause is present
  LParentName := ANode.GetAttr('extends');
  if LParentName <> '' then
  begin
    if not FRecordDefs.TryGetValue(LParentName, LParentDef) then
    begin
      GetErrors().RaiseOnError := True;
      GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
        ERR_LVM_TYPE, 'Record ''%s'' extends unknown record ''%s''',
        [LName, LParentName]);
      LDef.Free();
      Exit;
    end;
    // Copy all parent fields into child (preserving order)
    for LI := 0 to LParentDef.FieldNames.Count - 1 do
      LDef.AddField(LParentDef.FieldNames[LI],
        LParentDef.FieldDefaults[LParentDef.FieldNames[LI]]);
  end;

  LIsLayout := ANode.GetAttr('layout') = 'true';
  for LI := 0 to ANode.ChildCount() - 1 do
  begin
    LField := TLVMASTNode(ANode.Children[LI]);
    if LIsLayout then
    begin
      LSizeType := LField.GetAttr('size_type');
      LByteSize := 0;
      if (LSizeType = 'u8') or (LSizeType = 'i8') then
        LByteSize := 1
      else if (LSizeType = 'u16') or (LSizeType = 'i16') then
        LByteSize := 2
      else if (LSizeType = 'u32') or (LSizeType = 'i32') then
        LByteSize := 4
      else if (LSizeType = 'u64') or (LSizeType = 'i64') then
        LByteSize := 8
      else
      begin
        GetErrors().RaiseOnError := True;
        GetErrors().Add(ANode.Filename, LField.Line, LField.Col, esError,
          ERR_LVM_LAYOUT, RSLVMUnknownLayoutType, [LSizeType]);
      end;
      LDef.AddLayoutField(LField.GetAttr('name'), LByteSize,
        EvalExpr(TLVMASTNode(LField.Children[0])));
    end
    else
      LDef.AddField(LField.GetAttr('name'), EvalExpr(TLVMASTNode(LField.Children[0])));
  end;
  FRecordDefs.AddOrSetValue(LName, LDef);
end;

procedure TLangVM.DoExecVisitStmt(const ANode: TLVMASTNode);
var
  LMode: string;
  LI: Integer;
  LChildCount: Integer;
  LChildNode: TLVMValue;
  LArgs: TArray<TLVMValue>;
  LIdxVal: TLVMValue;
begin
  // visit operates on FCurrentNode (the target AST handle)
  if FCurrentNode.Kind = vkNil then
  begin
    GetErrors().RaiseOnError := True;
    GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
      ERR_LVM_VISIT, RSLVMVisitNoNode);
  end;

  LMode := ANode.GetAttr('mode');

  if LMode = 'children' then
  begin
    // Visit all children of current node
    SetLength(LArgs, 1);
    LArgs[0] := FCurrentNode;
    LChildCount := CallBuiltin('childCount', LArgs).AsInt();
    for LI := 0 to LChildCount - 1 do
    begin
      SetLength(LArgs, 2);
      LArgs[0] := FCurrentNode;
      LArgs[1] := TLVMValue.FromInt(LI);
      LChildNode := CallBuiltin('getChild', LArgs);
      // Dispatch through whichever handler is active (semantic or emitter)
      if FActiveSemanticDict <> nil then
        RunSemanticHandler(LChildNode)
      else
        RunEmitHandler(LChildNode);
    end;
  end
  else if LMode = 'attr' then
  begin
    // Visit the named child attribute
    LChildNode := CallBuiltin('getAttr', [FCurrentNode,
      TLVMValue.FromString(ANode.GetAttr('attr'))]);
    if LChildNode.Kind <> vkNil then
    begin
      if FActiveSemanticDict <> nil then
        RunSemanticHandler(LChildNode)
      else
        RunEmitHandler(LChildNode);
    end;
  end
  else if LMode = 'child' then
  begin
    // Visit child at specific index -- index is an expression child of ANode
    LIdxVal := EvalExpr(TLVMASTNode(ANode.Children[0]));
    SetLength(LArgs, 2);
    LArgs[0] := FCurrentNode;
    LArgs[1] := LIdxVal;
    LChildNode := CallBuiltin('getChild', LArgs);
    if LChildNode.Kind <> vkNil then
    begin
      if FActiveSemanticDict <> nil then
        RunSemanticHandler(LChildNode)
      else
        RunEmitHandler(LChildNode);
    end;
  end
  else
  begin
    GetErrors().RaiseOnError := True;
    GetErrors().Add(ANode.Filename, ANode.Line, ANode.Col, esError,
      ERR_LVM_VISIT, RSLVMVisitUnknownMode, [LMode]);
  end;
end;

procedure TLangVM.RunSemanticHandler(const AUserNode: TLVMValue);
var
  LNodeKind: string;
  LHandler: TLVMASTNode;
  LSavedNode: TLVMValue;
  LI: Integer;
  LChildCount: Integer;
  LChildNode: TLVMValue;
  LArgs: TArray<TLVMValue>;
begin
  if AUserNode.Kind = vkNil then Exit;

  // Get node kind from the host via builtin
  SetLength(LArgs, 1);
  LArgs[0] := AUserNode;
  LNodeKind := CallBuiltin('getNodeKind', LArgs).AsString();

  // Look up handler in active semantic dict
  if (FActiveSemanticDict <> nil) and
     FActiveSemanticDict.TryGetValue(LNodeKind, LHandler) then
  begin
    LSavedNode := FCurrentNode;
    FCurrentNode := AUserNode;
    FEnvironment.PushScope();
    try
      FEnvironment.ForceSetVar('node', AUserNode);
      ExecBlock(LHandler);
    finally
      FEnvironment.PopScope();
      FCurrentNode := LSavedNode;
    end;
  end
  else
  begin
    // No handler: auto-visit all children (default traversal)
    SetLength(LArgs, 1);
    LArgs[0] := AUserNode;
    LChildCount := CallBuiltin('childCount', LArgs).AsInt();
    for LI := 0 to LChildCount - 1 do
    begin
      LArgs[0] := AUserNode;
      SetLength(LArgs, 2);
      LArgs[1] := TLVMValue.FromInt(LI);
      LChildNode := CallBuiltin('getChild', LArgs);
      RunSemanticHandler(LChildNode);
    end;
  end;
end;

procedure TLangVM.LoadScript(const ASource: string; const AFilename: string);
var
  LTokens: TArray<TLVMToken>;
  LRoot: TLVMASTNode;
begin
  try
    LTokens := FLexer.Tokenize(ASource, AFilename);
    if GetErrors().HasErrors() then Exit;

    LRoot := FParser.Parse(LTokens, AFilename);

    // Always track root -- parser-created nodes are children of this tree
    FParsedRoots.Add(LRoot);
    if GetErrors().HasErrors() then Exit;
    WalkSource(LRoot);
  except
    on E: EStdAppException do
      GetErrors().RaiseOnError := False;
    // Other exceptions (invariant violations) propagate
  end;
end;

procedure TLangVM.AddImportPath(const APath: string);
var
  LPath: string;
begin
  LPath := TUtils.ResolvePath(APath, FBaseDir);
  if FImportPaths.IndexOf(LPath) < 0 then
    FImportPaths.Add(LPath);
end;

procedure TLangVM.LoadScriptFile(const AFilename: string);
var
  LFilename: string;
  LSource: string;
begin
  // Force .lvm extension and resolve path prefixes ($p: etc.)
  LFilename := TUtils.ResolvePath(
    TPath.ChangeExtension(AFilename, LVM_FILEEXT), FBaseDir);

  if not TFile.Exists(LFilename) then
  begin
    GetErrors().Add(esError, ERR_LVM_IMPORT, RSLVMLangNotFound,
      [LFilename], nil);
    Exit;
  end;

  // Set base directory for import resolution
  FBaseDir := TPath.GetDirectoryName(LFilename);

  // Track this file to prevent re-import
  FImported.Add(LFilename, True);

  LSource := TFile.ReadAllText(LFilename, TEncoding.UTF8);
  LoadScript(LSource, LFilename);
end;

procedure TLangVM.SetActiveParser(const AParser: TObject);
begin
  FActiveParser := AParser;
end;

function TLangVM.GetActiveParser(): TObject;
begin
  Result := FActiveParser;
end;

procedure TLangVM.Reset();
var
  LStream: TFileStream;
begin
  // Close any open file handles
  for LStream in FFileHandles.Values do
    LStream.Free();
  FFileHandles.Clear();
  FNextFileHandle := 1;

  // Clear handler maps first (they reference nodes in FParsedRoots)
  FSemanticHandlers.Clear();
  FEmitterHandlers.Clear();
  FMirHandlers.Clear();
  FGrammarRules.Clear();
  FPrefixRules.Clear();
  FInfixRules.Clear();
  FStmtRules.Clear();
  FFragments.Clear();

  // Now free the ASTs that handlers pointed into
  FRecordDefs.Clear();

  // Token config
  FTokenKeywords.Clear();
  FTokenOperators.Clear();
  FTokenStringStyles.Clear();
  FTokenLineComments.Clear();
  FTokenBlockComments.Clear();
  FTokenDirectives.Clear();
  FTokenDirectiveFlags.Clear();
  FRawBlockEnds.Clear();
  FTokenKindToText.Clear();
  FDefines.Clear();
  FModuleExtension := '';
  FLexerConfig.CaseSensitive := False;
  FLexerConfig.Terminator := '';
  FLexerConfig.BlockOpen := '';
  FLexerConfig.BlockClose := '';
  FLexerConfig.DirectivePrefix := '';
  FLexerConfig.HexPrefix.Clear();
  FUserTokenLists.Clear();
  FUserASTRoots.Clear();

  // Type config
  FTypeKeywords.Clear();
  FTypeMappings.Clear();
  FLiteralTypes.Clear();
  FCompatRules.Clear();
  FDeclKinds.Clear();
  FCallKinds.Clear();
  FCallNameAttr := '';
  FScopes.Reset();
  FActiveParser := nil;
  FResultNode := TLVMValue.Nil_();
  FCurrentInfixPower := 0;
  FRuleErrorSnapshot := 0;
  FCreatedNodes.Clear();
  FHostObjects.Clear();
  FSharedState.Clear();
  FParsedRoots.Clear();
  FImported.Clear();
  FImportPaths.Clear();
  FLanguageName := '';
  FLanguageVersion := '';
  FBaseDir := '';
  FCurrentNode := TLVMValue.Nil_();
  FActiveSemanticDict := nil;
  FSignal := lsNone;
  FReturnValue := TLVMValue.Nil_();
  FCurrentRoutineNode := nil;
  FOnPrint := Default(TCallback<TLVMPrintCallback>);
  FOnDiag := Default(TCallback<TLVMDiagCallback>);
  FLastError := '';
  FEnvironment.Clear();
end;

procedure TLangVM.SetOnPrint(const ACallback: TLVMPrintCallback;
  const AUserData: Pointer);
begin
  FOnPrint.Callback := ACallback;
  FOnPrint.UserData := AUserData;
end;

procedure TLangVM.SetOnDiag(const ACallback: TLVMDiagCallback;
  const AUserData: Pointer);
begin
  FOnDiag.Callback := ACallback;
  FOnDiag.UserData := AUserData;
end;

procedure TLangVM.SetHostObject(const AName: string; const AObj: TObject);
begin
  FHostObjects.AddOrSetValue(AName, AObj);
end;

function TLangVM.GetHostObject(const AName: string): TObject;
begin
  if not FHostObjects.TryGetValue(AName, Result) then
    Result := nil;
end;

function TLangVM.HasHostObject(const AName: string): Boolean;
begin
  Result := FHostObjects.ContainsKey(AName);
end;

{ TLangVM.SetShared }
procedure TLangVM.SetShared(const AKey: string; const AValue: string);
begin
  FSharedState.AddOrSetValue(AKey, TLVMValue.FromString(AValue));
end;

{ TLangVM.GetShared }
function TLangVM.GetShared(const AKey: string): string;
var
  LValue: TLVMValue;
begin
  if FSharedState.TryGetValue(AKey, LValue) then
    Result := LValue.AsString()
  else
    Result := '';
end;

{ TLangVM.HasShared }
function TLangVM.HasShared(const AKey: string): Boolean;
begin
  Result := FSharedState.ContainsKey(AKey);
end;

function TLangVM.Call(const ARoutineName: string;
  const AArgs: array of TLVMValue): TLVMValue;
var
  LRoutineVal: TLVMValue;
  LRoutineNode: TLVMASTNode;
  LBodyIdx: Integer;
  LParamNode: TLVMASTNode;
  LParamType: string;
  LI: Integer;
  LSavedRoutineNode: TLVMASTNode;
begin
  Result := TLVMValue.Nil_();
  try
  if not FEnvironment.TryGetVar(ARoutineName, LRoutineVal) then
  begin
    GetErrors().RaiseOnError := True;
    GetErrors().Add(esError, ERR_LVM_CALL, RSLVMUndefRoutine, [ARoutineName]);
  end;
  if LRoutineVal.Kind <> vkRoutine then
  begin
    GetErrors().RaiseOnError := True;
    GetErrors().Add(esError, ERR_LVM_CALL, RSLVMNotRoutine, [ARoutineName]);
  end;
  LRoutineNode := TLVMASTNode(LRoutineVal.AsRoutine());
  LBodyIdx := LRoutineNode.ChildCount() - 1;
  FEnvironment.PushScope();
  try
    // Bind parameters
    for LI := 0 to LBodyIdx - 1 do
    begin
      LParamNode := TLVMASTNode(LRoutineNode.Children[LI]);
      LParamType := LParamNode.GetAttr('type');
      if LI <= High(AArgs) then
      begin
        if (LParamType <> '') and (LParamType <> 'any') and (AArgs[LI].Kind <> vkNil) and
           (not TLVMValue.KindMatchesType(AArgs[LI], LParamType)) then
        begin
          GetErrors().RaiseOnError := True;
          GetErrors().Add(esError, ERR_LVM_TYPE, RSLVMArgTypeMismatch,
            [LI + 1, LParamType, AArgs[LI].KindName()]);
        end;
        FEnvironment.ForceSetVar(LParamNode.GetAttr('name'), AArgs[LI], LParamType);
      end
      else
        FEnvironment.ForceSetVar(LParamNode.GetAttr('name'), TLVMValue.Nil_(), LParamType);
    end;
    LSavedRoutineNode := FCurrentRoutineNode;
    FCurrentRoutineNode := LRoutineNode;
    FSignal := lsNone;
    ExecBlock(TLVMASTNode(LRoutineNode.Children[LBodyIdx]));
    FCurrentRoutineNode := LSavedRoutineNode;
    if FSignal = lsReturn then
    begin
      Result := FReturnValue;
      FSignal := lsNone;
      FReturnValue := TLVMValue.Nil_();
    end;
  finally
    FEnvironment.PopScope();
  end;
  except
    on E: EStdAppException do
      GetErrors().RaiseOnError := False;
  end;
end;

procedure TLangVM.Run(const ARoutineName: string);
begin
  if FErrors.HasErrors() then
    Exit;
  Call(ARoutineName, []);
end;

function TLangVM.Eval(const AExpr: string): TLVMValue;
var
  LTokens: TArray<TLVMToken>;
  LExprNode: TLVMASTNode;
begin
  LTokens := FLexer.Tokenize(AExpr, '<eval>');
  LExprNode := FParser.ParseSingleExpr(LTokens, '<eval>');
  try
    Result := EvalExpr(LExprNode);
  finally
    LExprNode.Free();
  end;
end;

function TLangVM.GetVar(const AName: string): TLVMValue;
begin
  Result := FEnvironment.GetVar(AName);
end;

procedure TLangVM.SetVar(const AName: string; const AValue: TLVMValue);
begin
  FEnvironment.ForceSetVar(AName, AValue);
end;

function TLangVM.GetExitCode(): Int64;
begin
  Result := FEnvironment.GetVar(LVM_EXITCODE).AsInt();
end;

procedure TLangVM.SetExitCode(const AValue: Int64);
begin
  FEnvironment.ForceSetVar(LVM_EXITCODE, TLVMValue.FromInt(AValue), 'int');
end;

function TLangVM.GetSourceFilename(): string;
begin
  Result := FEnvironment.GetVar(LVM_SRCFILE).AsString();
end;

procedure TLangVM.SetSourceFilename(const AValue: string);
begin
  FEnvironment.ForceSetVar(LVM_SRCFILE, TLVMValue.FromString(AValue), 'string');
end;

function TLangVM.GetZigBuild(): TLVMZigBuild;
begin
  Result := FZigBuild;
end;

function TLangVM.HasRoutine(const AName: string): Boolean;
var
  LVal: TLVMValue;
begin
  Result := FEnvironment.TryGetVar(AName, LVal) and
    (LVal.Kind = vkRoutine);
end;

function TLangVM.HasVar(const AName: string): Boolean;
begin
  Result := FEnvironment.HasVar(AName);
end;

function TLangVM.TryRun(const ARoutineName: string): Boolean;
begin
  FLastError := '';
  try
    Run(ARoutineName);
    Result := True;
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      Result := False;
    end;
  end;
end;

function TLangVM.TryCall(const ARoutineName: string;
  const AArgs: array of TLVMValue;
  out AResult: TLVMValue): Boolean;
begin
  FLastError := '';
  try
    AResult := Call(ARoutineName, AArgs);
    Result := True;
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      AResult := TLVMValue.Nil_();
      Result := False;
    end;
  end;
end;

procedure TLangVM.RunSemantics(const ARoot: TLVMValue);
var
  LPassDict: TLVMHandlerMap;
  LI: Integer;
  LJ: Integer;
  LChildCount: Integer;
  LArgs: TArray<TLVMValue>;
  LChildNode: TLVMValue;
  LPair: TPair<Integer, TLVMHandlerMap>;
  LList: TList<Integer>;
begin
  if ARoot.Kind = vkNil then Exit;

  // Get child count of the root
  SetLength(LArgs, 1);
  LArgs[0] := ARoot;
  LChildCount := CallBuiltin('childCount', LArgs).AsInt();

  if FSemanticHandlers.Count > 0 then
  begin
    // Collect and sort pass numbers
    LList := TList<Integer>.Create();
    try
      for LPair in FSemanticHandlers do
        LList.Add(LPair.Key);
      LList.Sort();

      for LI := 0 to LList.Count - 1 do
      begin
        LPassDict := FSemanticHandlers[LList[LI]];
        FActiveSemanticDict := LPassDict;
        try
          for LJ := 0 to LChildCount - 1 do
          begin
            SetLength(LArgs, 2);
            LArgs[0] := ARoot;
            LArgs[1] := TLVMValue.FromInt(LJ);
            LChildNode := CallBuiltin('getChild', LArgs);
            RunSemanticHandler(LChildNode);
          end;
        finally
          FActiveSemanticDict := nil;
        end;
      end;
    finally
      LList.Free();
    end;
  end;
end;

procedure TLangVM.RunEmitHandler(const AUserNode: TLVMValue);
var
  LNodeKind: string;
  LHandler: TLVMASTNode;
  LSavedNode: TLVMValue;
  LI: Integer;
  LChildCount: Integer;
  LChildNode: TLVMValue;
  LArgs: TArray<TLVMValue>;
begin
  if AUserNode.Kind = vkNil then Exit;

  // Get node kind from the host via builtin
  SetLength(LArgs, 1);
  LArgs[0] := AUserNode;
  LNodeKind := CallBuiltin('getNodeKind', LArgs).AsString();

  // Look up emitter handler
  if FEmitterHandlers.TryGetValue(LNodeKind, LHandler) then
  begin
    LSavedNode := FCurrentNode;
    FCurrentNode := AUserNode;
    FEnvironment.PushScope();
    try
      FEnvironment.ForceSetVar('node', AUserNode);
      ExecBlock(LHandler);
    finally
      FEnvironment.PopScope();
      FCurrentNode := LSavedNode;
    end;
  end
  else
  begin
    // No handler: auto-visit all children
    SetLength(LArgs, 1);
    LArgs[0] := AUserNode;
    LChildCount := CallBuiltin('childCount', LArgs).AsInt();
    for LI := 0 to LChildCount - 1 do
    begin
      SetLength(LArgs, 2);
      LArgs[0] := AUserNode;
      LArgs[1] := TLVMValue.FromInt(LI);
      LChildNode := CallBuiltin('getChild', LArgs);
      RunEmitHandler(LChildNode);
    end;
  end;
end;

procedure TLangVM.RunEmitters(const ARoot: TLVMValue);
var
  LI: Integer;
  LChildCount: Integer;
  LArgs: TArray<TLVMValue>;
  LChildNode: TLVMValue;
begin
  if ARoot.Kind = vkNil then Exit;

  SetLength(LArgs, 1);
  LArgs[0] := ARoot;
  LChildCount := CallBuiltin('childCount', LArgs).AsInt();

  for LI := 0 to LChildCount - 1 do
  begin
    SetLength(LArgs, 2);
    LArgs[0] := ARoot;
    LArgs[1] := TLVMValue.FromInt(LI);
    LChildNode := CallBuiltin('getChild', LArgs);
    RunEmitHandler(LChildNode);
  end;
end;

procedure TLangVM.RunMirHandler(const AEvent: string; const AVars: TArray<TPair<string, TLVMValue>>);
var
  LHandler: TLVMASTNode;
  LI: Integer;
begin
  if not FMirHandlers.TryGetValue(AEvent, LHandler) then
    Exit; // No handler registered for this event -- skip silently

  FEnvironment.PushScope();
  try
    // Inject event-specific variables into scope
    for LI := 0 to Length(AVars) - 1 do
      FEnvironment.ForceSetVar(AVars[LI].Key, AVars[LI].Value);
    ExecBlock(LHandler);
  finally
    FEnvironment.PopScope();
  end;
end;

{ TLVM.RunTargetHandler }
procedure TLangVM.RunTargetHandler(const AInsn: TLVMMirInsn);
var
  LHandler: TLVMASTNode;
  LParamsAttr: string;
  LParamNames: TArray<string>;
  LParamCount: Integer;
  LOperandCount: Integer;
  LI: Integer;
  LArr: TArray<TLVMValue>;
begin
  if not FTargetHandlers.TryGetValue(AInsn.Opcode, LHandler) then
  begin
    FErrors.Add(esError, ERR_LVM_TARGET,
      'No target handler for opcode "%s"', [MirOpcodeToStr(AInsn.Opcode)]);
    Exit;
  end;

  // Parse param names from handler
  LParamsAttr := LHandler.GetAttr('params');
  if LParamsAttr <> '' then
    LParamNames := LParamsAttr.Split([','])
  else
    SetLength(LParamNames, 0);
  LParamCount := Length(LParamNames);
  LOperandCount := Length(AInsn.Operands);

  // Variadic handling: if handler has fewer params than operands,
  // last param gets remaining operands as an array
  FEnvironment.PushScope();
  try
    // Bind context if present
    if FTargetContextName <> '' then
      FEnvironment.ForceSetVar(FTargetContextName, FTargetContext);

    if (LParamCount > 0) and (LOperandCount >= LParamCount) and
       (LOperandCount > LParamCount) then
    begin
      // Bind all params except last normally
      for LI := 0 to LParamCount - 2 do
        FEnvironment.ForceSetVar(LParamNames[LI],
          MirOperandToValue(AInsn.Operands[LI]));

      // Last param gets remaining operands as array
      SetLength(LArr, LOperandCount - (LParamCount - 1));
      for LI := LParamCount - 1 to LOperandCount - 1 do
        LArr[LI - (LParamCount - 1)] := MirOperandToValue(AInsn.Operands[LI]);
      FEnvironment.ForceSetVar(LParamNames[LParamCount - 1],
        TLVMValue.FromArray(LArr));
    end
    else
    begin
      // Exact match or fewer operands than params
      for LI := 0 to LParamCount - 1 do
      begin
        if LI < LOperandCount then
          FEnvironment.ForceSetVar(LParamNames[LI],
            MirOperandToValue(AInsn.Operands[LI]))
        else
          FEnvironment.ForceSetVar(LParamNames[LI], TLVMValue.Nil_());
      end;
    end;

    ExecBlock(LHandler);
  finally
    FEnvironment.PopScope();
  end;
end;

procedure TLangVM.RunMir();
var
  LI, LJ, LK, LN: Integer;
  LModule: TLVMMirModule;
  LFunc: TLVMMirFunc;
  LInsn: TLVMMirInsn;
  LProto: TLVMMirProto;
  LDataItem: TLVMMirDataItem;
  LVars: TArray<TPair<string, TLVMValue>>;
  LParamList: TLVMValue;
  LLocalList: TLVMValue;
  LResultList: TLVMValue;
  LImportList: TLVMValue;
  LExportList: TLVMValue;
  LOperandList: TLVMValue;
  LParamTypeList: TLVMValue;
  LArr: TArray<TLVMValue>;
begin
  for LI := 0 to FMirProgram.Modules.Count - 1 do
  begin
    LModule := FMirProgram.Modules[LI];

    // -- module event --
    // Build import list
    SetLength(LArr, Length(LModule.Imports));
    for LJ := 0 to Length(LModule.Imports) - 1 do
      LArr[LJ] := TLVMValue.FromString(LModule.Imports[LJ]);
    LImportList := TLVMValue.FromArray(LArr);

    // Build export list
    SetLength(LArr, Length(LModule.ExportList));
    for LJ := 0 to Length(LModule.ExportList) - 1 do
      LArr[LJ] := TLVMValue.FromString(LModule.ExportList[LJ]);
    LExportList := TLVMValue.FromArray(LArr);

    LVars := [
      TPair<string, TLVMValue>.Create('name', TLVMValue.FromString(LModule.ModuleName)),
      TPair<string, TLVMValue>.Create('imports', LImportList),
      TPair<string, TLVMValue>.Create('exports', LExportList)
    ];
    RunMirHandler('module', LVars);

    // -- proto events --
    for LJ := 0 to Length(LModule.Protos) - 1 do
    begin
      LProto := LModule.Protos[LJ];

      // Build result type list
      SetLength(LArr, Length(LProto.ResultTypes));
      for LK := 0 to Length(LProto.ResultTypes) - 1 do
        LArr[LK] := TLVMValue.FromString(MirTypeToStr(LProto.ResultTypes[LK]));
      LResultList := TLVMValue.FromArray(LArr);

      // Build param type list
      SetLength(LArr, Length(LProto.ParamTypes));
      for LK := 0 to Length(LProto.ParamTypes) - 1 do
        LArr[LK] := TLVMValue.FromString(MirTypeToStr(LProto.ParamTypes[LK]));
      LParamTypeList := TLVMValue.FromArray(LArr);

      LVars := [
        TPair<string, TLVMValue>.Create('name', TLVMValue.FromString(LProto.ProtoName)),
        TPair<string, TLVMValue>.Create('resultTypes', LResultList),
        TPair<string, TLVMValue>.Create('paramTypes', LParamTypeList),
        TPair<string, TLVMValue>.Create('isVararg', TLVMValue.FromBool(LProto.IsVararg))
      ];
      RunMirHandler('proto', LVars);
    end;

    // -- data events --
    for LJ := 0 to Length(LModule.DataItems) - 1 do
    begin
      LDataItem := LModule.DataItems[LJ];

      if LDataItem.DataKind = mdkString then
      begin
        LVars := [
          TPair<string, TLVMValue>.Create('name', TLVMValue.FromString(LDataItem.ItemName)),
          TPair<string, TLVMValue>.Create('value', TLVMValue.FromString(LDataItem.StrValue))
        ];
        RunMirHandler('string', LVars);
      end
      else if LDataItem.DataKind = mdkBss then
      begin
        LVars := [
          TPair<string, TLVMValue>.Create('name', TLVMValue.FromString(LDataItem.ItemName)),
          TPair<string, TLVMValue>.Create('size', TLVMValue.FromInt(LDataItem.BssSize))
        ];
        RunMirHandler('bss', LVars);
      end
      else if LDataItem.DataKind = mdkRef then
      begin
        LVars := [
          TPair<string, TLVMValue>.Create('name', TLVMValue.FromString(LDataItem.ItemName)),
          TPair<string, TLVMValue>.Create('target', TLVMValue.FromString(LDataItem.RefTarget)),
          TPair<string, TLVMValue>.Create('disp', TLVMValue.FromInt(LDataItem.RefDisp))
        ];
        RunMirHandler('ref', LVars);
      end
      else if LDataItem.DataKind = mdkExpr then
      begin
        LVars := [
          TPair<string, TLVMValue>.Create('name', TLVMValue.FromString(LDataItem.ItemName)),
          TPair<string, TLVMValue>.Create('func', TLVMValue.FromString(LDataItem.ExprFunc))
        ];
        RunMirHandler('expr', LVars);
      end
      else if LDataItem.DataKind = mdkLref then
      begin
        LVars := [
          TPair<string, TLVMValue>.Create('name', TLVMValue.FromString(LDataItem.ItemName)),
          TPair<string, TLVMValue>.Create('label1', TLVMValue.FromString(LDataItem.LrefLabel1)),
          TPair<string, TLVMValue>.Create('label2', TLVMValue.FromString(LDataItem.LrefLabel2)),
          TPair<string, TLVMValue>.Create('disp', TLVMValue.FromInt(LDataItem.LrefDisp))
        ];
        RunMirHandler('lref', LVars);
      end
      else
      begin
        // mdkData -- raw data values
        SetLength(LArr, Length(LDataItem.IntValues));
        for LK := 0 to Length(LDataItem.IntValues) - 1 do
          LArr[LK] := TLVMValue.FromInt(LDataItem.IntValues[LK]);
        LVars := [
          TPair<string, TLVMValue>.Create('name', TLVMValue.FromString(LDataItem.ItemName)),
          TPair<string, TLVMValue>.Create('dataType', TLVMValue.FromString(MirTypeToStr(LDataItem.DataType))),
          TPair<string, TLVMValue>.Create('values', TLVMValue.FromArray(LArr))
        ];
        RunMirHandler('data', LVars);
      end;
    end;

    // -- func events --
    for LJ := 0 to LModule.Funcs.Count - 1 do
    begin
      LFunc := LModule.Funcs[LJ];

      // Build result type list
      SetLength(LArr, Length(LFunc.ResultTypes));
      for LK := 0 to Length(LFunc.ResultTypes) - 1 do
        LArr[LK] := TLVMValue.FromString(MirTypeToStr(LFunc.ResultTypes[LK]));
      LResultList := TLVMValue.FromArray(LArr);

      // Build param list (type:name pairs as strings)
      SetLength(LArr, Length(LFunc.Params));
      for LK := 0 to Length(LFunc.Params) - 1 do
        LArr[LK] := TLVMValue.FromString(
          MirTypeToStr(LFunc.Params[LK].LocalType) + ':' + LFunc.Params[LK].LocalName);
      LParamList := TLVMValue.FromArray(LArr);

      // Build local list
      SetLength(LArr, Length(LFunc.Locals));
      for LK := 0 to Length(LFunc.Locals) - 1 do
        LArr[LK] := TLVMValue.FromString(
          MirTypeToStr(LFunc.Locals[LK].LocalType) + ':' + LFunc.Locals[LK].LocalName);
      LLocalList := TLVMValue.FromArray(LArr);

      LVars := [
        TPair<string, TLVMValue>.Create('name', TLVMValue.FromString(LFunc.FuncName)),
        TPair<string, TLVMValue>.Create('resultTypes', LResultList),
        TPair<string, TLVMValue>.Create('params', LParamList),
        TPair<string, TLVMValue>.Create('locals', LLocalList),
        TPair<string, TLVMValue>.Create('isVararg', TLVMValue.FromBool(LFunc.IsVararg))
      ];
      RunMirHandler('func', LVars);

      // -- insn/label events inside function --
      for LK := 0 to Length(LFunc.Insns) - 1 do
      begin
        LInsn := LFunc.Insns[LK];

        // If instruction has a label, fire label event first
        if LInsn.LabelDef <> '' then
        begin
          LVars := [
            TPair<string, TLVMValue>.Create('name', TLVMValue.FromString(LInsn.LabelDef))
          ];
          RunMirHandler('label', LVars);
        end;

        // Label-only entries are not real instructions -- skip opcode dispatch
        if LInsn.IsLabelOnly then
          Continue;

        // Fire target handler for per-opcode dispatch
        if FHasTarget then
          RunTargetHandler(LInsn);

        // Fire insn event -- build operand list
        SetLength(LArr, Length(LInsn.Operands));
        for LN := 0 to Length(LInsn.Operands) - 1 do
          LArr[LN] := MirOperandToValue(LInsn.Operands[LN]);
        LOperandList := TLVMValue.FromArray(LArr);

        LVars := [
          TPair<string, TLVMValue>.Create('opcode', TLVMValue.FromString(MirOpcodeToStr(LInsn.Opcode))),
          TPair<string, TLVMValue>.Create('operands', LOperandList)
        ];
        RunMirHandler('insn', LVars);
      end;

      // -- endfunc event --
      LVars := [
        TPair<string, TLVMValue>.Create('name', TLVMValue.FromString(LFunc.FuncName))
      ];
      RunMirHandler('endfunc', LVars);
    end;

    // -- endmodule event --
    LVars := [
      TPair<string, TLVMValue>.Create('name', TLVMValue.FromString(LModule.ModuleName))
    ];
    RunMirHandler('endmodule', LVars);
  end;
end;

{ IsMirSideEffect }
function TLangVM.IsMirSideEffect(const AOpcode: TLVMMirOpcode): Boolean;
begin
  Result := AOpcode in [
    // Memory store (side-effecting write)
    mopStore,
    // Calls
    mopCall, mopInline, mopJcall,
    // Returns
    mopRet, mopJret,
    // Unconditional branch
    mopJmp, mopJmpi,
    // Conditional branch (1-operand)
    mopBt, mopBf, mopBts, mopBfs,
    // Overflow branch
    mopBo, mopBno, mopUbo, mopUbno,
    // Compare-and-branch 64-bit
    mopBeq, mopBne, mopBlt, mopBle, mopBgt, mopBge,
    mopUblt, mopUble, mopUbgt, mopUbge,
    // Compare-and-branch 32-bit
    mopBeqs, mopBnes, mopBlts, mopBles, mopBgts, mopBges,
    mopUblts, mopUbles, mopUbgts, mopUbges,
    // Compare-and-branch float
    mopFbeq, mopFbne, mopFblt, mopFble, mopFbgt, mopFbge,
    mopDbeq, mopDbne, mopDblt, mopDble, mopDbgt, mopDbge,
    mopLdbeq, mopLdbne, mopLdblt, mopLdble, mopLdbgt, mopLdbge,
    // Switch
    mopSwitch,
    // Stack
    mopAlloca, mopBstart, mopBend,
    // Varargs
    mopVaStart, mopVaArg, mopVaBlockArg, mopVaEnd,
    // Properties
    mopPrset, mopPrbeq, mopPrbne
  ];
end;

{ MirPassDCE }
procedure TLangVM.MirPassDCE(const AFunc: TLVMMirFunc);

  // Returns the variable name from an operand, or '' if not a named variable
  function GetVarName(const AOp: TLVMMirOperand): string;
  begin
    case AOp.Kind of
      mokRegister: Result := AOp.RegName;
      mokReference: Result := AOp.RefName;
    else
      Result := '';
    end;
  end;

  procedure MarkLive(const ALive: TDictionary<string, Boolean>;
    const AOperands: TArray<TLVMMirOperand>; const AFrom, ATo: Integer);
  var
    LIdx: Integer;
    LName: string;
  begin
    for LIdx := AFrom to ATo do
    begin
      LName := GetVarName(AOperands[LIdx]);
      if LName <> '' then
        ALive.AddOrSetValue(LName, True);
    end;
  end;

var
  LInsns: TArray<TLVMMirInsn>;
  LLive: TDictionary<string, Boolean>;
  LKeep: TArray<Boolean>;
  LNewInsns: TArray<TLVMMirInsn>;
  LI, LJ, LCount: Integer;
  LInsn: TLVMMirInsn;
  LDstName: string;
begin
  LInsns := AFunc.Insns;
  if Length(LInsns) = 0 then
    Exit;

  LLive := TDictionary<string, Boolean>.Create();
  try
    SetLength(LKeep, Length(LInsns));
    for LI := 0 to High(LInsns) do
      LKeep[LI] := True;

    // Backward scan -- track liveness
    for LI := High(LInsns) downto 0 do
    begin
      LInsn := LInsns[LI];

      // Instructions with labels are branch targets -- always keep
      if LInsn.LabelDef <> '' then
      begin
        MarkLive(LLive, LInsn.Operands, 0, High(LInsn.Operands));
        Continue;
      end;

      // Side-effect instructions -- always keep
      if IsMirSideEffect(LInsn.Opcode) then
      begin
        MarkLive(LLive, LInsn.Operands, 0, High(LInsn.Operands));
        Continue;
      end;

      // Pure computation: Operands[0] = dest (write), Operands[1..N] = src (read)
      LDstName := '';
      if Length(LInsn.Operands) > 0 then
        LDstName := GetVarName(LInsn.Operands[0]);

      if LDstName <> '' then
      begin
        if not LLive.ContainsKey(LDstName) then
        begin
          // Destination is not live -- eliminate
          LKeep[LI] := False;
        end
        else
        begin
          // Destination is live -- consume it, mark sources live
          LLive.Remove(LDstName);
          MarkLive(LLive, LInsn.Operands, 1, High(LInsn.Operands));
        end;
      end
      else
      begin
        // Unknown shape -- keep and mark all operands live
        MarkLive(LLive, LInsn.Operands, 0, High(LInsn.Operands));
      end;
    end;

    // Rebuild instruction list without dead instructions
    LCount := 0;
    for LI := 0 to High(LKeep) do
      if LKeep[LI] then
        Inc(LCount);

    if LCount = Length(LInsns) then
      Exit; // Nothing eliminated

    SetLength(LNewInsns, LCount);
    LJ := 0;
    for LI := 0 to High(LInsns) do
    begin
      if LKeep[LI] then
      begin
        LNewInsns[LJ] := LInsns[LI];
        Inc(LJ);
      end;
    end;
    AFunc.Insns := LNewInsns;
  finally
    LLive.Free();
  end;
end;

{ OptimizeMir }
procedure TLangVM.OptimizeMir();
var
  LI, LJ: Integer;
  LModule: TLVMMirModule;
begin
  for LI := 0 to FMirProgram.Modules.Count - 1 do
  begin
    LModule := FMirProgram.Modules[LI];
    for LJ := 0 to LModule.Funcs.Count - 1 do
      MirPassDCE(LModule.Funcs[LJ]);
  end;
end;

procedure TLangVM.RunGrammarRule(const AName: string);
var
  LHandler: TLVMASTNode;
begin
  if not FGrammarRules.TryGetValue(AName, LHandler) then
  begin
    GetErrors().RaiseOnError := True;
    GetErrors().Add(esError, ERR_LVM_GRAMMAR, RSLVMGrammarNotFound, [AName]);
  end;

  FEnvironment.PushScope();
  try
    ExecBlock(LHandler);
  finally
    FEnvironment.PopScope();
  end;
end;

end.
