unit uGameEngine;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, sqldb,
  uGameTypes, uSonarEntity, uPlayerSub, uHostileSub, uBioEntity, uCountermeasure,
  uEntityManager, uSignalBuffer, uAcousticSim, uDatabaseManager, uCombatLogger,
  uAudioManager; // Tambahkan uAudioManager

type
  { Event callback untuk mengirim pesan log ke antarmuka (MainForm) secara real-time }
  TOnTacticalLogEvent = procedure(LogType: TTacticalLogType; const Msg: string) of object;

  { Event callback untuk memicu overlay transisi layar akhir (Menang/Kalah) }
  TOnMissionEndEvent = procedure(FinalState: TGameState; FinalScore: Integer; TimeSurvived: Double; TorpsFired: Integer) of object;

  { TEchoGameEngine: Pengendali inti siklus hidup simulasi, fisika, AI, dan kondisi menang/kalah }
  TEchoGameEngine = class
  private
    FState: TGameState;
    FEntityManager: TEntityManager;
    FAcousticSim: TAcousticSimulator;
    FSignalBuffer: TSignalRingBuffer;
    FWaterfallBuffer: TWaterfallBuffer;
    FDBManager: TDatabaseManager;
    FCombatLogger: TCombatLogger;
    FAudioManager: TAudioManager; // Referensi Audio Manager

    FMissionTime: Double;
    FActivePingTimer: Double;
    FHostileFireCooldown: Double;
    FExtractionPoint: TPoint2D;
    FScore: Integer;
    FTorpedoesFired: Integer;

    FOnTacticalLog: TOnTacticalLogEvent;
    FOnMissionEnd: TOnMissionEndEvent;

    procedure LogEvent(AType: TTacticalLogType; const AMessage: string);
    procedure ProcessInteractions(DeltaTime: Double);
    procedure EvaluateMissionStatus;
    procedure UpdateWaterfallFFT;
    procedure EndMission(FinalState: TGameState; const ReasonMsg: string);
  public
    constructor Create(const ADBPath: string; const AAssetDir: string); // Ubah Constructor
    destructor Destroy; override;

    { Inisialisasi & Kontrol Sesi }
    procedure StartNewMission;
    procedure PauseMission;
    procedure ResumeMission;

    { Siklus Utama Game Loop (Dipanggil via OnIdle / High-Precision Timer) }
    procedure Update(DeltaTime: Double);

    { Komando Taktis Pemain (Dipanggil dari Panel 2 Control Board) }
    procedure TriggerActivePing;
    procedure FirePlayerTorpedo(TargetBearing: Double);
    procedure DeployPlayerDecoy;

    { Akses Data High Score dari Database }
    procedure FetchHighScores(TargetDataSet: TSQLQuery);

    property State: TGameState read FState;
    property EntityManager: TEntityManager read FEntityManager;
    property AcousticSim: TAcousticSimulator read FAcousticSim;
    property SignalBuffer: TSignalRingBuffer read FSignalBuffer;
    property WaterfallBuffer: TWaterfallBuffer read FWaterfallBuffer;
    property MissionTime: Double read FMissionTime;
    property ActivePingTimer: Double read FActivePingTimer;
    property ExtractionPoint: TPoint2D read FExtractionPoint;
    property Score: Integer read FScore;
    property TorpedoesFired: Integer read FTorpedoesFired;
    property AudioManager: TAudioManager read FAudioManager; // Expose Audio Manager

    property OnTacticalLog: TOnTacticalLogEvent read FOnTacticalLog write FOnTacticalLog;
    property OnMissionEnd: TOnMissionEndEvent read FOnMissionEnd write FOnMissionEnd;
  end;

implementation

