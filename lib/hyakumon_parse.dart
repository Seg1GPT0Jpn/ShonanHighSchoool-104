// 百問繚乱の画面からコピーした文字を読み取り、点数の候補を取り出す。
// 生徒が自分の画面を自分でコピーして貼り付ける前提で、ポータルから百問繚乱にはアクセスしない。
// 取り出した候補は必ず確認画面で本人が見直してから保存する。

/// 百問繚乱の科目の略称 → ポータルの科目名
const subjectAliases = {
  '現国': '現代の国語',
  '現代の国語': '現代の国語',
  '言文': '言語文化',
  '言語文化': '言語文化',
  '数I': '数学Ⅰ',
  '数Ⅰ': '数学Ⅰ',
  '数学I': '数学Ⅰ',
  '数学Ⅰ': '数学Ⅰ',
  '数A': '数学A',
  '数学A': '数学A',
  '化基': '化学基礎',
  '化学基礎': '化学基礎',
  '生基': '生物基礎',
  '生物基礎': '生物基礎',
  '論表I': '論表Ⅰ',
  '論表Ⅰ': '論表Ⅰ',
  '論理表現I': '論表Ⅰ',
  '論理表現Ⅰ': '論表Ⅰ',
  '英コI': 'ECⅠ',
  '英コⅠ': 'ECⅠ',
  'ECI': 'ECⅠ',
  'ECⅠ': 'ECⅠ',
  '英語コミュニケーションI': 'ECⅠ',
  '英語コミュニケーションⅠ': 'ECⅠ',
  '公共': '公共',
  '地総': '地理総合',
  '地理総合': '地理総合',
  '情I': '情報Ⅰ',
  '情Ⅰ': '情報Ⅰ',
  '情報I': '情報Ⅰ',
  '情報Ⅰ': '情報Ⅰ',
};

class Parsed {
  Parsed({required this.exam, required this.subject, required this.score, required this.max, this.avg});
  final String exam;
  final String subject;
  final double score;
  final double max;
  final double? avg;

  @override
  String toString() => '$exam/$subject $score/$max avg=$avg';
}

/// 全角の英数字・記号を半角にそろえ、空白を詰める
String normalize(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if (r >= 0xFF01 && r <= 0xFF5E) {
      b.writeCharCode(r - 0xFEE0);
    } else if (r == 0x3000) {
      b.write(' ');
    } else {
      b.writeCharCode(r);
    }
  }
  return b.toString();
}

String? toSubject(String raw) {
  final k = normalize(raw).replaceAll(RegExp(r'\s+'), '');
  return subjectAliases[k];
}

final _examRe = RegExp(r'(前期|後期)?(中間|期末)試験|学年末試験|[^\s]*(模試|テスト)');
final _scoreRe = RegExp(r'(\d+(?:\.\d+)?)\s*点?\s*/\s*(\d+(?:\.\d+)?)\s*点');
final _avgRe = RegExp(r'^\s*(\d+(?:\.\d+)?)\s*点\s*$');

String? _exam(String line) => _examRe.firstMatch(line)?.group(0);

/// 貼り付けた文字から点数の候補を取り出す。
/// ・一覧画面：「前期期末試験 / 現国 / 42／100点 / 53.2点」のような並びが繰り返される
/// ・成績画面：「成績：前期期末試験 現代の国語 … 合計 42点 / 100点 … 全体平均 53.2点」
List<Parsed> parseHyakumon(String text) {
  final lines = [
    for (final l in normalize(text).split(RegExp(r'\r?\n')))
      if (l.trim().isNotEmpty) l.trim()
  ];

  // 成績画面：合計と全体平均だけを使う（大問別・設問別の点は使わない）
  final header = RegExp(r'成績\s*[:：]\s*(.+)').firstMatch(lines.join('\n'));
  final total = lines.indexWhere((l) => l.startsWith('合計'));
  if (header != null && total >= 0) {
    final h = header.group(1)!;
    final exam = _exam(h) ?? '';
    final subjRaw = h.replaceFirst(exam, '').trim();
    final joined = lines.sublist(total).join(' ');
    final m = _scoreRe.firstMatch(joined);
    if (m != null) {
      final a = RegExp(r'全体平均\s*(\d+(?:\.\d+)?)\s*点').firstMatch(joined);
      return [
        Parsed(
          exam: exam,
          subject: toSubject(subjRaw) ?? subjRaw,
          score: double.parse(m.group(1)!),
          max: double.parse(m.group(2)!),
          avg: a == null ? null : double.parse(a.group(1)!),
        )
      ];
    }
  }

  // 一覧画面：点数の行を起点に、前にある科目名・試験名、後ろにある平均を探す
  final out = <Parsed>[];
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    final m = _scoreRe.firstMatch(l);
    if (m == null || l.contains('大問')) continue;

    // 同じ行に科目名・試験名が入っていることもある（表の行がまとめてコピーされた場合）
    String? subject, exam;
    final before = l.substring(0, m.start);
    final words = before.split(RegExp(r'\s+'));
    for (var k = 0; k < words.length && subject == null; k++) {
      // 「数 I」のように科目名の途中に空白が入ることがある
      subject = toSubject(words[k]) ?? (k + 1 < words.length ? toSubject(words[k] + words[k + 1]) : null);
    }
    exam = _exam(before);
    for (var j = i - 1; j >= 0 && j >= i - 4 && (subject == null || exam == null); j--) {
      if (_scoreRe.hasMatch(lines[j])) break;
      subject ??= toSubject(lines[j]);
      exam ??= _exam(lines[j]);
    }

    double? avg;
    final after = l.substring(m.end).trim();
    final am = RegExp(r'^(\d+(?:\.\d+)?)\s*点').firstMatch(after);
    if (am != null) {
      avg = double.parse(am.group(1)!);
    } else if (i + 1 < lines.length) {
      final nm = _avgRe.firstMatch(lines[i + 1]);
      if (nm != null) avg = double.parse(nm.group(1)!);
    }

    out.add(Parsed(
      exam: exam ?? '',
      subject: subject ?? '',
      score: double.parse(m.group(1)!),
      max: double.parse(m.group(2)!),
      avg: avg,
    ));
  }
  return out;
}
