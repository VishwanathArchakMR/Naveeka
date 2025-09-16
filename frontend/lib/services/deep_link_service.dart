// lib/services/deep_link_service.dart

import 'dart:async';

/// Supported deep link kinds used across the app routes.
enum DeepLinkKind {
  place,
  landmark,
  restaurant,
  hotel,
  flight,
  train,
  bus,
  trainStation,
  cab,
  user,
  chat,
  review,
  trail,
  post,
  trailPost,
  tripGroup,
  favorite,
  history,
  message,
  unknown,
}

/// A parsed deep link target with type-safe fields for navigation layers.
class DeepLinkTarget {
  const DeepLinkTarget({
    required this.kind,
    required this.id,
    this.subId,
    this.params = const <String, String>{},
    this.original,
  });

  final DeepLinkKind kind;
  final String id;
  final String? subId; // optional secondary identifier (e.g., commentId/messageId)
  final Map<String, String> params; // preserved query params (utm/ref/etc.)
  final Uri? original; // the original URI received (useful for logging/analytics)

  @override
  String toString() => 'DeepLinkTarget(kind: $kind, id: $id, subId: $subId, params: $params)';
}

/// Centralized parser/builder for deep links.
/// - No external dependencies: adapter-friendly for uni_links or Firebase Dynamic Links.
/// - Accepts: custom scheme (e.g., myapp://place/123), https://host/path, and dynamic link wrappers.
class DeepLinkService {
  const DeepLinkService({
    this.appScheme = 'myapp',
    this.webHost = 'example.com',
  });

  /// Custom app scheme for native links (configure to match Android/iOS setup).
  final String appScheme;

  /// Canonical website host for universal links and sharing.
  final String webHost;

  /// Parse a URL string into a DeepLinkTarget, handling nested dynamic links when present.
  DeepLinkTarget? parse(String url) {
    if (url.trim().isEmpty) return null;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    return parseUri(uri);
  }

