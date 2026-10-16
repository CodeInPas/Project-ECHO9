unit uSonarRenderer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Graphics, ExtCtrls,
  BGRABitmap, BGRABitmapTypes,
  uThemeConfig, uGameTypes, uEntityManager, uSonarEntity;

type
  { TSonarRenderer: Mesin rendering radar berbasis layer (BGRABitmap) }
  TSonarRenderer = class
  private
    FStaticLayer: TBGRABitmap;
    FTrailLayer: TBGRABitmap;
    FCompositeLayer: TBGRABitmap;
    FTheme: TThemeConfig;

    FWidth: Integer;
    FHeight: Integer;
    FCenterX: Integer;
    FCenterY: Integer;
    FRadius: Integer;

    FSweepAngle: Double;
    FSweepSpeed: Double; // Derajat per detik

    procedure RebuildStaticLayer;
    procedure DrawGridAndAzimuth(Bitmap: TBGRABitmap);
    procedure FadeTrailLayer;
    procedure DrawSweepLine;
    procedure DrawEntities(EntityManager: TEntityManager);

    { Konversi Koordinat Game ke Layar UI }
    function GameToScreen(const PlayerPos, TargetPos: TPoint2D; MaxRange: Double): TPoint; inline;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Resize(AWidth, AHeight: Integer);
    procedure Update(DeltaTime: Double);
    procedure Render(PaintBox: TPaintBox; EntityManager: TEntityManager);

    property SweepAngle: Double read FSweepAngle;
  end;

implementation

constructor TSonarRenderer.Create;
begin
  inherited Create;
  FTheme := GetDefaultTheme;
  FSweepAngle := 0.0;
  FSweepSpeed := 90.0; // 1 putaran penuh = 4 detik

  FStaticLayer := nil;
  FTrailLayer := nil;
  FCompositeLayer := nil;
  FWidth := 0;
  FHeight := 0;
end;

destructor TSonarRenderer.Destroy;
begin
  if Assigned(FStaticLayer) then FStaticLayer.Free;
  if Assigned(FTrailLayer) then FTrailLayer.Free;
  if Assigned(FCompositeLayer) then FCompositeLayer.Free;
  inherited Destroy;
end;

procedure TSonarRenderer.Resize(AWidth, AHeight: Integer);
begin
  if (AWidth = FWidth) and (AHeight = FHeight) then Exit;
  if (AWidth <= 0) or (AHeight <= 0) then Exit;

  FWidth := AWidth;
  FHeight := AHeight;
  FCenterX := FWidth div 2;
  FCenterY := FHeight div 2;
  FRadius := Trunc(Min(FWidth, FHeight) * RADAR_RADIUS_RATIO);

  if Assigned(FStaticLayer) then FreeAndNil(FStaticLayer);
  if Assigned(FTrailLayer) then FreeAndNil(FTrailLayer);
  if Assigned(FCompositeLayer) then FreeAndNil(FCompositeLayer);

  FStaticLayer := TBGRABitmap.Create(FWidth, FHeight, FTheme.BgMain);
  FTrailLayer := TBGRABitmap.Create(FWidth, FHeight, BGRAPixelTransparent);
  FCompositeLayer := TBGRABitmap.Create(FWidth, FHeight, FTheme.BgMain);

  RebuildStaticLayer;
end;

procedure TSonarRenderer.DrawGridAndAzimuth(Bitmap: TBGRABitmap);
var
  i: Integer;
  AngRad: Double;
  X1, Y1, X2, Y2: Integer;
begin
  // Lingkaran konsentris
  for i := 1 to 4 do
    Bitmap.EllipseAntialias(FCenterX, FCenterY, (FRadius * i) / 4, (FRadius * i) / 4, FTheme.RadarGrid, 1.0);

  // Garis Azimuth (Tiap 30 derajat)
  Bitmap.FontName := UI_FONT_PRIMARY;
  Bitmap.FontHeight := 12;
  Bitmap.FontStyle := [];

  for i := 0 to 11 do
  begin
    AngRad := DegToRad((i * 30) - 90);

    // Garis dari tengah
    X1 := FCenterX + Trunc(Cos(AngRad) * (FRadius * 0.1));
    Y1 := FCenterY + Trunc(Sin(AngRad) * (FRadius * 0.1));
    X2 := FCenterX + Trunc(Cos(AngRad) * FRadius);
    Y2 := FCenterY + Trunc(Sin(AngRad) * FRadius);
    Bitmap.DrawLineAntialias(X1, Y1, X2, Y2, FTheme.RadarGrid, 1.0, False);

    // Label Derajat
    X2 := FCenterX + Trunc(Cos(AngRad) * (FRadius + 15));
    Y2 := FCenterY + Trunc(Sin(AngRad) * (FRadius + 15));

    // Perbaikan Error: Menghapus tlCenter karena parameter ke-7 pada BGRABitmap TextOutAngle adalah boolean (Antialias)
    Bitmap.TextOutAngle(X2, Y2, 0, IntToStr(i * 30), FTheme.RadarGrid, taCenter);
  end;
