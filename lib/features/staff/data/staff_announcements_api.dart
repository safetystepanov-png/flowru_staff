import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_storage.dart';

class StaffAnnouncementItem {
  final String announcementId;
  final String title;
  final String body;
  final bool isPinned;
  final bool isActive;
  final bool acknowledged;
  final int acknowledgedCount;
  final List<String> acknowledgedUserIds;
  final List<String> acknowledgedUsers;
  final String createdAt;
  final String? createdByUserId;

  StaffAnnouncementItem({
    required this.announcementId,
    required this.title,
    required this.body,
    required this.isPinned,
    required this.isActive,
    required this.acknowledged,
    required this.acknowledgedCount,
    required this.acknowledgedUserIds,
    required this.acknowledgedUsers,
    required this.createdAt,
    required this.createdByUserId,
  });

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value?.toString().trim().toLowerCase() ?? '';
    return s == 'true' || s == '1' || s == 'yes' || s == 'y';
  }

  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }

    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return <String>[];
  }

  factory StaffAnnouncementItem.fromJson(Map<String, dynamic> json) {
    final acknowledgedUsers = _parseStringList(
      json['acknowledged_users'] ??
          json['acknowledged_user_names'] ??
          json['ack_users'],
    );

    final acknowledgedUserIds = _parseStringList(
      json['acknowledged_user_ids'] ??
          json['ack_user_ids'] ??
          json['read_user_ids'],
    );

    return StaffAnnouncementItem(
      announcementId:
          json['announcement_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      isPinned: _parseBool(json['is_pinned']),
      isActive: _parseBool(json['is_active'] ?? true),
      acknowledged: _parseBool(
        json['acknowledged'] ?? json['is_read'] ?? json['seen'],
      ),
      acknowledgedCount: _parseInt(
        json['acknowledged_count'] ??
            json['acks_count'] ??
            json['read_count'] ??
            acknowledgedUsers.length,
      ),
      acknowledgedUserIds: acknowledgedUserIds,
      acknowledgedUsers: acknowledgedUsers,
      createdAt: json['created_at']?.toString() ?? '',
      createdByUserId: json['created_by_user_id']?.toString(),
    );
  }

  String get previewBody => body.trim();

  StaffAnnouncementItem copyWith({
    String? announcementId,
    String? title,
    String? body,
    bool? isPinned,
    bool? isActive,
    bool? acknowledged,
    int? acknowledgedCount,
    List<String>? acknowledgedUserIds,
    List<String>? acknowledgedUsers,
    String? createdAt,
    String? createdByUserId,
  }) {
    return StaffAnnouncementItem(
      announcementId: announcementId ?? this.announcementId,
      title: title ?? this.title,
      body: body ?? this.body,
      isPinned: isPinned ?? this.isPinned,
      isActive: isActive ?? this.isActive,
      acknowledged: acknowledged ?? this.acknowledged,
      acknowledgedCount: acknowledgedCount ?? this.acknowledgedCount,
      acknowledgedUserIds:
          acknowledgedUserIds ?? List<String>.from(this.acknowledgedUserIds),
      acknowledgedUsers:
          acknowledgedUsers ?? List<String>.from(this.acknowledgedUsers),
      createdAt: createdAt ?? this.createdAt,
      createdByUserId: createdByUserId ?? this.createdByUserId,
    );
  }
}

class StaffAnnouncementCreateResult {
  final bool ok;
  final String message;
  final String? announcementId;

  StaffAnnouncementCreateResult({
    required this.ok,
    required this.message,
    required this.announcementId,
  });

  factory StaffAnnouncementCreateResult.fromJson(Map<String, dynamic> json) {
    return StaffAnnouncementCreateResult(
      ok: _ResultParsers.parseBool(json['ok'] ?? true),
      message: json['message']?.toString() ?? '',
      announcementId:
          json['announcement_id']?.toString() ?? json['id']?.toString(),
    );
  }
}

