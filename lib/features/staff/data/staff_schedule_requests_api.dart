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

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<int> _parseIntList(dynamic raw) {
    if (raw is! List) return <int>[];

    return raw
        .map((e) => int.tryParse(e.toString()) ?? 0)
        .where((e) => e > 0)
        .toList()
      ..sort();
  }

  factory MyScheduleRequestItem.fromJson(Map<String, dynamic> json) {
    return MyScheduleRequestItem(
      requestId: _parseInt(json['request_id']),
      establishmentId: _parseInt(json['establishment_id']),
      year: _parseInt(json['year']),
      month: _parseInt(json['month']),
      selectedDays: _parseIntList(json['selected_days']),
      status: (json['status'] ?? 'pending').toString(),
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

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];

    return value
        .where((e) => e is Map)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim());
  }

  MyScheduleRequestItem? _pickExactMonthRequest({
    required List<Map<String, dynamic>> items,
    required int establishmentId,
    required int year,
    required int month,
  }) {
    final matches = items
        .map(MyScheduleRequestItem.fromJson)
        .where((request) =>
            request.establishmentId == establishmentId &&
            request.year == year &&
            request.month == month)
        .toList();

    if (matches.isEmpty) return null;
    if (matches.length == 1) return matches.first;

    matches.sort((a, b) {
      final aDate =
          _parseDate(a.updatedAt) ?? _parseDate(a.createdAt) ?? DateTime(1970);
      final bDate =
          _parseDate(b.updatedAt) ?? _parseDate(b.createdAt) ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });

    return matches.first;
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

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'get latest request failed: ${response.statusCode} body=${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is List) {
      final items = _asMapList(decoded);
      return _pickExactMonthRequest(
        items: items,
        establishmentId: establishmentId,
        year: year,
        month: month,
      );
    }

    final decodedMap = _asMap(decoded);
    if (decodedMap == null) return null;

    final directRequestId =
        int.tryParse((decodedMap['request_id'] ?? '').toString()) ?? 0;
    if (directRequestId > 0) {
      final direct = MyScheduleRequestItem.fromJson(decodedMap);
      if (direct.establishmentId == establishmentId &&
          direct.year == year &&
          direct.month == month) {
        return direct;
      }
      return null;
    }

    final items = _asMapList(decodedMap['items']);
    final fromItems = _pickExactMonthRequest(
      items: items,
      establishmentId: establishmentId,
      year: year,
      month: month,
    );
    if (fromItems != null) return fromItems;

    final requests = _asMapList(decodedMap['requests']);
    final fromRequests = _pickExactMonthRequest(
      items: requests,
      establishmentId: establishmentId,
      year: year,
      month: month,
    );
    if (fromRequests != null) return fromRequests;

    final dataList = _asMapList(decodedMap['data']);
    final fromDataList = _pickExactMonthRequest(
      items: dataList,
      establishmentId: establishmentId,
      year: year,
      month: month,
    );
    if (fromDataList != null) return fromDataList;

    final dataMap = _asMap(decodedMap['data']);
    if (dataMap != null) {
      final dataRequest = MyScheduleRequestItem.fromJson(dataMap);
      if (dataRequest.establishmentId == establishmentId &&
          dataRequest.year == year &&
          dataRequest.month == month) {
        return dataRequest;
      }
    }

    return null;
  }

  Future<MyScheduleRequestItem> submitScheduleRequest({
    required int establishmentId,
    required int year,
    required int month,
    required List<int> selectedDays,
    String? comment,
  }) async {
    final token = await _token();

    final uri = Uri.parse('${AppConfig.baseUrl}/api/v1/staff/schedule/request');

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

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'submit schedule request failed: ${response.statusCode} body=${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    final decodedMap = _asMap(decoded);
    if (decodedMap != null) {
      final directRequestId =
          int.tryParse((decodedMap['request_id'] ?? '').toString()) ?? 0;

      if (directRequestId > 0) {
        return MyScheduleRequestItem.fromJson(decodedMap);
      }

      final dataMap = _asMap(decodedMap['data']);
      if (dataMap != null) {
        return MyScheduleRequestItem.fromJson(dataMap);
      }
    }

    return MyScheduleRequestItem(
      requestId: 0,
      establishmentId: establishmentId,
      year: year,
      month: month,
      selectedDays: List<int>.from(selectedDays)..sort(),
      status: 'pending',
      comment: comment,
      createdAt: null,
      updatedAt: null,
    );
  }

  Future<void> requestSwap({
    required int establishmentId,
    required String shiftDate,
    String? reason,
  }) async {
    final token = await _token();

    final uri = Uri.parse('${AppConfig.baseUrl}/api/v1/staff/swap/request');

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
        if (reason != null && reason.trim().isNotEmpty)
          'reason': reason.trim(),
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'request swap failed: ${response.statusCode} body=${response.body}',
      );
    }
  }

  Future<void> submitSwapRequest({
    required int establishmentId,
    required String shiftDate,
    String? reason,
  }) async {
    await requestSwap(
      establishmentId: establishmentId,
      shiftDate: shiftDate,
      reason: reason,
    );
  }
}