  /// Parse a Uri into a DeepLinkTarget.
  /// Handles:
  /// - App scheme (myapp://place/ID)
  /// - HTTPS (https://example.com/place/ID)
  /// - Firebase Dynamic Links (https://*.page.link/... ?link=https://example.com/... or deep_link_id)
  DeepLinkTarget? parseUri(Uri uri) {
    // 1) Unwrap Firebase Dynamic Links if present: ?link=... or ?deep_link_id=...
    final nested = _extractDynamicDeepLink(uri);
    if (nested != null) {
      return parseUri(nested);
    }

    // 2) Accept only custom scheme or http(s)
    if (uri.scheme.isEmpty) return null;
    if (uri.scheme != appScheme && uri.scheme != 'https' && uri.scheme != 'http') return null;

    // 3) Normalize path segments (ignore leading/trailing slashes)
    final segs = uri.pathSegments.where((s) => s.trim().isNotEmpty).toList(growable: false);
    if (segs.isEmpty) return null;

    // 4) Collect query parameters (keep as string map)
    final qp = <String, String>{};
    uri.queryParametersAll.forEach((k, v) {
      if (v.isEmpty) return;
      qp[k] = v.last.toString();
    });

    // 5) Map known patterns to DeepLinkKind
    // Primary formats:
    //   /place/:id
    //   /landmark/:id
    //   /restaurant/:id
    //   /hotel/:id
    //   /flight/:id
    //   /train/:id
    //   /bus/:id
    //   /station/:id  or /train-station/:id
    //   /cab/:id
    //   /user/:id
    //   /chat/:id      (optionally /chat/:id/message/:messageId)
    //   /review/:id
    //   /trail/:id
    //   /post/:id
    //   /trail-post/:id
    //   /trip/:id   or /group/:id
    // Short aliases:
    //   /p/:id (place) /l/:id (landmark) /r/:id (restaurant) /h/:id (hotel)
    //   /u/:id (user)  /c/:id (chat)      /t/:id (trail)     /tp/:id (trail-post)
    final first = segs.isNotEmpty ? segs[0].toLowerCase() : '';
    String id(String? maybe) => (maybe ?? '').toString();

    // Helper to build a target.
    DeepLinkTarget mk(DeepLinkKind kind, String primary, {String? sub}) {
      return DeepLinkTarget(kind: kind, id: primary, subId: sub, params: qp, original: uri);
    }

    // Chat sub-route check: /chat/:chatId/message/:messageId
    if (first == 'chat' && segs.length >= 2) {
      final chatId = segs.length >= 2 ? segs[1] : '';
      String? messageId;
      if (segs.length >= 4 && segs[2].toLowerCase() == 'message') {
        messageId = segs[3];
      }
      return mk(DeepLinkKind.chat, id(chatId), sub: messageId);
    }

    // Station variations
    if ((first == 'station' || first == 'train-station') && segs.length >= 2) {
      return mk(DeepLinkKind.trainStation, id(segs.length >= 2 ? segs[1] : ''));
    }

    // Trip group variations
    if ((first == 'trip' || first == 'group') && segs.length >= 2) {
      return mk(DeepLinkKind.tripGroup, id(segs.length >= 2 ? segs[1] : ''));
    }

    // Short aliases first
    if (first == 'p' && segs.length >= 2) return mk(DeepLinkKind.place, id(segs.length >= 2 ? segs[1] : ''));
    if (first == 'l' && segs.length >= 2) return mk(DeepLinkKind.landmark, id(segs.length >= 2 ? segs[1] : ''));
    if (first == 'r' && segs.length >= 2) return mk(DeepLinkKind.restaurant, id(segs.length >= 2 ? segs[1] : ''));
    if (first == 'h' && segs.length >= 2) return mk(DeepLinkKind.hotel, id(segs.length >= 2 ? segs[1] : ''));
    if (first == 'u' && segs.length >= 2) return mk(DeepLinkKind.user, id(segs.length >= 2 ? segs[1] : ''));
    if (first == 'c' && segs.length >= 2) return mk(DeepLinkKind.chat, id(segs.length >= 2 ? segs[1] : ''));
    if (first == 't' && segs.length >= 2) return mk(DeepLinkKind.trail, id(segs.length >= 2 ? segs[1] : ''));
    if (first == 'tp' && segs.length >= 2) return mk(DeepLinkKind.trailPost, id(segs.length >= 2 ? segs[1] : ''));

    // Long names
    if (first == 'place' && segs.length >= 2) return mk(DeepLinkKind.place, id(segs.length >= 2 ? segs[1] : ''));
    if (first == 'landmark' && segs.length >= 2) return mk(DeepLinkKind.landmark, id(segs.length >= 2 ? segs[1] : ''));
    if (first == 'restaurant' && segs.length >= 2) return mk(DeepLinkKind.restaurant, id(segs.length >= 2 ? segs[1] : ''));
    if (first == 'hotel' && segs.length >= 2) return mk(DeepLinkKind.hotel, id(segs.length >= 2 ? segs[1] : ''));
    if (first == 'flight' && segs.length >= 2) return mk(DeepLinkKind.flight, id(segs.length >= 2 ? segs[1] : ''));
    if (first == 'train' && segs.length >= 2) return mk(DeepLinkKind.train, id(segs.length >= 2 ? segs[1] : ''));
    if (first == 'bus' && segs.length >= 2) return mk(DeepLinkKind.bus, id(segs.length >= 2 ? segs[1] : ''));
    if (first == 'cab' && segs.length >= 2) return mk(DeepLinkKind.cab, id(segs.length >= 2 ? segs[1] : ''));
    if (first == 'user' && segs.length >= 2) return mk(DeepLinkKind.user, id(segs.length >= 2 ? segs[1] : ''));
    if (first == 'review' && segs.length >= 2) return mk(DeepLinkKind.review, id(segs.length >= 2 ? segs[1] : ''));
    if (first == 'trail' && segs.length >= 2) return mk(DeepLinkKind.trail, id(segs.length >= 2 ? segs[1] : ''));
    if (first == 'post' && segs.length >= 2) return mk(DeepLinkKind.post, id(segs.length >= 2 ? segs[1] : ''));
    if (first == 'trail-post' && segs.length >= 2) return mk(DeepLinkKind.trailPost, id(segs.length >= 2 ? segs[1] : ''));
    if (first == 'favorite' && segs.length >= 2) return mk(DeepLinkKind.favorite, id(segs.length >= 2 ? segs[1] : ''));
    if (first == 'history' && segs.length >= 2) return mk(DeepLinkKind.history, id(segs.length >= 2 ? segs[1] : ''));
    if (first == 'message' && segs.length >= 2) return mk(DeepLinkKind.message, id(segs.length >= 2 ? segs[1] : ''));

    // Fallback: unknown
    return DeepLinkTarget(kind: DeepLinkKind.unknown, id: uri.toString(), params: qp, original: uri);
  }

