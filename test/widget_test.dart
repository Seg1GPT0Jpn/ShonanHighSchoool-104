import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shonan104/main.dart';
import 'package:shonan104/score_log.dart';

void main() {
  testWidgets('教材データを読み込んで一覧を出せる', (tester) async {
    await tester.pumpWidget(const PortalApp());
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(find.text('定期テスト・受験対策ポータル'), findsOneWidget);
    await tester.tap(find.text('教材').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('件'), findsWidgets);
  });

  testWidgets('百問繚乱の結果を記録して、端末に保存できる', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: ScoreLog(subjects: ['数学Ⅰ', '公共'])))));
    await tester.pumpAndSettle();
    expect(find.textContaining('まだ記録がありません'), findsOneWidget);
    await tester.tap(find.text('手で記録する'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '点数'), '72');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('最新 72%'), findsOneWidget);
    final saved = await ScoreStore.load();
    expect(saved.single.subject, '数学Ⅰ');
    expect(saved.single.score, 72);
  });

  test('満点に対する割合を計算する', () {
    final s = Score(id: '1', date: DateTime(2026, 10, 1), subject: '公共', title: '', score: 18, max: 20);
    expect(s.rate, 0.9);
    expect(Score.fromJson(s.toJson()).max, 20);
  });

  testWidgets('百問繚乱の一覧を貼り付けて、確認してから取り込める', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: ScoreLog(
                    subjects: const ['現代の国語', '数学Ⅰ'],
                    examDates: {'前期期末試験|現代の国語': DateTime(2026, 8, 25)})))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('百問繚乱から取り込む'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '紙\n前期期末試験\n現国\n42／100点\n53.2点\n紙\n前期期末試験\n数Ⅰ\n37／100点\n—');
    await tester.tap(find.text('読み取る'));
    await tester.pumpAndSettle();
    expect(find.text('2件見つかりました'), findsOneWidget);
    await tester.tap(find.text('2件を記録'));
    await tester.pumpAndSettle();
    final saved = await ScoreStore.load();
    expect(saved.length, 2);
    final g = saved.firstWhere((s) => s.subject == '現代の国語');
    expect(g.avg, 53.2);
    expect(ymd(g.date), '2026-08-25');
  });
}
