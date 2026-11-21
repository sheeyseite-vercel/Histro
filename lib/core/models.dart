/// Data models for articles fetched live from open references.

class Inline {
  final String text;
  final String? refId;
  final String? refLabel;
  const Inline(this.text, {this.refId, this.refLabel});

  bool get isRef => refId != null;

  Map<String, dynamic> toJson() => {
        't': text,
        if (refId != null) 'r': refId,
        if (refLabel != null) 'l': refLabel,
      };

  factory Inline.fromJson(Map<String, dynamic> j) => Inline(
        (j['t'] ?? '') as String,
        refId: j['r'] as String?,
        refLabel: j['l'] as String?,
      );
}

class Block {
  final String type; // p | li | quote
  final List<Inline> inlines;
  const Block(this.type, this.inlines);

  String get plain => inlines.where((i) => !i.isRef).map((i) => i.text).join();

  Map<String, dynamic> toJson() =>
      {'ty': type, 'in': inlines.map((i) => i.toJson()).toList()};

  factory Block.fromJson(Map<String, dynamic> j) => Block(
        j['ty'] as String,
        (j['in'] as List)
            .map((e) => Inline.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class Sect {
  final String title;
  final int level;
  final List<Block> blocks;
  const Sect(this.title, this.level, this.blocks);

  Map<String, dynamic> toJson() => {
        'ti': title,
        'lv': level,
        'bl': blocks.map((b) => b.toJson()).toList(),
      };

  factory Sect.fromJson(Map<String, dynamic> j) => Sect(
        j['ti'] as String,
        j['lv'] as int,
        (j['bl'] as List)
            .map((e) => Block.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class Ref {
  final String id;
  final String text;
  final List<String> links;
  const Ref(this.id, this.text, this.links);

  Map<String, dynamic> toJson() => {'id': id, 'tx': text, 'ln': links};

  factory Ref.fromJson(Map<String, dynamic> j) => Ref(
        j['id'] as String,
        j['tx'] as String,
        (j['ln'] as List).map((e) => e.toString()).toList(),
      );
}

class Fact {
  final String label;
  final List<String> values;
  const Fact(this.label, this.values);

  Map<String, dynamic> toJson() => {'lb': label, 'vs': values};

  factory Fact.fromJson(Map<String, dynamic> j) => Fact(
        j['lb'] as String,
        (j['vs'] as List).map((e) => e.toString()).toList(),
      );
}

class Article {
  final String title;
  final String lang;
  final String description;
  final String extract;
  final String? thumb;
  final String url;
  final double? lat;
  final double? lon;
  final int? year;
  final String? qid;
  final List<Fact> infobox;
  final List<Sect> sections;
  final Map<String, Ref> refs;

  /// Set at runtime when the article is shown in a different language than requested.
  String? fallbackNote;

  Article({
    required this.title,
    required this.lang,
    required this.description,
    required this.extract,
    required this.thumb,
    required this.url,
    required this.lat,
    required this.lon,
    required this.year,
    required this.qid,
    required this.infobox,
    required this.sections,
    required this.refs,
  });

  Article copyWith({int? year}) => Article(
        title: title,
        lang: lang,
        description: description,
        extract: extract,
        thumb: thumb,
        url: url,
        lat: lat,
        lon: lon,
        year: year ?? this.year,
        qid: qid,
        infobox: infobox,
        sections: sections,
        refs: refs,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'lang': lang,
        'desc': description,
        'extract': extract,
        'thumb': thumb,
        'url': url,
        'lat': lat,
        'lon': lon,
        'year': year,
        'qid': qid,
        'info': infobox.map((f) => f.toJson()).toList(),
        'sec': sections.map((s) => s.toJson()).toList(),
        'refs': refs.values.map((r) => r.toJson()).toList(),
      };

  factory Article.fromJson(Map<String, dynamic> j) {
    final refList = (j['refs'] as List)
        .map((e) => Ref.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return Article(
      title: j['title'] as String,
      lang: j['lang'] as String,
      description: (j['desc'] ?? '') as String,
      extract: (j['extract'] ?? '') as String,
      thumb: j['thumb'] as String?,
      url: (j['url'] ?? '') as String,
      lat: (j['lat'] as num?)?.toDouble(),
      lon: (j['lon'] as num?)?.toDouble(),
      year: j['year'] as int?,
      qid: j['qid'] as String?,
      infobox: (j['info'] as List)
          .map((e) => Fact.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      sections: (j['sec'] as List)
          .map((e) => Sect.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      refs: {for (final r in refList) r.id: r},
    );
  }

  /// Plain-text passages used to ground the assistant.
  List<Passage> passages() {
    final out = <Passage>[];
    for (final s in sections) {
      for (final b in s.blocks) {
        final t = b.plain.trim();
        if (t.length < 40) continue;
        out.add(Passage(title: title, url: url, section: s.title, text: t));
      }
    }
    return out;
  }
}

class Passage {
  final String title;
  final String url;
  final String section;
  final String text;
  const Passage({
    required this.title,
    required this.url,
    required this.section,
    required this.text,
  });
}

class SearchHit {
  final String title;
  final String snippet;
  final String lang;
  const SearchHit(this.title, this.snippet, this.lang);
}

/// Light-weight record of an article the reader opened or saved.
class SavedItem {
  final String title;
  final String lang;
  final String description;
  final String? thumb;
  final double? lat;
  final double? lon;
  final int? year;
  const SavedItem({
    required this.title,
    required this.lang,
    required this.description,
    this.thumb,
    this.lat,
    this.lon,
    this.year,
  });

  String get key => '$lang|$title';

  factory SavedItem.fromArticle(Article a) => SavedItem(
        title: a.title,
        lang: a.lang,
        description: a.description,
        thumb: a.thumb,
        lat: a.lat,
        lon: a.lon,
        year: a.year,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'lang': lang,
        'desc': description,
        'thumb': thumb,
        'lat': lat,
        'lon': lon,
        'year': year,
      };

  factory SavedItem.fromJson(Map<String, dynamic> j) => SavedItem(
        title: j['title'] as String,
        lang: j['lang'] as String,
        description: (j['desc'] ?? '') as String,
        thumb: j['thumb'] as String?,
        lat: (j['lat'] as num?)?.toDouble(),
        lon: (j['lon'] as num?)?.toDouble(),
        year: j['year'] as int?,
      );
}
