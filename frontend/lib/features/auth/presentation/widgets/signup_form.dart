// lib/features/auth/presentation/widgets/signup_form.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_result.dart';
import '../../../../core/errors/app_exception.dart';
import '../../providers/auth_providers.dart';

class SignupForm extends ConsumerStatefulWidget {
  const SignupForm({super.key});

  @override
  ConsumerState<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends ConsumerState<SignupForm> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _submitting = false;

  String _role = 'user'; // 'user' | 'partner'

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? _validateName(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Name is required';
    if (s.length < 2) return 'Name must be at least 2 characters';
    return null;
  } // [3]

  String? _validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Email is required';
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!re.hasMatch(s)) return 'Enter a valid email';
    return null;
  } // [3]

  String? _validatePhone(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Phone is required';
    // Simple international-friendly digits check (10-15 digits). Adjust as needed or use a phone package. [16]
    final re = RegExp(r'^[0-9+\-\s]{7,20}$');
    if (!re.hasMatch(s)) return 'Enter a valid phone';
    return null;
  } // [16]

  String? _validatePassword(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Password is required';
    if (s.length < 6) return 'Password must be at least 6 characters';
    return null;
  } // [3]

  String? _validateConfirm(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Please confirm the password';
    if (s != _passwordCtrl.text) return 'Passwords do not match';
    return null;
  } // [1]

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return; // [3]

    setState(() => _submitting = true);

    final payload = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'password': _passwordCtrl.text,
      'role': _role, // 'user' | 'partner'
    };

    try {
      final result = await ref
          .read(authStateProvider.notifier)
          .register(payload); // [9]

      if (!mounted) return;
      result.fold(
        onSuccess: (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account created. Welcome!')),
          ); // [3]
        },
        onError: (err) => _showError(err.safeMessage), // [22]
      );
    } catch (e) {
      final msg = e is AppException ? e.safeMessage : 'Sign up failed. Please try again.';
      _showError(msg); // [23]
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  } // [23]

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Name
          TextFormField(
            controller: _nameCtrl,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: _validateName,
          ), // [3]
          const SizedBox(height: 16),
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
            validator: _validateEmail,
          ), // [3]
          const SizedBox(height: 16),
          // Phone
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(
              labelText: 'Phone',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: _validatePhone,
          ), // [16]
          const SizedBox(height: 16),
          // Role
          DropdownButtonFormField<String>(
            initialValue: _role,
            items: const [
              DropdownMenuItem(value: 'user', child: Text('User')),
              DropdownMenuItem(value: 'partner', child: Text('Partner')),
            ],
            onChanged: _submitting
                ? null
                : (v) => setState(() => _role = v ?? 'user'),
            decoration: const InputDecoration(
              labelText: 'Account type',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ), // [3]
          const SizedBox(height: 16),
          // Password
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscure1,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure1 = !_obscure1),
                icon: Icon(_obscure1 ? Icons.visibility_off : Icons.visibility),
                tooltip: _obscure1 ? 'Show' : 'Hide',
              ),
            ),
            validator: _validatePassword,
          ), // [3]
          const SizedBox(height: 16),
          // Confirm Password
          TextFormField(
            controller: _confirmCtrl,
            obscureText: _obscure2,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Confirm password',
              prefixIcon: const Icon(Icons.lock_reset_outlined),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure2 = !_obscure2),
                icon: Icon(_obscure2 ? Icons.visibility_off : Icons.visibility),
                tooltip: _obscure2 ? 'Show' : 'Hide',
              ),
            ),
            validator: _validateConfirm,
            onFieldSubmitted: (_) => !_submitting ? _submit() : null,
          ), // [1]
          const SizedBox(height: 20),
          // Terms note (UI only; add checkbox if enforcement is needed)
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'By creating an account, you agree to our Terms and Privacy Policy.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ), // [3]
          const SizedBox(height: 16),
          // Submit button
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
                  : const Text('Create account'),
            ),
          ), // [3]
        ],
      ),
    );
  }
}
