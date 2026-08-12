{===============================================================================
  LangVM™ - Language Virtual Machine

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://langvm.org

  See LICENSE for license information
===============================================================================}

unit UTestCase.Script;

interface

uses
  StdApp.TestCase;

type

  { TLVMLanguage }
  TLVMLanguage = class(TTestCase)
  protected
    procedure RunLVMTest(const ARelPath: string);
  end;

  { TLVMDeclarations }
  TLVMDeclarations = class(TLVMLanguage)
  protected
    procedure Run(); override;
  public
    constructor Create(); override;
  end;

  { TLVMTypes }
  TLVMTypes = class(TLVMLanguage)
  protected
    procedure Run(); override;
  public
    constructor Create(); override;
  end;

  { TLVMVariables }
  TLVMVariables = class(TLVMLanguage)
  protected
    procedure Run(); override;
  public
    constructor Create(); override;
  end;

  { TLVMRoutines }
  TLVMRoutines = class(TLVMLanguage)
  protected
    procedure Run(); override;
  public
    constructor Create(); override;
  end;

  { TLVMControlFlow }
  TLVMControlFlow = class(TLVMLanguage)
  protected
    procedure Run(); override;
  public
    constructor Create(); override;
  end;

  { TLVMExpressions }
  TLVMExpressions = class(TLVMLanguage)
  protected
    procedure Run(); override;
  public
    constructor Create(); override;
  end;

  { TLVMDataStructures }
  TLVMDataStructures = class(TLVMLanguage)
  protected
    procedure Run(); override;
  public
    constructor Create(); override;
  end;

  { TLVMErrorHandling }
  TLVMErrorHandling = class(TLVMLanguage)
  protected
    procedure Run(); override;
  public
    constructor Create(); override;
  end;

  { TLVMBuiltins }
  TLVMBuiltins = class(TLVMLanguage)
  protected
    procedure Run(); override;
  public
    constructor Create(); override;
  end;

  { TLVMMir }
  TLVMMir = class(TLVMLanguage)
  protected
    procedure Run(); override;
  public
    constructor Create(); override;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  StdApp.Base,
  StdApp.Utils,
  LangVM;

// =========================================================================
//  TLVMLanguage -- Base test runner
// =========================================================================

{ TLVMLanguage.RunLVMTest }

procedure TLVMLanguage.RunLVMTest(const ARelPath: string);
var
  LLVM: TLangVM;
  LPath: string;
