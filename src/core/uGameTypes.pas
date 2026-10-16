unit uGameTypes;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math;

type
  { TGameState: Mewakili status utama simulasi saat ini }
  TGameState = (
    gsMainMenu,
    gsRunning,
    gsPaused,
    gsGameOver,
    gsMissionSuccess
  );

  { TEntityType: Jenis-jenis entitas yang dapat terdeteksi oleh radar }
  TEntityType = (
    etUnknown,      // Unclassified blip
    etPlayer,       // ECHO-9
    etHostileSub,   // Hunter-Killer musuh
    etAlliedSub,    // Kapal selam sekutu (IFF valid)
    etBiological,   // Ikan paus / kehidupan laut
    etTorpedo,      // Torpedo aktif (kecepatan sangat tinggi)
    etDecoy         // Alat pengecoh sonar
  );

  { TAudioCue: Konstanta enumerasi untuk pemicu Sound Effect (BASS/FMOD/OpenAL) }
  TAudioCue = (
    acNone,
    acAmbientAbyss, // Suara background dasar laut
    acActivePing,   // PING! melengking
    acTorpedoLaunch,// Suara tekanan peluncuran tabung torpedo
    acImplosion,    // Suara ledakan lambung bawah air
    acCavitation,   // Suara baling-baling saat berisik
    acWhaleCall,    // Nyanyian paus acak
    acAlarmGeneral, // Alarm status UI (Kuning/Merah)
    acDecoyScreech  // Suara nyaring alat decoy saat aktif
  );

  { TPoint2D: Record struktur koordinat presisi tinggi untuk fisika 2D }
  TPoint2D = record
    X, Y: Double;
  end;

  { TVector2D: Record untuk kecepatan dan arah pergerakan }
  TVector2D = record
    X, Y: Double;
  end;

  { TPolarCoord: Koordinat Polar untuk radar (Jarak dan Sudut/Bearing) }
  TPolarCoord = record
    Range: Double;   // Jarak absolut dari pusat radar (pemain)
    Bearing: Double; // Sudut arah datang (0-360 derajat)
  end;

  { TSignalProfile: Parameter matematis untuk sintesis gelombang suara di TAChart }
  TSignalProfile = record
    BaseFreq: Double;     // Frekuensi dasar (Hz)
    Amplitude: Double;    // Kuat sinyal sumber
    HarmonicCount: Integer; // Jumlah harmonik untuk bentuk gelombang (1 = sinus murni)
    IsMechanical: Boolean; // Jika True, gelombang cenderung gergaji (sawtooth). False = sinus organik.
  end;

  { TTacticalLogType: Jenis log untuk dikirim ke UI dan disave ke SQLite }
  TTacticalLogType = (
    tlInfo,
    tlWarning,
    tlAlert,
    tlCritical
  );

const
  { Konstanta Fisika dan Game Loop }
  c_MaxSilentSpeed    = 5.0;     // Maksimal kecepatan (knot) sebelum noise melonjak
  c_ActivePingDur     = 3.0;     // Durasi visibilitas peta setelah Active Ping (detik)
  c_BaseAmbientNoise  = 15.0;    // Level dasar gangguan sinyal (Noise Floor)
  c_MaxSonarRange     = 10000.0; // Jarak maksimum deteksi radar pasif (meter)
  c_PingCooldown      = 10.0;    // Jeda antar penggunaan Active Ping (detik)

{ Fungsi Utilitas Matematis }

// Menghitung jarak Cartesian antara dua titik
function PointDistance(const P1, P2: TPoint2D): Double; inline;

// Konversi derajat ke radian
function DegToRad(Degrees: Double): Double; inline;

// Konversi radian ke derajat
function RadToDeg(Radians: Double): Double; inline;

// Konversi Cartesian ke Polar (Relatif terhadap pusat P1)
function CartesianToPolar(const CenterP1, TargetP2: TPoint2D): TPolarCoord; inline;

// Konversi Polar ke Cartesian (Relatif terhadap pusat P1)
function PolarToCartesian(const CenterP1: TPoint2D; const Polar: TPolarCoord): TPoint2D; inline;

implementation

function PointDistance(const P1, P2: TPoint2D): Double; inline;
begin
  Result := Sqrt(Sqr(P2.X - P1.X) + Sqr(P2.Y - P1.Y));
end;

function DegToRad(Degrees: Double): Double; inline;
begin
  Result := Degrees * (Pi / 180.0);
end;

function RadToDeg(Radians: Double): Double; inline;
begin
  Result := Radians * (180.0 / Pi);
end;

function CartesianToPolar(const CenterP1, TargetP2: TPoint2D): TPolarCoord; inline;
var
  dx, dy: Double;
  b: Double;
begin
  dx := TargetP2.X - CenterP1.X;
  dy := TargetP2.Y - CenterP1.Y; // Note: Asumsi Y membesar ke bawah, mungkin perlu penyesuaian tergantung rendering

  Result.Range := PointDistance(CenterP1, TargetP2);

  if Result.Range = 0 then
    Result.Bearing := 0
  else
  begin
    b := RadToDeg(ArcTan2(dy, dx));
    // Normalisasi Bearing ke 0-360, dimana 0 adalah Utara (Atas), dan rotasi searah jarum jam
    // Penyesuaian matematis standar: Utara adalah -90 deg pada sistem koordinat layar biasa
    b := b + 90.0;
    if b < 0 then
      b := b + 360.0;
    Result.Bearing := b;
  end;
end;

function PolarToCartesian(const CenterP1: TPoint2D; const Polar: TPolarCoord): TPoint2D; inline;
var
  RadAngle: Double;
begin
  // Konversi balik Bearing (0=Utara) ke sudut trigonometri layar
  RadAngle := DegToRad(Polar.Bearing - 90.0);
  Result.X := CenterP1.X + (Polar.Range * Cos(RadAngle));
  Result.Y := CenterP1.Y + (Polar.Range * Sin(RadAngle));
end;

end.
