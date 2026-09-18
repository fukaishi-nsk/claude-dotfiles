# Codex 共通指示（正本: ~/claude-dotfiles/codex/AGENTS.md → setup.sh が ~/.codex/AGENTS.md へ実ファイルコピー）

## agent-browser（ブラウザ自動化・Claude Code と共用ツール）
- ログイン状態が必要な操作は、専用永続プロファイル `--profile "$HOME/.agent-browser/profiles/gmail"` を**全コマンドに毎回**付ける（Mac/Windows共通・2026-09-07制定）。付け忘れると別セッションの about:blank に飛ぶ。連続作業は `export AGENT_BROWSER_PROFILE="$HOME/.agent-browser/profiles/gmail"` でもよい
- サインインページに飛んだら `--headed` で開き直し、**本人にログインしてもらう**（メールアドレス欄までは代行可・パスワード以降は本人）。パスワードや認証コードを自分で入力しない
- 🚫 `--profile Default`（実Chromeプロファイルのテンポラリコピー起動）は**禁止**。コピー側と実Chromeが同じGoogleセッションCookieを持つため、起動の1〜5分後に実Chromeのログインが失効する（2026-09-07に「Chromeで再ログインさせられる」の原因として特定）。`~/.agent-browser/config.json` に `"profile"` の既定値も書かない
- ログイン不要の検証（localhost・公開ページ）は `--profile` を付けずに素の `open` で行う（空の一時プロファイルで起動する）
- 作業が終わったら `close` する（専用プロファイルのログイン状態は残る）

## 1Password CLI（op・Claude Code と共用 / 2026-09-18制定）
- MacBook に導入済み（`brew install --cask 1password-cli`＋1Passwordアプリの設定→開発者→「1Password CLIと連携」ON）。アカウント nsketchinc.1password.com。Mac mini は未導入
- 🚫 **Codex のサンドボックス内では op は 1Password アプリに接続できない**（2026-09-18 検証: read-only / workspace-write / `network_access=true` / `features.network_proxy.unix_sockets` の allow いずれも「couldn't connect to the 1Password desktop app」。サンドボックス無しでは成功）。op を含むコマンドは**最初からサンドボックス外での実行を要求（承認を得る）**し、失敗→再試行で無駄に回さない
- 承認後、1Password 側で「Allow Codex to get CLI access」の Touch ID ダイアログが出る。**本人が承認する**（パスワード・トークンを自分で入力しない）。認可は呼び出し元プロセス単位＝1コマンドごとに出るため、**op は必要な時だけ、1回の呼び出しにまとめて実行**（複数の `op read` を1コマンドに／`op run`・`op inject` で一括）。動作確認目的で叩かない
- `op whoami` は連携下で常に「account is not signed in」を返す偽エラー。確認は `op user get --me` か `op vault list`
- 連携ON直後に「not signed in」で他コマンドも通らない時は `op signin` を一度実行（承認はアプリ側）
- 資格情報（トークン・パスワード）は Codex が扱わない。サービスアカウントを使う場合の発行・保管は本人
