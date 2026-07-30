# claude-dotfiles

深石（fukaishi@nsketch.com）のClaude Code設定の**正本リポジトリ**。
CLAUDE.md・settings.json・主要スキルをここで一元管理し、複数PCで同期する。
`~/.claude/` 配下には正本へのシンボリックリンクを張って使う（`setup.sh`が自動でやる）。

## 新しいPCでのセットアップ

前提: GitHub認証（`gh auth login` またはSSH鍵）が済んでいること。

```bash
git clone https://github.com/fukaishi-nsk/claude-dotfiles.git ~/claude-dotfiles
~/claude-dotfiles/setup.sh
```

- `setup.sh` は `~/.claude/CLAUDE.md`・`~/.claude/settings.json`・`~/.claude/skills/*/SKILL.md` に正本へのsymlinkを張る
- そのPCに既存の設定ファイルがあれば `.bak` に退避される（上書き消去はされない）
- 実行後、Claude Codeを再起動する

### セットアップ後の検証（Claude Codeにやらせる）

1. `readlink ~/.claude/CLAUDE.md` が `~/claude-dotfiles/CLAUDE.md` を指すこと
2. `~/.claude/skills/*/SKILL.md` が正本へのsymlinkであること
3. 新しいセッションでCLAUDE.mdの内容が読み込まれ、`/email-draft` `/gmail-attachment-dl` 等のスキルが認識されること

## 運用ルール（正本はCLAUDE.mdの「dotfiles運用」セクション）

- **編集は必ず正本パス（`~/claude-dotfiles/...`）へ**。Claude CodeのEditツールはsymlink越しの書き込みを拒否する
- 正本を編集したら**その場で commit＋push**。dotfilesを編集する前には `git pull`（他PCの変更を取り込む）
- 新しいスキルを作る時は、正本を `skills/<名前>/SKILL.md` に置き、`~/.claude/skills/<名前>/SKILL.md` からsymlinkする（このPCでは手動、他PCは`setup.sh`再実行で反映）
- プロジェクトメモリ（`~/.claude/projects/*/memory`）は**PCローカルで同期されない**。全PC共通にしたい知見はCLAUDE.mdかスキルへ昇格させる

## スキルの前提ツール（PCごとに別途導入が必要）

| スキル | 前提 |
|---|---|
| gmail-attachment-dl | agent-browser（メインPCはHomebrew導入・**v0.33.0固定運用**）＋ Gmailログイン済みの実Chrome（`--profile Default`で参照） |
| email-draft | Gmailコネクタ（claude.ai側の接続なのでPC非依存） |

新しいPCで前提ツールが無い場合は、Claude Codeが導入を提案してから作業に入ること。
