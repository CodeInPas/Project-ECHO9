unit uCountermeasure;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, uGameTypes, uSonarEntity;

type
  { TTorpedo: Senjata berkecepatan tinggi dengan emisi frekuensi ekstrem }
  TTorpedo = class(TSonarEntity)
  private
    FFuelTime: Double;
    FTargetPos: TPoint2D;
    FIsHoming: Boolean;

    procedure NavigateToTarget(DeltaTime: Double); inline;
  public
    constructor Create(AUID: UInt64; StartPos: TPoint2D; TargetPos: TPoint2D; Homing: Boolean); reintroduce;

    procedure Update(DeltaTime: Double); override;

    property TargetPos: TPoint2D read FTargetPos write FTargetPos;
  end;

  { TDecoy: Pengecoh akustik statis untuk mengalihkan torpedo/musuh }
  TDecoy = class(TSonarEntity)
  private
    FLifeTime: Double;
  public
    constructor Create(AUID: UInt64; StartPos: TPoint2D); reintroduce;

    procedure Update(DeltaTime: Double); override;
  end;

implementation

{ TTorpedo }

constructor TTorpedo.Create(AUID: UInt64; StartPos: TPoint2D; TargetPos: TPoint2D; Homing: Boolean);
begin
  inherited Create(AUID, etTorpedo, StartPos);

  FTargetPos := TargetPos;
  FIsHoming := Homing;
  FFuelTime := 60.0; // Maksimal bahan bakar (detik)
  FSpeed := 45.0;    // Kecepatan sangat tinggi (45 knot)

  // Profil akustik torpedo (Frekuensi sangat tinggi, sawtooth)
  FSignature.BaseFreq := 1250.0;
  FSignature.Amplitude := 30.0;
  FSignature.HarmonicCount := 2;
  FSignature.IsMechanical := True;

  FNoiseLevel := c_BaseAmbientNoise + 60.0;

  if DistanceTo(FTargetPos) > 0 then
    FHeading := CartesianToPolar(FPosition, FTargetPos).Bearing;
end;

procedure TTorpedo.NavigateToTarget(DeltaTime: Double); inline;
var
  TargetBearing, HeadingDiff, TurnRate: Double;
begin
  TargetBearing := CartesianToPolar(FPosition, FTargetPos).Bearing;
  HeadingDiff := TargetBearing - FHeading;

  // Normalisasi selisih sudut untuk mendapatkan rute putaran terdekat (-180 hingga 180)
  if HeadingDiff > 180.0 then HeadingDiff := HeadingDiff - 360.0
  else if HeadingDiff < -180.0 then HeadingDiff := HeadingDiff + 360.0;

  // Kecepatan putar Torpedo (30 derajat per detik - gesit, namun memungkinkan target bermaneuver/menghindar)
  TurnRate := 30.0 * DeltaTime;

  if Abs(HeadingDiff) <= TurnRate then
    FHeading := TargetBearing
  else
    FHeading := FHeading + Sign(HeadingDiff) * TurnRate;

  // Normalisasi Heading 0-360
  if FHeading >= 360.0 then FHeading := FHeading - 360.0
  else if FHeading < 0.0 then FHeading := FHeading + 360.0;
end;

procedure TTorpedo.Update(DeltaTime: Double);
begin
  if not FIsAlive then Exit;

  FFuelTime := FFuelTime - DeltaTime;
  if FFuelTime <= 0.0 then
  begin
    FIsAlive := False;
    FSpeed := 0.0;
    Exit;
  end;

  if FIsHoming then
    NavigateToTarget(DeltaTime);

  inherited Update(DeltaTime);
end;

{ TDecoy }

constructor TDecoy.Create(AUID: UInt64; StartPos: TPoint2D);
begin
  inherited Create(AUID, etDecoy, StartPos);

  FLifeTime := 45.0; // Durasi aktif pengecoh (detik)
  FSpeed := 0.0;     // Statis mengapung di air

  // Profil akustik pengecoh (Sangat bising, meniru kapal selam pemain)
  FSignature.BaseFreq := 250.0;
  FSignature.Amplitude := 50.0;
  FSignature.HarmonicCount := 7;
  FSignature.IsMechanical := True;

  // Tingkat kebisingan lebih besar dari kapal pemain untuk memancing musuh
  FNoiseLevel := 100.0;
end;

procedure TDecoy.Update(DeltaTime: Double);
begin
  if not FIsAlive then Exit;

  FLifeTime := FLifeTime - DeltaTime;
  if FLifeTime <= 0.0 then
  begin
    FIsAlive := False;
    FNoiseLevel := 0.0;
  end;

  inherited Update(DeltaTime);
end;

end.
