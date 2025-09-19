// lib/features/atlas/presentation/widgets/offline_packs.dart

import 'package:flutter/material.dart';

enum OfflinePackStatus {
  notDownloaded,
  downloading,
  paused,
  completed,
  failed,
}

class OfflinePackInfo {
  final String id;
  final String title;
  final String regionLabel;
  final int sizeMB;
  final int downloadedMB;
  final int tilesCount;
  final DateTime? updatedAt;
  final OfflinePackStatus status;

  const OfflinePackInfo({
    required this.id,
    required this.title,
    required this.regionLabel,
    required this.sizeMB,
    required this.downloadedMB,
    required this.tilesCount,
    required this.status,
    this.updatedAt,
  });

  double get progress =>
      sizeMB > 0 ? (downloadedMB.clamp(0, sizeMB) / sizeMB) : 0.0;
  String get progressText =>
      sizeMB > 0 ? '${((progress) * 100).toStringAsFixed(0)}%' : '0%';
  String get sizeText => '$sizeMB MB';
}

class OfflinePacksSection extends StatelessWidget {
  final List<OfflinePackInfo> packs;

  // High-level actions
  final VoidCallback? onRequestNewDownload;

  // Per-pack actions
  final void Function(OfflinePackInfo pack)? onDownload;
  final void Function(OfflinePackInfo pack)? onPause;
  final void Function(OfflinePackInfo pack)? onResume;
  final void Function(OfflinePackInfo pack)? onRemove;
  final void Function(OfflinePackInfo pack)? onOpen;
  final void Function(OfflinePackInfo pack)? onRetry;

  const OfflinePacksSection({
    super.key,
    required this.packs,
    this.onRequestNewDownload,
    this.onDownload,
    this.onPause,
    this.onResume,
    this.onRemove,
    this.onOpen,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (packs.isEmpty) {
      return _EmptyOfflinePacks(
        onRequestNewDownload: onRequestNewDownload,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                Icons.offline_pin_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Offline Packs',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              if (onRequestNewDownload != null)
                TextButton.icon(
                  onPressed: onRequestNewDownload,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Download maps'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Packs list
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: packs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final pack = packs[index];
            return _OfflinePackCard(
              pack: pack,
              onDownload: onDownload,
              onPause: onPause,
              onResume: onResume,
              onRemove: onRemove,
              onOpen: onOpen,
              onRetry: onRetry,
            );
          },
        ),
      ],
    );
  }
}

class _OfflinePackCard extends StatelessWidget {
  final OfflinePackInfo pack;
  final void Function(OfflinePackInfo pack)? onDownload;
  final void Function(OfflinePackInfo pack)? onPause;
  final void Function(OfflinePackInfo pack)? onResume;
  final void Function(OfflinePackInfo pack)? onRemove;
  final void Function(OfflinePackInfo pack)? onOpen;
  final void Function(OfflinePackInfo pack)? onRetry;

  const _OfflinePackCard({
    required this.pack,
    this.onDownload,
    this.onPause,
    this.onResume,
    this.onRemove,
    this.onOpen,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInProgress =
        pack.status == OfflinePackStatus.downloading || pack.status == OfflinePackStatus.paused;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Title row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.map_rounded,
                  size: 24,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TitleAndMeta(pack: pack),
                ),
                // Overflow menu or remove
                IconButton(
                  tooltip: 'Remove',
                  onPressed: onRemove != null ? () => onRemove!(pack) : null,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),

            // Progress
            if (isInProgress) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(6)),
                      child: LinearProgressIndicator(
                        value: pack.status == OfflinePackStatus.downloading ? pack.progress : null,
                        minHeight: 6,
                        backgroundColor:
                            theme.colorScheme.outline.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    pack.status == OfflinePackStatus.downloading ? pack.progressText : '—',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],

            // Actions
            const SizedBox(height: 10),
            _ActionsRow(
              pack: pack,
              onDownload: onDownload,
              onPause: onPause,
              onResume: onResume,
              onOpen: onOpen,
              onRetry: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleAndMeta extends StatelessWidget {
  final OfflinePackInfo pack;
  const _TitleAndMeta({required this.pack});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          pack.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),

        // Region and size
        Row(
          children: [
            Icon(
              Icons.place_outlined,
              size: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                pack.regionLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              pack.sizeText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),

        // Tiles and updated
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              Icons.grid_view_rounded,
              size: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 4),
            Text(
              '${pack.tilesCount} tiles',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.schedule_rounded,
              size: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 4),
            Text(
              pack.updatedAt != null ? _relativeTime(pack.updatedAt!) : '—',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _relativeTime(DateTime dt) {
    final now = DateTime.now();
    final d = now.difference(dt);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${(d.inDays / 7).floor()}w ago';
  }
}

class _ActionsRow extends StatelessWidget {
  final OfflinePackInfo pack;
  final void Function(OfflinePackInfo pack)? onDownload;
  final void Function(OfflinePackInfo pack)? onPause;
  final void Function(OfflinePackInfo pack)? onResume;
  final void Function(OfflinePackInfo pack)? onOpen;
  final void Function(OfflinePackInfo pack)? onRetry;

  const _ActionsRow({
    required this.pack,
    this.onDownload,
    this.onPause,
    this.onResume,
    this.onOpen,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    switch (pack.status) {
      case OfflinePackStatus.notDownloaded:
        return Row(
          children: [
            ElevatedButton.icon(
              onPressed: onDownload != null ? () => onDownload!(pack) : null,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Download'),
            ),
            const SizedBox(width: 8),
            Text(
              'Ready to download',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
          ],
        );

      case OfflinePackStatus.downloading:
        return Row(
          children: [
            OutlinedButton.icon(
              onPressed: onPause != null ? () => onPause!(pack) : null,
              icon: const Icon(Icons.pause_rounded, size: 18),
              label: const Text('Pause'),
            ),
            const SizedBox(width: 8),
            Text(
              '${pack.downloadedMB}/${pack.sizeMB} MB',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        );

      case OfflinePackStatus.paused:
        return Row(
          children: [
            ElevatedButton.icon(
              onPressed: onResume != null ? () => onResume!(pack) : null,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Resume'),
            ),
            const SizedBox(width: 8),
            Text(
              '${pack.downloadedMB}/${pack.sizeMB} MB paused',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
            ),
          ],
        );

      case OfflinePackStatus.completed:
        return Row(
          children: [
            TextButton.icon(
              onPressed: onOpen != null ? () => onOpen!(pack) : null,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open'),
            ),
            const SizedBox(width: 8),
            Text(
              'Downloaded • ${pack.sizeText}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
            ),
          ],
        );

      case OfflinePackStatus.failed:
        return Row(
          children: [
            OutlinedButton.icon(
              onPressed: onRetry != null ? () => onRetry!(pack) : null,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
            const SizedBox(width: 8),
            Text(
              'Download failed',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        );
    }
  }
}

class _EmptyOfflinePacks extends StatelessWidget {
  final VoidCallback? onRequestNewDownload;
  const _EmptyOfflinePacks({this.onRequestNewDownload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 32,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 8),
          Text(
            'No offline packs yet',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Download maps for regions to access them without internet',
            style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (onRequestNewDownload != null)
            ElevatedButton.icon(
              onPressed: onRequestNewDownload,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Download maps'),
            ),
        ],
      ),
    );
  }
}
