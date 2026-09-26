import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../data/staff_client_qr_api.dart';
import '../../data/staff_rkeeper_api.dart';

class StaffRkeeperOrderScreen extends StatefulWidget {
  final int establishmentId;
  final StaffResolvedQrClient client;

  const StaffRkeeperOrderScreen({
    super.key,
    required this.establishmentId,
    required this.client,
  });

  @override
  State<StaffRkeeperOrderScreen> createState() =>
      _StaffRkeeperOrderScreenState();
}

class _StaffRkeeperOrderScreenState extends State<StaffRkeeperOrderScreen> {
  final StaffRkeeperApi _api = StaffRkeeperApi();
  List<StaffRkeeperOrder> _orders = const [];
  bool _loading = true;
  String? _error;
  String? _applyingGuid;

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
      final orders = await _api.getOpenOrders(widget.establishmentId);
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _apply(StaffRkeeperOrder order) async {
    if (_applyingGuid != null) return;
    final accepted = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Назначить карту клиенту?'),
        content: Text('${widget.client.clientName}\n${order.name}'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Назначить'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;

    setState(() => _applyingGuid = order.guid);
    try {
      final commandId = await _api.applyCard(
        establishmentId: widget.establishmentId,
        clientId: int.parse(widget.client.clientId),
        authorizationToken: widget.client.rkeeperAuthorizationToken,
        orderGuid: order.guid,
      );
      Map<String, dynamic>? status;
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        status = await _api.commandStatus(
          establishmentId: widget.establishmentId,
          commandId: commandId,
        );
        if (status['status'] == 'applied' || status['status'] == 'failed')
          break;
      }
      if (!mounted) return;
      if (status?['status'] != 'applied') {
        throw Exception(
          status?['error_text'] ?? 'r_keeper не подтвердил операцию',
        );
      }
      await showCupertinoDialog<void>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Готово'),
          content: Text(
            'Карта ${widget.client.clientId} назначена заказу ${order.name}.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Не удалось назначить карту'),
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Понятно'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _applyingGuid = null);
    }
  }

  String _money(int kopeks) => '${(kopeks / 100).toStringAsFixed(2)} ₽';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Выберите заказ')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(CupertinoIcons.person)),
                title: Text(widget.client.clientName),
                subtitle: Text(
                  'Карта № ${widget.client.clientId} · ${widget.client.points} баллов',
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CupertinoActivityIndicator(radius: 16)),
              )
            else if (_error != null)
              Center(child: Text(_error!, textAlign: TextAlign.center))
            else if (_orders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(36),
                child: Text(
                  'Открытых заказов сейчас нет',
                  textAlign: TextAlign.center,
                ),
              )
            else
              ..._orders.map(
                (order) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(CupertinoIcons.table),
                    ),
                    title: Text(order.name),
                    subtitle: Text(
                      'Стол ${order.tableCode.isEmpty ? '—' : order.tableCode}\n'
                      'К оплате: ${_money(order.toPaySum)}',
                    ),
                    isThreeLine: true,
                    trailing: _applyingGuid == order.guid
                        ? const CupertinoActivityIndicator()
                        : const Icon(CupertinoIcons.chevron_right),
                    onTap: () => _apply(order),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
