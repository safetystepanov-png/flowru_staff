import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_storage.dart';

class StaffAccrualResult {
  final bool success;
  final String clientId;
  final int establishmentId;
  final double amountAdded;
  final double newBalance;
  final double lifetimeEarned;

  StaffAccrualResult({
    required this.success,
    required this.clientId,
    required this.establishmentId,
    required this.amountAdded,
    required this.newBalance,
    required this.lifetimeEarned,
  });

  factory StaffAccrualResult.fromJson(Map<String, dynamic> json) {
    return StaffAccrualResult(
      success: json['success'] as bool,
      clientId: json['client_id'] as String,
      establishmentId: json['establishment_id'] as int,
      amountAdded: (json['amount_added'] as num).toDouble(),
      newBalance: (json['new_balance'] as num).toDouble(),
      lifetimeEarned: (json['lifetime_earned'] as num).toDouble(),
    );
  }
}

class StaffPointsApi {
  Future<StaffAccrualResult> accruePoints({
    required String clientId,
    required int establishmentId,
    required double amount,
    String? comment,
  }) async {
    final accessToken = await AuthStorage.getAccessToken();

    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Access token not found');
    }

    final uri = Uri.parse('${AppConfig.baseUrl}/api/v1/staff/clients/accrual');

    final response = await http.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'client_id': clientId,
        'establishment_id': establishmentId,
        'amount': amount,
        'comment': comment,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to accrue points. Code: ${response.statusCode}. Body: ${response.body}',
      );
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    return StaffAccrualResult.fromJson(data);
  }
}