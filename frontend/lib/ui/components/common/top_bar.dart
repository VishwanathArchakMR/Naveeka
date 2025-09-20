// lib/ui/components/common/top_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../navigation/route_names.dart';

class TopBar extends ConsumerWidget implements PreferredSizeWidget {
  const TopBar({
    super.key,
    this.title,
    this.showSettings = false,
    this.showBack = true,
    this.actions,
    this.backgroundColor,
    this.elevation,
    this.centerTitle,
  });

  final String? title;
  final bool showSettings;
  final bool showBack;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final double? elevation;
  final bool? centerTitle;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return AppBar(
      backgroundColor: backgroundColor ?? cs.surface, // modern neutral surface in M3 [2]
      elevation: elevation,
      scrolledUnderElevation: elevation ?? 1, // responds when content scrolls under [9]
      automaticallyImplyLeading: showBack,
      centerTitle: centerTitle,
      title: title != null
          ? Text(
              title!,
              style: Theme.of(context).textTheme.titleLarge?.copyWith( // M3 headline sizing [1]
                    fontWeight: FontWeight.w600,
                  ),
            )
          : null,
      actions: <Widget>[
        ...?actions,
        if (showSettings)
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.pushNamed(RouteNames.settings),
            tooltip: 'Settings',
          ),
      ],
    );
  }
}

class GradientTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const GradientTopBar({
    super.key,
    this.title,
    this.showSettings = false,
    this.showBack = true,
    this.actions,
    this.centerTitle,
    this.colors = const <Color>[
      Color(0xFF2fb5ff), // brand blue
      Color(0xFF2bd18b), // brand green
    ],
  });

  final String? title;
  final bool showSettings;
  final bool showBack;
  final List<Widget>? actions;
  final bool? centerTitle;

  /// Override gradient colors if desired.
  final List<Color> colors;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0, // keep gradient crisp while scrolling [1]
        automaticallyImplyLeading: showBack,
        centerTitle: centerTitle,
        iconTheme: const IconThemeData(color: Colors.white),
        title: title != null
            ? Text(
                title!,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
              )
            : null,
        actions: <Widget>[
          ...?actions,
          if (showSettings)
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.white),
              onPressed: () => context.pushNamed(RouteNames.settings),
              tooltip: 'Settings',
            ),
        ],
      ),
    );
  }
}

class HomeTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const HomeTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 20);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: preferredSize.height,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest, // modern neutral container [1]
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant), // subtle divider [2]
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => context.pushNamed(RouteNames.settings),
              tooltip: 'Settings',
            ),
            const Spacer(),
            Text(
              'Naveeka',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {
                // Navigate to notifications; try named first, then path, else inform.
                try {
                  context.pushNamed('notifications');
                } catch (_) {
                  try {
                    context.push('/notifications');
                  } catch (_) {
                    final messenger = ScaffoldMessenger.maybeOf(context);
                    messenger?.showSnackBar(
                      const SnackBar(content: Text('Notifications screen is not available')),
                    );
                  }
                }
              },
              tooltip: 'Notifications',
            ),
          ],
        ),
      ),
    );
  }
}
