import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_storage.dart';

class StaffLoyaltyConfig {
  final String mode;
  final String accrualType;
  final int fixedPointsPerPurchase;
  final int pointsPer100Rub;
  final double redeemRate;
  final int maxRedeemPercent;
  final bool pointsEnabledInDiscountMode;
  final int cashbackPercent;
  final List<Map<String, dynamic>> cashbackLevels;
  final List<Map<String, dynamic>> levels;
  final int clientVisits;
  final double clientTotalSpent;
  final int clientBalance;

  StaffLoyaltyConfig({
    required this.mode,
    required this.accrualType,
    required this.fixedPointsPerPurchase,
    required this.pointsPer100Rub,
    required this.redeemRate,
    required this.maxRedeemPercent,
    required this.pointsEnabledInDiscountMode,
    required this.cashbackPercent,
    required this.cashbackLevels,
    required this.levels,
    required this.clientVisits,
    required this.clientTotalSpent,
    required this.clientBalance,
  });

  factory StaffLoyaltyConfig.fromJson(Map<String, dynamic> json) {
    return StaffLoyaltyConfig(
      mode: (json['mode']?.toString() ?? 'points').trim(),
      accrualType: (json['accrual_type']?.toString() ?? 'per_purchase').trim(),
      fixedPointsPerPurchase:
          (json['fixed_points_per_purchase'] as num?)?.toInt() ?? 0,
      pointsPer100Rub: (json['points_per_100_rub'] as num?)?.toInt() ?? 0,
      redeemRate: (json['redeem_rate'] as num?)?.toDouble() ?? 1.0,
      maxRedeemPercent: (json['max_redeem_percent'] as num?)?.toInt() ?? 30,
      pointsEnabledInDiscountMode:
          json['points_enabled_in_discount_mode'] as bool? ?? false,
      cashbackPercent: (json['cashback_percent'] as num?)?.toInt() ?? 0,
      cashbackLevels:
          ((json['cashback_levels'] as List?) ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
      levels:
          ((json['levels'] as List?) ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
      clientVisits: (json['client_visits'] as num?)?.toInt() ?? 0,
      clientTotalSpent:
          (json['client_total_spent'] as num?)?.toDouble() ?? 0.0,
      clientBalance: (json['client_balance'] as num?)?.toInt() ?? 0,
    );
  }
}

class StaffAccrualResult {
  final bool ok;
  final String message;
  final int added;
  final int clientPoints;
  final String? label;

  StaffAccrualResult({
    required this.ok,
    required this.message,
    required this.added,
    required this.clientPoints,
    required this.label,
  });

  factory StaffAccrualResult.fromJson(Map<String, dynamic> json) {
    return StaffAccrualResult(
      ok: json['ok'] as bool? ?? false,
      message: json['message']?.toString() ?? '',
      added: (json['added'] as num?)?.toInt() ?? 0,
      clientPoints: (json['client_points'] as num?)?.toInt() ?? 0,
      label: json['label']?.toString(),
    );
  }
}

class StaffSpendResult {
  final bool ok;
  final String message;
  final int redeemed;
  final int clientPoints;
  final double payable;

  StaffSpendResult({
    required this.ok,
    required this.message,
    required this.redeemed,
    required this.clientPoints,
    required this.payable,
  });

  factory StaffSpendResult.fromJson(Map<String, dynamic> json) {
    return StaffSpendResult(
      ok: json['ok'] as bool? ?? false,
      message: json['message']?.toString() ?? '',
      redeemed: (json['redeemed'] as num?)?.toInt() ?? 0,
      clientPoints: (json['client_points'] as num?)?.toInt() ?? 0,
      payable: (json['payable'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class StaffLoyaltyApi {
  Future<String> _token() async {
    final accessToken = await AuthStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Access token not found');
    }
    return accessToken;
  }

  Future<StaffLoyaltyConfig> getLoyaltyConfig({
    required int establishmentId,
    required String clientId,
  }) async {
    final accessToken = await _token();

    final uri = Uri.parse(
      '${AppConfig.baseUrl}/api/v1/staff/loyalty/config?establishment_id=$establishmentId&client_id=$clientId',
    );

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      return StaffLoyaltyConfig.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    return StaffLoyaltyConfig(
      mode: 'points',
      accrualType: 'per_amount',
      fixedPointsPerPurchase: 10,
      pointsPer100Rub: 5,
      redeemRate: 1.0,
      maxRedeemPercent: 30,
      pointsEnabledInDiscountMode: false,
      cashbackPercent: 5,
      cashbackLevels: const [],
      levels: const [],
      clientVisits: 0,
      clientTotalSpent: 0.0,
      clientBalance: 0,
    );
  }

  Future<StaffAccrualResult> accrue({
    required int establishmentId,
    required String clientId,
    required double amount,
  }) async {
    final accessToken = await _token();

    final uri = Uri.parse('${AppConfig.baseUrl}/api/v1/staff/accrual');

    final response = await http.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'establishment_id': establishmentId,
        'client_id': clientId,
        'amount': amount,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'POST accrual failed: ${response.statusCode} ${response.body}',
      );
    }

    return StaffAccrualResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<StaffSpendResult> spend({
    required int establishmentId,
    required String clientId,
    required double amount,
    int? redeemPoints,
  }) async {
    final accessToken = await _token();

    final uri = Uri.parse('${AppConfig.baseUrl}/api/v1/staff/spend');

    final payload = <String, dynamic>{
      'establishment_id': establishmentId,
      'client_id': clientId,
      'amount': amount,
    };

    if (redeemPoints != null && redeemPoints > 0) {
      payload['redeem_points'] = redeemPoints;
    }

    final response = await http.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'POST spend failed: ${response.statusCode} ${response.body}',
      );
    }

    return StaffSpendResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}