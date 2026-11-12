# AI系のCLIとアプリを最新にする（Windows 用・会社の 3090 機 nsk3090 で作成）。定期実行 ai-apps-daily-update-win から呼ばれる。手でも叩ける。
#   powershell -NoProfile -ExecutionPolicy Bypass -File ~/claude-dotfiles/scripts/ai_update.ps1              … CLI更新＋更新待ちのアプリを再起動
#   powershell -NoProfile -ExecutionPolicy Bypass -File ~/claude-dotfiles/scripts/ai_update.ps1 -NoRestart   … CLI更新だけ。アプリは「更新待ち」を報告するだけ
# Mac 版は ai_update.sh。決まりは同じ（2026-11-12 深石さんと決めた）:
#   ・agent-browser は 0.34.0 固定運用なので更新しない
#   ・アプリを再起動するのは「起動中」かつ「更新待ち」のものだけ（無駄に落とさない）
#   ・Claude デスクトップは定期実行そのものが中で動くので再起動しない
#   ・claude remote-control は再起動しない（旧版のままなら報告するだけ）
#   ・失敗した更新を別の方法でやり直さない
# 出力: 1行1件。先頭の語で種別が分かる（更新 / 変化なし / 再起動 / 更新待ち / 注意 / 失敗）。終了コードは常に 0。
#
# ⚠️ Claude デスクトップ（MSIX）の中から動かすと、%LOCALAPPDATA% などへの書き込みがアプリ専用フォルダ
#   （%LOCALAPPDATA%\Packages\<アプリ>\LocalCache\）に振り替えられ、Start-Process で起動した子プロセスも同じ囲いの中で動く
#   （2026-11-12 nsk3090 で試験ファイルにより実測）。WMI（Win32_Process.Create）で起動したプロセスは囲いの外で動き、
#   画面のあるセッションにウィンドウも出る（同日実測）。そこでこのスクリプトは、囲いの中で呼ばれたと分かったら
#   自分自身を WMI で起動し直し、終わるのを待って結果を表示する（-Inner が付いた方が本体）。
#   アプリの更新待ちの見分け方（同日 nsk3090 で確認した置き場所）:
#     Antigravity … %LOCALAPPDATA%\antigravity-updater\ のインストーラの版 > 入っている版
#     Grok Bot    … %LOCALAPPDATA%\sand-updater\ のインストーラの版 > 入っている版
#     Cursor      … %TEMP%\vscode-stable-user-x64-*\CodeSetup-stable-<版>.exe の版 > 入っている版
#     ChatGPT（Codex アプリ・Store）と Claude デスクトップは見分ける方法が無い → 前回の版と比べて「更新」だけ報告する

param(
  [switch]$NoRestart,
  [switch]$Inner,
  [string]$LogPath
)

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
$LA = $env:LOCALAPPDATA
$WorkDir = Join-Path $env:USERPROFILE '.ai_update'   # ログと前回の版（ユーザーフォルダは振り替えられない）
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null

# ---------------- 外側: 囲いの中なら WMI で起動し直す ----------------
function Test-InPackage {
  $name = "_ai_update_probe_$([guid]::NewGuid().ToString('N')).txt"
  $probe = Join-Path $LA $name
  try { Set-Content -Path $probe -Value 'x' -ErrorAction Stop } catch { return $false }
  $redirected = @(Get-ChildItem -Path (Join-Path $LA 'Packages') -Directory -ErrorAction SilentlyContinue |
    Where-Object { Test-Path (Join-Path $_.FullName "LocalCache\Local\$name") }).Count -gt 0
  Remove-Item $probe -ErrorAction SilentlyContinue
  return $redirected
}

