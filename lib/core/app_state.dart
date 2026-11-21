import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'parser.dart';
import 'wiki.dart';

class AppState extends ChangeNotifier {
  String lang = 'en';
  List<SavedItem> saved = [];
  List<SavedItem> recent = [];
  SharedPreferences? _p;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    lang = _p!.getString('lang') ?? 'en';
    saved = _readList('saved');
    recent = _readList('recent');
    notifyListeners();
  }

  List<SavedItem> _readList(String key) {
    try {
      final raw = _p?.getString(key);
      if (raw == null) return [];
      return (jsonDecode(raw) as List)
          .map((e) => SavedItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _writeList(String key, List<SavedItem> v) {
    _p?.setString(key, jsonEncode(v.map((e) => e.toJson()).toList()));
  }

  void setLang(String l) {
    if (l == lang) return;
    lang = l;
    _p?.setString('lang', l);
    notifyListeners();
  }

  void toggleLang() => setLang(lang == 'en' ? 'ar' : 'en');

  bool isSaved(Article a) => saved.any((s) => s.key == SavedItem.fromArticle(a).key);

  void toggleSaved(Article a) {
    final item = SavedItem.fromArticle(a);
    if (saved.any((s) => s.key == item.key)) {
      saved = saved.where((s) => s.key != item.key).toList();
    } else {
      saved = [item, ...saved];
      _p?.setString('a:${item.key}', jsonEncode(a.toJson()));
    }
    _writeList('saved', saved);
    notifyListeners();
  }

  void addRecent(Article a) {
    final item = SavedItem.fromArticle(a);
    recent = [item, ...recent.where((s) => s.key != item.key)].take(60).toList();
    _writeList('recent', recent);
    notifyListeners();
  }

  /// All articles the reader has touched that have a place on the map.
  List<SavedItem> get pins {
    final map = <String, SavedItem>{};
    for (final s in [...recent, ...saved]) {
      if (s.lat != null && s.lon != null) map[s.key] = s;
    }
    return map.values.toList();
  }

  bool isSavedKey(String key) => saved.any((s) => s.key == key);

  Article? _cached(String lang, String title) {
    try {
      final raw = _p?.getString('a:$lang|$title');
      if (raw == null) return null;
      return Article.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  /// Fetches an article live; falls back to a saved copy when offline.
  Future<Article> fetchArticle(String lang, String title) async {
    try {
      final fs = Wiki.summary(lang, title);
      final fh = Wiki.html(lang, title);
      final s = await fs;
      final h = await fh;
      var a = parseArticle(lang: lang, title: title, htmlSource: h, summary: s);
      final qid = a.qid;
      if (qid != null) {
        final y = await Wiki.wikidataYear(qid);
        if (y != null) a = a.copyWith(year: y);
      }
      if (isSavedKey('$lang|${a.title}')) {
        _p?.setString('a:$lang|${a.title}', jsonEncode(a.toJson()));
      }
      return a;
    } catch (e) {
      final c = _cached(lang, title);
      if (c != null) return c;
      rethrow;
    }
  }

  /// Loads an article in the reader's language, falling back to the source language.
  Future<Article> openArticle(String title, String srcLang) async {
    if (srcLang == lang) {
      return fetchArticle(lang, title);
    }
    final t2 = await Wiki.langTitle(srcLang, title, lang);
    if (t2 != null) {
      return fetchArticle(lang, t2);
    }
    final a = await fetchArticle(srcLang, title);
    a.fallbackNote = lang == 'ar' ? 'fallbackAr' : 'fallbackEn';
    return a;
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