constructor TEchoGameEngine.Create(const ADBPath: string; const AAssetDir: string);
begin
  inherited Create;
  Randomize;

  FState := gsMainMenu;
  FMissionTime := 0.0;
  FActivePingTimer := 0.0;
  FHostileFireCooldown := 0.0;
  FScore := 0;
  FTorpedoesFired := 0;

  FDBManager := TDatabaseManager.Create(ADBPath);
  FDBManager.Connect;

  FCombatLogger := TCombatLogger.Create(FDBManager, FormatDateTime('yyyymmdd_hhnnss', Now));
  FEntityManager := TEntityManager.Create;
  FAcousticSim := TAcousticSimulator.Create;
  FSignalBuffer := TSignalRingBuffer.Create;
  FWaterfallBuffer := TWaterfallBuffer.Create;

  // Inisialisasi Audio Manager
  FAudioManager := TAudioManager.Create(AAssetDir);
end;

destructor TEchoGameEngine.Destroy;
begin
  FAudioManager.Free; // Bebaskan Audio Manager
  FWaterfallBuffer.Free;
  FSignalBuffer.Free;
  FAcousticSim.Free;
  FEntityManager.Free;
  FCombatLogger.Free;
  FDBManager.Free;
  inherited Destroy;
end;

procedure TEchoGameEngine.LogEvent(AType: TTacticalLogType; const AMessage: string);
var
  TimeStr, FullMsg: string;
begin
  TimeStr := Format('[%0.1fs] ', [FMissionTime]);
  FullMsg := TimeStr + AMessage;

  // Simpan ke buffer RAM (Zero Disk I/O)
  FCombatLogger.AddLog(FMissionTime, AType, AMessage);

  // Kirim ke UI jika handler terpasang
  if Assigned(FOnTacticalLog) then
    FOnTacticalLog(AType, FullMsg);
end;

procedure TEchoGameEngine.StartNewMission;
var
  StartPos, SpawnPos: TPoint2D;
  i: Integer;
  Polar: TPolarCoord;
begin
  FEntityManager.ClearAll;
  FSignalBuffer.Clear;
  FWaterfallBuffer.Clear;
  FCombatLogger.Clear;
  FAudioManager.StopAll; // Hentikan semua suara dari misi sebelumnya

  FMissionTime := 0.0;
  FActivePingTimer := 0.0;
  FHostileFireCooldown := 15.0;
  FScore := 0;
  FTorpedoesFired := 0;

  // Spawn Kapal Pemain di titik pusat (0, 0)
  StartPos.X := 0.0;
  StartPos.Y := 0.0;
  FEntityManager.SpawnPlayer(StartPos);

  // Titik Ekstraksi di Utara (Bearing 0, Jarak 7500m)
  FExtractionPoint.X := 0.0;
  FExtractionPoint.Y := -7500.0;

  // Spawn 3 Kapal Selam Musuh (Hunter-Killer) pada posisi melingkar acak
  for i := 1 to 3 do
  begin
    Polar.Range := 3000.0 + Random(4000);
    Polar.Bearing := Random(360);
    SpawnPos := PolarToCartesian(StartPos, Polar);
    FEntityManager.SpawnHostile(SpawnPos);
  end;

  // Spawn 4 Entitas Biologis (Paus) sebagai pengacau sinyal akustik
  for i := 1 to 4 do
  begin
    Polar.Range := 1500.0 + Random(5000);
    Polar.Bearing := Random(360);
    SpawnPos := PolarToCartesian(StartPos, Polar);
    FEntityManager.SpawnBio(SpawnPos);
  end;

  FState := gsRunning;
  LogEvent(tlInfo, 'SYSTEM ONLINE: SILENT RUNNING ENGAGED. NAVIGATE TO EXTRACTION.');

  // Putar Ambience Laut Dalam
  FAudioManager.PlayCue(acAmbientAbyss, 0.5, True);
end;

procedure TEchoGameEngine.PauseMission;
begin
  if FState = gsRunning then
  begin
    FState := gsPaused;
    LogEvent(tlInfo, 'SIMULATION PAUSED.');
  end;
end;

procedure TEchoGameEngine.ResumeMission;
begin
  if FState = gsPaused then
  begin
    FState := gsRunning;
    LogEvent(tlInfo, 'SIMULATION RESUMED.');
  end;
end;

procedure TEchoGameEngine.TriggerActivePing;
var
  Player: TPlayerSubmarine;
  i: Integer;
  Ent: TSonarEntity;
