import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import '../../auth/data/auth_storage.dart';
import '../../auth/data/session_expired_exception.dart';

class StaffSubscriptionItem {
  final int planItemId;
  final int menuItemId;
  final String name;
  final String? description;
  final double quantityPerUse;
  final String unitType;
  final String? groupName;
  final bool isOptional;
  final bool canUse;
  final String? unavailableReason;

  const StaffSubscriptionItem({
    required this.planItemId,
    required this.menuItemId,
    required this.name,
    required this.description,
    required this.quantityPerUse,
    required this.unitType,
    required this.groupName,
    required this.isOptional,
    required this.canUse,
    required this.unavailableReason,
  });

  factory StaffSubscriptionItem.fromJson(Map<String, dynamic> json) {
    return StaffSubscriptionItem(
      planItemId: (json['plan_item_id'] as num?)?.toInt() ?? 0,
      menuItemId: (json['menu_item_id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'Позиция',
      description: json['description']?.toString(),
      quantityPerUse: (json['quantity_per_use'] as num?)?.toDouble() ?? 1,
      unitType: json['unit_type']?.toString() ?? 'piece',
      groupName: json['group_name']?.toString(),
      isOptional: json['is_optional'] == true,
      canUse: json['can_use'] == true,
      unavailableReason: json['unavailable_reason']?.toString(),
    );
  }
}

class StaffSubscription {
  final int id;
  final int establishmentId;
  final int clientId;
  final int planId;
  final String planName;
  final String? planDescription;
  final String status;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? pausedAt;
  final double salePrice;
  final String usageMode;
  final double? usageLimit;
  final double used;
  final double? remaining;
  final bool isUnlimited;
  final bool autoRenewEnabled;
  final List<StaffSubscriptionItem> items;

  const StaffSubscription({
    required this.id,
    required this.establishmentId,
    required this.clientId,
    required this.planId,
    required this.planName,
    required this.planDescription,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.pausedAt,
    required this.salePrice,
    required this.usageMode,
    required this.usageLimit,
    required this.used,
    required this.remaining,
    required this.isUnlimited,
    required this.autoRenewEnabled,
    required this.items,
  });

  factory StaffSubscription.fromJson(Map<String, dynamic> json) {
    DateTime? date(dynamic v) {
      final s = v?.toString();
      return (s == null || s.isEmpty) ? null : DateTime.tryParse(s)?.toLocal();
    }

    final rawItems = (json['items'] as List?) ?? const [];

    return StaffSubscription(
      id: (json['id'] as num?)?.toInt() ?? 0,
      establishmentId: (json['establishment_id'] as num?)?.toInt() ?? 0,
      clientId: (json['client_id'] as num?)?.toInt() ?? 0,
      planId: (json['plan_id'] as num?)?.toInt() ?? 0,
      planName: json['plan_name']?.toString() ?? 'Абонемент',
      planDescription: json['plan_description']?.toString(),
      status: json['status']?.toString() ?? 'active',
      startsAt: date(json['starts_at']),
      endsAt: date(json['ends_at']),
      pausedAt: date(json['paused_at']),
      salePrice: (json['sale_price'] as num?)?.toDouble() ?? 0,
      usageMode: json['usage_mode']?.toString() ?? 'total',
      usageLimit: (json['usage_limit'] as num?)?.toDouble(),
      used: (json['used'] as num?)?.toDouble() ?? 0,
      remaining: (json['remaining'] as num?)?.toDouble(),
      isUnlimited: json['is_unlimited'] == true,
      autoRenewEnabled: json['auto_renew_enabled'] == true,
      items: rawItems
          .whereType<Map>()
          .map(
            (e) => StaffSubscriptionItem.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'active':
        return 'Активен';
      case 'paused':
        return 'Приостановлен';
      case 'pending':
        return 'Ожидает активации';
      case 'expired':
        return 'Завершён';
      case 'cancelled':
        return 'Отменён';
      default:
        return status;
    }
  }

  String get remainingLabel {
    if (isUnlimited) return 'Без ограничений';
    final v = remaining ?? 0;
    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
  }
}

class StaffSubscriptionUseResult {
  final int usageEventId;
  final StaffSubscription? subscription;
  const StaffSubscriptionUseResult({
    required this.usageEventId,
    required this.subscription,
  });
}

class StaffSubscriptionsApi {
  Future<String> _token() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.trim().isEmpty) {
      await AuthStorage.clearSessionButKeepBiometric();
      throw const SessionExpiredException();
    }
    return token.trim();
  }

  Future<void> _check(http.Response r) async {
    if (r.statusCode == 401 || r.statusCode == 403) {
      await AuthStorage.clearSessionButKeepBiometric();
      throw const SessionExpiredException();
    }
  }

  String _error(http.Response r) {
    try {
      final d = jsonDecode(r.body);
      if (d is Map && d['detail'] != null) return d['detail'].toString();
    } catch (_) {}
    return 'Ошибка ${r.statusCode}';
  }

  Future<List<StaffSubscription>> getClientSubscriptions({
    required int establishmentId,
    required String clientId,
  }) async {
    final token = await _token();
    final uri = Uri.parse(
      '${AppConfig.baseUrl}/api/v1/staff/clients/subscriptions'
      '?establishment_id=$establishmentId'
      '&client_id=${Uri.encodeQueryComponent(clientId)}',
    );
    final r = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    await _check(r);
    if (r.statusCode != 200) throw Exception(_error(r));
    final d = jsonDecode(r.body);
    final items = d is Map ? (d['items'] as List? ?? const []) : const [];
    return items
        .whereType<Map>()
        .map((e) => StaffSubscription.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<StaffSubscriptionUseResult> useItem({
    required int establishmentId,
    required int clientId,
    required int subscriptionId,
    required int menuItemId,
    double quantity = 1,
  }) async {
    final token = await _token();
    final uri = Uri.parse(
      '${AppConfig.baseUrl}/api/v1/staff/subscriptions/$subscriptionId/use',
    );
    final r = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'establishment_id': establishmentId,
        'client_id': clientId,
        'menu_item_id': menuItemId,
        'quantity': quantity,
        'idempotency_key':
            'staff-$subscriptionId-$menuItemId-${DateTime.now().microsecondsSinceEpoch}',
      }),
    );
    await _check(r);
    if (r.statusCode != 200) throw Exception(_error(r));
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    final raw = d['subscription'];
    return StaffSubscriptionUseResult(
      usageEventId: (d['usage_event_id'] as num?)?.toInt() ?? 0,
      subscription: raw is Map
          ? StaffSubscription.fromJson(Map<String, dynamic>.from(raw))
          : null,
    );
  }
}
