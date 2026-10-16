unit uCombatLogger;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections, uGameTypes, uDatabaseManager;

type
  { TCombatLogRecord: Struktur data log tempur individu }
  TCombatLogRecord = record
    LogTime: Double;
    LogType: TTacticalLogType;
    Message: string;
  end;

  TCombatLogList = specialize TList<TCombatLogRecord>;

  { TCombatLogger: Penyangga (buffer) memori untuk mencatat aktivitas selama permainan
    berlangsung tanpa memicu operasi I/O disk (SQLite) yang dapat membekukan frame UI. }
  TCombatLogger = class
  private
    FLogs: TCombatLogList;
    FMissionID: string;
    FDBManager: TDatabaseManager;
  public
    constructor Create(ADBManager: TDatabaseManager; const AMissionID: string);
    destructor Destroy; override;

    { Menambahkan log baru ke dalam RAM (O(1) kompleksitas) }
    procedure AddLog(TimeOffset: Double; AType: TTacticalLogType; const AMessage: string); inline;
    procedure Clear;

    { Menyimpan seluruh log ke SQLite dalam satu siklus transaksi tunggal (Batch Commit).
      Hanya dipanggil pada akhir permainan (Mission Success / Game Over). }
    procedure FlushToDatabase;

    property Logs: TCombatLogList read FLogs;
  end;

implementation

constructor TCombatLogger.Create(ADBManager: TDatabaseManager; const AMissionID: string);
begin
  inherited Create;
  FLogs := TCombatLogList.Create;
  FDBManager := ADBManager;
  FMissionID := AMissionID;
end;

destructor TCombatLogger.Destroy;
begin
  FLogs.Free;
  inherited Destroy;
end;

procedure TCombatLogger.AddLog(TimeOffset: Double; AType: TTacticalLogType; const AMessage: string); inline;
var
  NewLog: TCombatLogRecord;
begin
  NewLog.LogTime := TimeOffset;
  NewLog.LogType := AType;
  NewLog.Message := AMessage;
  FLogs.Add(NewLog);
end;

procedure TCombatLogger.Clear;
begin
  FLogs.Clear;
end;

procedure TCombatLogger.FlushToDatabase;
var
  i: Integer;
  LogTypeInt: Integer;
  SQL: string;
  FS: TFormatSettings;
begin
  if (not Assigned(FDBManager)) or (not FDBManager.Connected) or (FLogs.Count = 0) then Exit;

  // Pastikan format desimal SQLite selalu menggunakan titik
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';

  FDBManager.BeginTransaction;
  try
    for i := 0 to FLogs.Count - 1 do
    begin
      LogTypeInt := Ord(FLogs[i].LogType);

      // Escape tanda kutip tunggal untuk mencegah SQL syntax error
      SQL := Format(
        'INSERT INTO CombatLogs (MissionID, LogTime, LogType, Message) VALUES (''%s'', %f, %d, ''%s'');',
        [FMissionID, FLogs[i].LogTime, LogTypeInt, StringReplace(FLogs[i].Message, '''', '''''', [rfReplaceAll])],
        FS
      );

      FDBManager.ExecuteDirect(SQL);
    end;

    FDBManager.CommitTransaction;
    FLogs.Clear; // Kosongkan RAM setelah berhasil disimpan
  except
    FDBManager.RollbackTransaction;
  end;
end;

end.

