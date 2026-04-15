import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../auth/data/auth_storage.dart';
import '../../../../core/config/app_config.dart';
import '../widgets/staff_glass_ui.dart';

class StaffClientRewardsScreen extends StatefulWidget {
  final int establishmentId;
  final String establishmentName;
  final String clientId;
  final String clientName;

  const StaffClientRewardsScreen({
    super.key,
    required this.establishmentId,
    required this.establishmentName,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<StaffClientRewardsScreen> createState() =>
      _StaffClientRewardsScreenState();
}

class _StaffClientRewardsScreenState extends State<StaffClientRewardsScreen> {
  bool _loading = true;
  bool _redeeming = false;
  String? _error;
  List<_RewardItem> _items = [];

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
        '${AppConfig.baseUrl}/api/v1/staff/rewards?establishment_id=${widget.establishmentId}',
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
          'rewards failed: ${response.statusCode} ${response.body}',
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
            .map((e) => _RewardItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить награды';
      });
    }
  }

  Future<void> _redeem(_RewardItem item) async {
    if (_redeeming) return;

    setState(() {
      _redeeming = true;
      _error = null;
    });

    try {
      final token = await _token();

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/staff/rewards/redeem'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'establishment_id': widget.establishmentId,
          'client_id': widget.clientId,
          'reward_id': item.id,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'redeem failed: ${response.statusCode} ${response.body}',
        );
      }

      if (!mounted) return;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Готово'),
          content: Text(
            decoded['message']?.toString() ?? 'Награда успешно выдана',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _load();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось выдать награду';
      });
    } finally {
      if (mounted) {
        setState(() {
          _redeeming = false;
        });
      }
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

  Widget _rewardCard(_RewardItem item) {
    return StaffGlassPanel(
      radius: 24,
      glowColor: kStaffPink.withOpacity(0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const StaffGradientIcon(
                icon: CupertinoIcons.gift_fill,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: kStaffInkPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (item.description.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              item.description,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: kStaffInkSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: kStaffBlue.withOpacity(0.10),
                ),
                child: Text(
                  '${item.costLabel} баллов',
                  style: const TextStyle(
                    color: kStaffInkPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [kStaffBlue, kStaffPink],
                  ),
                ),
                child: ElevatedButton(
                  onPressed: _redeeming ? null : () => _redeem(item),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _redeeming
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Выдать',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
            ],
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
          'Награды',
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
                        glowColor: kStaffViolet.withOpacity(0.10),
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
                          icon: CupertinoIcons.gift_fill,
                          title: 'Наград пока нет',
                          subtitle: 'В этом заведении ещё не добавлены награды',
                        )
                      else
                        ..._items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _rewardCard(item),
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

class _RewardItem {
  final String id;
  final String title;
  final String description;
  final double cost;

  _RewardItem({
    required this.id,
    required this.title,
    required this.description,
    required this.cost,
  });

  factory _RewardItem.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return _RewardItem(
      id: json['id']?.toString() ?? json['reward_id']?.toString() ?? '',
      title: json['title']?.toString() ??
          json['name']?.toString() ??
          'Награда',
      description: json['description']?.toString() ?? '',
      cost: parseNum(
        json['cost'] ?? json['price'] ?? json['points_cost'],
      ),
    );
  }

  String get costLabel {
    if (cost == cost.roundToDouble()) {
      return cost.toInt().toString();
    }
    return cost.toStringAsFixed(2);
  }
}