begin
  LPath := TUtils.ResolvePath('$P:res\tests\lvm\' + ARelPath);

  if not TFile.Exists(LPath) then
  begin
    Check(False, Format('Test file not found: %s', [ARelPath]));
    Exit;
  end;

  LLVM := TLangVM.Create();
  try
    LLVM.LoadScriptFile(LPath);

    if not LLVM.GetErrors().HasErrors() then
      LLVM.Run('main');

    if LLVM.GetErrors().HasErrors() then
      Check(False, LLVM.GetErrors().ToString())
    else
      Check(True, 'Passed');
  finally
    LLVM.Free();
  end;
end;

// =========================================================================
//  TLVMDeclarations
// =========================================================================

{ TLVMDeclarations }

constructor TLVMDeclarations.Create();
begin
  inherited;
  Title := 'Declarations';

  RegisterTest('let_basic', procedure
  begin
    RunLVMTest('declarations/let_basic.lvm');
  end);

  RegisterTest('let_multiple', procedure
  begin
    RunLVMTest('declarations/let_multiple.lvm');
  end);

  RegisterTest('const_basic', procedure
  begin
    RunLVMTest('declarations/const_basic.lvm');
  end);

  RegisterTest('enum_basic', procedure
  begin
    RunLVMTest('declarations/enum_basic.lvm');
  end);
end;

procedure TLVMDeclarations.Run();
begin
  inherited;
end;

// =========================================================================
//  TLVMTypes
// =========================================================================

{ TLVMTypes }

constructor TLVMTypes.Create();
begin
  inherited;
  Title := 'Types';

  RegisterTest('type_int', procedure
  begin
    RunLVMTest('types/type_int.lvm');
  end);

  RegisterTest('type_float', procedure
  begin
    RunLVMTest('types/type_float.lvm');
  end);

  RegisterTest('type_string', procedure
  begin
    RunLVMTest('types/type_string.lvm');
  end);

  RegisterTest('type_bool', procedure
  begin
    RunLVMTest('types/type_bool.lvm');
  end);
end;

procedure TLVMTypes.Run();
begin
  inherited;
end;

// =========================================================================
//  TLVMVariables
// =========================================================================

{ TLVMVariables }

constructor TLVMVariables.Create();
begin
  inherited;
  Title := 'Variables';

  RegisterTest('assign_basic', procedure
  begin
    RunLVMTest('variables/assign_basic.lvm');
  end);

  RegisterTest('scope_basic', procedure
  begin
    RunLVMTest('variables/scope_basic.lvm');
  end);
end;

procedure TLVMVariables.Run();
begin
  inherited;
end;

// =========================================================================
//  TLVMRoutines
// =========================================================================

{ TLVMRoutines }

constructor TLVMRoutines.Create();
begin
  inherited;
  Title := 'Routines';

  RegisterTest('routine_basic', procedure
  begin
    RunLVMTest('routines/routine_basic.lvm');
  end);
end;

procedure TLVMRoutines.Run();
begin
  inherited;
end;

// =========================================================================
//  TLVMControlFlow
// =========================================================================

{ TLVMControlFlow }

constructor TLVMControlFlow.Create();
begin
  inherited;
  Title := 'Control Flow';

  RegisterTest('if_basic', procedure
  begin
    RunLVMTest('control_flow/if_basic.lvm');
  end);

  RegisterTest('while_basic', procedure
  begin
    RunLVMTest('control_flow/while_basic.lvm');
  end);

  RegisterTest('for_list', procedure
  begin
    RunLVMTest('control_flow/for_list.lvm');
  end);
end;

procedure TLVMControlFlow.Run();
begin
  inherited;
end;

// =========================================================================
//  TLVMExpressions
// =========================================================================

{ TLVMExpressions }

constructor TLVMExpressions.Create();
begin
  inherited;
  Title := 'Expressions';

  RegisterTest('arith_basic', procedure
  begin
    RunLVMTest('expressions/arith_basic.lvm');
  end);

  RegisterTest('compare_basic', procedure
  begin
    RunLVMTest('expressions/compare_basic.lvm');
  end);

  RegisterTest('logic_basic', procedure
  begin
    RunLVMTest('expressions/logic_basic.lvm');
  end);
end;

procedure TLVMExpressions.Run();
begin
  inherited;
end;

// =========================================================================
//  TLVMDataStructures
// =========================================================================

{ TLVMDataStructures }

constructor TLVMDataStructures.Create();
begin
  inherited;
  Title := 'Data Structures';

  RegisterTest('list_basic', procedure
  begin
    RunLVMTest('data_structures/list_basic.lvm');
  end);

  RegisterTest('map_basic', procedure
  begin
    RunLVMTest('data_structures/map_basic.lvm');
  end);
end;

procedure TLVMDataStructures.Run();
begin
  inherited;
end;

// =========================================================================
//  TLVMErrorHandling
// =========================================================================

{ TLVMErrorHandling }

constructor TLVMErrorHandling.Create();
begin
  inherited;
  Title := 'Error Handling';

  RegisterTest('try_catch_basic', procedure
  begin
    RunLVMTest('error_handling/try_catch_basic.lvm');
  end);

  RegisterTest('error_in_ferrors', procedure
  begin
    RunLVMTest('error_handling/error_in_ferrors.lvm');
  end);

  RegisterTest('try_recover_works', procedure
  begin
    RunLVMTest('error_handling/try_recover_works.lvm');
  end);

  RegisterTest('try_recover_gets_msg', procedure
  begin
    RunLVMTest('error_handling/try_recover_gets_msg.lvm');
  end);

  // Parse error test -- Delphi-side, no .lvm file needed
  RegisterTest('parse_error_in_ferrors', procedure
  var
    LLVM: TLangVM;
  begin
    LLVM := TLangVM.Create();
    try
      LLVM.LoadScript('routine broken( {', 'parse_error_test');
      Check(LLVM.GetErrors().HasErrors(), 'Parse error recorded in FErrors');
    finally
      LLVM.Free();
    end;
  end);

  RegisterTest('builtin_error_in_ferrors', procedure
  begin
    RunLVMTest('error_handling/builtin_error_in_ferrors.lvm');
  end);
end;

procedure TLVMErrorHandling.Run();
begin
  inherited;
end;

// =========================================================================
//  TLVMBuiltins
// =========================================================================

{ TLVMBuiltins }

constructor TLVMBuiltins.Create();
begin
  inherited;
  Title := 'Builtins';

  RegisterTest('builtin_len', procedure
  begin
    RunLVMTest('builtins/builtin_len.lvm');
  end);

  RegisterTest('builtin_typeof', procedure
  begin
    RunLVMTest('builtins/builtin_typeof.lvm');
  end);
end;

procedure TLVMBuiltins.Run();
begin
  inherited;
end;

// =========================================================================
//  TLVMMir
// =========================================================================

{ TLVMMir }

constructor TLVMMir.Create();
begin
  inherited;
  Title := 'MIR';

  RegisterTest('mir_parse_basic', procedure
  begin
    RunLVMTest('mir/mir_parse_basic.lvm');
  end);

  RegisterTest('mir_dispatch', procedure
  begin
    RunLVMTest('mir/mir_dispatch.lvm');
  end);
end;

procedure TLVMMir.Run();
begin
  inherited;
end;

end.
