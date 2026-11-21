import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import 'assistant_view.dart';
import 'common.dart';

Future<void> openUrl(String url) async {
  final u = Uri.tryParse(url);
  if (u == null) return;
  await launchUrl(u, mode: LaunchMode.externalApplication);
}

class ArticleScreen extends StatefulWidget {
  final String title;
  final String srcLang;
  const ArticleScreen({super.key, required this.title, required this.srcLang});

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  Future<Article>? _f;
  String _lang = '';
  String _srcTitle = '';
  String _srcLang = '';
  final _isc = ItemScrollController();
  final Map<int, int> _idx = {};

  @override
  void initState() {
    super.initState();
    _srcTitle = widget.title;
    _srcLang = widget.srcLang;
  }

  Future<Article> _load(AppState state) async {
    final a = await state.openArticle(_srcTitle, _srcLang);
    state.addRecent(a);
    return a;
  }

  void _reload(AppState state) => setState(() => _f = _load(state));

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (_lang != state.lang) {
      _lang = state.lang;
      _f = _load(state);
    }
    final ui = state.lang;
    return Scaffold(
      body: FutureBuilder<Article>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return SafeArea(
              child: Column(children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: BackButton(onPressed: () => Navigator.of(context).pop()),
                ),
                Expanded(child: Loading(lang: ui)),
              ]),
            );
          }
          if (snap.hasError) {
            return SafeArea(
              child: Column(children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: BackButton(onPressed: () => Navigator.of(context).pop()),
                ),
                Expanded(child: ErrorView(lang: ui, onRetry: () => _reload(state))),
              ]),
            );
          }
          return _buildArticle(context, state, snap.data!);
        },
      ),
    );
  }

  Widget _buildArticle(BuildContext context, AppState state, Article a) {
    final ui = state.lang;
    final al = a.lang; // language of the article text
    final dir = al == 'ar' ? TextDirection.rtl : TextDirection.ltr;
    final saved = state.isSaved(a);

    // Flatten into lazily built items.
    final items = <Widget>[];
    _idx.clear();

    items.add(_header(context, state, a));
    if (a.fallbackNote != null) {
      items.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: P.chip,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(tr(ui, a.fallbackNote!), style: body(ui, 13, color: P.muted)),
        ),
      ));
    }
    items.add(_actions(context, state, a, saved));
    if (a.infobox.isNotEmpty) items.add(_infobox(a, ui));

    // Table of contents (level-2 headings).
    final heads = <int>[];
    for (var i = 0; i < a.sections.length; i++) {
      final s = a.sections[i];
      if (s.title.isNotEmpty && s.level <= 2) heads.add(i);
    }
    if (heads.length > 2) {
      items.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(tr(ui, 'contents'), lang: ui),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final i in heads)
                  Pill(a.sections[i].title, lang: al, onTap: () {
                    final at = _idx[i];
                    if (at != null && _isc.isAttached) {
                      _isc.scrollTo(
                          index: at,
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeOut);
                    }
                  }),
              ],
            ),
          ],
        ),
      ));
    }

    for (var i = 0; i < a.sections.length; i++) {
      final s = a.sections[i];
      if (s.title.isNotEmpty) {
        _idx[i] = items.length;
        items.add(Padding(
          padding: EdgeInsets.fromLTRB(20, s.level <= 2 ? 26 : 16, 20, 4),
          child: Text(s.title,
              style: display(al, s.level <= 2 ? 28 : 21)),
        ));
      }
      for (final b in s.blocks) {
        items.add(_blockWidget(context, a, b));
      }
    }

    items.add(_refsList(a, ui));
    items.add(_footer(a, ui));

    return Directionality(
      textDirection: dir,
      child: SafeArea(
        bottom: false,
        child: ScrollablePositionedList.builder(
          itemScrollController: _isc,
          padding: const EdgeInsets.only(bottom: 32),
          itemCount: items.length,
          itemBuilder: (_, i) => items[i],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, AppState state, Article a) {
    final ui = state.lang;
    final al = a.lang;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
          child: Row(
            children: [
              BackButton(onPressed: () => Navigator.of(context).pop()),
              const Spacer(),
              LangButton(lang: ui, onTap: state.toggleLang),
            ],
          ),
        ),
        if (a.thumb != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                a.thumb!,
                height: 190,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (a.year != null)
                Text(
                  formatYear(al, a.year!),
                  style: body(al, 13, color: P.red, weight: FontWeight.w600),
                ),
              Text(a.title, style: display(al, 36, height: al == 'ar' ? 1.3 : 1.05)),
              if (a.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(a.description, style: body(al, 15, color: P.muted)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _actions(BuildContext context, AppState state, Article a, bool saved) {
    final ui = state.lang;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Pill(saved ? tr(ui, 'unsave') : tr(ui, 'save'),
              lang: ui,
              dark: saved,
              icon: saved ? Icons.bookmark : Icons.bookmark_border,
              onTap: () => state.toggleSaved(a)),
          Pill(tr(ui, 'askThis'),
              lang: ui,
              icon: Icons.auto_awesome_outlined,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => Scaffold(
                        appBar: AppBar(
                            title: Text(a.title,
                                style: display(ui, 20),
                                overflow: TextOverflow.ellipsis)),
                        body: AssistantView(article: a),
                      )))),
          Pill(tr(ui, 'openOriginal'),
              lang: ui, icon: Icons.open_in_new, onTap: () => openUrl(a.url)),
        ],
      ),
    );
  }

  Widget _infobox(Article a, String ui) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        decoration: BoxDecoration(
          color: P.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: P.line),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(tr(ui, 'facts'), lang: ui, color: P.red),
            const SizedBox(height: 8),
            for (final f in a.infobox)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.label,
                        style: body(a.lang, 12, color: P.muted, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    if (f.values.length == 1)
                      Text(f.values.first, style: body(a.lang, 14.5))
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < f.values.length; i++) ...[
                            if (i > 0) const SizedBox(width: 10),
                            Expanded(
                              child: Text(f.values[i], style: body(a.lang, 14.5)),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _blockWidget(BuildContext context, Article a, Block b) {
    final al = a.lang;
    final base = body(al, al == 'ar' ? 17 : 16.5, height: al == 'ar' ? 1.9 : 1.55);
    final spans = <InlineSpan>[];
    for (final i in b.inlines) {
      if (i.isRef) {
        final r = a.refs[i.refId];
        final label = (i.refLabel ?? '').isEmpty ? '•' : i.refLabel!;
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.top,
          child: GestureDetector(
            onTap: r == null ? null : () => _showRef(context, a, r, label),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Text(label,
                  style: body('en', 10.5, color: P.red, weight: FontWeight.w700)),
            ),
          ),
        ));
      } else {
        spans.add(TextSpan(text: i.text));
      }
    }
    final text = Text.rich(TextSpan(style: base, children: spans));
    if (b.type == 'li') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, right: 10, left: 10),
              child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(color: P.red, shape: BoxShape.circle),
              ),
            ),
            Expanded(child: text),
          ],
        ),
      );
    }
    if (b.type == 'quote') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 8),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontStyle: FontStyle.italic),
          child: text,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: text,
    );
  }

  void _showRef(BuildContext context, Article a, Ref r, String label) {
    final ui = AppScope.of(context).lang;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: P.card,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .6),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Directionality(
              textDirection: a.lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow('${tr(ui, 'refTitle')} $label', lang: ui, color: P.red),
                  const SizedBox(height: 8),
                  Text(r.text, style: body(a.lang, 15.5)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final l in r.links.take(3))
                        Pill(Uri.tryParse(l)?.host ?? tr(ui, 'openLink'),
                            lang: ui,
                            icon: Icons.open_in_new,
                            onTap: () => openUrl(l)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _refsList(Article a, String ui) {
    if (a.refs.isEmpty) return const SizedBox.shrink();
    final list = a.refs.values.toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('${tr(ui, 'references')} (${list.length})',
              style: display(ui, 24)),
          children: [
            for (var i = 0; i < list.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: list[i].links.isEmpty ? null : () => openUrl(list[i].links.first),
                  child: Text(
                    '${i + 1}. ${list[i].text}',
                    style: body(a.lang, 13.5,
                        color: list[i].links.isEmpty ? P.muted : P.ink),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _footer(Article a, String ui) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Text(tr(ui, 'attribution'), style: body(ui, 12, color: P.muted)),
      );
}
