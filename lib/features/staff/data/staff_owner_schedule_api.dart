import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_storage.dart';

class OwnerScheduleEmployee {
  final String employeeUserId;
  final String employeeName;
  final String? employeePhone;
  final String? employeeRole;
  final String? employeeLabel;

  const OwnerScheduleEmployee({
    required this.employeeUserId,
    required this.employeeName,
    required this.employeePhone,
    required this.employeeRole,
    required this.employeeLabel,
  });

  factory OwnerScheduleEmployee.fromJson(Map<String, dynamic> json) {
    return OwnerScheduleEmployee(
      employeeUserId: json['employee_user_id']?.toString() ?? '',
      employeeName: json['employee_name']?.toString() ?? 'Сотрудник',
      employeePhone: json['employee_phone']?.toString(),
      employeeRole: json['employee_role']?.toString(),
      employeeLabel: json['employee_label']?.toString(),
    );
  }

  String get effectiveLabel {
    final raw = employeeLabel?.trim() ?? '';
    if (raw.isNotEmpty) return raw.toUpperCase();

    final parts = employeeName
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'EM';
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }

    final word = parts.first.toUpperCase();
    if (word.length >= 3) return word.substring(0, 3);
    if (word.length == 2) return word;
    return '${word}X';
  }
}

class OwnerScheduleSaveItem {
  final String employeeUserId;
  final String employeeName;
  final String? employeeRole;
  final String? employeeLabel;

  const OwnerScheduleSaveItem({
    required this.employeeUserId,
    required this.employeeName,
    required this.employeeRole,
    required this.employeeLabel,
  });

  Map<String, dynamic> toJson() {
    return {
      'employee_user_id': employeeUserId,
      'employee_name': employeeName,
      'employee_role': employeeRole,
      'employee_label': employeeLabel,
    };
  }
}

class OwnerScheduleSaveDay {
  final DateTime date;
  final List<OwnerScheduleSaveItem> items;

  const OwnerScheduleSaveDay({
    required this.date,
    required this.items,
  });
}

class StaffOwnerScheduleApi {
  const StaffOwnerScheduleApi();

  Future<String> _token() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Access token not found');
    }
    return token;
  }

  Future<List<OwnerScheduleEmployee>> getEmployees({
    required int establishmentId,
  }) async {
    final token = await _token();

    final uri = Uri.parse(
      '${AppConfig.baseUrl}/api/v1/staff/owner/schedule/employees?establishment_id=$establishmentId',
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
        'get employees failed: ${response.statusCode} body=${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is Map<String, dynamic>) {
      final items = (decoded['items'] as List?) ?? const [];
      return items
          .whereType<Map>()
          .map(
            (e) => OwnerScheduleEmployee.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();
    }

    return const <OwnerScheduleEmployee>[];
  }

  Future<void> saveScheduleMonth({
    required int establishmentId,
    required int year,
    required int month,
    required List<OwnerScheduleSaveDay> days,
  }) async {
    final token = await _token();

    final uri = Uri.parse(
      '${AppConfig.baseUrl}/api/v1/staff/owner/schedule/save',
    );

    final payloadDays = days.map((day) {
      final y = day.date.year.toString().padLeft(4, '0');
      final m = day.date.month.toString().padLeft(2, '0');
      final d = day.date.day.toString().padLeft(2, '0');

      return {
        'date': '$y-$m-$d',
        'items': day.items.map((item) => item.toJson()).toList(),
      };
    }).toList();

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
        'days': payloadDays,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'save schedule failed: ${response.statusCode} body=${response.body}',
      );
    }
  }

  Future<void> publishScheduleMonth({
    required int establishmentId,
    required int year,
    required int month,
    required List<OwnerScheduleSaveDay> days,
  }) async {
    await saveScheduleMonth(
      establishmentId: establishmentId,
      year: year,
      month: month,
      days: days,
    );
  }
}