import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../auth/data/auth_storage.dart';
import '../../../../core/config/app_config.dart';
import '../widgets/staff_glass_ui.dart';

class StaffClientHistoryScreen extends StatefulWidget {
  final int establishmentId;
  final String establishmentName;
  final String clientId;
  final String clientName;

  const StaffClientHistoryScreen({
    super.key,
    required this.establishmentId,
    required this.establishmentName,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<StaffClientHistoryScreen> createState() =>
      _StaffClientHistoryScreenState();
}

class _StaffClientHistoryScreenState extends State<StaffClientHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<_HistoryItem> _items = [];

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
        '${AppConfig.baseUrl}/api/v1/staff/clients/history?client_id=${Uri.encodeQueryComponent(widget.clientId)}&establishment_id=${widget.establishmentId}',
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          'client history failed: ${response.statusCode} ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);

      List<dynamic> raw;
      if (decoded is List) {
        raw = decoded;
      } else if (decoded is Map<String, dynamic> && decoded['items'] is List) {
        raw = decoded['items'] as List<dynamic>;
      } else {
        raw = [];
      }

      if (!mounted) return;

      setState(() {
        _items = raw
            .map((e) => _HistoryItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить историю клиента';
      });
    }
  }

  Widget _stateCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return StaffGlassPanel(
      radius: 26,
      child: Column(
        children: [
          StaffGradientIcon(icon: icon, size: 24),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: kStaffInkPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: kStaffInkSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'accrual':
      case 'visit':
      case 'earn':
        return kStaffBlue;
      case 'spend':
      case 'redeem':
      case 'write_off':
        return kStaffPink;
      default:
        return kStaffViolet;
    }
  }

  IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'accrual':
      case 'visit':
      case 'earn':
        return CupertinoIcons.plus_circle_fill;
      case 'spend':
      case 'redeem':
      case 'write_off':
        return CupertinoIcons.minus_circle_fill;
      default:
        return CupertinoIcons.clock_fill;
    }
  }

  String _typeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'accrual':
        return 'Начисление';
      case 'spend':
        return 'Списание';
      case 'visit':
        return 'Визит';
      case 'redeem':
        return 'Погашение';
      case 'earn':
        return 'Начисление';
      default:
        return type.isEmpty ? 'Операция' : type;
    }
  }

  String _formatDate(String value) {
    if (value.isEmpty) return '';
    try {
      final dt = DateTime.parse(value).toLocal();
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final hh = dt.hour.toString().padLeft(2, '0');
      final mi = dt.minute.toString().padLeft(2, '0');
      return '$dd.$mm • $hh:$mi';
    } catch (_) {
      return value;
    }
  }

  Widget _itemCard(_HistoryItem item) {
    final color = _typeColor(item.operationType);

    return StaffGlassPanel(
      radius: 22,
      glowColor: color.withOpacity(0.10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: color.withOpacity(0.12),
            ),
            child: Icon(
              _typeIcon(item.operationType),
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _typeLabel(item.operationType),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: kStaffInkPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.amountLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                if (item.comment.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.comment,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      color: kStaffInkSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  _formatDate(item.createdAt),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: kStaffInkSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kStaffBgTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'История клиента',
          style: TextStyle(
            color: kStaffInkPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        iconTheme: const IconThemeData(color: kStaffInkPrimary),
      ),
      body: StaffScreenBackground(
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(kStaffViolet),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      StaffGlassPanel(
                        radius: 26,
                        glowColor: kStaffBlue.withOpacity(0.10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.clientName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: kStaffInkPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.establishmentName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: kStaffInkSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_error != null)
                        _stateCard(
                          icon: CupertinoIcons.exclamationmark_circle_fill,
                          title: 'Ошибка',
                          subtitle: _error!,
                        )
                      else if (_items.isEmpty)
                        _stateCard(
                          icon: CupertinoIcons.time_solid,
                          title: 'История пока пустая',
                          subtitle: 'По этому клиенту пока нет операций',
                        )
                      else
                        ..._items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _itemCard(item),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _HistoryItem {
  final String id;
  final String operationType;
  final double amount;
  final String comment;
  final String createdAt;

  _HistoryItem({
    required this.id,
    required this.operationType,
    required this.amount,
    required this.comment,
    required this.createdAt,
  });

  factory _HistoryItem.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return _HistoryItem(
      id: json['id']?.toString() ?? '',
      operationType: json['operation_type']?.toString() ??
          json['type']?.toString() ??
          '',
      amount: parseNum(json['amount']),
      comment: json['comment']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  String get amountLabel {
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }
    return amount.toStringAsFixed(2);
  }
}