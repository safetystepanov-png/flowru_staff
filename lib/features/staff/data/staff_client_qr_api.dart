import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_storage.dart';
import '../../auth/data/session_expired_exception.dart';
import '../../auth/data/user_api.dart';

class StaffResolvedQrClient {
  final String clientId;
  final String coreClientId;
  final String clientName;
  final String phone;
  final int establishmentId;
  final String establishmentName;
  final int points;
  final int visits;
  final bool created;
  final String message;

  const StaffResolvedQrClient({
    required this.clientId,
    required this.coreClientId,
    required this.clientName,
    required this.phone,
    required this.establishmentId,
    required this.establishmentName,
    required this.points,
    required this.visits,
    required this.created,
    required this.message,
  });

  factory StaffResolvedQrClient.fromJson(Map<String, dynamic> json) {
    final rawClient = json['client'];

    final client = rawClient is Map
        ? Map<String, dynamic>.from(rawClient)
        : json;

    final rawEstablishment = json['establishment'];

    final establishment = rawEstablishment is Map
        ? Map<String, dynamic>.from(rawEstablishment)
        : <String, dynamic>{};

    return StaffResolvedQrClient(
      clientId:
          (client['client_id'] ??
                  client['client_legacy_id'] ??
                  client['legacy_id'] ??
                  client['id'] ??
                  json['client_id'] ??
                  json['id'] ??
                  '')
              .toString(),
      coreClientId: (client['id'] ?? json['id'] ?? '').toString(),
      clientName:
          (client['name'] ??
                  client['full_name'] ??
                  client['client_name'] ??
                  json['client_name'] ??
                  json['full_name'] ??
                  'Клиент')
              .toString(),
      phone: (client['phone'] ?? json['phone'] ?? '').toString(),
      establishmentId: _toInt(establishment['id'] ?? json['establishment_id']),
      establishmentName:
          (establishment['name'] ?? json['establishment_name'] ?? '')
              .toString(),
      points: _toInt(client['points'] ?? json['points']),
      visits: _toInt(client['visits'] ?? json['visits']),
      created: json['created'] == true,
      message: (json['message'] ?? '').toString(),
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value.toString().trim()) ?? 0;
  }
}

class StaffClientQrApi {
  final UserApi _userApi = UserApi();

  Future<String> _token() async {
    final token = await AuthStorage.getAccessToken();

    if (token == null || token.trim().isEmpty) {
      await AuthStorage.clearSessionButKeepBiometric();
      throw const SessionExpiredException();
    }

    return token.trim();
  }

  Future<String> _refreshAccessToken() async {
    final refreshToken = await AuthStorage.getRefreshToken();

    if (refreshToken == null || refreshToken.trim().isEmpty) {
      await AuthStorage.clearSessionButKeepBiometric();
      throw const SessionExpiredException();
    }

    final result = await _userApi.refresh(
      refreshToken: refreshToken.trim(),
      deviceId: 'staff-mobile',
      platform: 'mobile',
    );

    if (!result.ok || result.accessToken.trim().isEmpty) {
      await AuthStorage.clearSessionButKeepBiometric();

      throw SessionExpiredException(
        result.message.isNotEmpty
            ? result.message
            : 'Сессия истекла. Войдите снова.',
      );
    }

    await AuthStorage.saveAccessToken(result.accessToken);
    await AuthStorage.saveRefreshToken(result.refreshToken);

    return result.accessToken.trim();
  }

  Future<http.Response> _postResolveQr({
    required String accessToken,
    required int establishmentId,
    required String qrToken,
  }) {
    return http.post(
      Uri.parse('${AppConfig.baseUrl}/api/v1/staff/clients/resolve-qr'),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'establishment_id': establishmentId,
        'qr_token': qrToken.trim(),
      }),
    );
  }

  String _responseText(http.Response response) {
    try {
      return utf8.decode(response.bodyBytes);
    } catch (_) {
      return response.body;
    }
  }

  Map<String, dynamic>? _responseJson(http.Response response) {
    try {
      final decoded = jsonDecode(_responseText(response));

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  String _errorMessageFromResponse(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      return 'Сессия истекла. Войдите снова.';
    }

    final decoded = _responseJson(response);

    if (decoded != null) {
      final detail = decoded['detail'];
      final message = decoded['message'];
      final error = decoded['error'];

      if (detail is String && detail.trim().isNotEmpty) {
        return detail.trim();
      }

      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }

      if (error is String && error.trim().isNotEmpty) {
        return error.trim();
      }

      if (detail is Map) {
        final nested = detail['message'] ?? detail['error'];

        if (nested is String && nested.trim().isNotEmpty) {
          return nested.trim();
        }
      }
    }

    if (response.statusCode == 404) {
      return 'Клиент не найден. Проверьте QR-код и попробуйте снова.';
    }

    if (response.statusCode >= 500) {
      return 'Сервер временно недоступен. Попробуйте ещё раз.';
    }

    return 'Не удалось распознать QR клиента.';
  }

  Future<StaffResolvedQrClient> resolveClientQr({
    required int establishmentId,
    required String qrToken,
  }) async {
    final normalizedQrToken = qrToken.trim();

    if (normalizedQrToken.isEmpty) {
      throw Exception('QR-код пустой.');
    }

    var accessToken = await _token();

    var response = await _postResolveQr(
      accessToken: accessToken,
      establishmentId: establishmentId,
      qrToken: normalizedQrToken,
    );

    print('========== RESOLVE QR ==========');
    print('ESTABLISHMENT_ID=$establishmentId');
    print('QR_TOKEN=$normalizedQrToken');
    print('QR_STATUS=${response.statusCode}');
    print('QR_BODY=${utf8.decode(response.bodyBytes, allowMalformed: true)}');
    print('================================');

    if (response.statusCode == 401 || response.statusCode == 403) {
      accessToken = await _refreshAccessToken();

      response = await _postResolveQr(
        accessToken: accessToken,
        establishmentId: establishmentId,
        qrToken: normalizedQrToken,
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      await AuthStorage.clearSessionButKeepBiometric();
      throw const SessionExpiredException();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessageFromResponse(response));
    }

    final decoded = _responseJson(response);

    if (decoded == null) {
      throw Exception('Сервер вернул некорректный ответ.');
    }

    final result = StaffResolvedQrClient.fromJson(decoded);

    if (result.clientId.trim().isEmpty) {
      throw Exception('Сервер не вернул номер клиента.');
    }

    return result;
  }
}
