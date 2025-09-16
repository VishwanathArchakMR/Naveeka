// lib/features/settings/presentation/widgets/help_support.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupport extends StatelessWidget {
  const HelpSupport({
    super.key,
    this.supportEmail = 'support@example.com',
    this.supportPhone,
    this.faqs = const <({String q, String a})>[],
    this.privacyUrl,
    this.termsUrl,
    this.onSubmitReport, // Future<void> Function(String title, String description, bool includeDiagnostics)
  });

  final String supportEmail;
  final String? supportPhone;
  final List<({String q, String a})> faqs;
  final Uri? privacyUrl;
  final Uri? termsUrl;

  final Future<void> Function(String title, String description, bool includeDiagnostics)? onSubmitReport;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Help & support', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 6),

            // FAQs
            if (faqs.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 1.0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: _FaqsList(faqs: faqs),
              ),

            if (faqs.isNotEmpty) const SizedBox(height: 12),

            // Contact and Report
            _ActionTile(
              icon: Icons.support_agent,
              label: 'Contact support',
              onTap: () => _openContactSheet(context),
            ),
            const Divider(height: 0),
            _ActionTile(
              icon: Icons.bug_report_outlined,
              label: 'Report a problem',
              onTap: () => _openReportSheet(context),
            ),

            const SizedBox(height: 12),

            // Policies
            if (privacyUrl != null || termsUrl != null)
              Container(
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 1.0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  children: [
                    if (privacyUrl != null)
                      _ActionTile(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Privacy policy',
                        onTap: () => _launch(privacyUrl!),
                      ),
                    if (privacyUrl != null && termsUrl != null) const Divider(height: 0),
                    if (termsUrl != null)
                      _ActionTile(
                        icon: Icons.description_outlined,
                        label: 'Terms of service',
                        onTap: () => _launch(termsUrl!),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _launch(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _sendEmail({String? subject, String? body}) async {
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      queryParameters: {
        if ((subject ?? '').isNotEmpty) 'subject': subject!,
        if ((body ?? '').isNotEmpty) 'body': body!,
      },
    );
    await _launch(uri);
  }

  Future<void> _call() async {
    if ((supportPhone ?? '').isEmpty) return;
    final uri = Uri(scheme: 'tel', path: supportPhone!.trim());
    await _launch(uri);
  }

  void _openContactSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _ContactSheet(
        onEmail: (subj, body) => _sendEmail(subject: subj, body: body),
        onCall: supportPhone == null ? null : _call,
        supportEmail: supportEmail,
        supportPhone: supportPhone,
      ),
    );
  }

  void _openReportSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _ReportSheet(
        onSubmit: onSubmitReport ??
            (title, desc, includeDiag) async {
              // Fallback: compose email
              await _sendEmail(
                subject: 'Bug report: $title',
                body: '$desc\n\nInclude diagnostics: $includeDiag',
              );
            },
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: cs.primary),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _FaqsList extends StatelessWidget {
  const _FaqsList({required this.faqs});
  final List<({String q, String a})> faqs;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: faqs.length,
      separatorBuilder: (_, __) => const Divider(height: 0),
      itemBuilder: (context, i) {
        final item = faqs[i];
        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 8),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            title: Text(item.q, style: const TextStyle(fontWeight: FontWeight.w800)),
            iconColor: cs.primary,
            collapsedIconColor: cs.onSurfaceVariant,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(item.a),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ContactSheet extends StatefulWidget {
  const _ContactSheet({required this.onEmail, this.onCall, required this.supportEmail, this.supportPhone});
  final Future<void> Function(String subject, String body) onEmail;
  final Future<void> Function()? onCall;
  final String supportEmail;
  final String? supportPhone;

  @override
  State<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends State<_ContactSheet> {
  final _subject = TextEditingController();
  final _body = TextEditingController();

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Contact support', style: TextStyle(fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _subject,
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _body,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: widget.supportEmail));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email copied')));
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy email'),
                  ),
                ),
                const SizedBox(width: 8),
                if (widget.onCall != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onCall,
                      icon: const Icon(Icons.call),
                      label: Text(widget.supportPhone ?? 'Call'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  await widget.onEmail(_subject.text.trim(), _body.text.trim());
                  if (mounted) Navigator.maybePop(context);
                },
                icon: const Icon(Icons.send),
                label: const Text('Send email'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.onSubmit});
  final Future<void> Function(String title, String description, bool includeDiagnostics) onSubmit;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  bool _includeDiag = true;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Report a problem', style: TextStyle(fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _desc,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Describe the issue',
                hintText: 'Steps to reproduce, expected vs actual, screenshots/links…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Include diagnostics'),
              subtitle: Text('Attach app version and basic device info', style: TextStyle(color: cs.onSurfaceVariant)),
              value: _includeDiag,
              onChanged: (v) => setState(() => _includeDiag = v),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          await widget.onSubmit(_title.text.trim(), _desc.text.trim(), _includeDiag);
                          if (mounted) Navigator.maybePop(context);
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                icon: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.report_gmailerrorred_outlined),
                label: const Text('Submit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
