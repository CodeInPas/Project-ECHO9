unit uThemeConfig;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, BGRABitmapTypes;

const
  { Tipografi }
  UI_FONT_PRIMARY    = 'Consolas';
  UI_FONT_SECONDARY  = 'Arial';

  { Proporsi dan Geometri Visual }
  RADAR_RADIUS_RATIO = 0.45; // Radius maksimal radar = 45% dari nilai terkecil Width/Height
  SWEEP_LINE_WIDTH   = 2.5;  // Ketebalan garis pemindai radar (Sweep Line)

type
  { TThemeConfig: Struktur palet warna terpusat untuk keseluruhan render BGRABitmap }
  TThemeConfig = record
    BgMain: TBGRAPixel;
    BgPanel: TBGRAPixel;
    RadarGrid: TBGRAPixel;
    RadarSweep: TBGRAPixel;
    BlipFriendly: TBGRAPixel;
    BlipHostile: TBGRAPixel;
    BlipUnknown: TBGRAPixel;
    BlipDecoy: TBGRAPixel;
    TextNormal: TBGRAPixel;
    TextAlert: TBGRAPixel;
    GlassBg: TBGRAPixel;
    GlassBorder: TBGRAPixel;
    PhosphorFade: TBGRAPixel;
  end;

{ Mengambil preset tema utama (Abyssal Dark & Telemetry Neon) }
function GetDefaultTheme: TThemeConfig;

implementation

function GetDefaultTheme: TThemeConfig;
begin
  // Fungsi BGRA(R, G, B, A) digunakan untuk inisialisasi yang efisien pada memori

  // Background Utama
  Result.BgMain          := BGRA(7, 11, 16, 255);        // #070B10 Abyssal Obsidian
  Result.BgPanel         := BGRA(13, 21, 32, 255);       // #0D1520 Deep Navy

  // Komponen Radar
  Result.RadarGrid       := BGRA(30, 58, 95, 128);       // #1E3A5F Cyan redup (Semi-transparan)
  Result.RadarSweep      := BGRA(0, 240, 255, 200);      // #00F0FF Phosphor Cyan

  // Entitas (Blip)
  Result.BlipFriendly    := BGRA(0, 255, 102, 255);      // #00FF66 Biometric Green
  Result.BlipHostile     := BGRA(255, 30, 66, 255);      // #FF1E42 Crimson Alert
  Result.BlipUnknown     := BGRA(255, 176, 0, 255);      // #FFB000 Tactical Amber
  Result.BlipDecoy       := BGRA(200, 200, 200, 255);    // Putih Keabuan

  // Tipografi & Log
  Result.TextNormal      := BGRA(0, 240, 255, 255);      // Cyan (Default Telemetry)
  Result.TextAlert       := BGRA(255, 30, 66, 255);      // Merah (Peringatan)

  // UI Glassmorphism (Hover Panel / Tooltip HUD)
  Result.GlassBg         := BGRA(16, 26, 38, 192);       // Gelap transparan
  Result.GlassBorder     := BGRA(30, 58, 95, 255);       // Garis tepi tipis

  // Efek Trail (Warna khusus dengan Alpha sangat rendah untuk membersihkan frame perlahan)
  Result.PhosphorFade    := BGRA(7, 11, 16, 12);         // Menghasilkan efek fading phosphor ekor radar
end;

end.

