// 百問繚乱の結果の「匿名ランキング（分布）」。
// ・学校のGoogleアカウントでログインした人だけが参加・閲覧できる（firestore.rules で強制）
// ・サーバーに送るのは「5%ごとの区間」だけ。点数そのもの・名前・メールアドレスは送らない
// ・ほかの人に見えるのは、区間ごとの人数だけ。参加者が20人未満のあいだは誰にも見えない
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_config.dart';
import 'score_log.dart';

const minParticipants = 20;

/// 正答率 → 区間（0〜20。0は0〜4%、19は95〜99%、20は100%）
int binOf(double rate) => (rate.clamp(0, 1) * 100 ~/ 5).clamp(0, 20).toInt();

String binLabel(int b) => b == 20 ? '100%' : '${b * 5}〜${b * 5 + 4}%';

String binField(int b) => 'b${b.toString().padLeft(2, '0')}';

/// 記録から、ランキングの対象（学校の定期試験）を表すキーを作る。対象外なら null
/// 例：2026年度 前期期末試験 現代の国語 → 2026_前期期末_現代の国語
String? rankKey(Score s) {
  final m = RegExp(r'(前期中間|前期期末|後期中間|学年末)試験').firstMatch(s.title);
  if (m == null || s.subject.isEmpty) return null;
  final year = s.date.month < 4 ? s.date.year - 1 : s.date.year;
  return '${year}_${m.group(1)}_${s.subject}';
}

/// 上位何%か（同じ区間の人は半分ずつ上下にいるとみなす）
double topPercent(Map<int, int> counts, int mine) {
  final total = counts.values.fold(0, (a, b) => a + b);
  if (total == 0) return 0;
  var above = 0;
  for (final e in counts.entries) {
    if (e.key > mine) above += e.value;
  }
  return (above + (counts[mine] ?? 0) / 2) / total * 100;
}

bool isSchoolAccount(User? u) =>
    u != null && u.emailVerified && (u.email ?? '').toLowerCase().endsWith('@${schoolDomain.toLowerCase()}');

class RankingSection extends StatefulWidget {
  const RankingSection({super.key, required this.scores});
  final List<Score> scores;

  @override
  State<RankingSection> createState() => _RankingSectionState();
}

class _RankingSectionState extends State<RankingSection> {
  String? error;

  Future<void> _signIn() async {
    setState(() => error = null);
    try {
      final p = GoogleAuthProvider()..setCustomParameters({'hd': schoolDomain, 'prompt': 'select_account'});
      final c = await FirebaseAuth.instance.signInWithPopup(p);
      if (!isSchoolAccount(c.user)) {
        await FirebaseAuth.instance.signOut();
        setState(() => error = '学校のGoogleアカウント（@$schoolDomain）でログインしてください。');
      }
    } catch (e) {
      setState(() => error = 'ログインできませんでした。');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final head = [
      Text('みんなの中での位置（匿名）', style: t.titleMedium),
      const SizedBox(height: 4),
      const Text('定期試験の結果を、名前を出さずに持ち寄って、点数の分布を見られます。'
          '送るのは「5%ごとの区間」だけで、点数そのもの・名前・メールアドレスは送りません。'
          '参加者が$minParticipants人になるまでは、分布は誰にも表示されません。',
          style: TextStyle(fontSize: 13)),
      const SizedBox(height: 8),
    ];
    if (!rankingConfigured) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ...head,
        const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('準備中です（委員会が設定すると使えるようになります）。'))),
      ]);
    }
    if (!kIsWeb) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ...head,
        const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('ランキングはWeb版で使えます。'))),
      ]);
    }
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        final u = snap.data;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ...head,
          if (!isSchoolAccount(u)) ...[
            FilledButton.icon(
              onPressed: _signIn,
              icon: const Icon(Icons.login),
              label: const Text('学校のGoogleアカウントでログイン'),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ] else ...[
            Row(children: [
              Expanded(child: Text('ログイン中', style: t.bodySmall)),
              TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('ログアウト')),
            ]),
            ..._targets().entries.map((e) => _RankCard(key: ValueKey(e.key), rankKey: e.key, latest: e.value, uid: u!.uid)),
            if (_targets().isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('対象の記録がありません。百問繚乱から定期試験（前期期末試験など）の結果を取り込むと、ここに出ます。'),
                ),
              ),
          ],
        ]);
      },
    );
  }

  /// キーごとに一番新しい記録
  Map<String, Score> _targets() {
    final m = <String, Score>{};
    for (final s in widget.scores) {
      final k = rankKey(s);
      if (k != null && (m[k] == null || !s.date.isBefore(m[k]!.date))) m[k] = s;
    }
    return m;
  }
}

