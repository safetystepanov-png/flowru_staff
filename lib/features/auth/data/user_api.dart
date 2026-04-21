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

class RefreshResult {
  final bool ok;
  final String message;
  final String accessToken;
  final String refreshToken;
  final String tokenType;

  const RefreshResult({
    required this.ok,
    required this.message,
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
  });

  factory RefreshResult.fromJson(Map<String, dynamic> json) {
    return RefreshResult(
      ok: true,
      message: 'OK',
      accessToken: json['access_token']?.toString() ?? '',
      refreshToken: json['refresh_token']?.toString() ?? '',
      tokenType: json['token_type']?.toString() ?? 'bearer',
    );
  }

  factory RefreshResult.error(String message) {
    return RefreshResult(
      ok: false,
      message: message,
      accessToken: '',
      refreshToken: '',
      tokenType: '',
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

class AccessProfileUser {
  final String id;
  final String phone;
  final bool phoneVerified;
  final String fullName;
  final String email;
  final bool isActive;

  const AccessProfileUser({
    required this.id,
    required this.phone,
    required this.phoneVerified,
    required this.fullName,
    required this.email,
    required this.isActive,
  });

  factory AccessProfileUser.fromJson(Map<String, dynamic> json) {
    return AccessProfileUser(
      id: json['id']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      phoneVerified: json['phone_verified'] as bool? ?? false,
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      isActive: json['is_active'] as bool? ?? false,
    );
  }
}

class AccessProfileEstablishment {
  final int id;
  final String name;
  final String role;
  final String paidUntil;
  final String subscriptionStatus;
  final bool accessActive;

  const AccessProfileEstablishment({
    required this.id,
    required this.name,
    required this.role,
    required this.paidUntil,
    required this.subscriptionStatus,
    required this.accessActive,
  });

  factory AccessProfileEstablishment.fromJson(Map<String, dynamic> json) {
    return AccessProfileEstablishment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      paidUntil: json['paid_until']?.toString() ?? '',
      subscriptionStatus: json['subscription_status']?.toString() ?? '',
      accessActive: json['access_active'] as bool? ?? false,
    );
  }
}

class AccessProfile {
  final AccessProfileUser? user;
  final List<String> roles;
  final bool hasAccess;
  final List<AccessProfileEstablishment> establishments;

  const AccessProfile({
    required this.user,
    required this.roles,
    required this.hasAccess,
    required this.establishments,
  });

  factory AccessProfile.fromJson(Map<String, dynamic> json) {
    final rolesRaw = (json['roles'] as List?) ?? const [];
    final establishmentsRaw = (json['establishments'] as List?) ?? const [];

    return AccessProfile(
      user: json['user'] is Map<String, dynamic>
          ? AccessProfileUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      roles: rolesRaw.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList(),
      hasAccess: json['has_access'] as bool? ?? false,
      establishments: establishmentsRaw
          .whereType<Map<String, dynamic>>()
          .map(AccessProfileEstablishment.fromJson)
          .toList(),
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

  Future<RefreshResult> refresh({
    required String refreshToken,
    required String deviceId,
    required String platform,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/v1/auth/refresh'),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'refresh_token': refreshToken,
        'device_id': deviceId,
        'platform': platform,
      }),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return RefreshResult.fromJson(decoded);
    }

    String message = 'Не удалось обновить сессию';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        message = decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            message;
      }
    } catch (_) {}

    return RefreshResult.error(message);
  }

  static Future<UserMe> getMe(String accessToken) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/api/v1/users/me'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('GET me failed: ${response.statusCode} ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return UserMe.fromJson(decoded);
  }

  static Future<AccessProfile> getAccessProfile(String accessToken) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/api/v1/users/access-profile'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'GET access-profile failed: ${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return AccessProfile.fromJson(decoded);
  }
}
