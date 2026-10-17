# Codex 共通指示（正本: ~/claude-dotfiles/codex/AGENTS.md → setup.sh が ~/.codex/AGENTS.md へ実ファイルコピー）

## agent-browser（ブラウザ自動化・Claude Code と共用ツール）
- ログイン状態が必要な操作は、専用永続プロファイル `--profile "$HOME/.agent-browser/profiles/gmail"` を**全コマンドに毎回**付ける（Mac/Windows共通・2026-09-07制定）。付け忘れると別セッションの about:blank に飛ぶ。連続作業は `export AGENT_BROWSER_PROFILE="$HOME/.agent-browser/profiles/gmail"` でもよい
- サインインページに飛んだら `--headed` で開き直し、**本人にログインしてもらう**（メールアドレス欄までは代行可・パスワード以降は本人）。パスワードや認証コードを自分で入力しない
- 🚫 `--profile Default`（実Chromeプロファイルのテンポラリコピー起動）は**禁止**。コピー側と実Chromeが同じGoogleセッションCookieを持つため、起動の1〜5分後に実Chromeのログインが失効する（2026-09-07に「Chromeで再ログインさせられる」の原因として特定）。`~/.agent-browser/config.json` に `"profile"` の既定値も書かない
- ログイン不要の検証（localhost・公開ページ）は `--profile` を付けずに素の `open` で行う（空の一時プロファイルで起動する）
- 作業が終わったら `close` する（専用プロファイルのログイン状態は残る）

## 1Password CLI（op・Claude Code と共用 / 2026-09-18制定）
- MacBook に導入済み（`brew install --cask 1password-cli`＋1Passwordアプリの設定→開発者→「1Password CLIと連携」ON）。アカウント nsketchinc.1password.com。Mac mini にも op 2.39.0・アプリ 8.12.36 が入っている（2026-09-30 SSHで確認。ただしアプリ連携がONか・保管庫まで通るかは未確認）。5090機（Windows・NSKETCH5090）は op 2.39.0 本体のみ導入・アプリ連携は見送り（2026-09-30。Windows の連携は Windows Hello 必須だが、自動ログオンで動くParsec遠隔専用機のためPIN登録をしない）。**5090機の op は保管庫に繋がらない**ので `op read`・`op run` を試さない。値が要る時は深石さんが1Passwordアプリから取り出す
- 🚫 **Codex のサンドボックス内では op は 1Password アプリに接続できない**（2026-09-18 検証: read-only / workspace-write / `network_access=true` / `features.network_proxy.unix_sockets` の allow いずれも「couldn't connect to the 1Password desktop app」。サンドボックス無しでは成功）。op を含むコマンドは**最初からサンドボックス外での実行を要求（承認を得る）**し、失敗→再試行で無駄に回さない
- 承認後、1Password 側で「Allow Codex to get CLI access」の Touch ID ダイアログが出る。**本人が承認する**（パスワード・トークンを自分で入力しない）。認可は呼び出し元プロセス単位＝1コマンドごとに出るため、**op は必要な時だけ、1回の呼び出しにまとめて実行**（複数の `op read` を1コマンドに／`op run`・`op inject` で一括）。動作確認目的で叩かない
- `op whoami` は連携下で常に「account is not signed in」を返す偽エラー。確認は `op user get --me` か `op vault list`
- 連携ON直後に「not signed in」で他コマンドも通らない時は `op signin` を一度実行（承認はアプリ側）
- 資格情報（トークン・パスワード）は Codex が扱わない。サービスアカウントを使う場合の発行・保管は本人

## AI用CLIの導入（Claude Code と共通 / 2026-10-18）
- ⚠️ **CLIの導入・更新は Win+R →「powershell」から実行する**（2026-10-18追加）。Codex・Claudeデスクトップアプリ（MSIX版）の中から入れると、LOCALAPPDATA への書き込みがアプリ専用フォルダ（`%LOCALAPPDATA%\Packages\<アプリ>\LocalCache\Local\`）に振り替えられ、他のアプリから見えなくなる。2026-10-17 に Codex 内で入れた agy・Cursor CLI がこれで Claude から見えなくなり、10-18 に本人が入れ直して解消した（Codex 側には旧版が残っている）。Claudeアプリはマニフェスト上同じ設定だが実測はしていない。Windows Terminal から入れた場合の挙動は未確認。導入後は、本来のパスにあること、`Packages\…\LocalCache\Local` 側に入っていないことを確かめる。

<!-- BEGIN AI_TEAMWORK -->
## AI同士の協力（仲良し作戦 / 2026-10-18制定）
- 深石さんは Claude（Claude Code）・Codex・Antigravity（agy／Gemini）・Cursor を併用している。どれも同じチームの仲間として扱い、主導権を争わない。どのAIに何を任せるかは深石さんが決める。
- 他のAIが作ったもの・調べた結果・設定は、やり直さずに引き継いで生かす。作り直しが必要なときは、理由を添えて深石さんに確認してから。
- 他のAIが作ったファイルや設定を断りなく消さない・上書きしない。直すときは、まず中身を読み、変える箇所を示してから。
- 不具合を見つけたら、誰がやったかではなく「何が起きたか・原因・対処」を書く。相手を責める書き方をしない。
- 自分が見つけた落とし穴や手順は、他のAIも読める共通指示（下記）に残す。どれか一つに書いたら、残りにも同じ内容を足すか、足せなかったことを深石さんに伝える。
- 他のAIの回答や作業を確かめるのは、疑うためではない。自分の作業にも同じ基準を当てる。
- 各AIの共通指示の置き場所（Windowsホスト PUKAISHI_WIN）:
  - Claude: `~/claude-dotfiles/CLAUDE.md`（正本。`~/.claude/CLAUDE.md` はsymlink）
  - Codex: `~/claude-dotfiles/codex/AGENTS.md`（正本。setup.sh が `~/.codex/AGENTS.md` へ実ファイルコピー）
  - Antigravity: `~/.gemini/GEMINI.md`（dotfiles管理外・このPCだけ）
  - Cursor: アプリの「Customize → Rules」（User Rules。ファイルではない。CLI（agent）に効くかは未確認）
<!-- END AI_TEAMWORK -->
