# 104回生 定期テスト・受験対策ポータル（非公式）

湘南高校104回生の生徒が作っている、非公式のテスト対策ポータルです。Flutterで作っていて、Webとスマホアプリの両方に対応しています。

公開URL: https://seg1gpt0jpn.github.io/ShonanHighSchoool-104/

## 自動更新

`main` に push すると、GitHub Actions（`.github/workflows/deploy.yml`）が次の順に動き、数分でサイトが更新されます。

1. `flutter analyze` と `flutter test`
2. `flutter build web`
3. GitHub Pages へ公開

## 教材の追加・更新

アプリに表示される教材と日程は、次のファイルから読み込んでいます。

- `assets/data/materials.json`：教材の一覧
- `assets/data/schedule.json`：テスト日程

管理台帳（xlsx）から作り直すときは、次を実行します。

```
python3 tools/ledger_to_json.py 管理台帳_104回生.xlsx
```

教材の `url` が空のときは「準備中」と表示されます。URLを入れると、タップしたときにそのURLが開きます。

## このリポジトリに入れないもの

このリポジトリは公開されていて、世界中の誰でも見られます。そのため、次のものは入れません（`.gitignore` で除外しています）。

- 試験問題のスキャン（氏名・組・番号・書き込みが写っています）
- 解答解説PDFなどの教材ファイル、管理台帳
- 担当者の名前、学校アカウント、百問繚乱のID・パスワード

教材ファイルは閲覧を制限できる場所に置き、`url` にはそのリンクを入れます。

## 開発

```
flutter pub get
flutter run -d chrome
flutter test
```
