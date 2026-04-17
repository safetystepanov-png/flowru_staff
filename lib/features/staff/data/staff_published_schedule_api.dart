import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_storage.dart';

class PublishedSchedulePerson {
  final String employeeUserId;
  final String employeeName;
  final String? employeeRole;

  const PublishedSchedulePerson({
    required this.employeeUserId,
    required this.employeeName,
    required this.employeeRole,
  });

  bool get isMine => employeeUserId == 'me';

  factory PublishedSchedulePerson.fromJson(Map<String, dynamic> json) {
    return PublishedSchedulePerson(
      employeeUserId: json['employee_user_id']?.toString() ?? '',
      employeeName: json['employee_name']?.toString() ?? 'Сотрудник',
      employeeRole: json['employee_role']?.toString(),
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

  factory PublishedScheduleDay.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date']?.toString() ?? '';
    final parsed = DateTime.tryParse(rawDate);
    return PublishedScheduleDay(
      date: parsed == null
          ? DateTime.now()
          : DateTime(parsed.year, parsed.month, parsed.day),
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
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

  factory PublishedScheduleMonth.fromJson(Map<String, dynamic> json) {
    return PublishedScheduleMonth(
      establishmentId: (json['establishment_id'] as num?)?.toInt() ?? 0,
      year: (json['year'] as num?)?.toInt() ?? 0,
      month: (json['month'] as num?)?.toInt() ?? 0,
      published: json['published'] == true,
      days: ((json['days'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PublishedScheduleDay.fromJson)
          .toList(),
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

    if (response.statusCode != 200) {
      throw Exception(
        'schedule month failed: ${response.statusCode} body=${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return PublishedScheduleMonth.fromJson(decoded);
  }
}
