import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_storage.dart';

class StaffAnnouncementAudienceUser {
  final String userId;
  final String userName;
  final String? role;
  final String? acknowledgedAt;

  const StaffAnnouncementAudienceUser({
    required this.userId,
    required this.userName,
    required this.role,
    required this.acknowledgedAt,
  });

  factory StaffAnnouncementAudienceUser.fromJson(Map<String, dynamic> json) {
    return StaffAnnouncementAudienceUser(
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? 'Сотрудник',
      role: json['role']?.toString(),
      acknowledgedAt: json['acknowledged_at']?.toString(),
    );
  }
}

class StaffAnnouncementAudience {
  final String announcementId;
  final String title;
  final String body;
  final bool isPinned;
  final bool isActive;
  final String createdAt;
  final int acknowledgedCount;
  final int pendingCount;
  final int totalStaffCount;
  final List<StaffAnnouncementAudienceUser> acknowledgedUsers;
  final List<StaffAnnouncementAudienceUser> pendingUsers;

  const StaffAnnouncementAudience({
    required this.announcementId,
    required this.title,
    required this.body,
    required this.isPinned,
    required this.isActive,
    required this.createdAt,
    required this.acknowledgedCount,
    required this.pendingCount,
    required this.totalStaffCount,
    required this.acknowledgedUsers,
    required this.pendingUsers,
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

  factory StaffAnnouncementAudience.fromJson(Map<String, dynamic> json) {
    final ackRaw = (json['acknowledged_users'] as List?) ?? const [];
    final pendingRaw = (json['pending_users'] as List?) ?? const [];

    return StaffAnnouncementAudience(
      announcementId:
          json['announcement_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      isPinned: _parseBool(json['is_pinned']),
      isActive: _parseBool(json['is_active'] ?? true),
      createdAt: json['created_at']?.toString() ?? '',
      acknowledgedCount: _parseInt(json['acknowledged_count']),
      pendingCount: _parseInt(json['pending_count']),
      totalStaffCount: _parseInt(json['total_staff_count']),
      acknowledgedUsers: ackRaw
          .map(
            (e) => StaffAnnouncementAudienceUser.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
      pendingUsers: pendingRaw
          .map(
            (e) => StaffAnnouncementAudienceUser.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class StaffAnnouncementItem {
  final String announcementId;
  final String title;
  final String body;
  final bool isPinned;
  final bool isActive;
  final bool isAcknowledged;
  final String? acknowledgedAt;
  final int acknowledgedCount;
  final int totalStaffCount;
  final String createdAt;
  final String? createdByUserId;

  const StaffAnnouncementItem({
    required this.announcementId,
    required this.title,
    required this.body,
    required this.isPinned,
    required this.isActive,
    required this.isAcknowledged,
    required this.acknowledgedAt,
    required this.acknowledgedCount,
    required this.totalStaffCount,
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

  factory StaffAnnouncementItem.fromJson(Map<String, dynamic> json) {
    return StaffAnnouncementItem(
      announcementId:
          json['announcement_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      isPinned: _parseBool(json['is_pinned']),
      isActive: _parseBool(json['is_active'] ?? true),
      isAcknowledged: _parseBool(
        json['is_acknowledged'] ?? json['acknowledged'],
      ),
      acknowledgedAt: json['acknowledged_at']?.toString(),
      acknowledgedCount: _parseInt(json['acknowledged_count']),
      totalStaffCount: _parseInt(json['total_staff_count']),
      createdAt: json['created_at']?.toString() ?? '',
      createdByUserId: json['created_by_user_id']?.toString(),
    );
  }

  StaffAnnouncementItem copyWith({
    bool? isAcknowledged,
    String? acknowledgedAt,
    int? acknowledgedCount,
  }) {
    return StaffAnnouncementItem(
      announcementId: announcementId,
      title: title,
      body: body,
      isPinned: isPinned,
      isActive: isActive,
      isAcknowledged: isAcknowledged ?? this.isAcknowledged,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      acknowledgedCount: acknowledgedCount ?? this.acknowledgedCount,
      totalStaffCount: totalStaffCount,
      createdAt: createdAt,
      createdByUserId: createdByUserId,
    );
  }
}

class StaffAnnouncementCreateResult {
  final bool ok;
  final String message;
  final String? announcementId;

  const StaffAnnouncementCreateResult({
    required this.ok,
    required this.message,
    required this.announcementId,
  });

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value?.toString().trim().toLowerCase() ?? '';
    return s == 'true' || s == '1' || s == 'yes' || s == 'y';
  }

  factory StaffAnnouncementCreateResult.fromJson(Map<String, dynamic> json) {
    return StaffAnnouncementCreateResult(
      ok: _parseBool(json['ok'] ?? json['success'] ?? true),
      message: json['message']?.toString() ?? '',
      announcementId:
          json['announcement_id']?.toString() ?? json['id']?.toString(),
    );
  }
}

class StaffAnnouncementAcknowledgeResult {
  final bool ok;
  final String message;
  final String? acknowledgedAt;

  const StaffAnnouncementAcknowledgeResult({
    required this.ok,
    required this.message,
    required this.acknowledgedAt,
  });

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value?.toString().trim().toLowerCase() ?? '';
    return s == 'true' || s == '1' || s == 'yes' || s == 'y';
  }

  factory StaffAnnouncementAcknowledgeResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return StaffAnnouncementAcknowledgeResult(
      ok: _parseBool(json['ok'] ?? json['success'] ?? true),
      message: json['message']?.toString() ?? '',
      acknowledgedAt: json['acknowledged_at']?.toString(),
    );
  }
}

class StaffAnnouncementDeleteResult {
  final bool ok;
  final String message;

  const StaffAnnouncementDeleteResult({
    required this.ok,
    required this.message,
  });

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value?.toString().trim().toLowerCase() ?? '';
    return s == 'true' || s == '1' || s == 'yes' || s == 'y';
  }

  factory StaffAnnouncementDeleteResult.fromJson(Map<String, dynamic> json) {
    return StaffAnnouncementDeleteResult(
      ok: _parseBool(json['ok'] ?? json['success'] ?? true),
      message: json['message']?.toString() ?? '',
    );
  }
}

class StaffAnnouncementsApi {
  const StaffAnnouncementsApi();

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

    return <StaffAnnouncementItem>[];
  }

  Future<StaffAnnouncementCreateResult> createAnnouncement({
    required int establishmentId,
    required String title,
    required String body,
    bool isPinned = false,
  }) async {
    final token = await _token();

    final uri = Uri.parse('${AppConfig.baseUrl}/api/v1/staff/announcements');

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
        'POST acknowledge failed: ${response.statusCode} ${response.body}',
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

    if (response.statusCode != 200) {
      throw Exception(
        'DELETE announcement failed: ${response.statusCode} ${response.body}',
      );
    }

    return StaffAnnouncementDeleteResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<StaffAnnouncementAudience> getAnnouncementAudience({
    required int establishmentId,
    required String announcementId,
  }) async {
    final token = await _token();

    final uri = Uri.parse(
      '${AppConfig.baseUrl}/api/v1/staff/announcements/$announcementId/audience?establishment_id=$establishmentId',
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
        'GET announcement audience failed: ${response.statusCode} ${response.body}',
      );
    }

    return StaffAnnouncementAudience.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}