unit UnitAI;

interface

uses
  Windows, Classes, Messages, Math;

type
  TChess = (ChessNone, ChessBlack, ChessWhite);
  TBoard = array[1..8, 1..8] of TChess;

  TEval = record //电脑分析结果
    Max: Double; //估值
    X: Integer;
    Y: Integer;
    Path: string; //估值路径
  end;

  TSearchEval = record //查找时的电脑分析结果
    Max: Double; //估值
    Path: string; //估值路径
  end;

  TBoardCountAI = record
    CompCount, ManCount, SpCount: Integer;
  end;

  TCost = array[1..8, 1..8] of Integer;

  TChangeChessResult = record
    L, R, U, D, LU, LD, RU, RD: Byte;
    Chessable: Boolean;
  end;

//  TCallBack = procedure(X,Y: Integer); stdcall;
  //TSearchRootChange = procedure(Sender: TObject; RootCount, Index: Integer) of object;

  TOthelloAI = class(TObject)
  private
    { Private declarations }
    FLast, FLast2: Boolean; //是否终局推理/是否即将终局推理
    FStep: Integer;
    FBoardStep: Integer;
    FBoard: TBoard;
    FThinkingPos: TPoint;
    //FShowSearch: Boolean;

    FDepthMax: Integer; //最大推理深度
    FBranch: Integer; //推理分支数
    FMaxPos: TPoint; //最大推理值所在位置
    FMaxValue: Double; //最大推理值
    FSavEva: array of TEval; //保存各种下法的最佳推理。
    FCost: TCost; //棋格表
    FLevel: Integer; //难度（推理深度）
    //FUseBook: Boolean; //采用定式
    //FRandomSelect: Boolean; //随机选择
    FThinking: Boolean;

//    FOnEndThink: TNotifyEvent;

    //FThinkThread: TThread;

    function RandomAI(ASideToGo: TChess; Dir: Integer = 0): TPoint;
    function GetSavEva(AIdx: Integer): TEval;
    procedure SetSavEva(AIdx: Integer; const Value: TEval);
    procedure ExecuteThread(AStartDepth: Integer);
    function ChangeChess(X, Y: Integer; Chess: TChess; Param: Integer;
      var ABoard: TBoard): TChangeChessResult;
    procedure DoEndThink(Sender: TObject);
  protected
    { Protected declarations }
    procedure SortEva;
    procedure ChangeCost;
    function GetBoardCountAI: TBoardCountAI;
    function AddValue: Integer;
    function Evaluate(AManGo: Boolean): Double; //估值
    //procedure Notification(AComponent: TComponent;
    //  Operation: TOperation); override;
  public
    { Public declarations }

    CompColor: TChess;
    ManColor: TChess;
    CurrentChess: TChess;
    Handle: HWND;

    constructor Create;
//    destructor Free;
    procedure InitCost;
    procedure DoThink;
//    procedure Stop; 
    function SavEvalCount: Integer;
    property Board: TBoard read FBoard write FBoard;
    property BoardStep: Integer read FBoardStep write FBoardStep;
    property Level: Integer read FLevel write FLevel;
    property Branch: Integer read FBranch write FBranch;
    property MaxValue: Double read FMaxValue;
    property MaxPos: TPoint read FMaxPos write FMaxPos;
    property SavEva[AIdx: Integer]: TEval read GetSavEva write SetSavEva;
    property ThinkingPos: TPoint read FThinkingPos;
    property Thinking: Boolean read FThinking;
    //property OnEndThink: TCallBack read FOnEndThink write FOnEndThink;
//  published
    { Published declarations }
    //property RandomSelect: Boolean read FRandomSelect write FRandomSelect;
    //property UseBook: Boolean read FUseBook write FUseBook;
    //property Level: Integer read FLevel write FLevel; //难度
    //property ShowSearch: Boolean read FShowSearch write FShowSearch;
    //property OthBoard: TBcOthBoard read FOthBoard write SetOthBoard;
    //property OthBook: TBcOthBook read FOthBook write SetOthBook;
    //property OnSearchBranch: TNotifyEvent read FOnSearchBranch write SetOnSearchBranch;
    //property OnSearchRootChange: TSearchRootChange read FOnSearchRootChange write FOnSearchRootChange;
    //property OnStartThink: TNotifyEvent read FOnStartThink write FOnStartThink;
    //property OnEndThink: TNotifyEvent read FOnEndThink write FOnEndThink;
  end;

  TThinkThread = class(TThread)
  private
    FStartDepth: Integer;
    FAI: TOthelloAI;
    RootCount: Integer;
    RootIndex: Integer;
//    OldSearchPos: TPoint;
//    OldMaxPos: TPoint;
//    procedure DoSearchBranch;
//    procedure DoSearchRootChange;
//    procedure DrawSearch(Sender: TObject);
//    procedure DrawCross(X, Y: Integer; AColor: TColor);

    function NegaScout(Depth: Integer; Alpha, Beta: Double;
      LastCanGo, AddFlag: Boolean): TSearchEval; //搜索函数
  protected
    procedure Execute; override;
//    procedure DoTerminate; override;
  public
    constructor Create(AStartDepth: Integer; AI: TOthelloAI);
  end;


const
//  RandomSelectDefault = True;
//  UseBookDefault = True;
  LevelDefault = 5;
  WM_THINKEND = WM_USER + $2000;

implementation

type
  TCanGoNode = record
    Value: Integer;
    X: Integer;
    Y: Integer;
  end;

const
  FreeHand = 2;

{ TOthelloAI }

procedure TOthelloAI.InitCost;
var
  i, j: Integer;
begin
  for i := 1 to 8 do
    for j := 1 to 8 do
      FCost[i, j] := -9;

  FCost[2, 2] := -100;
  FCost[2, 7] := -100;
  FCost[7, 2] := -100;
  FCost[7, 7] := -100;
  FCost[2, 1] := -5;
  FCost[1, 2] := -5;
  FCost[7, 1] := -5;
  FCost[1, 7] := -5;
  FCost[8, 2] := -5;
  FCost[2, 8] := -5;
  FCost[8, 7] := -5;
  FCost[7, 8] := -5;
  FCost[1, 1] := 200;
  FCost[8, 8] := 200;
  FCost[1, 8] := 200;
  FCost[8, 1] := 200;
  for i := 3 to 6 do
  begin
    FCost[1, i] := -5;
    FCost[i, 1] := -5;
    FCost[8, i] := -5;
    FCost[i, 8] := -5;
  end;
end;

procedure TOthelloAI.SortEva;
var
  i, j: integer;
  tempLink: TEval;
begin
  for j := Low(FSavEva) to High(FSavEva) - 1 do
    for i := Low(FSavEva) to High(FSavEva) - j - 1 do
    begin
      if SavEva[i].max <= SavEva[i + 1].max then
      begin
        tempLink.max := SavEva[i].max;
        tempLink.x := SavEva[i].x;
        tempLink.y := SavEva[i].y;
        tempLink.path := SavEva[i].path;
        FSavEva[i].max := SavEva[i + 1].max;
        FSavEva[i].x := SavEva[i + 1].x;
        FSavEva[i].y := SavEva[i + 1].y;
        FSavEva[i].path := SavEva[i + 1].path;
        FSavEva[i + 1].max := templink.max;
        FSavEva[i + 1].x := templink.x;
        FSavEva[i + 1].y := templink.y;
        FSavEva[i + 1].path := templink.path;
      end;
    end
end;

procedure TOthelloAI.DoThink;
var
  EndGameDepthMax: Integer; //终局深度
  BoardCount: TBoardCountAI;
begin
//----初始化----
  FThinking := True;
  //if Assigned(FOnStartThink) then
  //  FOnStartThink(Self);
  //FBoard := OthBoard.GetBoard;
  EndGameDepthMax := FLevel * 2 - 1;
  BoardCount := GetBoardCountAI;
  if (BoardCount.SpCount <= EndGameDepthMax) then
  begin
    FDepthMax := EndGameDepthMax;
    FLast := True;
  end
  else
  begin
    FDepthMax := FLevel;
    FLast := False;
    if BoardCount.SpCount <= EndGameDepthMax + 6 then
      FLast2 := True;
  end;
  FBranch := 0;

  FMaxPos.X := -1;
  FMaxPos.Y := -1;
  FMaxValue := -9000;

  SetLength(FSavEva, 0);
  FStep := BoardStep;

  Randomize;
  if not FLast then
    ChangeCost;

// 用于调试！
//  DoEndThink(Self);
//  exit;


//----初始化end----
  if FStep = 1 then
  begin
    FMaxValue := 0;
    FMaxPos := RandomAI(CurrentChess, Random(8));
    Branch := 0;
    DoEndThink(Self);
  end
  else
  begin
    ExecuteThread(FDepthMax);
  end;
{  else if Assigned(OthBook) then
  begin
    if UseBook then
    begin
      if not OthBook.GetBook then
        ExecuteThread(FDepthMax)
      else
      begin
        FMaxValue := 0;
        FMaxPos := OthBook.BookPos;
        Branch := 0;
        DoEndThink(Self);
      end;
    end
    else
      ExecuteThread(FDepthMax);
  end;
}
end;

function TOthelloAI.Evaluate(AManGo: Boolean): Double;
var
  i, j: integer;
  wg, bg: integer;
  vb, vw: integer;
  temp: Double;
  CR: TChangeChessResult;
  BoardCount: TBoardCountAI;
