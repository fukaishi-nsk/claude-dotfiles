#!/usr/bin/env python3
"""Gmail API で From（送信元）を指定した下書きを作る。

Gmail コネクタの create_draft は From を指定できず、下書きが常に fukaishi@ 名義になる。
このスクリプトは Gmail API を直接呼び、登録済みの送信元（support@nanco.io など）を
From に入れた下書きを作る。返信なら元のスレッドに入れ、元メールを引用する。

認証ファイル（どちらも中身を表示しない・チャットに貼らない）:
  ~/.config/claude-gmail/client_secret.json  … Google Cloud の OAuth クライアント（デスクトップ）。深石さんが置く
  ~/.config/claude-gmail/token.json          … 初回 `auth` で作られる。権限 600

使い方:
  gmail_draft.py auth                         # 初回だけ。ブラウザで許可する
  gmail_draft.py send-as                      # 使える送信元の一覧
  gmail_draft.py create --from support@nanco.io --to a@example.com [--cc b@example.com ...] \
      --subject "件名" --html-file body.html [--text-file body.txt] [--reply-to <Gmailのmessage id>]
  gmail_draft.py show <draft id>              # 下書きの From・To・Cc・件名・threadId を表示
"""
import argparse
import base64
import html
import json
import os
import sys
from email.message import EmailMessage
from email.utils import formataddr

CONF = os.path.expanduser("~/.config/claude-gmail")
CLIENT = os.path.join(CONF, "client_secret.json")
TOKEN = os.path.join(CONF, "token.json")
SCOPES = [
    "https://www.googleapis.com/auth/gmail.compose",
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/gmail.settings.basic",
]


def service():
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from googleapiclient.discovery import build

    if not os.path.exists(TOKEN):
        sys.exit("token.json がありません。先に `gmail_draft.py auth` を実行してください")
    creds = Credentials.from_authorized_user_file(TOKEN, SCOPES)
    if not creds.valid:
        if creds.expired and creds.refresh_token:
            creds.refresh(Request())
            _save(creds)
        else:
            sys.exit("認証が切れています。`gmail_draft.py auth` をやり直してください")
    return build("gmail", "v1", credentials=creds, cache_discovery=False)


def _save(creds):
    os.makedirs(CONF, exist_ok=True)
    fd = os.open(TOKEN, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(creds.to_json())


def cmd_auth(_):
    from google_auth_oauthlib.flow import InstalledAppFlow

    if not os.path.exists(CLIENT):
        sys.exit(f"{CLIENT} がありません。OAuth クライアント（デスクトップ）の JSON をここに置いてください")
    flow = InstalledAppFlow.from_client_secrets_file(CLIENT, SCOPES)
    creds = flow.run_local_server(port=0, prompt="consent")
    _save(creds)
    print("認証できました（token.json を保存・中身は表示しません）")


def send_as_list(svc):
    return svc.users().settings().sendAs().list(userId="me").execute().get("sendAs", [])


def cmd_send_as(_):
    for s in send_as_list(service()):
        print(s["sendAsEmail"], "|", s.get("displayName", ""), "| 既定" if s.get("isDefault") else "",
              "| 確認済み" if s.get("verificationStatus", "accepted") == "accepted" else "| 未確認")


def _header(msg, name):
    for h in msg["payload"].get("headers", []):
        if h["name"].lower() == name.lower():
            return h["value"]
    return ""


def _html_part(payload):
    """元メールの本文（HTML があれば HTML、なければテキストを HTML 化）を返す。"""
    def walk(p):
        yield p
        for c in p.get("parts", []) or []:
            yield from walk(c)

    found = {}
    for p in walk(payload):
        mt, data = p.get("mimeType"), p.get("body", {}).get("data")
        if data and mt in ("text/html", "text/plain") and mt not in found:
            found[mt] = base64.urlsafe_b64decode(data).decode("utf-8", "replace")
    if "text/html" in found:
        return found["text/html"]
    return html.escape(found.get("text/plain", "")).replace("\n", "<br>")


def cmd_create(a):
    svc = service()
    allowed = {s["sendAsEmail"].lower(): s for s in send_as_list(svc)}
    if a.from_.lower() not in allowed:
        sys.exit(f"{a.from_} は送信元として登録されていません。使えるのは: {', '.join(allowed)}")
    sender = allowed[a.from_.lower()]

    html_body = open(a.html_file, encoding="utf-8").read()
    text_body = open(a.text_file, encoding="utf-8").read() if a.text_file else None

    msg = EmailMessage()
    msg["From"] = formataddr((sender.get("displayName", ""), sender["sendAsEmail"])) if sender.get("displayName") else sender["sendAsEmail"]
    msg["To"] = ", ".join(a.to)
    if a.cc:
        msg["Cc"] = ", ".join(a.cc)
    subject = a.subject
    thread_id = None

    if a.reply_to:
        orig = svc.users().messages().get(userId="me", id=a.reply_to, format="full").execute()
        thread_id = orig["threadId"]
        mid = _header(orig, "Message-ID")
        refs = _header(orig, "References")
        if mid:
            msg["In-Reply-To"] = mid
            msg["References"] = (refs + " " + mid).strip()
        if not subject:
            s = _header(orig, "Subject")
            subject = s if s.lower().startswith(("re:", "re：")) else "Re: " + s
        if not a.no_quote:
            when, who = _header(orig, "Date"), _header(orig, "From")
            html_body += (
                '<br><div class="gmail_quote"><div dir="ltr" class="gmail_attr">'
                f"{html.escape(when)} {html.escape(who)}:<br></div>"
                '<blockquote class="gmail_quote" style="margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex">'
                f"{_html_part(orig['payload'])}</blockquote></div>"
            )
    msg["Subject"] = subject

    msg.set_content(text_body or "")
    msg.add_alternative(html_body, subtype="html")
    raw = base64.urlsafe_b64encode(msg.as_bytes()).decode()
    body = {"message": {"raw": raw}}
    if thread_id:
        body["message"]["threadId"] = thread_id
    d = svc.users().drafts().create(userId="me", body=body).execute()
    print(json.dumps({"draftId": d["id"], "messageId": d["message"]["id"],
                      "threadId": d["message"].get("threadId")}, ensure_ascii=False))


def cmd_show(a):
    svc = service()
    d = svc.users().drafts().get(userId="me", id=a.draft_id, format="metadata").execute()
    m = d["message"]
    out = {k: _header(m, k) for k in ("From", "To", "Cc", "Subject", "In-Reply-To")}
    out["threadId"] = m.get("threadId")
    print(json.dumps(out, ensure_ascii=False, indent=1))


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("auth").set_defaults(fn=cmd_auth)
    sub.add_parser("send-as").set_defaults(fn=cmd_send_as)
    c = sub.add_parser("create")
    c.add_argument("--from", dest="from_", required=True)
    c.add_argument("--to", nargs="+", required=True)
    c.add_argument("--cc", nargs="*", default=[])
    c.add_argument("--subject", default="")
    c.add_argument("--html-file", required=True)
    c.add_argument("--text-file")
    c.add_argument("--reply-to", help="返信先の Gmail message id")
    c.add_argument("--no-quote", action="store_true", help="元メールを引用しない")
    c.set_defaults(fn=cmd_create)
    s = sub.add_parser("show")
    s.add_argument("draft_id")
    s.set_defaults(fn=cmd_show)
    a = p.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
