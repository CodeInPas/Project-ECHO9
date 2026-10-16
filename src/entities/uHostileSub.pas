unit uHostileSub;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, uGameTypes, uSonarEntity;

type
  { THostileAIState: State Machine untuk kecerdasan buatan kapal musuh }
  THostileAIState = (
    hasPatrol,          // Bergerak acak/terjadwal dengan kecepatan rendah
    hasStopAndListen,   // Mesin dimatikan (FSpeed = 0) untuk mendengarkan sonar pasif
    hasInvestigate,     // Menuju koordinat sumber suara mencurigakan
    hasAttack,          // Mengunci target dan bermanuver agresif
    hasEvade            // Melakukan manuver menghindar (zigzag/menjauh) dari ancaman torpedo
  );

  { THostileSubmarine: Entitas Hunter-Killer AI }
  THostileSubmarine = class(TSonarEntity)
  private
    FAIState: THostileAIState;
    FStateTimer: Double;
    FTargetWaypoint: TPoint2D;
    FEvasionTimer: Double;

    { Memproses transisi dan aksi berdasarkan state saat ini }
    procedure ProcessAI(DeltaTime: Double); inline;
    { Navigasi vektor menuju titik tertentu dengan perputaran sudut halus }
    procedure NavigateTo(Target: TPoint2D; TargetSpeed, DeltaTime: Double); inline;
    { Menghasilkan waypoint acak di sekitar posisi saat ini }
    procedure AssignRandomWaypoint(Radius: Double); inline;
  public
    constructor Create(AUID: UInt64; StartPos: TPoint2D); reintroduce;

    procedure Update(DeltaTime: Double); override;

    { Dipanggil oleh Engine jika emisi suara pemain melampaui threshold deteksi musuh }
    procedure AlertToNoise(const SourcePos: TPoint2D; IsHighThreat: Boolean);

    { Dipanggil oleh Engine jika mendeteksi torpedo mendekat }
    procedure EvadeThreat(const ThreatPos: TPoint2D);

    property AIState: THostileAIState read FAIState;
  end;

implementation

constructor THostileSubmarine.Create(AUID: UInt64; StartPos: TPoint2D);
begin
  inherited Create(AUID, etHostileSub, StartPos);

  FAIState := hasPatrol;
  FStateTimer := 0.0;
  FEvasionTimer := 0.0;

  // Profil Signature spesifik musuh (Sawtooth wave, frekuensi menengah-tinggi)
  FSignature.BaseFreq := 450.0;
  FSignature.Amplitude := 15.0;
  FSignature.HarmonicCount := 5;
  FSignature.IsMechanical := True;

  AssignRandomWaypoint(2000.0);
end;

procedure THostileSubmarine.AssignRandomWaypoint(Radius: Double); inline;
var
  RandAngle: Double;
begin
  RandAngle := Random * Pi * 2;
  FTargetWaypoint.X := FPosition.X + (Cos(RandAngle) * Radius);
  FTargetWaypoint.Y := FPosition.Y + (Sin(RandAngle) * Radius);
end;

procedure THostileSubmarine.NavigateTo(Target: TPoint2D; TargetSpeed, DeltaTime: Double); inline;
var
  Polar: TPolarCoord;
  HeadingDiff: Double;
  TurnRate: Double;
begin
  Polar := CartesianToPolar(FPosition, Target);

  // Perbaikan Tuning: Belokan dinamis yang lebih realistis (tidak instan)
  HeadingDiff := Polar.Bearing - FHeading;

  // Normalisasi selisih sudut (-180 ke 180)
  if HeadingDiff > 180.0 then HeadingDiff := HeadingDiff - 360.0
  else if HeadingDiff < -180.0 then HeadingDiff := HeadingDiff + 360.0;

  // Kecepatan putar maksimum 15 derajat per detik
  TurnRate := 15.0 * DeltaTime;

  if Abs(HeadingDiff) <= TurnRate then
    FHeading := Polar.Bearing
  else
    FHeading := FHeading + Sign(HeadingDiff) * TurnRate;

  // Normalisasi Heading 0-360
  if FHeading >= 360.0 then FHeading := FHeading - 360.0
  else if FHeading < 0.0 then FHeading := FHeading + 360.0;

  // Akselerasi linier yang disesuaikan
  if FSpeed < TargetSpeed then
    FSpeed := Min(FSpeed + (2.5 * DeltaTime), TargetSpeed)
  else if FSpeed > TargetSpeed then
    FSpeed := Max(FSpeed - (1.5 * DeltaTime), TargetSpeed);
