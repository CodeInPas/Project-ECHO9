unit uAudioManager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, BASS, uGameTypes;

type
  { TAudioManager: Pengendali pusat untuk Sound FX dan Ambience Lingkungan
    menggunakan pustaka BASS audio engine. }
  TAudioManager = class
  private
    FAssetDir: string;
    FIsMuted: Boolean;
    FEngineThrust: Double;

    { Pemetaan enumerasi TAudioCue ke nama file audio }
    FAssetPaths: array[TAudioCue] of string;

    { Penyimpanan Handle Channel BASS untuk audio yang sedang diputar }
    FActiveChannels: array[TAudioCue] of HSTREAM;

    procedure InitializeAssetPaths;
    procedure SystemPlaySound(const FilePath: string; Volume: Double; Loop: Boolean; var ChannelHandle: HSTREAM);
    procedure SystemStopSound(var ChannelHandle: HSTREAM);
  public
    constructor Create(const AAssetDir: string);
    destructor Destroy; override;

    { Kontrol Audio Dasar }
    procedure PlayCue(Cue: TAudioCue; Volume: Double = 1.0; Loop: Boolean = False);
    procedure StopCue(Cue: TAudioCue);
    procedure StopAll;
    procedure SetMute(Value: Boolean);

    { Kontrol Audio Dinamis berdasarkan fisika simulasi }
    procedure UpdateAmbience(Depth: Integer);
    procedure UpdateEngineAcoustics(ThrustKts: Double; IsSilentRunning: Boolean; IsTakingDamage: Boolean);
  end;

implementation

constructor TAudioManager.Create(const AAssetDir: string);
var
  Cue: TAudioCue;
begin
  inherited Create;
  FAssetDir := IncludeTrailingPathDelimiter(AAssetDir);
  FIsMuted := False;
  FEngineThrust := 0.0;

  for Cue := Low(TAudioCue) to High(TAudioCue) do
    FActiveChannels[Cue] := 0;

  InitializeAssetPaths;

  // Inisialisasi BASS Audio Device (-1 = Default Device, 44100Hz, Stereo/Default flags)
  if BASS_Init(-1, 44100, 0, 0, nil) = False then
  begin
    // Jika gagal menginisialisasi hardware audio, Anda bisa mencatatnya ke log jika diperlukan
  end;
end;

destructor TAudioManager.Destroy;
begin
  StopAll;
  BASS_Free(); // Bebaskan resource BASS engine
  inherited Destroy;
end;

procedure TAudioManager.InitializeAssetPaths;
begin
  // Pemetaan file fisik (bisa menggunakan .mp3 atau .ogg secara konsisten)
  FAssetPaths[acNone]          := '';
  FAssetPaths[acAmbientAbyss]  := 'ambience_deep_ocean.mp3';
  FAssetPaths[acActivePing]    := 'sfx_sonar_ping.mp3';
  FAssetPaths[acTorpedoLaunch] := 'sfx_torpedo_tube_fire.mp3';
  FAssetPaths[acImplosion]     := 'sfx_hull_implosion.mp3';
  FAssetPaths[acCavitation]    := 'sfx_propeller_cavitation.mp3';
  FAssetPaths[acWhaleCall]     := 'sfx_whale_moan.mp3';
  FAssetPaths[acAlarmGeneral]  := 'sfx_alarm_klaxon.mp3';
  FAssetPaths[acDecoyScreech]  := 'sfx_decoy_active.mp3';
end;

procedure TAudioManager.SystemPlaySound(const FilePath: string; Volume: Double; Loop: Boolean; var ChannelHandle: HSTREAM);
var
   Flags: DWORD;
