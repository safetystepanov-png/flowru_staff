
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../data/staff_points_api.dart';
import 'staff_design_system.dart';

class StaffAccrualScreen extends StatefulWidget {
  final String clientId;
  final String clientName;
  final int establishmentId;
  final int currentBalance;

  const StaffAccrualScreen({
    super.key,
    required this.clientId,
    required this.clientName,
    required this.establishmentId,
    required this.currentBalance,
  });

  @override
  State<StaffAccrualScreen> createState() => _StaffAccrualScreenState();
}

class _StaffAccrualScreenState extends State<StaffAccrualScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final StaffPointsApi _pointsApi = StaffPointsApi();

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
      final result = await _pointsApi.accruePoints(
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
        _success = 'Баллы успешно начислены';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Ошибка начисления баллов';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final balanceText = _newBalance == null
        ? '${widget.currentBalance}'
        : _newBalance!.toStringAsFixed(_newBalance! % 1 == 0 ? 0 : 2);

    return StaffUnifiedScaffold(
      title: 'Начисление',
      useList: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StaffGlassCard(
            child: Row(
              children: [
                const StaffFloatingGlyph(
                  icon: CupertinoIcons.plus,
                  mainColor: kHomeBlue,
                  secondaryColor: kHomeMintTop,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.clientName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kHomeInk)),
                      const SizedBox(height: 4),
                      Text('ID клиента: ${widget.clientId}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: kHomeInkSoft)),
                      const SizedBox(height: 8),
                      StaffInfoChip(label: 'Текущий баланс', value: balanceText, color: kHomeBlue),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          StaffGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StaffSectionHeader(title: 'Данные', subtitle: 'Сколько баллов нужно начислить'),
                const SizedBox(height: 14),
                StaffTextFieldCard(
                  controller: _amountController,
                  hint: 'Количество баллов',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  prefix: const Icon(CupertinoIcons.star_fill, color: kHomeInkSoft),
                ),
                const SizedBox(height: 12),
                StaffTextFieldCard(
                  controller: _commentController,
                  hint: 'Комментарий',
                  maxLines: 3,
                  prefix: const Icon(CupertinoIcons.text_alignleft, color: kHomeInkSoft),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            StaffStateCard(icon: CupertinoIcons.exclamationmark_circle_fill, title: 'Ошибка', subtitle: _error!, glow: kHomeAccentRed),
          ],
          if (_success != null) ...[
            const SizedBox(height: 12),
            StaffGlassCard(
              glow: kHomeMintTop,
              child: Text(_success!, style: const TextStyle(color: kHomeInk, fontWeight: FontWeight.w900)),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: StaffPillButton(
              text: 'Начислить',
              icon: CupertinoIcons.add_circled_solid,
              onTap: _submit,
              loading: _loading,
              colors: const [kHomeBlue, kHomeViolet],
            ),
          ),
        ],
      ),
    );
  }
}
