unit UnitMain;

interface

uses
  Windows, UnitAI;

type
  TTable = array[1..8, 1..8] of Integer;

var
  OthelloAI: TOthelloAI;

  function Think(hWnd: HWND; var Table: TTable; ThinkLevel: Integer; Chess: Integer; Step: Integer): Integer; stdcall;
  procedure StopThink; stdcall;

implementation

function Think(hWnd: HWND; var Table: TTable; ThinkLevel: Integer; Chess: Integer; Step: Integer): Integer; stdcall;
var
  i: Integer;
  j: Integer;
  TempBoard: TBoard;
begin
  try
    OthelloAI := TOthelloAI.Create;
    with OthelloAI do
    begin
      for i := 1 to 8 do
        for j := 1 to 8 do
          TempBoard[i,j] := TChess(Table[j,i]);
      Board := TempBoard; // 需要从外部传递进来
      Level := ThinkLevel;
      BoardStep := Step; // 需要从外部传递进来
      CompColor := TChess(Chess);
      if CompColor = ChessBlack then
        ManColor := ChessWhite
      else
        ManColor := ChessBlack;
      CurrentChess := CompColor; // 需要从外部传递进来
      Handle := hWnd;
      DoThink;
    end;
    Result := 0;
  except
    Result := -1;
  end;
end;

procedure StopThink;
begin
  try
    if Assigned(OthelloAI) then
      OthelloAI.Free;
  except
  end;
end;

end.
