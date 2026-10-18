import 'package:flutter/foundation.dart';
import '../../../../flowru_future_ui.dart';
import 'dart:async';
import '../../../auth/data/auth_storage.dart';
import '../../../auth/presentation/screens/login_phone_screen.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/delivery_work_api.dart';

const _ink = Color(0xFF0A2B47),
    _mint = Color(0xFF0BAEBB),
    _soft = Color(0xFF557186);

class DeliveryWorkScreen extends StatefulWidget {
  final bool courierLogin;
  final int? establishmentId;
  final String establishmentName;
  const DeliveryWorkScreen({
    super.key,
    this.courierLogin = false,
    this.establishmentId,
    this.establishmentName = '',
  });
  @override
  State<DeliveryWorkScreen> createState() => _DeliveryWorkScreenState();
}

class _DeliveryWorkScreenState extends State<DeliveryWorkScreen>
    with WidgetsBindingObserver {
  final _api = DeliveryWorkApi();
  List<Map<String, dynamic>> _items = [], _couriers = [];
  bool _loading = true, _fetching = false, _busy = false, _history = false;
  int _connected = 0;
  String? _error;
  Timer? _timer;
  bool get _courier => widget.establishmentId == null;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_busy) _load(silent: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      _load(silent: true);
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_fetching) return;
    _fetching = true;
    try {
      final data = await _api.request(
        _courier
            ? '/courier/deliveries'
            : '/staff/deliveries?establishment_id=${widget.establishmentId}',
      );
      if (!mounted) return;
      setState(() {
        _items = (data['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _couriers = (data['couriers'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _connected = (data['connected'] as num? ?? 0).toInt();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
    } finally {
      _fetching = false;
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load(silent: true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _money(dynamic v) =>
      '${((v as num? ?? 0) / 100).toStringAsFixed(2).replaceAll('.00', '')} ₽';
  String _time(dynamic v) {
    final d = DateTime.tryParse('$v')?.toLocal();
    return d == null
        ? ''
        : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _itemText(Map i) {
    final mods = (i['modifiers'] as List? ?? [])
        .whereType<Map>()
        .map((m) => '${m['name'] ?? ''}')
        .where((n) => n.isNotEmpty);
    return '${i['quantity'] ?? 1} × ${i['title'] ?? i['name'] ?? 'Позиция'}${i['variant_name'] == null ? '' : ' · ${i['variant_name']}'}${mods.isEmpty ? '' : ' · ${mods.join(', ')}'}';
  }

  bool _done(Map r) =>
      ['completed', 'cancelled', 'expired'].contains(r['preorder_status']) ||
      ['refunded', 'canceled'].contains(r['state']);
  Future<void> _claim() async {
    final input = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подключиться как курьер'),
        content: TextField(
          controller: input,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'Код от владельца',
            helperText: 'Получите код в заведении',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Назад'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, input.text.trim()),
            child: const Text('Подключить'),
          ),
        ],
      ),
    );
    input.dispose();
    if (code == null || code.isEmpty) return;
    await _run(() async {
      await _api.request('/courier/deliveries/claim', data: {'code': code});
    });
  }

  Future<void> _assign(Map r) async {
    final available = _couriers.where((c) => c['connected'] == true).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Владелец должен подключить курьера в админке'),
        ),
      );
      return;
    }
    final id = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.65,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'Кому передать заказ',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              ...available.map(
                (c) => ListTile(
                  leading: const Icon(Icons.delivery_dining_rounded),
                  title: Text('${c['name']}'),
                  onTap: () => Navigator.pop(ctx, (c['id'] as num).toInt()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (id != null)
      await _run(() async {
        await _api.request(
          '/staff/deliveries/${r['id']}/assign',
          data: {'courier_id': id},
        );
      });
  }

  Future<void> _status(Map r, String status) async {
    int? minutes;
    String? comment;
    if (status == 'in_work') {
      final input = TextEditingController();
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Когда будет готово?'),
          content: TextField(
            controller: input,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Минут на приготовление',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Назад'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, input.text.trim()),
              child: const Text('Принять'),
            ),
          ],
        ),
      );
      input.dispose();
      if (result == null) return;
      minutes = int.tryParse(result);
      if (minutes == null || minutes < 1 || minutes > 180) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Укажите от 1 до 180 минут')),
          );
        return;
      }
    }
    if (status == 'cancelled') {
      final input = TextEditingController();
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Отменить доставку?'),
          content: TextField(
            controller: input,
            maxLength: 300,
            decoration: const InputDecoration(
              labelText: 'Причина отмены',
              helperText: 'После отмены запросим возврат оплаты',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Назад'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, input.text.trim()),
              child: const Text('Отменить заказ'),
            ),
          ],
        ),
      );
      input.dispose();
      if (result == null) return;
      if (result.isEmpty) return;
      comment = result;
    }
    await _run(() async {
      await _api.request(
        '/staff/preorders/${r['preorder_id']}/status',
        data: {
          'status': status,
          if (minutes != null) 'prepare_minutes': minutes,
          if (comment != null) 'staff_comment': comment,
        },
      );
    });
  }

  Future<void> _step(Map r, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          action == 'pickup' ? 'Заказ у вас?' : 'Заказ передан клиенту?',
        ),
        content: Text(
          action == 'pickup'
              ? 'Подтвердите получение заказа в заведении.'
              : 'После подтверждения доставка будет завершена.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Назад'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );
    if (ok == true)
      await _run(() async {
        await _api.request(
          '/courier/deliveries/${r['id']}/step',
          data: {'action': action},
        );
      });
  }

  Widget _button(String text, VoidCallback tap, {bool secondary = false}) =>
      secondary
      ? TextButton(onPressed: _busy ? null : tap, child: Text(text))
      : FilledButton(
          onPressed: _busy ? null : tap,
          style: FilledButton.styleFrom(backgroundColor: _mint),
          child: Text(text),
        );
  Future<void> _route(Map place) async {
    final address = (place['address'] ?? '').toString();
    final lat = num.tryParse('${place['latitude']}'),
        lon = num.tryParse('${place['longitude']}');
    if ((lat == null || lon == null) && address.isEmpty) return;
    if (!kIsWeb && lat != null && lon != null) {
      final native = Uri.parse(
        'dgis://2gis.ru/routeSearch/rsType/pedestrian/to/$lon,$lat',
      );
      if (await canLaunchUrl(native) &&
          await launchUrl(native, mode: LaunchMode.externalApplication))
        return;
    }
    final query = lat != null && lon != null ? '$lat,$lon' : address;
    await launchUrl(
      Uri.https('2gis.ru', '/search/$query'),
      mode: LaunchMode.externalApplication,
    );
  }

  Widget _order(Map<String, dynamic> r) {
    final done = _done(r),
        phase = '${r['delivery_phase']}',
        status = '${r['preorder_status']}';
    final cancelled =
        status == 'cancelled' ||
        ['refunded', 'canceled'].contains(r['state']) ||
        r['desired_action'] == 'cancel';
    final pickup = r['pickup_location'] is Map
        ? Map<String, dynamic>.from(r['pickup_location'] as Map)
        : <String, dynamic>{};
    final address = r['delivery_address'] is Map
        ? Map<String, dynamic>.from(r['delivery_address'] as Map)
        : <String, dynamic>{};
    final onWay = phase == 'on_way';
    final place = onWay ? address : pickup;
    final ready = DateTime.tryParse(
      '${onWay ? r['estimated_delivery_to'] : r['estimated_ready_at']}',
    );
    final minutes = ready == null
        ? null
        : (ready.difference(DateTime.now()).inSeconds / 60).ceil();
    final headline = cancelled
        ? 'Отменён'
        : done
        ? 'Доставлен'
        : status == 'ready' && !onWay
        ? 'Можно забирать'
        : minutes == null
        ? 'Уточняем время'
        : minutes > 0
        ? 'Через $minutes мин'
        : onWay
        ? 'Доставьте заказ'
        : 'Подойдите к заведению';
    final next = onWay
        ? 'Доставить заказ №${r['preorder_id']}'
        : 'Забрать заказ №${r['preorder_id']}';
    final items = (r['items'] as List? ?? []).whereType<Map>().toList();
    final routeReady =
        (place['address'] ?? '').toString().isNotEmpty ||
        (place['latitude'] != null && place['longitude'] != null);
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureHero(
            imageAsset: 'assets/flowru_future/courier.png',
            title: headline,
            subtitle: next,
            height: 185,
          ),
          const SizedBox(height: 12),
          FutureGlass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      onWay ? Icons.home_outlined : Icons.local_cafe_outlined,
                      color: futureAqua,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            onWay
                                ? '${r['client_name'] ?? 'Клиент'}'
                                : '${pickup['name'] ?? 'Заведение'}',
                            style: const TextStyle(
                              color: futureInk,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            (place['address'] ?? '').toString().isEmpty
                                ? 'Адрес заведения не указан'
                                : '${place['address']}',
                            style: const TextStyle(
                              color: futureSoft,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FutureAction(
                  label: onWay ? 'Маршрут к клиенту' : 'Маршрут до заведения',
                  onTap: routeReady ? () => _route(place) : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FutureGlass(
            child: Row(
              children: [
                for (final label in ['Готовится', 'Можно забрать', 'В пути'])
                  Expanded(
                    child: Column(
                      children: [
                        Icon(
                          label == 'Готовится'
                              ? Icons.local_cafe_outlined
                              : label == 'Можно забрать'
                              ? Icons.shopping_bag_outlined
                              : Icons.delivery_dining_rounded,
                          color:
                              (onWay
                                  ? label == 'В пути'
                                  : status == 'ready'
                                  ? label == 'Можно забрать'
                                  : label == 'Готовится')
                              ? futureAqua
                              : futureSoft,
                          size: 23,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color:
                                (onWay
                                    ? label == 'В пути'
                                    : status == 'ready'
                                    ? label == 'Можно забрать'
                                    : label == 'Готовится')
                                ? futureInk
                                : futureSoft,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FutureGlass(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              leading: const Icon(
                Icons.person_outline_rounded,
                color: futureInk,
              ),
              title: Text(
                onWay ? 'Адрес и связь' : 'Кому доставить',
                style: const TextStyle(
                  color: futureInk,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                '${r['client_name'] ?? 'Клиент'} · ${address['address'] ?? 'Адрес уточняется'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: futureSoft, fontSize: 12),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              children: [
                Text(
                  'Квартира ${r['apartment'] ?? '—'} · подъезд ${r['entrance'] ?? '—'} · этаж ${r['floor'] ?? '—'}',
                  style: const TextStyle(color: futureInk, fontSize: 13),
                ),
                if ('${r['delivery_note'] ?? ''}'.isNotEmpty)
                  Text(
                    '${r['delivery_note']}',
                    style: const TextStyle(color: futureSoft, fontSize: 13),
                  ),
                if ('${r['client_phone'] ?? ''}'.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri(scheme: 'tel', path: '${r['client_phone']}'),
                    ),
                    icon: const Icon(Icons.phone_outlined),
                    label: const Text('Связаться с клиентом'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FutureGlass(
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, color: futureSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Доставка  ${_time(r['estimated_delivery_from'])}–${_time(r['estimated_delivery_to'])}',
                    style: const TextStyle(
                      color: futureInk,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FutureGlass(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              leading: const Icon(
                Icons.shopping_bag_outlined,
                color: futureInk,
              ),
              title: Text(
                'Состав · ${items.length} поз.',
                style: const TextStyle(
                  color: futureInk,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                '${r['amount'] ?? '—'} ₽ · ${r['courier_name'] ?? ''}',
                style: const TextStyle(color: futureSoft, fontSize: 12),
              ),
              childrenPadding: const EdgeInsets.all(16),
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${item['quantity']} × ${item['name'] ?? ''}${item['variant_name'] == null ? '' : ' · ${item['variant_name']}'}',
                        style: const TextStyle(color: futureInk, fontSize: 13),
                      ),
                    ),
                  ),
                if ('${r['order_text'] ?? ''}'.isNotEmpty)
                  Text(
                    '${r['order_text']}',
                    style: const TextStyle(color: futureSoft, fontSize: 12),
                  ),
              ],
            ),
          ),
          if (!done && !cancelled) ...[
            const SizedBox(height: 14),
            if (_courier)
              FutureAction(
                label: onWay
                    ? 'Передал клиенту'
                    : status == 'ready'
                    ? 'Забрал заказ'
                    : 'Ждём готовности',
                onTap: _busy
                    ? null
                    : onWay
                    ? () => _step(r, 'delivered')
                    : phase == 'assigned' && status == 'ready'
                    ? () => _step(r, 'pickup')
                    : null,
              )
            else
              Wrap(
                spacing: 8,
                children: [
                  _button(
                    'Назначить курьера',
                    () => _assign(r),
                    secondary: true,
                  ),
                  if (status == 'in_work')
                    _button('Заказ готов', () => _status(r, 'ready')),
                ],
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _items.where((r) => _done(r) == _history).toList();
    if (!_history)
      visible.sort((a, b) {
        int rank(Map r) => r['delivery_phase'] == 'on_way'
            ? 0
            : r['preorder_status'] == 'ready'
            ? 1
            : 2;
        final result = rank(a).compareTo(rank(b));
        if (result != 0) return result;
        return '${a['estimated_delivery_to'] ?? a['created_at']}'.compareTo(
          '${b['estimated_delivery_to'] ?? b['created_at']}',
        );
      });
    return Scaffold(
      backgroundColor: const Color(0xFFF2FAFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2FAFF),
        foregroundColor: _ink,
        title: Text(
          _courier ? 'Сейчас' : 'Доставка',
          style: const TextStyle(fontWeight: FontWeight.w900, color: futureInk),
        ),
        actions: [
          if (_courier && !widget.courierLogin)
            IconButton(
              onPressed: _busy ? null : _claim,
              tooltip: 'Код подключения',
              icon: const Icon(Icons.add_link_rounded),
            ),
          IconButton(
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (widget.courierLogin)
            IconButton(
              tooltip: 'Выйти',
              onPressed: () async {
                await AuthStorage.clearSessionButKeepBiometric();
                if (mounted)
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginPhoneScreen()),
                    (_) => false,
                  );
              },
              icon: const Icon(Icons.logout_rounded),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              if (widget.establishmentName.isNotEmpty)
                Text(
                  widget.establishmentName,
                  style: const TextStyle(color: _soft),
                ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => setState(() => _history = false),
                        child: Text(
                          'Активные · ${_items.where((r) => !_done(r)).length}',
                          style: TextStyle(
                            fontWeight: !_history
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: _ink,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: () => setState(() => _history = true),
                        child: Text(
                          'История',
                          style: TextStyle(
                            fontWeight: _history
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: _ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_busy) const LinearProgressIndicator(color: _mint),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: _mint),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _load(),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            if (_courier &&
                                !widget.courierLogin &&
                                _connected == 0)
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.delivery_dining_rounded,
                                      size: 64,
                                      color: _mint,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Подключитесь к заведению',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: _ink,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Владелец выдаст код. После подключения здесь появятся назначенные вам доставки.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: _soft),
                                    ),
                                    const SizedBox(height: 16),
                                    _button('Ввести код', _claim),
                                  ],
                                ),
                              ),
                            if (visible.isEmpty &&
                                (!_courier || _connected > 0))
                              const Padding(
                                padding: EdgeInsets.all(28),
                                child: Text(
                                  'Здесь пока нет заказов',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: _soft),
                                ),
                              ),
                            ...visible.map(_order),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