begin
  vb := 0;
  vw := 0;
  if FLast then
  begin
    BoardCount := GetBoardCountAI;
    Result := BoardCount.CompCount - BoardCount.ManCount;
    if AManGo then
      Result := -Result;
    Exit;
  end;

  wg := 0;
  bg := 0;
  ChangeCost;

  for i := 1 to 8 do
  begin
    for j := 1 to 8 do
    begin
      if (FBoard[i, j] = CompColor) then
        vb := vb + FCost[i, j];
      if (FBoard[i, j] = ManColor) then
        vw := vw + FCost[i, j];
    end;
  end;

  for i := 1 to 8 do
  begin
    for j := 1 to 8 do
    begin
      if (not ((i = 2) and (j = 2))) and (not ((i = 2) and (j = 7)))
        and (not ((i = 7) and (j = 2))) and (not ((i = 7) and (j = 7))) then
      begin
        CR := ChangeChess(i, j, CompColor, 0, FBoard);
        if CR.Chessable then
        begin
          if not FLast2 then
          begin
            if (i = 1) and (j = 2) and (FBoard[1, 1] = ChessNone) then
            begin
              if FBoard[1, 3] <> ManColor then
                Inc(bg);
            end
            else if (i = 2) and (j = 1) and (FBoard[1, 1] = ChessNone) then
            begin
              if FBoard[3, 1] <> ManColor then
                Inc(bg);
            end
            else if (i = 7) and (j = 1) and (FBoard[8, 1] = ChessNone) then
            begin
              if FBoard[6, 1] <> ManColor then
                Inc(bg);
            end
            else if (i = 1) and (j = 7) and (FBoard[1, 8] = ChessNone) then
            begin
              if FBoard[1, 6] <> ManColor then
                Inc(bg);
            end
            else if (i = 8) and (j = 2) and (FBoard[8, 1] = ChessNone) then
            begin
              if FBoard[8, 3] <> ManColor then
                Inc(bg);
            end
            else if (i = 2) and (j = 8) and (FBoard[1, 8] = ChessNone) then
            begin
              if FBoard[3, 8] <> ManColor then
                Inc(bg);
            end
            else if (i = 8) and (j = 7) and (FBoard[8, 8] = ChessNone) then
            begin
              if FBoard[8, 6] <> ManColor then
                Inc(bg);
            end
            else if (i = 7) and (j = 8) and (FBoard[8, 8] = ChessNone) then
            begin
              if FBoard[6, 8] <> ManColor then
                Inc(bg);
            end
            else
              Inc(bg);
          end
          else
            Inc(bg);
        end;
        CR := ChangeChess(i, j, ManColor, 0, FBoard);
        if CR.Chessable then
        begin
          if not FLast2 then
          begin
            if (i = 1) and (j = 2) and (FBoard[1, 1] = ChessNone) then
            begin
              if FBoard[1, 3] <> CompColor then
                Inc(wg);
            end
            else if (i = 2) and (j = 1) and (FBoard[1, 1] = ChessNone) then
            begin
              if FBoard[3, 1] <> CompColor then
                Inc(wg);
            end
            else if (i = 7) and (j = 1) and (FBoard[8, 1] = ChessNone) then
            begin
              if FBoard[6, 1] <> CompColor then
                Inc(wg);
            end
            else if (i = 1) and (j = 7) and (FBoard[1, 8] = ChessNone) then
            begin
              if FBoard[1, 6] <> CompColor then
                Inc(wg);
            end
            else if (i = 8) and (j = 2) and (FBoard[8, 1] = ChessNone) then
            begin
              if FBoard[8, 3] <> CompColor then
                Inc(wg);
            end
            else if (i = 2) and (j = 8) and (FBoard[1, 8] = ChessNone) then
            begin
              if FBoard[3, 8] <> CompColor then
                Inc(wg);
            end
            else if (i = 8) and (j = 7) and (FBoard[8, 8] = ChessNone) then
            begin
              if FBoard[8, 6] <> CompColor then
                Inc(wg);
            end
            else if (i = 7) and (j = 8) and (FBoard[8, 8] = ChessNone) then
            begin
              if FBoard[6, 8] <> CompColor then
                Inc(wg);
            end
            else
              Inc(wg);
          end
          else
            Inc(wg);
        end;
      end;
    end;
  end;
  temp := Sqrt(bg * 100) - Sqrt(wg * 100) + AddValue;
  if vb - vw >= 0 then
    Result := Sqrt(vb - vw) * 2 + temp
  else
    Result := -Sqrt(vw - vb) * 2 + temp;
  //if FRandomSelect then
  Result := Round(Result * 10) / 10;
  if AManGo then
    Result := -Result;
end;

function TOthelloAI.AddValue: Integer;
var
  Addition, i: integer;
  CR: TChangeChessResult;
 // t: cardinal;
begin
  Addition := 0;
//real FreeHand
  if FBoard[1, 1] = ChessNone then
  begin
    if (FBoard[1, 2] = ManColor) and (FBoard[2, 1] = ManColor)
      and (FBoard[2, 2] = ManColor) then
      Inc(Addition, 2 * FreeHand)
    else if (FBoard[1, 2] = CompColor) and (FBoard[2, 1] = CompColor)
      and (FBoard[2, 2] = CompColor) then
      Dec(Addition, 2 * FreeHand);
  end;
  if FBoard[8, 8] = ChessNone then
  begin
    if (FBoard[7, 8] = ManColor) and (FBoard[8, 7] = ManColor)
      and (FBoard[7, 7] = ManColor) then
      Inc(Addition, 2 * FreeHand)
    else if (FBoard[7, 8] = CompColor) and (FBoard[8, 7] = CompColor)
      and (FBoard[7, 7] = CompColor) then
      Dec(Addition, 2 * FreeHand);
  end;
  if FBoard[1, 8] = ChessNone then
  begin
    if (FBoard[1, 7] = ManColor) and (FBoard[2, 8] = ManColor) and
      (FBoard[2, 7] = ManColor) then
      Inc(Addition, 2 * FreeHand)
    else if (FBoard[1, 7] = CompColor) and (FBoard[2, 8] = CompColor)
      and (FBoard[2, 7] = CompColor) then
      Dec(Addition, 2 * FreeHand);
  end;
  if FBoard[8, 1] = ChessNone then
  begin
    if (FBoard[8, 2] = ManColor) and (FBoard[7, 1] = ManColor)
      and (FBoard[7, 2] = ManColor) then
      Inc(Addition, 2 * FreeHand)
    else if (FBoard[8, 2] = CompColor) and (FBoard[7, 1] = CompColor) and
      (FBoard[7, 2] = CompColor) then
      Dec(Addition, 2 * FreeHand);
  end;

  for i := 2 to 7 do
  begin
    if FBoard[i, 1] = ChessNone then
    begin
      if (FBoard[i - 1, 1] = ManColor) and (FBoard[i + 1, 1] = ManColor)
        and (FBoard[i, 2] = ManColor) and (FBoard[i - 1, 2] = ManColor)
        and (FBoard[i + 1, 2] = ManColor) then
        Inc(Addition, 2 * FreeHand)
      else if (FBoard[i - 1, 1] = CompColor) and (FBoard[i + 1, 1] = CompColor)
        and (FBoard[i, 2] = CompColor) and (FBoard[i - 1, 2] = CompColor)
        and (FBoard[i + 1, 2] = CompColor) then
        Dec(Addition, 2 * FreeHand);
    end;
  end;
  for i := 2 to 7 do
  begin
    if FBoard[i, 8] = ChessNone then
    begin
      if (FBoard[i - 1, 8] = ManColor) and (FBoard[i + 1, 8] = ManColor) and
        (FBoard[i, 7] = ManColor) and (FBoard[i - 1, 7] = ManColor) and
        (FBoard[i + 1, 7] = ManColor) then
        Inc(Addition, 2 * FreeHand)
      else if (FBoard[i - 1, 8] = CompColor) and (FBoard[i + 1, 8] = CompColor) and
        (FBoard[i, 7] = CompColor) and (FBoard[i - 1, 7] = CompColor) and
        (FBoard[i + 1, 7] = CompColor) then
        Dec(Addition, 2 * FreeHand);
    end;
  end;
  for i := 2 to 7 do
  begin
    if FBoard[1, i] = ChessNone then
    begin
      if (FBoard[1, i - 1] = ManColor) and (FBoard[1, i + 1] = ManColor) and
        (FBoard[2, i] = ManColor) and (FBoard[2, i - 1] = ManColor) and
        (FBoard[2, i + 1] = ManColor) then
        Inc(Addition, 2 * FreeHand)
      else if (FBoard[1, i - 1] = CompColor) and (FBoard[1, i + 1] = CompColor) and
        (FBoard[2, i] = CompColor) and (FBoard[2, i - 1] = CompColor) and
        (FBoard[2, i + 1] = CompColor) then
        Dec(Addition, 2 * FreeHand);
    end;
  end;
  for i := 2 to 7 do
  begin
    if FBoard[8, i] = ChessNone then
    begin
      if (FBoard[8, i - 1] = ManColor) and (FBoard[8, i + 1] = ManColor) and
        (FBoard[7, i] = ManColor) and (FBoard[7, i - 1] = ManColor) and
        (FBoard[7, i + 1] = ManColor) then
        Inc(Addition, 2 * FreeHand)
      else if (FBoard[8, i - 1] = CompColor) and (FBoard[8, i + 1] = CompColor) and
        (FBoard[7, i] = CompColor) and (FBoard[7, i - 1] = CompColor) and
        (FBoard[7, i + 1] = CompColor) then
        Dec(Addition, 2 * FreeHand);
    end;
  end;


//--oxxo--
  if (FBoard[1, 1] = ChessNone) and (FBoard[2, 1] = ChessNone) and
    (FBoard[3, 1] = CompColor) and (FBoard[4, 1] = ManColor) and
    (FBoard[5, 1] = ManColor) and (FBoard[6, 1] = CompColor) and
    (FBoard[7, 1] = ChessNone) and (FBoard[8, 1] = ChessNone) then
    Dec(Addition, 2 * FreeHand);
  if (FBoard[1, 8] = ChessNone) and (FBoard[2, 8] = ChessNone) and
    (FBoard[3, 8] = CompColor) and (FBoard[4, 8] = ManColor) and
    (FBoard[5, 8] = ManColor) and (FBoard[6, 8] = CompColor) and
    (FBoard[7, 8] = ChessNone) and (FBoard[8, 8] = ChessNone) then
    Dec(Addition, 2 * FreeHand);
  if (FBoard[1, 1] = ChessNone) and (FBoard[1, 2] = ChessNone) and
    (FBoard[1, 3] = CompColor) and (FBoard[1, 4] = ManColor) and
    (FBoard[1, 5] = ManColor) and (FBoard[1, 6] = CompColor) and
    (FBoard[1, 7] = ChessNone) and (FBoard[1, 8] = ChessNone) then
    Dec(Addition, 2 * FreeHand);
  if (FBoard[8, 1] = ChessNone) and (FBoard[8, 2] = ChessNone) and
    (FBoard[8, 3] = CompColor) and (FBoard[8, 4] = ManColor) and
    (FBoard[8, 5] = ManColor) and (FBoard[8, 6] = CompColor) and
    (FBoard[8, 7] = ChessNone) and (FBoard[8, 8] = ChessNone) then
    Dec(Addition, 2 * FreeHand);
  if (FBoard[1, 1] = ChessNone) and (FBoard[2, 1] = ChessNone) and
    (FBoard[3, 1] = ManColor) and (FBoard[4, 1] = CompColor) and
    (FBoard[5, 1] = CompColor) and (FBoard[6, 1] = ManColor) and
    (FBoard[7, 1] = ChessNone) and (FBoard[8, 1] = ChessNone) then
    Inc(Addition, 2 * FreeHand);
  if (FBoard[1, 8] = ChessNone) and (FBoard[2, 8] = ChessNone) and
    (FBoard[3, 8] = ManColor) and (FBoard[4, 8] = CompColor) and
    (FBoard[5, 8] = CompColor) and (FBoard[6, 8] = ManColor) and
    (FBoard[7, 8] = ChessNone) and (FBoard[8, 8] = ChessNone) then
    Inc(Addition, 2 * FreeHand);
  if (FBoard[1, 1] = ChessNone) and (FBoard[1, 2] = ChessNone) and
    (FBoard[1, 3] = ManColor) and (FBoard[1, 4] = CompColor) and
    (FBoard[1, 5] = CompColor) and (FBoard[1, 6] = ManColor) and
    (FBoard[1, 7] = ChessNone) and (FBoard[1, 8] = ChessNone) then
    Inc(Addition, 2 * FreeHand);
  if (FBoard[8, 1] = ChessNone) and (FBoard[8, 2] = ChessNone) and
    (FBoard[8, 3] = ManColor) and (FBoard[8, 4] = CompColor) and
    (FBoard[8, 5] = CompColor) and (FBoard[8, 6] = ManColor) and
    (FBoard[8, 7] = ChessNone) and (FBoard[8, 8] = ChessNone) then
    Inc(Addition, 2 * FreeHand);

