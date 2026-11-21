import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import 'article_screen.dart';
import 'common.dart';

const _sepia = ColorFilter.matrix(<double>[
  0.393, 0.769, 0.189, 0, 0,
  0.349, 0.686, 0.168, 0, 0,
  0.272, 0.534, 0.131, 0, 0,
  0, 0, 0, 1, 0,
]);

class AtlasScreen extends StatefulWidget {
  const AtlasScreen({super.key});

  @override
  State<AtlasScreen> createState() => _AtlasScreenState();
}

class _AtlasScreenState extends State<AtlasScreen> {
  double? _year;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final pins = state.pins;
    final years = pins.where((p) => p.year != null).map((p) => p.year!).toList()..sort();
    final minY = (years.isNotEmpty ? years.first : 0) - 25;
    final maxY = (years.isNotEmpty ? years.last : 2025) + 25;
    final double y =
        (_year ?? maxY.toDouble()).clamp(minY.toDouble(), maxY.toDouble()).toDouble();
    final shown = pins.where((p) => p.year == null || p.year! <= y).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(tr(lang, 'mapTitle'),
                    style: display(lang, 34, weight: FontWeight.w600)),
              ),
              LangButton(lang: lang, onTap: state.toggleLang),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                options: const MapOptions(
                  initialCenter: LatLng(36, 12),
                  initialZoom: 3.2,
                  minZoom: 2,
                  maxZoom: 9,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.histo.histo',
                    tileBuilder: (context, tileWidget, tile) =>
                        ColorFiltered(colorFilter: _sepia, child: tileWidget),
                  ),
                  MarkerLayer(
                    markers: [
                      for (final p in shown)
                        Marker(
                          point: LatLng(p.lat!, p.lon!),
                          width: 44,
                          height: 44,
                          child: _Pin(
                            item: p,
                            saved: state.isSavedKey(p.key),
                            onTap: () => _open(context, p),
                          ),
                        ),
                    ],
                  ),
                  const RichAttributionWidget(
                    attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
                  ),
                ],
              ),
              if (pins.isEmpty)
                Positioned(
                  left: 24,
                  right: 24,
                  top: 24,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: P.card.withOpacity(.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: P.line),
                    ),
                    child: Text(tr(lang, 'noPins'),
                        textAlign: TextAlign.center,
                        style: body(lang, 14.5, color: P.muted)),
                  ),
                ),
            ],
          ),
        ),
        if (years.length > 1)
          Container(
            color: P.card,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Eyebrow(tr(lang, 'showingUpTo'), lang: lang),
                    const Spacer(),
                    Text(formatYear(lang, y.round()),
                        style: body(lang, 14, color: P.red, weight: FontWeight.w700)),
                  ],
                ),
                Slider(
                  value: y,
                  min: minY.toDouble(),
                  max: maxY.toDouble(),
                  activeColor: P.red,
                  inactiveColor: P.tan,
                  onChanged: (v) => setState(() => _year = v),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _open(BuildContext context, SavedItem p) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ArticleScreen(title: p.title, srcLang: p.lang)));
  }
}

class _Pin extends StatelessWidget {
  final SavedItem item;
  final bool saved;
  final VoidCallback onTap;
  const _Pin({required this.item, required this.saved, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Tooltip(
          message: item.title,
          child: Center(
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: saved ? P.red : P.ink,
                shape: BoxShape.circle,
                border: Border.all(color: P.paper, width: 3),
                boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6)],
              ),
            ),
          ),
        ),
      );
}
