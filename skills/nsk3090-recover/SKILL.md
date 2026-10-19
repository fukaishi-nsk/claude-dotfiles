---
name: nsk3090-recover
description: 会社の3090機（nsk3090・Windows 11）が「Parsecで見られない／いない」「SSHが応答しない」「固まった」時の診断と遠隔復旧（SSHで状態確認→Parsecサービス再起動 or Windows再起動→接続確認）。Mac mini・MacBookのどちらのClaude Codeからでも使う。
---

# 3090機（nsk3090）遠隔復旧

対象: GALLERIA ZA7R-R39（PC名 `NSK3090`・Windows 11 Home）。SSHユーザー `nsketch`（ローカル管理者）、自動サインインON・スリープOFF。Parsec は「Per Computer」導入＝Windowsサービス `Parsec`（自動起動・ログイン画面からでも接続可）。
逆方向（3090からMac miniを直す）は `macmini-recover` スキル。

## 0. 接続先（どのPCから叩くか）

| 叩く側 | SSH先 | 備考 |
|---|---|---|
| Mac mini（社内LAN） | `ssh Host3090` | 鍵 `~/.ssh/id_3090_ed25519`。ホスト鍵は 2026-10-19 に再インストール後の鍵へ更新済み |
| MacBook（社内） | `ssh Host3090` | |
| MacBook（社外） | `ssh Host3090-remote` | Mac mini（Tailscale）を踏み台にする。**Mac mini が死んでいると使えない** → その時は Parsec で Mac mini 以外から入るか、深石さんの帰社待ち |

3090 に Tailscale は無い（2026-10-19 撤去・tailnet が無料で使えないため）。

⚠️ **IPはLANの差し口で変わる**: 増設カード（BUFFALO）= `192.168.10.26`（通常）／オンボード = `192.168.10.24`。`.26` がつながらなければ `.24` を試す:
`ssh -o HostName=192.168.10.24 Host3090 hostname`
どちらもダメなら `for i in $(seq 2 254); do nc -z -G 1 192.168.10.$i 22 2>/dev/null && echo 192.168.10.$i; done` で22番が開いている機器を探し、ホスト鍵の指紋が `SHA256:ULDBq38FAEZOeJAkRE3xxUdJdNIZMFrMxqmjtqQ2Co8`（ED25519）と一致することを確かめてから使う。

## Windowsへのコマンドの渡し方（重要）

- SSHの既定シェルは **cmd.exe**。`powershell -Command "..."` を直書きすると引用符・`|`・`--` が cmd に食われて壊れる（2026-10-19 に何度も失敗）
- 確実な型: **手元で .ps1 を書く → scp で送る → `powershell -NoProfile -ExecutionPolicy Bypass -File` で実行 → 消す**
- ⚠️ **.ps1 は ASCII だけで書く**（日本語を1文字でも入れると、PowerShell 5.1 が Shift-JIS として読んで全体が構文エラーになる）
- 出力の日本語は文字化けして返る（Windowsの既定コードページのため）。数値・英語の部分で判断する

## 1. 診断（読み取りのみ・承認不要）

```bash
D=$(mktemp -d)
cat > $D/diag3090.ps1 <<'EOF'
'== boot'; (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
'== parsec service'; Get-Service Parsec | Format-Table Name,Status,StartType -AutoSize | Out-String
'== parsec procs'; Get-Process -Name parsecd,pservice -ErrorAction SilentlyContinue | Format-Table Name,Id,SessionId -AutoSize | Out-String
'== web'; try { (Invoke-WebRequest -UseBasicParsing -TimeoutSec 8 https://www.google.com).StatusCode } catch { "web failed: $($_.Exception.Message)" }
'== tcp states'; Get-NetTCPConnection -ErrorAction SilentlyContinue | Group-Object State | Format-Table Name,Count -AutoSize | Out-String
'== parsec host log (connections)'; Select-String -Path C:\ProgramData\Parsec\log.txt -Pattern 'Parsec: Started','connected\.','failed with error' | Select-Object -Last 6 | ForEach-Object { $_.Line }
'== parsec client log (server check)'; Select-String -Path C:\ProgramData\Parsec\log_cl.txt -Pattern 'successful /me','failed with error' | Select-Object -Last 4 | ForEach-Object { $_.Line }
'== disk C free GB'; [math]::Round((Get-PSDrive C).Free/1GB)
'== gpu'; & nvidia-smi --query-gpu=temperature.gpu,utilization.gpu,memory.used --format=csv 2>&1
EOF
scp -q $D/diag3090.ps1 Host3090:C:/Users/nsketch/diag3090.ps1 && ssh Host3090 'powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\nsketch\diag3090.ps1 & del C:\Users\nsketch\diag3090.ps1'
rm -rf $D
```