//-oooooo-
  if (FBoard[2, 1] = CompColor) and (FBoard[3, 1] = CompColor) and
    (FBoard[4, 1] = CompColor) and (FBoard[5, 1] = CompColor) and
    (FBoard[6, 1] = CompColor) and (FBoard[7, 1] = CompColor) then
    Inc(Addition, 2 * FreeHand);
  if (FBoard[2, 8] = CompColor) and (FBoard[3, 8] = CompColor) and
    (FBoard[4, 8] = CompColor) and (FBoard[5, 8] = CompColor) and
    (FBoard[6, 8] = CompColor) and (FBoard[7, 8] = CompColor) then
    Inc(Addition, 2 * FreeHand);
  if (FBoard[1, 2] = CompColor) and (FBoard[1, 3] = CompColor) and
    (FBoard[1, 4] = CompColor) and (FBoard[1, 5] = CompColor) and
    (FBoard[1, 6] = CompColor) and (FBoard[1, 7] = CompColor) then
    Inc(Addition, 2 * FreeHand);
  if (FBoard[8, 2] = CompColor) and (FBoard[8, 3] = CompColor) and
    (FBoard[8, 4] = CompColor) and (FBoard[8, 5] = CompColor) and
    (FBoard[8, 6] = CompColor) and (FBoard[8, 7] = CompColor) then
    Inc(Addition, 2 * FreeHand);
  if (FBoard[2, 1] = ManColor) and (FBoard[3, 1] = ManColor) and
    (FBoard[4, 1] = ManColor) and (FBoard[5, 1] = ManColor) and
    (FBoard[6, 1] = ManColor) and (FBoard[7, 1] = ManColor) then
    Dec(Addition, 2 * FreeHand);
  if (FBoard[2, 8] = ManColor) and (FBoard[3, 8] = ManColor) and
    (FBoard[4, 8] = ManColor) and (FBoard[5, 8] = ManColor) and
    (FBoard[6, 8] = ManColor) and (FBoard[7, 8] = ManColor) then
    Dec(Addition, 2 * FreeHand);
  if (FBoard[1, 2] = ManColor) and (FBoard[1, 3] = ManColor) and
    (FBoard[1, 4] = ManColor) and (FBoard[1, 5] = ManColor) and
    (FBoard[1, 6] = ManColor) and (FBoard[1, 7] = ManColor) then
    Dec(Addition, 2 * FreeHand);
  if (FBoard[8, 2] = ManColor) and (FBoard[8, 3] = ManColor) and
    (FBoard[8, 4] = ManColor) and (FBoard[8, 5] = ManColor) and
    (FBoard[8, 6] = ManColor) and (FBoard[8, 7] = ManColor) then
    Dec(Addition, 2 * FreeHand);
//o-ooooo-
//????????
  if (FBoard[1, 1] = CompColor) and (FBoard[2, 1] = ChessNone) and
    (FBoard[3, 1] = CompColor) and (FBoard[4, 1] = CompColor) and
    (FBoard[5, 1] = CompColor) and (FBoard[6, 1] = CompColor) and
    (FBoard[7, 1] = CompColor) and ((FBoard[2, 2] <> ManColor) or
    (FBoard[3, 2] <> ManColor)) then
    Dec(Addition, 3 * FreeHand);
  if (FBoard[8, 1] = CompColor) and (FBoard[7, 1] = ChessNone) and
    (FBoard[6, 1] = CompColor) and (FBoard[5, 1] = CompColor) and
    (FBoard[4, 1] = CompColor) and (FBoard[3, 1] = CompColor) and
    (FBoard[2, 1] = CompColor) and ((FBoard[7, 2] <> ManColor) or
    (FBoard[6, 2] <> ManColor)) then
    Dec(Addition, 3 * FreeHand);
  if (FBoard[1, 1] = CompColor) and (FBoard[1, 2] = ChessNone) and
    (FBoard[1, 3] = CompColor) and (FBoard[1, 4] = CompColor) and
    (FBoard[1, 5] = CompColor) and (FBoard[1, 6] = CompColor) and
    (FBoard[1, 7] = CompColor) and ((FBoard[2, 2] <> ManColor) or
    (FBoard[2, 3] <> ManColor)) then
    Dec(Addition, 3 * FreeHand);
  if (FBoard[1, 8] = CompColor) and (FBoard[1, 7] = ChessNone) and
    (FBoard[1, 6] = CompColor) and (FBoard[1, 5] = CompColor) and
    (FBoard[1, 4] = CompColor) and (FBoard[1, 3] = CompColor) and
    (FBoard[1, 2] = CompColor) and ((FBoard[2, 7] <> ManColor) or
    (FBoard[2, 6] <> ManColor)) then
    Dec(Addition, 3 * FreeHand);
  if (FBoard[1, 8] = CompColor) and (FBoard[2, 8] = ChessNone) and
    (FBoard[3, 8] = CompColor) and (FBoard[4, 8] = CompColor) and
    (FBoard[5, 8] = CompColor) and (FBoard[6, 8] = CompColor) and
    (FBoard[7, 8] = CompColor) and ((FBoard[2, 7] <> ManColor) or
    (FBoard[3, 7] <> ManColor)) then
    Dec(Addition, 3 * FreeHand);
  if (FBoard[8, 8] = CompColor) and (FBoard[7, 8] = ChessNone) and
    (FBoard[6, 8] = CompColor) and (FBoard[5, 8] = CompColor) and
    (FBoard[4, 8] = CompColor) and (FBoard[3, 8] = CompColor) and
    (FBoard[2, 8] = CompColor) and ((FBoard[7, 7] <> ManColor) or
    (FBoard[6, 7] <> ManColor)) then
    Dec(Addition, 3 * FreeHand);
  if (FBoard[8, 1] = CompColor) and (FBoard[8, 2] = ChessNone) and
    (FBoard[8, 3] = CompColor) and (FBoard[8, 4] = CompColor) and
    (FBoard[8, 5] = CompColor) and (FBoard[8, 6] = CompColor) and
    (FBoard[8, 7] = CompColor) and ((FBoard[7, 2] <> ManColor) or
    (FBoard[7, 3] <> ManColor)) then
    Dec(Addition, 3 * FreeHand);
  if (FBoard[8, 8] = CompColor) and (FBoard[8, 7] = ChessNone) and
    (FBoard[8, 6] = CompColor) and (FBoard[8, 5] = CompColor) and
    (FBoard[8, 4] = CompColor) and (FBoard[8, 3] = CompColor) and
    (FBoard[8, 2] = CompColor) and ((FBoard[7, 7] <> ManColor) or
    (FBoard[7, 6] <> ManColor)) then
    Dec(Addition, 3 * FreeHand);

  if (FBoard[1, 1] = ManColor) and (FBoard[2, 1] = ChessNone) and
    (FBoard[3, 1] = ManColor) and (FBoard[4, 1] = ManColor) and
    (FBoard[5, 1] = ManColor) and (FBoard[6, 1] = ManColor) and
    (FBoard[7, 1] = ManColor) and ((FBoard[2, 2] <> ManColor) or
    (FBoard[3, 2] <> ManColor)) then
    Inc(Addition, 3 * FreeHand);
  if (FBoard[8, 1] = ManColor) and (FBoard[7, 1] = ChessNone) and
    (FBoard[6, 1] = ManColor) and (FBoard[5, 1] = ManColor) and
    (FBoard[4, 1] = ManColor) and (FBoard[3, 1] = ManColor) and
    (FBoard[2, 1] = ManColor) and ((FBoard[7, 2] <> ManColor) or
    (FBoard[6, 2] <> ManColor)) then
    Inc(Addition, 3 * FreeHand);
  if (FBoard[1, 1] = ManColor) and (FBoard[1, 2] = ChessNone) and
    (FBoard[1, 3] = ManColor) and (FBoard[1, 4] = ManColor) and
    (FBoard[1, 5] = ManColor) and (FBoard[1, 6] = ManColor) and
    (FBoard[1, 7] = ManColor) and ((FBoard[2, 2] <> ManColor) or
    (FBoard[2, 3] <> ManColor)) then
    Inc(Addition, 3 * FreeHand);
  if (FBoard[1, 8] = ManColor) and (FBoard[1, 7] = ChessNone) and
    (FBoard[1, 6] = ManColor) and (FBoard[1, 5] = ManColor) and
    (FBoard[1, 4] = ManColor) and (FBoard[1, 3] = ManColor) and
    (FBoard[1, 2] = ManColor) and ((FBoard[2, 7] <> ManColor) or
    (FBoard[2, 6] <> ManColor)) then
    Inc(Addition, 3 * FreeHand);
  if (FBoard[1, 8] = ManColor) and (FBoard[2, 8] = ChessNone) and
    (FBoard[3, 8] = ManColor) and (FBoard[4, 8] = ManColor) and
    (FBoard[5, 8] = ManColor) and (FBoard[6, 8] = ManColor) and
    (FBoard[7, 8] = ManColor) and ((FBoard[2, 7] <> ManColor) or
    (FBoard[3, 7] <> ManColor)) then
    Inc(Addition, 3 * FreeHand);
  if (FBoard[8, 8] = ManColor) and (FBoard[7, 8] = ChessNone) and
    (FBoard[6, 8] = ManColor) and (FBoard[5, 8] = ManColor) and
    (FBoard[4, 8] = ManColor) and (FBoard[3, 8] = ManColor) and
    (FBoard[2, 8] = ManColor) and ((FBoard[7, 7] <> ManColor) or
    (FBoard[6, 7] <> ManColor)) then
    Inc(Addition, 3 * FreeHand);
  if (FBoard[8, 1] = ManColor) and (FBoard[8, 2] = ChessNone) and
    (FBoard[8, 3] = ManColor) and (FBoard[8, 4] = ManColor) and
    (FBoard[8, 5] = ManColor) and (FBoard[8, 6] = ManColor) and
    (FBoard[8, 7] = ManColor) and ((FBoard[7, 2] <> ManColor) or
    (FBoard[7, 3] <> ManColor)) then
    Inc(Addition, 3 * FreeHand);
  if (FBoard[8, 8] = ManColor) and (FBoard[8, 7] = ChessNone) and
    (FBoard[8, 6] = ManColor) and (FBoard[8, 5] = ManColor) and
    (FBoard[8, 4] = ManColor) and (FBoard[8, 3] = ManColor) and
    (FBoard[8, 2] = ManColor) and ((FBoard[7, 7] <> ManColor) or
    (FBoard[7, 6] <> ManColor)) then
    Inc(Addition, 3 * FreeHand);

