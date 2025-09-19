// lib/features/auth/presentation/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/components/cards/glass_card.dart';
import '../providers/auth_providers.dart';
import '../../../core/storage/token_storage.dart';

// Composed auth widgets
import 'widgets/login_form.dart';
import 'widgets/signup_form.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  bool _isLogin = true;

  late final AnimationController _animationController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  late final Animation<double> _fade =
      CurvedAnimation(curve: Curves.easeInOut, parent: _animationController);
  late final Animation<Offset> _slide =
      Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(_fade);

  @override
  void initState() {
    super.initState();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // DEMO: Bypass backend and go straight in (kept for quick reviews)
  Future<void> _demoLogin({required String role}) async {
    final mockToken = 'demo_${role}_${DateTime.now().millisecondsSinceEpoch}';
    await TokenStorage.save(mockToken);
    await ref.read(authStateProvider.notifier).loadMe();
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final title = _isLogin ? 'Welcome Back' : 'Create Your Account';
    final subtitle = _isLogin
        ? 'Login to explore soulful journeys'
        : 'Join Naveeka and start your adventure';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Column(
                children: [
                  // Logo + Intro
                  Hero(
                    tag: 'app_logo',
                    child: Column(
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF38E8C6), Color(0xFF7BD8FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.tealAccent.withValues(alpha: 0.4),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.explore, color: Colors.white, size: 44),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Form Card: compose login or signup form
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        if (_isLogin) const LoginForm() else const SignupForm(),
                        const SizedBox(height: 16),

                        // Forgot password entry (push screen directly; no router entry required)
                        if (_isLogin)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                              child: const Text('Forgot password?'),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Toggle between Login and Register
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin
                          ? "Don't have an account? Register"
                          : 'Already have an account? Sign in',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),

                  // Demo login (bypass backend)
                  if (_isLogin) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Quick Demo',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              await _demoLogin(role: 'user');
                            },
                            child: const Text('User Demo'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              await _demoLogin(role: 'partner');
                            },
                            child: const Text('Partner Demo'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
