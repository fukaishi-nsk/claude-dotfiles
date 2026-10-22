---
name: nanco-illust
description: nanco ブランドのイラスト（手描き風の線画＋セージグリーンの差し色）を fal.ai または会社の 3090 で描き、深石さんと相談しながら直す。使うのは次の2つの場合だけ ①nanco-material（オンライン相談後などのサービス資料の改定）の中で図解の絵が要る時 ②深石さんが /nanco-illust と明示した時。それ以外の「絵を描いて」「画像を作って」では使わない（2026-10-20 深石さん指示）。Mac mini（~/src/nanco_illust）でだけ動く。
---

# nanco-illust — 相談しながら nanco のイラストを描く

2026-10-20 制定。Slack bot（固定の20枚）とは別の、深石さん専用の使い方。深石さんが **Claude の画面で、スレッドのように相談しながら** 描いて直していく。

**使う場面は2つだけ**（2026-10-20 深石さん「それ以外は逆にじゃまになる可能性もある」）:
1. `nanco-material` でサービス資料を改定していて、図解に絵が要る時（進め方は nanco-material の「絵の使い方」）
2. 深石さんが `/nanco-illust` と明示した時

それ以外の「絵を描いて」「画像を作って」では使わない。迷ったら使わずに、使うかを聞く。

## 前提（変えるときは深石さんに確認）

- 動く場所: **Mac mini だけ**（`~/src/nanco_illust`）。MacBook からは remote-control で Mac mini のセッションを使う。MacBook の手元にはスクリプトも LoRA も無い
- 生成: **fal.ai の `fal-ai/flux-lora`**（FLUX.1-dev ＋ nanco の LoRA）と **3090 版**（下の「3090 で描く」）の2つ。深石さん 2026-10-21「3090版とfalを両方使う」。**使い分けは未決**: 指定がなければ fal で描き、3090 でも描けることを一言添える。5090 は使わない（2026年11月から使えない）
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

## 3090 で描く（費用0円・2026-10-21〜）

- コマンドは fal 版と同じ引数（`--workers` だけ無い）。出力の形（元画像・`transparent/`・`_sheet.png`）も同じ:
  ```bash
  cd ~/src/nanco_illust && .venv/bin/python nanco_generate_3090.py "<English subject>" --only lv03,lv04 --seeds 2 --sheet
  ```
