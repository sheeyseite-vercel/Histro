import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import 'assistant_view.dart';
import 'atlas_screen.dart';
import 'home_screen.dart';
import 'saved_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    final items = [
      (Icons.explore_outlined, Icons.explore, tr(lang, 'discover')),
      (Icons.map_outlined, Icons.map, tr(lang, 'atlas')),
      (Icons.bookmark_border, Icons.bookmark, tr(lang, 'saved')),
      (Icons.auto_awesome_outlined, Icons.auto_awesome, tr(lang, 'ask')),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _i,
          children: const [
            HomeScreen(),
            AtlasScreen(),
            SavedScreen(),
            AssistantView(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: P.card,
          border: Border(top: BorderSide(color: P.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                for (var k = 0; k < items.length; k++)
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _i = k),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_i == k ? items[k].$2 : items[k].$1,
                              color: _i == k ? P.red : P.muted),
                          const SizedBox(height: 3),
                          Text(items[k].$3,
                              style: body(lang, 11,
                                  color: _i == k ? P.red : P.muted,
                                  weight: FontWeight.w600,
                                  height: 1.2)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
