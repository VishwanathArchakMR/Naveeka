// lib/models/paged_state.dart

class PagedState<T> {
  final List<T> items;
  final bool hasMore;
  final String? nextCursor;
  final int totalCount;
  final bool isLoading;
  final String? error;

  const PagedState({
    required this.items,
    required this.hasMore,
    this.nextCursor,
    required this.totalCount,
    this.isLoading = false,
    this.error,
  });

  factory PagedState.empty() {
    return PagedState<T>(
      items: const [],
      hasMore: false,
      totalCount: 0,
    );
  }

  factory PagedState.loading() {
    return PagedState<T>(
      items: const [],
      hasMore: false,
      totalCount: 0,
      isLoading: true,
    );
  }

  factory PagedState.error(String error) {
    return PagedState<T>(
      items: const [],
      hasMore: false,
      totalCount: 0,
      error: error,
    );
  }

  factory PagedState.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return PagedState<T>(
      items: (json['items'] as List<dynamic>?)
          ?.map((item) => fromJsonT(item as Map<String, dynamic>))
          .toList() ?? [],
      hasMore: json['hasMore'] ?? false,
      nextCursor: json['nextCursor'],
      totalCount: json['totalCount'] ?? 0,
      isLoading: json['isLoading'] ?? false,
      error: json['error'],
    );
  }

  Map<String, dynamic> toJson(Map<String, dynamic> Function(T) toJsonT) {
    return {
      'items': items.map((item) => toJsonT(item)).toList(),
      'hasMore': hasMore,
      'nextCursor': nextCursor,
      'totalCount': totalCount,
      'isLoading': isLoading,
      'error': error,
    };
  }

  PagedState<T> copyWith({
    List<T>? items,
    bool? hasMore,
    String? nextCursor,
    int? totalCount,
    bool? isLoading,
    String? error,
  }) {
    return PagedState<T>(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      totalCount: totalCount ?? this.totalCount,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  /// Add new items to the existing list
  PagedState<T> appendItems(List<T> newItems, {String? newNextCursor}) {
    return PagedState<T>(
      items: [...items, ...newItems],
      hasMore: hasMore,
      nextCursor: newNextCursor ?? nextCursor,
      totalCount: totalCount,
      isLoading: false,
      error: null,
    );
  }

  /// Replace all items with new ones
  PagedState<T> replaceItems(List<T> newItems, {String? newNextCursor}) {
    return PagedState<T>(
      items: newItems,
      hasMore: hasMore,
      nextCursor: newNextCursor ?? nextCursor,
      totalCount: totalCount,
      isLoading: false,
      error: null,
    );
  }

  /// Set loading state
  PagedState<T> setLoading(bool loading) {
    return PagedState<T>(
      items: items,
      hasMore: hasMore,
      nextCursor: nextCursor,
      totalCount: totalCount,
      isLoading: loading,
      error: null,
    );
  }

  /// Set error state
  PagedState<T> setError(String error) {
    return PagedState<T>(
      items: items,
      hasMore: hasMore,
      nextCursor: nextCursor,
      totalCount: totalCount,
      isLoading: false,
      error: error,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PagedState<T> &&
        other.items == items &&
        other.hasMore == hasMore &&
        other.nextCursor == nextCursor &&
        other.totalCount == totalCount &&
        other.isLoading == isLoading &&
        other.error == error;
  }

  @override
  int get hashCode {
    return Object.hash(
      items,
      hasMore,
      nextCursor,
      totalCount,
      isLoading,
      error,
    );
  }

  @override
  String toString() {
    return 'PagedState(items: ${items.length}, hasMore: $hasMore, totalCount: $totalCount, isLoading: $isLoading)';
  }
}