class StaffAnnouncementAcknowledgeResult {
  final bool ok;
  final String message;

  StaffAnnouncementAcknowledgeResult({
    required this.ok,
    required this.message,
  });

  factory StaffAnnouncementAcknowledgeResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return StaffAnnouncementAcknowledgeResult(
      ok: _ResultParsers.parseBool(json['ok'] ?? true),
      message: json['message']?.toString() ?? '',
    );
  }
}

class StaffAnnouncementDeleteResult {
  final bool ok;
  final String message;

  StaffAnnouncementDeleteResult({
    required this.ok,
    required this.message,
  });

  factory StaffAnnouncementDeleteResult.fromJson(Map<String, dynamic> json) {
    return StaffAnnouncementDeleteResult(
      ok: _ResultParsers.parseBool(json['ok'] ?? true),
      message: json['message']?.toString() ?? '',
    );
  }
}

class StaffAnnouncementsApi {
  Future<String> _token() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Access token not found');
    }
    return token;
  }

  Future<List<StaffAnnouncementItem>> getAnnouncements({
    required int establishmentId,
  }) async {
    final token = await _token();

    final uri = Uri.parse(
      '${AppConfig.baseUrl}/api/v1/staff/announcements?establishment_id=$establishmentId',
    );

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'GET announcements failed: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    if (data is List) {
      return data
          .map((e) => StaffAnnouncementItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    if (data is Map<String, dynamic>) {
      final items = (data['items'] as List?) ?? const [];
      return items
          .map((e) => StaffAnnouncementItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return [];
  }

  Future<List<StaffAnnouncementItem>> getPinnedAnnouncements({
    required int establishmentId,
  }) async {
    final items = await getAnnouncements(establishmentId: establishmentId);
    return items.where((e) => e.isPinned && e.isActive).toList();
  }

  Future<List<StaffAnnouncementItem>> getActiveAnnouncements({
    required int establishmentId,
  }) async {
    final items = await getAnnouncements(establishmentId: establishmentId);
    return items.where((e) => e.isActive).toList();
  }

  Future<StaffAnnouncementCreateResult> createAnnouncement({
    required int establishmentId,
    required String title,
    required String body,
    bool isPinned = false,
  }) async {
    final token = await _token();

    final uri = Uri.parse(
      '${AppConfig.baseUrl}/api/v1/staff/announcements',
    );

    final response = await http.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'establishment_id': establishmentId,
        'title': title,
        'body': body,
        'is_pinned': isPinned,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'POST announcements failed: ${response.statusCode} ${response.body}',
      );
    }

    return StaffAnnouncementCreateResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<StaffAnnouncementAcknowledgeResult> acknowledgeAnnouncement({
    required int establishmentId,
    required String announcementId,
  }) async {
    final token = await _token();

    final uri = Uri.parse(
      '${AppConfig.baseUrl}/api/v1/staff/announcements/$announcementId/acknowledge',
    );

    final response = await http.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'establishment_id': establishmentId,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'POST acknowledge announcement failed: ${response.statusCode} ${response.body}',
      );
    }

    return StaffAnnouncementAcknowledgeResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<StaffAnnouncementDeleteResult> deleteAnnouncement({
    required int establishmentId,
    required String announcementId,
  }) async {
    final token = await _token();

    final uri = Uri.parse(
      '${AppConfig.baseUrl}/api/v1/staff/announcements/$announcementId?establishment_id=$establishmentId',
    );

    final response = await http.delete(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
        'DELETE announcement failed: ${response.statusCode} ${response.body}',
      );
    }

    if (response.statusCode == 204 || response.body.trim().isEmpty) {
      return StaffAnnouncementDeleteResult(
        ok: true,
        message: 'Объявление удалено',
      );
    }

    return StaffAnnouncementDeleteResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}

class _ResultParsers {
  static bool parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value?.toString().trim().toLowerCase() ?? '';
    return s == 'true' || s == '1' || s == 'yes' || s == 'y';
  }
}