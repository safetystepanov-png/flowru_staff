
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../data/staff_rewards_api.dart';
import 'staff_design_system.dart';

class StaffRewardRedemptionsHistoryScreen extends StatefulWidget {
  final String clientId;
  final String clientName;
  final int establishmentId;

  const StaffRewardRedemptionsHistoryScreen({
    super.key,
    required this.clientId,
    required this.clientName,
    required this.establishmentId,
  });

  @override
  State<StaffRewardRedemptionsHistoryScreen> createState() => _StaffRewardRedemptionsHistoryScreenState();
}

class _StaffRewardRedemptionsHistoryScreenState extends State<StaffRewardRedemptionsHistoryScreen> {
  final StaffRewardsApi _api = StaffRewardsApi();

  bool _loading = true;
  String? _error;
  List<StaffRewardRedemptionHistoryItem> _items = [];

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
      final items = await _api.getRedemptionHistory(
        clientId: widget.clientId,
        establishmentId: widget.establishmentId,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка загрузки истории погашений';
        _loading = false;
      });
    }
  }

  Widget _itemCard(StaffRewardRedemptionHistoryItem item) {
    return StaffGlassCard(
      glow: kHomePink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.rewardTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: kHomeInk)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: StaffInfoChip(label: 'Баллы', value: '${item.pointsSpent}', color: kHomeBlue)),
              const SizedBox(width: 10),
              Expanded(child: StaffInfoChip(label: 'Статус', value: item.status ?? '-', color: kHomePink)),
            ],
          ),
          const SizedBox(height: 10),
          Text('Дата: ${item.createdAt ?? '-'}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: kHomeInkSoft)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StaffUnifiedScaffold(
      title: 'История погашений',
      onRefresh: _load,
      useList: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StaffGlassCard(
            child: Text(widget.clientName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kHomeInk)),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const StaffStateCard(icon: CupertinoIcons.clock_fill, title: 'Загрузка', subtitle: 'Получаем историю погашений')
          else if (_error != null)
            StaffStateCard(icon: CupertinoIcons.exclamationmark_circle_fill, title: 'Ошибка', subtitle: _error!, glow: kHomeAccentRed)
          else if (_items.isEmpty)
            const StaffStateCard(icon: CupertinoIcons.clock, title: 'Пока пусто', subtitle: 'История погашений пока пустая', glow: kHomePink)
          else
            ..._items.map((e) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _itemCard(e))),
        ],
      ),
    );
  }
}
