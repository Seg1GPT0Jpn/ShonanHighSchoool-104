import 'package:flutter_test/flutter_test.dart';
import 'package:shonan104/main.dart';

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
}
