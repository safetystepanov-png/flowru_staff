import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_storage.dart';

class StaffEstablishmentHistoryItem {
  final String eventType;
  final String? entityId;
  final String? title;
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
      eventType: json['event_type']?.toString() ?? '',
      entityId: json['entity_id']?.toString(),
      title: json['title']?.toString(),
      amount: json['amount'] == null
          ? null
          : double.tryParse(json['amount'].toString()),
      comment: json['comment']?.toString(),
      createdAt: json['created_at']?.toString(),
      actorUserId: json['actor_user_id']?.toString(),
    );
  }
}

class StaffClientHistoryItem {
  final String eventType;
  final String? title;
  final double? amount;
  final String? comment;
  final String? createdAt;

  StaffClientHistoryItem({
    required this.eventType,
    required this.title,
    required this.amount,
    required this.comment,
    required this.createdAt,
  });

  factory StaffClientHistoryItem.fromJson(Map<String, dynamic> json) {
    return StaffClientHistoryItem(
      eventType: json['event_type']?.toString() ?? '',
      title: json['title']?.toString(),
      amount: json['amount'] == null
          ? null
          : double.tryParse(json['amount'].toString()),
      comment: json['comment']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}

class StaffHistoryApi {
  Future<String> _token() async {
    final accessToken = await AuthStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Access token not found');
    }
    return accessToken;
  }

  Future<List<StaffEstablishmentHistoryItem>> getEstablishmentHistory({
    required int establishmentId,
  }) async {
    final accessToken = await _token();

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
      throw Exception(
        'GET establishment history failed: ${response.statusCode} ${response.body}',
      );
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    final List items = (data['items'] as List?) ?? [];

    return items
        .map(
          (item) => StaffEstablishmentHistoryItem.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<List<StaffClientHistoryItem>> getClientHistory({
    required int establishmentId,
    required String clientId,
  }) async {
    final accessToken = await _token();

    final uri = Uri.parse(
      '${AppConfig.baseUrl}/api/v1/staff/clients/history?client_id=$clientId&establishment_id=$establishmentId',
    );

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'GET client history failed: ${response.statusCode} ${response.body}',
      );
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    final List items = (data['items'] as List?) ?? [];

    return items
        .map(
          (item) => StaffClientHistoryItem.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }
}