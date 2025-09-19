// lib/ui/components/common/error_boundary.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' as f; // Use FlutterError, FlutterExceptionHandler explicitly.

// Removed the local handler import to avoid type name collision with Flutter's FlutterExceptionHandler.
// import '../../../core/errors/flutter_exception_handler.dart';

/// A friendly error boundary widget that renders a fallback UI when an error is caught.
class ErrorBoundary extends StatefulWidget {
  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallback,
    this.onError,
    this.onRetry,
    this.captureGlobal = false,
    this.showDetailsByDefault = false,
    this.title = 'Something went wrong',
    this.message,
  });

  final Widget child;

  final Widget Function(BuildContext context, Object error, StackTrace? stack)? fallback;

  final void Function(f.FlutterErrorDetails details)? onError;

  final VoidCallback? onRetry;

  final bool captureGlobal;

  final bool showDetailsByDefault;

  final String title;

  final String? message;

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stack;

  // Preserve previous global handlers to restore on dispose.
  f.FlutterExceptionHandler? _prevFlutterOnError; // typedef: void Function(FlutterErrorDetails) [web:6310]
  ErrorCallback? _prevPlatformOnError; // PlatformDispatcher.onError uses ErrorCallback(bool Function(Object, StackTrace)?) [web:6318]

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
    // Capture framework (build/layout/paint/callback) errors. [web:6304]
    _prevFlutterOnError = f.FlutterError.onError;
    f.FlutterError.onError = (f.FlutterErrorDetails details) {
      _handleError(details);
      _prevFlutterOnError?.call(details);
    };

    // Capture uncaught platform/zone-originated errors. [web:6306][web:6315]
    _prevPlatformOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      _handleError(f.FlutterErrorDetails(exception: error, stack: stack));
      return _prevPlatformOnError?.call(error, stack) ?? true;
    };
  }

  void _restoreGlobalHandlers() {
    f.FlutterError.onError = _prevFlutterOnError;
    PlatformDispatcher.instance.onError = _prevPlatformOnError;
  }

  void _handleError(f.FlutterErrorDetails details) {
    if (!mounted) return;
    setState(() {
      _error = details.exception;
      _stack = details.stack;
    });
    widget.onError?.call(details);
  }

  void _clearError() {
    setState(() {
      _error = null;
      _stack = null;
      _showDetails = widget.showDetailsByDefault;
    });
  }

  @override
  Widget build(BuildContext context) {
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

    return widget.child;
  }
}

/// Default fallback UI with a large icon, title, message, details expander, and retry button.
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

    final Color iconBg = cs.error.withValues(alpha: 0.14);
    final Color iconFg = cs.onErrorContainer;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
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
          color: cs.surfaceContainerHighest.withValues(alpha: 0.9),
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
