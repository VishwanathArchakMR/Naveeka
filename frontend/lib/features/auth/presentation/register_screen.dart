// lib/features/auth/presentation/register_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/components/glass_card.dart';
import 'widgets/signup_form.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with TickerProviderStateMixin {
  late final AnimationController _animController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.1),
    end: Offset.zero,
  ).chain( CurveTween(curve: Curves.easeOutCubic)).animate(_animController);

  @override
  void initState() {
    super.initState();
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  // Header
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
                          child: const Icon(Icons.person_add, color: Colors.white, size: 44),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Create Your Account',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Join Naveeka and start exploring soulful journeys',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Form (composed)
                  const GlassCard(
                    padding: EdgeInsets.all(20),
                    child: SignupForm(),
                  ),
                  const SizedBox(height: 20),

                  // Go to Login
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text(
                      'Already have an account? Login',
                      style: TextStyle(color: Colors.white70),
                    ),
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
