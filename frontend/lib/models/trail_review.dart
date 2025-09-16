// lib/models/trail_review.dart

class TrailReview {
  final String id;
  final String trailId;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final double rating;
  final String content;
  final List<String> imageUrls;
  final DateTime visitDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int helpfulCount;
  final bool myHelpful;

  const TrailReview({
    required this.id,
    required this.trailId,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.rating,
    required this.content,
    required this.imageUrls,
    required this.visitDate,
    required this.createdAt,
    required this.updatedAt,
    required this.helpfulCount,
    required this.myHelpful,
  });

  factory TrailReview.fromJson(Map<String, dynamic> json) {
    return TrailReview(
      id: json['id'] ?? '',
      trailId: json['trailId'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      userAvatarUrl: json['userAvatarUrl'],
      rating: json['rating']?.toDouble() ?? 0.0,
      content: json['content'] ?? '',
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      visitDate: DateTime.parse(json['visitDate']),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      helpfulCount: json['helpfulCount'] ?? 0,
      myHelpful: json['myHelpful'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trailId': trailId,
      'userId': userId,
      'userName': userName,
      'userAvatarUrl': userAvatarUrl,
      'rating': rating,
      'content': content,
      'imageUrls': imageUrls,
      'visitDate': visitDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'helpfulCount': helpfulCount,
      'myHelpful': myHelpful,
    };
  }

  TrailReview copyWith({
    String? id,
    String? trailId,
    String? userId,
    String? userName,
    String? userAvatarUrl,
    double? rating,
    String? content,
    List<String>? imageUrls,
    DateTime? visitDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? helpfulCount,
    bool? myHelpful,
  }) {
    return TrailReview(
      id: id ?? this.id,
      trailId: trailId ?? this.trailId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      rating: rating ?? this.rating,
      content: content ?? this.content,
      imageUrls: imageUrls ?? this.imageUrls,
      visitDate: visitDate ?? this.visitDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      myHelpful: myHelpful ?? this.myHelpful,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TrailReview &&
        other.id == id &&
        other.trailId == trailId &&
        other.userId == userId &&
        other.userName == userName &&
        other.userAvatarUrl == userAvatarUrl &&
        other.rating == rating &&
        other.content == content &&
        other.imageUrls == imageUrls &&
        other.visitDate == visitDate &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.helpfulCount == helpfulCount &&
        other.myHelpful == myHelpful;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      trailId,
      userId,
      userName,
      userAvatarUrl,
      rating,
      content,
      imageUrls,
      visitDate,
      createdAt,
      updatedAt,
      helpfulCount,
      myHelpful,
    );
  }

  @override
  String toString() {
    return 'TrailReview(id: $id, trailId: $trailId, userName: $userName, rating: $rating)';
  }
}

