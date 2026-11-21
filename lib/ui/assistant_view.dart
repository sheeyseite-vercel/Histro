import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/assistant.dart';
import '../core/models.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import 'article_screen.dart';
import 'common.dart';

class _Msg {
  final bool user;
  final String text;
  final AssistantAnswer? answer;
  const _Msg(this.user, this.text, {this.answer});
}

class AssistantView extends StatefulWidget {
  final Article? article;
  const AssistantView({super.key, this.article});

  @override
  State<AssistantView> createState() => _AssistantViewState();
}

class _AssistantViewState extends State<AssistantView> {
  final _msgs = <_Msg>[];
  final _c = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String q) async {
    final text = q.trim();
    if (text.isEmpty || _busy) return;
    final state = AppScope.of(context);
    setState(() {
      _msgs.add(_Msg(true, text));
      _busy = true;
      _c.clear();
    });
    _toEnd();
    AssistantAnswer ans;
    try {
      ans = await Assistant.ask(state, text, article: widget.article);
    } catch (_) {
      ans = const AssistantAnswer(text: '', sources: [], viaAi: false, found: false);
    }
    if (!mounted) return;
    setState(() {
      _msgs.add(_Msg(false, ans.text, answer: ans));
      _busy = false;
    });
    _toEnd();
  }

  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 200,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final embedded = widget.article != null;
    return Column(
      children: [
        if (!embedded)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(lang, 'ask'),
                          style: display(lang, 30, weight: FontWeight.w700)),
                      Text(tr(lang, 'assistantNote'),
                          style: body(lang, 12.5, color: P.muted)),
                    ],
                  ),
                ),
                LangButton(lang: lang, onTap: state.toggleLang),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(tr(lang, 'assistantNote'),
                  style: body(lang, 12.5, color: P.muted)),
            ),
          ),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            children: [
              if (_msgs.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final k in const ['suggest1', 'suggest2', 'suggest3'])
                        Pill(tr(lang, k), lang: lang, onTap: () => _send(tr(lang, k))),
                    ],
                  ),
                ),
              for (final m in _msgs) _bubble(m, lang),
              if (_busy)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: P.red),
                      ),
                      const SizedBox(width: 10),
                      Text(tr(lang, 'thinking'), style: body(lang, 13.5, color: P.muted)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Container(
            decoration: BoxDecoration(
              color: P.card,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: P.tan),
            ),
            padding: const EdgeInsetsDirectional.only(start: 16, end: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _c,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _send,
                    style: body(lang, 15),
                    decoration: InputDecoration(
                      hintText: tr(lang, 'assistantHint'),
                      hintStyle: body(lang, 15, color: P.muted),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: P.red,
                    minimumSize: const Size(44, 44),
                  ),
                  tooltip: 'Send',
                  onPressed: _busy ? null : () => _send(_c.text),
                  icon: Icon(lang == 'ar' ? Icons.arrow_back : Icons.arrow_forward,
                      color: P.paper, size: 20),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _bubble(_Msg m, String lang) {
    if (m.user) {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Container(
          margin: const EdgeInsetsDirectional.only(start: 48, top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: P.ink,
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: Text(m.text, style: body(lang, 15, color: P.paper)),
        ),
      );
    }
    final a = m.answer!;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsetsDirectional.only(end: 24, top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: P.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: P.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!a.found)
              Text(tr(lang, 'nothingFound'), style: body(lang, 15))
            else ...[
              Eyebrow(a.viaAi ? tr(lang, 'aiAnswer') : tr(lang, 'offlineAnswer'),
                  lang: lang, color: a.viaAi ? P.red : P.muted),
              const SizedBox(height: 8),
              Text(a.text, style: body(lang, 15.5)),
              if (a.sources.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in a.sources.take(3))
                      Pill(s.title,
                          lang: lang,
                          icon: Icons.open_in_new,
                          onTap: () => openUrl(s.url)),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
