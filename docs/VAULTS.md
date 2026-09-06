# Vaults / データ保管庫

Bookmark の **Vault（データ保管庫）** は、アプリのデータ一式を置く物理的な保存場所です。Workspace は Vault 内の論理的な整理単位であり、Vault そのものとは別の概念です。

## Vault の内容

現在の Vault 形式は次の構成です。

```text
<My Vault>/
├─ database.sqlite
├─ profile.json
├─ photos/
└─ attachments/
```

- `database.sqlite` — Object、ObjectType、Database、View、Relation などの構造化データ
- `profile.json` — portable な Vault 識別情報
- `photos/` — Bookmark が管理する写真
- `attachments/` — Bookmark が管理する添付ファイル

`profile.json` は Vault 自身の絶対パスを保存しません。写真や添付ファイルも、Vault 内で管理されるものは可能な限り Vault-relative な保存パスを使用します。このため、完全な Vault 一式を別の場所へ復元しても同じ内部構造を解決できます。

## 新しい Vault を作成する

新規作成では、ユーザーがフォルダ選択 UI で保存先を選びます。Bookmark は既存ファイルを誤って上書きしないため、空の保存先だけを新規 Vault として初期化します。

初期化時には現在の通常のデータベーススキーマを使って `database.sqlite` を作成し、`profile.json`、`photos/`、`attachments/` を用意します。作成に失敗した場合は、その Vault を有効な登録済み Vault として扱いません。

## 既存の Vault を開く

既存 Vault を開く場合、Bookmark は選択されたフォルダをその場所のまま使用します。アプリ管理フォルダへ自動コピーしません。

少なくとも `profile.json` と `database.sqlite` が必要です。不正または不完全なフォルダは fail closed とし、現在の Vault を置き換えません。互換性のあるデータベースを開く際のスキーマ更新は通常の `AppDatabase` migration 経路を使用します。

## Vault の切り替え

Vault の切り替えでは、同じ Vault に対して別の `AppDatabase` グラフを並行して開きません。現在のデータベースを既存の Profile/Vault bootstrap lifecycle で閉じ、選択した Vault を通常の起動経路で開き直します。

切り替えに失敗した場合は以前の Vault へ戻すことを優先し、失敗した切り替えを成功として扱いません。

## Vault が見つからない場合

外付けドライブが外れている、クラウドフォルダがオフラインになっている、フォルダを Finder で移動した、などの理由で登録済み Vault が見つからないことがあります。

Bookmark はその場合に同じ論理 Vault 名で空の `database.sqlite` を自動作成しません。空データへ置き換わったように見える事故を防ぐためです。

将来の「場所を再指定」操作では、候補フォルダが同じ Vault ID を持つことと、実際の SQLite データベースを含むことを確認したうえで、登録情報の保存パスだけを修復します。元の場所を自動削除することはありません。

## iCloud Drive / Google Drive / Dropbox / 外付けドライブ

Vault は通常の filesystem folder なので、iCloud Drive、Google Drive、Dropbox、外付けドライブなどを保存場所として選ぶこと自体は可能です。ただし、これは Bookmark 独自の同期プロトコルではありません。

特に SQLite データベースを含むため、次の制約があります。

- **同じ Vault を複数のコンピュータや複数の Bookmark プロセスから同時編集することはサポートしません。**
- クラウド同期中の競合、部分同期、オフライン placeholder、外付けドライブの切断などは外部 filesystem の状態に依存します。
- Vault が一時的に利用できない場合、Bookmark は空の代替 Vault を自動生成せず fail closed します。
- 別端末で使う場合は、同期が完了していることを確認し、同じ Vault を同時に開かない運用を推奨します。

クラウドフォルダ対応は best-effort の保存場所対応であり、リアルタイム共同編集や競合解決を保証するものではありません。

## バックアップと復元

Profile/Vault バックアップは `database.sqlite`、`profile.json`、`photos/`、`attachments/` を含む完全な portable data set として扱います。

復元先が元の絶対パスと異なっていても、Vault-relative な管理ファイル参照は新しい Vault root から解決されます。外部にある絶対ファイル参照は、Vault 内へ黙ってコピーしたり書き換えたりしません。

## Vault の移動

Vault の安全な移動は単純な `directoryPath` 書き換えではありません。実装時は次の順序を守ります。

1. 新しい書き込みを止め、active database を安全に閉じる。
2. SQLite の WAL/SHM を含む状態を durable にする。
3. Vault 全体を移動先へコピーする。
4. database、metadata、managed media、attachments を移動先で検証する。
5. 検証後に registry path を更新する。
6. 新しい場所から通常の起動経路で再オープンする。
7. 再オープン成功前に元の Vault を削除しない。

失敗した移動は元の Vault をそのまま残すことが必須です。

## データ安全上の原則

- missing Vault を空データで自動置換しない。
- non-empty folder を新規 Vault 作成で上書きしない。
- Open は選択した Vault をその場所で使用し、自動コピーしない。
- 外部/custom Vault を登録解除しても、物理ファイルを自動削除しない。
- Move は移動先の検証と再オープン成功前に元データを削除しない。
- 外部絶対ファイル参照を黙ってコピー・書き換えしない。
- filesystem 例外の内部パスや詳細をユーザー向けエラーへ不用意に露出しない。
