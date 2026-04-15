import 'package:flutter/material.dart';

import '../../data/staff_spend_api.dart';

class StaffSpendScreen extends StatefulWidget {
  final String clientId;
  final String clientName;
  final int establishmentId;
  final int currentBalance;

  const StaffSpendScreen({
    super.key,
    required this.clientId,
    required this.clientName,
    required this.establishmentId,
    required this.currentBalance,
  });

  @override
  State<StaffSpendScreen> createState() => _StaffSpendScreenState();
}

class _StaffSpendScreenState extends State<StaffSpendScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  final StaffSpendApi _spendApi = StaffSpendApi();

  bool _loading = false;
  String? _error;
  String? _success;
  double? _newBalance;

  @override
  void dispose() {
    _amountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final rawAmount = _amountController.text.trim().replaceAll(',', '.');

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    if (rawAmount.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Введите количество баллов';
      });
      return;
    }

    final amount = double.tryParse(rawAmount);
    if (amount == null || amount <= 0) {
      setState(() {
        _loading = false;
        _error = 'Введите корректное количество баллов';
      });
      return;
    }

    try {
      final result = await _spendApi.spendPoints(
        clientId: widget.clientId,
        establishmentId: widget.establishmentId,
        amount: amount,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
        _newBalance = result.newBalance;
        _success = 'Баллы успешно списаны';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Ошибка списания баллов';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final balanceText = _newBalance == null
        ? '${widget.currentBalance}'
        : _newBalance!.toStringAsFixed(_newBalance! % 1 == 0 ? 0 : 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Списать баллы'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.clientName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('ID клиента: ${widget.clientId}'),
            const SizedBox(height: 4),
            Text('Текущий баланс: $balanceText'),
            const SizedBox(height: 24),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Сколько баллов списать',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Комментарий',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: const Icon(Icons.remove_circle_outline),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Списать'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            if (_success != null)
              Text(
                _success!,
                style: const TextStyle(color: Colors.green, fontSize: 16),
              ),
          ],
        ),
      ),
    );
  }
}