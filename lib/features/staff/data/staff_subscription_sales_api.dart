import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/data/auth_storage.dart';
import '../../../core/config/app_config.dart';

class StaffSubscriptionSaleException implements Exception {
  final String message;
  final String? code;
  final Map<String, dynamic>? details;

  const StaffSubscriptionSaleException(this.message, {this.code, this.details});

  @override
  String toString() => message;
}

class StaffSubscriptionSalePlan {
  final int id;
  final String name;
  final double price;
  final int durationValue;
  final String durationUnit;
  final int durationDays;
  final String? usageMode;
  final num? usageLimit;

  const StaffSubscriptionSalePlan({
    required this.id,
    required this.name,
    required this.price,
    required this.durationValue,
    required this.durationUnit,
    required this.durationDays,
    required this.usageMode,
    required this.usageLimit,
  });

  factory StaffSubscriptionSalePlan.fromJson(Map<String, dynamic> json) {
    return StaffSubscriptionSalePlan(
      id: _toInt(json['id']),
      name: (json['name'] ?? 'Абонемент').toString(),
      price: _toDouble(json['price']),
      durationValue: _toInt(json['duration_value'], fallback: 30),
      durationUnit: (json['duration_unit'] ?? 'day').toString(),
      durationDays: _toInt(json['duration_days'], fallback: 30),
      usageMode: json['usage_mode']?.toString(),
      usageLimit: json['usage_limit'] as num?,
    );
  }

  String get durationLabel {
    final value = durationValue;

    switch (durationUnit.toLowerCase()) {
      case 'week':
        return '$value ${_plural(value, 'неделя', 'недели', 'недель')}';
      case 'month':
        return '$value ${_plural(value, 'месяц', 'месяца', 'месяцев')}';
      case 'year':
        return '$value ${_plural(value, 'год', 'года', 'лет')}';
      default:
        return '$value ${_plural(value, 'день', 'дня', 'дней')}';
    }
  }

  String get usageLabel {
    final mode = (usageMode ?? '').toLowerCase();

    if (mode == 'per_day') {
      final limit = usageLimit?.toInt() ?? 1;
      return '$limit ${_plural(limit, 'раз', 'раза', 'раз')} в день';
    }

    if (mode == 'per_week') {
      final limit = usageLimit?.toInt() ?? 1;
      return '$limit ${_plural(limit, 'раз', 'раза', 'раз')} в неделю';
    }

    if (mode == 'total') {
      final limit = usageLimit?.toInt() ?? 0;
      return '$limit ${_plural(limit, 'использование', 'использования', 'использований')}';
    }

    if (mode == 'unlimited') {
      return 'Без ограничений';
    }

    return 'По условиям тарифа';
  }

  static String _plural(int value, String one, String few, String many) {
    final mod10 = value % 10;
    final mod100 = value % 100;

    if (mod10 == 1 && mod100 != 11) return one;
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return few;
    }

    return many;
  }
}

class StaffSubscriptionSaleClient {
  final int id;
  final String name;
  final String phone;
  final List<StaffActiveSubscriptionSummary> activeSubscriptions;

  const StaffSubscriptionSaleClient({
    required this.id,
    required this.name,
    required this.phone,
    required this.activeSubscriptions,
  });

  factory StaffSubscriptionSaleClient.fromJson(Map<String, dynamic> json) {
    final client = json['client'] is Map<String, dynamic>
        ? json['client'] as Map<String, dynamic>
        : <String, dynamic>{};

    final rawSubscriptions = json['active_subscriptions'] is List
        ? json['active_subscriptions'] as List
        : const [];

    return StaffSubscriptionSaleClient(
      id: _toInt(client['id']),
      name: (client['name'] ?? 'Клиент').toString(),
      phone: (client['phone'] ?? '').toString(),
      activeSubscriptions: rawSubscriptions
          .whereType<Map>()
          .map(
            (item) => StaffActiveSubscriptionSummary.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
    );
  }
}

class StaffActiveSubscriptionSummary {
  final int subscriptionId;
  final int planId;
  final String planName;
  final DateTime? startsAt;
  final DateTime? endsAt;

  const StaffActiveSubscriptionSummary({
    required this.subscriptionId,
    required this.planId,
    required this.planName,
    required this.startsAt,
    required this.endsAt,
  });

  factory StaffActiveSubscriptionSummary.fromJson(Map<String, dynamic> json) {
    return StaffActiveSubscriptionSummary(
      subscriptionId: _toInt(json['subscription_id']),
      planId: _toInt(json['plan_id']),
      planName: (json['plan_name'] ?? 'Абонемент').toString(),
      startsAt: _toDateTime(json['starts_at']),
      endsAt: _toDateTime(json['ends_at']),
    );
  }
}

class StaffOfflineSubscriptionSaleResult {
  final int saleId;
  final int subscriptionId;
  final String clientName;
  final String clientPhone;
  final String planName;
  final double price;
  final int durationValue;
  final String durationUnit;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool alreadyProcessed;

