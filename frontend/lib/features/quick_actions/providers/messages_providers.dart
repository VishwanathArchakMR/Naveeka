// lib/features/quick_actions/providers/messages_providers.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Local minimal types when the UI widget file doesn't export them.
@immutable
class GeoPoint {
  final double lat;
  final double lng;
  const GeoPoint(this.lat, this.lng);
}

@immutable
class ShareLocationRequest {
  final double lat;
  final double lng;
  final String? label;
  const ShareLocationRequest({required this.lat, required this.lng, this.label});
}

/// ---------------- Domain models ----------------

@immutable
class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.title,
    required this.lastMessageAt,
    this.lastMessageText,
    this.lastMessageSender,
    this.unreadCount = 0,
    this.isMuted = false,
    this.isPinned = false,
    this.isTyping = false,
    this.participantAvatars = const <String>[],
    this.hasAttachments = false,
  });

  final String id;
  final String title;
  final DateTime lastMessageAt;

  final String? lastMessageText;
  final String? lastMessageSender;
  final int unreadCount;

  final bool isMuted;
  final bool isPinned;
  final bool isTyping;

  final List<String> participantAvatars;
  final bool hasAttachments;

  ConversationSummary copyWith({
    String? title,
    DateTime? lastMessageAt,
    String? lastMessageText,
    String? lastMessageSender,
    int? unreadCount,
    bool? isMuted,
    bool? isPinned,
    bool? isTyping,
    List<String>? participantAvatars,
    bool? hasAttachments,
  }) {
    return ConversationSummary(
      id: id,
      title: title ?? this.title,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageSender: lastMessageSender ?? this.lastMessageSender,
      unreadCount: unreadCount ?? this.unreadCount,
      isMuted: isMuted ?? this.isMuted,
      isPinned: isPinned ?? this.isPinned,
      isTyping: isTyping ?? this.isTyping,
      participantAvatars: participantAvatars ?? this.participantAvatars,
      hasAttachments: hasAttachments ?? this.hasAttachments,
    );
  }
}

@immutable
class MessageItem {
  const MessageItem({
    required this.id,
    required this.senderId,
    required this.sentAt,
    this.text,
    this.isMine = false,
    this.attachmentUrls = const <String>[],
    this.location,
  });

  final String id;
  final String senderId;
  final DateTime sentAt;
  final String? text;
  final bool isMine;
  final List<String> attachmentUrls;
  final GeoPoint? location;

  MessageItem copyWith({
    String? text,
    bool? isMine,
    List<String>? attachmentUrls,
    GeoPoint? location,
  }) {
    return MessageItem(
      id: id,
      senderId: senderId,
      sentAt: sentAt,
      text: text ?? this.text,
      isMine: isMine ?? this.isMine,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      location: location ?? this.location,
    );
  }
}

@immutable
class CursorPage<T> {
  const CursorPage({required this.items, this.nextCursor});
  final List<T> items;
  final String? nextCursor;

  CursorPage<T> merge(CursorPage<T> next) => CursorPage<T>(items: [...items, ...next.items], nextCursor: next.nextCursor);
}

/// ---------------- Repository contract ----------------

abstract class MessagesRepository {
  // Conversations
  Future<CursorPage<ConversationSummary>> listConversations({String? cursor, int limit = 30, String? query});
  Future<bool> toggleMute({required String conversationId, required bool next});
  Future<bool> togglePin({required String conversationId, required bool next});
  Future<void> markRead({required String conversationId, required String upToMessageId});
  Future<void> setTyping({required String conversationId, required bool typing});

  // Thread messages
  Future<CursorPage<MessageItem>> listMessages({required String conversationId, String? cursor, int limit = 40});
  Future<MessageItem> sendText({required String conversationId, required String text});
  Future<MessageItem> sendAttachment({required String conversationId, required Uri fileOrUrl});
  Future<MessageItem> shareLocation({required String conversationId, required ShareLocationRequest request});
}

/// Inject a concrete implementation in app bootstrap with overrideWithValue.
final messagesRepositoryProvider = Provider<MessagesRepository>((ref) {
  throw UnimplementedError('Provide MessagesRepository via override in main/bootstrap');
});

/// ---------------- Simple read-only providers ----------------

@immutable
class ConversationQuery {
  const ConversationQuery({this.query, this.pageSize = 30});
  final String? query;
  final int pageSize;

  @override
  bool operator ==(Object other) => other is ConversationQuery && other.query == query && other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(query, pageSize);
}