begin
  if FState <> gsRunning then Exit;
  Player := FEntityManager.Player;
  if not Assigned(Player) then Exit;

  if Player.CanPing then
  begin
    Player.FirePing;
    FActivePingTimer := c_ActivePingDur;
    LogEvent(tlAlert, 'ACTIVE SONAR PING TRANSMITTED! POSITION EXPOSED TO HOSTILES!');

    // Putar Suara Active Ping
    FAudioManager.PlayCue(acActivePing, 1.0, False);

    // Seluruh kapal musuh dalam radius sonar langsung mengunci posisi pemain
    for i := 0 to FEntityManager.Entities.Count - 1 do
    begin
      Ent := FEntityManager.Entities[i];
      if (Ent.IsAlive) and (Ent is THostileSubmarine) then
      begin
        if Ent.DistanceTo(Player.Position) <= c_MaxSonarRange then
          THostileSubmarine(Ent).AlertToNoise(Player.Position, True);
      end;
    end;
  end
  else
    LogEvent(tlWarning, Format('ACTIVE PING ON COOLDOWN (%0.1fs REMAINING).', [Player.PingCooldownTimer]));
end;

procedure TEchoGameEngine.FirePlayerTorpedo(TargetBearing: Double);
var
  Player: TPlayerSubmarine;
  Polar: TPolarCoord;
  SpawnPos, TargetPos: TPoint2D;
begin
  if FState <> gsRunning then Exit;
  Player := FEntityManager.Player;
  if (not Assigned(Player)) or (not Player.IsAlive) then Exit;

  if Player.TorpedoCount <= 0 then
  begin
    LogEvent(tlWarning, 'TORPEDO BAY EMPTY! CANNOT FIRE.');
    Exit;
  end;

  Player.TorpedoCount := Player.TorpedoCount - 1;
  Inc(FTorpedoesFired); // Rekam statistik

  // Spawn torpedo 40m di depan arah tembak agar tidak menabrak lambung sendiri
  Polar.Bearing := TargetBearing;
  Polar.Range := 40.0;
  SpawnPos := PolarToCartesian(Player.Position, Polar);

  Polar.Range := c_MaxSonarRange;
  TargetPos := PolarToCartesian(Player.Position, Polar);

  FEntityManager.SpawnTorpedo(SpawnPos, TargetPos, False);
  LogEvent(tlAlert, Format('TORPEDO LAUNCHED ON BEARING %0.0f DEG!', [TargetBearing]));

  // Putar Suara Peluncuran Torpedo
  FAudioManager.PlayCue(acTorpedoLaunch, 0.9, False);
end;

procedure TEchoGameEngine.DeployPlayerDecoy;
var
  Player: TPlayerSubmarine;
  Polar: TPolarCoord;
  SpawnPos: TPoint2D;
begin
  if FState <> gsRunning then Exit;
  Player := FEntityManager.Player;
  if (not Assigned(Player)) or (not Player.IsAlive) then Exit;

  if Player.DecoyCount <= 0 then
  begin
    LogEvent(tlWarning, 'NO ACOUSTIC DECOYS REMAINING!');
    Exit;
  end;

  Player.DecoyCount := Player.DecoyCount - 1;

  // Lepaskan decoy 30m di belakang buritan kapal pemain
  Polar.Bearing := Player.Heading + 180.0;
  if Polar.Bearing >= 360.0 then Polar.Bearing := Polar.Bearing - 360.0;
  Polar.Range := 30.0;
  SpawnPos := PolarToCartesian(Player.Position, Polar);

  FEntityManager.SpawnDecoy(SpawnPos);
  LogEvent(tlInfo, 'ACOUSTIC DECOY DEPLOYED. EVASIVE MANEUVERS RECOMMENDED.');

  // Putar Suara Decoy (Looping, idealnya dihentikan saat decoy hancur, namun untuk simplifikasi diputar sekali durasi panjang)
  FAudioManager.PlayCue(acDecoyScreech, 0.7, False);
end;

