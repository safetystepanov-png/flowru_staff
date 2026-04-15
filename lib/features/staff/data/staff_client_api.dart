import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_storage.dart';

class StaffClientSearchItem {
  final String clientId;
  final String? userId;
  final String? fullName;
  final String? phone;
  final String? qrCode;
  final int balance;
  final String? levelName;

  StaffClientSearchItem({
    required this.clientId,
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.qrCode,
    required this.balance,
    required this.levelName,
  });

  factory StaffClientSearchItem.fromJson(Map<String, dynamic> json) {
    return StaffClientSearchItem(
      clientId: json['client_id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      fullName: json['full_name']?.toString(),
      phone: json['phone']?.toString(),
      qrCode: json['qr_code']?.toString(),
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      levelName: json['level_name']?.toString(),
    );
  }
}

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
      clientId: json['client_id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      fullName: json['full_name']?.toString(),
      phone: json['phone']?.toString(),
      qrCode: json['qr_code']?.toString(),
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      levelName: json['level_name']?.toString(),
    );
  }
}

class StaffClientApi {
  Future<String> _token() async {
    final accessToken = await AuthStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Access token not found');
    }
    return accessToken;
  }

  Future<List<StaffClientSearchItem>> searchClients({
    required int establishmentId,
    required String query,
  }) async {
    final accessToken = await _token();

    final uri = Uri.parse(
      '${AppConfig.baseUrl}/api/v1/staff/clients/search?q=${Uri.encodeQueryComponent(query)}&establishment_id=$establishmentId',
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
        'GET search clients failed: ${response.statusCode} ${response.body}',
      );
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    final List items = (data['items'] as List?) ?? [];

    return items
        .map(
          (item) => StaffClientSearchItem.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<StaffClientDetailItem> getClientDetail({
    required int establishmentId,
    required String clientId,
  }) async {
    final accessToken = await _token();

    final uri = Uri.parse(
      '${AppConfig.baseUrl}/api/v1/staff/clients/detail?client_id=$clientId&establishment_id=$establishmentId',
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
        'GET client detail failed: ${response.statusCode} ${response.body}',
      );
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    return StaffClientDetailItem.fromJson(data);
  }
}