import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../auth/data/auth_storage.dart';
import '../../../../core/config/app_config.dart';

const Color kPreorderMint = Color(0xFF0BAEBB);
const Color kPreorderDeep = Color(0xFF064B64);
const Color kPreorderInk = Color(0xFF0A2B47);
const Color kPreorderSoft = Color(0xFF557186);
const Color kPreorderBg = Color(0xFFF4FAFB);

class StaffPreordersScreen extends StatefulWidget {
  final int establishmentId;
  final String establishmentName;

  const StaffPreordersScreen({
    super.key,
    required this.establishmentId,
    required this.establishmentName,
  });

  @override
  State<StaffPreordersScreen> createState() => _StaffPreordersScreenState();
}

class _StaffPreordersScreenState extends State<StaffPreordersScreen> {
  bool _loading = true;
  bool _updating = false;
  String? _error;
  List<_PreorderItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<String> _token() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Access token not found');
    }
    return token;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await _token();
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/v1/staff/preorders?establishment_id=${widget.establishmentId}&limit=100',
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('preorders failed: ${response.statusCode} ${response.body}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final rawItems = (decoded['items'] as List?) ?? const [];

      if (!mounted) return;
      setState(() {
        _items = rawItems
            .map((e) => _PreorderItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить предзаказы';
      });
    }
  }

  Future<void> _setStatus(_PreorderItem item, String status) async {
    if (_updating) return;

    setState(() {
      _updating = true;
      _error = null;
    });

    try {
      final token = await _token();
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/staff/preorders/${item.id}/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'status': status,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('status failed: ${response.statusCode} ${response.body}');
      }

      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось обновить статус';
      });
    } finally {
      if (mounted) {
        setState(() {
          _updating = false;
        });
      }
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'new':
        return 'Новый';
      case 'in_work':
        return 'В работе';
      case 'ready':
        return 'Готов';
      case 'completed':
        return 'Выдан';
      case 'cancelled':
        return 'Отменён';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'new':
        return const Color(0xFFFFA51E);
      case 'in_work':
        return const Color(0xFF246BFF);
      case 'ready':
        return const Color(0xFF22C55E);
      case 'completed':
        return const Color(0xFF64748B);
      case 'cancelled':
        return const Color(0xFFFF6A5E);
      default:
        return kPreorderSoft;
    }
  }

  Widget _actionButton({
    required String text,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: SizedBox(
        height: 42,
        child: ElevatedButton(
          onPressed: _updating ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _orderCard(_PreorderItem item) {
    final statusColor = _statusColor(item.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE3EEF3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.055),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [kPreorderMint, kPreorderDeep],
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.bag_fill,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.clientName.isEmpty ? 'Клиент' : item.clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kPreorderInk,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.clientPhone.isEmpty ? 'Телефон не указан' : item.clientPhone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kPreorderSoft,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusText(item.status),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            item.orderText,
            style: const TextStyle(
              color: kPreorderInk,
              fontSize: 15.5,
              height: 1.35,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                CupertinoIcons.clock_fill,
                size: 15,
                color: kPreorderSoft,
              ),
              const SizedBox(width: 6),
              Text(
                item.pickupLabel,
                style: const TextStyle(
                  color: kPreorderSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (item.status == 'new') ...[
            Row(
              children: [
                _actionButton(
                  text: 'В работе',
                  color: const Color(0xFF246BFF),
                  onTap: () => _setStatus(item, 'in_work'),
                ),
                const SizedBox(width: 8),
                _actionButton(
                  text: 'Отменить',
                  color: const Color(0xFFFF6A5E),
                  onTap: () => _setStatus(item, 'cancelled'),
                ),
              ],
            ),
          ] else if (item.status == 'in_work') ...[
            Row(
              children: [
                _actionButton(
                  text: 'Готов',
                  color: const Color(0xFF22C55E),
                  onTap: () => _setStatus(item, 'ready'),
                ),
                const SizedBox(width: 8),
                _actionButton(
                  text: 'Отменить',
                  color: const Color(0xFFFF6A5E),
                  onTap: () => _setStatus(item, 'cancelled'),
                ),
              ],
            ),
          ] else if (item.status == 'ready') ...[
            Row(
              children: [
                _actionButton(
                  text: 'Выдан',
                  color: kPreorderDeep,
                  onTap: () => _setStatus(item, 'completed'),
                ),
                const SizedBox(width: 8),
                _actionButton(
                  text: 'Отменить',
                  color: const Color(0xFFFF6A5E),
                  onTap: () => _setStatus(item, 'cancelled'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPreorderBg,
      appBar: AppBar(
        backgroundColor: kPreorderBg,
        elevation: 0,
        foregroundColor: kPreorderInk,
        title: const Text(
          'Предзаказы',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(CupertinoIcons.refresh_bold),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator(radius: 16))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          colors: [kPreorderMint, kPreorderDeep],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Заказы к приходу',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Новые заявки клиентов, которые хотят забрать заказ без ожидания в очереди.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.82),
                              fontSize: 13.5,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6A5E).withOpacity(0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFFF6A5E),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                    if (_items.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: const Text(
                          'Предзаказов пока нет',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: kPreorderSoft,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    else
                      ..._items.map(_orderCard),
                  ],
                ),
              ),
      ),
    );
  }
}

class _PreorderItem {
  final int id;
  final int establishmentId;
  final int? clientId;
  final String clientName;
  final String clientPhone;
  final String orderText;
  final String pickupType;
  final int? pickupMinutes;
  final String status;
  final String createdAt;

  _PreorderItem({
    required this.id,
    required this.establishmentId,
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    required this.orderText,
    required this.pickupType,
    required this.pickupMinutes,
    required this.status,
    required this.createdAt,
  });

  factory _PreorderItem.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    return _PreorderItem(
      id: parseInt(json['id']) ?? 0,
      establishmentId: parseInt(json['establishment_id']) ?? 0,
      clientId: parseInt(json['client_id']),
      clientName: json['client_name']?.toString() ?? '',
      clientPhone: json['client_phone']?.toString() ?? '',
      orderText: json['order_text']?.toString() ?? '',
      pickupType: json['pickup_type']?.toString() ?? 'in_minutes',
      pickupMinutes: parseInt(json['pickup_minutes']),
      status: json['status']?.toString() ?? 'new',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  String get pickupLabel {
    if (pickupType == 'asap') return 'Как можно скорее';
    if (pickupType == 'at_time') return 'К определённому времени';
    final minutes = pickupMinutes ?? 0;
    if (minutes <= 0) return 'Как можно скорее';
    return 'Забрать через $minutes мин.';
  }
}
