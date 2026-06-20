import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../auth/data/auth_storage.dart';
import '../../../auth/data/user_api.dart';
import '../../../../core/config/app_config.dart';

const Color kPreorderMint = Color(0xFF0BAEBB);
const Color kPreorderMintLight = Color(0xFF42E8DF);
const Color kPreorderDeep = Color(0xFF064B64);
const Color kPreorderInk = Color(0xFF0A2B47);
const Color kPreorderSoft = Color(0xFF557186);
const Color kPreorderBg = Color(0xFFF3FAFB);
const Color kPreorderOrange = Color(0xFFFFA51E);
const Color kPreorderBlue = Color(0xFF246BFF);
const Color kPreorderGreen = Color(0xFF22C55E);
const Color kPreorderRed = Color(0xFFFF6A5E);
const Color kPreorderViolet = Color(0xFF7A4CFF);
const Color kPreorderCard = Color(0xFFFFFFFF);
const Color kPreorderStroke = Color(0xFFE3EEF3);

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

class _StaffPreordersScreenState extends State<StaffPreordersScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _updating = false;
  String? _error;
  List<_PreorderItem> _items = [];
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception(
        'Р РЋР ВµРЎРѓРЎРѓР С‘РЎРЏ Р С‘РЎРѓРЎвЂљР ВµР С”Р В»Р В°. Р вЂ™Р С•Р в„–Р Т‘Р С‘РЎвЂљР Вµ Р В·Р В°Р Р…Р С•Р Р†Р С•.',
      );
    }
    return token.trim();
  }

  Future<String> _refreshAccessToken() async {
    final refreshToken = await AuthStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.trim().isEmpty) {
      throw Exception(
        'Р РЋР ВµРЎРѓРЎРѓР С‘РЎРЏ Р С‘РЎРѓРЎвЂљР ВµР С”Р В»Р В°. Р вЂ™Р С•Р в„–Р Т‘Р С‘РЎвЂљР Вµ Р В·Р В°Р Р…Р С•Р Р†Р С•.',
      );
    }

    final result = await UserApi().refresh(
      refreshToken: refreshToken.trim(),
      deviceId: kIsWeb ? 'staff-web' : 'staff-mobile',
      platform: kIsWeb ? 'web' : 'mobile',
    );

    if (!result.ok || result.accessToken.trim().isEmpty) {
      throw Exception(
        'Р РЋР ВµРЎРѓРЎРѓР С‘РЎРЏ Р С‘РЎРѓРЎвЂљР ВµР С”Р В»Р В°. Р вЂ™Р С•Р в„–Р Т‘Р С‘РЎвЂљР Вµ Р В·Р В°Р Р…Р С•Р Р†Р С•.',
      );
    }

    await AuthStorage.saveAccessToken(result.accessToken.trim());

    if (result.refreshToken.trim().isNotEmpty) {
      await AuthStorage.saveRefreshToken(result.refreshToken.trim());
    }

    return result.accessToken.trim();
  }

  Future<Map<String, String>> _authorizedHeaders({
    bool json = false,
    bool forceRefresh = false,
  }) async {
    final token = forceRefresh ? await _refreshAccessToken() : await _token();

    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
    };
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/v1/staff/preorders?establishment_id=${widget.establishmentId}&limit=100',
      );

      var response = await http.get(uri, headers: await _authorizedHeaders());

      if (response.statusCode == 401 || response.statusCode == 403) {
        response = await http.get(
          uri,
          headers: await _authorizedHeaders(forceRefresh: true),
        );
      }

      if (response.statusCode != 200) {
        throw Exception(
          _statusErrorMessage(response.statusCode, response.body),
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final rawItems = (decoded['items'] as List?) ?? const [];

      if (!mounted) return;
      setState(() {
        _items = rawItems
            .map(
              (e) => _PreorderItem.fromJson((e as Map).cast<String, dynamic>()),
            )
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final message = e.toString().replaceFirst('Exception: ', '').trim();
        _loading = false;
        _error = message.isEmpty
            ? 'Р СњР Вµ РЎС“Р Т‘Р В°Р В»Р С•РЎРѓРЎРЉ Р В·Р В°Р С–РЎР‚РЎС“Р В·Р С‘РЎвЂљРЎРЉ Р С—РЎР‚Р ВµР Т‘Р В·Р В°Р С”Р В°Р В·РЎвЂ№'
            : message;
      });
    }
  }

  double? _parseAmount(String raw) {
    final normalized = raw
        .trim()
        .replaceAll(' ', '')
        .replaceAll('РІвЂљР…', '')
        .replaceAll(',', '.');

    if (normalized.isEmpty) return null;

    final value = double.tryParse(normalized);
    if (value == null || value <= 0) return null;

    return value;
  }

  String _formatMoney(double value) {
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  Future<double?> _askCompletedAmount(_PreorderItem item) async {
    final controller = TextEditingController(
      text: item.amountTotal != null && item.amountTotal! > 0
          ? _formatMoney(item.amountTotal!)
          : '',
    );

    String? localError;

    final result = await showDialog<double>(
      context: context,
      barrierDismissible: !_updating,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
              contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              actionsPadding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
              title: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kPreorderMint, kPreorderDeep],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: kPreorderMint.withOpacity(0.28),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.payments_rounded,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Р РЋРЎС“Р СР СР В° РЎвЂЎР ВµР С”Р В°',
                      style: TextStyle(
                        color: kPreorderInk,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Р вЂ™Р Р†Р ВµР Т‘Р С‘РЎвЂљР Вµ РЎРѓРЎС“Р СР СРЎС“, Р С”Р С•РЎвЂљР С•РЎР‚РЎС“РЎР‹ Р С”Р В»Р С‘Р ВµР Р…РЎвЂљ Р С•Р С—Р В»Р В°РЎвЂљР С‘Р В» Р В·Р В° Р В·Р В°Р С”Р В°Р В·. Р СџР С•РЎРѓР В»Р Вµ Р Р†РЎвЂ№Р Т‘Р В°РЎвЂЎР С‘ Flowru Р В°Р Р†РЎвЂљР С•Р СР В°РЎвЂљР С‘РЎвЂЎР ВµРЎРѓР С”Р С‘ Р Р…Р В°РЎвЂЎР С‘РЎРѓР В»Р С‘РЎвЂљ Р В±Р С•Р Р…РЎС“РЎРѓРЎвЂ№ Р С—Р С• Р С—РЎР‚Р В°Р Р†Р С‘Р В»Р В°Р С Р В·Р В°Р Р†Р ВµР Т‘Р ВµР Р…Р С‘РЎРЏ.',
                    style: TextStyle(
                      color: kPreorderSoft,
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText:
                          'Р РЋРЎС“Р СР СР В° РЎвЂЎР ВµР С”Р В°, РІвЂљР…',
                      hintText: 'Р СњР В°Р С—РЎР‚Р С‘Р СР ВµРЎР‚, 350',
                      errorText: localError,
                      filled: true,
                      fillColor: kPreorderBg,
                      prefixIcon: const Icon(Icons.payments_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: kPreorderStroke),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: kPreorderStroke),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                          color: kPreorderMint,
                          width: 1.7,
                        ),
                      ),
                    ),
                    onSubmitted: (_) {
                      final amount = _parseAmount(controller.text);
                      if (amount == null) {
                        setDialogState(() {
                          localError =
                              'Р вЂ™Р Р†Р ВµР Т‘Р С‘РЎвЂљР Вµ РЎРѓРЎС“Р СР СРЎС“ Р В±Р С•Р В»РЎРЉРЎв‚¬Р Вµ 0';
                        });
                        return;
                      }
                      Navigator.of(dialogContext).pop(amount);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'Р СњР В°Р В·Р В°Р Т‘',
                    style: TextStyle(
                      color: kPreorderSoft,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final amount = _parseAmount(controller.text);
                    if (amount == null) {
                      setDialogState(() {
                        localError =
                            'Р вЂ™Р Р†Р ВµР Т‘Р С‘РЎвЂљР Вµ РЎРѓРЎС“Р СР СРЎС“ Р В±Р С•Р В»РЎРЉРЎв‚¬Р Вµ 0';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(amount);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPreorderDeep,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Р вЂ™РЎвЂ№Р Т‘Р В°РЎвЂљРЎРЉ',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<void> _completePreorder(_PreorderItem item) async {
    if (_updating) return;

    final amount = await _askCompletedAmount(item);
    if (amount == null) return;

    await _setStatus(item, 'completed', amountTotal: amount);
  }

  String _statusErrorMessage(int statusCode, String body) {
    if (statusCode == 401 || statusCode == 403) {
      return 'Р РЋР ВµРЎРѓРЎРѓР С‘РЎРЏ Р С‘РЎРѓРЎвЂљР ВµР С”Р В»Р В°. Р вЂ™Р С•Р в„–Р Т‘Р С‘РЎвЂљР Вµ Р В·Р В°Р Р…Р С•Р Р†Р С•.';
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] != null) {
        final detail = decoded['detail'].toString().trim();

        if (detail.toLowerCase().contains('invalid token')) {
          return 'Р РЋР ВµРЎРѓРЎРѓР С‘РЎРЏ Р С‘РЎРѓРЎвЂљР ВµР С”Р В»Р В°. Р вЂ™Р С•Р в„–Р Т‘Р С‘РЎвЂљР Вµ Р В·Р В°Р Р…Р С•Р Р†Р С•.';
        }

        if (detail.isNotEmpty) {
          return detail;
        }
      }
    } catch (_) {}

    if (statusCode == 400) {
      return 'Р СџРЎР‚Р С•Р Р†Р ВµРЎР‚РЎРЉРЎвЂљР Вµ РЎРѓРЎС“Р СР СРЎС“ РЎвЂЎР ВµР С”Р В° Р С‘ Р Р…Р В°РЎРѓРЎвЂљРЎР‚Р С•Р в„–Р С”Р С‘ Р Р…Р В°РЎвЂЎР С‘РЎРѓР В»Р ВµР Р…Р С‘РЎРЏ';
    }

    return 'Р СњР Вµ РЎС“Р Т‘Р В°Р В»Р С•РЎРѓРЎРЉ Р С•Р В±Р Р…Р С•Р Р†Р С‘РЎвЂљРЎРЉ РЎРѓРЎвЂљР В°РЎвЂљРЎС“РЎРѓ';
  }

  Future<void> _setStatus(
    _PreorderItem item,
    String status, {
    double? amountTotal,
  }) async {
    if (_updating) return;

    setState(() {
      _updating = true;
      _error = null;
    });

    try {
      final payload = <String, dynamic>{'status': status};

      if (status == 'completed') {
        payload['amount_total'] = amountTotal;
      }

      final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/v1/staff/preorders/${item.id}/status',
      );

      var response = await http.post(
        uri,
        headers: await _authorizedHeaders(json: true),
        body: jsonEncode(payload),
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        response = await http.post(
          uri,
          headers: await _authorizedHeaders(json: true, forceRefresh: true),
          body: jsonEncode(payload),
        );
      }

      if (response.statusCode != 200) {
        throw Exception(
          _statusErrorMessage(response.statusCode, response.body),
        );
      }

      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final message = e.toString().replaceFirst('Exception: ', '').trim();
        _error = message.isEmpty
            ? 'Р СњР Вµ РЎС“Р Т‘Р В°Р В»Р С•РЎРѓРЎРЉ Р С•Р В±Р Р…Р С•Р Р†Р С‘РЎвЂљРЎРЉ РЎРѓРЎвЂљР В°РЎвЂљРЎС“РЎРѓ'
            : message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _updating = false;
        });
      }
    }
  }

  List<_PreorderItem> get _activeItems {
    final result = _items
        .where(
          (e) =>
              e.status == 'new' || e.status == 'in_work' || e.status == 'ready',
        )
        .toList();

    result.sort((a, b) {
      int rank(String status) {
        if (status == 'new') return 1;
        if (status == 'in_work') return 2;
        if (status == 'ready') return 3;
        return 9;
      }

      final r = rank(a.status).compareTo(rank(b.status));
      if (r != 0) return r;
      return b.id.compareTo(a.id);
    });

    return result;
  }

  List<_PreorderItem> get _doneItems {
    final result = _items
        .where(
          (e) =>
              e.status == 'completed' ||
              e.status == 'cancelled' ||
              e.status == 'expired',
        )
        .toList();
    result.sort((a, b) => b.id.compareTo(a.id));
    return result;
  }

  int get _newCount => _items.where((e) => e.status == 'new').length;
  int get _inWorkCount => _items.where((e) => e.status == 'in_work').length;
  int get _readyCount => _items.where((e) => e.status == 'ready').length;

  String _statusText(String status) {
    switch (status) {
      case 'new':
        return 'Р СњР С•Р Р†РЎвЂ№Р в„–';
      case 'in_work':
        return 'Р вЂ™ РЎР‚Р В°Р В±Р С•РЎвЂљР Вµ';
      case 'ready':
        return 'Р вЂњР С•РЎвЂљР С•Р Р†';
      case 'completed':
        return 'Р вЂ™РЎвЂ№Р Т‘Р В°Р Р…';
      case 'cancelled':
        return 'Р С›РЎвЂљР СР ВµР Р…РЎвЂР Р…';
      case 'expired':
        return 'Р СџРЎР‚Р С•Р С—РЎС“РЎвЂ°Р ВµР Р…';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'new':
        return kPreorderOrange;
      case 'in_work':
        return kPreorderBlue;
      case 'ready':
        return kPreorderGreen;
      case 'completed':
        return kPreorderGreen;
      case 'cancelled':
        return kPreorderRed;
      case 'expired':
        return kPreorderOrange;
      default:
        return kPreorderSoft;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'new':
        return CupertinoIcons.bell_fill;
      case 'in_work':
        return CupertinoIcons.flame_fill;
      case 'ready':
        return CupertinoIcons.checkmark_seal_fill;
      case 'completed':
        return CupertinoIcons.archivebox_fill;
      case 'cancelled':
        return CupertinoIcons.xmark_circle_fill;
      case 'expired':
        return CupertinoIcons.exclamationmark_triangle_fill;
      default:
        return CupertinoIcons.bag_fill;
    }
  }

  Widget _heroMetric(String label, int value, IconData icon) {
    return Expanded(
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 520),
        tween: Tween(begin: 0, end: 1),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) {
          return Transform.translate(
            offset: Offset(0, 12 * (1 - t)),
            child: Opacity(opacity: t, child: child),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white.withOpacity(0.90), size: 18),
              const SizedBox(height: 9),
              Text(
                value.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.82),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerCard() {
    final activeCount = _activeItems.length;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glow = 0.20 + (_pulseController.value * 0.12);
        return Container(
          padding: const EdgeInsets.all(22),
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            gradient: const LinearGradient(
              colors: [kPreorderMintLight, kPreorderMint, kPreorderDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: kPreorderMint.withOpacity(glow),
                blurRadius: 38,
                offset: const Offset(0, 20),
              ),
              BoxShadow(
                color: kPreorderDeep.withOpacity(0.12),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -34,
            child: Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.10),
              ),
            ),
          ),
          Positioned(
            right: 36,
            bottom: -42,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 700),
                    tween: Tween(begin: 0.92, end: 1),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.24),
                        ),
                      ),
                      child: const Icon(
                        CupertinoIcons.bag_fill,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Р вЂ”Р В°Р С”Р В°Р В·РЎвЂ№',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.9,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          activeCount > 0
                              ? '$activeCount Р В°Р С”РЎвЂљР С‘Р Р†Р Р…РЎвЂ№РЎвЂ¦ Р В·Р В°Р С”Р В°Р В·Р С•Р Р† РЎРѓР ВµР в„–РЎвЂЎР В°РЎРѓ'
                              : 'Р С’Р С”РЎвЂљР С‘Р Р†Р Р…РЎвЂ№РЎвЂ¦ Р В·Р В°Р С”Р В°Р В·Р С•Р Р† РЎРѓР ВµР в„–РЎвЂЎР В°РЎРѓ Р Р…Р ВµРЎвЂљ',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.88),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _heroMetric(
                    'Р Р…Р С•Р Р†РЎвЂ№Р Вµ',
                    _newCount,
                    CupertinoIcons.bell_fill,
                  ),
                  const SizedBox(width: 9),
                  _heroMetric(
                    'Р Р† РЎР‚Р В°Р В±Р С•РЎвЂљР Вµ',
                    _inWorkCount,
                    CupertinoIcons.flame_fill,
                  ),
                  const SizedBox(width: 9),
                  _heroMetric(
                    'Р С–Р С•РЎвЂљР С•Р Р†РЎвЂ№',
                    _readyCount,
                    CupertinoIcons.checkmark_seal_fill,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 11),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: const LinearGradient(
                colors: [kPreorderMint, kPreorderDeep],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: kPreorderInk,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.55,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: kPreorderStroke),
            ),
            child: Text(
              subtitle,
              style: const TextStyle(
                color: kPreorderSoft,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String text,
    required Color color,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: SizedBox(
        height: 46,
        child: ElevatedButton.icon(
          onPressed: _updating ? null : onTap,
          icon: Icon(icon, size: 16),
          label: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            disabledBackgroundColor: color.withOpacity(0.34),
            disabledForegroundColor: Colors.white.withOpacity(0.72),
            elevation: 0,
            shadowColor: color.withOpacity(0.22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: const TextStyle(
              fontSize: 12.4,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeLine({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.075),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Text(
            '$label: ',
            style: const TextStyle(
              color: kPreorderSoft,
              fontSize: 12.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: kPreorderInk,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentLine(_PreorderItem item) {
    final isCard = item.paymentMethod == 'card';
    final isCash = item.paymentMethod == 'cash';

    final color = isCard
        ? kPreorderBlue
        : isCash
        ? kPreorderGreen
        : kPreorderSoft;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Icon(item.paymentIcon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            item.paymentLabel,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _accrualLine(_PreorderItem item) {
    final amount = item.amountTotal;
    final bonus = item.bonusAccrued;

    final parts = <String>[];
    if (amount != null && amount > 0) {
      parts.add('Р В§Р ВµР С” ${_formatMoney(amount)} РІвЂљР…');
    }
    if (bonus != null && bonus > 0) {
      parts.add(
        'Р Р…Р В°РЎвЂЎР С‘РЎРѓР В»Р ВµР Р…Р С• ${_formatMoney(bonus)} Р В±Р В°Р В»Р В»Р С•Р Р†',
      );
    }

    if (parts.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: kPreorderGreen.withOpacity(0.10),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: kPreorderGreen.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.sparkles, size: 18, color: kPreorderGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              parts.join('  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: kPreorderGreen,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderCard(_PreorderItem item, int index) {
    final statusColor = _statusColor(item.status);
    final isActive =
        item.status == 'new' ||
        item.status == 'in_work' ||
        item.status == 'ready';

    Widget card = TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 420 + (index.clamp(0, 6) * 70)),
      tween: Tween(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - t)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kPreorderCard,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isActive ? statusColor.withOpacity(0.34) : kPreorderStroke,
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isActive ? statusColor : Colors.black).withOpacity(
                isActive ? 0.14 : 0.045,
              ),
              blurRadius: isActive ? 30 : 18,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -24,
              top: -28,
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withOpacity(0.07),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(19),
                        gradient: LinearGradient(
                          colors: [statusColor, statusColor.withOpacity(0.64)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.22),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        _statusIcon(item.status),
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.clientName.isEmpty
                                ? 'Р С™Р В»Р С‘Р ВµР Р…РЎвЂљ'
                                : 'Р вЂ”Р В°Р С”Р В°Р В·Р В°Р В»: ${item.clientName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: kPreorderInk,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.clientPhone.isEmpty
                                ? 'Р СћР ВµР В»Р ВµРЎвЂћР С•Р Р… Р Р…Р Вµ РЎС“Р С”Р В°Р В·Р В°Р Р…'
                                : item.clientPhone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: kPreorderSoft,
                              fontSize: 12.7,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: statusColor.withOpacity(0.14),
                        ),
                      ),
                      child: Text(
                        _statusText(item.status),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11.4,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.orderText.trim().isEmpty
                      ? 'Р вЂ”Р В°Р С”Р В°Р В· Р В±Р ВµР В· Р С•Р С—Р С‘РЎРѓР В°Р Р…Р С‘РЎРЏ'
                      : item.orderText.trim(),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kPreorderInk,
                    fontSize: 15.2,
                    height: 1.36,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _timeLine(
                        icon: CupertinoIcons.arrow_down_circle_fill,
                        label: 'Р СџР С•РЎРѓРЎвЂљРЎС“Р С—Р С‘Р В»',
                        value: item.createdLabel,
                        color: kPreorderBlue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _timeLine(
                        icon: CupertinoIcons.clock_fill,
                        label: 'Р вЂ”Р В°Р В±РЎР‚Р В°РЎвЂљРЎРЉ',
                        value: item.pickupLabel,
                        color: kPreorderOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _paymentLine(item),
                if (item.amountTotal != null || item.bonusAccrued != null) ...[
                  const SizedBox(height: 8),
                  _accrualLine(item),
                ],
                const SizedBox(height: 12),
                if (item.status == 'new') ...[
                  Row(
                    children: [
                      _actionButton(
                        text: 'Р вЂ™ РЎР‚Р В°Р В±Р С•РЎвЂљР Вµ',
                        color: kPreorderBlue,
                        icon: CupertinoIcons.flame_fill,
                        onTap: () => _setStatus(item, 'in_work'),
                      ),
                      const SizedBox(width: 8),
                      _actionButton(
                        text: 'Р С›РЎвЂљР СР ВµР Р…Р С‘РЎвЂљРЎРЉ',
                        color: kPreorderRed,
                        icon: CupertinoIcons.xmark_circle_fill,
                        onTap: () => _setStatus(item, 'cancelled'),
                      ),
                    ],
                  ),
                ] else if (item.status == 'in_work') ...[
                  Row(
                    children: [
                      _actionButton(
                        text: 'Р вЂњР С•РЎвЂљР С•Р Р†',
                        color: kPreorderGreen,
                        icon: CupertinoIcons.checkmark_seal_fill,
                        onTap: () => _setStatus(item, 'ready'),
                      ),
                      const SizedBox(width: 8),
                      _actionButton(
                        text: 'Р С›РЎвЂљР СР ВµР Р…Р С‘РЎвЂљРЎРЉ',
                        color: kPreorderRed,
                        icon: CupertinoIcons.xmark_circle_fill,
                        onTap: () => _setStatus(item, 'cancelled'),
                      ),
                    ],
                  ),
                ] else if (item.status == 'ready') ...[
                  Row(
                    children: [
                      _actionButton(
                        text: 'Р вЂ™РЎвЂ№Р Т‘Р В°Р Р…',
                        color: kPreorderDeep,
                        icon: CupertinoIcons.archivebox_fill,
                        onTap: () => _completePreorder(item),
                      ),
                      const SizedBox(width: 8),
                      _actionButton(
                        text: 'Р С›РЎвЂљР СР ВµР Р…Р С‘РЎвЂљРЎРЉ',
                        color: kPreorderRed,
                        icon: CupertinoIcons.xmark_circle_fill,
                        onTap: () => _setStatus(item, 'cancelled'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );

    if (!isActive) return card;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.010);
        return Transform.scale(scale: scale, child: child);
      },
      child: card,
    );
  }

  Widget _doneCompactRow(_PreorderItem item) {
    final statusColor = _statusColor(item.status);

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 360),
      tween: Tween(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - t)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.86),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kPreorderStroke),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _statusIcon(item.status),
                color: statusColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.doneCompactTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kPreorderInk,
                  fontSize: 13.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              item.createdLabel,
              style: const TextStyle(
                color: kPreorderSoft,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ordersGrid(List<_PreorderItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;

        if (!isWide) {
          return Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                _orderCard(items[i], i),
                if (i != items.length - 1) const SizedBox(height: 13),
              ],
            ],
          );
        }

        return GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.22,
          ),
          itemBuilder: (context, index) => _orderCard(items[index], index),
        );
      },
    );
  }

  Widget _emptyState() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 520),
      tween: Tween(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - t)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: kPreorderStroke),
          boxShadow: [
            BoxShadow(
              color: kPreorderDeep.withOpacity(0.05),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [kPreorderMintLight, kPreorderMint, kPreorderDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: kPreorderMint.withOpacity(0.24),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                CupertinoIcons.bag_badge_plus,
                color: Colors.white,
                size: 31,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Р С’Р С”РЎвЂљР С‘Р Р†Р Р…РЎвЂ№РЎвЂ¦ Р С—РЎР‚Р ВµР Т‘Р В·Р В°Р С”Р В°Р В·Р С•Р Р† Р Р…Р ВµРЎвЂљ',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kPreorderInk,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.25,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Р С™Р С•Р С–Р Т‘Р В° Р С”Р В»Р С‘Р ВµР Р…РЎвЂљ Р С•РЎвЂљР С—РЎР‚Р В°Р Р†Р С‘РЎвЂљ Р В·Р В°Р С”Р В°Р В·, Р С•Р Р… Р С—Р С•РЎРЏР Р†Р С‘РЎвЂљРЎРѓРЎРЏ Р В·Р Т‘Р ВµРЎРѓРЎРЉ. Р СџР С•РЎвЂљРЎРЏР Р…Р С‘РЎвЂљР Вµ РЎРЊР С”РЎР‚Р В°Р Р… Р Р†Р Р…Р С‘Р В·, РЎвЂЎРЎвЂљР С•Р В±РЎвЂ№ Р С•Р В±Р Р…Р С•Р Р†Р С‘РЎвЂљРЎРЉ РЎРѓР С—Р С‘РЎРѓР С•Р С”.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kPreorderSoft,
                fontSize: 13.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBanner() {
    if (_error == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kPreorderRed.withOpacity(0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kPreorderRed.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: kPreorderRed,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                color: kPreorderRed,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeItems = _activeItems;
    final doneItems = _doneItems.take(10).toList();

    return Scaffold(
      backgroundColor: kPreorderBg,
      appBar: AppBar(
        backgroundColor: kPreorderBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: kPreorderInk,
        title: const Text(
          'Р СџРЎР‚Р ВµР Т‘Р В·Р В°Р С”Р В°Р В·РЎвЂ№',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.35),
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
                color: kPreorderMint,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                  children: [
                    _headerCard(),
                    _errorBanner(),
                    _sectionTitle(
                      'Р С’Р С”РЎвЂљР С‘Р Р†Р Р…РЎвЂ№Р Вµ',
                      '${activeItems.length} Р В·Р В°Р С”Р В°Р В·Р С•Р Р†',
                    ),
                    if (activeItems.isEmpty)
                      _emptyState()
                    else
                      _ordersGrid(activeItems),
                    if (doneItems.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _sectionTitle(
                        'Р СњР ВµР Т‘Р В°Р Р†Р Р…Р С‘Р Вµ',
                        '${doneItems.length}',
                      ),
                      ...doneItems.map(_doneCompactRow),
                    ],
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
  final String paymentMethod;
  final String createdAt;
  final String? pickupAt;
  final double? amountTotal;
  final double? bonusAccrued;

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
    required this.paymentMethod,
    required this.createdAt,
    required this.pickupAt,
    required this.amountTotal,
    required this.bonusAccrued,
  });

  factory _PreorderItem.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString().replaceAll(',', '.'));
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
      paymentMethod: json['payment_method']?.toString() ?? 'unknown',
      createdAt: json['created_at']?.toString() ?? '',
      pickupAt: json['pickup_at']?.toString(),
      amountTotal: parseDouble(json['amount_total']),
      bonusAccrued: parseDouble(json['bonus_accrued']),
    );
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';

    try {
      final dt = DateTime.parse(raw).toLocal();
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    } catch (_) {
      return raw;
    }
  }

  String get doneCompactTitle {
    final order = orderText.trim().isEmpty
        ? 'Р вЂ”Р В°Р С”Р В°Р В· Р В±Р ВµР В· Р С•Р С—Р С‘РЎРѓР В°Р Р…Р С‘РЎРЏ'
        : orderText.trim();
    final name = clientName.trim();

    if (status == 'expired') {
      if (name.isEmpty) {
        return 'Р СџРЎР‚Р С•Р С—РЎС“РЎвЂ°Р ВµР Р…: $order';
      }
      return 'Р СџРЎР‚Р С•Р С—РЎС“РЎвЂ°Р ВµР Р…: $name  $order';
    }

    if (name.isEmpty) {
      return order;
    }

    return 'Р вЂ”Р В°Р С”Р В°Р В·Р В°Р В»: $name  $order';
  }

  String get paymentLabel {
    switch (paymentMethod) {
      case 'card':
        return 'Р С›Р С—Р В»Р В°РЎвЂљР В° Р С”Р В°РЎР‚РЎвЂљР С•Р в„–';
      case 'cash':
        return 'Р СњР В°Р В»Р С‘РЎвЂЎР Р…РЎвЂ№Р СР С‘';
      default:
        return 'Р С›Р С—Р В»Р В°РЎвЂљР В° Р Р…Р Вµ РЎС“Р С”Р В°Р В·Р В°Р Р…Р В°';
    }
  }

  IconData get paymentIcon {
    switch (paymentMethod) {
      case 'card':
        return Icons.credit_card_rounded;
      case 'cash':
        return Icons.payments_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String get createdLabel => _formatTime(createdAt);

  String get pickupLabel {
    final exact = _formatTime(pickupAt);
    if (exact != '') return exact;

    if (pickupType == 'asap')
      return 'Р С”Р В°Р С” Р СР С•Р В¶Р Р…Р С• РЎРѓР С”Р С•РЎР‚Р ВµР Вµ';
    if (pickupType == 'at_time')
      return 'Р С” Р Р†РЎвЂ№Р В±РЎР‚Р В°Р Р…Р Р…Р С•Р СРЎС“ Р Р†РЎР‚Р ВµР СР ВµР Р…Р С‘';

    final minutes = pickupMinutes ?? 0;
    if (minutes <= 0)
      return 'Р С”Р В°Р С” Р СР С•Р В¶Р Р…Р С• РЎРѓР С”Р С•РЎР‚Р ВµР Вµ';
    return 'РЎвЂЎР ВµРЎР‚Р ВµР В· $minutes Р СР С‘Р Р….';
  }
}
