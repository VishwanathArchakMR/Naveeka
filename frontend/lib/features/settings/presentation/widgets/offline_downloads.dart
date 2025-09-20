// lib/features/settings/presentation/widgets/offline_downloads.dart

import 'package:flutter/material.dart';

/// Represents a single offline-downloadable item (e.g., map area, guide, media).
class OfflineItem {
  const OfflineItem({
    required this.id,
    required this.title,
    required this.sizeBytes,
    required this.status,
    this.progress = 0.0, // 0..1 for active downloads
    this.subtitle,
    this.thumbnailUrl,
  });

  final String id;
  final String title;
  final int sizeBytes;
  final DownloadStatus status;
  final double progress;
  final String? subtitle;
  final String? thumbnailUrl;
}

enum DownloadStatus { queued, downloading, paused, completed, failed }

enum DownloadQuality { standard, high }

class OfflineDownloads extends StatelessWidget {
  const OfflineDownloads({
    super.key,
    this.sectionTitle = 'Offline downloads',

    // Quotas / storage
    required this.totalBytesUsed,
    required this.totalBytesCapacity,

    // Preferences
    required this.wifiOnly,
    required this.autoUpdate,

    // Items
    required this.items,

    // Callbacks
    this.onToggleWifiOnly,
    this.onToggleAutoUpdate,
    this.onResumeItem, // Future<void> Function(String id)
    this.onPauseItem, // Future<void> Function(String id)
    this.onRemoveItem, // Future<void> Function(String id)
    this.onRemoveAll, // Future<void> Function()
    this.onPickQuality, // Future<void> Function(DownloadQuality)
    this.onAddNew, // VoidCallback to open a picker elsewhere
  });

  final String sectionTitle;

  final int totalBytesUsed;
  final int totalBytesCapacity;

  final bool wifiOnly;
  final bool autoUpdate;

  final List<OfflineItem> items;

  final ValueChanged<bool>? onToggleWifiOnly;
  final ValueChanged<bool>? onToggleAutoUpdate;

  final Future<void> Function(String id)? onResumeItem;
  final Future<void> Function(String id)? onPauseItem;
  final Future<void> Function(String id)? onRemoveItem;
  final Future<void> Function()? onRemoveAll;

  final Future<void> Function(DownloadQuality q)? onPickQuality;

