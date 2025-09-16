// lib/features/settings/presentation/widgets/settings_side_sheet.dart

import 'package:flutter/material.dart';

/// Adaptive Settings side sheet:
/// - On wide layouts, opens as a right-anchored modal side sheet (showGeneralDialog + slide) 
/// - On narrow layouts, falls back to a rounded modal bottom sheet
/// - Provides header with title + close, scrollable body, and optional footer actions
/// - Uses Color.withValues (no withOpacity) and const where possible
class SettingsSideSheet extends StatelessWidget {
  const SettingsSideSheet({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions,
    this.onClose,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  /// Optional footer actions (e.g., Save/Reset buttons).
  final List<Widget>? actions;

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;

    // Constrain sheet width on large screens for a comfortable reading column.
    final maxW = width >= 1200
        ? 520.0
        : width >= 900
            ? 460.0
            : 400.0;

    return SafeArea(
      child: Material(
        color: cs.surface,
        elevation: 2,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints.tightFor(width: maxW),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          if ((subtitle ?? '').trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                subtitle!.trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                      onPressed: onClose ?? () => Navigator.maybePop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 0),

              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: child,
                ),
              ),

              // Footer
              if ((actions ?? const []).isNotEmpty) ...[
                const Divider(height: 0),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (int i = 0; i < actions!.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        actions![i],
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Adaptive presenter:
  /// - If screen width >= breakpoint, presents a modal side sheet using showGeneralDialog
  /// - Otherwise, presents a rounded modal bottom sheet using showModalBottomSheet
  static Future<T?> showAdaptive<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    required WidgetBuilder builder,
    List<Widget>? actions,
    double breakpoint = 720, // PX threshold to switch to side sheet
    Color? barrierColor,
    bool barrierDismissible = true,
  }) async {
    final width = MediaQuery.of(context).size.width;
    if (width < breakpoint) {
      // Bottom sheet fallback for narrow devices.
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: _BottomSheetWrapper(
            title: title,
            subtitle: subtitle,
            actions: actions,
            child: builder(ctx),
          ),
        ),
      );
    }

    // Side sheet for wide devices using showGeneralDialog with slide transition.
    return showGeneralDialog<T>(
      context: context,
      barrierLabel: 'Settings',
      barrierDismissible: barrierDismissible,
      barrierColor: (barrierColor ?? Colors.black).withValues(alpha: 0.32),
      pageBuilder: (ctx, anim, secAnim) {
        return Align(
          alignment: Alignment.centerRight,
          child: SettingsSideSheet(
            title: title,
            subtitle: subtitle,
            actions: actions,
            onClose: () => Navigator.maybePop(ctx),
            child: builder(ctx),
          ),
        );
      },
      transitionBuilder: (ctx, anim, secAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 280),
    );
  }
}

/// Internal wrapper for bottom-sheet presentation to reuse the same header/footer layout.
class _BottomSheetWrapper extends StatelessWidget {
  const _BottomSheetWrapper({
    required this.title,
    required this.child,
    this.subtitle,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        if ((subtitle ?? '').trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle!.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            const Divider(height: 0),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: child,
              ),
            ),
            if ((actions ?? const []).isNotEmpty) ...[
              const Divider(height: 0),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (int i = 0; i < actions!.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      actions![i],
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
