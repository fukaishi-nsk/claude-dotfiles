---
name: nsketch-proposal
description: Nスケッチ標準の企画書スライド（HTML/CSS、TMS白基調、Inter + Noto Sans JP）を生成・編集する。HTMLベースで作成し、最終的にChromeのPDF出力でクライアント送付資料化する。
user-invocable: true
---

## このskillの役割

Nスケッチが受託案件向けに **HTMLベースの企画書（プレゼンスライド）** を作成するときに使用する。

デザイン基盤は Figmaの **TMS Core 2.0** / **TMS Planning** をもとに、白基調・Inter + Noto Sans JP に置き換えたもの。1920×1080 のスライド形式で、スクリーン上はナビゲーション付きで閲覧、最終的にChromeの印刷機能でPDF出力する。

## いつ使うか

- 「企画書を作って／作りたい」
- 「提案書をHTMLで作りたい」
- 「クライアントに送るスライドを作って」
- 案件フォルダの `02_Plan/企画書下書き_*.md` が既にあり、それをスライド化したいとき
- 既存の `proposal_template_v*.html` を別案件向けに流用したいとき

## 使い方

### Step 1: 案件情報の確認

下記をユーザーに確認、または `02_Plan/プロジェクト概要_*.md` から拾う:

- **案件タイトル**（例: 「生成AI活用 可能性検証プロジェクト」）
- **サブタイトル**（例: 「プロダクトデザインにおける生成AIの現在地と活かしどころ」）
- **クライアント名**（例: 「島津製作所 様」）
- **発行日**（例: 「2026.05」）
- **必要なスライド構成**（標準は5枚: Cover / TOC / 背景と目的 / アプローチ / スケジュール）
- **目次項目**
- **背景・課題・目的・成果**などの本文

### Step 2: テンプレからコピー

```bash
cp ~/.claude/skills/nsketch-proposal/template.html "02_Plan/proposal_v1.html"
```

### Step 3: 内容を差し替え

`template.html` 内のプレースホルダー（島津案件の値が入っているところ）を案件情報で置き換える:

- `生成AI活用 可能性検証プロジェクト` → 新案件タイトル
- `プロダクトデザインにおける生成AIの現在地と活かしどころ` → サブタイトル
- `島津製作所 様` → クライアント名
- `2026.05` → 発行日
- TOC項目
- 各スライドの中身

### Step 4: 不要なスライドの削除

5枚すべて使う必要はない。`<section class="slide ...">` ブロック単位で削除可能。

スライドの追加もできる（例: Thanks スライド、Roadmap スライドなど）。詳細は「追加スライドのバリエーション」を参照。

### Step 5: ブラウザで確認

```bash
open "02_Plan/proposal_v1.html"
```

スライド操作: `→/←` (次/前)、`Space` (次)、`Home/End` (最初/最後)。

### Step 6: PDF出力

Chromeで開いた状態で:
1. `Cmd+P` で印刷ダイアログ
2. 送信先: **PDFに保存**
3. レイアウト: **横**
4. 用紙サイズ: **A3（横向き）** または **カスタム: 1920×1080**
5. 余白: **なし**
6. 背景のグラフィック: **オン**
7. 保存先: `01_File_to/proposal_v1.pdf`

## 利用可能なスライドタイプ（標準5枚）

| # | クラス | 用途 | リファレンス画像 |
|---|---|---|---|
| 1 | `.cover` | 表紙（H1タイトル + H4サブタイトル + Company/Date/Project） | `references/01_cover.png` |
| 2 | `.toc` | 目次（H1サイズ大きい番号＋セクション名のリスト） | `references/02_toc.png` |
| 3 | `.context` | 背景・目的・成果など（3列×2行のTextBlockグリッド） | `references/03_context_textgrid.png` |
| 4 | `.approach` | アプローチ・検討テーマ（左に説明＋Badge、右に2×3カードグリッド） | `references/04_approach_cardgrid.png` |
| 5 | `.timeline` | スケジュール（ガントチャート＋下部マイルストーン） | `references/05_timeline.png` |

## 追加スライドのバリエーション（必要に応じて）

以下のスライドタイプも template.html 内に過去版として残っているか、再追加可能:

