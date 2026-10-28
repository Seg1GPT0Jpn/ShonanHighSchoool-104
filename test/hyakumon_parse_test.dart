import 'package:flutter_test/flutter_test.dart';
import 'package:shonan104/hyakumon_parse.dart';

// 百問繚乱の画面（スクリーンショット）をもとに、コピーしたときの文字を再現したもの。
// 実際にコピーした文字は改行の位置などが違う可能性があるので、両方の形を試す。
const listByLine = '''
紙
前期期末試験
現国
42／100点
53.2点
 成績を見る
紙
前期期末試験
数Ⅰ
37／100点
—
 成績を見る
紙
52前期期末試験
言文
26／100点
44.8点
 成績を見る
紙
前期中間試験
論表Ⅰ
86／100点
68.3点
 成績を見る
''';

const listByRow = '''
紙	前期期末試験	化基	78／100点	—	成績を見る
紙	前期期末試験	数 I	37／100点	—	成績を見る
紙	前期期末試験	生基	70／100点	—	成績を見る
''';

const detail = '''
戻る
成績：前期期末試験 現代の国語
成績	答案
1	大問別 4点 / 10点
設問番号	正誤	得点/配点	全体平均
1 (1)		0点 / 1点	57.7%
1 (2)		1点 / 1点	71.3%
2	大問別 3点 / 10点
合計
42点 / 100点
全体平均
53.2点
''';

void main() {
  test('一覧画面（1行に1項目）から科目ごとの点数を読み取る', () {
    final r = parseHyakumon(listByLine);
    expect(r.length, 4);
    expect(r[0].subject, '現代の国語');
    expect(r[0].exam, '前期期末試験');
    expect(r[0].score, 42);
    expect(r[0].max, 100);
    expect(r[0].avg, 53.2);
    expect(r[1].subject, '数学Ⅰ');
    expect(r[1].avg, isNull);
    expect(r[2].subject, '言語文化');
    expect(r[2].exam, '前期期末試験');
    expect(r[3].exam, '前期中間試験');
    expect(r[3].subject, '論表Ⅰ');
  });

  test('一覧画面（表の1行がタブ区切り）から読み取る', () {
    final r = parseHyakumon(listByRow);
    expect([for (final p in r) p.subject], ['化学基礎', '数学Ⅰ', '生物基礎']);
    expect([for (final p in r) p.score], [78, 37, 70]);
  });

  test('成績画面では合計と全体平均だけを読み取り、大問別・設問別の点は使わない', () {
    final r = parseHyakumon(detail);
    expect(r.length, 1);
    expect(r.single.subject, '現代の国語');
    expect(r.single.exam, '前期期末試験');
    expect(r.single.score, 42);
    expect(r.single.avg, 53.2);
  });

  test('関係のない文字からは何も取り出さない', () {
    expect(parseHyakumon('こんにちは\n成績を見る'), isEmpty);
  });
}