- 中身: Mac mini が段階・seed・お題の言葉を決め（fal 版と同じ関数）、SSH（`Host3090`）で 3090 の `C:\Users\nsketch\flux3090\nanco3090\nanco3090_worker.py` に描かせ、絵を受け取って透過と一覧を作る。3090 側は 5090 と同じ diffusers の描き方で、本体だけ Nunchaku INT4 の FLUX.1-dev。**同じ seed なら 5090 の昔の絵とほぼ同じ絵**になる（fal とは少し違う）。深石さんの評価「悪くない」（2026-10-22）
- 速さ: モデル読み込み約15秒＋**1枚約16秒**（1枚ずつ順番）。4枚で約2分。たくさん描くと fal より遅い
- 記録: `generated/local3090_usage.csv`。3090 側にも `nanco3090\runs\` に元画像が残る
- 3090 が使えない時: 3090 の GPU が使用中（VRAM 4GB超）なら描かずに止まる → 3090 で何が動いているか深石さんに確認する（深石さんが3090を使っている時間がある）。つながらない時は `/nsk3090-recover`
- LoRA は 3090 の `nanco3090\loras\` に10段階のコピーがある。Mac 側の LoRA を作り直したら、3090 にも送り直す
- 利用規約: FLUX.1-dev は非商用ライセンス。手元の GPU で描いた絵を nanco の仕事に使ってよいかは**未確認**（fal は「生成画像は商用利用可」と明記）

## 前後（BEFORE→AFTER）の対を描く（2026-10-20 デンケンで確立）

- 2枚を別々に描くと、同じ seed・同じ言い回しでも物の数・形・大きさが変わって**別の場面に見える**（深石さん「完全に別シーンに見える」）
- うまくいった方法: BEFORE を nanco の LoRA で描く → その元画像（透過前）を `fal_client.upload_file` で上げ → **`fal-ai/flux-pro/kontext`** に `image_url` と指示文を渡して AFTER に書き換える（1枚 約$0.04）。同じ紙・同じ缶が、同じ線と色のまま片付いた
  - 指示文の例: `Rearrange the same objects into a tidy, organized state: stack all the scattered papers into one neat straight pile and stand the paint cans upright in a neat row beside it. Keep exactly the same hand-drawn illustration style, line weight, sage green colors, size, viewpoint and plain white background. No people, no text.`
  - 透過はスクリプトの `remove_background_smooth()` を import して使う。AFTER は物が大きめに描かれるので、資料では2枚の高さをそろえて置く
  - 比較した `fal-ai/flux-lora/image-to-image`（元画像を下敷きに LoRA で描き直し・strength 0.75/0.85）は、紙の色や缶の形が変わってつながりが弱かった
  - Kontext は nanco の LoRA を通さない。絵柄は入力画像から受け継ぐだけなので、毎回同じになるとは限らない。**商用利用の条件は未確認**（下の利用規約と同じ扱い）
  - 今回のスクリプトはセッションの一時フォルダに置いただけ。繰り返し使うなら `nanco_generate_fal.py` に `--edit-from <画像> --edit "<指示文>"` のような形で取り込む（未実装）

## 描いた絵の置き場所と自動の片付け（2026-10-20〜）

- `generated/` 直下のフォルダは、**描いてから30日たつと毎日4:30にMacのゴミ箱へ移る**（launchd `com.nsketch.nanco-illust-cleanup`・正本 `~/claude-dotfiles/launchd/nanco-illust-cleanup/`）。直下のファイル（`fal_usage.csv` など）は残る
- 資料に使った絵・使い回したい絵は、30日以内に共有ドライブ `Nanco/illust/nanco-illust_資料素材/` へ移す（透過版＋`元画像/`に元画像。`_一覧.png` も作り直す）。一覧は nanco-material の「素材と前例」
- セッションの一時フォルダ（scratchpad）で作った絵（Kontext の AFTER など）は、セッションが終わると消えるので、使ったらすぐ素材フォルダへ移す

## 気をつけること

- **画面・紙の文字はでたらめになる**（FLUX の癖）。数字や文字が要る絵は、資料側で文字を重ねる前提で、そう伝える
- 同じ seed でも 5090 の昔の絵と同じにはならない（fal は計算の環境が違う）
- **利用規約は未確認**: FLUX.1-dev（fal 経由）で作った絵の商用利用の条件、AI 生成と明示する必要があるかは、まだ確かめていない。LP や広告など大きく使う前に確かめる
- LoRA の fal 上の URL は `loras/fal_urls.json` にあり、切れていたらスクリプトが上げ直す（[uploaded …] と出る）

## 経緯（詳しくは Mac mini のプロジェクトメモリ `naynco-project.md` Step 11）

- 2026-10-19〜20 に 5090／3090／fal／MiniMax（image-01・H3）を比べ、**fal flux-lora に決定**（速い・今の絵柄に近い・GPU 不要）
- H3（MiniMax の公開モデル）は 3090＋ComfyUI で1枚12秒まで速くなったが、線が太すぎ／細くすると手描き感が消えるで見送り（環境は 2026-10-21 に削除済み）
- 2026-10-21 FLUX.2 klein 4B（Apache 2.0）でも LoRA を作ったが、手書き感が薄く見送り（LoRA は Mac `loras/klein/`）。同日、3090 で 5090 と同じ描き方＋Nunchaku INT4 にして1枚16秒で再現できた → 3090 版として追加
