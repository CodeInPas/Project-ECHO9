unit uMainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  ComCtrls, Buttons, Types, Math, LCLType, sqldb, DB, DBGrids, Menus,
  TAGraph, TASeries, TASources, TAChartUtils,
  BGRABitmap, BGRABitmapTypes,
  uGameTypes, uThemeConfig, uSonarEntity, uPlayerSub, uHostileSub,
  uSignalBuffer, uSonarRenderer, uGameEngine, uAudioManager;

type
  { TMainForm: Form utama simulator kapal selam ECHO-9 dengan arsitektur 2-Panel }
  TMainForm = class(TForm)
    MainMenu1: TMainMenu;
    MenuItem1: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem3: TMenuItem;
    MenuItem4: TMenuItem;
    MenuItem5: TMenuItem;
    MenuItem6: TMenuItem;
    { Panel 1: Main Sonar & Telemetry Terminal (Kiri) }
    pnlLeftTerminal: TPanel;
    pnlSonarScope: TPanel;
    pbSonar: TPaintBox;
    pnlBottomTelemetry: TPanel;
    pnlSpectrogramContainer: TPanel;
    pnlSpecHeader: TPanel;
    lblSpecTitle: TLabel;
    lblSpecLegend: TLabel;
    pnlChartsGrid: TPanel;
    pnlWaterfallBox: TPanel;
    pbWaterfall: TPaintBox;
    lblWaterfallAxis: TLabel;
    pnlNoiseFloorBox: TPanel;
    chartNoiseFloor: TChart;
    lsSignalWave: TLineSeries;
    lsNoiseBaseline: TLineSeries;
    Separator1: TMenuItem;
    udsWaveform: TListChartSource;
    udsBaseline: TListChartSource;
    lblNoiseFloorAxis: TLabel;
    pnlSNRBox: TPanel;
    chartSNR: TChart;
    lsSNRPeak: TLineSeries;
    lsSNRAvg: TLineSeries;
    udsSNRPeak: TListChartSource;
    udsSNRAvg: TListChartSource;
    lblSNRAxis: TLabel;
    pnlCombatLogContainer: TPanel;
    lbCombatLog: TListBox;

    { Panel Overlay Transisi Akhir Permainan }
    pnlMissionEndOverlay: TPanel;
    pnlEndCardBg: TPanel;
    lblMissionStatus: TLabel;
    lblEndStatsLabel: TLabel;
    lblEndStatTime: TLabel;
    lblEndStatScore: TLabel;
    lblEndStatTorps: TLabel;
    btnRestartMission: TSpeedButton;
    btnExitToMenu: TSpeedButton;

    { Panel 2: Tactical Control Board & Properties (Kanan) }
    pnlRightControl: TPanel;
    pnlTopNavTabs: TPanel;
    btnTabNav: TSpeedButton;
    btnTabSensor: TSpeedButton;
    btnTabWeapons: TSpeedButton;
    btnTabDB: TSpeedButton;
    pnlHeaderControl: TPanel;
    lblControlBoard: TLabel;

    { Container Tumpukan Panel Seksi Kontrol }
    pnlControlStack: TPanel;

    { Sub-Panel A: Tactical Operations (Default) }
    pnlOperationsView: TPanel;
    pnlPropulsion: TPanel;
    lblPropulsionTitle: TLabel;
    tbThrust: TTrackBar;
    tbDepth: TTrackBar;
    tbHeading: TTrackBar;
    lblCapThrustSlider: TLabel;
    lblCapDepthSlider: TLabel;
    lblCapHeadingSlider: TLabel;
    pnlReadoutThrust: TPanel;
    lblTitleThrust: TLabel;
    lblValThrust: TLabel;
    pnlReadoutDepth: TPanel;
    lblTitleDepth: TLabel;
    lblValDepth: TLabel;
    pnlReadoutHeading: TPanel;
    lblTitleHeading: TLabel;
    lblValHeading: TLabel;

    pnlSilentRunning: TPanel;
    btnSilentRunning: TSpeedButton;
    lblSilentStatus: TLabel;

    pnlSensors: TPanel;
    lblGainTitle: TLabel;
    lblFreqFilterTitle: TLabel;
    lblPingProtectedTop: TLabel;
    lblPingProtectedBot: TLabel;
    tbGain: TTrackBar;
    tbFreqFilter: TTrackBar;
    pnlGainReadout: TPanel;
    lblValGain: TLabel;
    pnlFreqReadout: TPanel;
    lblValFreq: TLabel;
    pnlActivePingGuard: TPanel;
    btnActivePing: TSpeedButton;

    pnlTorpedoBay: TPanel;
    lblTorpedoTitle: TLabel;
    pnlTube1: TPanel;
    btnTube1: TSpeedButton;
    pnlTube2: TPanel;
    btnTube2: TSpeedButton;
    pnlHullStatus: TPanel;
    lblHullIntegrity: TLabel;
    pnlDecoyControl: TPanel;
    btnDeployDecoy: TSpeedButton;

    { Sub-Panel B: Database Archive (High Scores) }
    pnlDatabaseView: TPanel;
    dsHighScores: TDatasource;
    sqlqHighScores: TSQLQuery;
    dbgHighScores: TDBGrid;
    lblDBTitle: TLabel;
    btnDBRefresh: TSpeedButton;

    { Event Handlers }
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);

    procedure pbSonarPaint(Sender: TObject);
    procedure pbSonarResize(Sender: TObject);
    procedure pbSonarMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure pbSonarMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);

    procedure pbWaterfallPaint(Sender: TObject);
    procedure pbWaterfallResize(Sender: TObject);

    procedure lbCombatLogDrawItem(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);

    procedure tbPropulsionChange(Sender: TObject);
    procedure tbSensorChange(Sender: TObject);
    procedure btnSilentRunningClick(Sender: TObject);
    procedure btnActivePingClick(Sender: TObject);
    procedure btnTube1Click(Sender: TObject);
    procedure btnTube2Click(Sender: TObject);
    procedure btnDeployDecoyClick(Sender: TObject);
    procedure btnNavTabClick(Sender: TObject);

    procedure btnRestartMissionClick(Sender: TObject);
    procedure btnExitToMenuClick(Sender: TObject);
    procedure btnDBRefreshClick(Sender: TObject);
  private
    FEngine: TEchoGameEngine;
    FSonarRenderer: TSonarRenderer;
    FWaterfallBmp: TBGRABitmap;
    FTheme: TThemeConfig;

    FLastTick: QWord;
    FChartRefreshAccum: Double;

    FCurrentDepth: Integer;
    FGainMultiplier: Double;
    FFreqFilterCutoff: Integer;
    FLockedBearing: Double;
    FHoveredEntity: TSonarEntity;
    FMousePos: TPoint;

    { Siklus Game Loop Non-Blocking via Application.OnIdle }
    procedure OnAppIdle(Sender: TObject; var Done: Boolean);

    { Inisialisasi & Konfigurasi }
    procedure ConfigureTAChart;
    procedure ApplyAbyssalTheme;
    procedure SyncControlsFromPlayer;
    procedure InitializeMissionOverlay;
    procedure RefreshDBGrid;

    { Rendering Overlay Tambahan pada Sonar & Spectrogram }
    procedure DrawRadarTacticalHUD(ACanvas: TCanvas);
    procedure RenderWaterfallBitmap;

    { Callback penerima pesan log dari GameEngine }
    procedure HandleTacticalLog(LogType: TTacticalLogType; const Msg: string);
    { Callback pemicu layar transisi menang/kalah }
    procedure HandleMissionEnd(FinalState: TGameState; FinalScore: Integer; TimeSurvived: Double; TorpsFired: Integer);
  public
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

