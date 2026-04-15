import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_storage.dart';

class StaffRewardItem {
  final String rewardId;
  final String title;
  final String? description;
  final int pointsCost;
  final bool isActive;

  StaffRewardItem({
    required this.rewardId,
    required this.title,
    required this.description,
    required this.pointsCost,
    required this.isActive,
  });

  factory StaffRewardItem.fromJson(Map<String, dynamic> json) {
    return StaffRewardItem(
      rewardId: json['reward_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      pointsCost: (json['points_cost'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class StaffRewardRedeemResult {
  final bool ok;
  final String message;
  final String? redemptionId;
  final int clientPoints;

  StaffRewardRedeemResult({
    required this.ok,
    required this.message,
    required this.redemptionId,
    required this.clientPoints,
  });

  factory StaffRewardRedeemResult.fromJson(Map<String, dynamic> json) {
    return StaffRewardRedeemResult(
      ok: json['ok'] as bool? ?? false,
      message: json['message']?.toString() ?? '',
      redemptionId: json['redemption_id']?.toString(),
      clientPoints: (json['client_points'] as num?)?.toInt() ?? 0,
    );
  }
}

class StaffRewardsApi {
  Future<String> _token() async {
    final accessToken = await AuthStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Access token not found');
    }
    return accessToken;
  }

  Future<List<StaffRewardItem>> getRewards({
    required int establishmentId,
  }) async {
    final accessToken = await _token();

    final uri = Uri.parse(
      '${AppConfig.baseUrl}/api/v1/staff/rewards?establishment_id=$establishmentId',
    );

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'GET rewards failed: ${response.statusCode} ${response.body}',
      );
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    final List items = (data['items'] as List?) ?? [];

    return items
        .map((item) => StaffRewardItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<StaffRewardRedeemResult> redeemReward({
    required int establishmentId,
    required String clientId,
    required String rewardId,
  }) async {
    final accessToken = await _token();

    final uri = Uri.parse('${AppConfig.baseUrl}/api/v1/staff/rewards/redeem');

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
        'reward_id': rewardId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'POST rewards/redeem failed: ${response.statusCode} ${response.body}',
      );
    }

    return StaffRewardRedeemResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}