// 百問繚乱の結果を、生徒が自分で入力して記録する機能。
// 記録はこの端末（ブラウザ）の中だけに保存し、どこにも送らない。
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _storeKey = 'hyakumon_log_v1';

class Score {
  Score({
    required this.id,
    required this.date,
    required this.subject,
    required this.title,
    required this.score,
    required this.max,
  });

  factory Score.fromJson(Map<String, dynamic> j) => Score(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        subject: j['subject'] as String,
        title: (j['title'] ?? '') as String,
        score: (j['score'] as num).toDouble(),
        max: (j['max'] as num).toDouble(),
      );

  final String id;
  final DateTime date;
  final String subject;
  final String title;
  final double score;
  final double max;

  double get rate => max > 0 ? score / max : 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': ymd(date),
        'subject': subject,
        'title': title,
        'score': score,
        'max': max,
      };
}

String ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String num0(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

/// 端末内の保存。プライベートモードなどで保存できない場合も、画面は動くようにする。
class ScoreStore {
  static Future<List<Score>> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_storeKey);
      if (s == null) return [];
      return [for (final j in jsonDecode(s) as List) Score.fromJson(j as Map<String, dynamic>)]
        ..sort((a, b) => a.date.compareTo(b.date));
    } catch (_) {
      return [];
    }
  }

  static Future<bool> save(List<Score> list) async {
    try {
      final p = await SharedPreferences.getInstance();
      return await p.setString(_storeKey, jsonEncode([for (final s in list) s.toJson()]));
    } catch (_) {
      return false;
    }
  }
}

class ScoreLog extends StatefulWidget {
  const ScoreLog({super.key, required this.subjects});
  final List<String> subjects;

  @override
  State<ScoreLog> createState() => _ScoreLogState();
}

class _ScoreLogState extends State<ScoreLog> {
  List<Score> list = [];
  bool loaded = false;
  String? filter;

  @override
  void initState() {
    super.initState();
    ScoreStore.load().then((v) => setState(() {
          list = v;
          loaded = true;
        }));
  }

  Future<void> _commit(List<Score> next) async {
    next.sort((a, b) => a.date.compareTo(b.date));
    setState(() => list = next);
    final ok = await ScoreStore.save(next);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('この端末に保存できませんでした。プライベートモードでは記録が残りません。')));
    }
  }

  Future<void> _edit([Score? s]) async {
    final r = await showDialog<Score>(
      context: context,
      builder: (_) => _ScoreDialog(subjects: widget.subjects, initial: s, last: list.isEmpty ? null : list.last),
    );
    if (r == null) return;
    await _commit([for (final x in list) if (x.id != r.id) x, r]);
  }

  Future<void> _delete(Score s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('この記録を消しますか？'),
        content: Text('${ymd(s.date)}　${s.subject}　${num0(s.score)}/${num0(s.max)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('やめる')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('消す')),
        ],
      ),
    );
    if (ok == true) await _commit([for (final x in list) if (x.id != s.id) x]);
  }

  Future<void> _export() async {
    await Clipboard.setData(ClipboardData(text: jsonEncode([for (final s in list) s.toJson()])));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('記録をコピーしました。メモ帳などに貼り付けて保存できます。')));
    }
  }

  Future<void> _import() async {
    final ctl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('記録を読み込む'),
        content: TextField(
          controller: ctl,
          maxLines: 6,
          decoration: const InputDecoration(hintText: '「書き出す」でコピーした文字を貼り付け'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('やめる')),
          FilledButton(onPressed: () => Navigator.pop(c, ctl.text), child: const Text('読み込む')),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    try {
      final add = [for (final j in jsonDecode(text) as List) Score.fromJson(j as Map<String, dynamic>)];
      final ids = {for (final s in list) s.id};
      await _commit([...list, for (final s in add) if (!ids.contains(s.id)) s]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${add.length}件を読み込みました。')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('読み込めませんでした。貼り付けた文字を確かめてください。')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (!loaded) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
    final subjects = [...{for (final s in list) s.subject}];
    final shown = [for (final s in list.reversed) if (filter == null || s.subject == filter) s];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text('自分の記録', style: t.titleMedium)),
        PopupMenuButton<String>(
          tooltip: 'その他',
          onSelected: (v) => v == 'export' ? _export() : _import(),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'export', child: Text('書き出す（コピー）')),
            PopupMenuItem(value: 'import', child: Text('読み込む')),
          ],
        ),
      ]),
      const Text('百問繚乱で出た点数を自分で入力します。記録はこの端末の中だけに保存され、ほかの人には見えません。',
          style: TextStyle(fontSize: 13)),
      const SizedBox(height: 8),
      FilledButton.tonalIcon(onPressed: _edit, icon: const Icon(Icons.add), label: const Text('結果を記録する')),
      const SizedBox(height: 12),
      if (list.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('まだ記録がありません。百問繚乱で演習したら、点数を記録してみましょう。'),
          ),
        )
      else ...[
        for (final sub in subjects) _SubjectCard(subject: sub, scores: [for (final s in list) if (s.subject == sub) s]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          ChoiceChip(label: const Text('すべて'), selected: filter == null, onSelected: (_) => setState(() => filter = null)),
          for (final s in subjects)
            ChoiceChip(label: Text(s), selected: filter == s, onSelected: (_) => setState(() => filter = s)),
        ]),
        const SizedBox(height: 4),
        Card(
          child: Column(children: [
            for (final s in shown)
              ListTile(
                dense: true,
                title: Text('${s.subject}${s.title.isEmpty ? '' : '　${s.title}'}'),
                subtitle: Text(ymd(s.date)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${num0(s.score)} / ${num0(s.max)}', style: t.titleSmall),
                  IconButton(tooltip: '消す', icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => _delete(s)),
                ]),
                onTap: () => _edit(s),
              ),
          ]),
        ),
      ],
      const SizedBox(height: 8),
      const Text('※ブラウザの履歴やサイトのデータを消すと、記録も消えます。機種変更の前には「書き出す」で控えをとってください。',
          style: TextStyle(fontSize: 12)),
    ]);
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.subject, required this.scores});
  final String subject;
  final List<Score> scores;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final last = scores.last;
    final diff = scores.length > 1 ? (last.rate - scores[scores.length - 2].rate) * 100 : null;
    final avg = scores.map((s) => s.rate).reduce((a, b) => a + b) / scores.length * 100;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          Expanded(
            flex: 5,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(subject, style: t.titleSmall),
              const SizedBox(height: 2),
              Text('最新 ${(last.rate * 100).round()}%', style: t.headlineSmall),
              Text([
                '平均 ${avg.round()}%',
                '${scores.length}回',
                if (diff != null) '前回比 ${diff >= 0 ? '+' : ''}${diff.round()}',
              ].join('・'), style: t.bodySmall),
            ]),
          ),
          Expanded(
            flex: 6,
            child: SizedBox(
              height: 64,
              child: CustomPaint(painter: _Spark([for (final s in scores) s.rate], c.primary, c.outlineVariant)),
            ),
          ),
        ]),
      ),
    );
  }
}