const
  CHART_DISPLAY_POINTS = 128; // Jumlah sampel titik untuk penyegaran cepat 20 FPS

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
var
  DBPath: string;
  AssetDir: string;
begin
  DoubleBuffered := True;
  FTheme := GetDefaultTheme;

  FCurrentDepth := 450;
  FGainMultiplier := 1.5;
  FFreqFilterCutoff := 450;
  FLockedBearing := 180.0;
  FHoveredEntity := nil;
  FChartRefreshAccum := 0.0;

  // Inisialisasi path
  DBPath := ExtractFilePath(Application.ExeName) + 'echo9_core.db';
  AssetDir := ExtractFilePath(Application.ExeName) + 'assets' + PathDelim + 'audio';

  // Create Game Engine dengan parameter AssetDir untuk Audio Manager
  FEngine := TEchoGameEngine.Create(DBPath, AssetDir);
  FEngine.OnTacticalLog := @HandleTacticalLog;
  FEngine.OnMissionEnd := @HandleMissionEnd;

  FSonarRenderer := TSonarRenderer.Create;
  FWaterfallBmp := TBGRABitmap.Create(260, 120, FTheme.BgMain);

  ApplyAbyssalTheme;
  ConfigureTAChart;
  InitializeMissionOverlay;

  // Konfigurasi Grid Database
  dsHighScores.DataSet := sqlqHighScores;
  dbgHighScores.DataSource := dsHighScores;

  // Setel visibilitas tab panel awal
  pnlOperationsView.Visible := True;
  pnlDatabaseView.Visible := False;

  // Mulai misi simulasi pertama
  FEngine.StartNewMission;
  SyncControlsFromPlayer;

  // Tambahkan pesan status awal sesuai referensi visual
  lbCombatLog.Items.AddObject('[WARNING] NOISE SPIKE AT 015°', TObject(PtrInt(Ord(tlWarning))));
  lbCombatLog.Items.AddObject('[ALERT] ACTIVE PING DETECTED', TObject(PtrInt(Ord(tlAlert))));
  lbCombatLog.Items.AddObject('[STATUS] CAVITATION LEVEL: NOMINAL', TObject(PtrInt(Ord(tlInfo))));

  FLastTick := GetTickCount64;
  Application.OnIdle := @OnAppIdle;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  Application.OnIdle := nil;
  if sqlqHighScores.Active then sqlqHighScores.Close;
  if Assigned(FWaterfallBmp) then FWaterfallBmp.Free;
  if Assigned(FSonarRenderer) then FSonarRenderer.Free;
  if Assigned(FEngine) then FEngine.Free;
end;

