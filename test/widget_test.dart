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
    await tester.tap(find.text('結果を記録する'));
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
}
