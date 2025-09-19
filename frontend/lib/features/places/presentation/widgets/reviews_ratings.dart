// lib/features/places/presentation/widgets/reviews_ratings.dart

import 'package:flutter/material.dart';

import '../../../../models/place.dart';

class ReviewItem {
  const ReviewItem({
    required this.id,
    required this.author,
    required this.rating,
    required this.text,
    required this.date, // DateTime
    this.source,
    this.helpfulCount = 0,
  });

  final String id;
  final String author;
  final double rating;
  final String text;
  final DateTime date;
  final String? source;
  final int helpfulCount;
}

/// Ratings + reviews section with:
/// - Summary (average, total count)
/// - Distribution bars
/// - Sort controls
/// - Review list with expand/collapse and actions
/// - Optional "Write a review" bottom sheet
class ReviewsRatings extends StatefulWidget {
  const ReviewsRatings({
    super.key,
    this.place,
    this.averageRating,
    this.totalCount,
    this.distribution, // Map<int,int> for 1..5 stars
    this.reviews = const <ReviewItem>[],
    this.sortBy = 'recent', // recent | highest | lowest | helpful
    this.onSortChanged,
    this.onHelpful, // Future<void> Function(ReviewItem)
    this.onReport, // Future<void> Function(ReviewItem)
    this.onSubmitReview, // Future<void> Function(double rating, String text)
    this.enableWrite = false,
    this.title = 'Reviews & ratings',
  });

  /// Convenience factory to wire from Place fields when available.
  factory ReviewsRatings.fromPlace(
    Place p, {
    Key? key,
    Map<int, int>? distribution,
    List<ReviewItem> reviews = const <ReviewItem>[],
    String sortBy = 'recent',
    Future<void> Function(String sortBy)? onSortChanged,
    Future<void> Function(ReviewItem item)? onHelpful,
    Future<void> Function(ReviewItem item)? onReport,
    Future<void> Function(double rating, String text)? onSubmitReview,
    bool enableWrite = false,
    String title = 'Reviews & ratings',
  }) {
    // Read from toJson() map to avoid compile-time coupling to specific getters.
    Map<String, dynamic> m = const <String, dynamic>{};
    try {
      final dyn = p as dynamic;
      final j = dyn.toJson();
      if (j is Map<String, dynamic>) m = j;
    } catch (_) {
      // Ignore if model doesn't expose toJson
    } // Using JSON maps is a robust way to read optional fields across varying models. [web:5858]

    num? pickNum(List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v is num) return v;
        if (v is String) {
          final n = num.tryParse(v);
          if (n != null) return n;
        }
      }
      return null;
    }

    final avg = pickNum(['rating', 'avgRating'])?.toDouble();
    final total = pickNum(['reviewsCount', 'reviewCount'])?.toInt();

    return ReviewsRatings(
      key: key,
      place: p,
      averageRating: avg,
      totalCount: total,
      distribution: distribution,
      reviews: reviews,
      sortBy: sortBy,
      onSortChanged: onSortChanged,
      onHelpful: onHelpful,
      onReport: onReport,
      onSubmitReview: onSubmitReview,
      enableWrite: enableWrite,
      title: title,
    );
  }

  final Place? place;
  final double? averageRating;
  final int? totalCount;
  final Map<int, int>? distribution;
  final List<ReviewItem> reviews;

  final String sortBy;
  final Future<void> Function(String sortBy)? onSortChanged;

  final Future<void> Function(ReviewItem item)? onHelpful;
  final Future<void> Function(ReviewItem item)? onReport;

  final Future<void> Function(double rating, String text)? onSubmitReview;
  final bool enableWrite;

  final String title;

  @override
  State<ReviewsRatings> createState() => _ReviewsRatingsState();
}

class _ReviewsRatingsState extends State<ReviewsRatings> {
  late String _sortBy;

  @override
  void initState() {
    super.initState();
    _sortBy = widget.sortBy;
  }

