import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_storage.dart';

class StaffClientDetailItem {
  final String clientId;
  final String? userId;
  final String? fullName;
  final String? phone;
  final String? qrCode;
  final int balance;
  final String? levelName;

  StaffClientDetailItem({
    required this.clientId,
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.qrCode,
    required this.balance,
    required this.levelName,
  });

  factory StaffClientDetailItem.fromJson(Map<String, dynamic> json) {
    return StaffClientDetailItem(
      clientId: json['client_id'] as String,
      userId: json['user_id'] as String?,
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      qrCode: json['qr_code'] as String?,
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      levelName: json['level_name'] as String?,
    );
  }
}

class StaffClientDetailApi {
  Future<StaffClientDetailItem> getClientDetail({
    required String clientId,
    required int establishmentId,
  }) async {
    final accessToken = await AuthStorage.getAccessToken();

    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Access token not found');
    }

    final uri = Uri.parse(
      '${AppConfig.baseUrl}/api/v1/staff/clients/detail'
      '?client_id=${Uri.encodeQueryComponent(clientId)}'
      '&establishment_id=$establishmentId',
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
        'Failed to load client detail. Code: ${response.statusCode}. Body: ${response.body}',
      );
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    return StaffClientDetailItem.fromJson(data);
  }
}