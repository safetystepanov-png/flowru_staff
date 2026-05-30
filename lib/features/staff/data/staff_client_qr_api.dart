import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_storage.dart';

class StaffResolvedQrClient {
  final String clientId;
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
    final client = json['client'] is Map<String, dynamic>
        ? json['client'] as Map<String, dynamic>
        : <String, dynamic>{};

    final establishment = json['establishment'] is Map<String, dynamic>
        ? json['establishment'] as Map<String, dynamic>
        : <String, dynamic>{};

    return StaffResolvedQrClient(
      clientId: (client['client_id'] ?? client['id'] ?? '').toString(),
      clientName: (client['name'] ?? client['client_name'] ?? 'Клиент').toString(),
      phone: (client['phone'] ?? '').toString(),
      establishmentId: _toInt(establishment['id'] ?? json['establishment_id']),
      establishmentName: (establishment['name'] ?? '').toString(),
      points: _toInt(client['points']),
      visits: _toInt(client['visits']),
      created: json['created'] == true,
      message: (json['message'] ?? '').toString(),
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}

class StaffClientQrApi {
  static const List<String> _preferredKeys = [
    'client_id',
    'clientId',
    'legacy_id',
    'legacyId',
    'qr_token',
    'qrToken',
    'token',
    'code',
    'payload',
    'phone',
  ];

  Future<String> _token() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Access token not found');
    }
    return token;
  }

  String _firstUsefulValue(Map<dynamic, dynamic> map) {
    for (final key in _preferredKeys) {
      final value = map[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    for (final entry in map.entries) {
      final value = entry.value;
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return '';
  }

  String _extractFromUri(Uri uri) {
    for (final key in _preferredKeys) {
      final value = uri.queryParameters[key];
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    final segments = uri.pathSegments
        .map((e) => Uri.decodeComponent(e).trim())
        .where((e) => e.isNotEmpty)
        .toList();

    for (int i = 0; i < segments.length; i++) {
      final current = segments[i].toLowerCase();

      if ((current == 'client' ||
              current == 'clients' ||
              current == 'client_id' ||
              current == 'legacy_id' ||
              current == 'qr' ||
              current == 'wallet' ||
              current == 'card') &&
          i + 1 < segments.length &&
          segments[i + 1].trim().isNotEmpty) {
        return segments[i + 1].trim();
      }
    }

    if (segments.isNotEmpty) {
      return segments.last.trim();
    }

    return '';
  }

  String _extractByRegex(String value) {
    final patterns = [
      RegExp(r'(?:client_id|clientId|legacy_id|legacyId|qr_token|qrToken|token|code|payload|phone)=([^&\s]+)', caseSensitive: false),
      RegExp(r'(?:client_id|clientId|legacy_id|legacyId|qr_token|qrToken|token|code|payload|phone):([^&\s]+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(value);
      if (match != null) {
        final found = match.group(1);
        if (found != null && found.trim().isNotEmpty) {
          return Uri.decodeComponent(found.trim());
        }
      }
    }

    return '';
  }

  String _normalizeQrToken(String rawToken) {
    var value = rawToken.replaceAll('\uFEFF', '').trim();

    if (value.isEmpty) return value;

    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        final fromJson = _firstUsefulValue(decoded);
        if (fromJson.isNotEmpty) return fromJson;
      }
    } catch (_) {}

    final regexValue = _extractByRegex(value);
    if (regexValue.isNotEmpty) return regexValue;

    final uri = Uri.tryParse(value);
    if (uri != null && (uri.hasScheme || uri.hasAuthority || uri.queryParameters.isNotEmpty)) {
      final fromUri = _extractFromUri(uri);
      if (fromUri.isNotEmpty) return fromUri;
    }

    if (value.startsWith('flowru://')) {
      final flowruUri = Uri.tryParse(value);
      if (flowruUri != null) {
        final fromFlowru = _extractFromUri(flowruUri);
        if (fromFlowru.isNotEmpty) return fromFlowru;
      }
    }

    return value;
  }

  Future<StaffResolvedQrClient> resolveClientQr({
    required int establishmentId,
    required String qrToken,
  }) async {
    final token = await _token();
    final normalizedQrToken = _normalizeQrToken(qrToken);

    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/v1/staff/clients/resolve-qr'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'establishment_id': establishmentId,
        'qr_token': normalizedQrToken,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Не удалось распознать QR клиента';

      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final detail = decoded['detail'];
          if (detail is String && detail.trim().isNotEmpty) {
            message = detail.trim();
          }
        }
      } catch (_) {}

      throw Exception(message);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Некорректный ответ сервера');
    }

    return StaffResolvedQrClient.fromJson(decoded);
  }
}
