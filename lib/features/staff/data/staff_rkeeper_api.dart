import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_storage.dart';
import '../../auth/data/session_expired_exception.dart';

class StaffRkeeperOrder {
  final String guid;
  final String name;
  final String tableCode;
  final int orderSum;
  final int toPaySum;
  final DateTime? createdAt;

  const StaffRkeeperOrder({
    required this.guid,
    required this.name,
    required this.tableCode,
    required this.orderSum,
    required this.toPaySum,
    required this.createdAt,
  });

  factory StaffRkeeperOrder.fromJson(Map<String, dynamic> json) {
    int number(dynamic value) =>
        value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    return StaffRkeeperOrder(
      guid: '${json['order_guid'] ?? ''}',
      name: '${json['order_name'] ?? 'Заказ'}',
      tableCode: '${json['table_code'] ?? ''}',
      orderSum: number(json['order_sum']),
      toPaySum: number(json['to_pay_sum']),
      createdAt: DateTime.tryParse('${json['create_time'] ?? ''}'),
    );
  }
}

class StaffRkeeperApi {
  Future<String> _token() async {
    final value = await AuthStorage.getAccessToken();
    if (value == null || value.trim().isEmpty) {
      throw const SessionExpiredException();
    }
    return value.trim();
  }

  Future<List<StaffRkeeperOrder>> getOpenOrders(int establishmentId) async {
    final response = await http.get(
      Uri.parse(
        '${AppConfig.baseUrl}/api/v1/staff/rkeeper/orders'
        '?establishment_id=$establishmentId',
      ),
      headers: {
        'Authorization': 'Bearer ${await _token()}',
        'Accept': 'application/json',
      },
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const SessionExpiredException();
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200) {
      throw Exception(
        body is Map ? body['detail'] : 'Не удалось получить заказы',
      );
    }
    final raw = body is Map && body['items'] is List
        ? body['items'] as List
        : const [];
    return raw
        .whereType<Map>()
        .map((e) => StaffRkeeperOrder.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.guid.isNotEmpty)
        .toList();
  }

  Future<String> applyCard({
    required int establishmentId,
    required int clientId,
    required String authorizationToken,
    required String orderGuid,
  }) async {
    final response = await http.post(
      Uri.parse(
        '${AppConfig.baseUrl}/api/v1/staff/rkeeper/orders/'
        '${Uri.encodeComponent(orderGuid)}/apply-card',
      ),
      headers: {
        'Authorization': 'Bearer ${await _token()}',
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'establishment_id': establishmentId,
        'client_id': clientId,
        'authorization_token': authorizationToken,
      }),
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const SessionExpiredException();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        body is Map ? body['detail'] : 'Не удалось назначить карту',
      );
    }
    return '${body['command_id'] ?? ''}';
  }

  Future<Map<String, dynamic>> commandStatus({
    required int establishmentId,
    required String commandId,
  }) async {
    final response = await http.get(
      Uri.parse(
        '${AppConfig.baseUrl}/api/v1/staff/rkeeper/commands/$commandId'
        '?establishment_id=$establishmentId',
      ),
      headers: {
        'Authorization': 'Bearer ${await _token()}',
        'Accept': 'application/json',
      },
    );
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200 || body is! Map) {
      throw Exception('Не удалось проверить результат r_keeper');
    }
    return Map<String, dynamic>.from(body);
  }
}