procedure TMainForm.ApplyAbyssalTheme;
begin
  Color := RGBToColor(7, 11, 16);
  pnlLeftTerminal.Color := RGBToColor(7, 11, 16);
  pnlSonarScope.Color := RGBToColor(7, 11, 16);
  pnlBottomTelemetry.Color := RGBToColor(10, 16, 24);
  pnlSpectrogramContainer.Color := RGBToColor(10, 16, 24);
  pnlSpecHeader.Color := RGBToColor(13, 21, 32);
  pnlChartsGrid.Color := RGBToColor(7, 11, 16);
  pnlCombatLogContainer.Color := RGBToColor(5, 8, 12);

  lbCombatLog.Color := RGBToColor(5, 8, 12);
  lbCombatLog.Font.Name := UI_FONT_PRIMARY;
  lbCombatLog.Font.Size := 9;

  pnlRightControl.Color := RGBToColor(13, 21, 32);
  pnlTopNavTabs.Color := RGBToColor(10, 16, 24);
  pnlHeaderControl.Color := RGBToColor(16, 26, 38);

  pnlControlStack.Color := RGBToColor(13, 21, 32);
  pnlOperationsView.Color := RGBToColor(13, 21, 32);
  pnlDatabaseView.Color := RGBToColor(13, 21, 32);

  pnlPropulsion.Color := RGBToColor(13, 21, 32);
  pnlSilentRunning.Color := RGBToColor(16, 26, 38);
  pnlSensors.Color := RGBToColor(13, 21, 32);
  pnlTorpedoBay.Color := RGBToColor(13, 21, 32);

  dbgHighScores.Color := RGBToColor(10, 16, 24);
  dbgHighScores.FixedColor := RGBToColor(16, 26, 38);
  dbgHighScores.Font.Color := RGBToColor(200, 200, 200);
end;

procedure TMainForm.ConfigureTAChart;
begin
  // Konfigurasi Chart 1: Noise Floor
  chartNoiseFloor.BackColor := RGBToColor(7, 11, 16);
  chartNoiseFloor.Color := RGBToColor(7, 11, 16);
  chartNoiseFloor.Frame.Color := RGBToColor(30, 58, 95);
  chartNoiseFloor.Extent.UseXMin := True;
  chartNoiseFloor.Extent.UseXMax := True;
  chartNoiseFloor.Extent.UseYMin := True;
  chartNoiseFloor.Extent.UseYMax := True;
  chartNoiseFloor.Extent.XMin := 0;
  chartNoiseFloor.Extent.XMax := CHART_DISPLAY_POINTS - 1;
  chartNoiseFloor.Extent.YMin := 0;
  chartNoiseFloor.Extent.YMax := 120;
  chartNoiseFloor.LeftAxis.Grid.Color := RGBToColor(20, 40, 65);
  chartNoiseFloor.BottomAxis.Grid.Color := RGBToColor(20, 40, 65);
  chartNoiseFloor.LeftAxis.Marks.LabelFont.Color := RGBToColor(130, 170, 200);
  chartNoiseFloor.BottomAxis.Marks.Visible := False;

  lsSignalWave.Source := udsWaveform;
  lsSignalWave.SeriesColor := RGBToColor(0, 240, 255); // Cyan

  lsNoiseBaseline.Source := udsBaseline;
  lsNoiseBaseline.SeriesColor := RGBToColor(255, 176, 0); // Amber

  // Konfigurasi Chart 2: Signal-to-Noise Ratio (SNR)
  chartSNR.BackColor := RGBToColor(7, 11, 16);
  chartSNR.Color := RGBToColor(7, 11, 16);
  chartSNR.Frame.Color := RGBToColor(30, 58, 95);
  chartSNR.Extent.UseXMin := True;
  chartSNR.Extent.UseXMax := True;
  chartSNR.Extent.UseYMin := True;
  chartSNR.Extent.UseYMax := True;
  chartSNR.Extent.XMin := 0;
  chartSNR.Extent.XMax := CHART_DISPLAY_POINTS - 1;
  chartSNR.Extent.YMin := 0;
  chartSNR.Extent.YMax := 120;
  chartSNR.LeftAxis.Grid.Color := RGBToColor(20, 40, 65);
  chartSNR.BottomAxis.Grid.Color := RGBToColor(20, 40, 65);
  chartSNR.LeftAxis.Marks.LabelFont.Color := RGBToColor(130, 170, 200);
  chartSNR.BottomAxis.Marks.Visible := False;

  lsSNRPeak.Source := udsSNRPeak;
  lsSNRPeak.SeriesColor := RGBToColor(0, 240, 255);

  lsSNRAvg.Source := udsSNRAvg;
  lsSNRAvg.SeriesColor := RGBToColor(255, 176, 0);
end;

procedure TMainForm.InitializeMissionOverlay;
begin
  pnlMissionEndOverlay.Color := RGBToColor(0, 0, 0);
  pnlMissionEndOverlay.Visible := False;
  pnlMissionEndOverlay.BringToFront;

  pnlEndCardBg.Color := RGBToColor(13, 21, 32);

  lblMissionStatus.Font.Color := RGBToColor(255, 255, 255);
  lblEndStatsLabel.Font.Color := RGBToColor(0, 240, 255);
  lblEndStatTime.Font.Color := RGBToColor(200, 200, 200);
  lblEndStatScore.Font.Color := RGBToColor(200, 200, 200);
  lblEndStatTorps.Font.Color := RGBToColor(200, 200, 200);