  final VoidCallback? onAddNew;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final used = _fmtBytes(totalBytesUsed);
    final cap = _fmtBytes(totalBytesCapacity);
    final pct = totalBytesCapacity > 0 ? (totalBytesUsed / totalBytesCapacity).clamp(0.0, 1.0) : 0.0;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(child: Text(sectionTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                if (onAddNew != null)
                  FilledButton.icon(
                    onPressed: onAddNew,
                    icon: const Icon(Icons.download_for_offline_outlined, size: 18),
                    label: const Text('Add'),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // Storage usage
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 1.0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Storage', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 10,
                      backgroundColor: cs.surfaceContainerHigh.withValues(alpha: 1.0),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: Text('$used used of $cap', style: TextStyle(color: cs.onSurfaceVariant))),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: onRemoveAll,
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: const Text('Clear all'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Preferences
            const _SectionHeader(text: 'Preferences'),
            _SwitchTile(
              icon: Icons.wifi_tethering_off,
              title: 'Wi‑Fi only',
              subtitle: 'Download only on Wi‑Fi to save mobile data',
              value: wifiOnly,
              onChanged: onToggleWifiOnly,
            ),
            _SwitchTile(
              icon: Icons.update,
              title: 'Auto‑update',
              subtitle: 'Keep offline areas up to date when connected',
              value: autoUpdate,
              onChanged: onToggleAutoUpdate,
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: const _LeadIcon(icon: Icons.high_quality),
              title: const Text('Download quality', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('Choose size vs. detail trade‑off', style: TextStyle(color: cs.onSurfaceVariant)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openQualitySheet(context),
            ),

            const SizedBox(height: 12),

            // Items
            const _SectionHeader(text: 'Offline items'),
            if (items.isEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 1.0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Row(
                  children: [
                    const _LeadIcon(icon: Icons.folder_off_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('No downloads yet', style: TextStyle(color: cs.onSurfaceVariant)),
                    ),
                    if (onAddNew != null) TextButton.icon(onPressed: onAddNew, icon: const Icon(Icons.add), label: const Text('Add')),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (context, i) => _ItemTile(
                  item: items[i],
                  onResume: onResumeItem,
                  onPause: onPauseItem,
                  onRemove: onRemoveItem,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openQualitySheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => Material(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(sheetContext).viewInsets.bottom),
          child: _QualitySheet(onPick: (q) async {
            if (onPickQuality != null) await onPickQuality!(q);
            if (sheetContext.mounted) Navigator.maybePop(sheetContext);
          }),
        ),
      ),
    );
  }

  String _fmtBytes(int b) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double v = b.toDouble();
    int idx = 0;
    while (v >= 1024 && idx < units.length - 1) {
      v /= 1024;
      idx++;
    }
    return '${v.toStringAsFixed(v >= 100 ? 0 : v >= 10 ? 1 : 2)} ${units[idx]}';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
    );
  }
}

class _LeadIcon extends StatelessWidget {
  const _LeadIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: cs.primary),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: _LeadIcon(icon: icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: (subtitle ?? '').isEmpty ? null : Text(subtitle!, style: TextStyle(color: cs.onSurfaceVariant)),
      trailing: Switch.adaptive(value: value, onChanged: onChanged),
      onTap: onChanged == null ? null : () => onChanged!(!value),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    this.onResume,
    this.onPause,
    this.onRemove,
  });

  final OfflineItem item;
  final Future<void> Function(String id)? onResume;
  final Future<void> Function(String id)? onPause;
  final Future<void> Function(String id)? onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = _fmtBytes(item.sizeBytes);
    final isActive = item.status == DownloadStatus.downloading || item.status == DownloadStatus.queued || item.status == DownloadStatus.paused;
    final statusText = switch (item.status) {
      DownloadStatus.queued => 'Queued',
      DownloadStatus.downloading => 'Downloading',
      DownloadStatus.paused => 'Paused',
      DownloadStatus.completed => 'Completed',
      DownloadStatus.failed => 'Failed',
    };

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      leading: _LeadIcon(icon: _iconFor(item.status)),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((item.subtitle ?? '').trim().isNotEmpty)
            Text(item.subtitle!.trim(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onSurfaceVariant)),
          Text('$statusText • $size', style: TextStyle(color: cs.onSurfaceVariant)),
          if (item.status == DownloadStatus.downloading || item.status == DownloadStatus.queued)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: item.status == DownloadStatus.queued ? null : item.progress.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: cs.surfaceContainerHigh.withValues(alpha: 1.0),
                ),
              ),
            ),
        ],
      ),
      trailing: isActive
          ? Wrap(
              spacing: 6,
              children: [
                if (item.status == DownloadStatus.downloading || item.status == DownloadStatus.queued)
                  IconButton(
                    tooltip: 'Pause',
                    icon: const Icon(Icons.pause_circle_outline),
                    onPressed: onPause == null ? null : () => onPause!(item.id),
                  ),
                if (item.status == DownloadStatus.paused || item.status == DownloadStatus.failed)
                  IconButton(
                    tooltip: 'Resume',
                    icon: const Icon(Icons.play_circle_outline),
                    onPressed: onResume == null ? null : () => onResume!(item.id),
                  ),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onRemove == null ? null : () => onRemove!(item.id),
                ),
              ],
            )
          : IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.delete_outline),
              onPressed: onRemove == null ? null : () => onRemove!(item.id),
            ),
    );
  }

  IconData _iconFor(DownloadStatus s) {
    return switch (s) {
      DownloadStatus.queued => Icons.schedule,
      DownloadStatus.downloading => Icons.download,
      DownloadStatus.paused => Icons.pause_circle_outline,
      DownloadStatus.completed => Icons.check_circle_outline,
      DownloadStatus.failed => Icons.error_outline,
    };
  }

  String _fmtBytes(int b) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double v = b.toDouble();
    int idx = 0;
    while (v >= 1024 && idx < units.length - 1) {
      v /= 1024;
      idx++;
    }
    return '${v.toStringAsFixed(v >= 100 ? 0 : v >= 10 ? 1 : 2)} ${units[idx]}';
  }
}

class _QualitySheet extends StatefulWidget {
  const _QualitySheet({required this.onPick});
  final ValueChanged<DownloadQuality> onPick;

  @override
  State<_QualitySheet> createState() => _QualitySheetState();
}

class _QualitySheetState extends State<_QualitySheet> {
  DownloadQuality _q = DownloadQuality.standard;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Download quality', style: TextStyle(fontWeight: FontWeight.w800))),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ],
        ),
        const SizedBox(height: 6),

        // Modern single-choice control
        SegmentedButton<DownloadQuality>(
          segments: const <ButtonSegment<DownloadQuality>>[
            ButtonSegment(value: DownloadQuality.standard, label: Text('Standard'), icon: Icon(Icons.speed)),
            ButtonSegment(value: DownloadQuality.high, label: Text('High'), icon: Icon(Icons.high_quality)),
          ],
          selected: <DownloadQuality>{_q},
          onSelectionChanged: (set) {
            if (set.isNotEmpty) {
              setState(() => _q = set.first);
            }
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Standard • Smaller size, faster downloads', style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text('High • More detail, larger size', style: TextStyle(color: cs.onSurfaceVariant)),
            ],
          ),
        ),

        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => widget.onPick(_q),
            icon: const Icon(Icons.check),
            label: const Text('Apply'),
          ),
        ),
      ],
    );
  }
}
