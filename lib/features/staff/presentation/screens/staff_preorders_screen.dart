import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../auth/data/auth_storage.dart';
import '../../../auth/data/user_api.dart';
import '../../../../core/config/app_config.dart';

const Color _mint = Color(0xFF0BAEBB);
const Color _mintLight = Color(0xFF42E8DF);
const Color _deep = Color(0xFF064B64);
const Color _ink = Color(0xFF0A2B47);
const Color _soft = Color(0xFF557186);
const Color _bg = Color(0xFFF3FAFB);
const Color _stroke = Color(0xFFE3EEF3);
const Color _orange = Color(0xFFFFA51E);
const Color _blue = Color(0xFF246BFF);
const Color _green = Color(0xFF22C55E);
const Color _red = Color(0xFFFF6A5E);

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
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Сессия истекла. Войдите заново.');
    }
    return token.trim();
  }

  Future<String> _refreshAccessToken() async {
    final refreshToken = await AuthStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.trim().isEmpty) {
      throw Exception('Сессия истекла. Войдите заново.');
    }

    final result = await UserApi().refresh(
      refreshToken: refreshToken.trim(),
      deviceId: kIsWeb ? 'staff-web' : 'staff-mobile',
      platform: kIsWeb ? 'web' : 'mobile',
    );

    if (!result.ok || result.accessToken.trim().isEmpty) {
      throw Exception('Сессия истекла. Войдите заново.');
    }

    await AuthStorage.saveAccessToken(result.accessToken.trim());

    if (result.refreshToken.trim().isNotEmpty) {
      await AuthStorage.saveRefreshToken(result.refreshToken.trim());
    }

    return result.accessToken.trim();
  }

  Future<Map<String, String>> _headers({
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

      var response = await http.get(uri, headers: await _headers());

      if (response.statusCode == 401 || response.statusCode == 403) {
        response = await http.get(
          uri,
          headers: await _headers(forceRefresh: true),
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
        _error = message.isEmpty ? 'Не удалось загрузить предзаказы' : message;
      });
    }
  }

  String _statusErrorMessage(int statusCode, String body) {
    if (statusCode == 401 || statusCode == 403) {
      return 'Сессия истекла. Войдите заново.';
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] != null) {
        final detail = decoded['detail'].toString().trim();

        if (detail.toLowerCase().contains('invalid token')) {
          return 'Сессия истекла. Войдите заново.';
        }

        if (detail.isNotEmpty) return detail;
      }
    } catch (_) {}

    if (statusCode == 400) {
      return 'Проверьте сумму чека и настройки начисления';
    }

    return 'Не удалось обновить статус';
  }

  double? _parseAmount(String raw) {
    final normalized = raw
        .trim()
        .replaceAll(' ', '')
        .replaceAll('₽', '')
        .replaceAll(',', '.');

    if (normalized.isEmpty) return null;

    final value = double.tryParse(normalized);
    if (value == null || value <= 0) return null;

    return value;
  }

  String _formatMoney(double value) {
    if (value == value.roundToDouble()) return value.round().toString();
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
                        colors: [_mintLight, _mint, _deep],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.payments_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Сумма чека',
                      style: TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w900,
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
                    'Введите сумму, которую клиент оплатил за заказ. После выдачи Flowru автоматически начислит бонусы.',
                    style: TextStyle(
                      color: _soft,
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
                      labelText: 'Сумма чека, ₽',
                      hintText: 'Например, 350',
                      errorText: localError,
                      filled: true,
                      fillColor: _bg,
                      prefixIcon: const Icon(Icons.payments_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: _stroke),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: _stroke),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: _mint, width: 1.7),
                      ),
                    ),
                    onSubmitted: (_) {
                      final amount = _parseAmount(controller.text);
                      if (amount == null) {
                        setDialogState(() {
                          localError = 'Введите сумму больше 0';
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
                    'Назад',
                    style: TextStyle(color: _soft, fontWeight: FontWeight.w900),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final amount = _parseAmount(controller.text);
                    if (amount == null) {
                      setDialogState(() {
                        localError = 'Введите сумму больше 0';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(amount);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _deep,
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
                    'Выдать',
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
        headers: await _headers(json: true),
        body: jsonEncode(payload),
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        response = await http.post(
          uri,
          headers: await _headers(json: true, forceRefresh: true),
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
        _error = message.isEmpty ? 'Не удалось обновить статус' : message;
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
        return 'Новый';
      case 'in_work':
        return 'В работе';
      case 'ready':
        return 'Готов';
      case 'completed':
        return 'Выдан';
      case 'cancelled':
        return 'Отменён';
      case 'expired':
        return 'Пропущен';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'new':
        return _orange;
      case 'in_work':
        return _blue;
      case 'ready':
        return _green;
      case 'completed':
        return _green;
      case 'cancelled':
        return _red;
      case 'expired':
        return _orange;
      default:
        return _soft;
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

  Widget _fadeIn({required Widget child, int delay = 0}) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 420 + delay),
      tween: Tween(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _heroMetric(String label, int value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.88), size: 18),
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
    );
  }

  Widget _heroCard() {
    final activeCount = _activeItems.length;

    return AnimatedBuilder(
      animation: _motion,
      builder: (context, child) {
        final glow = 0.16 + (_motion.value * 0.10);
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            gradient: const LinearGradient(
              colors: [_mintLight, _mint, _deep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _mint.withOpacity(glow),
                blurRadius: 36,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Stack(
        children: [
          Positioned(
            right: -26,
            top: -32,
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
            right: 34,
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
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.22)),
                    ),
                    child: const Icon(
                      CupertinoIcons.bag_fill,
                      color: Colors.white,
                      size: 31,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Предзаказы',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          activeCount > 0
                              ? '$activeCount активных заказов сейчас'
                              : 'Активных заказов сейчас нет',
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
                  _heroMetric('новые', _newCount, CupertinoIcons.bell_fill),
                  const SizedBox(width: 9),
                  _heroMetric(
                    'в работе',
                    _inWorkCount,
                    CupertinoIcons.flame_fill,
                  ),
                  const SizedBox(width: 9),
                  _heroMetric(
                    'готовы',
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

  Widget _sectionHeader(String title, String count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 11),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: const LinearGradient(
                colors: [_mintLight, _mint, _deep],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _stroke),
            ),
            child: Text(
              count,
              style: const TextStyle(
                color: _soft,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoLine({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Text(
            '$label: ',
            style: const TextStyle(
              color: _soft,
              fontSize: 12.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill({
    required IconData icon,
    required String text,
    required Color color,
  }) {
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
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 13,
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
        ? _blue
        : isCash
        ? _green
        : _soft;

    return _pill(icon: item.paymentIcon, text: item.paymentLabel, color: color);
  }

  Widget _accrualLine(_PreorderItem item) {
    final amount = item.amountTotal;
    final bonus = item.bonusAccrued;

    final parts = <String>[];
    if (amount != null && amount > 0) {
      parts.add('Чек ${_formatMoney(amount)} ₽');
    }
    if (bonus != null && bonus > 0) {
      parts.add('начислено ${_formatMoney(bonus)} баллов');
    }

    if (parts.isEmpty) return const SizedBox.shrink();

    return _pill(
      icon: CupertinoIcons.sparkles,
      text: parts.join(' • '),
      color: _green,
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

  Widget _orderCard(_PreorderItem item, int index) {
    final statusColor = _statusColor(item.status);
    final isActive =
        item.status == 'new' ||
        item.status == 'in_work' ||
        item.status == 'ready';

    return _fadeIn(
      delay: index.clamp(0, 6) * 70,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: isActive ? 1.0 : 0.995,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isActive ? statusColor.withOpacity(0.30) : _stroke,
              width: isActive ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (isActive ? statusColor : Colors.black).withOpacity(
                  isActive ? 0.12 : 0.045,
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
                      AnimatedBuilder(
                        animation: _motion,
                        builder: (context, child) {
                          final scale = item.status == 'new'
                              ? 1.0 + (_motion.value * 0.035)
                              : 1.0;
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(19),
                            gradient: LinearGradient(
                              colors: [
                                statusColor,
                                statusColor.withOpacity(0.65),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Icon(
                            _statusIcon(item.status),
                            color: Colors.white,
                            size: 23,
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.clientName.isEmpty
                                  ? 'Клиент'
                                  : 'Заказал: ${item.clientName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.clientPhone.isEmpty
                                  ? 'Телефон не указан'
                                  : item.clientPhone,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _soft,
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
                        ? 'Заказ без описания'
                        : item.orderText.trim(),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 15.2,
                      height: 1.36,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _infoLine(
                          icon: CupertinoIcons.arrow_down_circle_fill,
                          label: 'Поступил',
                          value: item.createdLabel,
                          color: _blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _infoLine(
                          icon: CupertinoIcons.clock_fill,
                          label: 'Забрать',
                          value: item.pickupLabel,
                          color: _orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _paymentLine(item),
                  if (item.amountTotal != null ||
                      item.bonusAccrued != null) ...[
                    const SizedBox(height: 8),
                    _accrualLine(item),
                  ],
                  const SizedBox(height: 12),
                  if (item.status == 'new')
                    Row(
                      children: [
                        _actionButton(
                          text: 'В работе',
                          color: _blue,
                          icon: CupertinoIcons.flame_fill,
                          onTap: () => _setStatus(item, 'in_work'),
                        ),
                        const SizedBox(width: 8),
                        _actionButton(
                          text: 'Отменить',
                          color: _red,
                          icon: CupertinoIcons.xmark_circle_fill,
                          onTap: () => _setStatus(item, 'cancelled'),
                        ),
                      ],
                    )
                  else if (item.status == 'in_work')
                    Row(
                      children: [
                        _actionButton(
                          text: 'Готов',
                          color: _green,
                          icon: CupertinoIcons.checkmark_seal_fill,
                          onTap: () => _setStatus(item, 'ready'),
                        ),
                        const SizedBox(width: 8),
                        _actionButton(
                          text: 'Отменить',
                          color: _red,
                          icon: CupertinoIcons.xmark_circle_fill,
                          onTap: () => _setStatus(item, 'cancelled'),
                        ),
                      ],
                    )
                  else if (item.status == 'ready')
                    Row(
                      children: [
                        _actionButton(
                          text: 'Выдан',
                          color: _deep,
                          icon: CupertinoIcons.archivebox_fill,
                          onTap: () => _completePreorder(item),
                        ),
                        const SizedBox(width: 8),
                        _actionButton(
                          text: 'Отменить',
                          color: _red,
                          icon: CupertinoIcons.xmark_circle_fill,
                          onTap: () => _setStatus(item, 'cancelled'),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _doneRow(_PreorderItem item) {
    final statusColor = _statusColor(item.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.90),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _stroke),
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
            child: Icon(_statusIcon(item.status), color: statusColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.doneCompactTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontSize: 13.2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.createdLabel,
            style: const TextStyle(
              color: _soft,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ordersList(List<_PreorderItem> items) {
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
            childAspectRatio: 1.18,
          ),
          itemBuilder: (context, index) => _orderCard(items[index], index),
        );
      },
    );
  }

  Widget _emptyState() {
    return _fadeIn(
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: _stroke),
          boxShadow: [
            BoxShadow(
              color: _deep.withOpacity(0.05),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_mintLight, _mint, _deep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                CupertinoIcons.bag_badge_plus,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Активных предзаказов нет',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ink,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Когда клиент отправит заказ, он появится здесь. Потяните экран вниз, чтобы обновить список.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _soft,
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
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: _red.withOpacity(0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _red.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: _red,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                color: _red,
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
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _ink,
        title: const Text(
          'Предзаказы',
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
                color: _mint,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                  children: [
                    _fadeIn(child: _heroCard()),
                    _errorBanner(),
                    _sectionHeader('Активные', '${activeItems.length} заказов'),
                    if (activeItems.isEmpty)
                      _emptyState()
                    else
                      _ordersList(activeItems),
                    if (doneItems.isNotEmpty) ...[
                      _sectionHeader('Недавние', '${doneItems.length}'),
                      ...doneItems.map(_doneRow),
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
        ? 'Заказ без описания'
        : orderText.trim();
    final name = clientName.trim();

    if (status == 'expired') {
      if (name.isEmpty) return 'Пропущен: $order';
      return 'Пропущен: $name  $order';
    }

    if (name.isEmpty) return order;

    return 'Заказал: $name  $order';
  }

  String get paymentLabel {
    switch (paymentMethod) {
      case 'card':
        return 'Оплата картой';
      case 'cash':
        return 'Наличными';
      default:
        return 'Оплата не указана';
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

    if (pickupType == 'asap') return 'как можно скорее';
    if (pickupType == 'at_time') return 'к выбранному времени';

    final minutes = pickupMinutes ?? 0;
    if (minutes <= 0) return 'как можно скорее';
    return 'через $minutes мин.';
  }
}