end;

procedure TMainForm.RefreshDBGrid;
begin
  FEngine.FetchHighScores(sqlqHighScores);

  if sqlqHighScores.Active and (dbgHighScores.Columns.Count > 0) then
  begin
    // Menyesuaikan tampilan kolom Grid agar selaras dengan tema UI
    dbgHighScores.Columns[0].Width := 50;  // ScoreID
    dbgHighScores.Columns[1].Width := 100; // PlayerName
    dbgHighScores.Columns[2].Width := 80;  // SurvivalTime
    dbgHighScores.Columns[3].Width := 60;  // Score
    dbgHighScores.Columns[4].Width := 120; // RecordDate
  end;
end;

procedure TMainForm.SyncControlsFromPlayer;
var
  Player: TPlayerSubmarine;
begin
  Player := FEngine.EntityManager.Player;
  if not Assigned(Player) then Exit;

  Player.Speed := tbThrust.Position;
  Player.Heading := tbHeading.Position;

  lblValThrust.Caption := Format('%d KTS', [tbThrust.Position]);
  lblValDepth.Caption := Format('%dm', [FCurrentDepth]);
  lblValHeading.Caption := Format('%0.3d°', [tbHeading.Position]);

  if Player.SilentRunning then
  begin
    lblSilentStatus.Caption := 'SILENT RUNNING:' + LineEnding + 'ACTIVE (5 KTS MAX)';
    lblSilentStatus.Font.Color := RGBToColor(255, 215, 0);
    btnSilentRunning.Caption := 'ON';
  end
  else
  begin
    lblSilentStatus.Caption := 'SILENT RUNNING:' + LineEnding + 'OFF (FULL POWER)';
    lblSilentStatus.Font.Color := RGBToColor(140, 160, 180);
    btnSilentRunning.Caption := 'OFF';
  end;

  lblHullIntegrity.Caption := Format('HULL INTEGRITY:' + LineEnding + '%0.0f%%', [Player.HullIntegrity]);
  if Player.HullIntegrity > 60 then
    lblHullIntegrity.Font.Color := RGBToColor(0, 255, 102)
  else if Player.HullIntegrity > 30 then
    lblHullIntegrity.Font.Color := RGBToColor(255, 176, 0)
  else
    lblHullIntegrity.Font.Color := RGBToColor(255, 30, 66);

  if Player.TorpedoCount >= 2 then
  begin
    btnTube1.Caption := 'Tube 1: READY';
    btnTube1.Font.Color := RGBToColor(0, 255, 102);
    btnTube2.Caption := 'Tube 2: LOADING';
    btnTube2.Font.Color := RGBToColor(255, 176, 0);
  end
  else if Player.TorpedoCount = 1 then
  begin
    btnTube1.Caption := 'Tube 1: READY';
    btnTube1.Font.Color := RGBToColor(0, 255, 102);
    btnTube2.Caption := 'Tube 2: EMPTY';
    btnTube2.Font.Color := RGBToColor(120, 120, 120);
  end
  else
  begin
    btnTube1.Caption := 'Tube 1: EMPTY';
    btnTube1.Font.Color := RGBToColor(255, 30, 66);
    btnTube2.Caption := 'Tube 2: EMPTY';
    btnTube2.Font.Color := RGBToColor(255, 30, 66);
  end;

  btnDeployDecoy.Caption := Format('DECOY READY (%d)' + LineEnding + '(COOLDOWN: 0s)', [Player.DecoyCount]);
end;

procedure TMainForm.OnAppIdle(Sender: TObject; var Done: Boolean);
var
  NowTick: QWord;
  DeltaTime: Double;
  i, BinIdx: Integer;
  RawVal: Double;
begin
  NowTick := GetTickCount64;
  DeltaTime := (NowTick - FLastTick) / 1000.0;

  // Jaga frame rate pada ~60 FPS (16 ms)
  if DeltaTime < 0.016 then
  begin
    Sleep(1);
    Done := False;
    Exit;
  end;

  FLastTick := NowTick;

  // Jika game berakhir (menang/kalah), hentikan pergerakan di latar belakang
  if FEngine.State in [gsGameOver, gsMissionSuccess] then
  begin
    Done := False;
    Exit;
  end;

  // Update fisika, AI, dan DSP
  FEngine.Update(DeltaTime);
  FSonarRenderer.Update(DeltaTime);

  // Render Radar Utama pada 60 FPS
  pbSonar.Invalidate;

  // Decoupled Refresh Rate untuk TAChart & Waterfall (20 FPS / tiap 50 ms)
  FChartRefreshAccum := FChartRefreshAccum + DeltaTime;
  if FChartRefreshAccum >= 0.05 then
  begin
    FChartRefreshAccum := 0.0;

    chartNoiseFloor.DisableRedrawing;
    try
      udsWaveform.Clear;
      udsBaseline.Clear;
      for i := 0 to CHART_DISPLAY_POINTS - 1 do
      begin
        RawVal := FEngine.SignalBuffer.GetOrderedValue(MAX_WAVEFORM_POINTS - CHART_DISPLAY_POINTS + i);
        udsWaveform.Add(i, EnsureRange(60.0 + (RawVal * FGainMultiplier * 1.8), 5.0, 115.0));
        udsBaseline.Add(i, EnsureRange(32.0 + (Abs(RawVal) * 0.6), 5.0, 90.0));
      end;
    finally
      chartNoiseFloor.EnableRedrawing;
      chartNoiseFloor.Invalidate;
    end;

    chartSNR.DisableRedrawing;
    try
      udsSNRPeak.Clear;
      udsSNRAvg.Clear;
      for i := 0 to CHART_DISPLAY_POINTS - 1 do
      begin
        BinIdx := (i * (MAX_FFT_BINS - 1)) div (CHART_DISPLAY_POINTS - 1);
        udsSNRPeak.Add(i, EnsureRange(25.0 + FEngine.WaterfallBuffer.GetAmplitude(0, BinIdx) * FGainMultiplier, 5.0, 115.0));
        udsSNRAvg.Add(i, EnsureRange(18.0 + (FEngine.WaterfallBuffer.GetAmplitude(4, BinIdx) * 0.7), 5.0, 85.0));
      end;
    finally
      chartSNR.EnableRedrawing;
      chartSNR.Invalidate;
    end;

    RenderWaterfallBitmap;
    pbWaterfall.Invalidate;
    SyncControlsFromPlayer;
  end;

  Done := False;