procedure TEchoGameEngine.ProcessInteractions(DeltaTime: Double);
var
  i, j: Integer;
  Ent, OtherEnt, BestDecoy: TSonarEntity;
  Player: TPlayerSubmarine;
  Hostile: THostileSubmarine;
  Torp: TTorpedo;
  Dist, MinDecoyDist: Double;
  Polar: TPolarCoord;
  SpawnPos: TPoint2D;
begin
  Player := FEntityManager.Player;
  if (not Assigned(Player)) or (not Player.IsAlive) then Exit;

  if FHostileFireCooldown > 0.0 then
    FHostileFireCooldown := FHostileFireCooldown - DeltaTime;

  for i := 0 to FEntityManager.Entities.Count - 1 do
  begin
    Ent := FEntityManager.Entities[i];
    if not Ent.IsAlive then Continue;

    // 1. Interaksi AI Kapal Selam Musuh
    if Ent is THostileSubmarine then
    begin
      Hostile := THostileSubmarine(Ent);
      Dist := Hostile.DistanceTo(Player.Position);

      // Deteksi kebisingan pasif pemain oleh sensor musuh
      if (Player.NoiseLevel > (c_BaseAmbientNoise + 12.0)) and (Dist < 4500.0) then
        Hostile.AlertToNoise(Player.Position, Player.NoiseLevel > 60.0);

      // Tembak torpedo jika musuh dalam mode Attack dan jarak < 3000m
      if (Hostile.AIState = hasAttack) and (Dist < 3000.0) and (FHostileFireCooldown <= 0.0) then
      begin
        FHostileFireCooldown := 25.0; // Jeda tembak antar torpedo musuh
        Polar := CartesianToPolar(Hostile.Position, Player.Position);
        Polar.Range := 45.0;
        SpawnPos := PolarToCartesian(Hostile.Position, Polar);

        FEntityManager.SpawnTorpedo(SpawnPos, Player.Position, True);
        LogEvent(tlCritical, Format('WARNING: HOSTILE TORPEDO TRANSIENT DETECTED AT BEARING %0.0f!', [Polar.Bearing]));

        // Putar Suara Alarm Peringatan Torpedo Musuh
        FAudioManager.PlayCue(acAlarmGeneral, 0.8, False);
      end;
    end
    // 1.5 Interaksi AI Entitas Biologis (Paus) - Sesekali bernyanyi
    else if Ent is TBioEntity then
    begin
      if Random < (0.05 * DeltaTime) then // Probabilitas kecil tiap frame
        FAudioManager.PlayCue(acWhaleCall, 0.4, False);
    end
    // 2. Interaksi Torpedo (Homing, Pengalihan Decoy, dan Detonasi Benturan)
    else if Ent is TTorpedo then
    begin
      Torp := TTorpedo(Ent);

      // Cari apakah ada Decoy aktif di sekitar torpedo untuk mengalihkan kuncian
      BestDecoy := nil;
      MinDecoyDist := 1500.0;
      for j := 0 to FEntityManager.Entities.Count - 1 do
      begin
        OtherEnt := FEntityManager.Entities[j];
        if (OtherEnt.IsAlive) and (OtherEnt.EntityType = etDecoy) then
        begin
          Dist := Torp.DistanceTo(OtherEnt.Position);
          if Dist < MinDecoyDist then
          begin
            MinDecoyDist := Dist;
            BestDecoy := OtherEnt;
          end;
        end;
      end;

      if Assigned(BestDecoy) then
        Torp.TargetPos := BestDecoy.Position
      else if Torp.DistanceTo(Player.Position) < 2000.0 then
        Torp.TargetPos := Player.Position;

      // Evaluasi jarak benturan (Detonasi jarak dekat < 25 meter) dan deteksi peringatan dini
      for j := 0 to FEntityManager.Entities.Count - 1 do
      begin
        OtherEnt := FEntityManager.Entities[j];
        if (not OtherEnt.IsAlive) or (OtherEnt = Torp) or (OtherEnt.EntityType = etTorpedo) then Continue;

        Dist := Torp.DistanceTo(OtherEnt.Position);

        // Fitur Peringatan Dini AI Musuh (Menghindar jika torpedo mendekat < 1200m)
        if OtherEnt is THostileSubmarine then
        begin
          if (Dist < 1200.0) and (THostileSubmarine(OtherEnt).AIState <> hasEvade) then
          begin
            THostileSubmarine(OtherEnt).EvadeThreat(Torp.Position);
            LogEvent(tlInfo, Format('SONAR CONTACT-%0.2d IS EXECUTING EVASIVE MANEUVERS!', [OtherEnt.UID]));
          end;
        end;

        if Dist <= 25.0 then
        begin
          Torp.IsAlive := False; // Torpedo meledak

          // Putar Suara Ledakan (Implosion)
          FAudioManager.PlayCue(acImplosion, 1.0, False);

          if OtherEnt = Player then
          begin
            Player.TakeDamage(55.0);
            LogEvent(tlCritical, Format('DIRECT TORPEDO HIT! HULL INTEGRITY AT %0.0f%%!', [Player.HullIntegrity]));
          end
          else if OtherEnt is THostileSubmarine then
          begin
            OtherEnt.IsAlive := False;
            Inc(FScore, 500);
            LogEvent(tlInfo, 'TARGET DESTROYED: HOSTILE SUBMARINE IMPLOSION CONFIRMED!');
          end
          else if OtherEnt is TDecoy then
          begin
            OtherEnt.IsAlive := False;
            Inc(FScore, 100);
            LogEvent(tlInfo, 'DECOY DESTROYED BY TORPEDO. THREAT NEUTRALIZED.');
            FAudioManager.StopCue(acDecoyScreech); // Matikan suara decoy
          end
          else if OtherEnt is TBioEntity then
          begin
            OtherEnt.IsAlive := False;
            Dec(FScore, 250);
            LogEvent(tlWarning, 'BIOLOGICAL CONTACT HIT BY TORPEDO!');
          end;

          Break;
        end;
      end;
    end;
  end;
