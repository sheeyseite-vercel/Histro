import 'package:html/dom.dart';
import 'package:html/parser.dart' as hp;

import 'models.dart';

const Set<String> _skipTitles = {
  'references', 'notes', 'footnotes', 'bibliography', 'external links',
  'further reading', 'see also', 'sources', 'citations', 'works cited',
  'primary sources', 'secondary sources', 'explanatory notes',
  'الهوامش', 'مراجع', 'المراجع', 'وصلات خارجية', 'روابط خارجية',
  'انظر أيضا', 'انظر أيضًا', 'المصادر', 'ملاحظات', 'قراءة موسعة',
  'قراءات إضافية', 'مصادر', 'وصلات خارجيه',
};

const List<String> _skipClasses = [
  'hatnote', 'navbox', 'thumb', 'metadata', 'sistersitebox', 'mw-empty-elt',
  'reflist', 'refbegin', 'floatright', 'tright', 'tleft', 'shortdescription',
  'noprint', 'mbox', 'ambox', 'sidebar', 'side-box', 'toc', 'gallery',
  'mw-references-wrap', 'navbox-styles', 'authority-control',
];

bool _hasAnyClass(Element e, List<String> names) {
  final c = e.classes;
  for (final n in names) {
    if (c.contains(n)) return true;
  }
  return false;
}

