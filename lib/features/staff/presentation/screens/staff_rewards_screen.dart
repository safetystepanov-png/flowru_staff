import 'package:flutter/material.dart';

import '../../data/staff_rewards_api.dart';
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
      final items = await _api.getRewards(
        establishmentId: widget.establishmentId,
      );

      if (!mounted) return;

      setState(() {
        _items = items.where((e) => e.isActive).toList();
        _loading = false;
      });
    } catch (e) {
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
    } catch (e) {
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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(item.description ?? '-'),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${item.pointsCost} баллов',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _redeemReward(item),
                icon: const Icon(Icons.card_giftcard),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Погасить'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Подарки / погашение'),
        actions: [
          IconButton(
            onPressed: _openHistory,
            icon: const Icon(Icons.history),
          ),
          IconButton(
            onPressed: _loadRewards,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.clientName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_success != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            _success!,
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                      if (_items.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Text('Доступных наград пока нет'),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) => _rewardCard(_items[index]),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}