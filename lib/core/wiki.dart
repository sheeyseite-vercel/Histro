import 'dart:convert';

import 'package:html/parser.dart' as hp;
import 'package:http/http.dart' as http;

import 'models.dart';

const Map<String, String> _headers = {
  'User-Agent': 'HISTO/1.0 (history reference app; open-source)',
  'Accept': 'application/json',
};

Future<dynamic> _getJson(Uri u, {int seconds = 25}) async {
  final r = await http.get(u, headers: _headers).timeout(Duration(seconds: seconds));
  if (r.statusCode != 200) {
    throw Exception('HTTP ${r.statusCode}');
  }
  return jsonDecode(utf8.decode(r.bodyBytes));
}

String _stripTags(String s) => hp.parseFragment(s).text ?? '';

/// Thin client over the public Wikipedia / Wikidata / Wikimedia APIs.
class Wiki {
  static Future<List<SearchHit>> search(String lang, String q) async {
    final u = Uri.https('$lang.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'list': 'search',
      'srsearch': q,
      'srlimit': '20',
      'format': 'json',
      'formatversion': '2',
      'utf8': '1',
    });
    final j = await _getJson(u);
    final list = (j['query']?['search'] as List?) ?? const [];
    return list
        .map((e) => SearchHit(
              e['title'] as String,
              _stripTags((e['snippet'] ?? '') as String),
              lang,
            ))
        .toList();
  }

  static Future<Map<String, dynamic>?> summary(String lang, String title) async {
    try {
      final u = Uri.parse(
          'https://$lang.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(title.replaceAll(' ', '_'))}');
      final j = await _getJson(u);
      return Map<String, dynamic>.from(j as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<String> html(String lang, String title) async {
    final u = Uri.parse(
        'https://$lang.wikipedia.org/api/rest_v1/page/html/${Uri.encodeComponent(title.replaceAll(' ', '_'))}');
    final r = await http
        .get(u, headers: {..._headers, 'Accept': 'text/html'})
        .timeout(const Duration(seconds: 40));
    if (r.statusCode != 200) {
      throw Exception('HTTP ${r.statusCode}');
    }
    return utf8.decode(r.bodyBytes);
  }

  /// Title of the same article in another language, or null.
  static Future<String?> langTitle(String from, String title, String to) async {
    try {
      final u = Uri.https('$from.wikipedia.org', '/w/api.php', {
        'action': 'query',
        'prop': 'langlinks',
        'titles': title,
        'lllang': to,
        'redirects': '1',
        'format': 'json',
        'formatversion': '2',
      });
      final j = await _getJson(u);
      final pages = (j['query']?['pages'] as List?) ?? const [];
      if (pages.isEmpty) return null;
      final ll = pages.first['langlinks'] as List?;
      if (ll == null || ll.isEmpty) return null;
      return ll.first['title'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Best-effort year of an event/person from Wikidata.
  static Future<int?> wikidataYear(String qid) async {
    for (final prop in const ['P585', 'P580', 'P571', 'P569']) {
      try {
        final u = Uri.https('www.wikidata.org', '/w/api.php', {
          'action': 'wbgetclaims',
          'entity': qid,
          'property': prop,
          'format': 'json',
        });
        final j = await _getJson(u, seconds: 10);
        final claims = (j['claims']?[prop] as List?) ?? const [];
        for (final c in claims) {
          final t = c['mainsnak']?['datavalue']?['value']?['time'] as String?;
          if (t == null) continue;
          final m = RegExp(r'^([+-])0*(\d+)-').firstMatch(t);
          if (m == null) continue;
          final y = int.parse(m.group(2)!);
          return m.group(1) == '-' ? -y : y;
        }
      } catch (_) {
        // try next property
      }
    }
    return null;
  }

  /// Events that happened on today's date, from the Wikimedia feed.
  static Future<List<Map<String, dynamic>>> onThisDay(String lang) async {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final u = Uri.parse(
        'https://api.wikimedia.org/feed/v1/wikipedia/$lang/onthisday/events/$mm/$dd');
    final j = await _getJson(u, seconds: 15);
    final events = (j['events'] as List?) ?? const [];
    return events
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((e) => (e['pages'] as List?)?.isNotEmpty ?? false)
        .toList();
  }
}