//-o------
  if (FBoard[1, 1] = ChessNone) and (FBoard[2, 1] = ManColor) and
    (FBoard[3, 1] = ChessNone) and ((FBoard[4, 1] = ChessNone) or
    (FBoard[4, 1] = CompColor)) and (FBoard[5, 1] = ChessNone) and
    (FBoard[7, 1] = ChessNone) and (FBoard[8, 1] = ChessNone) then
    Inc(Addition, 5 * FreeHand);
  if (FBoard[1, 1] = ChessNone) and (FBoard[2, 1] = ChessNone) and
    (FBoard[4, 1] = ChessNone) and ((FBoard[5, 1] = ChessNone) or
    (FBoard[5, 1] = CompColor)) and (FBoard[6, 1] = ChessNone) and
    (FBoard[7, 1] = ManColor) and (FBoard[8, 1] = ChessNone) then
    Inc(Addition, 5 * FreeHand);
  if (FBoard[1, 8] = ChessNone) and (FBoard[2, 8] = ManColor) and
    (FBoard[3, 8] = ChessNone) and ((FBoard[4, 8] = ChessNone) or
    (FBoard[4, 8] = CompColor)) and (FBoard[5, 8] = ChessNone) and
    (FBoard[7, 8] = ChessNone) and (FBoard[8, 8] = ChessNone) then
    Inc(Addition, 5 * FreeHand);
  if (FBoard[1, 8] = ChessNone) and (FBoard[2, 8] = ChessNone) and
    (FBoard[4, 8] = ChessNone) and ((FBoard[5, 8] = ChessNone) or
    (FBoard[5, 8] = CompColor)) and (FBoard[6, 8] = ChessNone) and
    (FBoard[7, 8] = ManColor) and (FBoard[8, 8] = ChessNone) then
    Inc(Addition, 5 * FreeHand);
  if (FBoard[1, 1] = ChessNone) and (FBoard[1, 2] = ManColor) and
    (FBoard[1, 3] = ChessNone) and ((FBoard[1, 4] = ChessNone) or
    (FBoard[1, 4] = CompColor)) and (FBoard[1, 5] = ChessNone) and
    (FBoard[1, 7] = ChessNone) and (FBoard[1, 8] = ChessNone) then
    Inc(Addition, 5 * FreeHand);
  if (FBoard[1, 1] = ChessNone) and (FBoard[1, 2] = ChessNone) and
    (FBoard[1, 4] = ChessNone) and ((FBoard[1, 5] = ChessNone) or
    (FBoard[1, 5] = CompColor)) and (FBoard[1, 6] = ChessNone) and
    (FBoard[1, 7] = ManColor) and (FBoard[1, 8] = ChessNone) then
    Inc(Addition, 5 * FreeHand);
  if (FBoard[8, 1] = ChessNone) and (FBoard[8, 2] = ManColor) and
    (FBoard[8, 3] = ChessNone) and ((FBoard[8, 4] = ChessNone) or
    (FBoard[8, 4] = CompColor)) and (FBoard[8, 5] = ChessNone) and
    (FBoard[8, 7] = ChessNone) and (FBoard[8, 8] = ChessNone) then
    Inc(Addition, 5 * FreeHand);
  if (FBoard[8, 1] = ChessNone) and (FBoard[8, 2] = ChessNone) and
    (FBoard[8, 4] = ChessNone) and ((FBoard[8, 5] = ChessNone) or
    (FBoard[8, 5] = CompColor)) and (FBoard[8, 6] = ChessNone) and
    (FBoard[8, 7] = ManColor) and (FBoard[8, 8] = ChessNone) then
    Inc(Addition, 5 * FreeHand);

  if (FBoard[1, 1] = ChessNone) and (FBoard[2, 1] = CompColor) and
    (FBoard[3, 1] = ChessNone) and ((FBoard[4, 1] = ChessNone) or
    (FBoard[4, 1] = ManColor)) and (FBoard[5, 1] = ChessNone) and
    (FBoard[7, 1] = ChessNone) and (FBoard[8, 1] = ChessNone) then
    Dec(Addition, 5 * FreeHand);
  if (FBoard[1, 1] = ChessNone) and (FBoard[2, 1] = ChessNone) and
    (FBoard[4, 1] = ChessNone) and ((FBoard[5, 1] = ChessNone) or
    (FBoard[5, 1] = ManColor)) and (FBoard[6, 1] = ChessNone) and
    (FBoard[7, 1] = CompColor) and (FBoard[8, 1] = ChessNone) then
    Dec(Addition, 5 * FreeHand);
  if (FBoard[1, 8] = ChessNone) and (FBoard[2, 8] = CompColor) and
    (FBoard[3, 8] = ChessNone) and ((FBoard[4, 8] = ChessNone) or
    (FBoard[4, 8] = ManColor)) and (FBoard[5, 8] = ChessNone) and
    (FBoard[7, 8] = ChessNone) and (FBoard[8, 8] = ChessNone) then
    Dec(Addition, 5 * FreeHand);
  if (FBoard[1, 8] = ChessNone) and (FBoard[2, 8] = ChessNone) and
    (FBoard[4, 8] = ChessNone) and ((FBoard[5, 8] = ChessNone) or
    (FBoard[5, 8] = ManColor)) and (FBoard[6, 8] = ChessNone) and
    (FBoard[7, 8] = CompColor) and (FBoard[8, 8] = ChessNone) then
    Dec(Addition, 5 * FreeHand);
  if (FBoard[1, 1] = ChessNone) and (FBoard[1, 2] = CompColor) and
    (FBoard[1, 3] = ChessNone) and ((FBoard[1, 4] = ChessNone) or
    (FBoard[1, 4] = ManColor)) and (FBoard[1, 5] = ChessNone) and
    (FBoard[1, 7] = ChessNone) and (FBoard[1, 8] = ChessNone) then
    Dec(Addition, 5 * FreeHand);
  if (FBoard[1, 1] = ChessNone) and (FBoard[1, 2] = ChessNone) and
    (FBoard[1, 4] = ChessNone) and ((FBoard[1, 5] = ChessNone) or
    (FBoard[1, 5] = ManColor)) and (FBoard[1, 6] = ChessNone) and
    (FBoard[1, 7] = CompColor) and (FBoard[1, 8] = ChessNone) then
    Dec(Addition, 5 * FreeHand);
  if (FBoard[8, 1] = ChessNone) and (FBoard[8, 2] = CompColor) and
    (FBoard[8, 3] = ChessNone) and ((FBoard[8, 4] = ChessNone) or
    (FBoard[8, 4] = ManColor)) and (FBoard[8, 5] = ChessNone) and
    (FBoard[8, 7] = ChessNone) and (FBoard[8, 8] = ChessNone) then
    Dec(Addition, 5 * FreeHand);
  if (FBoard[8, 1] = ChessNone) and (FBoard[8, 2] = ChessNone) and
    (FBoard[8, 4] = ChessNone) and ((FBoard[8, 5] = ChessNone) or
    (FBoard[8, 5] = ManColor)) and (FBoard[8, 6] = ChessNone) and
    (FBoard[8, 7] = CompColor) and (FBoard[8, 8] = ChessNone) then
    Dec(Addition, 5 * FreeHand);


//---o
//--oo
  if (FBoard[4, 1] = ManColor) and (FBoard[4, 2] = ManColor) and
    (FBoard[3, 2] = ManColor) and (FBoard[3, 1] = ChessNone) and
    (FBoard[2, 1] = ChessNone) and (FBoard[1, 1] = ChessNone) then
    Inc(Addition, FreeHand);
  if (FBoard[5, 1] = ManColor) and (FBoard[5, 2] = ManColor) and
    (FBoard[6, 2] = ManColor) and (FBoard[6, 1] = ChessNone) and
    (FBoard[7, 1] = ChessNone) and (FBoard[8, 1] = ChessNone) then
    Inc(Addition, FreeHand);
  if (FBoard[1, 4] = ManColor) and (FBoard[2, 4] = ManColor) and
    (FBoard[2, 3] = ManColor) and (FBoard[1, 3] = ChessNone) and
    (FBoard[1, 2] = ChessNone) and (FBoard[1, 1] = ChessNone) then
    Inc(Addition, FreeHand);
  if (FBoard[1, 5] = ManColor) and (FBoard[2, 5] = ManColor) and
    (FBoard[2, 6] = ManColor) and (FBoard[1, 6] = ChessNone) and
    (FBoard[1, 7] = ChessNone) and (FBoard[1, 8] = ChessNone) then
    Inc(Addition, FreeHand);
  if (FBoard[4, 8] = ManColor) and (FBoard[4, 7] = ManColor) and
    (FBoard[3, 7] = ManColor) and (FBoard[3, 8] = ChessNone) and
    (FBoard[2, 8] = ChessNone) and (FBoard[1, 8] = ChessNone) then
    Inc(Addition, FreeHand);
  if (FBoard[5, 8] = ManColor) and (FBoard[5, 7] = ManColor) and
    (FBoard[6, 7] = ManColor) and (FBoard[6, 8] = ChessNone) and
    (FBoard[7, 8] = ChessNone) and (FBoard[8, 8] = ChessNone) then
    Inc(Addition, FreeHand);
  if (FBoard[8, 4] = ManColor) and (FBoard[7, 4] = ManColor) and
    (FBoard[7, 3] = ManColor) and (FBoard[8, 3] = ChessNone) and
    (FBoard[8, 2] = ChessNone) and (FBoard[8, 1] = ChessNone) then
    Inc(Addition, FreeHand);
  if (FBoard[8, 5] = ManColor) and (FBoard[7, 5] = ManColor) and
    (FBoard[7, 6] = ManColor) and (FBoard[8, 6] = ChessNone) and
    (FBoard[8, 7] = ChessNone) and (FBoard[8, 8] = ChessNone) then
    Inc(Addition, FreeHand);

  if (FBoard[4, 1] = CompColor) and (FBoard[4, 2] = CompColor) and
    (FBoard[3, 2] = CompColor) and (FBoard[3, 1] = ChessNone) and
    (FBoard[2, 1] = ChessNone) and (FBoard[1, 1] = ChessNone) then
    Dec(Addition, FreeHand);
  if (FBoard[5, 1] = CompColor) and (FBoard[5, 2] = CompColor) and
    (FBoard[6, 2] = CompColor) and (FBoard[6, 1] = ChessNone) and
    (FBoard[7, 1] = ChessNone) and (FBoard[8, 1] = ChessNone) then
    Dec(Addition, FreeHand);
  if (FBoard[1, 4] = CompColor) and (FBoard[2, 4] = CompColor) and
    (FBoard[2, 3] = CompColor) and (FBoard[1, 3] = ChessNone) and
    (FBoard[1, 2] = ChessNone) and (FBoard[1, 1] = ChessNone) then
    Dec(Addition, FreeHand);
  if (FBoard[1, 5] = CompColor) and (FBoard[2, 5] = CompColor) and
    (FBoard[2, 6] = CompColor) and (FBoard[1, 6] = ChessNone) and
    (FBoard[1, 7] = ChessNone) and (FBoard[1, 8] = ChessNone) then
    Dec(Addition, FreeHand);
  if (FBoard[4, 8] = CompColor) and (FBoard[4, 7] = CompColor) and
    (FBoard[3, 7] = CompColor) and (FBoard[3, 8] = ChessNone) and
    (FBoard[2, 8] = ChessNone) and (FBoard[1, 8] = ChessNone) then
    Dec(Addition, FreeHand);
  if (FBoard[5, 8] = CompColor) and (FBoard[5, 7] = CompColor) and
    (FBoard[6, 7] = CompColor) and (FBoard[6, 8] = ChessNone) and
    (FBoard[7, 8] = ChessNone) and (FBoard[8, 8] = ChessNone) then
    Dec(Addition, FreeHand);
  if (FBoard[8, 4] = CompColor) and (FBoard[7, 4] = CompColor) and
    (FBoard[7, 3] = CompColor) and (FBoard[8, 3] = ChessNone) and
    (FBoard[8, 2] = ChessNone) and (FBoard[8, 1] = ChessNone) then
    Dec(Addition, FreeHand);
  if (FBoard[8, 5] = CompColor) and (FBoard[7, 5] = CompColor) and
    (FBoard[7, 6] = CompColor) and (FBoard[8, 6] = ChessNone) and
    (FBoard[8, 7] = ChessNone) and (FBoard[8, 8] = ChessNone) then
    Dec(Addition, FreeHand);
