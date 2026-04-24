class ReactionItem {
  final String emoji;
  final int count;
  final bool reactedByMe;

  const ReactionItem({
    required this.emoji,
    required this.count,
    required this.reactedByMe,
  });

  factory ReactionItem.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v == null) return 1;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 1;
    }

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      final s = value?.toString().toLowerCase() ?? '';
      return s == 'true' || s == '1' || s == 'yes';
    }

    return ReactionItem(
      emoji: json['emoji']?.toString() ?? '👍',
      count: parseInt(json['count']),
      reactedByMe: parseBool(json['reacted_by_me'] ?? json['is_mine'] ?? json['selected']),
    );
  }

  Map<String, dynamic> toJson() => {
    'emoji': emoji,
    'count': count,
    'reacted_by_me': reactedByMe,
  };
}