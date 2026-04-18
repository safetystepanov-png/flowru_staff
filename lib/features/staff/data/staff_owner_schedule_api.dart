import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_storage.dart';
import 'staff_owner_requests_api.dart';

class OwnerScheduleSaveDay {
  final DateTime date;
  final List<OwnerRequestItem> items;

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

    final uniqueLabels = _buildUniqueLabels(days);

    final payloadDays = days.map((day) {
      final y = day.date.year.toString().padLeft(4, '0');
      final m = day.date.month.toString().padLeft(2, '0');
      final d = day.date.day.toString().padLeft(2, '0');

      return {
        'date': '$y-$m-$d',
        'items': day.items.map((item) {
          final employeeUserId = item.employeeUserId.trim().isEmpty
              ? (item.isSchedule
                  ? 'employee_${item.requestId}'
                  : 'swap_${item.requestId}')
              : item.employeeUserId.trim();

          return {
            'employee_user_id': employeeUserId,
            'employee_name': item.employeeName,
            'employee_role': item.isSwap ? 'Смена' : 'Сотрудник',
            'employee_label':
                uniqueLabels[employeeUserId] ?? item.effectiveCalendarLabel,
          };
        }).toList(),
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

  Map<String, String> _buildUniqueLabels(List<OwnerScheduleSaveDay> days) {
    final grouped = <String, List<String>>{};

    for (final day in days) {
      for (final item in day.items) {
        final employeeUserId = item.employeeUserId.trim().isEmpty
            ? (item.isSchedule
                ? 'employee_${item.requestId}'
                : 'swap_${item.requestId}')
            : item.employeeUserId.trim();

        final base = item.effectiveCalendarLabel.toUpperCase();

        grouped.putIfAbsent(base, () => <String>[]);
        if (!grouped[base]!.contains(employeeUserId)) {
          grouped[base]!.add(employeeUserId);
        }
      }
    }

    final result = <String, String>{};

    grouped.forEach((base, ids) {
      ids.sort();
      for (var i = 0; i < ids.length; i++) {
        result[ids[i]] = i == 0 ? base : '$base${i + 1}';
      }
    });

    return result;
  }
}