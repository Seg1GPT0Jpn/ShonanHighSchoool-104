import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'score_log.dart';

const hyakumonUrl =
    'https://shonan544-kanagawapref.s.simple-edu.co.jp/#/student/exam_list';
const repoUrl = 'https://github.com/Seg1GPT0Jpn/ShonanHighSchoool-104';

void main() => runApp(const PortalApp());

class Item {
  Item(Map<String, dynamic> j)
      : id = j['id'],
        exam = j['exam'],
        subject = j['subject'],
        unit = j['unit'],
        kind = j['kind'],
        method = j['method'],
        check = j['check'],
        updated = j['updated'],
        version = j['version'],
        url = j['url'];
  final String id, exam, subject, unit, kind, method, check, updated, version, url;
  bool get isAi => method.contains('AI');
  bool get needsCheck => isAi && check != '委員確認済み';
}

class Exam {
  Exam(Map<String, dynamic> j)
      : exam = j['exam'],
        date = j['date'],
        subject = j['subject'],
        period = j['period'],
        range = j['range'];
  final String exam, date, subject, period, range;
}

class Data {
  Data(this.materials, this.schedule);
  final List<Item> materials;
  final List<Exam> schedule;

  static Future<Data> load() async {
    Future<List> read(String p) async =>
        jsonDecode(await rootBundle.loadString(p)) as List;
    return Data(
      [for (final j in await read('assets/data/materials.json')) Item(j)],
      [for (final j in await read('assets/data/schedule.json')) Exam(j)],
    );
  }
}

// 教材は相対パス（materials/…）で持っているので、ページのURLを基準に開く
Future<void> open(String url) =>
    launchUrl(Uri.base.resolve(url), mode: LaunchMode.externalApplication);

class PortalApp extends StatelessWidget {
  const PortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
          colorSchemeSeed: const Color(0xFF1F5FA8),
          brightness: b,
          useMaterial3: true,
        );
    return MaterialApp(
      title: '104回生 テスト対策ポータル',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: FutureBuilder(
        future: Data.load(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Scaffold(body: Center(child: Text('読み込みに失敗しました: ${snap.error}')));
          }
          if (!snap.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return Shell(data: snap.data!);
        },
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key, required this.data});
  final Data data;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;

  static const dests = [
    (Icons.home_outlined, Icons.home, 'ホーム'),
    (Icons.menu_book_outlined, Icons.menu_book, '教材'),
    (Icons.event_outlined, Icons.event, '日程'),
    (Icons.quiz_outlined, Icons.quiz, '百問繚乱'),
    (Icons.flag_outlined, Icons.flag, '誤り報告'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(data: widget.data, go: (i) => setState(() => tab = i)),
      FindPage(materials: widget.data.materials),
      SchedulePage(schedule: widget.data.schedule),
      HyakumonPage(subjects: [...{for (final m in widget.data.materials) m.subject}]),
      const ReportPage(),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final body = SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: pages[tab],
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('104回生 テスト対策ポータル')),
      body: wide
          ? Row(children: [
              NavigationRail(
                selectedIndex: tab,
                onDestinationSelected: (i) => setState(() => tab = i),
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final d in dests)
                    NavigationRailDestination(
                        icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ])
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
              destinations: [
                for (final d in dests)
                  NavigationDestination(
                      icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
              ],
            ),
    );
  }
}

class Notice extends StatelessWidget {
  const Notice(this.text, {super.key, this.icon = Icons.info_outline});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Card(
      color: c.tertiaryContainer,
      child: ListTile(
        leading: Icon(icon, color: c.onTertiaryContainer),
        title: Text(text, style: TextStyle(color: c.onTertiaryContainer)),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.data, required this.go});
  final Data data;
  final void Function(int) go;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ms = data.materials;
    final ready = ms.where((m) => m.url.isNotEmpty).length;
    final subjects = ms.map((m) => m.subject).toSet().length;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('定期テスト・受験対策ポータル', style: t.headlineSmall),
      const SizedBox(height: 4),
      const Text('湘南高校104回生の生徒が作っている非公式のページです。学校の公式サイトではありません。'),
      const SizedBox(height: 12),
      const Notice('「AI作成」の解答・解説は学校の正式解答ではありません。答えが合っているか、授業ノートや先生の解説で確かめてください。',
          icon: Icons.smart_toy_outlined),
      const SizedBox(height: 12),
      Row(children: [
        _Stat('教材', '${ms.length}件'),
        _Stat('科目', '$subjects'),
        _Stat('閲覧可能', '$ready件'),
      ]),
      const SizedBox(height: 12),
      Card(
        child: Column(children: [
          ListTile(
            leading: const Icon(Icons.menu_book),
            title: const Text('教材をさがす'),
            subtitle: const Text('試験・科目・種類で絞り込み'),
            onTap: () => go(1),
          ),
          ListTile(
            leading: const Icon(Icons.event),
            title: const Text('テスト日程'),
            subtitle: const Text('後期の日程は要確認'),
            onTap: () => go(2),
          ),
          ListTile(
            leading: const Icon(Icons.quiz),
            title: const Text('百問繚乱'),
            subtitle: const Text('演習サイトへのリンクと、自分の結果の記録'),
            onTap: () => go(3),
          ),
          ListTile(
            leading: const Icon(Icons.flag),
            title: const Text('まちがいを見つけたら'),
            onTap: () => go(4),
          ),
        ]),
      ),
    ]);
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(children: [
            Text(value, style: t.headlineSmall),
            Text(label, style: t.bodySmall),
          ]),
        ),
      ),
    );
  }
}