end;

procedure TEchoGameEngine.UpdateWaterfallFFT;
var
  FFTRow: TFFTArray;
  i: Integer;
  Ent: TSonarEntity;
  Player: TPlayerSubmarine;
  BinIdx: Integer;
  Dist, Amp: Double;
begin
  Player := FEntityManager.Player;
  if not Assigned(Player) then Exit;

  // Isi dasar spektrum dengan noise floor acak
  for i := 0 to MAX_FFT_BINS - 1 do
    FFTRow[i] := Random * (c_BaseAmbientNoise * 0.4);

  // Petakan frekuensi setiap entitas ke dalam bin FFT (0..255 mewakili 0..1500 Hz)
  for i := 0 to FEntityManager.Entities.Count - 1 do
  begin
    Ent := FEntityManager.Entities[i];
    if (not Ent.IsAlive) or (Ent = Player) then Continue;

    Dist := Ent.DistanceTo(Player.Position);
    if Dist > c_MaxSonarRange then Continue;

    BinIdx := EnsureRange(Round((Ent.Signature.BaseFreq / 1500.0) * (MAX_FFT_BINS - 1)), 0, MAX_FFT_BINS - 1);
    Amp := (Ent.Signature.Amplitude * 20.0) / Max(1.0, Dist * 0.02);

    FFTRow[BinIdx] := Min(120.0, FFTRow[BinIdx] + Amp);
  end;

  FWaterfallBuffer.PushRow(FFTRow);
end;

procedure TEchoGameEngine.EvaluateMissionStatus;
var
  Player: TPlayerSubmarine;
  i, AliveHostiles: Integer;
begin
  Player := FEntityManager.Player;

  // 1. Cek Kekalahan (Kapal Hancur)
  if (not Assigned(Player)) or (not Player.IsAlive) then
  begin
    EndMission(gsGameOver, 'CRITICAL FAILURE: ECHO-9 DESTROYED IN THE ABYSS.');
    Exit;
  end;

  // 2. Cek Kemenangan via Titik Ekstraksi
  if Player.DistanceTo(FExtractionPoint) <= 150.0 then
  begin
    Inc(FScore, 1000);
    EndMission(gsMissionSuccess, 'MISSION ACCOMPLISHED: EXTRACTION ZONE REACHED SAFELY.');
    Exit;
  end;

  // 3. Cek Kemenangan via Eliminasi Seluruh Musuh
  AliveHostiles := 0;
  for i := 0 to FEntityManager.Entities.Count - 1 do
    if (FEntityManager.Entities[i].IsAlive) and (FEntityManager.Entities[i].EntityType = etHostileSub) then
      Inc(AliveHostiles);

  if AliveHostiles = 0 then
  begin
    Inc(FScore, 750);
    EndMission(gsMissionSuccess, 'MISSION ACCOMPLISHED: ALL HOSTILE THREATS ELIMINATED.');
  end;