final conversationsFirstPageProvider = FutureProvider.family.autoDispose<CursorPage<ConversationSummary>, ConversationQuery>((ref, q) async {
  final repo = ref.watch(messagesRepositoryProvider);
  return repo.listConversations(cursor: null, limit: q.pageSize, query: (q.query ?? '').trim().isEmpty ? null : q.query!.trim());
});

final threadFirstPageProvider = FutureProvider.family.autoDispose<CursorPage<MessageItem>, String>((ref, conversationId) async {
  final repo = ref.watch(messagesRepositoryProvider);
  return repo.listMessages(conversationId: conversationId, cursor: null);
});

/// ---------------- Controllers (pagination + mutations) ----------------

@immutable
class PagedState<T> {
  const PagedState({required this.items, required this.cursor, required this.loading, this.error});
  final List<T> items;
  final String? cursor;
  final bool loading;
  final Object? error;

  PagedState<T> copy({List<T>? items, String? cursor, bool? loading, Object? error}) =>
      PagedState<T>(items: items ?? this.items, cursor: cursor ?? this.cursor, loading: loading ?? this.loading, error: error);

  static PagedState<T> empty<T>() => PagedState<T>(items: List.empty(), cursor: null, loading: false);
}

class ConversationsController extends AsyncNotifier<PagedState<ConversationSummary>> {
  ConversationQuery _q = const ConversationQuery();

  @override
  FutureOr<PagedState<ConversationSummary>> build() async {
    return PagedState.empty();
  }

  Future<void> init(ConversationQuery query) async {
    _q = query;
    await refresh();
  }

  Future<void> refresh() async {
    final repo = ref.read(messagesRepositoryProvider);
    state = const AsyncLoading();
    final res = await AsyncValue.guard(() => repo.listConversations(cursor: null, limit: _q.pageSize, query: (_q.query ?? '').trim().isEmpty ? null : _q.query!.trim()));
    state = res.whenData((page) => PagedState<ConversationSummary>(items: page.items, cursor: page.nextCursor, loading: false));
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull ?? PagedState.empty<ConversationSummary>();
    if (current.loading || current.cursor == null) return;
    final repo = ref.read(messagesRepositoryProvider);
    state = AsyncData(current.copy(loading: true));
    final res = await AsyncValue.guard(() => repo.listConversations(cursor: current.cursor, limit: _q.pageSize, query: (_q.query ?? '').trim().isEmpty ? null : _q.query!.trim()));
    res.when(
      data: (page) => state = AsyncData(current.copy(items: [...current.items, ...page.items], cursor: page.nextCursor, loading: false)),
      loading: () => state = AsyncData(current.copy(loading: true)),
      error: (e, st) {
        state = AsyncError(e, st);
        state = AsyncData(current.copy(loading: false, error: e));
      },
    );
  }

  Future<bool> setMuted(String conversationId, bool next) async {
    final current = state.valueOrNull ?? PagedState.empty<ConversationSummary>();
    final idx = current.items.indexWhere((e) => e.id == conversationId);
    if (idx >= 0) {
      final optimistic = [...current.items];
      optimistic[idx] = optimistic[idx].copyWith(isMuted: next);
      state = AsyncData(current.copy(items: optimistic));
    }
    final repo = ref.read(messagesRepositoryProvider);
    final res = await AsyncValue.guard(() => repo.toggleMute(conversationId: conversationId, next: next));
    final ok = res.value ?? false;
    if (!ok && idx >= 0) {
      final revert = [...(state.valueOrNull ?? current).items];
      revert[idx] = revert[idx].copyWith(isMuted: !next);
      state = AsyncData((state.valueOrNull ?? current).copy(items: revert));
    }
    return ok;
  }

  Future<bool> setPinned(String conversationId, bool next) async {
    final current = state.valueOrNull ?? PagedState.empty<ConversationSummary>();
    final idx = current.items.indexWhere((e) => e.id == conversationId);
    if (idx >= 0) {
      final optimistic = [...current.items];
      optimistic[idx] = optimistic[idx].copyWith(isPinned: next);
      state = AsyncData(current.copy(items: optimistic));
    }
    final repo = ref.read(messagesRepositoryProvider);
    final res = await AsyncValue.guard(() => repo.togglePin(conversationId: conversationId, next: next));
    final ok = res.value ?? false;
    if (!ok && idx >= 0) {
      final revert = [...(state.valueOrNull ?? current).items];
      revert[idx] = revert[idx].copyWith(isPinned: !next);
      state = AsyncData((state.valueOrNull ?? current).copy(items: revert));
    }
    return ok;
  }

