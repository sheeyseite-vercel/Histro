import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/theme.dart';

class Pill extends StatelessWidget {
  final String label;
  final bool dark;
  final IconData? icon;
  final VoidCallback? onTap;
  final String lang;
  const Pill(this.label,
      {super.key, required this.lang, this.dark = false, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = dark ? P.paper : P.ink;
    return Material(
      color: dark ? P.ink : P.chip,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(label,
                      style: body(lang, 13, color: fg, weight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Eyebrow extends StatelessWidget {
  final String text;
  final String lang;
  final Color color;
  const Eyebrow(this.text, {super.key, required this.lang, this.color = P.muted});

  @override
  Widget build(BuildContext context) => Text(
        lang == 'ar' ? text : text.toUpperCase(),
        style: body(lang, 12, color: color, weight: FontWeight.w600)
            .copyWith(letterSpacing: lang == 'ar' ? 0 : 1.6),
      );
}

class LangButton extends StatelessWidget {
  final String lang;
  final VoidCallback onTap;
  const LangButton({super.key, required this.lang, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Switch language',
        child: Material(
          color: P.paper,
          shape: StadiumBorder(side: BorderSide(color: P.tan)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 64),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(tr(lang, 'switchLang'),
                      style: body(lang == 'ar' ? 'en' : 'ar', 13,
                          weight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ),
      );
}

class Loading extends StatelessWidget {
  final String lang;
  const Loading({super.key, required this.lang});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3, color: P.red),
            ),
            const SizedBox(height: 14),
            Text(tr(lang, 'thinking'), style: body(lang, 14, color: P.muted)),
          ],
        ),
      );
}

class ErrorView extends StatelessWidget {
  final String lang;
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.lang, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 40, color: P.muted),
              const SizedBox(height: 12),
              Text(tr(lang, 'error'),
                  textAlign: TextAlign.center,
                  style: body(lang, 15, color: P.muted)),
              const SizedBox(height: 16),
              Pill(tr(lang, 'retry'), lang: lang, dark: true, onTap: onRetry),
            ],
          ),
        ),
      );
}

class Thumb extends StatelessWidget {
  final String? url;
  final double size;
  const Thumb(this.url, {super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final box = BoxDecoration(
      color: P.sand,
      borderRadius: BorderRadius.circular(10),
    );
    if (url == null) {
      return Container(
        width: size,
        height: size,
        decoration: box,
        child: const Icon(Icons.public, color: P.muted),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: box,
          child: const Icon(Icons.public, color: P.muted),
        ),
      ),
    );
  }
}