/// 正答率（0〜100%）の推移を表す小さな折れ線。点線は50%の目安。
class _Spark extends CustomPainter {
  _Spark(this.v, this.color, this.grid);
  final List<double> v;
  final Color color, grid;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 6.0;
    final h = size.height - pad * 2, w = size.width - pad * 2;
    final g = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, pad + h / 2), Offset(x + 3, pad + h / 2), g);
    }
    Offset pt(int i) => Offset(
        pad + (v.length == 1 ? w / 2 : w * i / (v.length - 1)),
        pad + h * (1 - v[i].clamp(0, 1)));
    final line = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < v.length; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }
    canvas.drawPath(path, line);
    final dot = Paint()..color = color;
    for (var i = 0; i < v.length; i++) {
      canvas.drawCircle(pt(i), i == v.length - 1 ? 4 : 2.5, dot);
    }
  }

  @override
  bool shouldRepaint(_Spark o) => o.v != v || o.color != color;
}

class _ScoreDialog extends StatefulWidget {
  const _ScoreDialog({required this.subjects, this.initial, this.last});
  final List<String> subjects;
  final Score? initial;
  final Score? last;

  @override
  State<_ScoreDialog> createState() => _ScoreDialogState();
}

class _ScoreDialogState extends State<_ScoreDialog> {
  late DateTime date = widget.initial?.date ?? DateTime.now();
  late String subject = widget.initial?.subject ?? widget.last?.subject ?? widget.subjects.first;
  late final title = TextEditingController(text: widget.initial?.title ?? '');
  late final score = TextEditingController(text: widget.initial == null ? '' : num0(widget.initial!.score));
  late final max = TextEditingController(
      text: num0(widget.initial?.max ?? widget.last?.max ?? 100));
  String? error;

  void _ok() {
    final s = double.tryParse(score.text.trim()), m = double.tryParse(max.text.trim());
    if (s == null || m == null || m <= 0 || s < 0 || s > m) {
      setState(() => error = '点数は 0 以上・満点以下の数字で入力してください。');
      return;
    }
    Navigator.pop(
        context,
        Score(
          id: widget.initial?.id ??
              '${DateTime.now().microsecondsSinceEpoch}${math.Random().nextInt(999)}',
          date: date,
          subject: subject,
          title: title.text.trim(),
          score: s,
          max: m,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final subs = {...widget.subjects, subject}.toList();
    return AlertDialog(
      title: Text(widget.initial == null ? '結果を記録する' : '記録を直す'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DropdownButtonFormField<String>(
            initialValue: subject,
            decoration: const InputDecoration(labelText: '科目'),
            items: [for (final s in subs) DropdownMenuItem(value: s, child: Text(s))],
            onChanged: (v) => setState(() => subject = v!),
          ),
          TextField(
            controller: title,
            decoration: const InputDecoration(labelText: 'テスト名（なくてもよい）', hintText: '例：前期期末対策 第3回'),
          ),
          Row(children: [
            Expanded(
              child: TextField(
                controller: score,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: '点数'),
                autofocus: widget.initial == null,
              ),
            ),
            const Padding(padding: EdgeInsets.fromLTRB(8, 16, 8, 0), child: Text('/')),
            Expanded(
              child: TextField(
                controller: max,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: '満点'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text('日付　${ymd(date)}'),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2026, 4, 1),
                lastDate: DateTime(2029, 3, 31),
              );
              if (d != null) setState(() => date = d);
            },
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('やめる')),
        FilledButton(onPressed: _ok, child: const Text('保存')),
      ],
    );
  }
}