class FindPage extends StatefulWidget {
  const FindPage({super.key, required this.materials});
  final List<Item> materials;

  @override
  State<FindPage> createState() => _FindPageState();
}

class _FindPageState extends State<FindPage> {
  String? exam, subject, kind;

  @override
  Widget build(BuildContext context) {
    final ms = widget.materials;
    List<String> uniq(String Function(Item) f) => [...{for (final m in ms) f(m)}];
    final list = ms
        .where((m) =>
            (exam == null || m.exam == exam) &&
            (subject == null || m.subject == subject) &&
            (kind == null || m.kind == kind))
        .toList();

    Widget chips(String label, List<String> opts, String? sel, void Function(String?) set) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 40, child: Text(label)),
            ChoiceChip(label: const Text('すべて'), selected: sel == null, onSelected: (_) => set(null)),
            for (final o in opts)
              ChoiceChip(label: Text(o), selected: sel == o, onSelected: (_) => set(o)),
          ]),
        );

    return ListView(padding: const EdgeInsets.all(16), children: [
      chips('試験', uniq((m) => m.exam), exam, (v) => setState(() => exam = v)),
      chips('科目', uniq((m) => m.subject), subject, (v) => setState(() => subject = v)),
      chips('種類', uniq((m) => m.kind), kind, (v) => setState(() => kind = v)),
      Text('${list.length}件', style: Theme.of(context).textTheme.labelLarge),
      for (final m in list) MaterialCard(m),
    ]);
  }
}

class MaterialCard extends StatelessWidget {
  const MaterialCard(this.m, {super.key});
  final Item m;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    Widget tag(String s, Color bg, Color fg) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
          child: Text(s, style: TextStyle(fontSize: 12, color: fg)),
        );
    return Card(
      child: ListTile(
        title: Text('${m.exam}　${m.subject}　${m.kind}'),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(spacing: 6, runSpacing: 4, children: [
            Text('${m.unit}・${m.version}・更新 ${m.updated}'),
            if (m.isAi) tag('AI作成・学校の正式解答ではない', c.errorContainer, c.onErrorContainer),
            if (m.needsCheck) tag(m.check == '未確認' ? '内容未確認' : '要確認あり', c.secondaryContainer, c.onSecondaryContainer),
          ]),
        ),
        trailing: m.url.isEmpty
            ? const Text('準備中')
            : const Icon(Icons.open_in_new),
        onTap: m.url.isEmpty ? null : () => open(m.url),
      ),
    );
  }
}

class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key, required this.schedule});
  final List<Exam> schedule;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<Exam>>{};
    for (final e in schedule) {
      groups.putIfAbsent(e.exam, () => []).add(e);
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Notice('問題用紙に書かれた実施日から作っています。時限・範囲と後期の日程は要確認です。'),
      for (final g in groups.entries) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
          child: Text(g.key, style: Theme.of(context).textTheme.titleMedium),
        ),
        Card(
          child: Column(children: [
            for (final e in g.value)
              ListTile(
                dense: true,
                leading: Text(e.date.substring(5).replaceFirst('-', '/')),
                title: Text(e.subject),
                subtitle: Text([if (e.period.isNotEmpty) e.period, e.range].join('　')),
              ),
          ]),
        ),
      ],
    ]);
  }
}

class HyakumonPage extends StatelessWidget {
  const HyakumonPage({super.key, required this.subjects});
  final List<String> subjects;

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('百問繚乱', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('学校で使っている演習サイトです。ログインは百問繚乱のページで、自分のアカウントで行ってください。'),
      const SizedBox(height: 8),
      const Notice('このポータルは百問繚乱のIDやパスワードを預かりません。自動ログインや結果の取り込みもしません。',
          icon: Icons.lock_outline),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: () => open(hyakumonUrl),
        icon: const Icon(Icons.open_in_new),
        label: const Text('百問繚乱を開く'),
      ),
      const SizedBox(height: 24),
      ScoreLog(subjects: subjects),
    ]);
  }
}

class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('まちがいを見つけたら', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('解答・解説のまちがいや、読みにくいところを教えてください。教材ID（例：2026-1M-MATH1-EXP-01）と問題番号を書いてもらえると助かります。'),
      const SizedBox(height: 8),
      const Notice('報告に名前やクラスは書かないでください。', icon: Icons.privacy_tip_outlined),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: () => open('$repoUrl/issues/new?labels=%E8%AA%A4%E3%82%8A%E5%A0%B1%E5%91%8A&title=%5B%E8%AA%A4%E3%82%8A%E5%A0%B1%E5%91%8A%5D%20'),
        icon: const Icon(Icons.open_in_new),
        label: const Text('GitHubで報告する'),
      ),
      const SizedBox(height: 8),
      const Text('※GitHubのアカウントが必要です。アカウントがない人向けの報告フォームは準備中です。'),
    ]);
  }
}
