// lib/features/auth/presentation/forgot_password_screen.dart

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/config/constants.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Email is required';
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!re.hasMatch(s)) return 'Enter a valid email';
    return null;
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    setState(() => _submitting = true);
    final email = _emailCtrl.text.trim();

    try {
      final result = await ApiResult.guardFuture<Map<String, dynamic>>(() async {
        // Common REST pattern: POST /api/auth/password/reset-request { email }.
        // If your backend differs, adjust the endpoint accordingly.
        final dio = DioClient.instance.dio;
        final path = '${AppConstants.apiAuth}/password/reset-request';
        final res = await dio.post(path, data: {'email': email});
        return Map<String, dynamic>.from(res.data as Map);
      });

      if (!mounted) return;
      result.fold(
        onSuccess: (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'If an account exists for that email, a reset link has been sent.',
              ),
            ),
          );
          Navigator.of(context).maybePop();
        },
        onError: (err) {
          _showError(err.safeMessage);
        },
      );
    } on AppException catch (e) {
      _showError(e.safeMessage);
    } on DioException catch (e) {
      _showError(e.message ?? 'Request failed. Please try again.');
    } catch (_) {
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.padding),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Enter the email associated with your account and we’ll send a reset link.',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'name@example.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: _validateEmail,
                  onFieldSubmitted: (_) => !_submitting ? _submit() : null,
                ),
                const SizedBox(height: 24),
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
                        : const Text('Send reset link'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
