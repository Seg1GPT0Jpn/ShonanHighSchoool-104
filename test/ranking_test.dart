import 'package:flutter_test/flutter_test.dart';
import 'package:shonan104/ranking.dart';
import 'package:shonan104/score_log.dart';

Score s(String title, String subject, double score, {DateTime? date}) => Score(
    id: '1', date: date ?? DateTime(2026, 8, 25), subject: subject, title: title, score: score, max: 100);

void main() {
  test('正答率を5%ごとの区間にする', () {
    expect(binOf(0), 0);
    expect(binOf(0.04), 0);
    expect(binOf(0.42), 8);
    expect(binOf(0.99), 19);
    expect(binOf(1), 20);
    expect(binLabel(8), '40〜44%');
  });

  test('定期試験の記録だけがランキングの対象になる', () {
    expect(rankKey(s('前期期末試験', '現代の国語', 42)), '2026_前期期末_現代の国語');
    expect(rankKey(s('52前期期末試験', '言語文化', 26)), '2026_前期期末_言語文化');
    expect(rankKey(s('学年末試験', '公共', 60, date: DateTime(2027, 3, 1))), '2026_学年末_公共');
    expect(rankKey(s('第3回 小テスト', '数学Ⅰ', 80)), isNull);
    expect(rankKey(s('前期期末試験', '', 80)), isNull);
  });

  test('上位何%かを分布から計算する', () {
    final c = {for (var b = 0; b <= 20; b++) b: 0}..addAll({4: 10, 8: 6, 12: 4});
    expect(topPercent(c, 12), 10);
    expect(topPercent(c, 8), 35);
  });
}