end;

procedure TSonarRenderer.RebuildStaticLayer;
begin
  if not Assigned(FStaticLayer) then Exit;
  FStaticLayer.Fill(FTheme.BgMain);
  DrawGridAndAzimuth(FStaticLayer);
end;

procedure TSonarRenderer.Update(DeltaTime: Double);
begin
  FSweepAngle := FSweepAngle + (FSweepSpeed * DeltaTime);
  if FSweepAngle >= 360.0 then
    FSweepAngle := FSweepAngle - 360.0;
end;

procedure TSonarRenderer.FadeTrailLayer;
begin
  // Menerapkan kotak hitam semi-transparan untuk memudarkan jejak radar sebelumnya
  FTrailLayer.FillRect(0, 0, FWidth, FHeight, FTheme.PhosphorFade, dmDrawWithTransparency);
end;

procedure TSonarRenderer.DrawSweepLine;
var
  AngRad: Double;
  X, Y: Integer;
begin
  AngRad := DegToRad(FSweepAngle - 90.0);
  X := FCenterX + Trunc(Cos(AngRad) * FRadius);
  Y := FCenterY + Trunc(Sin(AngRad) * FRadius);

  FTrailLayer.DrawLineAntialias(FCenterX, FCenterY, X, Y, FTheme.RadarSweep, SWEEP_LINE_WIDTH, False);
end;

function TSonarRenderer.GameToScreen(const PlayerPos, TargetPos: TPoint2D; MaxRange: Double): TPoint; inline;
var
  Polar: TPolarCoord;
  ScreenRad: Double;
  AngRad: Double;
begin
  Polar := CartesianToPolar(PlayerPos, TargetPos);
  ScreenRad := (Polar.Range / MaxRange) * FRadius;
  AngRad := DegToRad(Polar.Bearing - 90.0);

  Result.X := FCenterX + Trunc(Cos(AngRad) * ScreenRad);
  Result.Y := FCenterY + Trunc(Sin(AngRad) * ScreenRad);
end;

procedure TSonarRenderer.DrawEntities(EntityManager: TEntityManager);
var
  i: Integer;
  Ent: TSonarEntity;
  ScrPos: TPoint;
  Polar: TPolarCoord;
  BlipColor: TBGRAPixel;
  AngleDiff: Double;
begin
  if not Assigned(EntityManager.Player) then Exit;

  for i := 0 to EntityManager.Entities.Count - 1 do
  begin
    Ent := EntityManager.Entities[i];
    if (not Ent.IsAlive) or (Ent = EntityManager.Player) then Continue;

    Polar := CartesianToPolar(EntityManager.Player.Position, Ent.Position);
    if Polar.Range > c_MaxSonarRange then Continue;

    // Hitung perbedaan sudut antara entitas dan sapuan radar
    AngleDiff := Abs(Polar.Bearing - FSweepAngle);
    if AngleDiff > 180.0 then AngleDiff := 360.0 - AngleDiff;

    // Hanya gambar jika sapuan radar baru saja melewatinya (Toleransi 5 derajat)
    if AngleDiff <= 5.0 then
    begin
      ScrPos := GameToScreen(EntityManager.Player.Position, Ent.Position, c_MaxSonarRange);

      case Ent.EntityType of
        etHostileSub: BlipColor := FTheme.BlipHostile;
        etAlliedSub:  BlipColor := FTheme.BlipFriendly;
        etTorpedo:    BlipColor := FTheme.BlipHostile;
        etDecoy:      BlipColor := FTheme.BlipDecoy;
        else          BlipColor := FTheme.BlipUnknown;
      end;

      FTrailLayer.FillEllipseAntialias(ScrPos.X, ScrPos.Y, 3.5, 3.5, BlipColor);

      // Glow effect ringan (digambar sedikit lebih besar dengan alpha rendah)
      BlipColor.alpha := 100;
      FTrailLayer.FillEllipseAntialias(ScrPos.X, ScrPos.Y, 6.0, 6.0, BlipColor);
    end;
  end;
end;

procedure TSonarRenderer.Render(PaintBox: TPaintBox; EntityManager: TEntityManager);
begin
  if (FWidth <= 0) or (FHeight <= 0) then Exit;
  if not Assigned(FCompositeLayer) then Exit;

  FadeTrailLayer;
  DrawSweepLine;
  if Assigned(EntityManager) then DrawEntities(EntityManager);

  // Gabungkan Static Layer dan Trail Layer ke Composite Layer
  FCompositeLayer.PutImage(0, 0, FStaticLayer, dmSet);
  FCompositeLayer.PutImage(0, 0, FTrailLayer, dmDrawWithTransparency);

  // Titik pusat (Posisi Kapal Pemain)
  FCompositeLayer.FillEllipseAntialias(FCenterX, FCenterY, 3, 3, FTheme.RadarSweep);

  // Kirim hasil akhir ke kanvas
  FCompositeLayer.Draw(PaintBox.Canvas, 0, 0, False);
end;

end.
