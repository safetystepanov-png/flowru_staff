import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_storage.dart';

class OwnerRequestItem {
  final int requestId;
  final String requestType;
  final String employeeUserId;
  final String employeeName;
  final String? employeeLabel;
  final String subtitle;
  final String status;
  final String? createdAt;
  final List<int> selectedDays;
  final int? year;
  final int? month;
  final String? shiftDate;
  final String? comment;
  final String? reason;
  final String? employeeRole;
  final String? employeePhone;

  const OwnerRequestItem({
    required this.requestId,
    required this.requestType,
    required this.employeeUserId,
    required this.employeeName,
    required this.employeeLabel,
    required this.subtitle,
    required this.status,
    required this.createdAt,
    required this.selectedDays,
    required this.year,
    required this.month,
    required this.shiftDate,
    required this.comment,
    required this.reason,
    required this.employeeRole,
    required this.employeePhone,
  });

  bool get isSchedule => requestType == 'schedule';
  bool get isSwap => requestType == 'swap';

  String get typeLabel => isSchedule ? 'График' : 'Замена';

  String get effectiveCalendarLabel {
    if (employeeLabel != null && employeeLabel!.trim().isNotEmpty) {
      return employeeLabel!.trim().toUpperCase();
    }
    return buildBaseLabel(employeeName);
  }

  String get effectiveRole {
    final role = employeeRole?.trim();
    if (role != null && role.isNotEmpty) return role;
    return isSwap ? 'Смена' : 'Сотрудник';
  }

  factory OwnerRequestItem.fromScheduleJson(Map<String, dynamic> json) {
    final employeeName = json['employee_name']?.toString().trim().isNotEmpty ==
            true
        ? json['employee_name']!.toString().trim()
        : 'Сотрудник';

    final employeeLabel = json['employee_label']?.toString();
    final year = (json['year'] as num?)?.toInt();
    final month = (json['month'] as num?)?.toInt();
    final days = ((json['selected_days'] as List?) ?? const [])
        .map((e) => int.tryParse(e.toString()) ?? 0)
        .where((e) => e > 0)
        .toList()
      ..sort();

    final monthLabel = _monthRu(month);
    final subtitle = year != null && monthLabel.isNotEmpty
        ? '$employeeName · $monthLabel $year · ${days.length} дн.'
        : '$employeeName · ${days.length} дн.';

    return OwnerRequestItem(
      requestId: (json['request_id'] as num?)?.toInt() ?? 0,
      requestType: 'schedule',
      employeeUserId: json['employee_user_id']?.toString() ?? '',
      employeeName: employeeName,
      employeeLabel: employeeLabel,
      subtitle: subtitle,
      status: json['status']?.toString() ?? 'pending',
      createdAt: json['created_at']?.toString(),
      selectedDays: days,
      year: year,
      month: month,
      shiftDate: null,
      comment: json['comment']?.toString(),
      reason: null,
      employeeRole: json['employee_role']?.toString(),
      employeePhone: json['employee_phone']?.toString(),
    );
  }

  factory OwnerRequestItem.fromSwapJson(Map<String, dynamic> json) {
    final employeeName = json['requester_name']?.toString().trim().isNotEmpty ==
            true
        ? json['requester_name']!.toString().trim()
        : 'Сотрудник';

    final employeeLabel = json['employee_label']?.toString();
    final shiftDate = json['shift_date']?.toString();
    final subtitle = shiftDate == null || shiftDate.isEmpty
        ? employeeName
        : '$employeeName · ${_formatDate(shiftDate)}';

    return OwnerRequestItem(
      requestId: (json['request_id'] as num?)?.toInt() ?? 0,
      requestType: 'swap',
      employeeUserId: json['requester_user_id']?.toString() ?? '',
      employeeName: employeeName,
      employeeLabel: employeeLabel,
      subtitle: subtitle,
      status: json['status']?.toString() ?? 'pending',
      createdAt: json['created_at']?.toString(),
      selectedDays: const [],
      year: null,
      month: null,
      shiftDate: shiftDate,
      comment: null,
      reason: json['reason']?.toString(),
      employeeRole: json['employee_role']?.toString(),
      employeePhone: json['employee_phone']?.toString(),
    );
  }

  static String buildBaseLabel(String rawName) {
    final name = rawName.trim();
    if (name.isEmpty || name.toLowerCase() == 'сотрудник') return 'EMP';

    final parts = name
        .split(RegExp(r'\s+'))
        .where((e) => e.trim().isNotEmpty)
        .toList();

    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }

    final word = parts.first.toUpperCase();
    if (word.length >= 3) return word.substring(0, 3);
    if (word.length == 2) return word;
    return '${word}X';
  }

  static String _monthRu(int? month) {
    switch (month) {
      case 1:
        return 'январь';
      case 2:
        return 'февраль';
      case 3:
        return 'март';
      case 4:
        return 'апрель';
      case 5:
        return 'май';
      case 6:
        return 'июнь';
      case 7:
        return 'июль';
      case 8:
        return 'август';
      case 9:
        return 'сентябрь';
      case 10:
        return 'октябрь';
      case 11:
        return 'ноябрь';
      case 12:
        return 'декабрь';
      default:
        return '';
    }
  }

  static String _formatDate(String raw) {
    final parts = raw.split('-');
    if (parts.length != 3) return raw;
    return '${parts[2]}.${parts[1]}.${parts[0]}';
  }
}

class OwnerRequestsBundle {
  final List<OwnerRequestItem> items;

  const OwnerRequestsBundle({
    required this.items,
  });

  int get scheduleCount => items.where((e) => e.isSchedule).length;
  int get swapCount => items.where((e) => e.isSwap).length;
}

class StaffOwnerRequestsApi {
  const StaffOwnerRequestsApi();

  Future<String> _token() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Access token not found');
    }
    return token;
  }

  Future<OwnerRequestsBundle> getOwnerRequests({
    required int establishmentId,
  }) async {
    final token = await _token();

    final uri = Uri.parse(
      '${AppConfig.baseUrl}/api/v1/staff/owner/requests?establishment_id=$establishmentId',
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
        'owner requests failed: ${response.statusCode} body=${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    final scheduleItems = ((decoded['schedule_requests'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(OwnerRequestItem.fromScheduleJson);

    final swapItems = ((decoded['swap_requests'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(OwnerRequestItem.fromSwapJson);

    final items = [...scheduleItems, ...swapItems].toList()
      ..sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));

    return OwnerRequestsBundle(items: items);
  }

  Future<void> approveRequest({
    required int establishmentId,
    required String requestType,
    required int requestId,
  }) async {
    await _changeRequestStatus(
      establishmentId: establishmentId,
      requestType: requestType,
      requestId: requestId,
      action: 'approve',
    );
  }

  Future<void> rejectRequest({
    required int establishmentId,
    required String requestType,
    required int requestId,
  }) async {
    await _changeRequestStatus(
      establishmentId: establishmentId,
      requestType: requestType,
      requestId: requestId,
      action: 'reject',
    );
  }

  Future<void> _changeRequestStatus({
    required int establishmentId,
    required String requestType,
    required int requestId,
    required String action,
  }) async {
    final token = await _token();

    final uri = Uri.parse(
      '${AppConfig.baseUrl}/api/v1/staff/owner/requests/$requestType/$requestId/$action',
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
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        '$action request failed: ${response.statusCode} body=${response.body}',
      );
    }
  }
}