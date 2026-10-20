---
name: nanco-illust
description: nanco ブランドのイラスト（手描き風の線画＋セージグリーンの差し色）を、深石さんと Claude の画面で相談しながら fal.ai で描く。「〇〇の絵を描いて」「nancoのイラスト作って」「さっきの3番の感じでもう少し〇〇」「資料に入れる絵がほしい」と言われた時に使用。Mac mini（~/src/nanco_illust）でだけ動く。
---

# nanco-illust — 相談しながら nanco のイラストを描く

2026-10-20 制定。Slack bot（固定の20枚）とは別の、深石さん専用の使い方。深石さんが **Claude の画面で、スレッドのように相談しながら** 描いて直していく。

## 前提（変えるときは深石さんに確認）

- 動く場所: **Mac mini だけ**（`~/src/nanco_illust`）。MacBook からは remote-control で Mac mini のセッションを使う。MacBook の手元にはスクリプトも LoRA も無い
- 生成: **fal.ai の `fal-ai/flux-lora`**（FLUX.1-dev ＋ nanco の LoRA）。5090・3090 は使わない（5090 は 2026年11月から使えない）
- スクリプト: `~/src/nanco_illust/nanco_generate_fal.py`（Python は `~/src/nanco_illust/.venv/bin/python`）。fal のキーは `~/src/nanco_illust/.env` の `FAL_KEY` をスクリプトが自分で読む → **1Password・Touch ID は要らない**
- LoRA: `~/src/nanco_illust/loras/` の10段階（lv01＝線画だけ 〜 lv10＝色の面が多い）。強さは **1.0 固定**（深石さん 2026-10-20 決定。0.6/0.8 は線が黒くなるが絵柄が離れた）
- 品質チェックで落ちた絵は別の seed で自動で描き直す（最大2回）。**線がグレー・緑の絵は落とす／線が少ない絵は通す**（2026-10-20 決定）
- 費用: **1枚 約$0.037**（fal 見積もりAPIの実績 $0.038/回）。描き直しも1回分かかる。毎回 `generated/fal_usage.csv` に記録される
- 速さ: 5枚ずつ同時に頼む。4枚で約13秒、20枚で約2分（2026-10-20 実測）

## 進め方

1. **お題を英語にする**: 深石さんの日本語を、短い英語の名詞句にする（例「棚から品物を取る人」→ `a person taking an item from a warehouse shelf`）。被写体を先頭に置く（スクリプトが自動で先頭に回す）。訳を一言そえる
2. **最初は少なめに描く**: 迷うなら `--only lv01,lv03,lv04,lv06 --seeds 2`（8枚・約$0.3）。用途が決まっていれば絞る（線画だけ＝lv01〜02、緑の差し色＝lv03〜05、色の面＝lv06〜）。20枚フルは頼まれた時だけ
3. **一覧を見せる**: `--sheet` で番号付きの `_sheet.png` ができる。`SendUserFile`（display: render）で見せ、各番号の段階と seed を一言ずつ添える
4. **直す**: 「#03 の感じで」→ 同じ段階で seed を変える（`--only lv04 --seeds 4`）、または `--seed-list` でその seed を固定して `--extra` で言葉を足す。言葉の例:
   - 線を減らす: `extremely few strokes, more empty space`
   - 緑を増やす: `more sage green`／減らす: `almost no color`
   - 画角: `--aspect 16:9` など（1:1 4:3 3:4 3:2 2:3 16:9 9:16）
5. **決まったら渡す**: 透過PNGは出力フォルダの `transparent/`。資料に使うなら、その案件の `03_Design` などへのコピーを提案する（勝手に置かない）

## コマンドの型

```bash
cd ~/src/nanco_illust && .venv/bin/python nanco_generate_fal.py "<English subject>" --only lv03,lv04 --seeds 2 --sheet
```

- `--extra "..."` 追加の言葉／`--seed-list 42,123` seed 固定／`--aspect 16:9`／`--lines-only` 純粋な線画版も出す／`--taper` Slack と同じ20枚
- 出力: `generated/<日時>_<お題>/`（元画像）・`transparent/`（背景透過）・`_sheet.png`／`_sheet.txt`（番号と元ファイルの対応）
- 終了コード 1＝1枚以上が描けなかった（fal のエラーなど）。ログの FAILED 行を見て伝える

## 気をつけること

- **画面・紙の文字はでたらめになる**（FLUX の癖）。数字や文字が要る絵は、資料側で文字を重ねる前提で、そう伝える
- 同じ seed でも 5090 の昔の絵と同じにはならない（fal は計算の環境が違う）
- **利用規約は未確認**: FLUX.1-dev（fal 経由）で作った絵の商用利用の条件、AI 生成と明示する必要があるかは、まだ確かめていない。LP や広告など大きく使う前に確かめる
- LoRA の fal 上の URL は `loras/fal_urls.json` にあり、切れていたらスクリプトが上げ直す（[uploaded …] と出る）

## 経緯（詳しくは Mac mini のプロジェクトメモリ `naynco-project.md` Step 11）

- 2026-10-19〜20 に 5090／3090／fal／MiniMax（image-01・H3）を比べ、**fal flux-lora に決定**（速い・今の絵柄に近い・GPU 不要）
- H3（MiniMax の公開モデル）は 3090＋ComfyUI で1枚12秒まで速くなったが、線が太すぎ／細くすると手描き感が消えるで見送り（環境は 5090 `ai-toolkit-h3\`・3090 `h3\` に残置）
