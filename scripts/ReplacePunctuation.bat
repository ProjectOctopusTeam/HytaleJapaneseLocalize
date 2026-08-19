@echo off
rem ---------------------------------------------------------------------------
rem  ReplacePunctuation.bat
rem    repo root no ja-JP haika no *.lang file no touten (U+3001) / kuten (U+3002) wo
rem    han-kaku no comma / period ni okikaeru.
rem
rem  Usage:
rem    scripts\ReplacePunctuation.bat          ... <repo root>\ja-JP wo shori
rem    scripts\ReplacePunctuation.bat <dir>    ... shitei folder wo shori
rem    scripts\ReplacePunctuation.bat /dry     ... dry-run (file wa kakikaenai)
rem    scripts\ReplacePunctuation.bat <dir> /dry
rem ---------------------------------------------------------------------------
setlocal EnableExtensions

rem  bat wa scripts\ ni aru node, oya folder (repo root) wo kijun ni suru
for %%I in ("%~dp0..") do set "LJP_ROOT=%%~fI"
set "LJP_TARGET=%~1"
set "LJP_DRYRUN=0"

if /i "%~1"=="/dry" (
    set "LJP_TARGET="
    set "LJP_DRYRUN=1"
)
if /i "%~2"=="/dry" set "LJP_DRYRUN=1"

powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText('%~f0');$m='#PS'+'_BEGIN';$i=$s.IndexOf($m);if($i -lt 0){Write-Error 'script marker not found';exit 1};Invoke-Expression $s.Substring($i+$m.Length)"

exit /b %ERRORLEVEL%

#PS_BEGIN
$ErrorActionPreference = 'Stop'

$target = $env:LJP_TARGET
if ([string]::IsNullOrWhiteSpace($target)) {
    $target = Join-Path $env:LJP_ROOT 'ja-JP'
}
$dryRun = ($env:LJP_DRYRUN -eq '1')

if (-not (Test-Path -LiteralPath $target -PathType Container)) {
    Write-Host "[ERROR] Folder not found: $target" -ForegroundColor Red
    exit 1
}

# .bat を ASCII のまま保つため、句読点はコードポイントで生成する
$touten = [string][char]0x3001   # 、
$kuten  = [string][char]0x3002   # 。

# 直後が改行のときは半角スペースを入れない。
#   \r / \n  : ファイル上の実際の改行 (行末)
#   \x5Cn     : lang ファイル内の改行エスケープ "\n"
#   [ \t]    : すでに空白があるので二重に入れない
#   $        : ファイル末尾
$noSpace = '(?=\r|\n|\x5Cn|[ \t]|$)'

$enc = New-Object System.Text.UTF8Encoding($false)   # UTF-8 (BOM なし)

$files = @(Get-ChildItem -LiteralPath $target -Recurse -File -Filter *.lang)
if ($files.Count -eq 0) {
    Write-Host "[WARN] *.lang not found in: $target" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Target : $target"
Write-Host "Files  : $($files.Count)"
if ($dryRun) { Write-Host "Mode   : DRY-RUN (no file is modified)" -ForegroundColor Yellow }
Write-Host ""

$changedFiles = 0
$totalTouten  = 0
$totalKuten   = 0

foreach ($f in $files) {
    $text = [IO.File]::ReadAllText($f.FullName, $enc)

    $countT = ([regex]::Matches($text, $touten)).Count
    $countK = ([regex]::Matches($text, $kuten)).Count
    if (($countT + $countK) -eq 0) { continue }

    $new = $text
    # 1) 改行/空白の直前 -> スペースなし   2) それ以外 -> 直後に半角スペース
    $new = [regex]::Replace($new, $touten + $noSpace, ',')
    $new = $new.Replace($touten, ', ')
    $new = [regex]::Replace($new, $kuten + $noSpace, '.')
    $new = $new.Replace($kuten, '. ')

    if ($new -eq $text) { continue }

    if (-not $dryRun) {
        [IO.File]::WriteAllText($f.FullName, $new, $enc)
    }

    $changedFiles++
    $totalTouten += $countT
    $totalKuten  += $countK

    $rel = $f.FullName.Substring($target.TrimEnd('\').Length).TrimStart('\')
    Write-Host ("  {0,-60} touten:{1,4}  kuten:{2,4}" -f $rel, $countT, $countK)
}

Write-Host ""
Write-Host ("Changed files : {0} / {1}" -f $changedFiles, $files.Count)
Write-Host ("Replaced      : {0} = {1}   {2} = {3}" -f $touten, $totalTouten, $kuten, $totalKuten)
if ($dryRun) { Write-Host "(DRY-RUN: nothing was written)" -ForegroundColor Yellow }
Write-Host ""
exit 0