//--o
//?-x
  if (FBoard[1, 1] = ChessNone) and (FBoard[2, 1] = ChessNone) and
    (FBoard[3, 1] = CompColor) and (FBoard[2, 2] = ChessNone) and
    (FBoard[3, 2] = ManColor) then
    Inc(Addition, FreeHand);
  if (FBoard[8, 1] = ChessNone) and (FBoard[7, 1] = ChessNone) and
    (FBoard[6, 1] = CompColor) and (FBoard[7, 2] = ChessNone) and
    (FBoard[6, 2] = ManColor) then
    Inc(Addition, FreeHand);
  if (FBoard[1, 1] = ChessNone) and (FBoard[1, 2] = ChessNone) and
    (FBoard[1, 3] = CompColor) and (FBoard[2, 2] = ChessNone) and
    (FBoard[2, 3] = ManColor) then
    Inc(Addition, FreeHand);
  if (FBoard[1, 8] = ChessNone) and (FBoard[1, 7] = ChessNone) and
    (FBoard[1, 6] = CompColor) and (FBoard[2, 7] = ChessNone) and
    (FBoard[2, 6] = ManColor) then
    Inc(Addition, FreeHand);
  if (FBoard[1, 8] = ChessNone) and (FBoard[2, 8] = ChessNone) and
    (FBoard[3, 8] = CompColor) and (FBoard[2, 7] = ChessNone) and
    (FBoard[3, 7] = ManColor) then
    Inc(Addition, FreeHand);
  if (FBoard[8, 8] = ChessNone) and (FBoard[7, 8] = ChessNone) and
    (FBoard[6, 8] = CompColor) and (FBoard[7, 7] = ChessNone) and
    (FBoard[6, 7] = ManColor) then
    Inc(Addition, FreeHand);
  if (FBoard[8, 1] = ChessNone) and (FBoard[8, 2] = ChessNone) and
    (FBoard[8, 3] = CompColor) and (FBoard[7, 2] = ChessNone) and
    (FBoard[7, 3] = ManColor) then
    Inc(Addition, FreeHand);
  if (FBoard[8, 8] = ChessNone) and (FBoard[8, 7] = ChessNone) and
    (FBoard[8, 6] = CompColor) and (FBoard[7, 7] = ChessNone) and
    (FBoard[7, 6] = ManColor) then
    Inc(Addition, FreeHand);

  if (FBoard[1, 1] = ChessNone) and (FBoard[2, 1] = ChessNone) and
    (FBoard[3, 1] = ManColor) and (FBoard[2, 2] = ChessNone) and
    (FBoard[3, 2] = CompColor) then
    Dec(Addition, FreeHand);
  if (FBoard[8, 1] = ChessNone) and (FBoard[7, 1] = ChessNone) and
    (FBoard[6, 1] = ManColor) and (FBoard[7, 2] = ChessNone) and
    (FBoard[6, 2] = CompColor) then
    Dec(Addition, FreeHand);
  if (FBoard[1, 1] = ChessNone) and (FBoard[1, 2] = ChessNone) and
    (FBoard[1, 3] = ManColor) and (FBoard[2, 2] = ChessNone) and
    (FBoard[2, 3] = CompColor) then
    Dec(Addition, FreeHand);
  if (FBoard[1, 8] = ChessNone) and (FBoard[1, 7] = ChessNone) and
    (FBoard[1, 6] = ManColor) and (FBoard[2, 7] = ChessNone) and
    (FBoard[2, 6] = CompColor) then
    Dec(Addition, FreeHand);
  if (FBoard[1, 8] = ChessNone) and (FBoard[2, 8] = ChessNone) and
    (FBoard[3, 8] = ManColor) and (FBoard[2, 7] = ChessNone) and
    (FBoard[3, 7] = CompColor) then
    Dec(Addition, FreeHand);
  if (FBoard[8, 8] = ChessNone) and (FBoard[7, 8] = ChessNone) and
    (FBoard[6, 8] = ManColor) and (FBoard[7, 7] = ChessNone) and
    (FBoard[6, 7] = CompColor) then
    Dec(Addition, FreeHand);
  if (FBoard[8, 1] = ChessNone) and (FBoard[8, 2] = ChessNone) and
    (FBoard[8, 3] = ManColor) and (FBoard[7, 2] = ChessNone) and
    (FBoard[7, 3] = CompColor) then
    Dec(Addition, FreeHand);
  if (FBoard[8, 8] = ChessNone) and (FBoard[8, 7] = ChessNone) and
    (FBoard[8, 6] = ManColor) and (FBoard[7, 7] = ChessNone) and
    (FBoard[7, 6] = CompColor) then
    Dec(Addition, FreeHand);


  if (FBoard[1, 1] = CompColor) and (FBoard[1, 2] = ChessNone) and
    (FBoard[2, 1] = ChessNone) then
  begin
    CR := ChangeChess(1, 2, CompColor, 0, FBoard);
    if not CR.Chessable then
    begin
      CR := ChangeChess(2, 1, CompColor, 0, FBoard);
      if not CR.Chessable then
        Dec(Addition, round(sqrt(FCost[1, 1])) * 3 div 5);
    end;
  end;
  if (FBoard[1, 8] = CompColor) and (FBoard[1, 7] = ChessNone) and
    (FBoard[2, 8] = ChessNone) then
  begin
    CR := ChangeChess(1, 7, CompColor, 0, FBoard);
    if not CR.Chessable then
    begin
      CR := ChangeChess(2, 8, CompColor, 0, FBoard);
      if not CR.Chessable then
        Dec(Addition, round(sqrt(FCost[1, 8])) * 3 div 5);
    end;
  end;
  if (FBoard[8, 1] = CompColor) and (FBoard[7, 1] = ChessNone) and
    (FBoard[8, 2] = ChessNone) then
  begin
    CR := ChangeChess(8, 2, CompColor, 0, FBoard);
    if not CR.Chessable then
    begin
      CR := ChangeChess(7, 1, CompColor, 0, FBoard);
      if not CR.Chessable then
        Dec(Addition, round(sqrt(FCost[8, 1])) * 3 div 5);
    end;
  end;
  if (FBoard[8, 8] = CompColor) and (FBoard[8, 7] = ChessNone) and
    (FBoard[7, 8] = ChessNone) then
  begin
    CR := ChangeChess(8, 7, CompColor, 0, FBoard);
    if not CR.Chessable then
    begin
      CR := ChangeChess(7, 8, CompColor, 0, FBoard);
      if not CR.Chessable then
        Dec(Addition, round(sqrt(FCost[8, 8])) * 3 div 5);
    end;
  end;
  if (FBoard[1, 1] = ManColor) and (FBoard[1, 2] = ChessNone) and
    (FBoard[2, 1] = ChessNone) then
  begin
    CR := ChangeChess(1, 2, ManColor, 0, FBoard);
    if not CR.Chessable then
    begin
      CR := ChangeChess(2, 1, ManColor, 0, FBoard);
      if not CR.Chessable then
        Inc(Addition, round(sqrt(FCost[1, 1])) * 3 div 5);
    end;
  end;
  if (FBoard[1, 8] = ManColor) and (FBoard[1, 7] = ChessNone) and
    (FBoard[2, 8] = ChessNone) then
  begin
    CR := ChangeChess(1, 7, ManColor, 0, FBoard);
    if not CR.Chessable then
    begin
      CR := ChangeChess(2, 8, ManColor, 0, FBoard);
      if not CR.Chessable then
        Inc(Addition, round(sqrt(FCost[1, 8])) * 3 div 5);
    end;
  end;
  if (FBoard[8, 1] = ManColor) and (FBoard[7, 1] = ChessNone) and
    (FBoard[8, 2] = ChessNone) then
  begin
    CR := ChangeChess(8, 2, ManColor, 0, FBoard);
    if not CR.Chessable then
    begin
      CR := ChangeChess(7, 1, ManColor, 0, FBoard);
      if not CR.Chessable then
        Inc(Addition, round(sqrt(FCost[8, 1])) * 3 div 5);
    end;
  end;
  if (FBoard[8, 8] = ManColor) and (FBoard[8, 7] = ChessNone) and
    (FBoard[7, 8] = ChessNone) then
  begin
    CR := ChangeChess(8, 7, ManColor, 0, FBoard);
    if not CR.Chessable then
    begin
      CR := ChangeChess(7, 8, ManColor, 0, FBoard);
      if not CR.Chessable then
        Inc(Addition, round(sqrt(FCost[8, 8])) * 3 div 5);
    end;
  end;

  Result := Addition;
end;

{procedure TOthelloAI.SetOthBoard(const Value: TOthelloBoard);
begin
  FOthBoard := Value;
  //if Value <> nil then
  //  Value.FreeNotification(Self);
end;}


{procedure TOthelloAI.SetOthBook(const Value: TBcOthBook);
begin
  FOthBook := Value;
  if Value <> nil then
    Value.FreeNotification(Self);
end;}

procedure TOthelloAI.ChangeCost;
var
  i, j: integer;
  temp: integer;
