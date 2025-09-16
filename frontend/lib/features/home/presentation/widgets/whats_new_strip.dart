// lib/features/home/presentation/widgets/whats_new_strip.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../navigation/route_names.dart';

class WhatsNewStrip extends StatelessWidget {
  final List<Map<String, dynamic>> newsItems;

  const WhatsNewStrip({
    super.key,
    required this.newsItems,
  });

  @override
  Widget build(BuildContext context) {
    if (newsItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'What\'s New',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: newsItems.length,
            itemBuilder: (context, index) {
              final newsItem = newsItems[index];
              final title = newsItem['title'] as String? ?? 'News Update';
              final summary = newsItem['summary'] as String? ?? '';
              final type = newsItem['type'] as String? ?? 'general';
              final id = newsItem['id'] as String? ?? '';
              final date = newsItem['date'] as String? ?? '';
              
              return _NewsCard(
                title: title,
                summary: summary,
                type: type,
                date: date,
                onTap: () {
                  if (id.isNotEmpty) {
                    // Navigate to news detail or appropriate screen
                    context.pushNamed(RouteNames.atlas);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NewsCard extends StatelessWidget {
  final String title;
  final String summary;
  final String type;
  final String date;
  final VoidCallback onTap;

  const _NewsCard({
    required this.title,
    required this.summary,
    required this.type,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _getTypeColor(type).withValues(alpha: 0.1),
                _getTypeColor(type).withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getTypeColor(type).withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getTypeColor(type),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getTypeIcon(type),
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getTypeLabel(type),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (date.isNotEmpty)
                    Text(
                      _formatDate(date),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              if (summary.isNotEmpty)
                Text(
                  summary,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'feature':
        return Colors.blue;
      case 'update':
        return Colors.green;
      case 'event':
        return Colors.orange;
      case 'travel':
        return Colors.purple;
      case 'offer':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'feature':
        return Icons.new_releases_outlined;
      case 'update':
        return Icons.system_update_outlined;
      case 'event':
        return Icons.event_outlined;
      case 'travel':
        return Icons.flight_takeoff_outlined;
      case 'offer':
        return Icons.local_offer_outlined;
      default:
        return Icons.info_outlined;
    }
  }

  String _getTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'feature':
        return 'NEW';
      case 'update':
        return 'UPDATE';
      case 'event':
        return 'EVENT';
      case 'travel':
        return 'TRAVEL';
      case 'offer':
        return 'OFFER';
      default:
        return 'NEWS';
    }
  }

  String _formatDate(String date) {
    try {
      final dateTime = DateTime.tryParse(date);
      if (dateTime != null) {
        final now = DateTime.now();
        final difference = now.difference(dateTime).inDays;
        
        if (difference == 0) {
          return 'Today';
        } else if (difference == 1) {
          return 'Yesterday';
        } else if (difference < 7) {
          return '${difference}d ago';
        } else {
          return '${(difference / 7).floor()}w ago';
        }
      }
      return date;
    } catch (e) {
      return date;
    }
  }
}
