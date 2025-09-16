// lib/features/navee_ai/presentation/widgets/navee_ai_button.dart

import 'package:flutter/material.dart';

class NaveeAiButton extends StatelessWidget {
  const NaveeAiButton({
    super.key,
    this.extended = true,
    this.busy = false,
    this.label = 'Ask Navee',
    this.tooltip = 'Ask AI',
    this.onQuickAsk,        // Future<void> Function(String prompt)
    this.onOpenChat,        // VoidCallback
    this.onOpenExplore,     // VoidCallback
    this.onOpenCollaborate, // VoidCallback
    this.onOpenSettings,    // VoidCallback (long-press)
  });

  /// If true renders an extended FAB (with icon + text), otherwise a circular FAB.
  final bool extended;

  /// Replaces the icon with a small spinner when true.
  final bool busy;

  /// Visible label when extended=true.
  final String label;

  /// Tooltip text for accessibility on long-press/hover.
  final String tooltip;

  /// Called when the user submits the quick-ask prompt from the sheet.
  final Future<void> Function(String prompt)? onQuickAsk;

  /// Direct open handlers for full screens (optional shortcuts in the sheet).
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenExplore;
  final VoidCallback? onOpenCollaborate;

  /// Long-press handler to open AI settings.
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final btn = extended
        ? FloatingActionButton.extended(
            onPressed: () => _openQuickAsk(context),
            label: Text(label),
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.smart_toy_outlined),
          )
        : FloatingActionButton(
            onPressed: () => _openQuickAsk(context),
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.smart_toy_outlined),
          ); // FloatingActionButton and its extended variant are the standard primary actions, recommended for prominent shortcuts like “Ask AI”. [1][2]

    return GestureDetector(
      onLongPress: onOpenSettings,
      child: Tooltip(message: tooltip, child: btn),
    ); // Tooltip provides an accessible label and appears on long-press/hover, improving clarity of the FAB’s purpose. [10]
  }

  Future<void> _openQuickAsk(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _QuickAskSheet(
        onSubmit: onQuickAsk,
        onOpenChat: onOpenChat,
        onOpenExplore: onOpenExplore,
        onOpenCollaborate: onOpenCollaborate,
      ),
    ); // showModalBottomSheet presents a focused, shaped modal that prevents interaction with the rest of the UI until dismissed. [9][12]
  }
}

class _QuickAskSheet extends StatefulWidget {
  const _QuickAskSheet({
    required this.onSubmit,
    required this.onOpenChat,
    required this.onOpenExplore,
    required this.onOpenCollaborate,
  });

  final Future<void> Function(String prompt)? onSubmit;
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenExplore;
  final VoidCallback? onOpenCollaborate;

  @override
  State<_QuickAskSheet> createState() => _QuickAskSheetState();
}

class _QuickAskSheetState extends State<_QuickAskSheet> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || widget.onSubmit == null) {
      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Type a question or idea')),
        );
      }
      return;
    }
    setState(() => _sending = true);
    try {
      await widget.onSubmit!(text);
      if (mounted) Navigator.of(context).maybePop();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              const Expanded(
                child: Text('Quick ask', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 8),

          // Prompt input
          TextField(
            controller: _ctrl,
            minLines: 2,
            maxLines: 5,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              hintText: 'e.g., 3‑day Goa plan with beaches and food',
              prefixIcon: Icon(Icons.edit_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // Actions
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _sending ? null : _submit,
                  icon: _sending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  label: Text(_sending ? 'Sending…' : 'Ask'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Shortcuts
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onOpenExplore,
                  icon: const Icon(Icons.explore_outlined),
                  label: const Text('Explore'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onOpenChat,
                  icon: const Icon(Icons.forum_outlined),
                  label: const Text('Open chat'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onOpenCollaborate,
                  icon: const Icon(Icons.group_work_outlined),
                  label: const Text('Collaborate'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
