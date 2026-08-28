// notta-inbox-datestamp（GAS版）— Notta_Inbox の新着ファイルへ YYMMDD_ プレフィックスを自動付与する
//
// 正本: claude-dotfiles/gas/notta-inbox-datestamp/Code.gs
//   （GAS側を編集したらこのファイルへ反映する。逆も同じ＝手動同期。デプロイ先は
//     fukaishi@nsketch.com の Apps Script プロジェクト「notta-inbox-datestamp」）
// 経緯: 旧launchd版(datestamp.sh)は launchd文脈のmvがGoogle Drive File Provider側で
//   巻き戻り機能しなかった（2026-08-28判明）→ Drive APIで改名するGAS版へ移行。
// 実行: 時間主導トリガーで1時間おき。タイムゾーンは Asia/Tokyo（appsscript.jsonで設定）。

const FOLDER_ID = '1GKIiPsh_4DwyO72_5H-4Zz-1-PbSdshA'; // My Drive/Notta_Inbox
const INSTALLED_AT = new Date('2026-08-28T00:00:00+09:00'); // これ以前に作成されたファイルは触らない（既存ファイル保護）

function datestampNottaInbox() {
  const folder = DriveApp.getFolderById(FOLDER_ID);
  const files = folder.getFiles();
  const renamed = [];
  while (files.hasNext()) {
    const file = files.next();
    let name = file.getName();
    if (file.getDateCreated() < INSTALLED_AT) continue;

    // パス1: 拡張子なし → 末尾空白を除去して .txt を付与（Zap側修正の保険）
    if (name.indexOf('.') === -1) {
      const withExt = name.replace(/\s+$/, '') + '.txt';
      if (!folder.getFilesByName(withExt).hasNext()) {
        file.setName(withExt);
        renamed.push(name + ' -> ' + withExt);
        name = withExt;
      }
    }

    // パス2: 先頭が6桁数字+_ でない .txt → 作成日(JST・Drive着弾日)由来の YYMMDD_ を前置
    if (/\.txt$/.test(name) && !/^\d{6}_/.test(name)) {
      const prefix = Utilities.formatDate(file.getDateCreated(), 'Asia/Tokyo', 'yyMMdd');
      const target = prefix + '_' + name;
      if (!folder.getFilesByName(target).hasNext()) {
        file.setName(target);
        renamed.push(name + ' -> ' + target);
      }
    }
  }
  console.log(renamed.length ? renamed.join('\n') : 'no files to rename');
}
