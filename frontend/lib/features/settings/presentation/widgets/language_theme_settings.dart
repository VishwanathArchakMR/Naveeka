// lib/features/settings/presentation/widgets/language_theme_settings.dart

import 'package:flutter/material.dart';

/// A compact settings card for theme mode and language selection.
/// - Theme selection uses SegmentedButton for System/Light/Dark.
/// - Language selection opens a rounded bottom sheet with search + locales.
/// - Uses Color.withValues (no withOpacity) and const where possible.
class LanguageThemeSettings extends StatelessWidget {
  const LanguageThemeSettings({
    super.key,
    required this.currentThemeMode,
    required this.onThemeModeChanged,
    required this.supportedLocales,
    required this.currentLocale,
    required this.onLocaleChanged,
    this.sectionTitle = 'Appearance & language',
    this.localeDisplayName, // Optional: String Function(Locale) to display names
  });

  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  final List<Locale> supportedLocales;
  final Locale currentLocale;
  final ValueChanged<Locale> onLocaleChanged;

  final String sectionTitle;
  final String Function(Locale locale)? localeDisplayName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sectionTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),

            // Theme mode selector
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 1.0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Theme', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.phone_iphone)),
                      ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
                    ],
                    selected: {currentThemeMode},
                    onSelectionChanged: (s) => onThemeModeChanged(s.first),
                  ),
                  const SizedBox(height: 10),
                  _ThemePreview(mode: currentThemeMode),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Language selector
            Container(
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 1.0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.language, color: cs.primary),
                ),
                title: const Text('Language', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(_displayName(currentLocale), maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openLanguageSheet(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _displayName(Locale locale) {
    if (localeDisplayName != null) return localeDisplayName!(locale);
    final lang = locale.languageCode.toUpperCase();
    final country = (locale.countryCode ?? '').toUpperCase();
    return country.isEmpty ? lang : '$lang – $country';
  }

  void _openLanguageSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _LanguagePickerSheet(
        current: currentLocale,
        supported: supportedLocales,
        onPicked: (loc) {
          Navigator.maybePop(context);
          onLocaleChanged(loc);
        },
        localeDisplayName: localeDisplayName,
      ),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.mode});
  final ThemeMode mode;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final desc = switch (mode) {
      ThemeMode.system => 'Follows device setting',
      ThemeMode.light => 'Always light theme',
      ThemeMode.dark => 'Always dark theme',
    };
    return Row(
      children: [
        Expanded(
          child: Text(desc, style: TextStyle(color: cs.onSurfaceVariant)),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_iconFor(mode), size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(_labelFor(mode), style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }

  String _labelFor(ThemeMode m) {
    return switch (m) {
      ThemeMode.system => 'System',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
  }

  IconData _iconFor(ThemeMode m) {
    return switch (m) {
      ThemeMode.system => Icons.settings_suggest,
      ThemeMode.light => Icons.wb_sunny_outlined,
      ThemeMode.dark => Icons.nightlight_round,
    };
  }
}

class _LanguagePickerSheet extends StatefulWidget {
  const _LanguagePickerSheet({
    required this.current,
    required this.supported,
    required this.onPicked,
    this.localeDisplayName,
  });

  final Locale current;
  final List<Locale> supported;
  final ValueChanged<Locale> onPicked;
  final String Function(Locale locale)? localeDisplayName;

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _filter(widget.supported, _q.text);

    return Material(
      color: cs.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                const Expanded(child: Text('Choose language', style: TextStyle(fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 6),

            // Search
            TextField(
              controller: _q,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search languages',
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: cs.surface.withValues(alpha: 1.0),
              ),
            ),
            const SizedBox(height: 8),

            // List of locales
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (context, i) {
                  final loc = filtered[i];
                  final isCurrent = _sameLocale(loc, widget.current);
                  final name = widget.localeDisplayName?.call(loc) ?? _defaultName(loc);
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: cs.primary.withValues(alpha: 0.14),
                      child: Text(
                        loc.languageCode.toUpperCase(),
                        style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800, fontSize: 11),
                      ),
                    ),
                    title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    trailing: isCurrent ? const Icon(Icons.check_circle, color: Colors.green) : null,
                    onTap: () => widget.onPicked(loc),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Locale> _filter(List<Locale> all, String q) {
    final t = q.trim().toLowerCase();
    if (t.isEmpty) return all;
    return all.where((l) {
      final code = l.toString().toLowerCase();
      final display = _defaultName(l).toLowerCase();
      return code.contains(t) || display.contains(t);
    }).toList(growable: false);
  }

  String _defaultName(Locale l) {
    final lang = l.languageCode.toUpperCase();
    final c = (l.countryCode ?? '').toUpperCase();
    return c.isEmpty ? lang : '$lang – $c';
  }

  bool _sameLocale(Locale a, Locale b) {
    return a.languageCode == b.languageCode && (a.countryCode ?? '') == (b.countryCode ?? '');
  }
}