  Future<void> markRead(String conversationId, String upToMessageId) async {
    final current = state.valueOrNull ?? PagedState.empty<ConversationSummary>();
    final idx = current.items.indexWhere((e) => e.id == conversationId);
    if (idx >= 0 && current.items[idx].unreadCount > 0) {
      final optimistic = [...current.items];
      optimistic[idx] = optimistic[idx].copyWith(unreadCount: 0);
      state = AsyncData(current.copy(items: optimistic));
    }
    final repo = ref.read(messagesRepositoryProvider);
    await AsyncValue.guard(() => repo.markRead(conversationId: conversationId, upToMessageId: upToMessageId));
  }

  void setTypingLocal(String conversationId, bool typing) {
    final current = state.valueOrNull ?? PagedState.empty<ConversationSummary>();
    final idx = current.items.indexWhere((e) => e.id == conversationId);
    if (idx >= 0) {
      final patched = [...current.items];
      patched[idx] = patched[idx].copyWith(isTyping: typing);
      state = AsyncData(current.copy(items: patched));
    }
  }
}

final conversationsControllerProvider = AsyncNotifierProvider<ConversationsController, PagedState<ConversationSummary>>(ConversationsController.new);

/// Thread store keeps multiple threads keyed by conversationId.
@immutable
class ThreadStore {
  const ThreadStore({required this.threads});
  final Map<String, PagedState<MessageItem>> threads;

  ThreadStore copyWith({Map<String, PagedState<MessageItem>>? threads}) => ThreadStore(threads: threads ?? this.threads);
  static const empty = ThreadStore(threads: <String, PagedState<MessageItem>>{});
}

class ThreadsController extends AsyncNotifier<ThreadStore> {
  @override
  FutureOr<ThreadStore> build() async {
    return ThreadStore.empty;
  }

  PagedState<MessageItem> _get(String cid) => (state.valueOrNull ?? ThreadStore.empty).threads[cid] ?? PagedState.empty<MessageItem>();

  void _put(String cid, PagedState<MessageItem> s) {
    final curr = state.valueOrNull ?? ThreadStore.empty;
    final next = Map<String, PagedState<MessageItem>>.from(curr.threads)..[cid] = s;
    state = AsyncData(curr.copyWith(threads: next));
  }

  Future<void> refresh(String conversationId) async {
    final repo = ref.read(messagesRepositoryProvider);
    final curr = _get(conversationId);
    _put(conversationId, curr.copy(loading: true));
    final res = await AsyncValue.guard(() => repo.listMessages(conversationId: conversationId, cursor: null));
    res.when(
      data: (page) => _put(conversationId, PagedState<MessageItem>(items: page.items, cursor: page.nextCursor, loading: false)),
      loading: () => _put(conversationId, curr.copy(loading: true)),
      error: (e, st) {
        state = AsyncError(e, st);
        _put(conversationId, curr.copy(loading: false, error: e));
      },
    );
  }

  Future<void> loadMore(String conversationId) async {
    final repo = ref.read(messagesRepositoryProvider);
    final curr = _get(conversationId);
    if (curr.loading || curr.cursor == null) return;
    _put(conversationId, curr.copy(loading: true));
    final res = await AsyncValue.guard(() => repo.listMessages(conversationId: conversationId, cursor: curr.cursor));
    res.when(
      data: (page) => _put(conversationId, curr.copy(items: [...curr.items, ...page.items], cursor: page.nextCursor, loading: false)),
      loading: () => _put(conversationId, curr.copy(loading: true)),
      error: (e, st) {
        state = AsyncError(e, st);
        _put(conversationId, curr.copy(loading: false, error: e));
      },
    );
  }

  Future<MessageItem> sendText(String conversationId, String text) async {
    final repo = ref.read(messagesRepositoryProvider);
    final curr = _get(conversationId);
    final echo = MessageItem(id: 'local-${DateTime.now().microsecondsSinceEpoch}', senderId: 'me', sentAt: DateTime.now(), text: text, isMine: true);
    _put(conversationId, curr.copy(items: [echo, ...curr.items]));
    final res = await AsyncValue.guard(() => repo.sendText(conversationId: conversationId, text: text));
    return res.when(
      data: (msg) {
        final after = _get(conversationId);
        final items = [msg, ...after.items.where((m) => m.id != echo.id)];
        _put(conversationId, after.copy(items: items));
        return msg;
      },
      loading: () => echo,
      error: (e, st) {
        final after = _get(conversationId);
        _put(conversationId, after.copy(items: after.items.where((m) => m.id != echo.id).toList()));
        throw e;
      },
    );
  }

