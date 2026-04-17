import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_storage.dart';

class MyScheduleRequestItem {
  final int requestId;
  final int establishmentId;
  final int year;
  final int month;
  final List<int> selectedDays;
  final String status;
  final String? comment;
  final String? createdAt;
  final String? updatedAt;

  const MyScheduleRequestItem({
    required this.requestId,
    required this.establishmentId,
    required this.year,
    required this.month,
    required this.selectedDays,
    required this.status,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MyScheduleRequestItem.fromJson(Map<String, dynamic> json) {
    return MyScheduleRequestItem(
      requestId: (json['request_id'] as num?)?.toInt() ?? 0,
      establishmentId: (json['establishment_id'] as num?)?.toInt() ?? 0,
      year: (json['year'] as num?)?.toInt() ?? 0,
      month: (json['month'] as num?)?.toInt() ?? 0,
      selectedDays: ((json['selected_days'] as List?) ?? const [])
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .where((e) => e > 0)
          .toList()
        ..sort(),
      status: json['status']?.toString() ?? 'pending',
      comment: json['comment']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }
}

class StaffScheduleRequestsApi {
  const StaffScheduleRequestsApi();

  Future<String> _token() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Access token not found');
    }
    return token;
  }

  Future<MyScheduleRequestItem?> getLatestMyRequest({
    required int establishmentId,
    required int year,
    required int month,
  }) async {
    final token = await _token();

    final uri = Uri.parse(
      '${AppConfig.baseUrl}/api/v1/staff/schedule/my-requests'
      '?establishment_id=$establishmentId&year=$year&month=$month',
    );

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'get latest request failed: ${response.statusCode} body=${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is List && decoded.isNotEmpty) {
      final first = decoded.first;
      if (first is Map<String, dynamic>) {
        return MyScheduleRequestItem.fromJson(first);
      }
      if (first is Map) {
        return MyScheduleRequestItem.fromJson(
          Map<String, dynamic>.from(first),
        );
      }
    }

    if (decoded is Map<String, dynamic>) {
      final items = decoded['items'];
      if (items is List && items.isNotEmpty) {
        final first = items.first;
        if (first is Map<String, dynamic>) {
          return MyScheduleRequestItem.fromJson(first);
        }
        if (first is Map) {
          return MyScheduleRequestItem.fromJson(
            Map<String, dynamic>.from(first),
          );
        }
      }
    }

    return null;
  }

  Future<void> submitScheduleRequest({
    required int establishmentId,
    required int year,
    required int month,
    required List<int> selectedDays,
    String? comment,
  }) async {
    final token = await _token();

    final uri = Uri.parse(
      '${AppConfig.baseUrl}/api/v1/staff/schedule/request',
    );

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'establishment_id': establishmentId,
        'year': year,
        'month': month,
        'selected_days': selectedDays,
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'submit schedule request failed: ${response.statusCode} body=${response.body}',
      );
    }
  }

  Future<void> submitSwapRequest({
    required int establishmentId,
    required String shiftDate,
    String? reason,
  }) async {
    final token = await _token();

    final uri = Uri.parse(
      '${AppConfig.baseUrl}/api/v1/staff/swap/request',
    );

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'establishment_id': establishmentId,
        'shift_date': shiftDate,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'submit swap request failed: ${response.statusCode} body=${response.body}',
      );
    }
  }
}