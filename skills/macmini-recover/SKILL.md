---
name: macmini-recover
description: Mac mini（fukaishi_macmini・常時稼働の母艦）が「Parsecで見られない／いない」「Moonlightで見えない」「remote-controlが応答しない」時の診断と遠隔復旧（SSHで状態確認→Sunshine起動 or 再起動→Parsec接続確認）。MacBook・3090機のどちらのClaude Codeからでも使う。
---

# Mac mini 遠隔復旧

Mac mini（ユーザー `fukaishi_macmini`、LAN `192.168.10.28`、Tailscale `100.110.187.46`）がリモート画面から見えなくなった時の手順。
2026-07-21・2026-10-19 に同じ障害（TCP膠着）が起き、どちらも再起動で直った。
2026-10-22 は別の症状（Parsec の IPv4 側の STUN 応答が来ず `-6023 / -11003` で接続失敗）。Parsec アプリの再起動では直らず、本体の再起動で直った（判定は手順1）。
逆方向（Mac mini・MacBook から3090を直す）は `nsk3090-recover` スキル。
30分ごとの見守り合い（異常を Slack に知らせるだけ）と Mac mini の月次再起動は `~/claude-dotfiles/buddy/`（nsk-buddy）。Slack の通知から呼ばれた時は、通知の内容を手順1の診断で確かめてから動く。

## 0. 接続先（どのPCから叩くか）

| 叩く側 | SSH先 | 備考 |
|---|---|---|
| 3090機（Windows・社内LAN） | `ssh macmini` | 3090の `~/.ssh/config` に登録済み（鍵 `~/.ssh/id_macmini_ed25519`、2026-10-19）。Tailscaleは無いので**社内LANからのみ** |
| 5090機（Windows・NSKETCH5090・社内LAN） | `ssh fukaishi_macmini@192.168.10.28` | `~/.ssh/config` は無いが既定鍵 `id_rsa` で通る（2026-10-22 実測）。この機の Tailscale は管理者の承認待ちで使えない＝**社内LANからのみ** |
| MacBook（社内） | `ssh fukaishi_macmini@192.168.10.28` | 鍵認証済み |
| MacBook（社外） | `ssh fukaishi_macmini@100.110.187.46` | Tailscale経由 |

以下は `ssh macmini` で書く。MacBookでは読み替える。Windows では Claude Code の Bash（Git Bash）から叩く（PowerShell だと引用符が崩れる）。

## 1. 診断（読み取りのみ・承認不要）

```bash
ssh macmini 'bash -s' <<'EOF'
uptime
echo "TIME_WAIT=$(netstat -an -p tcp | grep -c TIME_WAIT)"
curl -s -o /dev/null -m 8 -w "google %{http_code}\n" https://www.google.com || echo "外向きTCP失敗 rc=$?"
pgrep -lf -i parsecd
pgrep -lf -i sunshine
echo "--parsec log"; tail -5 ~/.parsec/log.txt
grep -m1 "failed with error 17" ~/.parsec/log.txt
echo "--接続の成否"; grep -hE "STUN reply|net  |connected\.|failed to connect" ~/.parsec/log.1.txt ~/.parsec/log.txt 2>/dev/null | tail -8
EOF
```

※ Parsec ログは Parsec の起動時に `log.txt` → `log.1.txt` へ切り替わる。Parsec を再起動した後に前の記録を見るなら `log.1.txt` も読む。

判定:
- **SSHもつながらない** → Mac miniが落ちている／ネットワーク断。この手順では直せない。深石さんに現地確認（電源・LANケーブル）を頼む
- **TIME_WAIT が数万件（3万超）＋ curl 失敗＋ Parsecログに `NSURLConnection failed with error 17` が連続** → TCP膠着。手順2（再起動）へ。宛先の内訳は後で調べられるよう、再起動前に記録しておく:
  `ssh macmini 'netstat -an -p tcp | awk "/TIME_WAIT/{print \$5}" | sed -E "s/\.[0-9]+$//" | sort | uniq -c | sort -rn | head -5'`
- **TIME_WAIT は正常・google 200 なのに、`failed to connect (-6023 / -11003)` が出る。直前の `STUN reply` が IPv6（`2600:1f18:...`）だけで、`::ffff:3.228.228.84` が無い** → Parsec の IPv4 側だけが詰まっている（2026-10-22）。正常時は IPv6 と IPv4 の2行が同じ秒に並ぶ
  - 同じ社内LANの 5090機には、同じ接続元（IPv4 のみの回線）からつながった。Mac mini で python3 から IPv4 の STUN を送ると、送信元ポートを変えても全部応答があった。つまり回線・ルーター・ファイアウォールではない（Parsec は「受信を許可」）。原因は未特定
  - Parsec アプリの再起動（`osascript -e 'tell application "Parsec" to quit'` → `open -a Parsec`）では**直らなかった**。本体の再起動（手順2・承認要）で直った。次に同じ症状が出たら、Parsec の再起動は飛ばして、本体の再起動の承認を取ってよい
  - -6023 は公式では「P2P 接続を何かが邪魔している（NAT・ファイアウォール等）」。-11003 は公式の資料で見つからず意味は不明
