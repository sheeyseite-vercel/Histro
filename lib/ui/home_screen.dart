import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../core/wiki.dart';
import 'article_screen.dart';
import 'common.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _q = TextEditingController();
  Future<List<Map<String, dynamic>>>? _today;
  String _todayLang = '';

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadToday(String lang) async {
    try {
      final r = await Wiki.onThisDay(lang);
      if (r.isNotEmpty) return r;
    } catch (_) {}
    return Wiki.onThisDay('en');
  }

  void _search(String v) {
    final q = v.trim();
    if (q.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => SearchScreen(query: q)));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    if (_todayLang != lang) {
      _todayLang = lang;
      _today = _loadToday(lang);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow('HISTO', lang: lang),
                  Text(tr(lang, 'discover'), style: display(lang, 34, weight: FontWeight.w600)),
                ],
              ),
            ),
            LangButton(lang: lang, onTap: state.toggleLang),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: P.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: P.tan),
          ),
          padding: const EdgeInsetsDirectional.only(start: 16, end: 6),
          child: Row(
            children: [
              const Icon(Icons.search, color: P.muted, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _q,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _search,
                  style: body(lang, 15),
                  decoration: InputDecoration(
                    hintText: tr(lang, 'searchHint'),
                    hintStyle: body(lang, 15, color: P.muted),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Search',
                onPressed: () => _search(_q.text),
                icon: const Icon(Icons.arrow_forward, color: P.red),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _TodayCard(future: _today!, lang: lang),
        const SizedBox(height: 22),
        Eyebrow(tr(lang, 'startExploring'), lang: lang),
        const SizedBox(height: 10),
        for (final s in kSeeds)
          _SeedTile(
            label: lang == 'ar' ? s[1] : s[0],
            lang: lang,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ArticleScreen(title: s[2], srcLang: 'en'))),
          ),
      ],
    );
  }
}

class _SeedTile extends StatelessWidget {
  final String label;
  final String lang;
  final VoidCallback onTap;
  const _SeedTile({required this.label, required this.lang, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: P.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: P.line),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.close, size: 18, color: P.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(label,
                        style: display(lang, lang == 'ar' ? 21 : 20)),
                  ),
                  Icon(
                    lang == 'ar' ? Icons.chevron_left : Icons.chevron_right,
                    color: P.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _TodayCard extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> future;
  final String lang;
  const _TodayCard({required this.future, required this.lang});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        Widget inner;
        VoidCallback? onTap;
        if (snap.connectionState != ConnectionState.done) {
          inner = const SizedBox(
            height: 110,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: P.sand),
              ),
            ),
          );
        } else if (snap.hasError || (snap.data?.isEmpty ?? true)) {
          inner = const SizedBox(height: 4);
        } else {
          final events = snap.data!;
          final old = events.where((e) => ((e['year'] as num?) ?? 9999) < 1700).toList();
          final pool = old.isNotEmpty ? old : events;
          final e = pool[DateTime.now().day % pool.length];
          final pages = e['pages'] as List;
          final page = Map<String, dynamic>.from(pages.first as Map);
          final title = (page['title'] ?? '') as String;
          final pageLang = (page['content_urls']?['desktop']?['page'] as String?)
                  ?.contains('//ar.') ==
              true
              ? 'ar'
              : 'en';
          onTap = () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ArticleScreen(title: title, srcLang: pageLang)));
          inner = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${e['year']}', style: display('en', 34, color: P.paper)),
              const SizedBox(height: 4),
              Text(
                (e['text'] ?? '') as String,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: body(pageLang, 15, color: P.paper),
              ),
            ],
          );
        }
        return Material(
          color: P.ink,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow(tr(lang, 'todayInHistory'),
                      lang: lang, color: const Color(0xFFE3D5B8)),
                  const SizedBox(height: 10),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Align(alignment: AlignmentDirectional.centerStart, child: inner),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
