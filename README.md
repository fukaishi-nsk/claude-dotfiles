# claude-dotfiles

深石（fukaishi@nsketch.com）のClaude Code設定の**正本リポジトリ**。
CLAUDE.md・settings.json・主要スキルをここで一元管理し、複数PCで同期する。
`~/.claude/` 配下には正本へのシンボリックリンクを張って使う（`setup.sh`が自動でやる）。

## 新しいPCでのセットアップ

人間がやるのは2つだけ: **①Claude Codeをインストールしてログイン ②下のプロンプトを丸ごとコピペ**。残りはClaude Codeが実行する。

```
新PCにclaude-dotfilesをセットアップして。手順:
1. GitHub認証を確認（gh auth status）。未認証なら gh auth login を案内して私に操作させて
2. git clone https://github.com/fukaishi-nsk/claude-dotfiles.git ~/claude-dotfiles
3. ~/claude-dotfiles/setup.sh を実行（既存ファイルは.bakに退避されるので安全）
4. 検証: readlink ~/.claude/CLAUDE.md が正本を指すこと、~/.claude/skills/*/SKILL.md がsymlinkであること
5. 前提ツールの確認: agent-browserが無ければHomebrewで導入を提案（v0.34.0）。Gmailログイン済みChromeの有無も確認
6. README.mdの「setup.shが同期しないもの」を読んで、このPCで追加対応が要るものを私に一覧で報告
7. 完了したらClaude Codeの再起動を私に促す
```

以降はSessionStartフック（settings.jsonに同梱）がセッション開始ごとに自動でpull＋setup.shを走らせる。**pushだけは手動**（編集したらその場でcommit＋push）。

### setup.shが同期しないもの（新PCで個別対応）

- **前提ツール**: agent-browser（Homebrew・v0.34.0）、Gmailログイン済みの実Chrome
- **ローカルMCP**（notion/grok）: `claude mcp` で個別登録
- **スケジュール登録**: 手順書は同期されるが実行時刻の登録はPCごと。**他PCとの二重実行に注意**
- **プロジェクトメモリ**（`~/.claude/projects/*/memory`）: 同期されない。必要ならzip→マイドライブ方式（フォルダ名の `-Users-<ユーザー名>-` リネーム必須）

## 運用ルール（正本はCLAUDE.mdの「dotfiles運用」セクション）

- **編集は必ず正本パス（`~/claude-dotfiles/...`）へ**。Claude CodeのEditツールはsymlink越しの書き込みを拒否する
- 正本を編集したら**その場で commit＋push**。dotfilesを編集する前には `git pull`（他PCの変更を取り込む）
- 新しいスキルを作る時は、正本を `skills/<名前>/SKILL.md` に置き、`~/.claude/skills/<名前>/SKILL.md` からsymlinkする（このPCでは手動、他PCは`setup.sh`再実行で反映）
- プロジェクトメモリ（`~/.claude/projects/*/memory`）は**PCローカルで同期されない**。全PC共通にしたい知見はCLAUDE.mdかスキルへ昇格させる

## スキルの前提ツール（PCごとに別途導入が必要）

| スキル | 前提 |
|---|---|
| gmail-attachment-dl | agent-browser（メインPCはHomebrew導入・**v0.34.0固定運用**）＋ Gmailログイン済みの実Chrome（`--profile Default`で参照） |
| email-draft | Gmailコネクタ（claude.ai側の接続なのでPC非依存） |

新しいPCで前提ツールが無い場合は、Claude Codeが導入を提案してから作業に入ること。
