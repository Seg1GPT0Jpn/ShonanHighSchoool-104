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

## 百問繚乱の結果の記録

「百問繚乱」タブで、生徒が百問繚乱で出た点数を自分で入力し、科目別の推移を見られます（`lib/score_log.dart`）。

- 記録はその端末のブラウザの中（localStorage）だけに保存し、サーバーやGitHubには送りません
- 百問繚乱のID・パスワードは預からず、自動ログインや成績の取り込みもしません
- 機種変更のときは「書き出す」でコピーし、新しい端末で「読み込む」に貼り付けます
- 「百問繚乱から取り込む」：生徒が百問繚乱の一覧画面か成績画面の文字を自分でコピーして貼り付けると、科目・点数・全体平均を読み取る（`lib/hyakumon_parse.dart`）。確認画面で本人が見直してから保存する。貼り付けた文字は保存しない

## 匿名ランキング（分布）

「百問繚乱」タブの「みんなの中での位置（匿名）」。学校のGoogleアカウントでログインした人だけが参加・閲覧でき、送るのは5%ごとの区間だけ。参加者が20人以上になるまで分布は誰にも見えない（`lib/ranking.dart`、`firestore.rules`）。

使えるようにする手順は `docs/ranking_setup.md`。ルールの自動テストは `firestore_test/`（push のたびに GitHub Actions で実行）。

## 教材ファイル

`web/materials/` に置いた PDF が、そのままサイトから開けます（ファイル名は教材ID）。

- 過去問は、先生の許可を得たうえで、氏名・組・番号と書き込みを消した版（v2）だけを置いています
- 「AI作成」の解答・解説は学校の正式解答ではありません

このリポジトリは公開されていて、世界中の誰でも見られます。次のものは入れないでください。

- 氏名・組・番号や書き込みが残ったスキャン（原本）
- 管理台帳、担当者の名前、学校アカウント、百問繚乱のID・パスワード

## 開発

```
flutter pub get
flutter run -d chrome
flutter test
```
