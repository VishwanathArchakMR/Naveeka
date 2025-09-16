// lib/features/auth/presentation/widgets/social_login.dart

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Social sign-in section with Google and Apple buttons.
/// - Exposes callbacks instead of hard-wiring providers to prevent compile errors if not implemented yet.
/// - Apple button shows only on iOS/macOS (or Web) by default.
/// - Buttons are accessible and large enough per general branding recommendations. [12][11]
class SocialLogin extends StatelessWidget {
  const SocialLogin({
    super.key,
    this.onGoogle,
    this.onApple,
    this.showApple, // optional override
    this.busy = false,
  });

  final VoidCallback? onGoogle;
  final VoidCallback? onApple;
  final bool? showApple;
  final bool busy;

  bool get _isApplePlatform {
    // Apple Sign in recommended on iOS/macOS; allowed on Web depending on backend config. [14]
    if (kIsWeb) return true;
    return Platform.isIOS || Platform.isMacOS;
  }

  @override
  Widget build(BuildContext context) {
    final showAppleButton = showApple ?? _isApplePlatform;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Divider with label
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or continue with',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        // Buttons row
        Row(
          children: [
            Expanded(
              child: _GoogleButton(
                onPressed: busy ? null : onGoogle ?? () => _defaultSnack(context, 'Google sign-in coming soon'),
              ),
            ),
            if (showAppleButton) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _AppleButton(
                  onPressed: busy ? null : onApple ?? () => _defaultSnack(context, 'Apple sign-in coming soon'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  static void _defaultSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // Simple neutral style that can be themed; consider using official SDK-button in integration layer. [12][17]
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.g_mobiledata, size: 20), // Placeholder icon; replace with branded asset during SDK integration. [12]
      label: const Text('Continue with Google'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
      ),
    );
  }
}

class _AppleButton extends StatelessWidget {
  const _AppleButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // High-contrast Apple-style fill; replace with SignInWithAppleButton from package at integration time. [1][11]
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.apple, size: 20),
      label: const Text('Continue with Apple'),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
      ),
    );
  }
}
