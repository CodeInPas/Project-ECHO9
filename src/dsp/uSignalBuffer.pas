unit uSignalBuffer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math;

const
  MAX_WAVEFORM_POINTS = 1024;
  MAX_WATERFALL_ROWS  = 128;
  MAX_FFT_BINS        = 256;

type
  TWaveformArray = array[0..MAX_WAVEFORM_POINTS - 1] of Double;
  TFFTArray = array[0..MAX_FFT_BINS - 1] of Double;

  { TSignalRingBuffer: Penyimpanan sirkular berkinerja tinggi untuk gelombang waktu riil }
  TSignalRingBuffer = class
  private
    FBuffer: TWaveformArray;
    FHead: Integer;
  public
    constructor Create;
    procedure Push(Value: Double); inline;
    procedure PushBlock(const Values: array of Double);
    procedure Clear;

    { Mengambil nilai berurutan (0 = data terlama, MAX-1 = data terbaru) }
    function GetOrderedValue(Index: Integer): Double; inline;
  end;

  { TWaterfallBuffer: Penyimpanan sirkular 2D untuk riwayat Spectrogram (Waterfall) }
  TWaterfallBuffer = class
  private
    FGrid: array[0..MAX_WATERFALL_ROWS - 1] of TFFTArray;
    FHeadRow: Integer;
  public
    constructor Create;
    procedure PushRow(const FFTBins: TFFTArray);
    procedure Clear;

    { Mengambil amplitudo pada koordinat spesifik (Row 0 = terbaru) }
    function GetAmplitude(AgeRow, BinIndex: Integer): Double; inline;
  end;

implementation

{ TSignalRingBuffer }

constructor TSignalRingBuffer.Create;
begin
  inherited Create;
  Clear;
end;

procedure TSignalRingBuffer.Clear;
begin
  // Inisialisasi cepat dengan 0.0 (IEEE 754 representasi byte 0 = 0.0)
  FillChar(FBuffer, SizeOf(FBuffer), 0);
  FHead := 0;
end;

procedure TSignalRingBuffer.Push(Value: Double); inline;
begin
  FBuffer[FHead] := Value;
  FHead := (FHead + 1) mod MAX_WAVEFORM_POINTS;
end;

procedure TSignalRingBuffer.PushBlock(const Values: array of Double);
var
  i: Integer;
begin
  for i := 0 to High(Values) do
    Push(Values[i]);
end;

function TSignalRingBuffer.GetOrderedValue(Index: Integer): Double; inline;
var
  ActualIndex: Integer;
begin
  if (Index < 0) or (Index >= MAX_WAVEFORM_POINTS) then Exit(0.0);

  // Memetakan indeks linier ke indeks sirkular (memastikan data terlama di awal)
  ActualIndex := (FHead + Index) mod MAX_WAVEFORM_POINTS;
  Result := FBuffer[ActualIndex];
end;

{ TWaterfallBuffer }

constructor TWaterfallBuffer.Create;
begin
  inherited Create;
  Clear;
end;

procedure TWaterfallBuffer.Clear;
begin
  FillChar(FGrid, SizeOf(FGrid), 0);
  FHeadRow := 0;
end;

procedure TWaterfallBuffer.PushRow(const FFTBins: TFFTArray);
begin
  // Geser baris ke atas secara sirkular (Head bergerak mundur)
  FHeadRow := (FHeadRow - 1 + MAX_WATERFALL_ROWS) mod MAX_WATERFALL_ROWS;

  // Salin memori mentah untuk performa maksimal dibanding iterasi elemen
  Move(FFTBins[0], FGrid[FHeadRow][0], SizeOf(TFFTArray));
end;

function TWaterfallBuffer.GetAmplitude(AgeRow, BinIndex: Integer): Double; inline;
var
  ActualRow: Integer;
begin
  if (AgeRow < 0) or (AgeRow >= MAX_WATERFALL_ROWS) or
     (BinIndex < 0) or (BinIndex >= MAX_FFT_BINS) then Exit(0.0);

  ActualRow := (FHeadRow + AgeRow) mod MAX_WATERFALL_ROWS;
  Result := FGrid[ActualRow][BinIndex];
end;

end.
