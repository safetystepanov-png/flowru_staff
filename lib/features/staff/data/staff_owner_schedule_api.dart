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

    final payloadDays = days.map((day) {
      final y = day.date.year.toString().padLeft(4, '0');
      final m = day.date.month.toString().padLeft(2, '0');
      final d = day.date.day.toString().padLeft(2, '0');

      return {
        'date': '$y-$m-$d',
        'items': day.items
            .map(
              (item) => {
                'employee_user_id': item.isSchedule
                    ? (item.employeeName == 'Сотрудник'
                        ? 'employee_${item.requestId}'
                        : 'employee_${item.requestId}')
                    : (item.employeeName == 'Сотрудник'
                        ? 'swap_${item.requestId}'
                        : 'swap_${item.requestId}'),
                'employee_name': item.employeeName,
                'employee_role': item.isSwap ? 'Смена' : 'Сотрудник',
              },
            )
            .toList(),
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

    if (response.statusCode != 200) {
      throw Exception(
        'save schedule failed: ${response.statusCode} body=${response.body}',
      );
    }
  }
}
