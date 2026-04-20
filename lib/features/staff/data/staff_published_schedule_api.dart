import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_storage.dart';

class PublishedSchedulePerson {
  final String employeeUserId;
  final String employeeName;
  final String? employeeRole;
  final String? employeeLabel;
  final bool isMine;

  const PublishedSchedulePerson({
    required this.employeeUserId,
    required this.employeeName,
    required this.employeeRole,
    required this.employeeLabel,
    required this.isMine,
  });

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final s = value?.toString().trim().toLowerCase() ?? '';
    return s == 'true' || s == '1' || s == 'yes' || s == 'y';
  }

  factory PublishedSchedulePerson.fromJson(Map<String, dynamic> json) {
    return PublishedSchedulePerson(
      employeeUserId: (json['employee_user_id'] ??
              json['user_id'] ??
              json['staff_user_id'] ??
              json['employee_id'] ??
              '')
          .toString(),
      employeeName: (json['employee_name'] ??
              json['name'] ??
              json['employee'] ??
              json['full_name'] ??
              'Сотрудник')
          .toString(),
      employeeRole: (json['employee_role'] ??
              json['role'] ??
              json['position'] ??
              json['staff_role'])
          ?.toString(),
      employeeLabel:
          (json['employee_label'] ?? json['label'] ?? json['badge'])?.toString(),
      isMine: _parseBool(
        json['is_mine'] ?? json['mine'] ?? json['is_current_user'],
      ),
    );
  }
}

class PublishedScheduleDay {
  final DateTime date;
  final List<PublishedSchedulePerson> items;

  const PublishedScheduleDay({
    required this.date,
    required this.items,
  });

  static List<Map<String, dynamic>> _extractMapList(dynamic raw) {
    if (raw is! List) return <Map<String, dynamic>>[];

    return raw
        .where((e) => e is Map)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  factory PublishedScheduleDay.fromJson(Map<String, dynamic> json) {
    final rawDate =
        (json['date'] ?? json['shift_date'] ?? json['day'] ?? '').toString();
    final parsed = DateTime.tryParse(rawDate);

    final rawItems = json['items'] ??
        json['employees'] ??
        json['assignments'] ??
        json['staff'] ??
        json['workers'];

    return PublishedScheduleDay(
      date: parsed == null
          ? DateTime.now()
          : DateTime(parsed.year, parsed.month, parsed.day),
      items: _extractMapList(rawItems)
          .map(PublishedSchedulePerson.fromJson)
          .toList(),
    );
  }
}

class PublishedScheduleMonth {
  final int establishmentId;
  final int year;
  final int month;
  final bool published;
  final List<PublishedScheduleDay> days;

  const PublishedScheduleMonth({
    required this.establishmentId,
    required this.year,
    required this.month,
    required this.published,
    required this.days,
  });

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final s = value?.toString().trim().toLowerCase() ?? '';
    return s == 'true' || s == '1' || s == 'yes' || s == 'y';
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<Map<String, dynamic>> _extractMapList(dynamic raw) {
    if (raw is! List) return <Map<String, dynamic>>[];

    return raw
        .where((e) => e is Map)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Map<String, dynamic>? _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  factory PublishedScheduleMonth.fromJson(Map<String, dynamic> json) {
    final root = _asMap(
          json['data'] ?? json['month'] ?? json['schedule'] ?? json['result'],
        ) ??
        json;

    final rawDays =
        root['days'] ?? root['items'] ?? root['calendar'] ?? root['schedule_days'];

    return PublishedScheduleMonth(
      establishmentId:
          _parseInt(root['establishment_id'] ?? root['establishmentId']),
      year: _parseInt(root['year']),
      month: _parseInt(root['month']),
      published:
          _parseBool(root['published'] ?? root['is_published'] ?? root['ready']),
      days: _extractMapList(rawDays).map(PublishedScheduleDay.fromJson).toList(),
    );
  }
}

class StaffPublishedScheduleApi {
  const StaffPublishedScheduleApi();

  Future<String> _token() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Access token not found');
    }
    return token;
  }

  Future<PublishedScheduleMonth> getScheduleMonth({
    required int establishmentId,
    required int year,
    required int month,
  }) async {
    final token = await _token();

    final uri = Uri.parse(
      '${AppConfig.baseUrl}/api/v1/staff/schedule/month?establishment_id=$establishmentId&year=$year&month=$month',
    );

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    debugPrint('SCHEDULE MONTH URL: $uri');
    debugPrint('SCHEDULE MONTH STATUS: ${response.statusCode}');
    debugPrint('SCHEDULE MONTH BODY: ${response.body}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'schedule month failed: ${response.statusCode} body=${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is Map<String, dynamic>) {
      return PublishedScheduleMonth.fromJson(decoded);
    }

    if (decoded is Map) {
      return PublishedScheduleMonth.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    }

    throw Exception('schedule month invalid response: ${response.body}');
  }
}