if (-not $Inner -and (Test-InPackage)) {
  $log = Join-Path $WorkDir ("run_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
  $self = $MyInvocation.MyCommand.Path
  $cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$self`" -Inner -LogPath `"$log`""
  if ($NoRestart) { $cmd += ' -NoRestart' }
  try {
    $r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmd } -ErrorAction Stop
  } catch { Write-Output "失敗: 囲いの外での起動（WMI）ができなかった: $($_.Exception.Message)"; exit 0 }
  if ($r.ReturnValue -ne 0) { Write-Output "失敗: 囲いの外での起動（WMI）ができなかった（戻り値 $($r.ReturnValue)）"; exit 0 }
  $deadline = (Get-Date).AddMinutes(30)
  while ((Get-Process -Id $r.ProcessId -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 3 }
  if (Get-Process -Id $r.ProcessId -ErrorAction SilentlyContinue) { Write-Output "失敗: 30分たっても終わらなかった（途中までのログ: $log）" }
  if (Test-Path $log) { Get-Content -Path $log -Encoding UTF8 } else { Write-Output "失敗: 結果のログが無い（$log）" }
  exit 0
}

# ---------------- 本体 ----------------
if (-not $LogPath) { $LogPath = Join-Path $WorkDir ("run_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss')) }
function Say([string]$line) {
  Write-Output $line
  Add-Content -Path $LogPath -Value $line -Encoding UTF8
}
# 古いログは30日で消す
Get-ChildItem $WorkDir -Filter 'run_*.log' -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item -ErrorAction SilentlyContinue

function Get-Ver([string]$text) {  # 文字列の中の最初の 数字.数字… を返す
  if ($text -match '\d+(\.\d+)+') { return $Matches[0] } else { return $null }
}
function To-Version([string]$v) {  # 比較用（4つまで）
  if (-not $v) { return $null }
  $parts = @($v.Split('.') | Select-Object -First 4)
  while ($parts.Count -lt 4) { $parts += '0' }   # 2.31.2 と 2.31.2.0 を同じ版として比べる
  try { return [version]($parts -join '.') } catch { return $null }
}
function Short([string]$s) { $t = ($s -replace '\s+', ' ').Trim(); if ($t.Length -gt 200) { $t.Substring($t.Length - 200) } else { $t } }

# ---- CLI ----
function Update-Cli([string]$name, [scriptblock]$getVer, [scriptblock]$doUpdate) {
  $before = & $getVer
  if (-not $before) { Say "注意: $name は入っていない（飛ばした）"; return }
  $out = & $doUpdate 2>&1 | Out-String
  $code = $LASTEXITCODE
  $after = & $getVer
  if ($code -ne 0) { Say "失敗: $name の更新（$before のまま・終了コード $code）: $(Short $out)"; return }
  if ($before -ne $after) { Say "更新: $name $before → $after" } else { Say "変化なし: $name $before" }
}

$ClaudeExe = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
Say '== CLI =='
Update-Cli 'Claude Code' { if (Test-Path $ClaudeExe) { Get-Ver ((& $ClaudeExe --version 2>$null) -join ' ') } } { & $ClaudeExe update }
Update-Cli 'Codex CLI' { if (Get-Command codex.cmd -ErrorAction SilentlyContinue) { Get-Ver ((& codex.cmd --version 2>$null) -join ' ') } } { & npm.cmd i -g '@openai/codex@latest' }

# remote-control が旧版のまま動いていないか（起動時刻が Claude Code の入れ替えより前なら旧版）
$verDir = Join-Path $env:USERPROFILE '.local\share\claude\versions'
$newest = Get-ChildItem $verDir -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($newest) {
  Get-CimInstance Win32_Process -Filter "Name='claude.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'remote-control' } | ForEach-Object {
      if ($_.CreationDate -lt $newest.LastWriteTime) {
        Say ("注意: claude remote-control（pid {0}・{1} 起動）は旧版のまま。再起動していない" -f $_.ProcessId, $_.CreationDate.ToString('MM/dd HH:mm'))
      }
    }
}

# ---- アプリ ----
Say '== アプリ =='
$StatePath = Join-Path $WorkDir 'state.json'
$State = @{}
if (Test-Path $StatePath) { try { (Get-Content $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $State[$_.Name] = $_.Value } } catch {} }

function Get-ExeVer([string]$exe) { if (Test-Path $exe) { (Get-Ver (Get-Item $exe).VersionInfo.ProductVersion) -replace '^(\d+\.\d+\.\d+)\.0$', '$1' } }
function Get-Running([string]$exe) { @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe }) }
function Get-MaxVer([string[]]$vers) {
  $best = $null
  foreach ($v in $vers) { if ($v -and ((-not $best) -or (To-Version $v) -gt (To-Version $best))) { $best = $v } }
  return $best
}
function Pending-Electron([string]$dir) {  # electron-builder の更新用インストーラの版
  Get-MaxVer @(Get-ChildItem -Path (Join-Path $dir 'installer.exe'), (Join-Path $dir 'pending\*.exe') -ErrorAction SilentlyContinue |
    ForEach-Object { Get-Ver $_.VersionInfo.ProductVersion })
}
function Pending-Cursor {
  Get-MaxVer @(Get-ChildItem -Path (Join-Path $env:TEMP 'vscode-stable-user-x64-*\CodeSetup-stable-*.exe') -ErrorAction SilentlyContinue |
    ForEach-Object { Get-Ver $_.Name })
}

