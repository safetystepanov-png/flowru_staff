import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_storage.dart';

class StaffSpendResult {
  final bool success;
  final String clientId;
  final int establishmentId;
  final double amountSpent;
  final double newBalance;
  final double lifetimeSpent;

  StaffSpendResult({
    required this.success,
    required this.clientId,
    required this.establishmentId,
    required this.amountSpent,
    required this.newBalance,
    required this.lifetimeSpent,
  });

  factory StaffSpendResult.fromJson(Map<String, dynamic> json) {
    return StaffSpendResult(
      success: json['success'] as bool,
      clientId: json['client_id'] as String,
      establishmentId: json['establishment_id'] as int,
      amountSpent: (json['amount_spent'] as num).toDouble(),
      newBalance: (json['new_balance'] as num).toDouble(),
      lifetimeSpent: (json['lifetime_spent'] as num).toDouble(),
    );
  }
}

class StaffSpendApi {
  Future<StaffSpendResult> spendPoints({
    required String clientId,
    required int establishmentId,
    required double amount,
    String? comment,
  }) async {
    final accessToken = await AuthStorage.getAccessToken();

    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Access token not found');
    }

    final uri = Uri.parse('${AppConfig.baseUrl}/api/v1/staff/clients/spend');

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
        'Failed to spend points. Code: ${response.statusCode}. Body: ${response.body}',
      );
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    return StaffSpendResult.fromJson(data);
  }
}