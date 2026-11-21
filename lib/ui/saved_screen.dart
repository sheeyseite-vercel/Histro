import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import 'article_screen.dart';
import 'common.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(tr(lang, 'saved'),
                  style: display(lang, 34, weight: FontWeight.w600)),
            ),
            LangButton(lang: lang, onTap: state.toggleLang),
          ],
        ),
        const SizedBox(height: 12),
        if (state.saved.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(tr(lang, 'savedEmpty'),
                style: body(lang, 15, color: P.muted)),
          )
        else
          for (final s in state.saved) _Row(item: s, lang: lang),
        const SizedBox(height: 18),
        if (state.recent.isNotEmpty) ...[
          Eyebrow(tr(lang, 'recent'), lang: lang),
          const SizedBox(height: 8),
          for (final s in state.recent.take(15)) _Row(item: s, lang: lang),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final SavedItem item;
  final String lang;
  const _Row({required this.item, required this.lang});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ArticleScreen(title: item.title, srcLang: item.lang))),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              ThumbImage(item.thumb),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: display(item.lang, 20)),
                    if (item.description.isNotEmpty)
                      Text(item.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: body(item.lang, 13, color: P.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
