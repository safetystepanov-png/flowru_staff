
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../data/staff_rewards_api.dart';
import 'staff_design_system.dart';
import 'staff_reward_redemptions_history_screen.dart';

class StaffRewardsScreen extends StatefulWidget {
  final String clientId;
  final String clientName;
  final int establishmentId;

  const StaffRewardsScreen({
    super.key,
    required this.clientId,
    required this.clientName,
    required this.establishmentId,
  });

  @override
  State<StaffRewardsScreen> createState() => _StaffRewardsScreenState();
}

class _StaffRewardsScreenState extends State<StaffRewardsScreen> {
  final StaffRewardsApi _api = StaffRewardsApi();

  bool _loading = true;
  String? _error;
  String? _success;
  List<StaffRewardItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadRewards();
  }

  Future<void> _loadRewards() async {
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      final items = await _api.getRewards(establishmentId: widget.establishmentId);
      if (!mounted) return;
      setState(() {
        _items = items.where((e) => e.isActive).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Ошибка загрузки наград';
      });
    }
  }

  Future<void> _redeemReward(StaffRewardItem reward) async {
    setState(() {
      _error = null;
      _success = null;
    });

    try {
      final result = await _api.redeemReward(
        clientId: widget.clientId,
        establishmentId: widget.establishmentId,
        rewardId: reward.rewardId,
        comment: 'Погашение из Staff',
      );
      if (!mounted) return;
      setState(() {
        _success = 'Награда погашена. Новый баланс: ${result.newBalance}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка погашения награды';
      });
    }
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StaffRewardRedemptionsHistoryScreen(
          clientId: widget.clientId,
          clientName: widget.clientName,
          establishmentId: widget.establishmentId,
        ),
      ),
    );
  }

  Widget _rewardCard(StaffRewardItem item) {
    return StaffGlassCard(
      glow: kHomePink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const StaffFloatingGlyph(
                icon: CupertinoIcons.gift_fill,
                mainColor: kHomePink,
                secondaryColor: kHomeViolet,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(item.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kHomeInk)),
              ),
            ],
          ),
          if ((item.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(item.description!, style: const TextStyle(fontSize: 13.5, height: 1.4, color: kHomeInkSoft, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 12),
          StaffInfoChip(label: 'Стоимость', value: '${item.pointsCost} баллов', color: kHomeBlue),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: StaffPillButton(
              text: 'Погасить',
              icon: CupertinoIcons.gift,
              onTap: () => _redeemReward(item),
              colors: const [kHomeBlue, kHomePink],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StaffUnifiedScaffold(
      title: 'Подарки / погашение',
      onRefresh: _loadRewards,
      actions: [
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _openHistory,
          child: const Icon(CupertinoIcons.time, color: Colors.white, size: 22),
        ),
      ],
      useList: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StaffGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.clientName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kHomeInk)),
                const SizedBox(height: 6),
                const Text('Доступные награды и быстрое погашение', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kHomeInkSoft)),
              ],
            ),
          ),
          if (_success != null) ...[
            const SizedBox(height: 12),
            StaffGlassCard(glow: kHomeMintTop, child: Text(_success!, style: const TextStyle(color: kHomeInk, fontWeight: FontWeight.w900))),
          ],
          const SizedBox(height: 14),
          if (_loading)
            const StaffStateCard(icon: CupertinoIcons.clock_fill, title: 'Загрузка', subtitle: 'Получаем награды', glow: kHomeBlue)
          else if (_error != null)
            StaffStateCard(icon: CupertinoIcons.exclamationmark_circle_fill, title: 'Ошибка', subtitle: _error!, glow: kHomeAccentRed)
          else if (_items.isEmpty)
            const StaffStateCard(icon: CupertinoIcons.gift, title: 'Пока пусто', subtitle: 'Доступных наград пока нет', glow: kHomePink)
          else
            ..._items.map((e) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _rewardCard(e))),
        ],
      ),
    );
  }
}