end;

procedure TMainForm.FormResize(Sender: TObject);
var
  ThirdW: Integer;
begin
  if Assigned(pnlChartsGrid) then
  begin
    ThirdW := (pnlChartsGrid.ClientWidth - 16) div 3;
    pnlWaterfallBox.Width := ThirdW;
    pnlNoiseFloorBox.Width := ThirdW;
  end;
end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  // Matikan kontrol shortcut saat layar endgame muncul
  if pnlMissionEndOverlay.Visible then Exit;

  case Key of
    VK_SPACE: btnActivePingClick(Self);
    VK_S:     btnSilentRunningClick(Self);
    VK_F:     btnTube1Click(Self);
    VK_D:     btnDeployDecoyClick(Self);
  end;
end;

procedure TMainForm.pbSonarResize(Sender: TObject);
begin
  if Assigned(FSonarRenderer) then
    FSonarRenderer.Resize(pbSonar.Width, pbSonar.Height);
end;

procedure TMainForm.pbSonarPaint(Sender: TObject);
begin
  if not Assigned(FSonarRenderer) then Exit;

  // Render 3-layer BGRABitmap Radar
  FSonarRenderer.Render(pbSonar, FEngine.EntityManager);

  // Gambar Overlay HUD Taktis (Label Scope, Active Ping Ring, dan Target Callout Box)
  DrawRadarTacticalHUD(pbSonar.Canvas);
end;

procedure TMainForm.DrawRadarTacticalHUD(ACanvas: TCanvas);
var
  Player: TPlayerSubmarine;
  TargetEnt: TSonarEntity;
  Polar: TPolarCoord;
  CX, CY, Rad: Integer;
  AngRad, ScreenRad: Double;
  TX, TY: Integer;
  BoxRect: TRect;
  TypeStr: string;
