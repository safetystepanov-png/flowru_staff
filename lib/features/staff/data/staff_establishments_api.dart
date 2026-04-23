import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/data/auth_storage.dart';
import '../../../core/config/app_config.dart';

class StaffEstablishmentItem {
  final int id;
  final String name;
  final String role;

  const StaffEstablishmentItem({
    required this.id,
    required this.name,
    required this.role,
  });

  factory StaffEstablishmentItem.fromJson(Map<String, dynamic> json) {
    int parseId(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return StaffEstablishmentItem(
      id: parseId(
        json['establishment_id'] ?? json['id'],
      ),
      name: (json['establishment_name'] ??
                  json['name'] ??
                  json['title'] ??
                  'Заведение')
              .toString()
              .trim(),
      role: (json['role'] ?? json['staff_role'] ?? 'staff')
          .toString()
          .trim(),
    );
  }
}

class StaffEstablishmentsApi {

Future<List<StaffEstablishmentItem>> getEstablishments() async {
  final token = await AuthStorage.getAccessToken();
  if (token == null || token.isEmpty) {
    throw Exception('Токен не найден');
  }

  final uri = Uri.parse('${AppConfig.baseUrl}/api/v1/staff/establishments');
  Object? lastError;

  for (int attempt = 1; attempt <= 2; attempt++) {
    try {
      final response = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        if (response.statusCode >= 500 && attempt < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 650));
          continue;
        }
        throw Exception(
          'Ошибка загрузки заведений: ${response.statusCode} ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);

      List<dynamic> rawItems = [];

      if (decoded is List) {
        rawItems = decoded;
      } else if (decoded is Map<String, dynamic>) {
        if (decoded['items'] is List) {
          rawItems = decoded['items'] as List<dynamic>;
        } else if (decoded['establishments'] is List) {
          rawItems = decoded['establishments'] as List<dynamic>;
        } else if (decoded['data'] is List) {
          rawItems = decoded['data'] as List<dynamic>;
        }
      }

      return rawItems
          .whereType<Map>()
          .map(
            (e) => StaffEstablishmentItem.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .where((e) => e.id > 0)
          .toList();
    } on TimeoutException catch (e) {
      lastError = e;
    } on http.ClientException catch (e) {
      lastError = e;
    } catch (e) {
      lastError = e;
      rethrow;
    }

    if (attempt < 2) {
      await Future<void>.delayed(const Duration(milliseconds: 650));
    }
  }

  throw Exception('Сервер долго не отвечает: $lastError');
}
}