end;

procedure THostileSubmarine.ProcessAI(DeltaTime: Double); inline;
begin
  case FAIState of
    hasPatrol:
      begin
        NavigateTo(FTargetWaypoint, 6.0, DeltaTime); // Kecepatan patroli lambat
        FNoiseLevel := c_BaseAmbientNoise + 15.0;

        if DistanceTo(FTargetWaypoint) < 75.0 then
        begin
          FAIState := hasStopAndListen;
          FStateTimer := 15.0 + Random(15);
        end;
      end;

    hasStopAndListen:
      begin
        // Deselerasi hingga berhenti
        if FSpeed > 0.0 then
          FSpeed := Max(FSpeed - (2.0 * DeltaTime), 0.0);

        FNoiseLevel := c_BaseAmbientNoise; // Emisi minimum untuk sensor pasif maksimal

        FStateTimer := FStateTimer - DeltaTime;
        if FStateTimer <= 0.0 then
        begin
          FAIState := hasPatrol;
          AssignRandomWaypoint(3500.0);
        end;
      end;

    hasInvestigate:
      begin
        NavigateTo(FTargetWaypoint, 14.0, DeltaTime); // Bergerak siaga
        FNoiseLevel := c_BaseAmbientNoise + 35.0;

        if DistanceTo(FTargetWaypoint) < 150.0 then
        begin
          FAIState := hasStopAndListen;
          FStateTimer := 12.0; // Berhenti dan pastikan target ada atau tidak
        end;
      end;

    hasAttack:
      begin
        NavigateTo(FTargetWaypoint, 22.0, DeltaTime); // Kecepatan pencegatan penuh
        FNoiseLevel := c_BaseAmbientNoise + 55.0; // Bising maksimum (Kavitasi)
      end;

    hasEvade:
      begin
        NavigateTo(FTargetWaypoint, 25.0, DeltaTime); // Kecepatan darurat maksimum
        FNoiseLevel := c_BaseAmbientNoise + 70.0;

        FEvasionTimer := FEvasionTimer - DeltaTime;
        if FEvasionTimer <= 0.0 then
        begin
          // Selesai menghindar, cek ulang sekitar (kembali menginvestigasi asal ancaman)
          FAIState := hasInvestigate;
        end;
      end;
  end;
end;

procedure THostileSubmarine.Update(DeltaTime: Double);
begin
  if FIsAlive then
    ProcessAI(DeltaTime);

  inherited Update(DeltaTime);
end;

procedure THostileSubmarine.AlertToNoise(const SourcePos: TPoint2D; IsHighThreat: Boolean);
begin
  if (not FIsAlive) or (FAIState = hasEvade) then Exit; // Jangan ganggu jika sedang menghindar

  // Prediksi pergerakan sederhana: kejar ke arah sumber suara
  FTargetWaypoint := SourcePos;

  if IsHighThreat then
    FAIState := hasAttack
  else if FAIState <> hasAttack then
    FAIState := hasInvestigate;
end;

procedure THostileSubmarine.EvadeThreat(const ThreatPos: TPoint2D);
var
  Polar: TPolarCoord;
  EvadeAngle: Double;
begin
  if not FIsAlive then Exit;

  // Kalkulasi sudut membelakangi ancaman (berbalik 180 derajat + manuver acak zigzag)
  Polar := CartesianToPolar(ThreatPos, FPosition);
  EvadeAngle := Polar.Bearing + (Random * 60.0 - 30.0); // Deviasi zigzag +- 30 derajat

  FTargetWaypoint.X := FPosition.X + (Cos(DegToRad(EvadeAngle - 90.0)) * 2500.0);
  FTargetWaypoint.Y := FPosition.Y + (Sin(DegToRad(EvadeAngle - 90.0)) * 2500.0);

  FAIState := hasEvade;
  FEvasionTimer := 8.0; // Lakukan manuver hindaran darurat selama 8 detik
end;

end.
