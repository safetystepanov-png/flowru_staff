import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../auth/data/auth_storage.dart';
import '../../../../core/config/app_config.dart';
import '../widgets/staff_glass_ui.dart';
import 'staff_client_accrual_screen.dart';
import 'staff_client_history_screen.dart';
import 'staff_client_rewards_screen.dart';
import 'staff_client_spend_screen.dart';

class StaffClientDetailScreen extends StatefulWidget {
  final int establishmentId;
  final String establishmentName;
  final String clientId;

  const StaffClientDetailScreen({
    super.key,
    required this.establishmentId,
    required this.establishmentName,
    required this.clientId,
  });

  @override
  State<StaffClientDetailScreen> createState() => _StaffClientDetailScreenState();
}

class _StaffClientDetailScreenState extends State<StaffClientDetailScreen> {
  bool _loading = true;
  String? _error;
  _ClientDetail? _client;

  Future<String> _token() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Access token not found');
    }
    return token;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await _token();
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/v1/staff/clients/detail?client_id=${Uri.encodeQueryComponent(widget.clientId)}&establishment_id=${widget.establishmentId}',
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('detail failed: ${response.statusCode} ${response.body}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _client = _ClientDetail.fromJson(decoded);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить клиента';
      });
    }
  }

  Widget _topCard() {
    final client = _client!;
    return StaffGlassPanel(
      radius: 28,
      glowColor: kStaffPink.withOpacity(0.12),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [kStaffBlue, kStaffPink],
              ),
            ),
            child: Center(
              child: Text(
                client.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            client.displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: kStaffInkPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            client.phone ?? 'Телефон не указан',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kStaffInkSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metrics() {
    final client = _client!;
    return Row(
      children: [
        Expanded(
          child: _metricCard(
            title: 'Баланс',
            value: client.balanceLabel,
            icon: CupertinoIcons.star_fill,
            glow: kStaffBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricCard(
            title: 'Визиты',
            value: client.visitsLabel,
            icon: CupertinoIcons.ticket_fill,
            glow: kStaffPink,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricCard(
            title: 'Потрачено',
            value: client.spentLabel,
            icon: CupertinoIcons.creditcard_fill,
            glow: kStaffViolet,
          ),
        ),
      ],
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color glow,
  }) {
    return StaffGlassPanel(
      radius: 22,
      glowColor: glow.withOpacity(0.12),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          StaffGradientIcon(icon: icon, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: kStaffInkPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: kStaffInkSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(colors: colors),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.all(18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _softActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color glow,
    required VoidCallback onTap,
  }) {
    return StaffGlassPanel(
      radius: 22,
      glowColor: glow.withOpacity(0.10),
      onTap: onTap,
      child: Row(
        children: [
          StaffGradientIcon(icon: icon, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: kStaffInkPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: kStaffInkSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            CupertinoIcons.chevron_right,
            color: kStaffInkPrimary,
          ),
        ],
      ),
    );
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

  Widget _content() {
    if (_error != null) {
      return _stateCard(
        icon: CupertinoIcons.exclamationmark_circle_fill,
        title: 'Ошибка',
        subtitle: _error!,
      );
    }

    if (_client == null) {
      return _stateCard(
        icon: CupertinoIcons.person_crop_circle_badge_xmark,
        title: 'Клиент не найден',
        subtitle: 'Не удалось получить данные клиента',
      );
    }

    return Column(
      children: [
        _topCard(),
        const SizedBox(height: 14),
        _metrics(),
        const SizedBox(height: 18),
        _actionButton(
          title: 'Начислить',
          subtitle: 'Провести покупку и начислить по логике лояльности',
          icon: CupertinoIcons.plus_circle_fill,
          colors: const [kStaffBlue, kStaffViolet],
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StaffClientAccrualScreen(
                  establishmentId: widget.establishmentId,
                  establishmentName: widget.establishmentName,
                  clientId: widget.clientId,
                  clientName: _client!.displayName,
                ),
              ),
            );
            _load();
          },
        ),
        const SizedBox(height: 12),
        _actionButton(
          title: 'Списать',
          subtitle: 'Проверить доступное списание и провести оплату',
          icon: CupertinoIcons.minus_circle_fill,
          colors: const [kStaffPink, kStaffViolet],
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StaffClientSpendScreen(
                  establishmentId: widget.establishmentId,
                  establishmentName: widget.establishmentName,
                  clientId: widget.clientId,
                  clientName: _client!.displayName,
                ),
              ),
            );
            _load();
          },
        ),
        const SizedBox(height: 12),
        _softActionTile(
          title: 'История клиента',
          subtitle: 'Посмотреть все операции и движения по клиенту',
          icon: CupertinoIcons.time_solid,
          glow: kStaffBlue,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StaffClientHistoryScreen(
                  establishmentId: widget.establishmentId,
                  establishmentName: widget.establishmentName,
                  clientId: widget.clientId,
                  clientName: _client!.displayName,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _softActionTile(
          title: 'Награды',
          subtitle: 'Доступные подарки и выдача награды клиенту',
          icon: CupertinoIcons.gift_fill,
          glow: kStaffPink,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StaffClientRewardsScreen(
                  establishmentId: widget.establishmentId,
                  establishmentName: widget.establishmentName,
                  clientId: widget.clientId,
                  clientName: _client!.displayName,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kStaffBgTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.establishmentName,
          style: const TextStyle(
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
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _content(),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ClientDetail {
  final String clientId;
  final String? fullName;
  final String? phone;
  final double balance;
  final int visits;
  final double totalSpent;

  _ClientDetail({
    required this.clientId,
    required this.fullName,
    required this.phone,
    required this.balance,
    required this.visits,
    required this.totalSpent,
  });

  factory _ClientDetail.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    int parseInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    return _ClientDetail(
      clientId: json['client_id']?.toString() ?? json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ??
          json['name']?.toString() ??
          json['display_name']?.toString(),
      phone: json['phone']?.toString(),
      balance: parseNum(
        json['balance'] ??
            json['client_balance'] ??
            json['points_balance'] ??
            json['bonuses_balance'],
      ),
      visits: parseInt(
        json['visits'] ?? json['client_visits'] ?? json['visits_count'],
      ),
      totalSpent: parseNum(
        json['total_spent'] ?? json['client_total_spent'],
      ),
    );
  }

  String get displayName {
    final name = (fullName ?? '').trim();
    if (name.isNotEmpty) return name;
    if ((phone ?? '').trim().isNotEmpty) return phone!.trim();
    return 'Клиент';
  }

  String get initials {
    final name = displayName.trim();
    if (name.isEmpty) return 'C';
    final parts = name.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'C';
    final first = parts.first.isNotEmpty ? parts.first[0] : 'C';
    if (parts.length == 1) return first.toUpperCase();
    final last = parts.last.isNotEmpty ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  String get balanceLabel {
    if (balance == balance.roundToDouble()) return balance.toInt().toString();
    return balance.toStringAsFixed(2);
  }

  String get visitsLabel => visits.toString();

  String get spentLabel => '${totalSpent.toStringAsFixed(0)} ₽';
}