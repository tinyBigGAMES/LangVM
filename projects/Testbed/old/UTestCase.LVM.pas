unit UTestCase.LVM;

interface

uses
  StdApp.TestCase;

type

  { TLVMTestCase }
  TLVMTestCase = class(TTestCase)
  protected
    procedure Run(); override;
  public
    constructor Create(); override;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections,
  Myrissa.LVM;

{ TLVMTestCase }

constructor TLVMTestCase.Create();
begin
  inherited;
  Title := 'LVM Tests';

  // -----------------------------------------------------------------------
  // Group 1: TLVMValue basics
  // -----------------------------------------------------------------------
  RegisterTest('Value_Nil', procedure
  var
    LVal: TLVMValue;
  begin
    Section('TLVMValue.Nil_');
    LVal := TLVMValue.Nil_();
    Check(LVal.Kind = vkNil, 'Kind is vkNil');
    Check(LVal.IsNil(), 'IsNil returns True');
    Check(not LVal.IsTrue(), 'Nil is not truthy');
    Check(LVal.KindName() = 'nil', 'KindName is nil');
  end);

  RegisterTest('Value_Int', procedure
  var
    LVal: TLVMValue;
  begin
    Section('TLVMValue.FromInt');
    LVal := TLVMValue.FromInt(42);
    Check(LVal.Kind = vkInt, 'Kind is vkInt');
    Check(LVal.AsInt() = 42, 'AsInt = 42');
    Check(LVal.IsTrue(), '42 is truthy');

    LVal := TLVMValue.FromInt(0);
    Check(not LVal.IsTrue(), '0 is not truthy');
    Check(LVal.AsInt() = 0, 'AsInt = 0');
  end);

  RegisterTest('Value_Float', procedure
  var
    LVal: TLVMValue;
  begin
    Section('TLVMValue.FromFloat');
    LVal := TLVMValue.FromFloat(3.14);
    Check(LVal.Kind = vkFloat, 'Kind is vkFloat');
    Check(Abs(LVal.AsFloat() - 3.14) < 1E-9, 'AsFloat ~ 3.14');
    Check(LVal.IsTrue(), '3.14 is truthy');

    LVal := TLVMValue.FromFloat(0.0);
    Check(not LVal.IsTrue(), '0.0 is not truthy');
  end);

  RegisterTest('Value_Bool', procedure
  var
    LVal: TLVMValue;
  begin
    Section('TLVMValue.FromBool');
    LVal := TLVMValue.FromBool(True);
    Check(LVal.Kind = vkBool, 'Kind is vkBool');
    Check(LVal.AsBool() = True, 'AsBool = True');
    Check(LVal.IsTrue(), 'True is truthy');

    LVal := TLVMValue.FromBool(False);
    Check(not LVal.IsTrue(), 'False is not truthy');
  end);

  RegisterTest('Value_String', procedure
  var
    LVal: TLVMValue;
  begin
    Section('TLVMValue.FromString');
    LVal := TLVMValue.FromString('hello');
    Check(LVal.Kind = vkString, 'Kind is vkString');
    Check(LVal.AsString() = 'hello', 'AsString = hello');
    Check(LVal.IsTrue(), 'non-empty string is truthy');

    LVal := TLVMValue.FromString('');
    Check(not LVal.IsTrue(), 'empty string is not truthy');
  end);

  RegisterTest('Value_Handle', procedure
  var
    LVal: TLVMValue;
    LDummy: Integer;
  begin
    Section('TLVMValue.FromHandle');
    LVal := TLVMValue.FromHandle(@LDummy);
    Check(LVal.Kind = vkHandle, 'Kind is vkHandle');
    Check(LVal.AsHandle() = @LDummy, 'AsHandle round-trips');
    Check(LVal.IsTrue(), 'non-nil handle is truthy');

    // By design, all handles are truthy (opaque -- only builtins inspect the pointer)
    LVal := TLVMValue.FromHandle(nil);
    Check(LVal.IsTrue(), 'nil handle is still truthy (opaque type)');
  end);

  RegisterTest('Value_List', procedure
  var
    LVal: TLVMValue;
    LList: TLVMListStore;
  begin
    Section('TLVMValue.FromList');
    LVal := TLVMValue.FromList();
    Check(LVal.Kind = vkList, 'Kind is vkList');
    LList := LVal.AsList();
    Check(Assigned(LList), 'AsList is assigned');
    Check(LList.Count = 0, 'new list is empty');
    LList.Add(TLVMValue.FromInt(10));
    Check(LList.Count = 1, 'list count after add');
    Check(LList[0].AsInt() = 10, 'list[0] = 10');
  end);

  RegisterTest('Value_Map', procedure
  var
    LVal: TLVMValue;
    LMap: TLVMMapStore;
  begin
    Section('TLVMValue.FromMap');
    LVal := TLVMValue.FromMap();
    Check(LVal.Kind = vkMap, 'Kind is vkMap');
    LMap := LVal.AsMap();
    Check(Assigned(LMap), 'AsMap is assigned');
    Check(LMap.Count = 0, 'new map is empty');
    LMap.Add('key', TLVMValue.FromString('val'));
    Check(LMap.Count = 1, 'map count after add');
    Check(LMap['key'].AsString() = 'val', 'map[key] = val');
  end);

  RegisterTest('Value_ToString', procedure
  begin
    Section('TLVMValue.ToString conversions');
    Check(TLVMValue.Nil_().ToString() = 'nil', 'nil => nil');
    Check(TLVMValue.FromInt(7).ToString() = '7', 'int => 7');
    Check(TLVMValue.FromBool(True).ToString() = 'true', 'bool => true');
    Check(TLVMValue.FromBool(False).ToString() = 'false', 'bool => false');
    Check(TLVMValue.FromString('abc').ToString() = 'abc', 'string => abc');
  end);

  // -----------------------------------------------------------------------
  // Group 2: TLVMLexer
  // -----------------------------------------------------------------------
  RegisterTest('Lexer_Keywords', procedure
  var
    LLexer: TLVMLexer;
    LTokens: TArray<TLVMToken>;
  begin
    Section('Tokenize keywords');
    LLexer := TLVMLexer.Create();
    try
      LTokens := LLexer.Tokenize('let if else while return', 'test');
      Check(Length(LTokens) = 6, 'token count = 6');
      Check(LTokens[0].Kind = tkLet, 'let');
      Check(LTokens[1].Kind = tkIf, 'if');
      Check(LTokens[2].Kind = tkElse, 'else');
      Check(LTokens[3].Kind = tkWhile, 'while');
      Check(LTokens[4].Kind = tkReturn, 'return');
      Check(LTokens[5].Kind = tkEOF, 'EOF');
    finally
      LLexer.Free();
    end;
  end);

  RegisterTest('Lexer_Numbers', procedure
  var
    LLexer: TLVMLexer;
    LTokens: TArray<TLVMToken>;
  begin
    Section('Tokenize numbers');
    LLexer := TLVMLexer.Create();
    try
      LTokens := LLexer.Tokenize('42 3.14', 'test');
      Check(Length(LTokens) = 3, 'token count = 3');
      Check(LTokens[0].Kind = tkIntLit, '42 is int');
      Check(LTokens[0].Text = '42', 'text = 42');
      Check(LTokens[1].Kind = tkFloatLit, '3.14 is float');
      Check(LTokens[1].Text = '3.14', 'text = 3.14');
    finally
      LLexer.Free();
    end;
  end);

  RegisterTest('Lexer_Strings', procedure
  var
    LLexer: TLVMLexer;
    LTokens: TArray<TLVMToken>;
  begin
    Section('Tokenize strings');
    LLexer := TLVMLexer.Create();
    try
      LTokens := LLexer.Tokenize('"hello world"', 'test');
      Check(Length(LTokens) = 2, 'token count = 2');
      Check(LTokens[0].Kind = tkStringLit, 'string literal');
      Check(LTokens[0].Text = 'hello world', 'text = hello world');
    finally
      LLexer.Free();
    end;
  end);

  RegisterTest('Lexer_Operators', procedure
  var
    LLexer: TLVMLexer;
    LTokens: TArray<TLVMToken>;
  begin
    Section('Tokenize operators');
    LLexer := TLVMLexer.Create();
    try
      LTokens := LLexer.Tokenize('+ - * / == != < >', 'test');
      Check(LTokens[0].Kind = tkPlus, '+');
      Check(LTokens[1].Kind = tkMinus, '-');
      Check(LTokens[2].Kind = tkStar, '*');
      Check(LTokens[3].Kind = tkSlash, '/');
      Check(LTokens[4].Kind = tkEqEq, '==');
      Check(LTokens[5].Kind = tkNeq, '!=');
      Check(LTokens[6].Kind = tkLt, '<');
      Check(LTokens[7].Kind = tkGt, '>');
    finally
      LLexer.Free();
    end;
  end);

  RegisterTest('Lexer_LineCol', procedure
  var
    LLexer: TLVMLexer;
    LTokens: TArray<TLVMToken>;
  begin
    Section('Line and column tracking');
    LLexer := TLVMLexer.Create();
    try
      LTokens := LLexer.Tokenize('''
      a
      b
      ''', 'test');
      Check(LTokens[0].Line = 1, 'a on line 1');
      Check(LTokens[0].Col = 1, 'a at col 1');
      Check(LTokens[1].Line = 2, 'b on line 2');
      Check(LTokens[1].Col = 1, 'b at col 1');
    finally
      LLexer.Free();
    end;
  end);

  RegisterTest('Lexer_Comments', procedure
  var
    LLexer: TLVMLexer;
    LTokens: TArray<TLVMToken>;
  begin
    Section('Comments are skipped');
    LLexer := TLVMLexer.Create();
    try
      LTokens := LLexer.Tokenize('''
      a // line comment
      b /* block */ c
      ''', 'test');
      Check(Length(LTokens) = 4, 'token count = 4');
      Check(LTokens[0].Text = 'a', 'first = a');
      Check(LTokens[1].Text = 'b', 'second = b');
      Check(LTokens[2].Text = 'c', 'third = c');
    finally
      LLexer.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Group 3: TLVMParser -- uses real node kinds from parser
  // -----------------------------------------------------------------------
  RegisterTest('Parser_LetStmt', procedure
  var
    LLexer: TLVMLexer;
    LParser: TLVMParser;
    LTokens: TArray<TLVMToken>;
    LRoot: TLVMASTNode;
    LRoutine: TLVMASTNode;
    LBody: TLVMASTNode;
    LStmt: TLVMASTNode;
  begin
    Section('Parse let statement in routine');
    LLexer := TLVMLexer.Create();
    LParser := TLVMParser.Create();
    try
      LTokens := LLexer.Tokenize('''
      language test version "1.0";
      routine main() {
        let x = 42;
      }
      ''', 'test');
      LRoot := LParser.Parse(LTokens, 'test');
      try
        Check(LRoot.Kind = 'source_file', 'root is source_file');
        // child[0] = language_decl, child[1] = routine_decl
        Check(LRoot.ChildCount() >= 2, 'source has >= 2 children');
        LRoutine := LRoot.Children[1];
        Check(LRoutine.Kind = 'routine_decl', 'second child is routine_decl');
        Check(LRoutine.GetAttr('name') = 'main', 'routine name = main');
        // routine with no params: child[0] = stmt_block (body)
        Check(LRoutine.ChildCount() >= 1, 'routine has body');
        LBody := LRoutine.Children[0];
        Check(LBody.Kind = 'stmt_block', 'body is stmt_block');
        Check(LBody.ChildCount() >= 1, 'body has statements');
        LStmt := LBody.Children[0];
        Check(LStmt.Kind = 'let_stmt', 'statement is let_stmt');
        Check(LStmt.GetAttr('name') = 'x', 'let name = x');
        // let_stmt child[0] = initializer expression
        Check(LStmt.ChildCount() >= 1, 'let has initializer');
        Check(LStmt.Children[0].Kind = 'expr.int', 'init is expr.int');
      finally
        LRoot.Free();
      end;
    finally
      LParser.Free();
      LLexer.Free();
    end;
  end);

  RegisterTest('Parser_IfStmt', procedure
  var
    LLexer: TLVMLexer;
    LParser: TLVMParser;
    LTokens: TArray<TLVMToken>;
    LRoot: TLVMASTNode;
    LRoutine: TLVMASTNode;
    LBody: TLVMASTNode;
    LIfNode: TLVMASTNode;
  begin
    Section('Parse if/else');
    LLexer := TLVMLexer.Create();
    LParser := TLVMParser.Create();
    try
      LTokens := LLexer.Tokenize('''
      language test version "1.0";
      routine main() {
        if true {
          let a = 1;
        } else {
          let b = 2;
        }
      }
      ''', 'test');
      LRoot := LParser.Parse(LTokens, 'test');
      try
        LRoutine := LRoot.Children[1];
        LBody := LRoutine.Children[0];
        LIfNode := LBody.Children[0];
        Check(LIfNode.Kind = 'if_stmt', 'if_stmt node');
        // if_stmt children: if_branch, else_branch
        Check(LIfNode.ChildCount() = 2, 'if has 2 children (if_branch, else_branch)');
        Check(LIfNode.Children[0].Kind = 'if_branch', 'first child is if_branch');
        Check(LIfNode.Children[1].Kind = 'else_branch', 'second child is else_branch');
      finally
        LRoot.Free();
      end;
    finally
      LParser.Free();
      LLexer.Free();
    end;
  end);

  RegisterTest('Parser_WhileStmt', procedure
  var
    LLexer: TLVMLexer;
    LParser: TLVMParser;
    LTokens: TArray<TLVMToken>;
    LRoot: TLVMASTNode;
    LRoutine: TLVMASTNode;
    LBody: TLVMASTNode;
    LWhile: TLVMASTNode;
  begin
    Section('Parse while loop');
    LLexer := TLVMLexer.Create();
    LParser := TLVMParser.Create();
    try
      LTokens := LLexer.Tokenize('''
      language test version "1.0";
      routine main() {
        while true {
          break;
        }
      }
      ''', 'test');
      LRoot := LParser.Parse(LTokens, 'test');
      try
        LRoutine := LRoot.Children[1];
        LBody := LRoutine.Children[0];
        LWhile := LBody.Children[0];
        Check(LWhile.Kind = 'while_stmt', 'while_stmt node');
        // while_stmt: child[0]=condition, child[1]=stmt_block body
        Check(LWhile.ChildCount() = 2, 'while has 2 children (cond, body)');
      finally
        LRoot.Free();
      end;
    finally
      LParser.Free();
      LLexer.Free();
    end;
  end);

  RegisterTest('Parser_Expr', procedure
  var
    LLexer: TLVMLexer;
    LParser: TLVMParser;
    LTokens: TArray<TLVMToken>;
    LRoot: TLVMASTNode;
    LRoutine: TLVMASTNode;
    LBody: TLVMASTNode;
    LLet: TLVMASTNode;
    LExpr: TLVMASTNode;
  begin
    Section('Parse arithmetic expression');
    LLexer := TLVMLexer.Create();
    LParser := TLVMParser.Create();
    try
      LTokens := LLexer.Tokenize('''
      language test version "1.0";
      routine main() {
        let x = 1 + 2;
      }
      ''', 'test');
      LRoot := LParser.Parse(LTokens, 'test');
      try
        LRoutine := LRoot.Children[1];
        LBody := LRoutine.Children[0];
        LLet := LBody.Children[0];
        Check(LLet.Kind = 'let_stmt', 'let_stmt node');
        Check(LLet.ChildCount() >= 1, 'let has initializer');
        LExpr := LLet.Children[0];
        Check(LExpr.Kind = 'expr.binary', 'initializer is expr.binary');
        Check(LExpr.GetAttr('op') = '+', 'op is +');
      finally
        LRoot.Free();
      end;
    finally
      LParser.Free();
      LLexer.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Group 4: TLVM interpreter -- builtins, environment, EvalExpr, ExecStmt
  // -----------------------------------------------------------------------
  RegisterTest('VM_Builtins', procedure
  var
    LVM: TLVM;
    LResult: TLVMValue;
    LCalled: Boolean;
  begin
    Section('RegisterBuiltin and CallBuiltin');
    LVM := TLVM.Create();
    try
      LCalled := False;
      LVM.RegisterBuiltin('test_fn', function(
        const AArgs: TArray<TLVMValue>; const AVM: TLVM): TLVMValue
      begin
        LCalled := True;
        Result := TLVMValue.FromInt(99);
      end);

      Check(LVM.HasBuiltin('test_fn'), 'test_fn registered');
      Check(not LVM.HasBuiltin('nope'), 'nope not registered');

      LResult := LVM.CallBuiltin('test_fn', []);
      Check(LCalled, 'builtin was called');
      Check(LResult.AsInt() = 99, 'result = 99');
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('VM_Environment', procedure
  var
    LVM: TLVM;
  begin
    Section('Environment get/set/scope');
    LVM := TLVM.Create();
    try
      LVM.Environment.SetVar('x', TLVMValue.FromInt(10));
      Check(LVM.Environment.HasVar('x'), 'x exists');
      Check(LVM.Environment.GetVar('x').AsInt() = 10, 'x = 10');

      LVM.Environment.PushScope();
      LVM.Environment.SetVar('x', TLVMValue.FromInt(20));
      Check(LVM.Environment.GetVar('x').AsInt() = 20, 'x = 20 in inner scope');

      LVM.Environment.PopScope();
      Check(LVM.Environment.GetVar('x').AsInt() = 10, 'x = 10 after pop');
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('VM_EvalExpr_Literal', procedure
  var
    LVM: TLVM;
    LNode: TLVMASTNode;
    LResult: TLVMValue;
  begin
    Section('EvalExpr on literal nodes');
    LVM := TLVM.Create();
    try
      // Integer literal
      LNode := TLVMASTNode.Create();
      try
        LNode.Kind := 'expr.int';
        LNode.SetAttr('value', '42');
        LResult := LVM.EvalExpr(LNode);
        Check(LResult.AsInt() = 42, 'int lit = 42');
      finally
        LNode.Free();
      end;

      // String literal
      LNode := TLVMASTNode.Create();
      try
        LNode.Kind := 'expr.string';
        LNode.SetAttr('value', 'hi');
        LResult := LVM.EvalExpr(LNode);
        Check(LResult.AsString() = 'hi', 'string lit = hi');
      finally
        LNode.Free();
      end;

      // Bool literal
      LNode := TLVMASTNode.Create();
      try
        LNode.Kind := 'expr.bool';
        LNode.SetAttr('value', 'true');
        LResult := LVM.EvalExpr(LNode);
        Check(LResult.AsBool() = True, 'bool lit = true');
      finally
        LNode.Free();
      end;

      // Nil literal
      LNode := TLVMASTNode.Create();
      try
        LNode.Kind := 'expr.nil';
        LResult := LVM.EvalExpr(LNode);
        Check(LResult.IsNil(), 'nil lit is nil');
      finally
        LNode.Free();
      end;
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('VM_EvalExpr_BinOp', procedure
  var
    LVM: TLVM;
    LNode: TLVMASTNode;
    LLeft: TLVMASTNode;
    LRight: TLVMASTNode;
    LResult: TLVMValue;
  begin
    Section('EvalExpr on binary nodes');
    LVM := TLVM.Create();
    try
      // 10 + 5
      LNode := TLVMASTNode.Create();
      LLeft := TLVMASTNode.Create();
      LRight := TLVMASTNode.Create();
      LLeft.Kind := 'expr.int';
      LLeft.SetAttr('value', '10');
      LRight.Kind := 'expr.int';
      LRight.SetAttr('value', '5');
      LNode.Kind := 'expr.binary';
      LNode.SetAttr('op', '+');
      LNode.AddChild(LLeft);
      LNode.AddChild(LRight);
      try
        LResult := LVM.EvalExpr(LNode);
        Check(LResult.AsInt() = 15, '10 + 5 = 15');
      finally
        LNode.Free();
      end;

      // 10 - 3
      LNode := TLVMASTNode.Create();
      LLeft := TLVMASTNode.Create();
      LRight := TLVMASTNode.Create();
      LLeft.Kind := 'expr.int';
      LLeft.SetAttr('value', '10');
      LRight.Kind := 'expr.int';
      LRight.SetAttr('value', '3');
      LNode.Kind := 'expr.binary';
      LNode.SetAttr('op', '-');
      LNode.AddChild(LLeft);
      LNode.AddChild(LRight);
      try
        LResult := LVM.EvalExpr(LNode);
        Check(LResult.AsInt() = 7, '10 - 3 = 7');
      finally
        LNode.Free();
      end;

      // 6 * 7
      LNode := TLVMASTNode.Create();
      LLeft := TLVMASTNode.Create();
      LRight := TLVMASTNode.Create();
      LLeft.Kind := 'expr.int';
      LLeft.SetAttr('value', '6');
      LRight.Kind := 'expr.int';
      LRight.SetAttr('value', '7');
      LNode.Kind := 'expr.binary';
      LNode.SetAttr('op', '*');
      LNode.AddChild(LLeft);
      LNode.AddChild(LRight);
      try
        LResult := LVM.EvalExpr(LNode);
        Check(LResult.AsInt() = 42, '6 * 7 = 42');
      finally
        LNode.Free();
      end;

      // 10 == 10
      LNode := TLVMASTNode.Create();
      LLeft := TLVMASTNode.Create();
      LRight := TLVMASTNode.Create();
      LLeft.Kind := 'expr.int';
      LLeft.SetAttr('value', '10');
      LRight.Kind := 'expr.int';
      LRight.SetAttr('value', '10');
      LNode.Kind := 'expr.binary';
      LNode.SetAttr('op', '==');
      LNode.AddChild(LLeft);
      LNode.AddChild(LRight);
      try
        LResult := LVM.EvalExpr(LNode);
        Check(LResult.AsBool() = True, '10 == 10 is true');
      finally
        LNode.Free();
      end;
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('VM_ExecStmt_Let', procedure
  var
    LVM: TLVM;
    LNode: TLVMASTNode;
    LExpr: TLVMASTNode;
  begin
    Section('ExecStmt -- let binding via hand-built AST');
    LVM := TLVM.Create();
    try
      // Build: let x = 42
      LNode := TLVMASTNode.Create();
      LNode.Kind := 'let_stmt';
      LNode.SetAttr('name', 'x');
      LExpr := TLVMASTNode.Create();
      LExpr.Kind := 'expr.int';
      LExpr.SetAttr('value', '42');
      LNode.AddChild(LExpr);
      try
        LVM.ExecStmt(LNode);
        Check(LVM.Environment.HasVar('x'), 'x bound');
        Check(LVM.Environment.GetVar('x').AsInt() = 42, 'x = 42');
      finally
        LNode.Free();
      end;
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('VM_ExecStmt_If', procedure
  var
    LVM: TLVM;
    LLexer: TLVMLexer;
    LParser: TLVMParser;
    LTokens: TArray<TLVMToken>;
    LRoot: TLVMASTNode;
    LRoutine: TLVMASTNode;
    LBody: TLVMASTNode;
  begin
    Section('ExecBlock -- if with true condition via parsed AST');
    LVM := TLVM.Create();
    LLexer := TLVMLexer.Create();
    LParser := TLVMParser.Create();
    try
      LTokens := LLexer.Tokenize('''
      language test version "1.0";
      routine main() {
        let result = 0;
        if true {
          result = 1;
        }
      }
      ''', 'test');
      LRoot := LParser.Parse(LTokens, 'test');
      try
        LRoutine := LRoot.Children[1];
        LBody := LRoutine.Children[0]; // stmt_block
        LVM.ExecBlock(LBody);
        Check(LVM.Environment.GetVar('result').AsInt() = 1, 'result = 1 after if-true');
      finally
        LRoot.Free();
      end;
    finally
      LParser.Free();
      LLexer.Free();
      LVM.Free();
    end;
  end);

  RegisterTest('VM_CallBuiltin_FromExpr', procedure
  var
    LVM: TLVM;
    LNode: TLVMASTNode;
    LCallee: TLVMASTNode;
    LArg: TLVMASTNode;
    LResult: TLVMValue;
  begin
    Section('EvalExpr on call node invokes builtin');
    LVM := TLVM.Create();
    try
      LVM.RegisterBuiltin('double', function(
        const AArgs: TArray<TLVMValue>; const AVM: TLVM): TLVMValue
      begin
        Result := TLVMValue.FromInt(AArgs[0].AsInt() * 2);
      end);

      // Build call node: double(21)
      // Child 0 = callee (expr.ident), children 1+ = args
      LNode := TLVMASTNode.Create();
      LNode.Kind := 'expr.call';
      LCallee := TLVMASTNode.Create();
      LCallee.Kind := 'expr.ident';
      LCallee.SetAttr('name', 'double');
      LNode.AddChild(LCallee);
      LArg := TLVMASTNode.Create();
      LArg.Kind := 'expr.int';
      LArg.SetAttr('value', '21');
      LNode.AddChild(LArg);
      try
        LResult := LVM.EvalExpr(LNode);
        Check(LResult.AsInt() = 42, 'double(21) = 42');
      finally
        LNode.Free();
      end;
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Group 5: Integration -- RunSemantics / RunEmitters with mock AST
  // -----------------------------------------------------------------------
  RegisterTest('Integration_RunEmitters', procedure
  var
    LVM: TLVM;
    LTokens: TArray<TLVMToken>;
    LRoot: TLVMASTNode;
    LHandlerFired: Boolean;
    LMockRoot: Pointer;
    LMockChild: Pointer;
    LSource: string;
  begin
    Section('RunEmitters dispatches to .lvm emitter handler via mock AST');
    LHandlerFired := False;

    // Minimal .lvm with one emitter handler for stmt.print
    // The handler calls the 'markFired' builtin to prove it ran
    LSource :=
      '''
      emitters {
        on stmt.print {
          markFired();
        }
      }
      ''';

    LVM := TLVM.Create();
    try
      // Mock AST: root has 1 child whose kind is "stmt.print"
      // Use tagged integer pointers as opaque handles
      LMockRoot := Pointer(1);
      LMockChild := Pointer(2);

      // getNodeKind: root->source_file, child->stmt.print
      LVM.RegisterBuiltin('getNodeKind', function(
        const AArgs: TArray<TLVMValue>; const AVM: TLVM): TLVMValue
      begin
        if AArgs[0].AsHandle() = LMockChild then
          Result := TLVMValue.FromString('stmt.print')
        else
          Result := TLVMValue.FromString('source_file');
      end);

      // childCount: root has 1 child, child has 0
      LVM.RegisterBuiltin('childCount', function(
        const AArgs: TArray<TLVMValue>; const AVM: TLVM): TLVMValue
      begin
        if AArgs[0].AsHandle() = LMockRoot then
          Result := TLVMValue.FromInt(1)
        else
          Result := TLVMValue.FromInt(0);
      end);

      // getChild: root[0] -> child
      LVM.RegisterBuiltin('getChild', function(
        const AArgs: TArray<TLVMValue>; const AVM: TLVM): TLVMValue
      begin
        Result := TLVMValue.FromHandle(LMockChild);
      end);

      // Tracking builtin -- proves handler body executed
      LVM.RegisterBuiltin('markFired', function(
        const AArgs: TArray<TLVMValue>; const AVM: TLVM): TLVMValue
      begin
        LHandlerFired := True;
        Result := TLVMValue.Nil_();
      end);

      // Parse and walk the .lvm to register handlers
      LTokens := LVM.Lexer.Tokenize(LSource, 'test.lvm');
      LRoot := LVM.Parser.Parse(LTokens, 'test.lvm');
      try
        LVM.WalkSource(LRoot);

        // Verify handler was registered
        Check(LVM.EmitterHandlers.ContainsKey('stmt.print'),
          'emitter handler registered for stmt.print');

        // Run emitters with mock AST root
        LVM.RunEmitters(TLVMValue.FromHandle(LMockRoot));

        Check(LHandlerFired, 'emitter handler body executed');
      finally
        LRoot.Free();
      end;
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('Integration_RunSemantics', procedure
  var
    LVM: TLVM;
    LTokens: TArray<TLVMToken>;
    LRoot: TLVMASTNode;
    LHandlerFired: Boolean;
    LMockRoot: Pointer;
    LMockChild: Pointer;
    LSource: string;
  begin
    Section('RunSemantics dispatches to .lvm semantic handler via mock AST');
    LHandlerFired := False;

    // Minimal .lvm with one semantic handler inside pass 1
    LSource :=
      '''
      semantics {
        pass 1 "resolve" {
          on decl.func {
            markFired();
          }
        }
      }
      ''';

    LVM := TLVM.Create();
    try
      LMockRoot := Pointer(10);
      LMockChild := Pointer(20);

      LVM.RegisterBuiltin('getNodeKind', function(
        const AArgs: TArray<TLVMValue>; const AVM: TLVM): TLVMValue
      begin
        if AArgs[0].AsHandle() = LMockChild then
          Result := TLVMValue.FromString('decl.func')
        else
          Result := TLVMValue.FromString('source_file');
      end);

      LVM.RegisterBuiltin('childCount', function(
        const AArgs: TArray<TLVMValue>; const AVM: TLVM): TLVMValue
      begin
        if AArgs[0].AsHandle() = LMockRoot then
          Result := TLVMValue.FromInt(1)
        else
          Result := TLVMValue.FromInt(0);
      end);

      LVM.RegisterBuiltin('getChild', function(
        const AArgs: TArray<TLVMValue>; const AVM: TLVM): TLVMValue
      begin
        Result := TLVMValue.FromHandle(LMockChild);
      end);

      LVM.RegisterBuiltin('markFired', function(
        const AArgs: TArray<TLVMValue>; const AVM: TLVM): TLVMValue
      begin
        LHandlerFired := True;
        Result := TLVMValue.Nil_();
      end);

      LTokens := LVM.Lexer.Tokenize(LSource, 'test.lvm');
      LRoot := LVM.Parser.Parse(LTokens, 'test.lvm');
      try
        LVM.WalkSource(LRoot);

        // Verify pass 1 handler was registered
        Check(LVM.SemanticHandlers.ContainsKey(1),
          'semantic pass 1 registered');

        LVM.RunSemantics(TLVMValue.FromHandle(LMockRoot));

        Check(LHandlerFired, 'semantic handler body executed');
      finally
        LRoot.Free();
      end;
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Group 6: Orchestration -- LoadSource, LoadFile, Reset
  // -----------------------------------------------------------------------
  RegisterTest('Integration_LoadSource', procedure
  var
    LVM: TLVM;
    LHandlerFired: Boolean;
    LMockRoot: Pointer;
    LMockChild: Pointer;
  begin
    Section('LoadSource parses and walks .lvm, then RunEmitters dispatches');
    LHandlerFired := False;
    LMockRoot := Pointer(1);
    LMockChild := Pointer(2);

    LVM := TLVM.Create();
    try
      LVM.RegisterBuiltin('getNodeKind', function(
        const AArgs: TArray<TLVMValue>; const AVM: TLVM): TLVMValue
      begin
        if AArgs[0].AsHandle() = LMockChild then
          Result := TLVMValue.FromString('stmt.print')
        else
          Result := TLVMValue.FromString('source_file');
      end);
      LVM.RegisterBuiltin('childCount', function(
        const AArgs: TArray<TLVMValue>; const AVM: TLVM): TLVMValue
      begin
        if AArgs[0].AsHandle() = LMockRoot then
          Result := TLVMValue.FromInt(1)
        else
          Result := TLVMValue.FromInt(0);
      end);
      LVM.RegisterBuiltin('getChild', function(
        const AArgs: TArray<TLVMValue>; const AVM: TLVM): TLVMValue
      begin
        Result := TLVMValue.FromHandle(LMockChild);
      end);
      LVM.RegisterBuiltin('markFired', function(
        const AArgs: TArray<TLVMValue>; const AVM: TLVM): TLVMValue
      begin
        LHandlerFired := True;
        Result := TLVMValue.Nil_();
      end);

      LVM.LoadSource(
        '''
        emitters {
          on stmt.print {
            markFired();
          }
        }
        ''', 'test.lvm');

      Check(LVM.EmitterHandlers.ContainsKey('stmt.print'),
        'handler registered via LoadSource');
      LVM.RunEmitters(TLVMValue.FromHandle(LMockRoot));
      Check(LHandlerFired, 'handler fired after LoadSource');
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('Integration_LoadFile', procedure
  var
    LVM: TLVM;
    LHandlerFired: Boolean;
    LMockRoot: Pointer;
    LMockChild: Pointer;
    LTempFile: string;
  begin
    Section('LoadFile reads .lvm from disk and registers handlers');
    LHandlerFired := False;
    LMockRoot := Pointer(1);
    LMockChild := Pointer(2);

    // Write a temp .lvm file
    LTempFile := TPath.Combine(TPath.GetTempPath(), 'test_loadfile.lvm');
    TFile.WriteAllText(LTempFile,
      '''
      emitters {
        on expr.intlit {
          markFired();
        }
      }
      ''', TEncoding.UTF8);
    try
      LVM := TLVM.Create();
      try
        LVM.RegisterBuiltin('getNodeKind', function(
          const AArgs: TArray<TLVMValue>; const AVM: TLVM): TLVMValue
        begin
          if AArgs[0].AsHandle() = LMockChild then
            Result := TLVMValue.FromString('expr.intlit')
          else
            Result := TLVMValue.FromString('source_file');
        end);
        LVM.RegisterBuiltin('childCount', function(
          const AArgs: TArray<TLVMValue>; const AVM: TLVM): TLVMValue
        begin
          if AArgs[0].AsHandle() = LMockRoot then
            Result := TLVMValue.FromInt(1)
          else
            Result := TLVMValue.FromInt(0);
        end);
        LVM.RegisterBuiltin('getChild', function(
          const AArgs: TArray<TLVMValue>; const AVM: TLVM): TLVMValue
        begin
          Result := TLVMValue.FromHandle(LMockChild);
        end);
        LVM.RegisterBuiltin('markFired', function(
          const AArgs: TArray<TLVMValue>; const AVM: TLVM): TLVMValue
        begin
          LHandlerFired := True;
          Result := TLVMValue.Nil_();
        end);

        LVM.LoadFile(LTempFile);

        Check(LVM.EmitterHandlers.ContainsKey('expr.intlit'),
          'handler registered via LoadFile');
        Check(LVM.BaseDir <> '', 'BaseDir set after LoadFile');
        LVM.RunEmitters(TLVMValue.FromHandle(LMockRoot));
        Check(LHandlerFired, 'handler fired after LoadFile');
      finally
        LVM.Free();
      end;
    finally
      if TFile.Exists(LTempFile) then
        TFile.Delete(LTempFile);
    end;
  end);

  RegisterTest('Integration_Reset', procedure
  var
    LVM: TLVM;
  begin
    Section('Reset clears .lvm state but preserves builtins');

    LVM := TLVM.Create();
    try
      LVM.RegisterBuiltin('myBuiltin', function(
        const AArgs: TArray<TLVMValue>; const AVM: TLVM): TLVMValue
      begin
        Result := TLVMValue.Nil_();
      end);

      LVM.LoadSource(
        '''
        emitters {
          on stmt.print {
            myBuiltin();
          }
        }
        ''', 'test.lvm');

      Check(LVM.EmitterHandlers.ContainsKey('stmt.print'),
        'handler exists before reset');
      Check(LVM.HasBuiltin('myBuiltin'),
        'builtin exists before reset');

      LVM.Reset();

      Check(not LVM.EmitterHandlers.ContainsKey('stmt.print'),
        'handler gone after reset');
      Check(LVM.HasBuiltin('myBuiltin'),
        'builtin preserved after reset');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Group 7: Record types
  // -----------------------------------------------------------------------
  RegisterTest('Record_Define', procedure
  var
    LVM: TLVM;
  begin
    Section('Parse and walk a record declaration');
    LVM := TLVM.Create();
    try
      LVM.LoadSource('''
        record RegState {
          name: "";
          index: 0;
          inUse: false;
        }
        ''', 'test.lvm');

      Check(LVM.RecordDefs.ContainsKey('RegState'), 'RegState registered');
      Check(LVM.RecordDefs['RegState'].FieldNames.Count = 3, '3 fields');
      Check(LVM.RecordDefs['RegState'].HasField('name'), 'has field name');
      Check(LVM.RecordDefs['RegState'].HasField('index'), 'has field index');
      Check(LVM.RecordDefs['RegState'].HasField('inUse'), 'has field inUse');
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('Record_Construct', procedure
  var
    LVM: TLVM;
    LVal: TLVMValue;
    LRoutineNode: TLVMASTNode;
  begin
    Section('Construct record instance with defaults');
    LVM := TLVM.Create();
    try
      LVM.LoadSource('''
        record Point {
          x: 0;
          y: 0;
          label: "origin";
        }
        routine main() {
          let p = Point();
        }
        ''', 'test.lvm');

      LRoutineNode := TLVMASTNode(LVM.Environment.GetVar('main').AsRoutine());
      LVM.Environment.PushScope();
      try
        LVM.ExecBlock(TLVMASTNode(LRoutineNode.Children[LRoutineNode.ChildCount() - 1]));
        Check(LVM.Environment.HasVar('p'), 'p is bound');
        LVal := LVM.Environment.GetVar('p');
        Check(LVal.Kind = vkMap, 'p is a map');
        Check(LVal.AsMap().TypeName = 'Point', 'TypeName = Point');
        Check(LVal.AsMap()['x'].AsInt() = 0, 'x = 0');
        Check(LVal.AsMap()['y'].AsInt() = 0, 'y = 0');
        Check(LVal.AsMap()['label'].AsString() = 'origin', 'label = origin');
      finally
        LVM.Environment.PopScope();
      end;
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('Record_DotRead', procedure
  var
    LVM: TLVM;
    LCaptured: string;
    LRoutineNode: TLVMASTNode;
  begin
    Section('Read record fields via dot access');
    LVM := TLVM.Create();
    try
      LCaptured := '';
      LVM.RegisterBuiltin('capture',
        function(const AArgs: TArray<TLVMValue>; const AVM: TLVM): TLVMValue
        begin
          if Length(AArgs) > 0 then
            LCaptured := LCaptured + AArgs[0].ToString();
          Result := TLVMValue.Nil_();
        end);

      LVM.LoadSource('''
        record Item {
          name: "sword";
          value: 100;
        }
        routine main() {
          let item = Item();
          capture(item.name);
          capture(item.value);
        }
        ''', 'test.lvm');

      LRoutineNode := TLVMASTNode(LVM.Environment.GetVar('main').AsRoutine());
      LVM.Environment.PushScope();
      try
        LVM.ExecBlock(TLVMASTNode(LRoutineNode.Children[LRoutineNode.ChildCount() - 1]));
        Check(LCaptured = 'sword100', 'dot read = sword100');
      finally
        LVM.Environment.PopScope();
      end;
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('Record_DotWrite', procedure
  var
    LVM: TLVM;
    LCaptured: string;
    LRoutineNode: TLVMASTNode;
  begin
    Section('Write record fields via dot assignment');
    LVM := TLVM.Create();
    try
      LCaptured := '';
      LVM.RegisterBuiltin('capture',
        function(const AArgs: TArray<TLVMValue>; const AVM: TLVM): TLVMValue
        begin
          if Length(AArgs) > 0 then
            LCaptured := LCaptured + AArgs[0].ToString();
          Result := TLVMValue.Nil_();
        end);

      LVM.LoadSource('''
        record Reg {
          name: "";
          inUse: false;
        }
        routine main() {
          let r = Reg();
          r.name = "rax";
          r.inUse = true;
          capture(r.name);
          capture(r.inUse);
        }
        ''', 'test.lvm');

      LRoutineNode := TLVMASTNode(LVM.Environment.GetVar('main').AsRoutine());
      LVM.Environment.PushScope();
      try
        LVM.ExecBlock(TLVMASTNode(LRoutineNode.Children[LRoutineNode.ChildCount() - 1]));
        Check(LCaptured = 'raxtrue', 'dot write = raxtrue');
      finally
        LVM.Environment.PopScope();
      end;
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('Record_TypeOf', procedure
  var
    LVM: TLVM;
    LCaptured: string;
    LRoutineNode: TLVMASTNode;
  begin
    Section('typeOf returns record name');
    LVM := TLVM.Create();
    try
      LCaptured := '';
      LVM.RegisterBuiltin('capture',
        function(const AArgs: TArray<TLVMValue>; const AVM: TLVM): TLVMValue
        begin
          if Length(AArgs) > 0 then
            LCaptured := LCaptured + AArgs[0].ToString();
          Result := TLVMValue.Nil_();
        end);

      LVM.LoadSource('''
        record Widget {
          id: 0;
        }
        routine main() {
          let w = Widget();
          capture(typeOf(w));
          let m = {"a": 1};
          capture(typeOf(m));
        }
        ''', 'test.lvm');

      LRoutineNode := TLVMASTNode(LVM.Environment.GetVar('main').AsRoutine());
      LVM.Environment.PushScope();
      try
        LVM.ExecBlock(TLVMASTNode(LRoutineNode.Children[LRoutineNode.ChildCount() - 1]));
        Check(LCaptured = 'Widgetmap', 'typeOf = Widgetmap');
      finally
        LVM.Environment.PopScope();
      end;
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('Record_RoutineParam', procedure
  var
    LVM: TLVM;
    LCaptured: string;
    LRoutineNode: TLVMASTNode;
  begin
    Section('Record + routine with parameter');
    LVM := TLVM.Create();
    try
      LCaptured := '';
      LVM.RegisterBuiltin('capture',
        function(const AArgs: TArray<TLVMValue>; const AVM: TLVM): TLVMValue
        begin
          if Length(AArgs) > 0 then
            LCaptured := LCaptured + AArgs[0].ToString();
          Result := TLVMValue.Nil_();
        end);

      LVM.LoadSource('''
        routine greet(msg: string) {
          capture(msg);
        }
        routine main() {
          greet("hello");
        }
        ''', 'test.lvm');

      LRoutineNode := TLVMASTNode(LVM.Environment.GetVar('main').AsRoutine());
      LVM.Environment.PushScope();
      try
        LVM.ExecBlock(TLVMASTNode(LRoutineNode.Children[LRoutineNode.ChildCount() - 1]));
        Check(LCaptured = 'hello', 'routine with param');
      finally
        LVM.Environment.PopScope();
      end;
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('Record_Integration', procedure
  var
    LVM: TLVM;
    LCaptured: string;
    LRoutineNode: TLVMASTNode;
  begin
    Section('Full record pattern -- define, construct, mutate, use in routine');
    LVM := TLVM.Create();
    try
      LCaptured := '';
      LVM.RegisterBuiltin('capture',
        function(const AArgs: TArray<TLVMValue>; const AVM: TLVM): TLVMValue
        begin
          if Length(AArgs) > 0 then
            LCaptured := LCaptured + AArgs[0].ToString();
          Result := TLVMValue.Nil_();
        end);

      LVM.LoadSource('''
        record RegState {
          name: "";
          inUse: false;
        }

        routine allocReg(regs: list) -> string {
          for r in regs {
            if not r.inUse {
              r.inUse = true;
              return r.name;
            }
          }
          return "none";
        }

        routine main() {
          let regs = [RegState(), RegState(), RegState()];
          regs[0].name = "rax";
          regs[1].name = "rcx";
          regs[2].name = "rdx";
          regs[0].inUse = true;
          let got = allocReg(regs);
          capture(got);
        }
        ''', 'test.lvm');

      LRoutineNode := TLVMASTNode(LVM.Environment.GetVar('main').AsRoutine());
      LVM.Environment.PushScope();
      try
        LVM.ExecBlock(TLVMASTNode(LRoutineNode.Children[LRoutineNode.ChildCount() - 1]));
        Check(LCaptured = 'rcx', 'allocReg found rcx');
      finally
        LVM.Environment.PopScope();
      end;
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('HexBinLiterals', procedure
  var
    LVM: TLVM;
    LRoutineNode: TLVMASTNode;
  begin
    Section('Hex and binary literal parsing');
    LVM := TLVM.Create();
    try
      LVM.LoadSource('''
        routine main() {
          let h = 0xFF;
          let b = 0b1010;
        }
        ''', 'test.lvm');
      LRoutineNode := TLVMASTNode(LVM.Environment.GetVar('main').AsRoutine());
      LVM.Environment.PushScope();
      try
        LVM.ExecBlock(TLVMASTNode(LRoutineNode.Children[LRoutineNode.ChildCount() - 1]));
        Check(LVM.Environment.GetVar('h').AsInt() = 255, 'hex 0xFF = 255');
        Check(LVM.Environment.GetVar('b').AsInt() = 10, 'bin 0b1010 = 10');
      finally
        LVM.Environment.PopScope();
      end;
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('Buffer_ReadWrite', procedure
  var
    LVM: TLVM;
    LRoutineNode: TLVMASTNode;
  begin
    Section('Buffer create, write, read round-trip');
    LVM := TLVM.Create();
    try
      LVM.LoadSource('''
        routine main() {
          let buf = buffer(16);
          bufWriteU8(buf, 0, 0xAB);
          bufWriteU16(buf, 1, 0x1234);
          bufWriteU32(buf, 4, 0xDEADBEEF);
          let r8 = bufReadU8(buf, 0);
          let r16 = bufReadU16(buf, 1);
          let r32 = bufReadU32(buf, 4);
          let sz = bufSize(buf);
        }
        ''', 'test.lvm');
      LRoutineNode := TLVMASTNode(LVM.Environment.GetVar('main').AsRoutine());
      LVM.Environment.PushScope();
      try
        LVM.ExecBlock(TLVMASTNode(LRoutineNode.Children[LRoutineNode.ChildCount() - 1]));
        Check(LVM.Environment.GetVar('r8').AsInt() = $AB, 'readU8 = 0xAB');
        Check(LVM.Environment.GetVar('r16').AsInt() = $1234, 'readU16 = 0x1234');
        Check(LVM.Environment.GetVar('r32').AsInt() = Int64($DEADBEEF), 'readU32 = 0xDEADBEEF');
        Check(LVM.Environment.GetVar('sz').AsInt() = 16, 'bufSize = 16');
      finally
        LVM.Environment.PopScope();
      end;
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('Bitwise_Ops', procedure
  var
    LVM: TLVM;
    LRoutineNode: TLVMASTNode;
  begin
    Section('Bitwise builtins');
    LVM := TLVM.Create();
    try
      LVM.LoadSource('''
        routine main() {
          let a = band(0xFF, 0x0F);
          let b = bor(0xF0, 0x0F);
          let c = bxor(0xFF, 0x0F);
          let d = shl(1, 8);
          let e = shr(256, 4);
        }
        ''', 'test.lvm');
      LRoutineNode := TLVMASTNode(LVM.Environment.GetVar('main').AsRoutine());
      LVM.Environment.PushScope();
      try
        LVM.ExecBlock(TLVMASTNode(LRoutineNode.Children[LRoutineNode.ChildCount() - 1]));
        Check(LVM.Environment.GetVar('a').AsInt() = $0F, 'band(0xFF,0x0F) = 0x0F');
        Check(LVM.Environment.GetVar('b').AsInt() = $FF, 'bor(0xF0,0x0F) = 0xFF');
        Check(LVM.Environment.GetVar('c').AsInt() = $F0, 'bxor(0xFF,0x0F) = 0xF0');
        Check(LVM.Environment.GetVar('d').AsInt() = 256, 'shl(1,8) = 256');
        Check(LVM.Environment.GetVar('e').AsInt() = 16, 'shr(256,4) = 16');
      finally
        LVM.Environment.PopScope();
      end;
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('Layout_Record', procedure
  var
    LVM: TLVM;
    LRoutineNode: TLVMASTNode;
  begin
    Section('Layout record definition and sizeof');
    LVM := TLVM.Create();
    try
      LVM.LoadSource('''
        record Header layout {
          magic: u16 = 0;
          ver: u8 = 0;
          flags: u8 = 0;
          dataSize: u32 = 0;
        }
        routine main() {
          let sz = sizeof("Header");
        }
        ''', 'test.lvm');
      Check(LVM.RecordDefs.ContainsKey('Header'), 'Header registered');
      Check(LVM.RecordDefs['Header'].IsLayout, 'Header is layout');
      Check(LVM.RecordDefs['Header'].TotalSize = 8, 'TotalSize = 8 (2+1+1+4)');
      LRoutineNode := TLVMASTNode(LVM.Environment.GetVar('main').AsRoutine());
      LVM.Environment.PushScope();
      try
        LVM.ExecBlock(TLVMASTNode(LRoutineNode.Children[LRoutineNode.ChildCount() - 1]));
        Check(LVM.Environment.GetVar('sz').AsInt() = 8, 'sizeof = 8');
      finally
        LVM.Environment.PopScope();
      end;
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('Layout_PackUnpack', procedure
  var
    LVM: TLVM;
    LRoutineNode: TLVMASTNode;
  begin
    Section('bufWriteRecord + bufReadRecord round-trip');
    LVM := TLVM.Create();
    try
      LVM.LoadSource('''
        record Pair layout {
          a: u16 = 0;
          b: u32 = 0;
        }
        routine main() {
          let p = Pair();
          p.a = 0x1234;
          p.b = 0xDEADBEEF;
          let buf = buffer(64);
          bufWriteRecord(buf, 0, p);
          let q = bufReadRecord(buf, 0, "Pair");
          let ra = q.a;
          let rb = q.b;
        }
        ''', 'test.lvm');
      LRoutineNode := TLVMASTNode(LVM.Environment.GetVar('main').AsRoutine());
      LVM.Environment.PushScope();
      try
        LVM.ExecBlock(TLVMASTNode(LRoutineNode.Children[LRoutineNode.ChildCount() - 1]));
        Check(LVM.Environment.GetVar('ra').AsInt() = $1234, 'round-trip a = 0x1234');
        Check(LVM.Environment.GetVar('rb').AsInt() = Int64($DEADBEEF), 'round-trip b = 0xDEADBEEF');
      finally
        LVM.Environment.PopScope();
      end;
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('List_Builtins', procedure
  var
    LVM: TLVM;
    LRoutineNode: TLVMASTNode;
  begin
    Section('List manipulation builtins');
    LVM := TLVM.Create();
    try
      LVM.LoadSource('''
        routine main() {
          let a = [10, 20, 30];
          listAppend(a, 40);
          let lenAfter = len(a);

          let idx = listIndexOf(a, 20);

          let removed = listRemove(a, 1);
          let lenAfterRemove = len(a);

          let b = [3, 1, 2];
          listSort(b);
          let sorted0 = b[0];
          let sorted1 = b[1];
          let sorted2 = b[2];

          let c = [1, 2, 3];
          listReverse(c);
          let rev0 = c[0];

          let d = [10, 20, 30, 40, 50];
          let s = listSlice(d, 1, 3);
          let sliceLen = len(s);
          let slice0 = s[0];
          let slice1 = s[1];

          let e = ["a", "b", "c"];
          let joined = listJoin(e, ",");

          let f = [1, 2, 3];
          let g = listCopy(f);
          listAppend(g, 4);
          let origLen = len(f);
          let copyLen = len(g);

          let h = [1, 2, 3];
          listInsert(h, 0, 0);
          let ins0 = h[0];
          let insLen = len(h);

          let i = [1, 2, 3];
          listClear(i);
          let clearLen = len(i);
        }
        ''', 'test.lvm');
      LRoutineNode := TLVMASTNode(LVM.Environment.GetVar('main').AsRoutine());
      LVM.Environment.PushScope();
      try
        LVM.ExecBlock(TLVMASTNode(LRoutineNode.Children[LRoutineNode.ChildCount() - 1]));
        Check(LVM.Environment.GetVar('lenAfter').AsInt() = 4, 'listAppend grows list');
        Check(LVM.Environment.GetVar('idx').AsInt() = 1, 'listIndexOf finds element');
        Check(LVM.Environment.GetVar('removed').AsInt() = 20, 'listRemove returns removed');
        Check(LVM.Environment.GetVar('lenAfterRemove').AsInt() = 3, 'listRemove shrinks list');
        Check(LVM.Environment.GetVar('sorted0').AsInt() = 1, 'listSort[0]=1');
        Check(LVM.Environment.GetVar('sorted1').AsInt() = 2, 'listSort[1]=2');
        Check(LVM.Environment.GetVar('sorted2').AsInt() = 3, 'listSort[2]=3');
        Check(LVM.Environment.GetVar('rev0').AsInt() = 3, 'listReverse[0]=3');
        Check(LVM.Environment.GetVar('sliceLen').AsInt() = 2, 'listSlice len=2');
        Check(LVM.Environment.GetVar('slice0').AsInt() = 20, 'listSlice[0]=20');
        Check(LVM.Environment.GetVar('slice1').AsInt() = 30, 'listSlice[1]=30');
        Check(LVM.Environment.GetVar('joined').AsString() = 'a,b,c', 'listJoin=a,b,c');
        Check(LVM.Environment.GetVar('origLen').AsInt() = 3, 'listCopy does not affect original');
        Check(LVM.Environment.GetVar('copyLen').AsInt() = 4, 'listCopy is independent');
        Check(LVM.Environment.GetVar('ins0').AsInt() = 0, 'listInsert at 0');
        Check(LVM.Environment.GetVar('insLen').AsInt() = 4, 'listInsert grows list');
        Check(LVM.Environment.GetVar('clearLen').AsInt() = 0, 'listClear empties list');
      finally
        LVM.Environment.PopScope();
      end;
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('Map_Builtins', procedure
  var
    LVM: TLVM;
    LRoutineNode: TLVMASTNode;
  begin
    Section('Map manipulation builtins');
    LVM := TLVM.Create();
    try
      LVM.LoadSource('''
        routine main() {
          let m = {"a": 1, "b": 2, "c": 3};
          let keys = mapKeys(m);
          let klen = len(keys);

          let vals = mapValues(m);
          let vlen = len(vals);

          let hasA = mapHas(m, "a");
          let hasZ = mapHas(m, "z");

          let removed = mapRemove(m, "b");
          let afterRemove = len(m);

          let m2 = mapCopy(m);
          mapClear(m);
          let origCleared = len(m);
          let copyIntact = len(m2);
        }
        ''', 'test.lvm');
      LRoutineNode := TLVMASTNode(LVM.Environment.GetVar('main').AsRoutine());
      LVM.Environment.PushScope();
      try
        LVM.ExecBlock(TLVMASTNode(LRoutineNode.Children[LRoutineNode.ChildCount() - 1]));
        Check(LVM.Environment.GetVar('klen').AsInt() = 3, 'mapKeys returns 3 keys');
        Check(LVM.Environment.GetVar('vlen').AsInt() = 3, 'mapValues returns 3 values');
        Check(LVM.Environment.GetVar('hasA').AsBool() = True, 'mapHas finds existing key');
        Check(LVM.Environment.GetVar('hasZ').AsBool() = False, 'mapHas misses absent key');
        Check(LVM.Environment.GetVar('removed').AsInt() = 2, 'mapRemove returns removed value');
        Check(LVM.Environment.GetVar('afterRemove').AsInt() = 2, 'mapRemove shrinks map');
        Check(LVM.Environment.GetVar('origCleared').AsInt() = 0, 'mapClear empties map');
        Check(LVM.Environment.GetVar('copyIntact').AsInt() = 2, 'mapCopy is independent');
      finally
        LVM.Environment.PopScope();
      end;
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('Math_Builtins', procedure
  var
    LVM: TLVM;
    LRoutineNode: TLVMASTNode;
  begin
    Section('Math builtins');
    LVM := TLVM.Create();
    try
      LVM.LoadSource('''
        routine main() {
          let a1 = abs(-5);
          let a2 = abs(3);
          let mn = min(3, 7);
          let mx = max(3, 7);
          let cl = clamp(10, 0, 5);
          let fl = floor(3.7);
          let ce = ceil(3.2);
          let rn = round(3.5);
          let tf = toFloat(42);
          let ti = toInt(3.9);
          let tiStr = toInt("123");
          let pw = pow(2, 10);
          let lg = log2(256);

          let ii = isInt(42);
          let if_ = isFloat(3.14);
          let is_ = isString("hi");
          let ib = isBool(true);
          let il = isList([1]);
          let im = isMap({"a": 1});
          let in_ = isNil(nil);
          let inF = isNil(42);
        }
        ''', 'test.lvm');
      LRoutineNode := TLVMASTNode(LVM.Environment.GetVar('main').AsRoutine());
      LVM.Environment.PushScope();
      try
        LVM.ExecBlock(TLVMASTNode(LRoutineNode.Children[LRoutineNode.ChildCount() - 1]));
        Check(LVM.Environment.GetVar('a1').AsInt() = 5, 'abs(-5)=5');
        Check(LVM.Environment.GetVar('a2').AsInt() = 3, 'abs(3)=3');
        Check(LVM.Environment.GetVar('mn').AsInt() = 3, 'min(3,7)=3');
        Check(LVM.Environment.GetVar('mx').AsInt() = 7, 'max(3,7)=7');
        Check(LVM.Environment.GetVar('cl').AsInt() = 5, 'clamp(10,0,5)=5');
        Check(LVM.Environment.GetVar('fl').AsInt() = 3, 'floor(3.7)=3');
        Check(LVM.Environment.GetVar('ce').AsInt() = 4, 'ceil(3.2)=4');
        Check(LVM.Environment.GetVar('rn').AsInt() = 4, 'round(3.5)=4');
        Check(LVM.Environment.GetVar('tf').Kind = vkFloat, 'toFloat returns float');
        Check(LVM.Environment.GetVar('ti').AsInt() = 3, 'toInt(3.9)=3');
        Check(LVM.Environment.GetVar('tiStr').AsInt() = 123, 'toInt("123")=123');
        Check(LVM.Environment.GetVar('pw').AsInt() = 1024, 'pow(2,10)=1024');
        Check(LVM.Environment.GetVar('lg').AsInt() = 8, 'log2(256)=8');
        Check(LVM.Environment.GetVar('ii').AsBool() = True, 'isInt(42)');
        Check(LVM.Environment.GetVar('if_').AsBool() = True, 'isFloat(3.14)');
        Check(LVM.Environment.GetVar('is_').AsBool() = True, 'isString("hi")');
        Check(LVM.Environment.GetVar('ib').AsBool() = True, 'isBool(true)');
        Check(LVM.Environment.GetVar('il').AsBool() = True, 'isList([1])');
        Check(LVM.Environment.GetVar('im').AsBool() = True, 'isMap({"a":1})');
        Check(LVM.Environment.GetVar('in_').AsBool() = True, 'isNil(nil)');
        Check(LVM.Environment.GetVar('inF').AsBool() = False, 'isNil(42)=false');
      finally
        LVM.Environment.PopScope();
      end;
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('String_Extras', procedure
  var
    LVM: TLVM;
    LRoutineNode: TLVMASTNode;
  begin
    Section('String extra builtins');
    LVM := TLVM.Create();
    try
      LVM.LoadSource('''
        routine main() {
          let parts = split("a,b,c", ",");
          let plen = len(parts);
          let p0 = parts[0];
          let p2 = parts[2];

          let ch = charAt("hello", 1);

          let pl = padLeft("42", 5, "0");
          let pr = padRight("hi", 5, ".");

          let rp = repeat("ab", 3);

          let ix = indexOf("hello world", "world");
          let ix2 = indexOf("hello", "xyz");

          let tb1 = toBool(1);
          let tb2 = toBool(0);
          let tb3 = toBool("");

          let ts = toString(42);

          let hx = hexToInt("FF");
          let hx2 = hexToInt("0xFF");

          let ih = intToHex(255, 2);
        }
        ''', 'test.lvm');
      LRoutineNode := TLVMASTNode(LVM.Environment.GetVar('main').AsRoutine());
      LVM.Environment.PushScope();
      try
        LVM.ExecBlock(TLVMASTNode(LRoutineNode.Children[LRoutineNode.ChildCount() - 1]));
        Check(LVM.Environment.GetVar('plen').AsInt() = 3, 'split produces 3 parts');
        Check(LVM.Environment.GetVar('p0').AsString() = 'a', 'split[0]=a');
        Check(LVM.Environment.GetVar('p2').AsString() = 'c', 'split[2]=c');
        Check(LVM.Environment.GetVar('ch').AsString() = 'e', 'charAt("hello",1)=e');
        Check(LVM.Environment.GetVar('pl').AsString() = '00042', 'padLeft("42",5,"0")=00042');
        Check(LVM.Environment.GetVar('pr').AsString() = 'hi...', 'padRight("hi",5,".")=hi...');
        Check(LVM.Environment.GetVar('rp').AsString() = 'ababab', 'repeat("ab",3)=ababab');
        Check(LVM.Environment.GetVar('ix').AsInt() = 6, 'indexOf finds "world" at 6');
        Check(LVM.Environment.GetVar('ix2').AsInt() = -1, 'indexOf returns -1 for miss');
        Check(LVM.Environment.GetVar('tb1').AsBool() = True, 'toBool(1)=true');
        Check(LVM.Environment.GetVar('tb2').AsBool() = False, 'toBool(0)=false');
        Check(LVM.Environment.GetVar('tb3').AsBool() = False, 'toBool("")=false');
        Check(LVM.Environment.GetVar('ts').AsString() = '42', 'toString(42)="42"');
        Check(LVM.Environment.GetVar('hx').AsInt() = 255, 'hexToInt("FF")=255');
        Check(LVM.Environment.GetVar('hx2').AsInt() = 255, 'hexToInt("0xFF")=255');
        Check(LVM.Environment.GetVar('ih').AsString() = 'FF', 'intToHex(255,2)=FF');
      finally
        LVM.Environment.PopScope();
      end;
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('Utility_Builtins', procedure
  var
    LVM: TLVM;
    LRoutineNode: TLVMASTNode;
  begin
    Section('Utility builtins');
    LVM := TLVM.Create();
    try
      LVM.LoadSource('''
        routine main() {
          assert(true, "should pass");

          let r = range(5);
          let rlen = len(r);
          let r0 = r[0];
          let r4 = r[4];

          let r2 = range(2, 5);
          let r2len = len(r2);
          let r2first = r2[0];
          let r2last = r2[2];

          let t = time();
          let tpos = t > 0.0;

          let rnd = random(100);
          let rndOk = rnd >= 0;

          let rf = randomFloat();
          let rfOk = rf >= 0.0;

          let pj = pathJoin("foo", "bar.txt");
          let pd = pathDir("foo/bar.txt");
          let pf = pathFile("foo/bar.txt");
          let pe = pathExt("foo/bar.txt");

          let fe = fileExists("__nonexistent_file_xyz__");
          let de = dirExists("__nonexistent_dir_xyz__");
        }
        ''', 'test.lvm');
      LRoutineNode := TLVMASTNode(LVM.Environment.GetVar('main').AsRoutine());
      LVM.Environment.PushScope();
      try
        LVM.ExecBlock(TLVMASTNode(LRoutineNode.Children[LRoutineNode.ChildCount() - 1]));
        Check(LVM.Environment.GetVar('rlen').AsInt() = 5, 'range(5) has 5 elements');
        Check(LVM.Environment.GetVar('r0').AsInt() = 0, 'range(5)[0]=0');
        Check(LVM.Environment.GetVar('r4').AsInt() = 4, 'range(5)[4]=4');
        Check(LVM.Environment.GetVar('r2len').AsInt() = 3, 'range(2,5) has 3 elements');
        Check(LVM.Environment.GetVar('r2first').AsInt() = 2, 'range(2,5)[0]=2');
        Check(LVM.Environment.GetVar('r2last').AsInt() = 4, 'range(2,5)[2]=4');
        Check(LVM.Environment.GetVar('tpos').AsBool() = True, 'time() > 0');
        Check(LVM.Environment.GetVar('rndOk').AsBool() = True, 'random(100) >= 0');
        Check(LVM.Environment.GetVar('rfOk').AsBool() = True, 'randomFloat() >= 0');
        Check(LVM.Environment.GetVar('pj').AsString() <> '', 'pathJoin produces non-empty');
        Check(LVM.Environment.GetVar('pe').AsString() = '.txt', 'pathExt=.txt');
        Check(LVM.Environment.GetVar('fe').AsBool() = False, 'fileExists nonexistent=false');
        Check(LVM.Environment.GetVar('de').AsBool() = False, 'dirExists nonexistent=false');
      finally
        LVM.Environment.PopScope();
      end;
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('Buffer_ExecFlag', procedure
  var
    LVM: TLVM;
    LRoutineNode: TLVMASTNode;
  begin
    Section('Executable buffer flag reporting');
    LVM := TLVM.Create();
    try
      LVM.LoadSource('''
        routine main() {
          let data = buffer(16);
          let exec = buffer(16, true);
          let d = bufIsExec(data);
          let e = bufIsExec(exec);
        }
        ''', 'test.lvm');
      LRoutineNode := TLVMASTNode(LVM.Environment.GetVar('main').AsRoutine());
      LVM.Environment.PushScope();
      try
        LVM.ExecBlock(TLVMASTNode(
          LRoutineNode.Children[LRoutineNode.ChildCount() - 1]));
        Check(LVM.Environment.GetVar('d').AsBool() = False, 'data buf not exec');
        Check(LVM.Environment.GetVar('e').AsBool() = True, 'exec buf is exec');
      finally
        LVM.Environment.PopScope();
      end;
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('Buffer_Exec', procedure
  var
    LVM: TLVM;
    LRoutineNode: TLVMASTNode;
  begin
    Section('JIT: mov eax,42 + ret executed from buffer');
    LVM := TLVM.Create();
    try
      LVM.LoadSource('''
        routine main() {
          let code = buffer(64, true);
          bufWriteU8(code, 0, 0xB8);
          bufWriteU32(code, 1, 42);
          bufWriteU8(code, 5, 0xC3);
          bufFlush(code);
          let result = bufCall(code, 0);
        }
        ''', 'test.lvm');
      LRoutineNode := TLVMASTNode(LVM.Environment.GetVar('main').AsRoutine());
      LVM.Environment.PushScope();
      try
        LVM.ExecBlock(TLVMASTNode(
          LRoutineNode.Children[LRoutineNode.ChildCount() - 1]));
        Check(LVM.Environment.GetVar('result').AsInt() = 42,
          'JIT: mov eax,42 + ret => 42');
      finally
        LVM.Environment.PopScope();
      end;
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('Buffer_Save', procedure
  var
    LVM: TLVM;
    LRoutineNode: TLVMASTNode;
    LPath: string;
  begin
    Section('bufSave writes buffer to file');
    LPath := TPath.Combine(TPath.GetTempPath(), '__test_buf_save__.bin');
    if TFile.Exists(LPath) then
      TFile.Delete(LPath);
    LVM := TLVM.Create();
    try
      LVM.LoadSource('''
        routine main() {
          let buf = buffer(4);
          bufWriteU32(buf, 0, 0xDEADBEEF);
          bufSave(buf, savePath);
        }
        ''', 'test.lvm');
      LRoutineNode := TLVMASTNode(LVM.Environment.GetVar('main').AsRoutine());
      LVM.Environment.PushScope();
      try
        LVM.Environment.SetVar('savePath', TLVMValue.FromString(LPath));
        LVM.ExecBlock(TLVMASTNode(
          LRoutineNode.Children[LRoutineNode.ChildCount() - 1]));
        Check(TFile.Exists(LPath), 'saved file exists');
      finally
        LVM.Environment.PopScope();
      end;
    finally
      LVM.Free();
    end;
    if TFile.Exists(LPath) then
      TFile.Delete(LPath);
  end);

  RegisterTest('POC_JIT_Hello', procedure
  var
    LVM: TLVM;
    LRoutineNode: TLVMASTNode;
  begin
    Section('POC: JIT execute machine code from LVM');
    LVM := TLVM.Create();
    try
      LVM.LoadSource('''
        routine main() {
          let code = buffer(64, true);
          bufWriteU8(code, 0, 0xB8);
          bufWriteU32(code, 1, 42);
          bufWriteU8(code, 5, 0xC3);
          bufFlush(code);
          let result = bufCall(code, 0);
          println(concat("JIT returned: ", intToStr(result)));
        }
        ''', 'poc.lvm');
      LRoutineNode := TLVMASTNode(LVM.Environment.GetVar('main').AsRoutine());
      LVM.Environment.PushScope();
      try
        LVM.ExecBlock(TLVMASTNode(
          LRoutineNode.Children[LRoutineNode.ChildCount() - 1]));
        Check(LVM.Environment.GetVar('result').AsInt() = 42,
          'JIT: mov eax,42 + ret => 42');
      finally
        LVM.Environment.PopScope();
      end;
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  //  Facade API tests
  // -----------------------------------------------------------------------

  RegisterTest('Facade_Run', procedure
  var
    LVM: TLVM;
  begin
    LVM := TLVM.Create();
    try
      LVM.LoadSource('''
        routine main() {
          let x = 42;
        }
        ''', 'test.lvm');
      LVM.Run('main');
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('Facade_Call_WithArgs', procedure
  var
    LVM: TLVM;
    LResult: TLVMValue;
  begin
    LVM := TLVM.Create();
    try
      LVM.LoadSource('''
        routine add(a: int, b: int) -> int {
          return a + b;
        }
        ''', 'test.lvm');
      LResult := LVM.Call('add', [TLVMValue.FromInt(17), TLVMValue.FromInt(25)]);
      Check(LResult.AsInt() = 42, 'Call with args returns 42');
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('Facade_Call_ReturnValue', procedure
  var
    LVM: TLVM;
    LResult: TLVMValue;
  begin
    LVM := TLVM.Create();
    try
      LVM.LoadSource('''
        routine greet(name: string) -> string {
          return concat("Hello, ", name, "!");
        }
        ''', 'test.lvm');
      LResult := LVM.Call('greet', [TLVMValue.FromString('World')]);
      Check(LResult.AsString() = 'Hello, World!', 'Call returns string');
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('Facade_SetVar', procedure
  var
    LVM: TLVM;
  begin
    LVM := TLVM.Create();
    try
      LVM.LoadSource('''
        routine double_hp() {
          hp = hp * 2;
        }
        ''', 'test.lvm');
      LVM.SetVar('hp', TLVMValue.FromInt(50));
      LVM.Run('double_hp');
      Check(LVM.GetVar('hp').AsInt() = 100, 'SetVar + Run + GetVar');
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('Facade_Eval', procedure
  var
    LVM: TLVM;
    LResult: TLVMValue;
  begin
    LVM := TLVM.Create();
    try
      LResult := LVM.Eval('2 + 3 * 4');
      Check(LResult.AsInt() = 14, 'Eval arithmetic');
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('Facade_HasRoutine', procedure
  var
    LVM: TLVM;
  begin
    LVM := TLVM.Create();
    try
      LVM.LoadSource('''
        routine onUpdate() { }
        ''', 'test.lvm');
      Check(LVM.HasRoutine('onUpdate') = True, 'HasRoutine finds routine');
      Check(LVM.HasRoutine('onDraw') = False, 'HasRoutine misses absent');
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('Facade_TryRun', procedure
  var
    LVM: TLVM;
  begin
    LVM := TLVM.Create();
    try
      LVM.LoadSource('''
        routine crasher() {
          let x = 1 / 0;
        }
        ''', 'test.lvm');
      Check(LVM.TryRun('nonexistent') = False, 'TryRun returns false on missing routine');
      Check(LVM.LastError <> '', 'LastError captured');
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('Facade_OnPrint', procedure
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
          print("hello ");
          println("world");
        }
        ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('hello'), 'OnPrint captured print');
      Check(LOutput.Contains('world'), 'OnPrint captured println');
    finally
      LVM.Free();
    end;
  end);

  // -- Step 5/6/7 tests: host objects, shared state, bufCopyBytes, float builtins --

  RegisterTest('BufCopyBytes', procedure
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
          let src = buffer(8);
          let dst = buffer(8);
          bufWriteU8(src, 0, 0xAA);
          bufWriteU8(src, 1, 0xBB);
          bufWriteU8(src, 2, 0xCC);
          bufCopyBytes(src, 0, dst, 2, 3);
          println(toString(bufReadU8(dst, 2)));
          println(toString(bufReadU8(dst, 3)));
          println(toString(bufReadU8(dst, 4)));
        }
        ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('170'), 'bufCopyBytes byte 0 = 0xAA');
      Check(LOutput.Contains('187'), 'bufCopyBytes byte 1 = 0xBB');
      Check(LOutput.Contains('204'), 'bufCopyBytes byte 2 = 0xCC');
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('BufWriteReadF32', procedure
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
          let buf = buffer(8);
          bufWriteF32(buf, 0, 3.14);
          let v = bufReadF32(buf, 0);
          println(toString(v));
        }
        ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('3.14'), 'bufWriteF32/bufReadF32 round-trip');
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('BufWriteReadF64', procedure
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
          let buf = buffer(16);
          bufWriteF64(buf, 0, 2.718281828);
          let v = bufReadF64(buf, 0);
          println(toString(v));
        }
        ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('2.718'), 'bufWriteF64/bufReadF64 round-trip');
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('HostObject', procedure
  var
    LVM: TLVM;
    LObj: TObject;
  begin
    LVM := TLVM.Create();
    try
      LObj := TObject.Create();
      try
        LVM.SetHostObject('testObj', LObj);
        Check(LVM.HasHostObject('testObj'), 'HasHostObject finds it');
        Check(not LVM.HasHostObject('nope'), 'HasHostObject misses absent');
        Check(LVM.GetHostObject('testObj') = LObj, 'GetHostObject returns same');
        Check(LVM.GetHostObject('nope') = nil, 'GetHostObject nil for absent');
      finally
        LObj.Free();
      end;
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('SharedState', procedure
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
        routine store() {
          setShared("count", 42);
          setShared("name", "test");
        }
        routine load() {
          println(toString(getShared("count")));
          println(getShared("name"));
          println(toString(hasShared("count")));
          println(toString(hasShared("nope")));
        }
        routine clear_it() {
          clearShared();
          println(toString(hasShared("count")));
        }
        ''', 'test.lvm');
      LVM.Run('store');
      LVM.Run('load');
      Check(LOutput.Contains('42'), 'getShared persists int');
      Check(LOutput.Contains('test'), 'getShared persists string');
      Check(LOutput.Contains('true'), 'hasShared true');
      LOutput := '';
      LVM.Run('clear_it');
      Check(LOutput.Contains('false'), 'clearShared clears');
    finally
      LVM.Free();
    end;
  end);

  RegisterTest('DiagCallback', procedure
  var
    LVM: TLVM;
    LCaptured: string;
  begin
    LVM := TLVM.Create();
    try
      LCaptured := '';
      LVM.SetOnDiag(
        procedure(const ASeverity: string; const AMessage: string;
          const AFile: string; const ALine: Integer; const ACol: Integer;
          const AUserData: Pointer)
        begin
          LCaptured := ASeverity + ':' + AMessage;
        end, nil);
      LVM.LoadSource('''
        routine main() {
          error "something broke";
        }
        ''', 'test.lvm');
      LVM.Run('main');
      Check(LCaptured.Contains('error'), 'diag severity captured');
      Check(LCaptured.Contains('something broke'), 'diag message captured');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test: pathChangeExt builtin
  // -----------------------------------------------------------------------
  RegisterTest('PathChangeExt', procedure
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
          let p1 = pathChangeExt("hello.exe", ".o");
          println("p1:" + p1);
          let p2 = pathChangeExt("/tmp/output.dll", ".o");
          println("p2:" + pathFile(p2));
          let p3 = pathChangeExt("noext", ".a");
          println("p3:" + p3);
        }
        ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('p1:hello.o'), 'Change .exe to .o');
      Check(LOutput.Contains('p2:output.o'), 'pathFile(pathChangeExt) extracts filename');
      Check(LOutput.Contains('p3:noext.a'), 'Add ext to extensionless');
    finally
      LVM.Free();
    end;
  end);

  // -----------------------------------------------------------------------
  // Test: unixTime builtin
  // -----------------------------------------------------------------------
  RegisterTest('UnixTime', procedure
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
          let t = unixTime();
          let ok = t > 1700000000 and t < 2000000000;
          println("ok:" + toString(ok));
          println("t:" + toString(t));
        }
        ''', 'test.lvm');
      LVM.Run('main');
      Check(LOutput.Contains('ok:true'), 'unixTime in valid range');
    finally
      LVM.Free();
    end;
  end);
end;

procedure TLVMTestCase.Run();
begin
  inherited;
end;

end.
