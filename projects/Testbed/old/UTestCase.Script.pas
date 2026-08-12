unit UTestCase.Script;

interface

uses
  StdApp.TestCase;

type

  { TScriptTestCase }
  TScriptTestCase = class(TTestCase)
  protected
    procedure Run(); override;
  public
    constructor Create(); override;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  StdApp.Utils,
  StdApp.Console,
  Myrissa.LVM;

{ TScriptTestCase }

constructor TScriptTestCase.Create();
begin
  inherited;
  Title := 'Script Tests';

  // -----------------------------------------------------------------------
  // Pipeline: lexSource -> parseProgram -> runEmitters
  // -----------------------------------------------------------------------
  RegisterTest('Pipeline_SayStmt', procedure
  var
    LVM: TLVM;
    LOutput: string;
    LPath: string;
  begin
    LVM := TLVM.Create();
    try
      LOutput := '';
      LPath := TUtils.ResolvePath('$P:res\tests\lvm\pipeline.lvm');
      Section('Load and run pipeline.lvm');
      Check(TFile.Exists(LPath), 'pipeline.lvm exists');
      LVM.LoadFile(LPath);
      LVM.SetOnPrint(
        procedure(const AText: string; const AUserData: Pointer)
        begin
          LOutput := LOutput + AText;
          TConsole.Print(AText);
        end, nil);
      LVM.Run('main');
      Check(LOutput.Contains('hello'), 'emitter printed hello');
      Check(LOutput.Contains('world'), 'emitter printed world');
    finally
      LVM.Free();
    end;
  end);
end;

procedure TScriptTestCase.Run();
begin
  inherited;
end;

end.
