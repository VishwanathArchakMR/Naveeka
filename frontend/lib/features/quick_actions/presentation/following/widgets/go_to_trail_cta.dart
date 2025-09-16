// lib/features/quick_actions/presentation/following/widgets/go_to_trail_cta.dart

import 'package:flutter/material.dart';

/// A reusable CTA prompting the user to open a "trail" screen.
/// - Inline card variant (default)
/// - MaterialBanner helper via ScaffoldMessenger
/// - Modern Material buttons and Color.withValues (no withOpacity)
class GoToTrailCta extends StatelessWidget {
  const GoToTrailCta({
    super.key,
    this.icon = Icons.travel_explore_outlined,
    this.title = 'Check out their trail',
    this.subtitle = 'See recent places, reviews, and journeys.',
    this.primaryLabel = 'Go to trail',
    this.secondaryLabel = 'Dismiss',
    this.onPrimary,
    this.onSecondary,
    this.padding = const EdgeInsets.fromLTRB(12, 10, 12, 10),
    this.borderRadius = 12,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  final String primaryLabel;
  final String secondaryLabel;

  final Future<void> Function()? onPrimary;
  final VoidCallback? onSecondary;

  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
      child: Padding(
        padding: padding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TextBlock(title: title, subtitle: subtitle),
            ),
            const SizedBox(width: 12),
            _Actions(
              primaryLabel: primaryLabel,
              secondaryLabel: secondaryLabel,
              onPrimary: onPrimary,
              onSecondary: onSecondary,
            ),
          ],
        ),
      ),
    );
  }

  /// Show as a MaterialBanner at the top of the screen.
  /// Call from an active Scaffold (e.g., after navigating to a tab).
  static void showBanner(
    BuildContext context, {
    IconData icon = Icons.travel_explore_outlined,
    String title = 'Check out their trail',
    String subtitle = 'See recent places, reviews, and journeys.',
    String primaryLabel = 'Go to trail',
    String secondaryLabel = 'Dismiss',
    Future<void> Function()? onPrimary,
    VoidCallback? onSecondary,
  }) {
    final cs = Theme.of(context).colorScheme;
    final banner = MaterialBanner(
      backgroundColor: cs.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: cs.primary),
      ),
      content: _TextBlock(title: title, subtitle: subtitle),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            if (onSecondary != null) onSecondary();
          },
          child: Text(secondaryLabel),
        ),
        ElevatedButton(
          onPressed: () async {
            if (onPrimary != null) await onPrimary();
            // Hide after action
            if (context.mounted) {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            }
          },
          child: Text(primaryLabel),
        ),
      ],
    );

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentMaterialBanner();
    messenger.showMaterialBanner(banner);
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}

class _Actions extends StatefulWidget {
  const _Actions({
    required this.primaryLabel,
    required this.secondaryLabel,
    this.onPrimary,
    this.onSecondary,
  });

  final String primaryLabel;
  final String secondaryLabel;
  final Future<void> Function()? onPrimary;
  final VoidCallback? onSecondary;

  @override
  State<_Actions> createState() => _ActionsState();
}

class _ActionsState extends State<_Actions> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: _busy
              ? null
              : () {
                  widget.onSecondary?.call();
                },
          child: Text(widget.secondaryLabel),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _busy
              ? null
              : () async {
                  if (widget.onPrimary == null) return;
                  setState(() => _busy = true);
                  try {
                    await widget.onPrimary!.call();
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            minimumSize: const Size(0, 40),
          ),
          child: _busy
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.primaryLabel),
        ),
      ],
    );
  }
}
