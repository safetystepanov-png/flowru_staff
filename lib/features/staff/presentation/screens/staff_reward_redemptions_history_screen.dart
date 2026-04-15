import 'package:flutter/material.dart';

import '../../data/staff_rewards_api.dart';

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
  State<StaffRewardRedemptionsHistoryScreen> createState() =>
      _StaffRewardRedemptionsHistoryScreenState();
}

class _StaffRewardRedemptionsHistoryScreenState
    extends State<StaffRewardRedemptionsHistoryScreen> {
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка загрузки истории погашений';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('История погашений'),
        actions: [
          IconButton(
            onPressed: _load,
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
                : _items.isEmpty
                    ? const Center(child: Text('История погашений пока пустая'))
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
                          const SizedBox(height: 16),
                          Expanded(
                            child: ListView.separated(
                              itemCount: _items.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = _items[index];

                                return Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.rewardTitle,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text('Списано баллов: ${item.pointsSpent}'),
                                        const SizedBox(height: 4),
                                        Text('Статус: ${item.status ?? "-"}'),
                                        const SizedBox(height: 4),
                                        Text('Дата: ${item.createdAt ?? "-"}'),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}