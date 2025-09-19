// lib/features/trails/presentation/widgets/post_composer.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../trails/data/trail_location_api.dart' show GeoPoint;

/// Immutable draft model emitted on submit.
class PostDraft {
  const PostDraft({
    required this.text,
    this.photoUris = const <Uri>[],
    this.tags = const <String>[],
    this.difficulty, // easy | moderate | hard
    this.rating, // 1..5 (double for steps like 0.5 if needed)
    this.location,
    this.shareToFeed = true,
    this.shareToGroup = false,
  });

  final String text;
  final List<Uri> photoUris;
  final List<String> tags;
  final String? difficulty;
  final double? rating;
  final GeoPoint? location;
  final bool shareToFeed;
  final bool shareToGroup;

  PostDraft copyWith({
    String? text,
    List<Uri>? photoUris,
    List<String>? tags,
    String? difficulty,
    double? rating,
    GeoPoint? location,
    bool? shareToFeed,
    bool? shareToGroup,
  }) {
    return PostDraft(
      text: text ?? this.text,
      photoUris: photoUris ?? this.photoUris,
      tags: tags ?? this.tags,
      difficulty: difficulty ?? this.difficulty,
      rating: rating ?? this.rating,
      location: location ?? this.location,
      shareToFeed: shareToFeed ?? this.shareToFeed,
      shareToGroup: shareToGroup ?? this.shareToGroup,
    );
  }
}

/// A UI-only post composer for trails: text + photos + tags + meta, with clean callbacks.
class PostComposer extends StatefulWidget {
  const PostComposer({
    super.key,
    this.initialText = '',
    this.initialTags = const <String>[],
    this.initialDifficulty,
    this.initialRating,
    this.initialLocation,
    this.shareToFeed = true,
    this.shareToGroup = false,

    // Pickers (provide implementations using image_picker or similar)
    this.onPickFromCamera, // Future<Uri?> Function()
    this.onPickFromGallery, // Future<List<Uri>?> Function() for multi-pick if supported
    this.onPickLocation, // Future<GeoPoint?> Function()

    // Submit
    required this.onSubmit, // Future<void> Function(PostDraft draft)
    this.onCancel,
  });

  final String initialText;
  final List<String> initialTags;
  final String? initialDifficulty;
  final double? initialRating;
  final GeoPoint? initialLocation;

  final bool shareToFeed;
  final bool shareToGroup;

  final Future<Uri?> Function()? onPickFromCamera;
  final Future<List<Uri>?> Function()? onPickFromGallery;
  final Future<GeoPoint?> Function()? onPickLocation;

  final Future<void> Function(PostDraft draft) onSubmit;
  final VoidCallback? onCancel;

  @override
  State<PostComposer> createState() => _PostComposerState();
}

class _PostComposerState extends State<PostComposer> {
  final _text = TextEditingController();
  final _tagCtrl = TextEditingController();
  final _focusText = FocusNode();

  final List<Uri> _photos = <Uri>[];
  final List<String> _tags = <String>[];

  String? _difficulty;
  double? _rating;
  GeoPoint? _location;

  bool _shareToFeed = true;
  bool _shareToGroup = false;
  bool _busy = false;

  static const _maxTextLength = 1000; // generous cap for posts

  @override
  void initState() {
    super.initState();
    _text.text = widget.initialText;
    _tags.addAll(widget.initialTags);
    _difficulty = widget.initialDifficulty;
    _rating = widget.initialRating;
    _location = widget.initialLocation;
    _shareToFeed = widget.shareToFeed;
    _shareToGroup = widget.shareToGroup;
  }

  @override
  void dispose() {
    _text.dispose();
    _tagCtrl.dispose();
    _focusText.dispose();
    super.dispose();
  }

  Future<void> _pickFromCamera() async {
    if (widget.onPickFromCamera == null) return;
    final uri = await widget.onPickFromCamera!.call();
    if (uri != null && mounted) {
      setState(() => _photos.add(uri));
    }
  }

