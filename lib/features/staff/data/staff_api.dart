import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_storage.dart';

class StaffEstablishmentItem {
  final String membershipId;
  final int establishmentId;
  final String establishmentName;
  final String role;
  final bool isActive;
  final String? joinedAt;

  StaffEstablishmentItem({
    required this.membershipId,
    required this.establishmentId,
    required this.establishmentName,
    required this.role,
    required this.isActive,
    required this.joinedAt,
  });

  factory StaffEstablishmentItem.fromJson(Map<String, dynamic> json) {
    return StaffEstablishmentItem(
      membershipId: json['membership_id']?.toString() ?? '',
      establishmentId: json['establishment_id'] as int,
      establishmentName: json['establishment_name']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      isActive: json['is_active'] as bool? ?? false,
      joinedAt: json['joined_at']?.toString(),
    );
  }
}

class StaffApi {
  Future<String> _token() async {
    final accessToken = await AuthStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Access token not found');
    }
    return accessToken;
  }

  Future<List<StaffEstablishmentItem>> getEstablishments() async {
    final accessToken = await _token();

    final uri = Uri.parse(
      '${AppConfig.baseUrl}/api/v1/staff/establishments',
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
        'GET establishments failed: ${response.statusCode} ${response.body}',
      );
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    final List items = (data['items'] as List?) ?? [];

    return items
        .map((item) => StaffEstablishmentItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}