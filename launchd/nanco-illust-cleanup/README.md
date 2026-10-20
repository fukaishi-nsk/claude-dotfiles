# nanco-illust-cleanup

nanco-illust の生成フォルダ `~/src/nanco_illust/generated/` 直下のフォルダを、**描いてから30日たったら Mac のゴミ箱へ移す**（2026-10-20 深石さん指示「候補として描いたけれど使わなかった絵は1ヶ月で自動削除」「生成フォルダ全部を30日でゴミ箱へ。3〜6月の分も消してOK」）。

- 動く場所: **Mac mini だけ**（nanco-illust が Mac mini でしか動かないため）。毎日 4:30 に launchd（`com.nsketch.nanco-illust-cleanup`）で実行
- 消し方: 完全には消さず `~/.Trash` へ `mv`。ゴミ箱を空にするまでは戻せる（名前がぶつかったら末尾に日時を付ける）
- 古さの判定: フォルダ名が `YYYYMMDD_` で始まればその日付、それ以外はフォルダの更新日時
- 触らないもの: `generated/` 直下のファイル（`fal_usage.csv`＝費用の記録、比較用の画像・JSON など）
- **使い回したい絵は、30日以内に共有ドライブ `Nanco/illust/nanco-illust_資料素材/` へ移す**（nanco-material の「素材と前例」に登録）。Slack bot の出力も同じフォルダに入るので、残したいものは同じく移す
- ログ: `~/Library/Logs/nanco-illust-cleanup.log`
- 導入: `bash install.sh`（Mac mini で1回）。試すだけなら `bash cleanup.sh --dry-run`。日数を変えるなら `DAYS=60 bash cleanup.sh`（常に変えるなら plist に EnvironmentVariables を足す）
- 導入時の実行結果（2026-10-20）: 3〜6月の分を含む160フォルダをゴミ箱へ（3.2GB→258MB）。launchd から `launchctl kickstart` で動かし、テスト用フォルダがゴミ箱へ移ることを確認（フルディスクアクセスの追加は不要だった）
