unit uEntityManager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections, uGameTypes, uSonarEntity,
  uPlayerSub, uHostileSub, uBioEntity, uCountermeasure;

type
  TSonarEntityList = specialize TObjectList<TSonarEntity>;

  { TEntityManager: Mengelola siklus hidup seluruh entitas dalam simulasi }
  TEntityManager = class
  private
    FEntities: TSonarEntityList;
    FPlayer: TPlayerSubmarine;
    FUIDCounter: UInt64;

    function GenerateUID: UInt64; inline;
  public
    constructor Create;
    destructor Destroy; override;

    { Siklus utama }
    procedure UpdateAll(DeltaTime: Double);
    procedure RemoveDeadEntities;
    procedure ClearAll;

    { Spawner (Factory Methods) }
    function SpawnPlayer(StartPos: TPoint2D): TPlayerSubmarine;
    function SpawnHostile(StartPos: TPoint2D): THostileSubmarine;
    function SpawnBio(StartPos: TPoint2D): TBioEntity;
    function SpawnTorpedo(StartPos, TargetPos: TPoint2D; Homing: Boolean): TTorpedo;
    function SpawnDecoy(StartPos: TPoint2D): TDecoy;

    property Entities: TSonarEntityList read FEntities;
    property Player: TPlayerSubmarine read FPlayer;
  end;

implementation

constructor TEntityManager.Create;
begin
  inherited Create;
  FEntities := TSonarEntityList.Create(True); // OwnsObjects = True (Otomatis Free)
  FUIDCounter := 0;
  FPlayer := nil;
end;

destructor TEntityManager.Destroy;
begin
  FEntities.Free;
  inherited Destroy;
end;

function TEntityManager.GenerateUID: UInt64; inline;
begin
  Inc(FUIDCounter);
  Result := FUIDCounter;
end;

procedure TEntityManager.UpdateAll(DeltaTime: Double);
var
  i: Integer;
begin
  // Update dilakukan dari index 0 ke atas
  for i := 0 to FEntities.Count - 1 do
  begin
    FEntities[i].Update(DeltaTime);
  end;
end;

procedure TEntityManager.RemoveDeadEntities;
var
  i: Integer;
begin
  // Iterasi mundur untuk menghapus elemen array tanpa menggeser indeks iterasi
  for i := FEntities.Count - 1 downto 0 do
  begin
    if not FEntities[i].IsAlive then
    begin
      if FEntities[i] = FPlayer then
        FPlayer := nil; // Jangan hancurkan pointer referensi utama jika pemain mati, tapi amankan state

      FEntities.Delete(i); // Memanggil Destroy secara otomatis karena OwnsObjects = True
    end;
  end;
end;

procedure TEntityManager.ClearAll;
begin
  FEntities.Clear;
  FPlayer := nil;
end;

function TEntityManager.SpawnPlayer(StartPos: TPoint2D): TPlayerSubmarine;
begin
  Result := TPlayerSubmarine.Create(GenerateUID, StartPos);
  FEntities.Add(Result);
  FPlayer := Result;
end;

function TEntityManager.SpawnHostile(StartPos: TPoint2D): THostileSubmarine;
begin
  Result := THostileSubmarine.Create(GenerateUID, StartPos);
  FEntities.Add(Result);
end;

function TEntityManager.SpawnBio(StartPos: TPoint2D): TBioEntity;
begin
  Result := TBioEntity.Create(GenerateUID, StartPos);
  FEntities.Add(Result);
end;

function TEntityManager.SpawnTorpedo(StartPos, TargetPos: TPoint2D; Homing: Boolean): TTorpedo;
begin
  Result := TTorpedo.Create(GenerateUID, StartPos, TargetPos, Homing);
  FEntities.Add(Result);
end;

function TEntityManager.SpawnDecoy(StartPos: TPoint2D): TDecoy;
begin
  Result := TDecoy.Create(GenerateUID, StartPos);
  FEntities.Add(Result);
end;

end.

