// lib/ui/components/common/error_boundary.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/errors/flutter_exception_handler.dart';

/// A friendly error boundary widget that renders a fallback UI when an error is caught.
/// - Optional global capture via FlutterError.onError and PlatformDispatcher.onError
/// - Retry hook to rebuild/reset state
/// - Minimal, Material 3–aligned fallback with details expander
/// Notes:
/// - Flutter’s error hooks (FlutterError.onError, ErrorWidget.builder, PlatformDispatcher.onError)
///   are global; use captureGlobal=true at a screen/root scope, not for tiny subtrees. [3][2]
class ErrorBoundary extends StatefulWidget {
  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallback,
    this.onError,
    this.onRetry,
    this.captureGlobal = false, // set true near app/screen roots, not deep subtrees
    this.showDetailsByDefault = false,
    this.title = 'Something went wrong',
    this.message,
  });

  /// The normal child to render when no error is present. [22]
  final Widget child;

  /// Optional fallback builder for a custom error UI; if null, a default UI is shown. [22]
  final Widget Function(BuildContext context, Object error, StackTrace? stack)? fallback;

  /// Error hook (e.g., for logging/analytics). [3]
  final void Function(FlutterErrorDetails details)? onError;

  /// Called when the user taps "Retry." If null, boundary will just clear its local error state. [3]
  final VoidCallback? onRetry;

  /// If true, installs global handlers while mounted (FlutterError.onError and PlatformDispatcher.onError). [3]
  final bool captureGlobal;

  /// Expand the details section (stack trace) by default. [3]
  final bool showDetailsByDefault;

  /// Title text for the default fallback UI. [22]
  final String title;

  /// Optional message shown under the title in the default fallback UI. [22]
  final String? message;

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stack;
  FlutterErrorDetails? _details;

  // Preserve previous global handlers to restore on dispose. [3]
  FlutterExceptionHandler? _prevFlutterOnError;
  PlatformDispatcherErrorCallback? _prevPlatformOnError;

  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _showDetails = widget.showDetailsByDefault;
    if (widget.captureGlobal) {
      _installGlobalHandlers();
    }
  }

  @override
  void didUpdateWidget(ErrorBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Toggle global capture based on the latest prop. [3]
    if (!oldWidget.captureGlobal && widget.captureGlobal) {
      _installGlobalHandlers();
    } else if (oldWidget.captureGlobal && !widget.captureGlobal) {
      _restoreGlobalHandlers();
    }
  }

  @override
  void dispose() {
    if (widget.captureGlobal) {
      _restoreGlobalHandlers();
    }
    super.dispose();
  }

  void _installGlobalHandlers() {
    // Capture framework (build/layout/paint/callback) errors. [3]
    _prevFlutterOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleError(details);
      _prevFlutterOnError?.call(details);
    };

    // Capture uncaught platform/zone-originated errors (outside framework callbacks). [3]
    _prevPlatformOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      _handleError(FlutterErrorDetails(exception: error, stack: stack));
      // Return previous decision or true to signal handled. [3]
      return _prevPlatformOnError?.call(error, stack) ?? true;
    };
  }

  void _restoreGlobalHandlers() {
    FlutterError.onError = _prevFlutterOnError;
    PlatformDispatcher.instance.onError = _prevPlatformOnError;
  }

  void _handleError(FlutterErrorDetails details) {
    if (!mounted) return;
    setState(() {
      _details = details;
      _error = details.exception;
      _stack = details.stack;
    });
    widget.onError?.call(details);
  }

  void _clearError() {
    setState(() {
      _details = null;
      _error = null;
      _stack = null;
      _showDetails = widget.showDetailsByDefault;
    });
  }

  @override
  Widget build(BuildContext context) {
    // If an error was recorded (globally or via manual call), render fallback. [3]
    if (_error != null) {
      if (widget.fallback != null) {
        return widget.fallback!(context, _error!, _stack);
      }
      return _DefaultErrorFallback(
        title: widget.title,
        message: widget.message ?? _error.toString(),
        stack: _stack,
        showDetails: _showDetails,
        onToggleDetails: () => setState(() => _showDetails = !_showDetails),
        onRetry: () {
          widget.onRetry?.call();
          _clearError();
        },
      );
    }

    // Try to build child with a protective wrapper around layout/paint errors via global hooks if enabled. [3]
    return widget.child;
  }
}

/// Default fallback UI with a large icon, title, message, details expander, and retry button. [22]
class _DefaultErrorFallback extends StatelessWidget {
  const _DefaultErrorFallback({
    required this.title,
    required this.message,
    required this.stack,
    required this.showDetails,
    required this.onToggleDetails,
    required this.onRetry,
  });

  final String title;
  final String message;
  final StackTrace? stack;
  final bool showDetails;
  final VoidCallback onToggleDetails;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    final Color iconBg = cs.error.withValues(alpha: 0.14); // wide‑gamut safe [21]
    final Color iconFg = cs.onErrorContainer;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest, // modern neutral surface [22]
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.error_outline_rounded, size: 34, color: iconFg),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: cs.onSurface),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: t.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  if (stack != null) _DetailsSection(stack: stack!, show: showDetails, onToggle: onToggleDetails),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      OutlinedButton(
                        onPressed: onRetry,
                        child: const Text('Retry'),
                      ),
                      TextButton(
                        onPressed: onToggleDetails,
                        child: Text(showDetails ? 'Hide details' : 'Show details'),
                      ),
                    ],
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

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({required this.stack, required this.show, required this.onToggle});

  final StackTrace stack;
  final bool show;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    return AnimatedCrossFade(
      crossFadeState: show ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      duration: const Duration(milliseconds: 150),
      firstChild: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.9), // updated surface [22][21]
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: SingleChildScrollView(
          child: Text(
            stack.toString(),
            style: t.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
      secondChild: const SizedBox.shrink(),
    );
  }
}