class _RankCard extends StatefulWidget {
  const _RankCard({super.key, required this.rankKey, required this.latest, required this.uid});
  final String rankKey;
  final Score latest;
  final String uid;

  @override
  State<_RankCard> createState() => _RankCardState();
}

class _RankCardState extends State<_RankCard> {
  int? myBin; // サーバー上の自分の区間（未参加なら null）
  Map<int, int>? counts; // 20人未満なら null
  bool loading = true, busy = false;
  String? msg;

  FirebaseFirestore get db => FirebaseFirestore.instance;
  DocumentReference<Map<String, dynamic>> get entry =>
      db.collection('entries').doc(widget.rankKey).collection('users').doc(widget.uid);
  DocumentReference<Map<String, dynamic>> get hist => db.collection('hist').doc(widget.rankKey);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final e = await entry.get();
      myBin = e.exists ? (e.data()!['b'] as num).toInt() : null;
    } catch (_) {
      myBin = null;
    }
    try {
      final h = await hist.get();
      counts = {for (var b = 0; b <= 20; b++) b: ((h.data()?[binField(b)] ?? 0) as num).toInt()};
    } catch (_) {
      counts = null; // 20人未満のあいだは、ルールで読めない
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _write(int? before, int? after) async {
    setState(() {
      busy = true;
      msg = null;
    });
    try {
      final w = db.batch();
      final d = <String, dynamic>{'total': FieldValue.increment((after == null ? 0 : 1) - (before == null ? 0 : 1))};
      if (before != null) d[binField(before)] = FieldValue.increment(-1);
      if (after != null) d[binField(after)] = FieldValue.increment(1);
      if (after == null) {
        w.delete(entry);
      } else {
        w.set(entry, {'b': after});
      }
      w.set(hist, d, SetOptions(merge: true));
      await w.commit();
      await _load();
    } catch (_) {
      setState(() => msg = 'うまく送れませんでした。もう一度試してください。');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = widget.latest;
    final localBin = binOf(s.rate);
    final parts = widget.rankKey.split('_');
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${parts[1]}試験　${parts.sublist(2).join('_')}', style: t.titleSmall),
          Text('自分の記録：${num0(s.score)} / ${num0(s.max)}（区間 ${binLabel(localBin)}）', style: t.bodySmall),
          const SizedBox(height: 8),
          if (loading)
            const LinearProgressIndicator()
          else ...[
            if (counts == null)
              const Text('参加者が20人になるまで、分布は表示されません。')
            else
              _Histogram(counts: counts!, mine: myBin),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (myBin == null)
                FilledButton.tonal(
                    onPressed: busy ? null : () => _write(null, localBin), child: const Text('匿名で参加する'))
              else ...[
                Text('参加中（区間 ${binLabel(myBin!)}）', style: t.bodySmall),
                if (myBin != localBin)
                  OutlinedButton(
                      onPressed: busy ? null : () => _write(myBin, localBin), child: const Text('記録に合わせて直す')),
                TextButton(onPressed: busy ? null : () => _write(myBin, null), child: const Text('参加をやめる')),
              ],
            ]),
            if (msg != null) Text(msg!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ]),
      ),
    );
  }
}

class _Histogram extends StatelessWidget {
  const _Histogram({required this.counts, this.mine});
  final Map<int, int> counts;
  final int? mine;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final total = counts.values.fold(0, (a, b) => a + b);
    final peak = counts.values.fold(1, (a, b) => b > a ? b : a);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
        mine == null
            ? '参加者 $total人'
            : '参加者 $total人のうち、上位 約${topPercent(counts, mine!).round()}%',
        style: t.titleSmall,
      ),
      const SizedBox(height: 6),
      SizedBox(
        height: 90,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var b = 0; b <= 20; b++)
            Expanded(
              child: Tooltip(
                message: '${binLabel(b)}：${counts[b] ?? 0}人',
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  height: 4 + 86 * (counts[b] ?? 0) / peak,
                  decoration: BoxDecoration(
                    color: b == mine ? c.primary : c.primaryContainer,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                ),
              ),
            ),
        ]),
      ),
      Row(children: [
        Text('0%', style: t.bodySmall),
        const Spacer(),
        Text('50%', style: t.bodySmall),
        const Spacer(),
        Text('100%', style: t.bodySmall),
      ]),
      if (mine != null) Text('濃い色が自分の区間です。', style: t.bodySmall),
    ]);
  }
}