begin
  temp := -9;
  for i := 2 to 7 do
  begin
    for j := 2 to 7 do
    begin
      if (FBoard[i, j] <> ChessNone)
        and (not ((i = 2) and (j = 2))) and (not ((i = 7) and (j = 2))) and
        (not ((i = 2) and (j = 7))) and (not ((i = 7) and (j = 7))) then
      begin
        if (FBoard[i + 1, j + 1] <> ChessNone) then
          Inc(temp);
        if (FBoard[i - 1, j - 1] <> ChessNone) then
          Inc(temp);
        if (FBoard[i + 1, j - 1] <> ChessNone) then
          Inc(temp);
        if (FBoard[i - 1, j + 1] <> ChessNone) then
          Inc(temp);
        if (FBoard[i + 1, j] <> ChessNone) then
          Inc(temp);
        if (FBoard[i, j + 1] <> ChessNone) then
          Inc(temp);
        if (FBoard[i - 1, j] <> ChessNone) then
          Inc(temp);
        if (FBoard[i, j - 1] <> ChessNone) then
          Inc(temp);
        FCost[i, j] := temp;
        temp := -9;
      end;
    end;
  end;

  if FBoard[1, 8] <> ChessNone then
  begin
    FCost[1, 7] := 40;
    FCost[2, 8] := 40;
  end;
  if FBoard[8, 8] <> ChessNone then
  begin
    FCost[8, 7] := 40;
    FCost[7, 8] := 40;
  end;
  if FBoard[1, 1] <> ChessNone then
  begin
    FCost[1, 2] := 40;
    FCost[2, 1] := 40;
  end;
  if FBoard[8, 1] <> ChessNone then
  begin
    FCost[8, 2] := 40;
    FCost[7, 1] := 40;
  end;

  if FBoard[1, 1] <> ChessNone then
  begin
    for i := 3 to 6 do
    begin
      FCost[i, 2] := -1;
      FCost[2, i] := -1;
    end;
    FCost[2, 2] := 20;
  end;
  if FBoard[8, 8] <> ChessNone then
  begin
    for i := 3 to 6 do
    begin
      FCost[7, i] := -1;
      FCost[i, 7] := -1;
    end;
    FCost[7, 7] := 20;
  end;
  if FBoard[8, 1] <> ChessNone then
  begin
    for i := 3 to 6 do
      FCost[i, 2] := -1;
    for i := 3 to 6 do
      FCost[7, i] := -1;
    FCost[7, 2] := 20;
  end;
  if FBoard[1, 8] <> ChessNone then
  begin
    for i := 3 to 6 do
      FCost[i, 7] := -1;
    for i := 3 to 6 do
      FCost[2, i] := -1;
    FCost[2, 7] := 20;
  end;
end;

{procedure TOthelloAI.SetOnSearchBranch(const Value: TNotifyEvent);
begin
  FOnSearchBranch := Value;
end;}

function TOthelloAI.GetSavEva(AIdx: Integer): TEval;
begin
  Result := FSavEva[AIdx];
end;

procedure TOthelloAI.SetSavEva(AIdx: Integer; const Value: TEval);
begin
  FSavEva[AIdx] := Value;
end;

constructor TOthelloAI.Create;
begin
  inherited;
  //FRandomSelect := RandomSelectDefault;
  //FUseBook := UseBookDefault;
  FLevel := LevelDefault;
end;

function TOthelloAI.GetBoardCountAI: TBoardCountAI;
var
  I, J: Integer;
begin
  Result.CompCount := 0;
  Result.SpCount := 0;
  Result.ManCount := 0;
  //with OthBoard do
  for I := 1 to 8 do
    for J := 1 to 8 do
    begin
      if FBoard[I, J] = CompColor then
        Inc(Result.CompCount)
      else if FBoard[I, J] = ManColor then
        Inc(Result.ManCount)
      else
        Inc(Result.SpCount);
    end;
end;

procedure TOthelloAI.ExecuteThread(AStartDepth: Integer);
begin
//  OthBoard.Enabled := False;
  TThinkThread.Create(AStartDepth, Self);
end;

procedure TOthelloAI.DoEndThink(Sender: TObject);
begin
//  OthBoard.Enabled := True;
  try
    if not FLast then
    begin
      if FMaxValue >= 0 then
        FMaxValue := Round(Power(FMaxValue, 0.88) * 100) / 100
      else
        FMaxValue := -Round(Power(-FMaxValue, 0.88) * 100) / 100;
    end;
    if not FLast then ChangeCost;
    SortEva;
    // 这里需要发送消息,以通知外部
    PostMessage(Handle, WM_THINKEND, MaxPos.X, MaxPos.Y);
    //if Assigned(FOnEndThink) then
    //  FOnEndThink(MaxPos.X, MaxPos.Y);
    FThinking := False;
  finally
    Free;
  end;
end;

function TOthelloAI.SavEvalCount: Integer;
begin
  Result := Length(FSavEva);
end;

{procedure TOthelloAI.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FOthBoard) then
    FOthBoard := nil
  else if (Operation = opRemove) and (AComponent = FOthBook) then
    FOthBook := nil;
end;
}

{procedure TOthelloAI.Stop;
begin
  FThinkThread.Terminate;
end;
}
{ TThinkThread }

constructor TThinkThread.Create(AStartDepth: Integer; AI: TOthelloAI);
begin
  inherited Create(False);
  FreeOnTerminate := True;
  FStartDepth := AStartDepth;
  FAI := AI;
  OnTerminate := FAI.DoEndThink;
  Priority := tpNormal;
end;

{
procedure TThinkThread.DoSearchBranch;
begin
  if Assigned(FAI.FOnSearchBranch) then
    FAI.FOnSearchBranch(FAI);
end;
}

{
procedure TThinkThread.DoSearchRootChange;
begin
  with FAI do
  begin
    if (Level > 6) and ShowSearch then
    begin
      if RootIndex <> 1 then
      begin
        if not PointsEqual(OldSearchPos, MaxPos) then
          DrawCross(OldSearchPos.X, OldSearchPos.Y, clWhite);
        if not PointsEqual(OldMaxPos, MaxPos) then
          DrawCross(OldMaxPos.X, OldMaxPos.Y, clWhite);
        if not PointsEqual(MaxPos, OldMaxPos) then
        begin
          DrawCross(MaxPos.X, MaxPos.Y, clRed);
          OldMaxPos := MaxPos;
        end;
      end
      else
        OldMaxPos := Point(-1, -1);
      DrawCross(ThinkingPos.X, ThinkingPos.Y, clBlue);
      OldSearchPos := ThinkingPos;
    end;
    if Assigned(FOnSearchRootChange) then
      FOnSearchRootChange(FAI, RootCount, RootIndex);
  end;
end;
}

{procedure TThinkThread.DoTerminate;
begin
//  FAI.OthBoard.OnDrawBoard := nil;
  inherited;
end;}

{procedure TThinkThread.DrawCross(X, Y: Integer; AColor: TColor);
var
  ARect: TRect;
  APoint: TPoint;
begin
  if (X < 0) or (Y < 0) then
    Exit;
  with FAI.OthBoard do
  begin
    ARect := CellRect(X - 1, Y - 1);
    with ARect do
    begin
      APoint.X := (Right - Left) div 2 + Left;
      APoint.Y := (Bottom - Top) div 2 + Top;
    end;
    with Canvas do
    begin
      Pen.Color := AColor;
      Pen.Width := 3;
      MoveTo(ARect.Left + 11, APoint.Y);
      Lineto(ARect.Left + 20, APoint.Y);
      MoveTo(APoint.X, ARect.Top + 11);
      Lineto(APoint.X, ARect.Top + 20);
    end;
  end;
end;
}

{
procedure TThinkThread.DrawSearch(Sender: TObject);
begin
  with FAI do
    if (Level > 6) and ShowSearch then
    begin
      DrawCross(ThinkingPos.X, ThinkingPos.Y, clBlue);
      if not PointsEqual(MaxPos, Point(-1, -1)) then
        DrawCross(MaxPos.X, MaxPos.Y, clRed);
    end;
end;
}

procedure TThinkThread.Execute;
begin
  inherited;
//  FAI.OthBoard.OnDrawBoard := DrawSearch;
  // 开始计算！
  NegaScout(FStartDepth, -9000, 9000, True, False);

  if Assigned(FAI) then
    FAI.DoEndThink(Self);
  //Terminate;
end;

function TThinkThread.NegaScout(Depth: Integer; Alpha, Beta: Double;
  LastCanGo, AddFlag: Boolean): TSearchEval;
var
  SavCost: TCost;
  SavBoard: TBoard;
  SavAddFlag: Boolean;

  t: TSearchEval;
  i: Integer;
  A: TSearchEval;
  B: Double;
  CanGo: array[1..30] of TCanGoNode;
  ASideToGo: TChess;
  CR: TChangeChessResult;
  FSPoint: Integer;

  procedure SortCanGo;
    procedure QuickSort(iLo, iHi: Integer);
    var
      Lo, Hi: Integer;
      Mid, T: TCanGoNode;
    begin
      Lo := iLo;
      Hi := iHi;
      Mid := CanGo[(Lo + Hi) shr 1];
      repeat
        while CanGo[Lo].Value > Mid.Value do
          Inc(Lo);
        while CanGo[Hi].Value < Mid.Value do
          Dec(Hi);
        if Lo <= Hi then
        begin
          T := CanGo[Lo];
          CanGo[Lo] := CanGo[Hi];
          CanGo[Hi] := T;
          Inc(Lo);
          Dec(Hi);
        end;
      until Lo > Hi;
      if Hi > iLo then
        QuickSort(iLo, Hi);
      if Lo < iHi then
        QuickSort(Lo, iHi);
    end;
  begin
    QuickSort(Low(CanGo), FSPoint - 1);
  end;

  procedure EvalCanGo;
  var
    i, j, k: Integer;
  begin
