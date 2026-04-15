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
  final String createdAt;
  final String? createdByUserId;

  StaffAnnouncementItem({
    required this.announcementId,
    required this.title,
    required this.body,
    required this.isPinned,
    required this.isActive,
    required this.createdAt,
    required this.createdByUserId,
  });

  factory StaffAnnouncementItem.fromJson(Map<String, dynamic> json) {
    return StaffAnnouncementItem(
      announcementId: json['announcement_id']?.toString() ??
          json['id']?.toString() ??
          '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      isPinned: json['is_pinned'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at']?.toString() ?? '',
      createdByUserId: json['created_by_user_id']?.toString(),
    );
  }
}

class StaffAnnouncementCreateResult {
  final bool ok;
  final String message;

  StaffAnnouncementCreateResult({
    required this.ok,
    required this.message,
  });

  factory StaffAnnouncementCreateResult.fromJson(Map<String, dynamic> json) {
    return StaffAnnouncementCreateResult(
      ok: json['ok'] as bool? ?? false,
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

    if (response.statusCode != 200) {
      throw Exception(
        'POST announcements failed: ${response.statusCode} ${response.body}',
      );
    }

    return StaffAnnouncementCreateResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}