import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/staff_client_qr_api.dart';

const _ink = Color(0xFF17283F);
const _mint = Color(0xFFBCF3E4);
const _muted = Color(0xFF75849A);
String _expiry(dynamic raw) {
  final date = DateTime.tryParse('$raw')?.toLocal();
  if (date == null) return 'Уточните в заведении';
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class StaffRafflePrizeScreen extends StatefulWidget {
  final int establishmentId;
  final String qr;
  const StaffRafflePrizeScreen({super.key, required this.establishmentId, required this.qr});
  @override State<StaffRafflePrizeScreen> createState() => _StaffRafflePrizeScreenState();
}
class _StaffRafflePrizeScreenState extends State<StaffRafflePrizeScreen> {
  Map<String, dynamic>? _prize;
  String? _error;
  bool _busy = false;
  @override void initState() { super.initState(); _load(false); }
  Future<void> _load(bool redeem) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final result = await StaffClientQrApi().rafflePrize(establishmentId: widget.establishmentId, qr: widget.qr, redeem: redeem);
      if (mounted) setState(() => _prize = redeem ? {...?_prize, ...result} : result);
      if (redeem) HapticFeedback.mediumImpact();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _confirm() async {
    final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (sheet) => SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Material(color: Colors.white, borderRadius: BorderRadius.circular(30), child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Icon(Icons.card_giftcard_rounded, color: Color(0xFF8A70AE), size: 36), const SizedBox(height: 18),
      const Text('Передаёте приз?', textAlign: TextAlign.center, style: TextStyle(color: _ink, fontSize: 27, letterSpacing: -.6, fontWeight: FontWeight.w900)), const SizedBox(height: 12),
      Text('${_prize?['prize_text'] ?? ''}', textAlign: TextAlign.center, style: const TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w700)), const SizedBox(height: 6),
      Text('${_prize?['winner_name'] ?? ''}', textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 14)), const SizedBox(height: 16),
      const Text('Подтвердите после передачи. Повторная выдача будет недоступна.', textAlign: TextAlign.center, style: TextStyle(color: _muted, height: 1.5, fontSize: 12)), const SizedBox(height: 22),
      _PrizeButton(label: 'Подтвердить выдачу', icon: Icons.check_rounded, onTap: () => Navigator.pop(sheet, true)),
      TextButton(onPressed: () => Navigator.pop(sheet, false), child: const Text('Вернуться', style: TextStyle(color: _muted))),
    ]))))));
    if (ok == true && mounted) await _load(true);
  }
  @override Widget build(BuildContext context) {
    final state = '${_prize?['state'] ?? ''}';
    final received = state == 'redeemed';
    final available = state == 'available';
    return Scaffold(backgroundColor: const Color(0xFFF3F7FA), body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(10, 5, 20, 0), child: Row(children: [IconButton(tooltip: 'Назад', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded, color: _ink)), const Expanded(child: Text('Выдача приза', style: TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 16))), const Icon(Icons.verified_user_outlined, color: Color(0xFF649F90), size: 20)])),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(clipBehavior: Clip.antiAlias, decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF243B53), Color(0xFF272C49), Color(0xFF365359)])), child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(24, 24, 24, 0), child: Column(children: [Text('${_prize?['establishment_name'] ?? 'Проверяем приз'}', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFB3C3D1), fontSize: 12, fontWeight: FontWeight.w700)), const SizedBox(height: 13), Text(received ? 'Подарок\nпередан' : 'Момент\nрадости', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 38, height: 1.03, letterSpacing: -1.1, fontWeight: FontWeight.w900))])),
          SizedBox(height: 204, child: Image.asset('assets/flowru_raffle/prize_orbit.png', fit: BoxFit.contain, excludeFromSemantics: true, errorBuilder: (_, __, ___) => const Icon(Icons.auto_awesome_rounded, color: _mint, size: 90))),
          if (_prize != null) Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 22), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), decoration: BoxDecoration(color: Colors.white.withOpacity(.1), border: Border.all(color: Colors.white.withOpacity(.15)), borderRadius: BorderRadius.circular(30)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(received ? Icons.verified_rounded : available ? Icons.check_circle_outline_rounded : Icons.schedule_rounded, color: _mint, size: 16), const SizedBox(width: 7), Flexible(child: Text(received ? 'Приз уже выдан' : available ? 'Можно выдать' : 'Срок получения истёк', style: const TextStyle(color: _mint, fontSize: 12, fontWeight: FontWeight.w800)))]))),
        ])),
        if (_prize != null) ...[
          const SizedBox(height: 16), Container(padding: const EdgeInsets.all(23), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: const Color(0xFFE2EAF0))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('ПЕРЕДАТЬ ПОБЕДИТЕЛЮ', style: TextStyle(color: _muted, fontSize: 9, letterSpacing: 1.4, fontWeight: FontWeight.w900)), const SizedBox(height: 10), Text('${_prize!['prize_text'] ?? ''}', style: const TextStyle(color: _ink, fontSize: 28, height: 1.12, letterSpacing: -.5, fontWeight: FontWeight.w900)), const SizedBox(height: 21), Container(height: 1, color: const Color(0xFFEDF0F5)), const SizedBox(height: 18), Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFF0EBFA), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.person_outline_rounded, color: Color(0xFF8A70AE))), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Победитель', style: TextStyle(color: _muted, fontSize: 11)), const SizedBox(height: 4), Text('${_prize!['winner_name'] ?? ''}', style: const TextStyle(color: _ink, fontSize: 19, fontWeight: FontWeight.w800))]))])])),
          if ('${_prize!['expires_at'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(4, 17, 4, 0), child: Row(children: [const Icon(Icons.schedule_rounded, size: 16, color: _muted), const SizedBox(width: 8), Expanded(child: Text('Получить до ${_expiry(_prize!['expires_at'])}', style: const TextStyle(color: _muted, fontSize: 12)))])),
        ],
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 16), child: Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: const Color(0xFFFFEDEE), borderRadius: BorderRadius.circular(20)), child: Text(_error!, style: const TextStyle(color: Color(0xFF9E4D5E), fontSize: 13, height: 1.5)))),
      ]))),
      Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 20), child: _busy ? const SizedBox(height: 56, child: Center(child: CircularProgressIndicator(color: Color(0xFF659F92)))) : available && _error == null ? _PrizeButton(label: 'Выдать приз', icon: Icons.card_giftcard_rounded, onTap: _confirm) : _error != null ? _PrizeButton(label: 'Проверить снова', icon: Icons.refresh_rounded, onTap: () => _load(false)) : _PrizeButton(label: received ? 'Готово' : 'Вернуться', icon: received ? Icons.check_rounded : Icons.arrow_back_rounded, onTap: () => Navigator.pop(context))),
    ])));
  }
}
class _PrizeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PrizeButton({required this.label, required this.icon, required this.onTap});
  @override Widget build(BuildContext context) => Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [_mint, Color(0xFFC5E5EF), Color(0xFFD9C7FA)]), borderRadius: BorderRadius.circular(22)), child: Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(22), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: _ink, size: 21), const SizedBox(width: 10), Flexible(child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w900)))])))));
}
