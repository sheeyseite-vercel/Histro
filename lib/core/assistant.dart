import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_state.dart';
import 'models.dart';
import 'wiki.dart';

/// Set at build time:
///   --dart-define=HISTO_PROXY_URL=https://your-worker.workers.dev
///   --dart-define=HISTO_APP_TOKEN=some-shared-token
const String kProxyUrl = String.fromEnvironment('HISTO_PROXY_URL');
const String kAppToken = String.fromEnvironment('HISTO_APP_TOKEN');

class SourceLink {
  final String title;
  final String url;
  const SourceLink(this.title, this.url);
}

class AssistantAnswer {
  final String text;
  final List<SourceLink> sources;
  final bool viaAi;
  final bool found;
  final String? provider;
  const AssistantAnswer({
    required this.text,
    required this.sources,
    required this.viaAi,
    required this.found,
    this.provider,
  });
}

List<String> _tokens(String s) => s
    .toLowerCase()
    .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
    .where((t) => t.length > 2)
    .toList();

class Assistant {
  /// Pick the passages most related to the question.
  static List<Passage> _rank(String q, List<Passage> all, {int take = 6}) {
    final qt = _tokens(q).toSet();
    if (qt.isEmpty) return all.take(take).toList();
    final scored = <MapEntry<Passage, int>>[];
    for (final p in all) {
      final low = '${p.section} ${p.text}'.toLowerCase();
      var score = 0;
      for (final t in qt) {
        if (low.contains(t)) score += 1 + (t.length > 5 ? 1 : 0);
      }
      if (score > 0) scored.add(MapEntry(p, score));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(take).map((e) => e.key).toList();
  }

  static Future<List<Passage>> _gather(
      AppState state, String question, Article? article) async {
    if (article != null) return article.passages();
    final all = <Passage>[];
    var hits = await Wiki.search(state.lang, question);
    var lang = state.lang;
    if (hits.isEmpty && state.lang != 'en') {
      hits = await Wiki.search('en', question);
      lang = 'en';
    }
    for (final h in hits.take(2)) {
      try {
        final a = await state.fetchArticle(lang, h.title);
        all.addAll(a.passages());
      } catch (_) {}
    }
    return all;
  }

  static Future<AssistantAnswer> ask(
    AppState state,
    String question, {
    Article? article,
  }) async {
    List<Passage> ranked;
    try {
      final all = await _gather(state, question, article);
      ranked = _rank(question, all);
    } catch (_) {
      return const AssistantAnswer(
          text: '', sources: [], viaAi: false, found: false);
    }
    if (ranked.isEmpty) {
      return const AssistantAnswer(
          text: '', sources: [], viaAi: false, found: false);
    }
    final links = <String, SourceLink>{};
    for (final p in ranked) {
      links[p.url] = SourceLink(p.title, p.url);
    }

    if (kProxyUrl.isNotEmpty) {
      try {
        final ctx = <Map<String, dynamic>>[];
        for (var i = 0; i < ranked.length; i++) {
          final p = ranked[i];
          final t = p.text.length > 1000 ? '${p.text.substring(0, 1000)}…' : p.text;
          ctx.add({
            'n': i + 1,
            'title': p.title,
            'url': p.url,
            'section': p.section,
            'text': t,
          });
        }
        final r = await http
            .post(
              Uri.parse('$kProxyUrl/chat'),
              headers: {
                'Content-Type': 'application/json',
                if (kAppToken.isNotEmpty) 'X-Histo-Key': kAppToken,
              },
              body: jsonEncode({
                'question': question,
                'lang': state.lang,
                'context': ctx,
              }),
            )
            .timeout(const Duration(seconds: 45));
        if (r.statusCode == 200) {
          final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
          final ans = (j['answer'] ?? '') as String;
          if (ans.trim().isNotEmpty) {
            return AssistantAnswer(
              text: ans.trim(),
              sources: links.values.toList(),
              viaAi: true,
              found: true,
              provider: j['provider'] as String?,
            );
          }
        }
      } catch (_) {
        // fall through to offline passages
      }
    }

    final buf = StringBuffer();
    for (final p in ranked.take(3)) {
      final t = p.text.length > 600 ? '${p.text.substring(0, 600)}…' : p.text;
      if (p.section.isNotEmpty) buf.writeln('${p.section}');
      buf.writeln(t);
      buf.writeln();
    }
    return AssistantAnswer(
      text: buf.toString().trim(),
      sources: links.values.toList(),
      viaAi: false,
      found: true,
    );
  }
}