end;

procedure TEchoGameEngine.EndMission(FinalState: TGameState; const ReasonMsg: string);
var
  FS: TFormatSettings;
  SQL: string;
begin
  FState := FinalState;
  LogEvent(tlCritical, ReasonMsg);

  FAudioManager.StopAll; // Matikan semua suara saat misi berakhir

  // Batch commit seluruh log tempur dari RAM ke SQLite
  FCombatLogger.FlushToDatabase;

  // Simpan skor akhir ke tabel HighScores
  if FDBManager.Connected then
  begin
    FS := DefaultFormatSettings;
    FS.DecimalSeparator := '.';
    FDBManager.BeginTransaction;
    try
      SQL := Format(
        'INSERT INTO HighScores (PlayerName, SurvivalTime, Score) VALUES (''COMMANDER'', %f, %d);',
        [FMissionTime, FScore], FS
      );
      FDBManager.ExecuteDirect(SQL);
      FDBManager.CommitTransaction;
    except
      FDBManager.RollbackTransaction;
    end;
  end;

  // Pemicu Overlay/Screen Transisi di Form Utama
  if Assigned(FOnMissionEnd) then
    FOnMissionEnd(FinalState, FScore, FMissionTime, FTorpedoesFired);
end;

procedure TEchoGameEngine.FetchHighScores(TargetDataSet: TSQLQuery);
begin
  if not FDBManager.Connected then Exit;

  if TargetDataSet.Active then TargetDataSet.Close;

  TargetDataSet.SQL.Text := 'SELECT ScoreID, PlayerName, SurvivalTime, Score, RecordDate ' +
                            'FROM HighScores ' +
                            'ORDER BY Score DESC ' +
                            'LIMIT 10;';
  TargetDataSet.DataBase := FDBManager.GetQuery('').DataBase;
  TargetDataSet.Transaction := FDBManager.GetQuery('').Transaction;
  TargetDataSet.Open;
end;

procedure TEchoGameEngine.Update(DeltaTime: Double);
begin
  if FState <> gsRunning then Exit;

  // Batasi DeltaTime maksimum (0.1s) untuk mencegah lonjakan fisika jika jendela sempat digeser
  if DeltaTime > 0.1 then DeltaTime := 0.1;

  FMissionTime := FMissionTime + DeltaTime;

  if FActivePingTimer > 0.0 then
  begin
    FActivePingTimer := FActivePingTimer - DeltaTime;
    if FActivePingTimer < 0.0 then FActivePingTimer := 0.0;
  end;

  FEntityManager.UpdateAll(DeltaTime);
  ProcessInteractions(DeltaTime);
  FEntityManager.RemoveDeadEntities;

  if Assigned(FEntityManager.Player) then
  begin
    FAcousticSim.ProcessAudioFrame(
      DeltaTime,
      uAcousticSim.TSonarEntityList(FEntityManager.Entities),
      FEntityManager.Player.Position,
      FSignalBuffer
    );
    UpdateWaterfallFFT;

    // Perbarui status audio dinamis (Engine/Kavitasi dan Ambience Kedalaman)
    // PERBAIKAN: Karena Depth hanya di-tracking di UI, kita kirimkan default 450m
    FAudioManager.UpdateAmbience(450);
    FAudioManager.UpdateEngineAcoustics(
      FEntityManager.Player.Speed,
      FEntityManager.Player.SilentRunning,
      FEntityManager.Player.HullIntegrity < 50.0
    );
  end;

  EvaluateMissionStatus;
end;

end.