  Future<MessageItem> sendAttachment(String conversationId, Uri fileOrUrl) async {
    final repo = ref.read(messagesRepositoryProvider);
    final curr = _get(conversationId);
    final echo = MessageItem(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      senderId: 'me',
      sentAt: DateTime.now(),
      text: null,
      isMine: true,
      attachmentUrls: [fileOrUrl.toString()],
    );
    _put(conversationId, curr.copy(items: [echo, ...curr.items]));
    final res = await AsyncValue.guard(() => repo.sendAttachment(conversationId: conversationId, fileOrUrl: fileOrUrl));
    return res.when(
      data: (msg) {
        final after = _get(conversationId);
        final items = [msg, ...after.items.where((m) => m.id != echo.id)];
        _put(conversationId, after.copy(items: items));
        return msg;
      },
      loading: () => echo,
      error: (e, st) {
        final after = _get(conversationId);
        _put(conversationId, after.copy(items: after.items.where((m) => m.id != echo.id).toList()));
        throw e;
      },
    );
  }

  Future<MessageItem> shareLocation(String conversationId, ShareLocationRequest req) async {
    final repo = ref.read(messagesRepositoryProvider);
    final curr = _get(conversationId);
    final echo = MessageItem(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      senderId: 'me',
      sentAt: DateTime.now(),
      text: null,
      isMine: true,
      location: GeoPoint(req.lat, req.lng),
    );
    _put(conversationId, curr.copy(items: [echo, ...curr.items]));
    final res = await AsyncValue.guard(() => repo.shareLocation(conversationId: conversationId, request: req));
    return res.when(
      data: (msg) {
        final after = _get(conversationId);
        final items = [msg, ...after.items.where((m) => m.id != echo.id)];
        _put(conversationId, after.copy(items: items));
        return msg;
      },
      loading: () => echo,
      error: (e, st) {
        final after = _get(conversationId);
        _put(conversationId, after.copy(items: after.items.where((m) => m.id != echo.id).toList()));
        throw e;
      },
    );
  }
}

final threadsControllerProvider = AsyncNotifierProvider<ThreadsController, ThreadStore>(ThreadsController.new);

/// Selector for a single thread state by conversationId (read-only view on the store).
final threadByIdProvider = Provider.family.autoDispose<PagedState<MessageItem>, String>((ref, conversationId) {
  final store = ref.watch(threadsControllerProvider).valueOrNull ?? ThreadStore.empty;
  return store.threads[conversationId] ?? PagedState.empty<MessageItem>();
});

/// ---------------- Facade for widgets/screens ----------------

typedef Reader = T Function<T>(ProviderListenable<T> provider);

class MessagesActions {
  MessagesActions(this._read);
  final Reader _read;

  // Conversations
  Future<void> initConversations(ConversationQuery q) => _read(conversationsControllerProvider.notifier).init(q);
  Future<void> refreshConversations() => _read(conversationsControllerProvider.notifier).refresh();
  Future<void> loadMoreConversations() => _read(conversationsControllerProvider.notifier).loadMore();
  Future<bool> setMuted(String cid, bool next) => _read(conversationsControllerProvider.notifier).setMuted(cid, next);
  Future<bool> setPinned(String cid, bool next) => _read(conversationsControllerProvider.notifier).setPinned(cid, next);
  Future<void> markRead(String cid, String upToMessageId) => _read(conversationsControllerProvider.notifier).markRead(cid, upToMessageId);
  void setTypingLocal(String cid, bool typing) => _read(conversationsControllerProvider.notifier).setTypingLocal(cid, typing);

  // Threads
  Future<void> refreshThread(String cid) => _read(threadsControllerProvider.notifier).refresh(cid);
  Future<void> loadMoreThread(String cid) => _read(threadsControllerProvider.notifier).loadMore(cid);
  Future<MessageItem> sendText(String cid, String text) => _read(threadsControllerProvider.notifier).sendText(cid, text);
  Future<MessageItem> sendAttachment(String cid, Uri fileOrUrl) => _read(threadsControllerProvider.notifier).sendAttachment(cid, fileOrUrl);
  Future<MessageItem> shareLocation(String cid, ShareLocationRequest req) => _read(threadsControllerProvider.notifier).shareLocation(cid, req);

  // Repository-level typing for network signaling
  Future<void> setTypingRemote(String cid, bool typing) => _read(messagesRepositoryProvider).setTyping(conversationId: cid, typing: typing);
}

final messagesActionsProvider = Provider<MessagesActions>((ref) => MessagesActions(ref.read));
