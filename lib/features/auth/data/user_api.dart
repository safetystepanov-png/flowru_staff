import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';

class AuthResult {
  final bool ok;
  final String message;
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final String userId;
  final String phone;
  final String fullName;

  const AuthResult({
    required this.ok,
    required this.message,
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.userId,
    required this.phone,
    required this.fullName,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      ok: true,
      message: 'OK',
      accessToken: json['access_token']?.toString() ?? '',
      refreshToken: json['refresh_token']?.toString() ?? '',
      tokenType: json['token_type']?.toString() ?? 'bearer',
      userId: json['user_id']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
    );
  }

  factory AuthResult.error(String message) {
    return AuthResult(
      ok: false,
      message: message,
      accessToken: '',
      refreshToken: '',
      tokenType: '',
      userId: '',
      phone: '',
      fullName: '',
    );
  }
}

class UserMe {
  final String id;
  final String phone;
  final String fullName;

  const UserMe({
    required this.id,
    required this.phone,
    required this.fullName,
  });

  factory UserMe.fromJson(Map<String, dynamic> json) {
    return UserMe(
      id: json['id']?.toString() ?? json['user_id']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
    );
  }
}

class UserApi {
  Future<AuthResult> register({
    required String phone,
    required String password,
    required String passwordConfirm,
    required String fullName,
    required String deviceId,
    required String platform,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/v1/auth/register'),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'phone': phone,
        'password': password,
        'password_confirm': passwordConfirm,
        'full_name': fullName,
        'device_id': deviceId,
        'platform': platform,
      }),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return AuthResult.fromJson(decoded);
    }

    String message = 'Ошибка регистрации';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        message = decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            message;
      }
    } catch (_) {}

    return AuthResult.error(message);
  }

  Future<AuthResult> login({
    required String phone,
    required String password,
    required String deviceId,
    required String platform,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/v1/auth/login'),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'phone': phone,
        'password': password,
        'device_id': deviceId,
        'platform': platform,
      }),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return AuthResult.fromJson(decoded);
    }

    String message = 'Ошибка входа';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        message = decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            message;
      }
    } catch (_) {}

    return AuthResult.error(message);
  }

  static Future<UserMe> getMe(String accessToken) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/api/v1/users/me'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('getMe failed');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return UserMe.fromJson(decoded);
  }
}