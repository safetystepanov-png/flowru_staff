import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../auth/data/auth_storage.dart';
import '../../../../core/config/app_config.dart';
import '../widgets/staff_glass_ui.dart';

class StaffClientAccrualScreen extends StatefulWidget {
  final int establishmentId;
  final String establishmentName;
  final String clientId;
  final String clientName;

  const StaffClientAccrualScreen({
    super.key,
    required this.establishmentId,
    required this.establishmentName,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<StaffClientAccrualScreen> createState() => _StaffClientAccrualScreenState();
}

class _StaffClientAccrualScreenState extends State<StaffClientAccrualScreen> {
  final TextEditingController _amountController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  _LoyaltyConfig? _config;
  _AccrualPreview? _preview;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _amountController.addListener(_recalculate);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Access token not found');
    }
    return token;
  }

  double _parseAmount() {
    final raw = _amountController.text.trim().replaceAll(',', '.');
    return double.tryParse(raw) ?? 0;
  }

  Future<void> _loadConfig() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await _token();
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/v1/staff/loyalty/config?establishment_id=${widget.establishmentId}&client_id=${Uri.encodeQueryComponent(widget.clientId)}',
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('config failed: ${response.statusCode} ${response.body}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _config = _LoyaltyConfig.fromJson(decoded);
        _loading = false;
      });

      _recalculate();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить настройки лояльности';
      });
    }
  }

  void _recalculate() {
    final config = _config;
    if (config == null) return;

    final amount = _parseAmount();
    if (amount <= 0) {
      setState(() {
        _preview = null;
      });
      return;
    }

    double added = 0;
    String label = '';

    if (config.mode == 'points') {
      if (config.accrualType == 'fixed' || config.fixedPointsPerPurchase > 0) {
        added = config.fixedPointsPerPurchase.toDouble();
        label = 'Фиксированное начисление';
      } else {
        final per100 = config.pointsPer100Rub;
        added = (amount / 100.0) * per100;
        added = added.floorToDouble();
        label = '$per100 баллов за 100 ₽';
      }
    } else if (config.mode == 'cashback') {
      final percent = config.activeCashbackPercent;
      added = amount * percent / 100.0;
      added = double.parse(added.toStringAsFixed(2));
      label = 'Кешбэк $percent%';
    } else {
      added = 0;
      label = 'Начисление не используется';
    }

    setState(() {
      _preview = _AccrualPreview(
        checkAmount: amount,
        added: added,
        label: label,
      );
    });
  }

  Future<void> _submit() async {
    final preview = _preview;
    if (preview == null || _saving) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final token = await _token();

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/staff/accrual'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'establishment_id': widget.establishmentId,
          'client_id': widget.clientId,
          'amount': preview.checkAmount,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('accrual failed: ${response.statusCode} ${response.body}');
      }

      if (!mounted) return;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Готово'),
          content: Text(decoded['message']?.toString() ?? 'Начисление выполнено'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(this.context).pop(true);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось выполнить начисление';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Widget _amountCard() {
    return StaffGlassPanel(
      radius: 26,
      glowColor: kStaffBlue.withOpacity(0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StaffSectionTitle(
            title: 'Сумма чека',
            subtitle: 'Введи фактическую сумму покупки',
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white.withOpacity(0.88),
              border: Border.all(color: kStaffBorder),
            ),
            child: TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                hintText: 'Например 1250',
                suffixText: '₽',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewCard() {
    final preview = _preview;
    final config = _config;

    return StaffGlassPanel(
      radius: 26,
      glowColor: kStaffViolet.withOpacity(0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StaffSectionTitle(
            title: 'Предпросмотр',
            subtitle: 'Что произойдёт после начисления',
          ),
          const SizedBox(height: 14),
          _line('Клиент', widget.clientName),
          _line('Режим', config?.modeLabel ?? '—'),
          _line('Чек', preview != null ? '${preview.checkAmount.toStringAsFixed(0)} ₽' : '—'),
          _line('Логика', preview?.label ?? '—'),
          _line('Начислится', preview != null ? preview.addedLabel : '—'),
        ],
      ),
    );
  }

  Widget _line(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: kStaffInkSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: kStaffInkPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _submitButton() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [kStaffBlue, kStaffViolet],
        ),
        boxShadow: [
          BoxShadow(
            color: kStaffBlue.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: (_preview == null || _saving) ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: _saving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Начислить',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
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
          'Начисление',
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
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _amountCard(),
                    const SizedBox(height: 14),
                    _previewCard(),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    _submitButton(),
                  ],
                ),
        ),
      ),
    );
  }
}

class _LoyaltyConfig {
  final String mode;
  final String accrualType;
  final int fixedPointsPerPurchase;
  final int pointsPer100Rub;
  final double cashbackPercent;
  final List<_CashbackLevel> cashbackLevels;
  final int clientVisits;
  final double clientTotalSpent;

  _LoyaltyConfig({
    required this.mode,
    required this.accrualType,
    required this.fixedPointsPerPurchase,
    required this.pointsPer100Rub,
    required this.cashbackPercent,
    required this.cashbackLevels,
    required this.clientVisits,
    required this.clientTotalSpent,
  });

  factory _LoyaltyConfig.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    double parseNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    final levelsRaw = (json['cashback_levels'] as List?) ?? const [];

    return _LoyaltyConfig(
      mode: json['mode']?.toString() ?? 'points',
      accrualType: json['accrual_type']?.toString() ?? 'per_amount',
      fixedPointsPerPurchase: parseInt(json['fixed_points_per_purchase']),
      pointsPer100Rub: parseInt(json['points_per_100_rub']),
      cashbackPercent: parseNum(json['cashback_percent']),
      cashbackLevels: levelsRaw
          .map((e) => _CashbackLevel.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      clientVisits: parseInt(json['client_visits']),
      clientTotalSpent: parseNum(json['client_total_spent']),
    );
  }

  double get activeCashbackPercent {
    if (cashbackLevels.isEmpty) return cashbackPercent;
    double result = cashbackPercent;
    for (final level in cashbackLevels) {
      if (clientTotalSpent >= level.spentRequired) {
        result = level.cashbackPercent;
      }
    }
    return result;
  }

  String get modeLabel {
    if (mode == 'cashback') return 'Кешбэк';
    if (mode == 'discount') return 'Скидки';
    return 'Баллы';
  }
}

class _CashbackLevel {
  final String name;
  final double spentRequired;
  final double cashbackPercent;

  _CashbackLevel({
    required this.name,
    required this.spentRequired,
    required this.cashbackPercent,
  });

  factory _CashbackLevel.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return _CashbackLevel(
      name: json['name']?.toString() ?? '',
      spentRequired: parseNum(json['spent_required']),
      cashbackPercent: parseNum(json['cashback_percent']),
    );
  }
}

class _AccrualPreview {
  final double checkAmount;
  final double added;
  final String label;

  _AccrualPreview({
    required this.checkAmount,
    required this.added,
    required this.label,
  });

  String get addedLabel {
    if (added == added.roundToDouble()) {
      return added.toInt().toString();
    }
    return added.toStringAsFixed(2);
  }
}