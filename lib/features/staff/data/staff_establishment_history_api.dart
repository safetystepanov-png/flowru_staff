import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_storage.dart';

class StaffEstablishmentHistoryItem {
  final String eventType;
  final String entityId;
  final String title;
  final double? amount;
  final String? comment;
  final String? createdAt;
  final String? actorUserId;

  StaffEstablishmentHistoryItem({
    required this.eventType,
    required this.entityId,
    required this.title,
    required this.amount,
    required this.comment,
    required this.createdAt,
    required this.actorUserId,
  });

  factory StaffEstablishmentHistoryItem.fromJson(Map<String, dynamic> json) {
    return StaffEstablishmentHistoryItem(
      eventType: json['event_type'] as String,
      entityId: json['entity_id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num?)?.toDouble(),
      comment: json['comment'] as String?,
      createdAt: json['created_at'] as String?,
      actorUserId: json['actor_user_id'] as String?,
    );
  }
}

class StaffEstablishmentHistoryApi {
  Future<List<StaffEstablishmentHistoryItem>> getHistory({
    required int establishmentId,
  }) async {
    final accessToken = await AuthStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Access token not found');
    }

    final uri = Uri.parse(
      '${AppConfig.baseUrl}/api/v1/staff/establishment/history?establishment_id=$establishmentId',
    );

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load establishment history. ${response.body}');
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    final List items = data['items'] as List;

    return items
        .map((item) => StaffEstablishmentHistoryItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}