String _clean(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

void _collect(Node n, List<Inline> out) {
  if (n is Text) {
    out.add(Inline(n.data));
    return;
  }
  if (n is! Element) return;
  final tag = n.localName;
  if (tag == 'style' || tag == 'script' || tag == 'link' || tag == 'figure' ||
      tag == 'table' || tag == 'img' || tag == 'meta') {
    return;
  }
  if (_hasAnyClass(n, const ['mw-editsection', 'noprint', 'mw-empty-elt'])) return;
  if (tag == 'sup' &&
      (n.classes.contains('mw-ref') || n.classes.contains('reference'))) {
    final a = n.querySelector('a');
    final href = a?.attributes['href'] ?? '';
    final i = href.indexOf('#');
    final id = i >= 0 ? href.substring(i + 1) : '';
    var label = (n.querySelector('.mw-reflink-text')?.text ?? a?.text ?? '').trim();
    label = label.replaceAll('[', '').replaceAll(']', '');
    if (id.isNotEmpty) out.add(Inline('', refId: id, refLabel: label));
    return;
  }
  if (tag == 'br') {
    out.add(const Inline(' '));
    return;
  }
  for (final c in n.nodes) {
    _collect(c, out);
  }
}

List<Inline> _inlinesOf(Element e) {
  final raw = <Inline>[];
  _collect(e, raw);
  final merged = <Inline>[];
  final buf = StringBuffer();
  void flush() {
    if (buf.isNotEmpty) {
      merged.add(Inline(buf.toString().replaceAll(RegExp(r'\s+'), ' ')));
      buf.clear();
    }
  }

  for (final i in raw) {
    if (i.isRef) {
      flush();
      merged.add(i);
    } else {
      buf.write(i.text);
    }
  }
  flush();
  // trim edges
  if (merged.isNotEmpty && !merged.first.isRef) {
    merged[0] = Inline(merged.first.text.trimLeft());
  }
  if (merged.isNotEmpty && !merged.last.isRef) {
    merged[merged.length - 1] = Inline(merged.last.text.trimRight());
  }
  merged.removeWhere((i) => !i.isRef && i.text.isEmpty);
  return merged;
}

void _plainRec(Node n, StringBuffer b) {
  if (n is Text) {
    b.write(n.data);
    return;
  }
  if (n is! Element) return;
  final tag = n.localName;
  if (tag == 'style' || tag == 'script' || tag == 'img' || tag == 'link') return;
  if (tag == 'sup') return;
  if (tag == 'br') {
    b.write('\n');
    return;
  }
  if (tag == 'li') b.write('\n');
  for (final c in n.nodes) {
    _plainRec(c, b);
  }
}

String _plain(Element e) {
  final b = StringBuffer();
  _plainRec(e, b);
  final lines = b
      .toString()
      .split('\n')
      .map(_clean)
      .where((l) => l.isNotEmpty)
      .toList();
  var s = lines.join('\n');
  if (s.length > 700) s = '${s.substring(0, 700)}…';
  return s;
}

List<Fact> _parseInfobox(Element t) {
  final facts = <Fact>[];
  var last = '';
  for (final tr in t.querySelectorAll('tr')) {
    final th = tr.children.where((e) => e.localName == 'th').toList();
    final td = tr.children.where((e) => e.localName == 'td').toList();
    if (td.isEmpty && th.isNotEmpty) {
      final txt = _plain(th.first);
      if (txt.isNotEmpty) last = txt;
      continue;
    }
    final vals = td.map(_plain).where((s) => s.isNotEmpty).toList();
    if (vals.isEmpty) continue;
    if (th.isNotEmpty) {
      final label = _plain(th.first);
      if (label.isEmpty) continue;
      facts.add(Fact(label, vals));
    } else {
      facts.add(Fact(last, vals));
    }
    if (facts.length >= 18) break;
  }
  return facts;
}

class _SB {
  String title;
  int level;
  final List<Block> blocks = [];
  _SB(this.title, this.level);
}

class _Walk {
  final List<_SB> out = [_SB('', 1)];
  List<Fact>? infobox;

  void node(Element c) {
    final tag = c.localName ?? '';
    if (tag == 'section') {
      for (final k in c.children) {
        node(k);
      }
      return;
    }
    if (RegExp(r'^h[1-6]$').hasMatch(tag)) {
      out.add(_SB(_clean(c.text), int.parse(tag.substring(1))));
      return;
    }
    if (tag == 'div') {
      if (c.classes.contains('mw-heading')) {
        final h = c.querySelector('h1,h2,h3,h4,h5,h6');
        if (h != null) {
          out.add(_SB(_clean(h.text), int.parse(h.localName!.substring(1))));
        }
        return;
      }
      if (_hasAnyClass(c, _skipClasses)) return;
      for (final k in c.children) {
        node(k);
      }
      return;
    }
    if (tag == 'table') {
      if (infobox == null && c.classes.contains('infobox')) {
        final f = _parseInfobox(c);
        if (f.isNotEmpty) infobox = f;
      }
      return;
    }
    if (_hasAnyClass(c, _skipClasses)) return;
    if (tag == 'p') {
      final ins = _inlinesOf(c);
      final txt = ins.where((i) => !i.isRef).map((i) => i.text).join().trim();
      if (txt.isNotEmpty) out.last.blocks.add(Block('p', ins));
      return;
    }
    if (tag == 'ul' || tag == 'ol') {
      for (final li in c.children) {
        if (li.localName != 'li') continue;
        final ins = _inlinesOf(li);
        if (ins.isNotEmpty) out.last.blocks.add(Block('li', ins));
      }
      return;
    }
    if (tag == 'blockquote') {
      final ins = _inlinesOf(c);
      if (ins.isNotEmpty) out.last.blocks.add(Block('quote', ins));
      return;
    }
  }
}

Map<String, Ref> _parseRefs(Document doc) {
  final refs = <String, Ref>{};
  for (final li in doc.querySelectorAll('ol.references li, ol.mw-references li')) {
    final id = li.id;
    if (id.isEmpty) continue;
    final textEl = li.querySelector('.mw-reference-text') ?? li;
    final text = _clean(textEl.text.replaceAll('↑', ''));
    final links = <String>[];
    for (final a in textEl.querySelectorAll('a')) {
      var href = a.attributes['href'] ?? '';
      if (href.startsWith('//')) href = 'https:$href';
      if (href.startsWith('http') && !links.contains(href)) links.add(href);
    }
    refs[id] = Ref(id, text, links);
  }
  return refs;
}

Article parseArticle({
  required String lang,
  required String title,
  required String htmlSource,
  Map<String, dynamic>? summary,
}) {
  final doc = hp.parse(htmlSource);
  final body = doc.body;
  final w = _Walk();
  if (body != null) {
    for (final c in body.children) {
      w.node(c);
    }
  }
  final refs = _parseRefs(doc);

  // Drop skipped sections (and their subsections) and empty ones.
  final kept = <Sect>[];
  int? skipLevel;
  for (var i = 0; i < w.out.length; i++) {
    final s = w.out[i];
    if (i > 0) {
      if (skipLevel != null && s.level > skipLevel) continue;
      skipLevel = null;
      if (_skipTitles.contains(s.title.toLowerCase())) {
        skipLevel = s.level;
        continue;
      }
    }
    final nextDeeper = i + 1 < w.out.length && w.out[i + 1].level > s.level;
    if (s.blocks.isEmpty && !(nextDeeper && s.title.isNotEmpty)) continue;
    kept.add(Sect(s.title, s.level, s.blocks));
  }

  final coords = summary?['coordinates'] as Map?;
  final thumb = (summary?['thumbnail'] as Map?)?['source'] as String?;
  final pageUrl =
      ((summary?['content_urls'] as Map?)?['desktop'] as Map?)?['page'] as String?;

  return Article(
    title: (summary?['title'] as String?) ?? title,
    lang: lang,
    description: (summary?['description'] as String?) ?? '',
    extract: (summary?['extract'] as String?) ?? '',
    thumb: thumb,
    url: pageUrl ??
        'https://$lang.wikipedia.org/wiki/${Uri.encodeComponent(title.replaceAll(' ', '_'))}',
    lat: (coords?['lat'] as num?)?.toDouble(),
    lon: (coords?['lon'] as num?)?.toDouble(),
    year: null,
    qid: summary?['wikibase_item'] as String?,
    infobox: w.infobox ?? const [],
    sections: kept,
    refs: refs,
  );
}