function Handle-App([string]$name, [string]$exe, [scriptblock]$getPending) {
  if (-not (Test-Path $exe)) { return }
  $before = Get-ExeVer $exe
  $pending = & $getPending
  if (-not $pending -or (To-Version $pending) -le (To-Version $before)) { Say "変化なし: $name $before（更新待ちなし）"; return }
  if ($NoRestart) { Say "更新待ち: $name $before → $pending（再起動していない）"; return }
  if ((Get-Running $exe).Count -eq 0) { Say "更新待ち: $name $before → $pending（起動していないので触っていない）"; return }
  # ウィンドウを閉じて終了させる（強制終了はしない。強制終了だと更新が入らない）
  for ($i = 0; $i -lt 40; $i++) {
    $procs = Get-Running $exe
    if ($procs.Count -eq 0) { break }
    $procs | Where-Object { $_.MainWindowHandle -ne 0 } | ForEach-Object { [void]$_.CloseMainWindow() }
    Start-Sleep -Seconds 3
  }
  if ((Get-Running $exe).Count -gt 0) { Say "失敗: $name が終了しなかった（$before のまま・保存の確認画面かトレイ常駐の可能性）"; return }
  # 更新の適用を待つ（最長180秒）
  for ($i = 0; $i -lt 60; $i++) {
    if ((To-Version (Get-ExeVer $exe)) -ge (To-Version $pending)) { break }
    Start-Sleep -Seconds 3
  }
  Start-Sleep -Seconds 5
  try { Start-Process -FilePath $exe -ErrorAction Stop } catch { Say "失敗: $name を起動し直せなかった: $($_.Exception.Message)"; return }
  Start-Sleep -Seconds 10
  $after = Get-ExeVer $exe
  if ((Get-Running $exe).Count -eq 0) { Say "失敗: $name を起動し直せなかった（版は $after）"; return }
  if ($before -ne $after) { Say "再起動: $name $before → $after" } else { Say "再起動: $name $before のまま（更新は入らなかった）" }
}

function Report-Only([string]$name, [string]$key, [string]$ver, [string]$note) {  # 更新待ちを見分けられないアプリ
  if (-not $ver) { return }
  $prev = $State[$key]
  if ($prev -and $prev -ne $ver) { Say "更新: $name $prev → $ver（アプリ自身・Store が入れた）" }
  else { Say "変化なし: $name $ver（$note）" }
  $State[$key] = $ver
}

Handle-App 'Antigravity' (Join-Path $LA 'Programs\antigravity\Antigravity.exe') { Pending-Electron (Join-Path $LA 'antigravity-updater') }
Handle-App 'Grok Bot'    (Join-Path $LA 'Programs\Grok Bot\Grok Bot.exe')       { Pending-Electron (Join-Path $LA 'sand-updater') }
Handle-App 'Cursor'      (Join-Path $LA 'Programs\cursor\Cursor.exe')           { Pending-Cursor }

$chatgpt = Get-AppxPackage -Name 'OpenAI.Codex' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($chatgpt) { Report-Only 'ChatGPT（Codex アプリ）' 'OpenAI.Codex' ([string]$chatgpt.Version) 'Store が更新・更新待ちは見分けられない' }
$claudeApp = Get-AppxPackage -Name 'Claude' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($claudeApp) { Report-Only 'Claude デスクトップ' 'Claude' ([string]$claudeApp.Version) '再起動しない・更新待ちは見分けられない' }

try { $State | ConvertTo-Json | Set-Content -Path $StatePath -Encoding UTF8 } catch { Say "注意: 前回の版の記録を保存できなかった: $($_.Exception.Message)" }
exit 0
