unit uBioEntity;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, uGameTypes, uSonarEntity;

type
  { TBioEntity: Entitas biologis (ikan paus/fauna laut) dengan pergerakan organik }
  TBioEntity = class(TSonarEntity)
  private
    FWanderTimer: Double;
    FTargetHeading: Double;
    FTargetSpeed: Double;
    FIsSpooked: Boolean;

    { Mengubah arah pergerakan secara acak dan halus }
    procedure UpdateOrganicMovement(DeltaTime: Double); inline;
  public
    constructor Create(AUID: UInt64; StartPos: TPoint2D); reintroduce;

    procedure Update(DeltaTime: Double); override;

    { Reaksi menghindar (berhamburan) jika ada ancaman seperti torpedo mendekat }
    procedure EvadeThreat(const ThreatPos: TPoint2D);
  end;

implementation

constructor TBioEntity.Create(AUID: UInt64; StartPos: TPoint2D);
begin
  inherited Create(AUID, etBiological, StartPos);

  FWanderTimer := 0.0;
  FIsSpooked := False;
  FHeading := Random * 360.0;
  FTargetHeading := FHeading;
  FSpeed := 1.0 + (Random * 2.0); // Kecepatan lambat 1-3 knot
  FTargetSpeed := FSpeed;

  // Profil akustik organik (Frekuensi sangat rendah, gelombang sinus alami)
  FSignature.BaseFreq := 35.0 + Random(50); // 35 - 85 Hz (Misal: Paus)
  FSignature.Amplitude := 5.0 + Random(5);
  FSignature.HarmonicCount := 1;            // Sinus murni, tidak ada distorsi mekanik
  FSignature.IsMechanical := False;

  FNoiseLevel := c_BaseAmbientNoise + 5.0;  // Relatif sunyi, membaur dengan ambient
end;

procedure TBioEntity.EvadeThreat(const ThreatPos: TPoint2D);
var
  Polar: TPolarCoord;
begin
  if not FIsAlive then Exit;

  // Fauna laut akan berbalik arah dari sumber ancaman (lari menjauh)
  Polar := CartesianToPolar(ThreatPos, FPosition);
  FTargetHeading := Polar.Bearing + (Random * 60.0 - 30.0); // Deviasi acak agar tidak lurus

  if FTargetHeading >= 360.0 then FTargetHeading := FTargetHeading - 360.0
  else if FTargetHeading < 0.0 then FTargetHeading := FTargetHeading + 360.0;

  // Berenang lebih cepat karena panik
  FTargetSpeed := 8.0 + (Random * 5.0);
  FWanderTimer := 12.0 + Random(8); // Durasi kepanikan 12-20 detik
  FIsSpooked := True;

  // Peningkatan amplitudo suara karena pergerakan berontak/agresif
  FSignature.Amplitude := 15.0 + Random(10);
  FNoiseLevel := c_BaseAmbientNoise + 20.0;
end;

procedure TBioEntity.UpdateOrganicMovement(DeltaTime: Double); inline;
var
  HeadingDiff: Double;
begin
  FWanderTimer := FWanderTimer - DeltaTime;

  // Tentukan tujuan arah dan kecepatan baru secara periodik (atau setelah panik reda)
  if FWanderTimer <= 0.0 then
  begin
    FTargetHeading := FHeading + (Random * 90.0 - 45.0); // Belok maksimal 45 derajat

    // Normalisasi TargetHeading ke 0-360
    if FTargetHeading >= 360.0 then FTargetHeading := FTargetHeading - 360.0
    else if FTargetHeading < 0.0 then FTargetHeading := FTargetHeading + 360.0;

    FTargetSpeed := 1.0 + (Random * 3.0); // Ubah kecepatan dengan santai
    FWanderTimer := 10.0 + Random(20);    // Tahan arah pergerakan selama 10-30 detik

    // Jika sebelumnya panik, kembalikan profil akustik ke normal (tenang)
    if FIsSpooked then
    begin
      FIsSpooked := False;
      FSignature.Amplitude := 5.0 + Random(5);
      FNoiseLevel := c_BaseAmbientNoise + 5.0;
    end;
  end;

  // Interpolasi arah (Turn Rate sangat lambat, terasa lebih organik dan berbobot)
  HeadingDiff := FTargetHeading - FHeading;

  // Normalisasi selisih sudut agar berputar melalui jalur terpendek
  if HeadingDiff > 180.0 then HeadingDiff := HeadingDiff - 360.0
  else if HeadingDiff < -180.0 then HeadingDiff := HeadingDiff + 360.0;

  // Gunakan faktor belokan dinamis (lebih cepat memutar saat panik)
  if FIsSpooked then
    FHeading := FHeading + (HeadingDiff * DeltaTime * 0.2)
  else
    FHeading := FHeading + (HeadingDiff * DeltaTime * 0.05);

  // Normalisasi ulang FHeading
  if FHeading >= 360.0 then FHeading := FHeading - 360.0
  else if FHeading < 0.0 then FHeading := FHeading + 360.0;

  // Interpolasi kecepatan (Akselerasi/Deselerasi halus)
  if FSpeed < FTargetSpeed then
    FSpeed := Min(FSpeed + (DeltaTime * 0.5), FTargetSpeed)
  else if FSpeed > FTargetSpeed then
    FSpeed := Max(FSpeed - (DeltaTime * 0.2), FTargetSpeed);
end;

procedure TBioEntity.Update(DeltaTime: Double);
begin
  if FIsAlive then
    UpdateOrganicMovement(DeltaTime);

  inherited Update(DeltaTime);
end;

end.
