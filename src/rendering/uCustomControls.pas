unit uCustomControls;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, Types, LMessages, ExtCtrls,
  BGRABitmap, BGRABitmapTypes, uThemeConfig;

type
  { TEchoGlassPanel: Panel transparan (Glassmorphism) menggunakan BGRABitmap }
  TEchoGlassPanel = class(TCustomControl)
  private
    FBuffer: TBGRABitmap;
    FTitle: string;
    FTheme: TThemeConfig;
    procedure SetTitle(const AValue: string);
  protected
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property Title: string read FTitle write SetTitle;
    property Align;
    property Anchors;
    property BoundsRect;
    property Visible;
    property Enabled;
  end;

  { TEchoAlertState: Status kewaspadaan UI }
  TEchoAlertState = (easNormal, easWarning, easAlert);

  { TEchoStatusLabel: Label dengan efek berkedip untuk peringatan sistem }
  TEchoStatusLabel = class(TCustomControl)
  private
    FTheme: TThemeConfig;
    FState: TEchoAlertState;
    FText: string;
    FBlinkTimer: TTimer;
    FIsVisible: Boolean;
    procedure SetState(const AValue: TEchoAlertState);
    procedure SetText(const AValue: string);
    procedure OnBlinkTimer(Sender: TObject);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property AlertState: TEchoAlertState read FState write SetState;
    property Caption: string read FText write SetText;
    property Align;
    property Anchors;
  end;

implementation

{ TEchoGlassPanel }

constructor TEchoGlassPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque, csAcceptsControls];
  DoubleBuffered := True;
  FTheme := GetDefaultTheme;
  FTitle := '';
  FBuffer := nil;
end;

destructor TEchoGlassPanel.Destroy;
begin
  if Assigned(FBuffer) then FBuffer.Free;
  inherited Destroy;
end;

procedure TEchoGlassPanel.Resize;
begin
  inherited Resize;
  if Assigned(FBuffer) then FreeAndNil(FBuffer);

  if (Width > 0) and (Height > 0) then
    FBuffer := TBGRABitmap.Create(Width, Height);

  Invalidate;
end;

procedure TEchoGlassPanel.SetTitle(const AValue: string);
begin
  if FTitle = AValue then Exit;
  FTitle := AValue;
  Invalidate;
end;

procedure TEchoGlassPanel.Paint;
begin
  if not Assigned(FBuffer) then Exit;

  // Render Background & Border
  FBuffer.Fill(FTheme.GlassBg);
  FBuffer.Rectangle(0, 0, Width, Height, FTheme.GlassBorder, FTheme.GlassBorder, dmSet, False);

  // Render Title
  if FTitle <> '' then
  begin
    FBuffer.FontName := UI_FONT_PRIMARY;
    FBuffer.FontHeight := 14;
    FBuffer.FontStyle := [fsBold];
    FBuffer.TextOut(10, 5, FTitle, FTheme.TextNormal, taLeftJustify);

    // Garis pemisah bawah judul
    FBuffer.DrawLineAntialias(10, 25, Width - 10, 25, FTheme.GlassBorder, 1.0);
  end;

  FBuffer.Draw(Canvas, 0, 0, False);
end;

{ TEchoStatusLabel }

constructor TEchoStatusLabel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  FTheme := GetDefaultTheme;
  FState := easNormal;
  FText := 'STATUS: NOMINAL';
  FIsVisible := True;

  FBlinkTimer := TTimer.Create(Self);
  FBlinkTimer.Interval := 500;
  FBlinkTimer.Enabled := False;
  FBlinkTimer.OnTimer := @OnBlinkTimer;

  Height := 24;
end;

destructor TEchoStatusLabel.Destroy;
begin
  FBlinkTimer.Free;
  inherited Destroy;
end;

procedure TEchoStatusLabel.SetState(const AValue: TEchoAlertState);
begin
  if FState = AValue then Exit;
  FState := AValue;

  case FState of
    easNormal:
      begin
        FBlinkTimer.Enabled := False;
        FIsVisible := True;
      end;
    easWarning, easAlert:
      begin
        FBlinkTimer.Interval := IfThen(FState = easAlert, 250, 500);
        FBlinkTimer.Enabled := True;
      end;
  end;

  Invalidate;
end;

procedure TEchoStatusLabel.SetText(const AValue: string);
begin
  if FText = AValue then Exit;
  FText := AValue;
  Invalidate;
end;

procedure TEchoStatusLabel.OnBlinkTimer(Sender: TObject);
begin
  FIsVisible := not FIsVisible;
  Invalidate;
end;

procedure TEchoStatusLabel.Paint;
var
  TextColor: TColor;
begin
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Name := UI_FONT_PRIMARY;
  Canvas.Font.Size := 10;
  Canvas.Font.Style := [fsBold];

  if not FIsVisible then Exit;

  case FState of
    easNormal:  TextColor := FTheme.BlipFriendly.ToColor;
    easWarning: TextColor := FTheme.BlipUnknown.ToColor;
    easAlert:   TextColor := FTheme.TextAlert.ToColor;
    else TextColor := clWhite;
  end;

  Canvas.Font.Color := TextColor;
  Canvas.TextOut(0, (Height - Canvas.TextHeight(FText)) div 2, FText);
end;

end.