  /// Build an app-scheme link (myapp://segment/id?params) suitable for native dispatch.
  Uri buildAppLink(DeepLinkTarget t) {
    final path = _pathFor(t);
    return Uri(
      scheme: appScheme,
      host: '', // host is typically empty for custom schemes
      path: path,
      queryParameters: t.params.isEmpty ? null : t.params,
    );
  }

  /// Build a canonical HTTPS link for sharing (https://example.com/segment/id?params).
  Uri buildWebLink(DeepLinkTarget t) {
    final path = _pathFor(t);
    return Uri(
      scheme: 'https',
      host: webHost,
      path: path,
      queryParameters: t.params.isEmpty ? null : t.params,
    );
  }

  /// Adapter utility: connect a stream of incoming URIs to parsed targets.
  /// For uni_links, pass `uriLinkStream` (or `linkStream`) here and handle targets in onTarget.
  StreamSubscription<Uri> bindUriStream(
    Stream<Uri> uriStream, {
    required void Function(DeepLinkTarget target) onTarget,
  }) {
    return uriStream.listen((uri) {
      final t = parseUri(uri);
      if (t != null) onTarget(t);
    });
  }

  // ----- internal helpers -----

  // Generates a normalized path for a target (no leading slash).
  String _pathFor(DeepLinkTarget t) {
    switch (t.kind) {
      case DeepLinkKind.place:
        return 'place/${t.id}';
      case DeepLinkKind.landmark:
        return 'landmark/${t.id}';
      case DeepLinkKind.restaurant:
        return 'restaurant/${t.id}';
      case DeepLinkKind.hotel:
        return 'hotel/${t.id}';
      case DeepLinkKind.flight:
        return 'flight/${t.id}';
      case DeepLinkKind.train:
        return 'train/${t.id}';
      case DeepLinkKind.bus:
        return 'bus/${t.id}';
      case DeepLinkKind.trainStation:
        return 'train-station/${t.id}';
      case DeepLinkKind.cab:
        return 'cab/${t.id}';
      case DeepLinkKind.user:
        return 'user/${t.id}';
      case DeepLinkKind.chat:
        if (t.subId != null && t.subId!.isNotEmpty) {
          return 'chat/${t.id}/message/${t.subId}';
        }
        return 'chat/${t.id}';
      case DeepLinkKind.review:
        return 'review/${t.id}';
      case DeepLinkKind.trail:
        return 'trail/${t.id}';
      case DeepLinkKind.post:
        return 'post/${t.id}';
      case DeepLinkKind.trailPost:
        return 'trail-post/${t.id}';
      case DeepLinkKind.tripGroup:
        return 'trip/${t.id}';
      case DeepLinkKind.favorite:
        return 'favorite/${t.id}';
      case DeepLinkKind.history:
        return 'history/${t.id}';
      case DeepLinkKind.message:
        return 'message/${t.id}';
      case DeepLinkKind.unknown:
        return ''; // caller should handle unknown
    }
  }

  // Unwrap Firebase Dynamic Links by extracting the inner "link" or "deep_link_id".
  Uri? _extractDynamicDeepLink(Uri uri) {
    // Check common param keys used by Firebase Dynamic Links.
    final linkParam = uri.queryParameters['link'];
    if (linkParam != null && linkParam.trim().isNotEmpty) {
      final nested = Uri.tryParse(linkParam.trim());
      if (nested != null) return nested;
    }
    final deepId = uri.queryParameters['deep_link_id'];
    if (deepId != null && deepId.trim().isNotEmpty) {
      final nested = Uri.tryParse(deepId.trim());
      if (nested != null) return nested;
    }
    return null;
  }
}
