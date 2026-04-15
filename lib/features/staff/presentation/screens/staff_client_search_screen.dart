import 'dart:convert';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../auth/data/auth_storage.dart';
import '../../../../core/config/app_config.dart';
import '../widgets/staff_glass_ui.dart';
import 'staff_client_detail_screen.dart';
import 'staff_qr_search_screen.dart';

class StaffClientSearchScreen extends StatefulWidget {
  final int establishmentId;
  final String establishmentName;

  const StaffClientSearchScreen({
    super.key,
    required this.establishmentId,
    required this.establishmentName,
  });

  @override
  State<StaffClientSearchScreen> createState() =>
      _StaffClientSearchScreenState();
}

class _StaffClientSearchScreenState extends State<StaffClientSearchScreen> {
  final TextEditingController _controller = TextEditingController();

  bool _loading = false;
  String? _error;
  List<_ClientSearchItem> _items = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Access token not found');
    }
    return token;
  }

  Future<void> _search() async {
    final query = _controller.text.trim();

    if (query.isEmpty) {
      setState(() {
        _items = [];
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await _token();

      final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/v1/staff/clients/search'
        '?establishment_id=${widget.establishmentId}'
        '&query=${Uri.encodeQueryComponent(query)}',
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
          'search failed: ${response.statusCode} ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);

      List<dynamic> raw;
      if (decoded is List) {
        raw = decoded;
      } else if (decoded is Map<String, dynamic> && decoded['items'] is List) {
        raw = decoded['items'] as List<dynamic>;
      } else if (decoded is Map<String, dynamic> &&
          decoded['clients'] is List) {
        raw = decoded['clients'] as List<dynamic>;
      } else {
        raw = [];
      }

      if (!mounted) return;

      setState(() {
        _items = raw
            .map((e) => _ClientSearchItem.fromJson(e as Map<String, dynamic>))
            .where((e) => e.clientId.isNotEmpty)
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось найти клиента';
      });
    }
  }

  Future<void> _openQrSearch() async {
    final result = await Navigator.of(context).push<_QrSearchResult>(
      MaterialPageRoute(
        builder: (_) => StaffQrSearchScreen(
          establishmentId: widget.establishmentId,
          establishmentName: widget.establishmentName,
        ),
      ),
    );

    if (result == null) return;

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StaffClientDetailScreen(
          establishmentId: widget.establishmentId,
          establishmentName: widget.establishmentName,
          clientId: result.clientId,
        ),
      ),
    );
  }

  void _openClient(_ClientSearchItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StaffClientDetailScreen(
          establishmentId: widget.establishmentId,
          establishmentName: widget.establishmentName,
          clientId: item.clientId,
        ),
      ),
    );
  }

  Widget _headerCard() {
    return StaffGlassPanel(
      radius: 28,
      glowColor: kStaffBlue.withOpacity(0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.establishmentName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: kStaffInkPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Поиск по телефону, имени или QR-коду',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: kStaffInkSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchCard() {
    return StaffGlassPanel(
      radius: 26,
      glowColor: kStaffViolet.withOpacity(0.10),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            onSubmitted: (_) => _search(),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Телефон, имя, номер клиента',
              hintStyle: TextStyle(
                color: kStaffInkSecondary,
                fontWeight: FontWeight.w700,
              ),
              prefixIcon: Icon(
                CupertinoIcons.search,
                color: kStaffInkSecondary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [kStaffBlue, kStaffViolet],
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: _loading ? null : _search,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Найти',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [kStaffPink, kStaffViolet],
                  ),
                ),
                child: ElevatedButton(
                  onPressed: _openQrSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.qrcode_viewfinder,
                        color: Colors.white,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Сканер',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
      radius: 24,
      child: Column(
        children: [
          StaffGradientIcon(icon: icon, size: 24),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
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
              fontWeight: FontWeight.w700,
              color: kStaffInkSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _clientCard(_ClientSearchItem item) {
    return StaffGlassPanel(
      radius: 24,
      glowColor: kStaffBlue.withOpacity(0.08),
      onTap: () => _openClient(item),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [kStaffBlue, kStaffPink],
              ),
            ),
            child: Center(
              child: Text(
                item.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: kStaffInkPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.phone.isEmpty ? 'Телефон не указан' : item.phone,
                  style: const TextStyle(
                    fontSize: 13.5,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kStaffBgTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Поиск клиента',
          style: TextStyle(
            color: kStaffInkPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        iconTheme: const IconThemeData(color: kStaffInkPrimary),
      ),
      body: StaffScreenBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _headerCard(),
              const SizedBox(height: 14),
              _searchCard(),
              const SizedBox(height: 14),
              if (_error != null)
                _stateCard(
                  icon: CupertinoIcons.exclamationmark_circle_fill,
                  title: 'Ошибка',
                  subtitle: _error!,
                )
              else if (_items.isEmpty)
                _stateCard(
                  icon: CupertinoIcons.person_2_fill,
                  title: 'Начни поиск',
                  subtitle:
                      'Введи телефон или имя клиента,\nлибо открой QR-сканер',
                )
              else
                ..._items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _clientCard(item),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClientSearchItem {
  final String clientId;
  final String fullName;
  final String phone;

  _ClientSearchItem({
    required this.clientId,
    required this.fullName,
    required this.phone,
  });

  factory _ClientSearchItem.fromJson(Map<String, dynamic> json) {
    return _ClientSearchItem(
      clientId: json['client_id']?.toString() ??
          json['id']?.toString() ??
          '',
      fullName: json['full_name']?.toString() ??
          json['name']?.toString() ??
          '',
      phone: json['phone']?.toString() ?? '',
    );
  }

  String get displayName {
    if (fullName.trim().isNotEmpty) return fullName.trim();
    if (phone.trim().isNotEmpty) return phone.trim();
    return 'Клиент';
  }

  String get initials {
    final parts = displayName
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'C';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _QrSearchResult {
  final String clientId;

  const _QrSearchResult({
    required this.clientId,
  });
}