正常時の目安（2026-10-19 実測）: Parsec サービス Running／parsecd がセッション1（ログイン中ユーザー）と pservice がセッション0／web 200／TimeWait 数十以下／`log_cl.txt` の最後に `successful /me`。

判定:
- **SSHもつながらない**（.24/.26 とも） → 3090 が落ちている・固まっている・LAN断。この手順では直せない。深石さんに現地確認（電源・LANケーブルの差し口）を頼む
- **Parsec サービスが Stopped／parsecd が無い** → 手順2（Parsecサービス再起動）
- **web が失敗**、または **TimeWait が数万** → Mac mini と同じTCP膠着の疑い（ポート範囲は 49152〜、16,384個）。手順3（Windows再起動）
- **`log_cl.txt` に `failed with error` が続き、`successful /me` が古い** → Parsec がサーバーに届いていない。まず手順2、ダメなら手順3
- どれにも当てはまらない → 推測で再起動しない。診断結果を深石さんに報告して判断を仰ぐ

## 2. Parsec サービスの再起動（⚠️ 実行前にチャットで深石さんの承認を取る）

接続中の Parsec セッションは切れる。

```bash
D=$(mktemp -d)
printf '%s\n' 'Restart-Service Parsec -Force' 'Start-Sleep 8' 'Get-Service Parsec | Format-Table Name,Status -AutoSize | Out-String' 'Get-Process -Name parsecd,pservice -ErrorAction SilentlyContinue | Format-Table Name,Id,SessionId -AutoSize | Out-String' > $D/rs.ps1
scp -q $D/rs.ps1 Host3090:C:/Users/nsketch/rs.ps1 && ssh Host3090 'powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\nsketch\rs.ps1 & del C:\Users\nsketch\rs.ps1'
rm -rf $D
```

⚠️ 2026-10-19 時点で**未実施の手順**（コマンドは標準のものだが、この機械で実際に効くかは未確認）。初回に使ったら結果をこのスキルに追記する。

## 3. Windows 再起動（⚠️ 実行前にチャットで深石さんの承認を取る）

3090 上で動いている作業（Claude Code・生成ジョブ・学習など）はすべて止まる。承認を取る時にそれを伝え、診断の `gpu` の使用率が高ければ特に念押しする。

```bash
ssh Host3090 'shutdown /r /t 10 /c "remote restart by Claude"'
```

- `nsketch` は管理者なので通る想定。⚠️ 2026-10-19 時点で**SSHからの再起動は未実施**。初回に使ったら結果を追記する
- 自動サインイン（nsketch・空パスワード）→ Parsec はサービスなので、サインイン前から自動で立ち上がる
- 復帰待ち（起動時刻が変わったら再起動済み）:

```bash
for i in $(seq 1 36); do r=$(ssh -o ConnectTimeout=4 Host3090 'powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToString(\"s\")"' 2>&1 | tail -1); echo "$(date +%H:%M:%S) $r"; sleep 10; done
```
（起動時刻の表示が再起動前と変わった行が出たら Ctrl+C 相当で打ち切ってよい。ループは最大6分）

## 4. 復旧確認

手順1の診断をもう一度流し、Parsec サービス Running・web 200・`log_cl.txt` に再起動後の時刻で `successful /me` があることを確かめる。
報告は「Parsecサーバーへの接続OK（ログで確認）」までが Claude 側で確認できる範囲。**実際に画面が映るかは深石さんにしか確認できない**ので、そう書く。

## 5. 記録

- 起きたこと・診断結果・実施した手順・時刻を報告に含める
- 未実施だった手順（2・3）を初めて使った時は、効いたかどうかをこのスキルに追記して commit＋push する
