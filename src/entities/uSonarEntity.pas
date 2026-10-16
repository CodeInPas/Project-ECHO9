unit uSonarEntity;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, uGameTypes;

type
  { TSonarEntity: Kelas dasar (Base Class) untuk seluruh entitas dalam simulasi }
  TSonarEntity = class
  protected
    FUID: UInt64;
    FEntityType: TEntityType;
    FPosition: TPoint2D;
    FVelocity: TVector2D;
    FHeading: Double;      // Arah hadap dalam derajat (0 = Utara)
    FSpeed: Double;        // Kecepatan absolut (Knot atau m/s)
    FIsAlive: Boolean;     // Status aktif/hancur
    FNoiseLevel: Double;   // Tingkat emisi suara (Desibel)
    FSignature: TSignalProfile; // Profil spektrum suara (DSP)

    { Memperbarui vektor X/Y berdasarkan Speed dan Heading }
    procedure UpdateVelocityVector; inline;
  public
    constructor Create(AUID: UInt64; AType: TEntityType; StartPos: TPoint2D); virtual;
    destructor Destroy; override;

    { Siklus pembaruan fisika dan state yang dipanggil oleh Game Loop }
    procedure Update(DeltaTime: Double); virtual;

    { Respon terhadap ancaman eksternal (Di-override oleh sub-class AI) }
    procedure EvadeThreat(const ThreatPos: TPoint2D); virtual;

    { Kalkulasi spasial relatif }
    function DistanceTo(const TargetPos: TPoint2D): Double; inline;

    property UID: UInt64 read FUID;
    property EntityType: TEntityType read FEntityType;
    property Position: TPoint2D read FPosition write FPosition;
    property Velocity: TVector2D read FVelocity;
    property Heading: Double read FHeading write FHeading;
    property Speed: Double read FSpeed write FSpeed;
    property IsAlive: Boolean read FIsAlive write FIsAlive;
    property NoiseLevel: Double read FNoiseLevel write FNoiseLevel;
    property Signature: TSignalProfile read FSignature write FSignature;
  end;

implementation

constructor TSonarEntity.Create(AUID: UInt64; AType: TEntityType; StartPos: TPoint2D);
begin
  inherited Create;
  FUID := AUID;
  FEntityType := AType;
  FPosition := StartPos;
  FIsAlive := True;
  FSpeed := 0.0;
  FHeading := 0.0;
  FVelocity.X := 0.0;
  FVelocity.Y := 0.0;
  FNoiseLevel := c_BaseAmbientNoise;
end;

destructor TSonarEntity.Destroy;
begin
  inherited Destroy;
end;

procedure TSonarEntity.UpdateVelocityVector; inline;
var
  RadAngle: Double;
begin
  // Rotasi trigonometri dengan asumsi Bearing 0 adalah Utara (-90 derajat di Cartesian)
  RadAngle := DegToRad(FHeading - 90.0);
  FVelocity.X := FSpeed * Cos(RadAngle);
  FVelocity.Y := FSpeed * Sin(RadAngle);
end;

procedure TSonarEntity.Update(DeltaTime: Double);
begin
  if not FIsAlive then Exit;

  // Jika memiliki kecepatan, update koordinat Cartesian berdasarkan DeltaTime
  if FSpeed > 0.0 then
  begin
    UpdateVelocityVector;
    FPosition.X := FPosition.X + (FVelocity.X * DeltaTime);
    FPosition.Y := FPosition.Y + (FVelocity.Y * DeltaTime);
  end;
end;

procedure TSonarEntity.EvadeThreat(const ThreatPos: TPoint2D);
begin
  // Implementasi dasar kosong.
  // Entitas seperti Kapal Selam Musuh (THostileSubmarine) atau Fauna (TBioEntity)
  // akan meng-override prosedur ini untuk menentukan manuver menghindar mereka sendiri.
end;

function TSonarEntity.DistanceTo(const TargetPos: TPoint2D): Double; inline;
begin
  Result := PointDistance(FPosition, TargetPos);
end;

end.