begin
  if FIsMuted or (FilePath = '') or not FileExists(FilePath) then Exit;

  // Jika channel lama masih aktif/berjalan, hentikan dulu sebelum membuat stream baru
  if ChannelHandle <> 0 then
    SystemStopSound(ChannelHandle);

  Flags := BASS_SAMPLE_FLOAT;
  if Loop then
    Flags := Flags or BASS_SAMPLE_LOOP;

  // Buat stream file menggunakan BASS (Mendukung MP3, WAV, OGG)
  ChannelHandle := BASS_StreamCreateFile(False, PChar(FilePath), 0, 0, Flags);

  if ChannelHandle <> 0 then
  begin
    // Atur volume (skala BASS_ATTRIB_VOL adalah 0.0 sampai 1.0)
    BASS_ChannelSetAttribute(ChannelHandle, BASS_ATTRIB_VOL, EnsureRange(Volume, 0.0, 1.0));
    BASS_ChannelPlay(ChannelHandle, False);
  end;
end;

procedure TAudioManager.SystemStopSound(var ChannelHandle: HSTREAM);
begin
  if ChannelHandle = 0 then Exit;

  BASS_ChannelStop(ChannelHandle);
  BASS_StreamFree(ChannelHandle);
  ChannelHandle := 0;
end;

procedure TAudioManager.PlayCue(Cue: TAudioCue; Volume: Double = 1.0; Loop: Boolean = False);
var
  FullPath: string;
begin
  if Cue = acNone then Exit;

  // Jika sound bersifat looping dan sudah berjalan, jangan putar ulang dari awal
  if Loop and (FActiveChannels[Cue] <> 0) then Exit;

  FullPath := FAssetDir + FAssetPaths[Cue];
  SystemPlaySound(FullPath, Volume, Loop, FActiveChannels[Cue]);
end;

procedure TAudioManager.StopCue(Cue: TAudioCue);
begin
  if Cue = acNone then Exit;
  SystemStopSound(FActiveChannels[Cue]);
end;

procedure TAudioManager.StopAll;
var
  Cue: TAudioCue;
begin
  for Cue := Low(TAudioCue) to High(TAudioCue) do
    StopCue(Cue);
end;

procedure TAudioManager.SetMute(Value: Boolean);
begin
  FIsMuted := Value;
  if FIsMuted then
     BASS_SetConfig(BASS_CONFIG_GVOL_STREAM, 0) // Mute master global via BASS
  else
     BASS_SetConfig(BASS_CONFIG_GVOL_STREAM, 10000); // Unmute (10000 = 100% volume master BASS)
end;

procedure TAudioManager.UpdateAmbience(Depth: Integer);
var
  AmbienceVolume: Double;
begin
  // Semakin dalam, suara ambience dasar laut semakin kencang/berat
  AmbienceVolume := EnsureRange(0.3 + (Depth / 1000.0) * 0.7, 0.3, 1.0);

  if FActiveChannels[acAmbientAbyss] = 0 then
    PlayCue(acAmbientAbyss, AmbienceVolume, True)
  else
  begin
    // Ubah volume secara *real-time* sesuai kedalaman menggunakan BASS attribute setter
    BASS_ChannelSetAttribute(FActiveChannels[acAmbientAbyss], BASS_ATTRIB_VOL, AmbienceVolume);
  end;
end;

procedure TAudioManager.UpdateEngineAcoustics(ThrustKts: Double; IsSilentRunning: Boolean; IsTakingDamage: Boolean);
begin
  FEngineThrust := ThrustKts;

  // 1. Logika Suara Kavitasi Baling-baling
  if (FEngineThrust > c_MaxSilentSpeed) and (not IsSilentRunning) then
  begin
    if FActiveChannels[acCavitation] = 0 then
      PlayCue(acCavitation, 0.8, True);
  end
  else
  begin
    if FActiveChannels[acCavitation] <> 0 then
      StopCue(acCavitation);
  end;

  // 2. Logika Suara Alarm Peringatan Kerusakan
  if IsTakingDamage then
  begin
    if FActiveChannels[acAlarmGeneral] = 0 then
      PlayCue(acAlarmGeneral, 0.6, True);
  end
  else
  begin
    if FActiveChannels[acAlarmGeneral] <> 0 then
      StopCue(acAlarmGeneral);
  end;
end;

end.