begin
  ACanvas.Brush.Style := bsClear;
  ACanvas.Font.Name := UI_FONT_PRIMARY;
  ACanvas.Font.Size := 11;
  ACanvas.Font.Style := [fsBold];
  ACanvas.Font.Color := RGBToColor(0, 240, 255);

  // Label sudut kiri atas & kanan bawah seperti pada gambar referensi
  ACanvas.TextOut(14, 12, 'PPI SONAR SCOPE');
  ACanvas.Font.Size := 9;
  ACanvas.TextOut(14, 30, '(360°)');

  ACanvas.Font.Size := 10;
  ACanvas.TextOut(pbSonar.Width - 155, pbSonar.Height - 38, 'PPI SONAR SCOPE');
  ACanvas.TextOut(pbSonar.Width - 75, pbSonar.Height - 22, '(360°)');

  Player := FEngine.EntityManager.Player;
  if not Assigned(Player) then Exit;

  CX := pbSonar.Width div 2;
  CY := pbSonar.Height div 2;
  Rad := Trunc(Min(pbSonar.Width, pbSonar.Height) * RADAR_RADIUS_RATIO);

  // Efek visual Active Ping (Gelombang cincin sian terang selama 3 detik)
  if FEngine.ActivePingTimer > 0.0 then
  begin
    ACanvas.Pen.Color := RGBToColor(0, 255, 255);
    ACanvas.Pen.Width := 2;
    ScreenRad := ((c_ActivePingDur - FEngine.ActivePingTimer) / c_ActivePingDur) * Rad;
    ACanvas.Ellipse(
      CX - Trunc(ScreenRad), CY - Trunc(ScreenRad),
      CX + Trunc(ScreenRad), CY + Trunc(ScreenRad)
    );
  end;

  // Tentukan entitas yang sedang di-hover atau pilih entitas terdekat untuk HUD Callout Box
  TargetEnt := FHoveredEntity;
  if (not Assigned(TargetEnt)) or (not TargetEnt.IsAlive) then
  begin
    if FEngine.EntityManager.Entities.Count > 1 then
      TargetEnt := FEngine.EntityManager.Entities[1];
  end;

  if Assigned(TargetEnt) and (TargetEnt <> Player) and TargetEnt.IsAlive then
  begin
    Polar := CartesianToPolar(Player.Position, TargetEnt.Position);
    if Polar.Range <= c_MaxSonarRange then
    begin
      ScreenRad := (Polar.Range / c_MaxSonarRange) * Rad;
      AngRad := DegToRad(Polar.Bearing - 90.0);
      TX := CX + Trunc(Cos(AngRad) * ScreenRad);
      TY := CY + Trunc(Sin(AngRad) * ScreenRad);

      // Gambar Retikel Target Kuning-Hijau
      ACanvas.Pen.Color := RGBToColor(180, 255, 100);
      ACanvas.Pen.Width := 1;
      ACanvas.Ellipse(TX - 12, TY - 12, TX + 12, TY + 12);
      ACanvas.MoveTo(TX - 18, TY); ACanvas.LineTo(TX + 18, TY);
      ACanvas.MoveTo(TX, TY - 18); ACanvas.LineTo(TX, TY + 18);

      // Gambar Kotak Info Glassmorphism (CONTACT-01 Callout)
      BoxRect := Rect(TX + 22, TY - 28, TX + 215, TY + 56);
      ACanvas.Line(TX + 12, TY, BoxRect.Left, TY);

      ACanvas.Brush.Style := bsSolid;
      ACanvas.Brush.Color := RGBToColor(10, 22, 28);
      ACanvas.Pen.Color := RGBToColor(0, 255, 128);
      ACanvas.Rectangle(BoxRect);

      if FEngine.ActivePingTimer > 0.0 then
      begin
        case TargetEnt.EntityType of
          etHostileSub: TypeStr := 'HOSTILE SUB';
          etBiological: TypeStr := 'BIOLOGICAL';
          etTorpedo:    TypeStr := 'TORPEDO!';
          etDecoy:      TypeStr := 'ACOUSTIC DECOY';
          else          TypeStr := 'UNCLASSIFIED';
        end;
      end
      else
        TypeStr := 'UNCLASSIFIED';

      ACanvas.Brush.Style := bsClear;
      ACanvas.Font.Size := 8;
      ACanvas.Font.Color := RGBToColor(200, 255, 220);
      ACanvas.TextOut(BoxRect.Left + 6, BoxRect.Top + 4, Format('CONTACT-%0.2d:', [TargetEnt.UID]));
      ACanvas.TextOut(BoxRect.Left + 6, BoxRect.Top + 16, TypeStr);
      ACanvas.TextOut(BoxRect.Left + 6, BoxRect.Top + 28, Format('(BRG: %0.3d° / RNG: %0.0fm)', [Round(Polar.Bearing), Polar.Range]));

      // Bar Indikator Bearing & Amplitude di dalam Callout
      ACanvas.Pen.Color := RGBToColor(40, 80, 70);
      ACanvas.Line(BoxRect.Left + 4, BoxRect.Top + 44, BoxRect.Right - 4, BoxRect.Top + 44);
      ACanvas.TextOut(BoxRect.Left + 6, BoxRect.Top + 47, 'BEARING');
      ACanvas.Brush.Style := bsSolid;
      ACanvas.Brush.Color := RGBToColor(0, 220, 255);
      ACanvas.FillRect(BoxRect.Left + 65, BoxRect.Top + 50, BoxRect.Left + 65 + Round((Polar.Bearing / 360.0) * 110), BoxRect.Top + 56);

      ACanvas.Brush.Style := bsClear;
      ACanvas.TextOut(BoxRect.Left + 6, BoxRect.Top + 63, 'AMPLITUDE');
      ACanvas.Brush.Style := bsSolid;
      ACanvas.Brush.Color := RGBToColor(255, 190, 50);
      ACanvas.FillRect(BoxRect.Left + 75, BoxRect.Top + 66, BoxRect.Left + 75 + EnsureRange(Round(TargetEnt.Signature.Amplitude * 3), 10, 100), BoxRect.Top + 73);
    end;
  end;
end;

procedure TMainForm.pbSonarMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  i, CX, CY, Rad: Integer;
  Ent: TSonarEntity;
  Player: TPlayerSubmarine;
  Polar: TPolarCoord;
  AngRad, ScreenRad: Double;
  EX, EY: Integer;
begin
  if pnlMissionEndOverlay.Visible then Exit;

  FMousePos := Point(X, Y);
  Player := FEngine.EntityManager.Player;
  if not Assigned(Player) then Exit;

  CX := pbSonar.Width div 2;
  CY := pbSonar.Height div 2;
  Rad := Trunc(Min(pbSonar.Width, pbSonar.Height) * RADAR_RADIUS_RATIO);

  for i := 0 to FEngine.EntityManager.Entities.Count - 1 do
  begin
    Ent := FEngine.EntityManager.Entities[i];
    if (not Ent.IsAlive) or (Ent = Player) then Continue;

    Polar := CartesianToPolar(Player.Position, Ent.Position);
    if Polar.Range > c_MaxSonarRange then Continue;

    ScreenRad := (Polar.Range / c_MaxSonarRange) * Rad;
    AngRad := DegToRad(Polar.Bearing - 90.0);
    EX := CX + Trunc(Cos(AngRad) * ScreenRad);
    EY := CY + Trunc(Sin(AngRad) * ScreenRad);

    if Sqrt(Sqr(X - EX) + Sqr(Y - EY)) <= 20.0 then
    begin
      FHoveredEntity := Ent;
      Break;
    end;
  end;
