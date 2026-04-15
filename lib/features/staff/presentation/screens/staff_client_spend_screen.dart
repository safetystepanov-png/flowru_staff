import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../auth/data/auth_storage.dart';
import '../../../../core/config/app_config.dart';
import '../widgets/staff_glass_ui.dart';

class StaffClientSpendScreen extends StatefulWidget {
  final int establishmentId;
  final String establishmentName;
  final String clientId;
  final String clientName;

  const StaffClientSpendScreen({
    super.key,
    required this.establishmentId,
    required this.establishmentName,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<StaffClientSpendScreen> createState() => _StaffClientSpendScreenState();
}

class _StaffClientSpendScreenState extends State<StaffClientSpendScreen> {
  final TextEditingController _amountController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  _SpendConfig? _config;
  _SpendPreview? _preview;

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
        _config = _SpendConfig.fromJson(decoded);
        _loading = false;
      });

      _recalculate();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить настройки списания';
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

    double redeemed = 0;
    double payable = amount;

    if (config.mode == 'points') {
      final byBalance = config.clientBalance;
      final byPercent = amount * config.maxRedeemPercent / 100.0;
      redeemed = byBalance < byPercent ? byBalance : byPercent;
      redeemed = redeemed.floorToDouble();
      payable = amount - redeemed;
    } else if (config.mode == 'cashback') {
      final byBalance = config.clientBalance;
      final byPercent = amount * config.maxRedeemPercent / 100.0;
      redeemed = byBalance < byPercent ? byBalance : byPercent;
      payable = amount - redeemed;
    } else {
      redeemed = 0;
      payable = amount;
    }

    if (payable < 0) payable = 0;

    setState(() {
      _preview = _SpendPreview(
        checkAmount: amount,
        redeemed: redeemed,
        payable: double.parse(payable.toStringAsFixed(2)),
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
        Uri.parse('${AppConfig.baseUrl}/api/v1/staff/spend'),
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
        throw Exception('spend failed: ${response.statusCode} ${response.body}');
      }

      if (!mounted) return;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Готово'),
          content: Text(decoded['message']?.toString() ?? 'Списание выполнено'),
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
        _error = 'Не удалось выполнить списание';
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
      glowColor: kStaffPink.withOpacity(0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StaffSectionTitle(
            title: 'Сумма чека',
            subtitle: 'Введи сумму покупки перед списанием',
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
            subtitle: 'Что произойдёт после списания',
          ),
          const SizedBox(height: 14),
          _line('Клиент', widget.clientName),
          _line('Режим', config?.modeLabel ?? '—'),
          _line('Баланс клиента', config != null ? config.balanceLabel : '—'),
          _line('Чек', preview != null ? '${preview.checkAmount.toStringAsFixed(0)} ₽' : '—'),
          _line('Списание', preview != null ? preview.redeemedLabel : '—'),
          _line('К оплате', preview != null ? '${preview.payable.toStringAsFixed(2)} ₽' : '—'),
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
          colors: [kStaffPink, kStaffViolet],
        ),
        boxShadow: [
          BoxShadow(
            color: kStaffPink.withOpacity(0.18),
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
                'Списать',
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
          'Списание',
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

class _SpendConfig {
  final String mode;
  final double clientBalance;
  final double maxRedeemPercent;

  _SpendConfig({
    required this.mode,
    required this.clientBalance,
    required this.maxRedeemPercent,
  });

  factory _SpendConfig.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return _SpendConfig(
      mode: json['mode']?.toString() ?? 'points',
      clientBalance: parseNum(json['client_balance']),
      maxRedeemPercent: parseNum(json['max_redeem_percent']),
    );
  }

  String get modeLabel {
    if (mode == 'cashback') return 'Кешбэк';
    if (mode == 'discount') return 'Скидки';
    return 'Баллы';
  }

  String get balanceLabel {
    if (clientBalance == clientBalance.roundToDouble()) {
      return clientBalance.toInt().toString();
    }
    return clientBalance.toStringAsFixed(2);
  }
}

class _SpendPreview {
  final double checkAmount;
  final double redeemed;
  final double payable;

  _SpendPreview({
    required this.checkAmount,
    required this.redeemed,
    required this.payable,
  });

  String get redeemedLabel {
    if (redeemed == redeemed.roundToDouble()) {
      return redeemed.toInt().toString();
    }
    return redeemed.toStringAsFixed(2);
  }
}