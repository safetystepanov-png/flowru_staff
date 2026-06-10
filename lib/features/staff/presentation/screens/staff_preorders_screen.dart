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
const Color kPreorderBg = Color(0xFFF3FAFB);
const Color kPreorderOrange = Color(0xFFFFA51E);
const Color kPreorderBlue = Color(0xFF246BFF);
const Color kPreorderGreen = Color(0xFF22C55E);
const Color kPreorderRed = Color(0xFFFF6A5E);
const Color kPreorderViolet = Color(0xFF7A4CFF);

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
      duration: const Duration(milliseconds: 950),
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
    } catch (_) {
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

  List<_PreorderItem> get _activeItems {
    final result = _items
        .where((e) => e.status == 'new' || e.status == 'in_work' || e.status == 'ready')
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
        .where((e) => e.status == 'completed' || e.status == 'cancelled')
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
      default:
        return CupertinoIcons.bag_fill;
    }
  }

  Widget _heroMetric(String label, int value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
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
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCard() {
    final activeCount = _activeItems.length;

    return Container(
      padding: const EdgeInsets.all(22),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFA51E),
            Color(0xFFFF6A5E),
            Color(0xFF7A4CFF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: kPreorderViolet.withOpacity(0.28),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(23),
                  border: Border.all(color: Colors.white.withOpacity(0.22)),
                ),
                child: const Icon(
                  CupertinoIcons.bag_fill,
                  color: Colors.white,
                  size: 29,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Заказы',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      activeCount > 0
                          ? '$activeCount активных'
                          : 'Активных заказов нет',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.86),
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
              _heroMetric('новые', _newCount),
              const SizedBox(width: 9),
              _heroMetric('в работе', _inWorkCount),
              const SizedBox(width: 9),
              _heroMetric('готовы', _readyCount),
            ],
          ),
        ],
      ),
    );
  }
  Widget _sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: kPreorderInk,
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.45,
              ),
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              color: kPreorderSoft,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
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

  Widget _timeLine({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
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
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kPreorderInk,
              fontSize: 12.4,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _orderCard(_PreorderItem item) {
    final statusColor = _statusColor(item.status);
    final isActive = item.status == 'new' || item.status == 'in_work' || item.status == 'ready';

    Widget card = Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isActive ? statusColor.withOpacity(0.35) : const Color(0xFFE3EEF3),
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isActive ? statusColor : Colors.black).withOpacity(isActive ? 0.16 : 0.045),
            blurRadius: isActive ? 26 : 16,
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
                  gradient: LinearGradient(
                    colors: [
                      statusColor,
                      statusColor.withOpacity(0.62),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
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
                      item.clientName.isEmpty ? 'Клиент' : 'Заказал: ${item.clientName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kPreorderInk,
                        fontSize: 16.5,
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
                        fontSize: 12.7,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusText(item.status),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            item.orderText,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kPreorderInk,
              fontSize: 15.2,
              height: 1.35,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          _timeLine(
            icon: CupertinoIcons.arrow_down_circle_fill,
            label: 'Поступил',
            value: item.createdLabel,
            color: kPreorderBlue,
          ),
          const SizedBox(height: 7),
          _timeLine(
            icon: CupertinoIcons.clock_fill,
            label: 'Забрать',
            value: item.pickupLabel,
            color: kPreorderOrange,
          ),
          const SizedBox(height: 10),
          if (item.status == 'new') ...[
            Row(
              children: [
                _actionButton(
                  text: 'В работе',
                  color: kPreorderBlue,
                  onTap: () => _setStatus(item, 'in_work'),
                ),
                const SizedBox(width: 8),
                _actionButton(
                  text: 'Отменить',
                  color: kPreorderRed,
                  onTap: () => _setStatus(item, 'cancelled'),
                ),
              ],
            ),
          ] else if (item.status == 'in_work') ...[
            Row(
              children: [
                _actionButton(
                  text: 'Готов',
                  color: kPreorderGreen,
                  onTap: () => _setStatus(item, 'ready'),
                ),
                const SizedBox(width: 8),
                _actionButton(
                  text: 'Отменить',
                  color: kPreorderRed,
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
                  color: kPreorderRed,
                  onTap: () => _setStatus(item, 'cancelled'),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    if (!isActive) return card;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.018);
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: card,
    );
  }

  Widget _doneCompactRow(_PreorderItem item) {
    final statusColor = _statusColor(item.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3EEF3)),
      ),
      child: Row(
        children: [
          Icon(
            _statusIcon(item.status),
            color: statusColor,
            size: 19,
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
    );
  }

  Widget _ordersGrid(List<_PreorderItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 680;

        if (!isWide) {
          return Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                _orderCard(items[i]),
                if (i != items.length - 1) const SizedBox(height: 12),
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
            childAspectRatio: 1.34,
          ),
          itemBuilder: (context, index) => _orderCard(items[index]),
        );
      },
    );
  }
  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE3EEF3)),
      ),
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kPreorderOrange, kPreorderViolet],
              ),
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Icon(
              CupertinoIcons.bag_badge_plus,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Активных предзаказов нет',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: kPreorderInk,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Когда клиент отправит заказ, он появится здесь.',
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
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                  children: [
                    _headerCard(),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: kPreorderRed.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: kPreorderRed,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                    _sectionTitle(
                      'Активные',
                      '${activeItems.length} заказов',
                    ),
                    if (activeItems.isEmpty)
                      _emptyState()
                    else
                      _ordersGrid(activeItems),
                    if (doneItems.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _sectionTitle(
                        'Недавние',
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
  final String createdAt;
  final String? pickupAt;

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
    required this.pickupAt,
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
      pickupAt: json['pickup_at']?.toString(),
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
    final order = orderText.trim().isEmpty ? 'Заказ без описания' : orderText.trim();
    final name = clientName.trim();

    if (name.isEmpty) {
      return order;
    }

    return 'Заказал: $name  $order';
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