end;

procedure TMainForm.pbSonarMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  CenterP, ClickP: TPoint2D;
  Polar: TPolarCoord;
begin
  if pnlMissionEndOverlay.Visible then Exit;

  CenterP.X := pbSonar.Width * 0.5;
  CenterP.Y := pbSonar.Height * 0.5;
  ClickP.X := X;
  ClickP.Y := Y;

  Polar := CartesianToPolar(CenterP, ClickP);
  FLockedBearing := Polar.Bearing;
  tbHeading.Position := Round(FLockedBearing) mod 360;
  SyncControlsFromPlayer;
end;

procedure TMainForm.pbWaterfallResize(Sender: TObject);
begin
  if Assigned(FWaterfallBmp) and (pbWaterfall.Width > 0) and (pbWaterfall.Height > 0) then
    FWaterfallBmp.SetSize(pbWaterfall.Width, pbWaterfall.Height);
end;

procedure TMainForm.RenderWaterfallBitmap;
var
  r, c, W, H, BinIdx: Integer;
  Amp: Double;
  P: PBGRAPixel;
begin
  if not Assigned(FWaterfallBmp) then Exit;
  W := FWaterfallBmp.Width;
  H := FWaterfallBmp.Height;
  if (W <= 0) or (H <= 0) then Exit;

  for r := 0 to H - 1 do
  begin
    P := FWaterfallBmp.ScanLine[r];
    for c := 0 to W - 1 do
    begin
      BinIdx := (c * (MAX_FFT_BINS - 1)) div Max(1, W - 1);
      Amp := FEngine.WaterfallBuffer.GetAmplitude(
        (r * (MAX_WATERFALL_ROWS - 1)) div Max(1, H - 1),
        BinIdx
      ) * FGainMultiplier;

      // Pemetaan palet warna Spectrogram (Abyssal Blue -> Cyan -> Amber/Yellow)
      if Amp < 15.0 then
        P^ := BGRA(7, 16 + Round(Amp), 28 + Round(Amp * 2), 255)
      else if Amp < 55.0 then
        P^ := BGRA(0, EnsureRange(Round(Amp * 3.8), 0, 255), EnsureRange(Round(Amp * 4.5), 0, 255), 255)
      else
        P^ := BGRA(255, EnsureRange(Round(140 + Amp), 0, 255), 40, 255);

      Inc(P);
    end;
  end;
  FWaterfallBmp.InvalidateBitmap;
end;

procedure TMainForm.pbWaterfallPaint(Sender: TObject);
begin
  if Assigned(FWaterfallBmp) then
  begin
    FWaterfallBmp.Draw(pbWaterfall.Canvas, 0, 0, True);
    pbWaterfall.Canvas.Brush.Style := bsClear;
    pbWaterfall.Canvas.Pen.Color := RGBToColor(30, 58, 95);
    pbWaterfall.Canvas.Rectangle(0, 0, pbWaterfall.Width, pbWaterfall.Height);
  end;
end;

procedure TMainForm.HandleTacticalLog(LogType: TTacticalLogType; const Msg: string);
var
  Prefix: string;
begin
  case LogType of
    tlInfo:     Prefix := '[STATUS] ';
    tlWarning:  Prefix := '[WARNING] ';
    tlAlert:    Prefix := '[ALERT] ';
    tlCritical: Prefix := '[CRITICAL] ';
  end;

  lbCombatLog.Items.AddObject(Prefix + Msg, TObject(PtrInt(Ord(LogType))));
  if lbCombatLog.Items.Count > 100 then
    lbCombatLog.Items.Delete(0);

  lbCombatLog.ItemIndex := lbCombatLog.Items.Count - 1;
end;

procedure TMainForm.HandleMissionEnd(FinalState: TGameState; FinalScore: Integer; TimeSurvived: Double; TorpsFired: Integer);
begin
  // Tampilkan layar transisi (Overlay)
  pnlMissionEndOverlay.Visible := True;

  if FinalState = gsMissionSuccess then
  begin
    lblMissionStatus.Caption := 'MISSION ACCOMPLISHED';
    lblMissionStatus.Font.Color := RGBToColor(0, 255, 102); // Hijau
  end
  else
  begin
    lblMissionStatus.Caption := 'MISSION FAILED: HULL COMPROMISED';
    lblMissionStatus.Font.Color := RGBToColor(255, 30, 66); // Merah
  end;

  // Format waktu bertahan (MM:SS)
  lblEndStatTime.Caption := Format('TIME SURVIVED : %0.2d:%0.2d', [Trunc(TimeSurvived) div 60, Trunc(TimeSurvived) mod 60]);
  lblEndStatScore.Caption := Format('FINAL SCORE   : %d PTS', [FinalScore]);
  lblEndStatTorps.Caption := Format('TORPEDO FIRED : %d', [TorpsFired]);
