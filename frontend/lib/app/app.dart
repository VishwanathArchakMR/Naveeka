// lib/app/app.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/theme/app_themes.dart';
import 'router.dart';
import '../features/auth/providers/auth_providers.dart';
import '../core/network/dio_client.dart';
import '../core/storage/seed_data_loader.dart';
import '../core/storage/local_storage.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  bool _initialized = false;
  String _initStatus = 'Initializing Naveeka...';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      setState(() => _initStatus = 'Setting up local storage...');
      await LocalStorage.instance.init(); // safe; idempotent [21]

      setState(() => _initStatus = 'Connecting to services...');
      await DioClient.instance.init(); // baseUrl + interceptors [22]

      setState(() => _initStatus = 'Loading travel data...');
      await SeedDataLoader.instance.loadAllSeedData(); // offline-first [23]

      setState(() => _initStatus = 'Setting up location services...');
      await LocationService.instance.init(); // current fix + cache [24]

      setState(() => _initStatus = 'Setting up notifications...');
      await NotificationService.instance.init(); // no-op if not wired yet [19]

      setState(() => _initStatus = 'Checking authentication...');
      await ref.read(authStateProvider.notifier).loadMe(); // restore JWT [25]

      setState(() {
        _initialized = true;
        _initStatus = 'Ready to explore!';
      });
    } catch (_) {
      // Graceful fallback: allow app to start in offline mode
      setState(() {
        _initStatus = 'Starting in offline mode...';
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return _buildSplash();
    }

    final router = ref.watch(routerProvider); // MaterialApp.router expects routerConfig [15]

    return MaterialApp.router(
      title: 'Naveeka - All-in-One Travel',
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('hi', 'IN'),
        Locale('kn', 'IN'),
      ],
    );
  }

  Widget _buildSplash() {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppThemes.darkTheme,
      home: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF2fb5ff),
                Color(0xFF2bd18b),
                Color(0xFF7a5cf0),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Naveeka logo placeholder
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15), // replace withOpacity [8][2]
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.explore_outlined,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Naveeka',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'All-in-One Travel',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Loading indicator
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _initStatus,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white60,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