- **Roadmap** (`.roadmap`): 横並びのフェーズpill + bullet + lineで時間軸を示す（過去版v2に実装あり）
- **Team** (`.team`): 体制紹介（左に主要メンバー3名、右に他メンバーグリッド）（過去版v2に実装あり）
- **Thanks** (`.thanks`): エンディング（Thank you + 連絡先）（過去版v2に実装あり）
- **Body 2-column** (`.body-slide`): 左カラム見出し＋右カラムグレーボックス（過去版v1/v2に実装あり）

これらが必要な場合は、案件フォルダの `proposal_template_v2.html`（古いテンプレ）からブロックをコピーして使う。

## デザイントークン（TMS Core 2.0 準拠 / 白基調）

template.html の `:root` で定義済み。書き換えるとき:

```css
/* Color */
--bg: #FFFFFF;
--text: #000000;
--text-50: rgba(0, 0, 0, 0.5);
--text-25: rgba(0, 0, 0, 0.25);
--text-10: rgba(0, 0, 0, 0.1);
--surface-5: rgba(0, 0, 0, 0.05);  /* グレーボックス */
--line: #D5D5D5;                    /* 罫線・border */
--gradient-dark: linear-gradient(180deg, #62656a 0%, #91969c 100%);
                                    /* Badge Style1 / Active状態のpill */
--gradient-light: linear-gradient(0deg, #b1b3b9 0%, #d8dae2 100%);
                                    /* Badge Style2 */

/* Font */
--font-sans: 'Inter', 'Noto Sans JP', sans-serif;

/* Typography Scale */
--h1: 100px;   --h1-lh: 112px;  /* 表紙タイトル */
--h2: 60px;    --h2-lh: 68px;   /* セクション大見出し */
--h4: 34px;    --h4-lh: 42px;   /* 中見出し、表紙サブタイトル */
--h6: 24px;    --h6-lh: 30px;   /* テキストブロック見出し */
--xl: 20px;    --xl-lh: 26px;   /* リード文、カードカテゴリ */
--md: 16px;    --md-lh: 20px;   /* バッジテキスト */
--sm: 18px;    --sm-lh: 22px;   /* テーブル本文 */

/* Spacing */
--pad-x: 44px;
--pad-y: 40px;
```

## やってはいけないこと

- **創作禁止**: 案件情報を勝手に作らない。確認できないデータは「未確認」または空欄にする
- **デザイントークンを勝手に変えない**: 既存のCSS変数を使う。新しい色やフォントを追加するときはユーザーに確認
- **PDFを送付する前にユーザーの確認をとる**: クライアント送付物は必ずユーザーがレビュー
- **「Helvetica Neue」に戻さない**: Nスケッチでは Inter + Noto Sans JP を採用
- **タイトルと同サイズのサブタイトルにしない**: 表紙サブタイトルは H4 (34px) で控えめに

## Figma元データ

Skillのテンプレ元になったFigmaファイル（Nスケッチ社内）:

- TMS Core 2.0: `https://www.figma.com/design/Po2F2aqofLdKimTuyE1c8p/TMS-Core-2.0--1-`
- TMS Planning: `https://www.figma.com/design/FwGobdaZRglLi0tQzy8LwQ/TMS-Planning--1-`

主に使うページ:
- Cover: Page 01 (nodeId `55:6591`)
- TOC: Page 02 (nodeId `55:6592`)
- 背景と目的: Page 55 (nodeId `55:6645`) — 3×2 TextBlock
- アプローチ: Page 50 (nodeId `55:6640`) — Left text + 2×3 Card
- Timeline: TMS Planning > Timeline 1 (nodeId `32:6496`)

Figmaに新しいパターンが追加されたら、Figma MCP経由で再取得→template.htmlを更新。

## 更新ログ

- 2026-05-11 (v1): 初版作成。7スライド対応（Cover/TOC/Body/Roadmap/Timeline/Team/Thanks）
- 2026-05-11 (v3): 構成変更。5スライド標準（Cover/TOC/背景と目的/アプローチ/スケジュール）。
  - 背景と目的スライドを新規追加（Page 55ベース）
  - アプローチをPage 50（カードグリッド）スタイルに刷新
  - Coverサブタイトルを H1(100px) → H4(34px) に縮小
  - Roadmap/Team/Thanks を削除（必要に応じて再追加可能）
