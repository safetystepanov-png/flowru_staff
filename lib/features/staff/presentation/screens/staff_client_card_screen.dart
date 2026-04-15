import 'package:flutter/material.dart';

import '../../data/staff_client_detail_api.dart';
import 'staff_accrual_screen.dart';
import 'staff_client_history_screen.dart';
import 'staff_rewards_screen.dart';
import 'staff_spend_screen.dart';

class StaffClientCardScreen extends StatefulWidget {
  final String clientId;
  final int establishmentId;

  const StaffClientCardScreen({
    super.key,
    required this.clientId,
    required this.establishmentId,
  });

  @override
  State<StaffClientCardScreen> createState() => _StaffClientCardScreenState();
}

class _StaffClientCardScreenState extends State<StaffClientCardScreen> {
  final StaffClientDetailApi _detailApi = StaffClientDetailApi();

  bool _loading = true;
  String? _error;
  StaffClientDetailItem? _client;

  @override
  void initState() {
    super.initState();
    _loadClient();
  }

  Future<void> _loadClient() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = await _detailApi.getClientDetail(
        clientId: widget.clientId,
        establishmentId: widget.establishmentId,
      );

      if (!mounted) return;

      setState(() {
        _client = client;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Ошибка загрузки карточки клиента';
      });
    }
  }

  Widget _infoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            title,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  Future<void> _openAccrual() async {
    if (_client == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StaffAccrualScreen(
          clientId: _client!.clientId,
          clientName: _client!.fullName ?? 'Без имени',
          establishmentId: widget.establishmentId,
          currentBalance: _client!.balance,
        ),
      ),
    );

    await _loadClient();
  }

  Future<void> _openSpend() async {
    if (_client == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StaffSpendScreen(
          clientId: _client!.clientId,
          clientName: _client!.fullName ?? 'Без имени',
          establishmentId: widget.establishmentId,
          currentBalance: _client!.balance,
        ),
      ),
    );

    await _loadClient();
  }

  Future<void> _openHistory() async {
    if (_client == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StaffClientHistoryScreen(
          clientId: _client!.clientId,
          clientName: _client!.fullName ?? 'Без имени',
          establishmentId: widget.establishmentId,
        ),
      ),
    );

    await _loadClient();
  }

  Future<void> _openRewards() async {
    if (_client == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StaffRewardsScreen(
          clientId: _client!.clientId,
          clientName: _client!.fullName ?? 'Без имени',
          establishmentId: widget.establishmentId,
        ),
      ),
    );

    await _loadClient();
  }

  Widget _buildTopCard() {
    final qrText = (_client!.qrCode == null || _client!.qrCode!.isEmpty)
        ? '-'
        : _client!.qrCode!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            color: Color(0x12000000),
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _client!.fullName ?? 'Без имени',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text('ID клиента: ${_client!.clientId}'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _infoChip(
                  'Баланс',
                  '${_client!.balance}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _infoChip(
                  'Уровень',
                  _client!.levelName ?? 'Без уровня',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _infoChip('Телефон', _client!.phone ?? 'не указан'),
          const SizedBox(height: 10),
          _infoChip('QR', qrText),
        ],
      ),
    );
  }

  Widget _buildActionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Действия с клиентом',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        _buildActionButton(
          title: 'Начислить баллы',
          icon: Icons.add_circle_outline,
          onTap: _openAccrual,
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          title: 'Списать баллы',
          icon: Icons.remove_circle_outline,
          onTap: _openSpend,
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          title: 'Подарки / погашение',
          icon: Icons.card_giftcard,
          onTap: _openRewards,
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          title: 'История клиента',
          icon: Icons.history,
          onTap: _openHistory,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Карточка клиента'),
        actions: [
          IconButton(
            onPressed: _loadClient,
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
                : _client == null
                    ? const Center(child: Text('Клиент не найден'))
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildTopCard(),
                            const SizedBox(height: 20),
                            _buildActionSection(),
                          ],
                        ),
                      ),
      ),
    );
  }
}