//扫描判断
//对各个可走的点进行评价
    with FAI do
    begin
      FSPoint := 1;

      for j := 1 to 8 do
        for i := 1 to 8 do
        begin
          if FLast then
          begin
            if FBoard[i, j] <> ChessNone then
              Continue;
            CR := ChangeChess(i, j, ASideToGo, 0, FBoard);
            if CR.Chessable then
            begin
              CanGo[FSPoint].x := i;
              CanGo[FSPoint].y := j;
              CanGo[FSPoint].Value := 200;
              if ((i = 1) and (j = 1)) or ((i = 8) and (j = 1)) or
                ((i = 8) and (j = 8)) or ((i = 1) and (j = 8)) then
                CanGo[FSPoint].Value := 300;
              if (FBoard[i - 1, j] = ChessNone) and (i > 1) then
                Dec(CanGo[FSPoint].Value, 10);
              if (FBoard[i, j - 1] = ChessNone) and (j > 1) then
                Dec(CanGo[FSPoint].Value, 10);
              if (FBoard[i + 1, j] = ChessNone) and (i < 8) then
                Dec(CanGo[FSPoint].Value, 10);
              if (FBoard[i, j + 1] = ChessNone) and (j < 8) then
                Dec(CanGo[FSPoint].Value, 10);
              if (FBoard[i - 1, j - 1] = ChessNone) and (i > 1) and (j > 1) then
                Dec(CanGo[FSPoint].Value, 10);
              if (FBoard[i + 1, j + 1] = ChessNone) and (i < 8) and (j < 8) then
                Dec(CanGo[FSPoint].Value, 10);
              if (FBoard[i + 1, j - 1] = ChessNone) and (i < 8) and (j > 1) then
                Dec(CanGo[FSPoint].Value, 10);
              if (FBoard[i - 1, j + 1] = ChessNone) and (i > 1) and (j < 8) then
                Dec(CanGo[FSPoint].Value, 10);
              Inc(FSPoint);
            end;
          end
          else
          begin
            if FBoard[i, j] <> ChessNone then
              Continue;
            CR := ChangeChess(i, j, ASideToGo, 3, FBoard);
            if CR.Chessable then
            begin
              CanGo[FSPoint].x := i;
              CanGo[FSPoint].y := j;
              CanGo[FSPoint].Value := 200;
              if ((i = 1) and (j = 1)) or ((i = 8) and (j = 1)) or
                ((i = 8) and (j = 8)) or ((i = 1) and (j = 8)) then
                CanGo[FSPoint].Value := 300
              else if ((i = 2) and (j = 2)) or ((i = 7) and (j = 2)) or
                ((i = 7) and (j = 7)) or ((i = 2) and (j = 7)) then
                CanGo[FSPoint].Value := 100
              else if ((i = 2) and (j = 1) and (FBoard[3, 1] = ManColor)) or
                ((i = 1) and (j = 2) and (FBoard[1, 3] = ManColor)) or
                ((i = 2) and (j = 8) and (FBoard[3, 8] = ManColor)) or
                ((i = 8) and (j = 2) and (FBoard[8, 3] = ManColor)) or
                ((i = 7) and (j = 1) and (FBoard[6, 1] = ManColor)) or
                ((i = 7) and (j = 8) and (FBoard[6, 8] = ManColor)) or
                ((i = 1) and (j = 7) and (FBoard[1, 6] = ManColor)) or
                ((i = 8) and (j = 7) and (FBoard[8, 6] = ManColor)) then
                CanGo[FSPoint].Value := 70;
              if (FBoard[i - 1, j] = ChessNone) and (i > 1) then
                Dec(CanGo[FSPoint].Value, 10);
              if (FBoard[i, j - 1] = ChessNone) and (j > 1) then
                Dec(CanGo[FSPoint].Value, 10);
              if (FBoard[i + 1, j] = ChessNone) and (i < 8) then
                Dec(CanGo[FSPoint].Value, 10);
              if (FBoard[i, j + 1] = ChessNone) and (j < 8) then
                Dec(CanGo[FSPoint].Value, 10);
              if (FBoard[i - 1, j - 1] = ChessNone) and (i > 1) and (j > 1) then
                Dec(CanGo[FSPoint].Value, 10);
              if (FBoard[i + 1, j + 1] = ChessNone) and (i < 8) and (j < 8) then
                Dec(CanGo[FSPoint].Value, 10);
              if (FBoard[i + 1, j - 1] = ChessNone) and (i < 8) and (j > 1) then
                Dec(CanGo[FSPoint].Value, 10);
              if (FBoard[i - 1, j + 1] = ChessNone) and (i > 1) and (j < 8) then
                Dec(CanGo[FSPoint].Value, 10);
              if (CR.L <> 0) and (j <> 1) and (j <> 8) then
                for k := 1 to CR.L do
                begin
                  if (FBoard[i - 1 - k, j] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i - k, j - 1] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + 1 - k, j] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i - k, j + 1] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i - 1 - k, j - 1] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + 1 - k, j + 1] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + 1 - k, j - 1] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i - 1 - k, j + 1] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                end;
              if (CR.R <> 0) and (j <> 1) and (j <> 8) then
                for k := 1 to CR.R do
                begin
                  if (FBoard[i - 1 + k, j] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + k, j - 1] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + 1 + k, j] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + k, j + 1] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i - 1 + k, j - 1] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + 1 + k, j + 1] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + 1 + k, j - 1] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i - 1 + k, j + 1] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                end;
              if (CR.U <> 0) and (i <> 1) and (i <> 8) then
                for k := 1 to CR.U do
                begin
                  if (FBoard[i - 1, j - k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i, j - 1 - k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + 1, j - k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i, j + 1 - k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i - 1, j - 1 - k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + 1, j + 1 - k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + 1, j - 1 - k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i - 1, j + 1 - k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                end;
              if (CR.D <> 0) and (i <> 1) and (i <> 8) then
                for k := 1 to CR.D do
                begin
                  if (FBoard[i - 1, j + k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i, j - 1 + k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + 1, j + k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i, j + 1 + k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i - 1, j - 1 + k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + 1, j + 1 + k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + 1, j - 1 + k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i - 1, j + 1 + k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                end;
              if CR.LU <> 0 then
                for k := 1 to CR.LU do
                begin
                  if (FBoard[i - 1 - k, j - k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i - k, j - 1 - k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + 1 - k, j - k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i - k, j + 1 - k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i - 1 - k, j - 1 - k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + 1 - k, j + 1 - k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + 1 - k, j - 1 - k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i - 1 - k, j + 1 - k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                end;
              if CR.LD <> 0 then
                for k := 1 to CR.LD do
                begin
                  if (FBoard[i - 1 - k, j + k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i - k, j - 1 + k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + 1 - k, j + k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i - k, j + 1 + k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i - 1 - k, j - 1 + k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + 1 - k, j + 1 + k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + 1 - k, j - 1 + k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i - 1 - k, j + 1 + k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                end;
              if CR.RU <> 0 then
                for k := 1 to CR.RU do
                begin
                  if (FBoard[i - 1 + k, j - k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + k, j - 1 - k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + 1 + k, j - k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + k, j + 1 - k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i - 1 + k, j - 1 - k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + 1 + k, j + 1 - k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + 1 + k, j - 1 - k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i - 1 + k, j + 1 - k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                end;
              if CR.RD <> 0 then
                for k := 1 to CR.RD do
                begin
                  if (FBoard[i - 1 + k, j + k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + k, j - 1 + k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + 1 + k, j + k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + k, j + 1 + k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i - 1 + k, j - 1 + k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + 1 + k, j + 1 + k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i + 1 + k, j - 1 + k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                  if (FBoard[i - 1 + k, j + 1 + k] = ChessNone) then
                    Dec(CanGo[FSPoint].Value, 10);
                end;
//              if FRandomSelect then
              Inc(CanGo[FSPoint].Value, Random(19) - 9);
              Inc(FSPoint);
            end;
          end;
        end;
    end;
  end;

  procedure FindAddFlag;
  begin
    with FAI do
      if ASideToGo = CompColor then
      begin
        if not FLast then
        begin
          if (Depth < 2) and (not AddFlag) then
          begin
            if ((CanGo[i].x = 1) and (CanGo[i].y = 2)) or
               ((CanGo[i].x = 1) and (CanGo[i].y = 7)) or
               ((CanGo[i].x = 8) and (CanGo[i].y = 2)) or
               ((CanGo[i].x = 8) and (CanGo[i].y = 7)) or
               ((CanGo[i].y = 1) and (CanGo[i].x = 2)) or
               ((CanGo[i].y = 1) and (CanGo[i].x = 7)) or
               ((CanGo[i].y = 8) and (CanGo[i].x = 2)) or
               ((CanGo[i].y = 8) and (CanGo[i].x = 7)) then
              AddFlag := True
            else if ((CanGo[i].x = 2) and (CanGo[i].y = 2)) or
                    ((CanGo[i].x = 7) and (CanGo[i].y = 7)) or
                    ((CanGo[i].x = 7) and (CanGo[i].y = 2)) or
                    ((CanGo[i].x = 2) and (CanGo[i].y = 7)) then
              AddFlag := True
            else if ((CanGo[i].x = 1) and (CanGo[i].y = 1)) or
                    ((CanGo[i].x = 8) and (CanGo[i].y = 8)) or
                    ((CanGo[i].x = 8) and (CanGo[i].y = 1)) or
                    ((CanGo[i].x = 1) and (CanGo[i].y = 8)) then
              AddFlag := True;
          end;
        end;
      end
      else
      begin
        if not FLast then
        begin
          if (Depth < 2) and (not AddFlag) then
          begin
            if ((CanGo[i].x = 1) and (CanGo[i].y = 2)) or
              ((CanGo[i].x = 1) and (CanGo[i].y = 7)) or
              ((CanGo[i].x = 8) and (CanGo[i].y = 2)) or
              ((CanGo[i].x = 8) and (CanGo[i].y = 7)) or
              ((CanGo[i].y = 1) and (CanGo[i].x = 2)) or
              ((CanGo[i].y = 1) and (CanGo[i].x = 7)) or
              ((CanGo[i].y = 8) and (CanGo[i].x = 2)) or
              ((CanGo[i].y = 8) and (CanGo[i].x = 7)) then
              AddFlag := True
            else if ((CanGo[i].x = 2) and (CanGo[i].y = 2)) or
              ((CanGo[i].x = 7) and (CanGo[i].y = 7)) or
              ((CanGo[i].x = 7) and (CanGo[i].y = 2)) or
              ((CanGo[i].x = 2) and (CanGo[i].y = 7)) then
              AddFlag := True
            else if ((CanGo[i].x = 1) and (CanGo[i].y = 1)) or
              ((CanGo[i].x = 8) and (CanGo[i].y = 8)) or
              ((CanGo[i].x = 8) and (CanGo[i].y = 1)) or
              ((CanGo[i].x = 1) and (CanGo[i].y = 8)) then
              AddFlag := True;
          end;
        end;
      end;
  end;

  procedure SaveBoardProc; //保存棋局
  begin
    SavCost := FAI.FCost;
    SavBoard := FAI.FBoard;
    SavAddFlag := AddFlag;
  end;

  procedure LoadBoardProc; //读取棋局
  begin
    FAI.FCost := SavCost;
    FAI.FBoard := SavBoard;
    AddFlag := SavAddFlag;
  end;

var
  BoardCount: TBoardCountAI;
  ThisCanGo: Boolean;

begin //节点初始化
  //if Terminated then Exit; 
  with FAI do
  begin
    Result.Path := '';
    if ((FDepthMax - Depth) mod 2 = 0) then
      ASideToGo := CompColor
    else
      ASideToGo := ManColor;

    if ((FStep - BoardStep = FDepthMax) and (AddFlag = False))
      or (FStep - BoardStep > FDepthMax) or (FStep = 61) then //是叶子节点
    begin
//------------------------branch
      Inc(FBranch);
      //if FBranch mod 10000 = 0 then
      //  Synchronize(DoSearchBranch);
//------------------------end branch
//叶子节点返回值
      Result.Max := Evaluate(ASideToGo = ManColor);
      Exit;
    end;

    EvalCanGo;
    SortCanGo;

    ThisCanGo := FSPoint <> 1;
    A.Max := Alpha;
    B := Beta;

    for i := 1 to FSPoint - 1 do //对每一个可下棋的位置
    begin
      if Depth = FDepthMax then
      begin
        RootCount := FSPoint - 1;
        RootIndex := i;
        FThinkingPos.X := CanGo[i].X;
        FThinkingPos.Y := CanGo[i].Y;
        //Synchronize(DoSearchRootChange);
      end;
      SaveBoardProc;
      ChangeChess(CanGo[i].x, CanGo[i].y, ASideToGo, 2, FBoard);
      FindAddFlag;

      Inc(FStep);
      t := NegaScout(Depth - 1, -B, -A.Max, True, AddFlag);
      t.Max := -t.Max;
      Dec(FStep);

      if (t.Max > A.Max) and (i > 1) and (t.Max < Beta) then
        if ((FStep - BoardStep < FDepthMax - 1) and (AddFlag = False))
          or ((FStep - BoardStep < FDepthMax) and AddFlag) or (FStep = 59) then
        begin
          Inc(FStep);
          A := NegaScout(Depth - 1, -Beta, -t.Max, True, AddFlag);
          A.Max := -A.Max;
          Dec(FStep);
        end;
      if t.Max > A.Max then
        A := t;
      if A.Max >= Beta then
      begin
        Result.Max := A.Max;
        Result.Path := chr(64 + CanGo[i].x) + chr(48 + CanGo[i].y) + A.Path;
        LoadBoardProc;
        Exit;
      end;
      B := A.Max + 0.00001;

      if (Depth = FDepthMax) then
      begin
        SetLength(FSavEva, Length(FSavEva) + 1);
        FSavEva[Length(FSavEva) - 1].Max := A.Max;
        FSavEva[Length(FSavEva) - 1].x := CanGo[i].x;
        FSavEva[Length(FSavEva) - 1].y := CanGo[i].y;
        FSavEva[Length(FSavEva) - 1].Path :=
          chr(64 + CanGo[i].x) + chr(48 + CanGo[i].y) + A.Path;
        if (A.Max > FMaxValue) then
        begin
          FMaxValue := A.Max;
          FMaxPos.X := CanGo[i].x;
          FMaxPos.Y := CanGo[i].y;
        end
      end;
      LoadBoardProc;
    end; //end loop

    if not ThisCanGo then
      if LastCanGo then //有一方不能下
      begin
        t := NegaScout(Depth - 1, -Beta, -Alpha, False, AddFlag);
        t.Max := -t.Max;

        if t.Max > Alpha then
          if t.Max >= Beta then
          begin
            Result.Max := t.Max;
            Result.Path := t.Path;
            Exit;
          end
          else
            A := t;
      end
      else //双方都不能下
      begin
//------------------------branch
        Inc(FBranch);
//------------------------end branch
        BoardCount := GetBoardCountAI;
        with BoardCount do
          if (CompCount > ManCount) then
          begin
            if not FLast then
              A.Max := 112.8
            else
              A.Max := CompCount - ManCount;
          end
          else if (CompCount < ManCount) then
          begin
            if not FLast then
              A.Max := -112.8
            else
              A.Max := CompCount - ManCount;
          end
          else
            A.Max := 0;
        if ASideToGo = ManColor then
          A.Max := -A.Max;
      end;

    Result := A;
  end;
end;

function TOthelloAI.RandomAI(ASideToGo: TChess; Dir: Integer = 0): TPoint;
var
  I, J: Integer;
begin
  Result := Point(0, 0);
  case Dir of
    0:
      for I := 1 to 8 do
        for J := 1 to 8 do
          if ChangeChess(I, J, ASideToGo, 0, FBoard).Chessable then
          begin
            Result := Point(I, J);
            Exit;
          end;
    1:
      for I := 8 downto 1 do
        for J := 1 to 8 do
          if ChangeChess(I, J, ASideToGo, 0, FBoard).Chessable then
          begin
            Result := Point(I, J);
            Exit;
          end;
    2:
      for I := 1 to 8 do
        for J := 8 downto 1 do
          if ChangeChess(I, J, ASideToGo, 0, FBoard).Chessable then
          begin
            Result := Point(I, J);
            Exit;
          end;
    3:
      for I := 8 downto 1 do
        for J := 8 downto 1 do
          if ChangeChess(I, J, ASideToGo, 0, FBoard).Chessable then
          begin
            Result := Point(I, J);
            Exit;
          end;
    4:
      for J := 1 to 8 do
        for I := 1 to 8 do
          if ChangeChess(I, J, ASideToGo, 0, FBoard).Chessable then
          begin
            Result := Point(I, J);
            Exit;
          end;
    5:
      for J := 1 to 8 do
        for I := 8 downto 1 do
          if ChangeChess(I, J, ASideToGo, 0, FBoard).Chessable then
          begin
            Result := Point(I, J);
            Exit;
          end;
    6:
      for J := 8 downto 1 do
        for I := 1 to 8 do
          if ChangeChess(I, J, ASideToGo, 0, FBoard).Chessable then
          begin
            Result := Point(I, J);
            Exit;
          end;
  else
    for J := 8 downto 1 do
      for I := 8 downto 1 do
        if ChangeChess(I, J, ASideToGo, 0, FBoard).Chessable then
        begin
          Result := Point(I, J);
          Exit;
        end;
  end;
end;

function TOthelloAI.ChangeChess(X, Y: Integer; Chess: TChess; Param: Integer;
  var ABoard: TBoard): TChangeChessResult;
var
  i: Integer;
  opChess: TChess;
  //Param的说明
  //0：判断该处是否可下棋
  //1:在该处下棋，并有动画(不使用)
  //2：在该处下棋，没有动画
  //3：判断该处是否可下棋，并返回在各个方向上吃子的个数
begin
  Result.Chessable := false;
  if ABoard[x, y] <> ChessNone then Exit;

  if Chess = ChessBlack then
    opChess := ChessWhite
  else
    opChess := ChessBlack;

  Result.L := 0;
  Result.R := 0;
  Result.U := 0;
  Result.D := 0;
  Result.LU := 0;
  Result.LD := 0;
  Result.RD := 0;
  Result.RU := 0;
  if (y > 2) and (ABoard[x, y - 1] = opChess) then
  begin
    for i := y - 2 downto 1 do
    begin
      if (ABoard[x, i] = ChessNone) then
        break;
      if (ABoard[x, i] = Chess) then
      begin
        Result.U := y - i - 1;
        Result.Chessable := true;
        if Param = 0 then
          Exit;
        Break;
      end;
    end;
  end;
  if (y < 7) and (ABoard[x, y + 1] = opChess) then
  begin
    for i := y + 2 to 8 do
    begin
      if (ABoard[x, i] = ChessNone) then
        break;
      if (ABoard[x, i] = Chess) then
      begin
        Result.D := i - y - 1;
        Result.Chessable := true;
        if Param = 0 then
          Exit;
        Break;
      end;
    end;
  end;
  if (x > 2) and (ABoard[x - 1, y] = opChess) then
  begin
    for i := x - 2 downto 1 do
    begin
      if (ABoard[i, y] = ChessNone) then
        break;
      if (ABoard[i, y] = Chess) then
      begin
        Result.L := x - i - 1;
        Result.Chessable := true;
        if Param = 0 then
          exit;
        break;
      end;
    end;
  end;
  if (x < 7) and (ABoard[x + 1, y] = opChess) then
  begin
    for i := x + 2 to 8 do
    begin
      if (ABoard[i, y] = ChessNone) then
        break;
      if (ABoard[i, y] = Chess) then
      begin
        Result.R := i - x - 1;
        Result.Chessable := true;
        if Param = 0 then
          exit;
        break;
      end;
    end;
  end;
  if (y > 2) and (x > 2) and (ABoard[x - 1, y - 1] = opChess) then
  begin
    for i := 2 to 7 do
    begin
      if (x - i >= 1) and (y - i >= 1) then
      begin
        if (ABoard[x - i, y - i] = ChessNone) then
          break;
        if (ABoard[x - i, y - i] = Chess) then
        begin
          Result.LU := i - 1;
          Result.Chessable := true;
          if Param = 0 then
            exit;
          break;
        end;
      end;
    end;
  end;
  if (y > 2) and (x < 7) and (ABoard[x + 1, y - 1] = opChess) then
  begin
    for i := 2 to 7 do
    begin
      if (x + i <= 8) and (y - i >= 1) then
      begin
        if ABoard[x + i, y - i] = ChessNone then
          break;
        if ABoard[x + i, y - i] = Chess then
        begin
          Result.RU := i - 1;
          Result.Chessable := true;
          if Param = 0 then
            exit;
          break;
        end;
      end;
    end;
  end;
  if (y < 7) and (x < 7) and (ABoard[x + 1, y + 1] = opChess) then
  begin
    for i := 2 to 7 do
    begin
      if (x + i <= 8) and (y + i <= 8) then
      begin
        if ABoard[x + i, y + i] = ChessNone then
          break;
        if ABoard[x + i, y + i] = Chess then
        begin
          Result.RD := i - 1;
          Result.Chessable := true;
          if Param = 0 then
            exit;
          break;
        end;
      end;
    end;
  end;
  if (y < 7) and (x > 2) and (ABoard[x - 1, y + 1] = opChess) then
  begin
    for i := 2 to 7 do
    begin
      if (x - i >= 1) and (y + i <= 8) then
      begin
        if ABoard[x - i, y + i] = ChessNone then
          break;
        if ABoard[x - i, y + i] = Chess then
        begin
          Result.LD := i - 1;
          Result.Chessable := true;
          if Param = 0 then
            exit;
          break;
        end;
      end;
    end;
  end;

  if (not Result.Chessable) or (Param = 0) or (Param = 3) then
    Exit;

  if (Result.U > 0) then
  begin
    ABoard[x, y] := Chess;
    for i := y - 1 downto y - Result.U do
    begin
      ABoard[x, i] := Chess;
    end;
  end;

  if (Result.D > 0) then
  begin
    ABoard[x, y] := Chess;
    for i := y + 1 to y + Result.D do
    begin
      ABoard[x, i] := Chess;
    end;
  end;

  if (Result.L > 0) then
  begin
    ABoard[x, y] := Chess;
    for i := x - 1 downto x - Result.L do
    begin
      ABoard[i, y] := Chess;
    end;
  end;

  if (Result.R > 0) then
  begin
    ABoard[x, y] := Chess;
    for i := x + 1 to x + Result.R do
    begin
      ABoard[i, y] := Chess;
    end;
  end;

  if (Result.LU > 0) then
  begin
    ABoard[x, y] := Chess;
    for i := 1 to Result.LU do
    begin
      ABoard[x - i, y - i] := Chess;
    end;
  end;

  if (Result.RU > 0) then
  begin
    ABoard[x, y] := Chess;
    for i := 1 to Result.RU do
    begin
      ABoard[x + i, y - i] := Chess;
    end;
  end;

  if (Result.RD > 0) then
  begin
    ABoard[x, y] := Chess;
    for i := 1 to Result.RD do
    begin
      ABoard[x + i, y + i] := Chess;
    end;
  end;

  if (Result.LD > 0) then
  begin
    ABoard[x, y] := Chess;
    for i := 1 to Result.LD do
    begin
      ABoard[x - i, y + i] := Chess;
    end;
  end;
end;

end.

