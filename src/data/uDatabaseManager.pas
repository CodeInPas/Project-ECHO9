unit uDatabaseManager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqldb, sqlite3conn;

type
  { TDatabaseManager: Pembungkus koneksi SQLite untuk penyimpanan asinkron/batch }
  TDatabaseManager = class
  private
    FConn: TSQLite3Connection;
    FTrans: TSQLTransaction;
    FQuery: TSQLQuery;
    FDBPath: string;

    procedure InitializeSchema;
    function GetConnected: Boolean; // <-- Perbaikan: Deklarasi fungsi getter
  public
    constructor Create(const ADBPath: string);
    destructor Destroy; override;

    procedure Connect;
    procedure Disconnect;

    { Transaksi dasar untuk eksekusi batch }
    procedure BeginTransaction; inline;
    procedure CommitTransaction; inline;
    procedure RollbackTransaction; inline;

    { Mengeksekusi DML murni tanpa result set (INSERT/UPDATE/DELETE) }
    procedure ExecuteDirect(const SQL: string); inline;

    { Referensi Query untuk pembacaan data (SELECT) }
    function GetQuery(const SQL: string): TSQLQuery;

    property Connected: Boolean read GetConnected; // <-- Perbaikan: Menggunakan getter method
  end;

implementation

constructor TDatabaseManager.Create(const ADBPath: string);
begin
  inherited Create;
  FDBPath := ADBPath;

  FConn := TSQLite3Connection.Create(nil);
  FTrans := TSQLTransaction.Create(nil);
  FQuery := TSQLQuery.Create(nil);

  FConn.Transaction := FTrans;
  FQuery.DataBase := FConn;
  FQuery.Transaction := FTrans;

  FConn.DatabaseName := FDBPath;
end;

destructor TDatabaseManager.Destroy;
begin
  Disconnect;
  FQuery.Free;
  FTrans.Free;
  FConn.Free;
  inherited Destroy;
end;

// <-- Perbaikan: Implementasi fungsi getter
function TDatabaseManager.GetConnected: Boolean;
begin
  Result := Assigned(FConn) and FConn.Connected;
end;

procedure TDatabaseManager.Connect;
begin
  if GetConnected then Exit;

  try
    // Buat file DB jika belum ada
    if not FileExists(FDBPath) then
    begin
      ForceDirectories(ExtractFilePath(FDBPath));
      // TSQLite3Connection akan otomatis membuat file jika belum ada
      // saat Connected := True, asalkan direktori sudah ada
    end;

    FConn.Connected := True;
    InitializeSchema;
  except
    on E: Exception do
      WriteLn('DB Connection Error: ', E.Message); // Fallback debug
  end;
end;

procedure TDatabaseManager.Disconnect;
begin
  if FQuery.Active then FQuery.Close;
  if FTrans.Active then FTrans.Rollback;
  if GetConnected then FConn.Connected := False;
end;

procedure TDatabaseManager.InitializeSchema;
const
  SQL_CREATE_LOGS =
    'CREATE TABLE IF NOT EXISTS CombatLogs (' +
    '  LogID INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  MissionID TEXT,' +
    '  LogTime REAL,' +
    '  LogType INTEGER,' +
    '  Message TEXT' +
    ');';

  SQL_CREATE_SCORES =
    'CREATE TABLE IF NOT EXISTS HighScores (' +
    '  ScoreID INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  PlayerName TEXT,' +
    '  SurvivalTime REAL,' +
    '  Score INTEGER,' +
    '  RecordDate DATETIME DEFAULT CURRENT_TIMESTAMP' +
    ');';
begin
  if not GetConnected then Exit;

  BeginTransaction;
  try
    FConn.ExecuteDirect(SQL_CREATE_LOGS);
    FConn.ExecuteDirect(SQL_CREATE_SCORES);
    CommitTransaction;
  except
    RollbackTransaction;
  end;
end;

procedure TDatabaseManager.BeginTransaction; inline;
begin
  if not FTrans.Active then FTrans.StartTransaction;
end;

procedure TDatabaseManager.CommitTransaction; inline;
begin
  if FTrans.Active then FTrans.Commit;
end;

procedure TDatabaseManager.RollbackTransaction; inline;
begin
  if FTrans.Active then FTrans.Rollback;
end;

procedure TDatabaseManager.ExecuteDirect(const SQL: string); inline;
begin
  FConn.ExecuteDirect(SQL);
end;

function TDatabaseManager.GetQuery(const SQL: string): TSQLQuery;
begin
  if FQuery.Active then FQuery.Close;
  FQuery.SQL.Text := SQL;
  Result := FQuery;
end;

end.
