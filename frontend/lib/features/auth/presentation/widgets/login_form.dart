// lib/features/auth/presentation/widgets/login_form.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../../../core/errors/app_exception.dart';
import '../../providers/auth_providers.dart';

class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscure = true;
  bool _submitting = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Email is required';
    // Simple and effective email check; adjust if stricter policy is needed. [7]
    final re = RegExp(
      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
    );
    if (!re.hasMatch(s)) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Password is required';
    if (s.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return; // ensure all validators pass [2]
    setState(() => _submitting = true);

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    try {
      // Call the notifier's login; it should return ApiResult or throw AppException. [20]
      final result = await ref.read(authStateProvider.notifier).login(email, password);

      if (!mounted) return;
      result.fold(
        onSuccess: (_) {
          // Navigate back or show success UI; router redirect will usually kick in. [20]
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Welcome back!')),
          );
        },
        onError: (err) {
          _showError(err.safeMessage);
        },
      );
    } catch (e) {
      final msg = e is AppException ? e.safeMessage : 'Login failed. Please try again.';
      _showError(msg);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen for auth state changes to surface async errors or success if provider exposes them. [20]
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Email
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'name@example.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: _validateEmail, // validator pattern per Flutter docs [2]
          ),
          const SizedBox(height: 16),
          // Password
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                tooltip: _obscure ? 'Show' : 'Hide',
              ),
            ),
            validator: _validatePassword, // validator pattern per Flutter docs [2]
            onFieldSubmitted: (_) => !_submitting ? _submit() : null,
          ),
          const SizedBox(height: 12),
          // Forgot password link (navigation handled by router)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _submitting
                  ? null
                  : () {
                      // Navigator/GoRouter push to forgot password route if available. [21]
                    },
              child: const Text('Forgot password?'),
            ),
          ),
          const SizedBox(height: 16),
          // Submit
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sign in'),
            ),
          ),
        ],
      ),
    );
  }
}