  const StaffOfflineSubscriptionSaleResult({
    required this.saleId,
    required this.subscriptionId,
    required this.clientName,
    required this.clientPhone,
    required this.planName,
    required this.price,
    required this.durationValue,
    required this.durationUnit,
    required this.startsAt,
    required this.endsAt,
    required this.alreadyProcessed,
  });

  factory StaffOfflineSubscriptionSaleResult.fromJson(
    Map<String, dynamic> json,
  ) {
    final client = json['client'] is Map<String, dynamic>
        ? json['client'] as Map<String, dynamic>
        : <String, dynamic>{};

    final plan = json['plan'] is Map<String, dynamic>
        ? json['plan'] as Map<String, dynamic>
        : <String, dynamic>{};

    return StaffOfflineSubscriptionSaleResult(
      saleId: _toInt(json['sale_id']),
      subscriptionId: _toInt(json['subscription_id']),
      clientName: (client['name'] ?? 'Клиент').toString(),
      clientPhone: (client['phone'] ?? '').toString(),
      planName: (plan['name'] ?? 'Абонемент').toString(),
      price: _toDouble(plan['price']),
      durationValue: _toInt(plan['duration_value'], fallback: 30),
      durationUnit: (plan['duration_unit'] ?? 'day').toString(),
      startsAt: _toDateTime(json['starts_at']),
      endsAt: _toDateTime(json['ends_at']),
      alreadyProcessed: json['already_processed'] == true,
    );
  }
}

class StaffSubscriptionSalesApi {
  Future<String> _token() async {
    final token = await AuthStorage.getAccessToken();

    if (token == null || token.trim().isEmpty) {
      throw const StaffSubscriptionSaleException(
        'Сессия завершена. Войдите в приложение снова.',
      );
    }

    return token.trim();
  }

  Future<List<StaffSubscriptionSalePlan>> getPlans({
    required int establishmentId,
  }) async {
    final token = await _token();

    final uri =
        Uri.parse(
          '${AppConfig.baseUrl}/api/v1/staff/subscription-sales/plans',
        ).replace(
          queryParameters: {'establishment_id': establishmentId.toString()},
        );

    final response = await http.get(uri, headers: _headers(token));

    final decoded = _decodeResponse(response);

    final items = decoded['items'] is List
        ? decoded['items'] as List
        : const [];

    return items
        .whereType<Map>()
        .map(
          (item) => StaffSubscriptionSalePlan.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<StaffSubscriptionSaleClient> getClient({
    required int establishmentId,
    required int clientId,
  }) async {
    final token = await _token();

    final uri = Uri.parse(
      '${AppConfig.baseUrl}/api/v1/staff/subscription-sales/client/$clientId',
    ).replace(queryParameters: {'establishment_id': establishmentId.toString()});

    final response = await http.get(uri, headers: _headers(token));

    return StaffSubscriptionSaleClient.fromJson(_decodeResponse(response));
  }

  Future<StaffOfflineSubscriptionSaleResult> activateOffline({
    required int establishmentId,
    required int clientId,
    required int planId,
    required String paymentMethod,
    required String idempotencyKey,
    String? receiptNumber,
  }) async {
    final token = await _token();

    final response = await http.post(
      Uri.parse(
        '${AppConfig.baseUrl}/api/v1/staff/subscription-sales/offline/activate',
      ),
      headers: _headers(token),
      body: jsonEncode({
        'establishment_id': establishmentId,
        'client_id': clientId,
        'plan_id': planId,
        'payment_method': paymentMethod,
        'receipt_number': _cleanNullable(receiptNumber),
        'payment_note': 'Оплата подтверждена сотрудником в Staff App',
        'idempotency_key': idempotencyKey,
      }),
    );

    return StaffOfflineSubscriptionSaleResult.fromJson(
      _decodeResponse(response),
    );
  }

  Map<String, String> _headers(String token) {
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    Map<String, dynamic> decoded = <String, dynamic>{};

    if (response.body.trim().isNotEmpty) {
      try {
        final raw = jsonDecode(utf8.decode(response.bodyBytes));

        if (raw is Map<String, dynamic>) {
          decoded = raw;
        } else if (raw is Map) {
          decoded = Map<String, dynamic>.from(raw);
        }
      } catch (_) {}
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final detail = decoded['detail'];

    if (detail is Map) {
      final details = Map<String, dynamic>.from(detail);
      final message = (details['message'] ?? 'Не удалось выполнить операцию')
          .toString();

      throw StaffSubscriptionSaleException(
        message,
        code: details['code']?.toString(),
        details: details,
      );
    }

    if (detail is String && detail.trim().isNotEmpty) {
      throw StaffSubscriptionSaleException(detail.trim());
    }

    throw StaffSubscriptionSaleException(
      'Ошибка сервера: ${response.statusCode}',
    );
  }
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _toDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

String? _cleanNullable(String? value) {
  final clean = value?.trim() ?? '';
  return clean.isEmpty ? null : clean;
}
