# Codex 共通指示（正本: ~/claude-dotfiles/codex/AGENTS.md → setup.sh が ~/.codex/AGENTS.md へ実ファイルコピー）

## agent-browser（ブラウザ自動化・Claude Code と共用ツール）
- ログイン状態が必要な操作は、専用永続プロファイル `--profile "$HOME/.agent-browser/profiles/gmail"` を**全コマンドに毎回**付ける（Mac/Windows共通・2026-09-07制定）。付け忘れると別セッションの about:blank に飛ぶ。連続作業は `export AGENT_BROWSER_PROFILE="$HOME/.agent-browser/profiles/gmail"` でもよい
- サインインページに飛んだら `--headed` で開き直し、**本人にログインしてもらう**（メールアドレス欄までは代行可・パスワード以降は本人）。パスワードや認証コードを自分で入力しない
- 🚫 `--profile Default`（実Chromeプロファイルのテンポラリコピー起動）は**禁止**。コピー側と実Chromeが同じGoogleセッションCookieを持つため、起動の1〜5分後に実Chromeのログインが失効する（2026-09-07に「Chromeで再ログインさせられる」の原因として特定）。`~/.agent-browser/config.json` に `"profile"` の既定値も書かない
- ログイン不要の検証（localhost・公開ページ）は `--profile` を付けずに素の `open` で行う（空の一時プロファイルで起動する）
- 作業が終わったら `close` する（専用プロファイルのログイン状態は残る）
