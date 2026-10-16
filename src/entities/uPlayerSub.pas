unit uPlayerSub;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, uGameTypes, uSonarEntity;

type
  { TPlayerSubmarine: Entitas khusus kapal selam yang dikendalikan oleh pemain (ECHO-9) }
  TPlayerSubmarine = class(TSonarEntity)
  private
    FHullIntegrity: Double;
    FSilentRunning: Boolean;
    FTorpedoCount: Integer;
    FDecoyCount: Integer;
    FPingCooldownTimer: Double;

    { Mengkalkulasi tingkat emisi suara berdasarkan kecepatan dan mode senyap }
    procedure CalculateDynamicNoise; inline;
  public
    constructor Create(AUID: UInt64; StartPos: TPoint2D); reintroduce;

    procedure Update(DeltaTime: Double); override;

    procedure ToggleSilentRunning; inline;
    function CanPing: Boolean; inline;
    procedure FirePing;
    procedure TakeDamage(DamageAmount: Double); inline;

    property HullIntegrity: Double read FHullIntegrity;
    property SilentRunning: Boolean read FSilentRunning write FSilentRunning;
    property TorpedoCount: Integer read FTorpedoCount write FTorpedoCount;
    property DecoyCount: Integer read FDecoyCount write FDecoyCount;
    property PingCooldownTimer: Double read FPingCooldownTimer;
  end;

implementation

constructor TPlayerSubmarine.Create(AUID: UInt64; StartPos: TPoint2D);
begin
  inherited Create(AUID, etPlayer, StartPos);

  FHullIntegrity := 100.0;
  FSilentRunning := True;
  FTorpedoCount := 6;
  FDecoyCount := 3;
  FPingCooldownTimer := 0.0;

  // Profil akustik dasar kapal selam ECHO-9
  FSignature.BaseFreq := 250.0;
  FSignature.Amplitude := 10.0;
  FSignature.HarmonicCount := 3;
  FSignature.IsMechanical := True;

  CalculateDynamicNoise;
end;

procedure TPlayerSubmarine.CalculateDynamicNoise; inline;
begin
  if FSilentRunning then
  begin
    if FSpeed <= c_MaxSilentSpeed then
      FNoiseLevel := c_BaseAmbientNoise + (FSpeed * 0.5)
    else
      // Penalti eksponensial berupa kavitasi bising jika ngebut saat mode senyap
      FNoiseLevel := c_BaseAmbientNoise + Power(FSpeed, 2.0);
  end
  else
  begin
    // Kebisingan standar reaktor dan baling-baling aktif
    FNoiseLevel := c_BaseAmbientNoise + 20.0 + (FSpeed * 3.0);
  end;
end;

procedure TPlayerSubmarine.Update(DeltaTime: Double);
begin
  inherited Update(DeltaTime);

  if not FIsAlive then Exit;

  // Pembaruan waktu tunggu (cooldown) Active Ping
  if FPingCooldownTimer > 0.0 then
  begin
    FPingCooldownTimer := FPingCooldownTimer - DeltaTime;
    if FPingCooldownTimer < 0.0 then
      FPingCooldownTimer := 0.0;
  end;

  CalculateDynamicNoise;
end;

procedure TPlayerSubmarine.ToggleSilentRunning; inline;
begin
  FSilentRunning := not FSilentRunning;
end;

function TPlayerSubmarine.CanPing: Boolean; inline;
begin
  Result := (FPingCooldownTimer <= 0.0) and FIsAlive;
end;

procedure TPlayerSubmarine.FirePing;
begin
  if CanPing then
  begin
    FPingCooldownTimer := c_PingCooldown;
    // Lonjakan kebisingan ekstrem ke sistem sekitar yang memancing respons AI Musuh
    FNoiseLevel := 250.0;
  end;
end;

procedure TPlayerSubmarine.TakeDamage(DamageAmount: Double); inline;
begin
  if not FIsAlive then Exit;

  FHullIntegrity := FHullIntegrity - DamageAmount;
  if FHullIntegrity <= 0.0 then
  begin
    FHullIntegrity := 0.0;
    FIsAlive := False;
    FSpeed := 0.0; // Mesin mati setelah hancur
  end;
end;

end.