  Future<void> _pickFromGallery() async {
    if (widget.onPickFromGallery == null) return;
    final uris = await widget.onPickFromGallery!.call();
    if ((uris ?? const <Uri>[]).isNotEmpty && mounted) {
      setState(() => _photos.addAll(uris!));
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  void _addTag() {
    final raw = _tagCtrl.text.trim();
    if (raw.isEmpty) return;
    if (!_tags.contains(raw)) {
      setState(() => _tags.add(raw));
    }
    _tagCtrl.clear();
  }

  void _removeTag(String t) {
    setState(() => _tags.remove(t));
  }

  Future<void> _pickLocation() async {
    if (widget.onPickLocation == null) return;
    final p = await widget.onPickLocation!.call();
    if (mounted) setState(() => _location = p);
  }

  Future<void> _submit() async {
    if (_busy) return;
    final text = _text.text.trim();
    if (text.isEmpty && _photos.isEmpty) {
      // nothing to post
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add text or photos to post')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final draft = PostDraft(
        text: text,
        photoUris: List<Uri>.from(_photos),
        tags: List<String>.from(_tags),
        difficulty: _difficulty,
        rating: _rating,
        location: _location,
        shareToFeed: _shareToFeed,
        shareToGroup: _shareToGroup,
      );
      await widget.onSubmit(draft);
      if (mounted) Navigator.maybePop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New post'),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: widget.onCancel ?? () => Navigator.maybePop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
            label: const Text('Post'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            // Text field
            const _SectionHeader(label: 'Description'),
            TextField(
              controller: _text,
              focusNode: _focusText,
              minLines: 3,
              maxLines: 7,
              maxLength: _maxTextLength, // applies input limit and (hidden) counter [16]
              decoration: InputDecoration(
                hintText: 'Share details about this trail…',
                filled: true,
                fillColor: cs.surfaceContainerHigh.withValues(alpha: 1.0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                // Hide the default maxLength counter for a cleaner UI [7][13]
                counterText: '',
              ),
            ),

            const SizedBox(height: 12),

            // Photos
            const _SectionHeader(label: 'Photos'),
            Row(
              children: [
                if (widget.onPickFromCamera != null)
                  _IconAction(
                    icon: Icons.photo_camera_outlined,
                    label: 'Camera',
                    onTap: _busy ? null : _pickFromCamera,
                  ),
                const SizedBox(width: 8),
                if (widget.onPickFromGallery != null)
                  _IconAction(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    onTap: _busy ? null : _pickFromGallery,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_photos.isNotEmpty)
              _PhotoGrid(
                uris: _photos,
                onRemove: _busy ? null : _removePhoto,
              ), // GridView is ideal for a small preview gallery with fixed columns [12][15]

            const SizedBox(height: 12),

            // Tags
            const _SectionHeader(label: 'Tags'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagCtrl,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addTag(),
                    decoration: InputDecoration(
                      hintText: 'Add a tag and press Enter',
                      isDense: true,
                      filled: true,
                      fillColor: cs.surfaceContainerHigh.withValues(alpha: 1.0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _addTag,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags
                    .map((t) => Chip(
                          label: Text(t),
                          onDeleted: _busy ? null : () => _removeTag(t),
                          backgroundColor: cs.surfaceContainerHigh.withValues(alpha: 1.0),
                        ))
                    .toList(growable: false),
              ),
            ],

            const SizedBox(height: 12),

            // Difficulty & Rating
            const _SectionHeader(label: 'Trail details'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ChipToggle(
                  label: 'Easy',
                  selected: _difficulty == 'easy',
                  onTap: () => setState(() => _difficulty = _difficulty == 'easy' ? null : 'easy'),
                ),
                _ChipToggle(
                  label: 'Moderate',
                  selected: _difficulty == 'moderate',
                  onTap: () => setState(() => _difficulty = _difficulty == 'moderate' ? null : 'moderate'),
                ),
                _ChipToggle(
                  label: 'Hard',
                  selected: _difficulty == 'hard',
                  onTap: () => setState(() => _difficulty = _difficulty == 'hard' ? null : 'hard'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.star_rate_rounded, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: (_rating ?? 3.0).clamp(1.0, 5.0),
                    onChanged: (v) => setState(() => _rating = v),
                    min: 1.0,
                    max: 5.0,
                    divisions: 8, // quarter-star steps if desired
                    label: (_rating ?? 3.0).toStringAsFixed(1),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Location
            const _SectionHeader(label: 'Location'),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _location == null
                        ? 'No location attached'
                        : '${_location!.lat.toStringAsFixed(5)}, ${_location!.lng.toStringAsFixed(5)}',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickLocation,
                  icon: const Icon(Icons.my_location),
                  label: Text(_location == null ? 'Add location' : 'Change'),
                ),
                if (_location != null) const SizedBox(width: 8),
                if (_location != null)
                  IconButton(
                    tooltip: 'Remove',
                    onPressed: _busy ? null : () => setState(() => _location = null),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Share toggles
            const _SectionHeader(label: 'Share'),
            SwitchListTile.adaptive(
              dense: true,
              title: const Text('Share to feed'),
              value: _shareToFeed,
              onChanged: (v) => setState(() => _shareToFeed = v),
            ),
            SwitchListTile.adaptive(
              dense: true,
              title: const Text('Share to group chat'),
              value: _shareToGroup,
              onChanged: (v) => setState(() => _shareToGroup = v),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.uris, required this.onRemove});

  final List<Uri> uris;
  final void Function(int index)? onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final crossAxisCount = MediaQuery.of(context).size.width >= 520 ? 4 : 3;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: List.generate(uris.length, (i) {
        final u = uris[i];
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant),
                image: DecorationImage(
                  image: NetworkImage(u.toString()),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              right: 4,
              top: 4,
              child: Material(
                color: Colors.black.withValues(alpha: 0.28),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove == null ? null : () => onRemove!(i),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.primary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: cs.primary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _ChipToggle extends StatelessWidget {
  const _ChipToggle({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cs.primary.withValues(alpha: 0.24) : cs.surfaceContainerHigh.withValues(alpha: 1.0),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? cs.primary : cs.outlineVariant),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? cs.primary : cs.onSurfaceVariant,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
    );
  }
}
