import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../core/wiki.dart';
import 'article_screen.dart';
import 'common.dart';

class SearchScreen extends StatefulWidget {
  final String query;
  const SearchScreen({super.key, required this.query});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  Future<List<SearchHit>>? _f;
  String _lang = '';

  Future<List<SearchHit>> _run(String lang) async {
    var r = await Wiki.search(lang, widget.query);
    if (r.isEmpty && lang != 'en') {
      r = await Wiki.search('en', widget.query);
    }
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    if (_lang != lang) {
      _lang = lang;
      _f = _run(lang);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.query, style: display(lang, 22), overflow: TextOverflow.ellipsis),
      ),
      body: FutureBuilder<List<SearchHit>>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Loading(lang: lang);
          }
          if (snap.hasError) {
            return ErrorView(
                lang: lang, onRetry: () => setState(() => _f = _run(lang)));
          }
          final hits = snap.data ?? const [];
          if (hits.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(tr(lang, 'noResults'),
                    textAlign: TextAlign.center,
                    style: body(lang, 15, color: P.muted)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
            itemCount: hits.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: P.line),
            itemBuilder: (context, i) {
              final h = hits[i];
              return InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ArticleScreen(title: h.title, srcLang: h.lang))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h.title, style: display(h.lang, 22)),
                      const SizedBox(height: 4),
                      Text(h.snippet,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: body(h.lang, 14, color: P.muted)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
