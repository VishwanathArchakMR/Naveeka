// lib/features/trails/presentation/trails_shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TrailsShell extends StatelessWidget {
  const TrailsShell({super.key, required this.child});
  final Widget child;

  int _indexForLocation(String loc) {
    if (loc.startsWith('/trails/search')) return 1;
    if (loc.startsWith('/trails/create')) return 2;
    if (loc.startsWith('/trails/reels')) return 3;
    if (loc.startsWith('/trails/profile')) return 4;
    return 0; // /trails/home (or /trails)
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/trails/home');
        break;
      case 1:
        context.go('/trails/search');
        break;
      case 2:
        context.go('/trails/create');
        break;
      case 3:
        context.go('/trails/reels');
        break;
      case 4:
        context.go('/trails/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use GoRouterState to read the current URI reliably on go_router >= 10
    // https://stackoverflow.com/a/78564351
    final loc = GoRouterState.of(context).uri.toString();
    final index = _indexForLocation(loc);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/home'); // adjust to the actual main Home path
            }
          },
          tooltip: 'Back',
        ),
        title: const Text('Trails'),
        centerTitle: false,
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => _onTap(context, i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            selectedIcon: Icon(Icons.add_box),
            label: 'Create',
          ),
          NavigationDestination(
            icon: Icon(Icons.movie_filter_outlined),
            selectedIcon: Icon(Icons.movie_filter),
            label: 'Reels',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