- **parsecd が無い** → `ssh macmini 'open -a Parsec'` で起動して手順3へ
- **Moonlightだけ見えない・sunshine が無い** → `ssh macmini 'open -b dev.lizardbyte.sunshine.wrapper'`（トレイからQuitされたまま。再ペアリング不要）
- どれにも当てはまらない → 推測で再起動しない。診断結果を深石さんに報告して判断を仰ぐ

## 2. 再起動（⚠️ 実行前に必ずチャットで深石さんの承認を取る）

再起動すると Mac mini 上の Claude（remote-control 含む）・Codex のセッションはすべて終了する。承認を取る時にそれを伝える。

sudo はパスワードが要るので使えない。System Events 経由で再起動する:

```bash
ssh macmini 'nohup osascript -e "tell application \"System Events\" to restart" >/tmp/restart.log 2>&1 &'
```

- アプリの終了待ちで実際に落ちるまで 1〜2 分かかる（2026-10-19 実測: 指示 10:25 → 落ちたのが 10:27 → 起動 10:28）
- 自動ログインON・FileVault OFF なので、起動後は自動でデスクトップまで進み、Parsec・Sunshine はログイン項目で自動起動する

復帰待ち（`uptime` に `day` が消えたら再起動済み）:

```bash
for i in $(seq 1 36); do r=$(ssh -o ConnectTimeout=4 macmini uptime 2>&1 | head -1); echo "$(date +%H:%M:%S) $r"; case "$r" in *" up "*day*|*"timed out"*|*refused*|*"No route"*|*closed*|*reset*) ;; *) break;; esac; sleep 10; done
```

⚠️ `case` で「mins」を条件にしない（「53 days, 3 mins」にも当たって早抜けする。2026-10-19 にやらかした）。

⚠️ **3分たっても落ちない時は、終了待ちで止まっているアプリがある**（2026-10-22: Mac mini 上の Claude デスクトップアプリが終了せず、7分止まった）。止めているアプリを特定する:

```bash
ssh macmini 'bash -s' <<'EOF'
asn=$(log show --last 10m --style compact --predicate 'process == "loginwindow"' 2>/dev/null | grep -o "_currentlyQuittingASN:LSASN:{hi=0x0;lo=0x[0-9a-f]*}" | tail -1 | sed -E "s/.*lo=(0x[0-9a-f]+).*/\1/")
echo "quitting ASN=$asn"; lsappinfo info -only name "ASN:0x0-$asn"
EOF
```

- Claude・Codex なら、承認時に「セッションが切れる」ことは了承済みなので、本体のプロセスを終了させてよい: `ssh macmini 'p=$(pgrep -x Claude | head -1); kill -TERM $p; sleep 10; kill -0 $p 2>/dev/null && kill -KILL $p'`。終了させると、すぐに再起動が進む（10-22 実測: 終了 09:30 → 落ちたのが 09:30:23 → 起動 09:31）
- それ以外のアプリ（保存していない文書があり得るもの）は、勝手に終了させず深石さんに確認する

## 3. 復旧確認

```bash
ssh macmini 'bash -s' <<'EOF'
uptime
echo "TIME_WAIT=$(netstat -an -p tcp | grep -c TIME_WAIT)"
curl -s -o /dev/null -m 8 -w "google %{http_code}\n" https://www.google.com
pgrep -lf /Applications/Parsec.app
grep -E "Parsec: Started|successful /me|connected\.|error 17" ~/.parsec/log.txt | tail -6
EOF
```

OK の条件: TIME_WAIT が数百以下・google 200・Parsecログで最後の `Parsec: Started` より後に `successful /me`（サーバー接続OK）があり、`error 17` が出ていない。誰かが接続すると `<名前>#<ID> connected.` が出る。IPv4 側の症状（手順1）の後は、接続時に `STUN reply from ::ffff:3.228.228.84` が出ているかも見る。
起動直後の `NSURLConnection failed with error -1009` や `Failed to get the me data ... Attempt number 1` は、ネットがつながる前の一時的なもので問題ない（10-19・10-22 とも、この後に接続できた）。
再起動の後、Mac mini 上の Claude（remote-control）・Codex のセッションは終わったまま。必要なら深石さんに立ち上げ直してもらう。
※ `/System/Library/PrivateFrameworks/CoreParsec.framework/parsecd` は macOS 標準の別物。Parsec アプリは `/Applications/Parsec.app/...` の方。

報告は「Parsecサーバーへの接続OK（ログで確認）」までが Claude 側で確認できる範囲。**実際に画面が映るかは深石さんにしか確認できない**ので、そう書く。

## 4. 記録

- 起きたこと・TIME_WAIT件数と宛先上位・Parsecが失敗し始めた時刻（`grep -m1 "failed with error 17"`）・再起動時刻を報告に含める
- 再発が続くなら原因アプリの特定が要る（2026-10-19 時点で未特定。宛先は Cloudflare 帯 2606:4700::/104.18.18-19.125 と 127.0.0.1）