end;

procedure TMainForm.lbCombatLogDrawItem(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
var
  LogType: TTacticalLogType;
begin
  if (Index < 0) or (Index >= lbCombatLog.Items.Count) then Exit;

  lbCombatLog.Canvas.Brush.Color := RGBToColor(5, 8, 12);
  lbCombatLog.Canvas.FillRect(ARect);

  LogType := TTacticalLogType(PtrInt(lbCombatLog.Items.Objects[Index]));
  case LogType of
    tlInfo:     lbCombatLog.Canvas.Font.Color := RGBToColor(0, 255, 102);   // Biometric Green
    tlWarning:  lbCombatLog.Canvas.Font.Color := RGBToColor(255, 200, 40);  // Tactical Amber
    tlAlert:    lbCombatLog.Canvas.Font.Color := RGBToColor(255, 120, 30);  // Orange Alert
    tlCritical: lbCombatLog.Canvas.Font.Color := RGBToColor(255, 40, 70);   // Crimson Alert
  end;

  lbCombatLog.Canvas.TextOut(ARect.Left + 6, ARect.Top + 1, lbCombatLog.Items[Index]);
end;

procedure TMainForm.tbPropulsionChange(Sender: TObject);
var
  Player: TPlayerSubmarine;
begin
  Player := FEngine.EntityManager.Player;
  if Assigned(Player) and Player.SilentRunning and (tbThrust.Position > 5) then
    tbThrust.Position := 5;

  FCurrentDepth := tbDepth.Position;
  FLockedBearing := tbHeading.Position;
  SyncControlsFromPlayer;
end;

procedure TMainForm.tbSensorChange(Sender: TObject);
begin
  FGainMultiplier := Max(0.2, tbGain.Position / 50.0);
  FFreqFilterCutoff := tbFreqFilter.Position;

  if tbGain.Position > 70 then
    lblValGain.Caption := 'HIGH'
  else if tbGain.Position > 35 then
    lblValGain.Caption := 'NOM'
  else
    lblValGain.Caption := 'LOW';

  lblValFreq.Caption := Format('%dHz', [FFreqFilterCutoff]);
end;

procedure TMainForm.btnSilentRunningClick(Sender: TObject);
var
  Player: TPlayerSubmarine;
begin
  Player := FEngine.EntityManager.Player;
  if not Assigned(Player) then Exit;

  Player.ToggleSilentRunning;
  if Player.SilentRunning and (tbThrust.Position > 5) then
    tbThrust.Position := 5;

  SyncControlsFromPlayer;
end;

procedure TMainForm.btnActivePingClick(Sender: TObject);
begin
  FEngine.TriggerActivePing;
  SyncControlsFromPlayer;
end;
procedure TMainForm.btnTube1Click(Sender: TObject);
begin
  FEngine.FirePlayerTorpedo(FLockedBearing);
  SyncControlsFromPlayer;
end;

procedure TMainForm.btnTube2Click(Sender: TObject);
begin
  FEngine.FirePlayerTorpedo(FLockedBearing);
  SyncControlsFromPlayer;
end;

procedure TMainForm.btnDeployDecoyClick(Sender: TObject);
begin
  FEngine.DeployPlayerDecoy;
  SyncControlsFromPlayer;
end;

procedure TMainForm.btnNavTabClick(Sender: TObject);
begin
  // Reset judul kontrol default
  lblControlBoard.Caption := 'TACTICAL CONTROL BOARD';

  if Sender = btnTabDB then
  begin
    lblControlBoard.Caption := 'SQLITE HIGH SCORES ARCHIVE';
    pnlOperationsView.Visible := False;
    pnlDatabaseView.Visible := True;
    RefreshDBGrid;
    HandleTacticalLog(tlInfo, Format('SQLITE ARCHIVE ACTIVE | MISSION SCORE: %d', [FEngine.Score]));
  end
  else
  begin
    // Untuk tab NAV, SENSOR, maupun WEAPONS, tampilkan panel operasi utama
    pnlOperationsView.Visible := True;
    pnlDatabaseView.Visible := False;

    // Penyesuaian judul panel opsional berdasarkan tab yang dipilih
    if Sender = btnTabSensor then
      lblControlBoard.Caption := 'TACTICAL CONTROL BOARD - SENSOR SUITE'
    else if Sender = btnTabWeapons then
      lblControlBoard.Caption := 'TACTICAL CONTROL BOARD - WEAPONS BAY';
  end;
end;

procedure TMainForm.btnDBRefreshClick(Sender: TObject);
begin
  RefreshDBGrid;
end;

procedure TMainForm.btnRestartMissionClick(Sender: TObject);
begin
  // Sembunyikan Overlay
  pnlMissionEndOverlay.Visible := False;
  lbCombatLog.Clear;

  // Restart Engine
  FEngine.StartNewMission;

  // Reset UI Control ke nilai awal (Default)
  tbThrust.Position := 5;
  tbDepth.Position := 450;
  tbHeading.Position := 180;

  SyncControlsFromPlayer;
end;

procedure TMainForm.btnExitToMenuClick(Sender: TObject);
begin
  Application.Terminate; // Saat ini langsung keluar. Bisa diganti logika ke Panel Main Menu nanti.
end;

end.
