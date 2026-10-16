unit uAcousticSim;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Generics.Collections,
  uGameTypes, uSonarEntity, uSignalBuffer;

type
  TSonarEntityList = specialize TObjectList<TSonarEntity>;

  { TAcousticSimulator: Mesin DSP untuk mensintesis gelombang suara prosedural }
  TAcousticSimulator = class
  private
    FTimeAccumulator: Double;
    FAmbientNoiseBase: Double;

    { Sintesis gelombang tunggal dari satu entitas }
    function SynthesizeEntityWave(TimePos: Double; const Sig: TSignalProfile; Distance, Speed: Double): Double; inline;
  public
    constructor Create;

    { Menghasilkan 1 blok buffer gelombang komposit dari semua sumber suara }
    procedure ProcessAudioFrame(DeltaTime: Double; Entities: TSonarEntityList; PlayerPos: TPoint2D; OutBuffer: TSignalRingBuffer);

    property AmbientNoiseBase: Double read FAmbientNoiseBase write FAmbientNoiseBase;
  end;

const
  TWO_PI = 2.0 * Pi;

implementation

constructor TAcousticSimulator.Create;
begin
  inherited Create;
  FTimeAccumulator := 0.0;
  FAmbientNoiseBase := c_BaseAmbientNoise;
end;

function TAcousticSimulator.SynthesizeEntityWave(TimePos: Double; const Sig: TSignalProfile; Distance, Speed: Double): Double; inline;
var
  i: Integer;
  Wave, Freq, HarmAmp: Double;
  Phase: Double;
begin
  if Distance > c_MaxSonarRange then Exit(0.0);

  // Doppler Shift sederhana berdasarkan kecepatan (asumsi pergerakan radial kasar)
  // Dalam simulasi nyata butuh vektor relatif, di sini disederhanakan
  Freq := Sig.BaseFreq + (Speed * 0.5);

  // Atenuasi (Pelemahan sinyal karena jarak) - Inverse Square Law disesuaikan
  // Dibatasi minimal 1.0 agar tidak division by zero
  HarmAmp := Sig.Amplitude / Max(1.0, (Distance * 0.05));

  if HarmAmp < 0.1 then Exit(0.0); // Culling sinyal terlalu lemah

  Wave := 0.0;

  if Sig.IsMechanical then
  begin
    // Sawtooth / Square approximation untuk mekanikal
    for i := 1 to Sig.HarmonicCount do
    begin
      Phase := TimePos * (Freq * i);
      // Sawtooth additive synthesis: Sin(x)/1 + Sin(2x)/2 + Sin(3x)/3 ...
      Wave := Wave + (Sin(TWO_PI * Phase) / i);
    end;
  end
  else
  begin
    // Sine organik
    for i := 1 to Sig.HarmonicCount do
    begin
      Phase := TimePos * (Freq * (1.0 + (i * 0.1))); // Harmonik tidak beraturan
      Wave := Wave + Sin(TWO_PI * Phase);
    end;
  end;

  Result := Wave * HarmAmp;
end;

procedure TAcousticSimulator.ProcessAudioFrame(DeltaTime: Double; Entities: TSonarEntityList; PlayerPos: TPoint2D; OutBuffer: TSignalRingBuffer);
var
  SampleCount, s, i: Integer;
  TimeStep, CurrentTime, CompositeWave: Double;
  Ent: TSonarEntity;
  Dist: Double;
begin
  // Asumsikan sample rate simulasi rendah untuk visual TAChart (misal 1000 Hz)
  SampleCount := Trunc(DeltaTime * 1000.0);
  if SampleCount <= 0 then SampleCount := 1;

  TimeStep := DeltaTime / SampleCount;

  for s := 0 to SampleCount - 1 do
  begin
    CurrentTime := FTimeAccumulator + (s * TimeStep);

    // Dasar noise (White noise)
    CompositeWave := (Random * FAmbientNoiseBase) - (FAmbientNoiseBase * 0.5);

    // Superposisi seluruh sumber suara aktif
    for i := 0 to Entities.Count - 1 do
    begin
      Ent := Entities[i];
      if (not Ent.IsAlive) or (Ent.EntityType = etPlayer) then Continue; // Lewati pemain sendiri

      Dist := Ent.DistanceTo(PlayerPos);
      if Dist > c_MaxSonarRange then Continue;

      // Tambahkan emisi suara entitas ke gelombang komposit
      CompositeWave := CompositeWave + SynthesizeEntityWave(CurrentTime, Ent.Signature, Dist, Ent.Speed);
    end;

    OutBuffer.Push(CompositeWave);
  end;

  FTimeAccumulator := FTimeAccumulator + DeltaTime;

  // Cegah presisi hilang (Floating Point Overflow) dengan mereset akumulator periodik
  if FTimeAccumulator > 10000.0 then
    FTimeAccumulator := FTimeAccumulator - 10000.0;
end;

end.