  @override
  Widget build(BuildContext context) {
    final avg = (widget.averageRating ?? _avgFrom(widget.reviews))?.toStringAsFixed(1) ?? '-';
    final count = widget.totalCount ?? widget.reviews.length;
    final dist = widget.distribution ?? _buildDist(widget.reviews);

    final sorted = [...widget.reviews];
    _applySort(sorted, _sortBy);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header + Write
            Row(
              children: [
                Expanded(
                  child: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                if (widget.enableWrite && widget.onSubmitReview != null)
                  OutlinedButton.icon(
                    onPressed: () => _openWriteSheet(context),
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text('Write a review'),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // Summary
            Row(
              children: [
                _BigRating(avg: avg),
                const SizedBox(width: 12),
                Expanded(
                  child: _Distribution(dist: dist, total: count),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Sort controls
            Row(
              children: [
                const Icon(Icons.sort, size: 18, color: Colors.black54),
                const SizedBox(width: 6),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _sortBy,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'recent', child: Text('Most recent')),
                      DropdownMenuItem(value: 'highest', child: Text('Highest rated')),
                      DropdownMenuItem(value: 'lowest', child: Text('Lowest rated')),
                      DropdownMenuItem(value: 'helpful', child: Text('Most helpful')),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      setState(() => _sortBy = v);
                      if (widget.onSortChanged != null) {
                        await widget.onSortChanged!(v);
                      }
                    },
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Reviews list
            if (sorted.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('No reviews yet'),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sorted.length,
                separatorBuilder: (_, __) => const Divider(height: 16),
                itemBuilder: (context, i) {
                  final r = sorted[i];
                  return _ReviewTile(
                    item: r,
                    onHelpful: widget.onHelpful,
                    onReport: widget.onReport,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Map<int, int> _buildDist(List<ReviewItem> items) {
    final m = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final r in items) {
      final k = r.rating.clamp(1, 5).round();
      m[k] = (m[k] ?? 0) + 1;
    }
    return m;
  }

  double? _avgFrom(List<ReviewItem> items) {
    if (items.isEmpty) return null;
    final s = items.fold<double>(0, (a, b) => a + b.rating);
    return s / items.length;
  }

  void _applySort(List<ReviewItem> list, String by) {
    switch (by) {
      case 'highest':
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'lowest':
        list.sort((a, b) => a.rating.compareTo(b.rating));
        break;
      case 'helpful':
        list.sort((a, b) => b.helpfulCount.compareTo(a.helpfulCount));
        break;
      case 'recent':
      default:
        list.sort((a, b) => b.date.compareTo(a.date));
    }
  }

  Future<void> _openWriteSheet(BuildContext context) async {
    final res = await showModalBottomSheet<_ReviewDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => const _WriteReviewSheet(),
    );
    if (res == null) return;
    if (widget.onSubmitReview != null) {
      await widget.onSubmitReview!(res.rating, res.text);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted')),
        );
      }
    }
  }
}

class _BigRating extends StatelessWidget {
  const _BigRating({required this.avg});
  final String avg;

  @override
  Widget build(BuildContext context) {
    final v = double.tryParse(avg) ?? 0.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(avg, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 28)),
        const SizedBox(height: 4),
        _Stars(rating: v),
      ],
    );
  }
}

class _Distribution extends StatelessWidget {
  const _Distribution({required this.dist, required this.total});
  final Map<int, int> dist;
  final int total;

  @override
  Widget build(BuildContext context) {
    final rows = [5, 4, 3, 2, 1];
    return Column(
      children: rows.map((star) {
        final count = dist[star] ?? 0;
        final ratio = total == 0 ? 0.0 : count / total;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(width: 24, child: Text('$star', textAlign: TextAlign.right)),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: ratio.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.black12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 40, child: Text('$count')),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ReviewTile extends StatefulWidget {
  const _ReviewTile({required this.item, this.onHelpful, this.onReport});
  final ReviewItem item;
  final Future<void> Function(ReviewItem item)? onHelpful;
  final Future<void> Function(ReviewItem item)? onReport;

  @override
  State<_ReviewTile> createState() => _ReviewTileState();
}

class _ReviewTileState extends State<_ReviewTile> with TickerProviderStateMixin {
  bool _open = false;
  int _helpful = 0;

  @override
  void initState() {
    super.initState();
    _helpful = widget.item.helpfulCount;
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.item;
    final initials = _initials(i.author);
    final date = _fmtDate(i.date);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text(initials)),
      title: Row(
        children: [
          Expanded(child: Text(i.author, maxLines: 1, overflow: TextOverflow.ellipsis)),
          _Stars(rating: i.rating),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text('$date${i.source != null ? ' · ${i.source}' : ''}', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 6),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: Text(
              i.text,
              maxLines: _open ? null : 4,
              overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
              style: const TextStyle(height: 1.35),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _open = !_open),
              icon: Icon(_open ? Icons.expand_less : Icons.expand_more),
              label: Text(_open ? 'Show less' : 'Show more'),
            ),
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  setState(() => _helpful += 1);
                  try {
                    await widget.onHelpful?.call(i);
                  } catch (_) {
                    if (mounted) setState(() => _helpful = (_helpful - 1).clamp(0, 1 << 31));
                  }
                },
                icon: const Icon(Icons.thumb_up_alt_outlined, size: 16),
                label: Text('Helpful ($_helpful)'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: widget.onReport == null ? null : () async => widget.onReport!.call(i),
                child: const Text('Report'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first;
    final second = parts.length > 1 ? parts[1] : '';
    final a = first.isNotEmpty ? first[0].toUpperCase() : ''; // Uppercase first letter of first word. [web:6060]
    final b = second.isNotEmpty ? second[0].toUpperCase() : ''; // Uppercase first letter of second word if present. [web:6060]
    final res = '$a$b';
    return res.isEmpty ? '?' : res;
  }

  String _fmtDate(DateTime dt) {
    final now = DateTime.now();
    final d = now.difference(dt);
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 30) return '${d.inDays}d ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating});
  final double rating;

  @override
  Widget build(BuildContext context) {
    final icons = <IconData>[];
    for (var i = 1; i <= 5; i++) {
      final icon = rating >= i - 0.25
          ? Icons.star
          : (rating >= i - 0.75 ? Icons.star_half : Icons.star_border);
      icons.add(icon);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: icons.map((ic) => Icon(ic, size: 16, color: Colors.amber)).toList(),
    );
  }
}

class _ReviewDraft {
  const _ReviewDraft({required this.rating, required this.text});
  final double rating;
  final String text;
}

class _WriteReviewSheet extends StatefulWidget {
  const _WriteReviewSheet();

  @override
  State<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<_WriteReviewSheet> {
  double _rating = 5.0;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add your review text')),
      );
      return;
    }
    Navigator.of(context).maybePop(_ReviewDraft(rating: _rating, text: text));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Write a review', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 8),
          // Star selector
          Row(
            children: List.generate(5, (i) {
              final idx = i + 1;
              return IconButton(
                onPressed: () => setState(() => _rating = idx.toDouble()),
                icon: Icon(idx <= _rating ? Icons.star : Icons.star_border, color: Colors.amber),
              );
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Share details of your experience',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.send),
              label: const Text('Submit'),
            ),
          ),
        ],
      ),
    );
  }
}
