import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/staff_client_qr_api.dart';
import '../../data/staff_subscription_sales_api.dart';
import 'staff_qr_scanner_screen.dart';

const Color _saleMintTop = Color(0xFF0FCAC5);
const Color _saleMintMid = Color(0xFF0BAEBB);
const Color _saleMintDeep = Color(0xFF075E70);
const Color _saleInk = Color(0xFF0A2B47);
const Color _saleSoft = Color(0xFF587487);
const Color _saleOrange = Color(0xFFFFA51E);
const Color _salePink = Color(0xFFFF4F91);
const Color _saleViolet = Color(0xFF7A4CFF);

class StaffSubscriptionSaleScreen extends StatefulWidget {
  final int establishmentId;
  final String establishmentName;

  const StaffSubscriptionSaleScreen({
    super.key,
    required this.establishmentId,
    required this.establishmentName,
  });

  @override
  State<StaffSubscriptionSaleScreen> createState() =>
      _StaffSubscriptionSaleScreenState();
}

class _StaffSubscriptionSaleScreenState
    extends State<StaffSubscriptionSaleScreen>
    with TickerProviderStateMixin {
  final StaffSubscriptionSalesApi _salesApi = StaffSubscriptionSalesApi();
  final StaffClientQrApi _qrApi = StaffClientQrApi();
  final TextEditingController _receiptController = TextEditingController();

  late final AnimationController _ambientController;
  late final AnimationController _successController;

  StaffSubscriptionSaleClient? _client;
  StaffSubscriptionSalePlan? _selectedPlan;
  StaffOfflineSubscriptionSaleResult? _result;

  List<StaffSubscriptionSalePlan> _plans = const [];

  bool _scanning = false;
  bool _loading = false;
  bool _activating = false;
  bool _paymentConfirmed = false;

  String _paymentMethod = 'external_terminal';
  String? _error;
  String? _idempotencyKey;

  @override
  void initState() {
    super.initState();

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7000),
    )..repeat();

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scanClient();
    });
  }

  @override
  void dispose() {
    _receiptController.dispose();
    _ambientController.dispose();
    _successController.dispose();
    super.dispose();
  }

  Future<void> _scanClient() async {
    if (_scanning || _activating) return;

    setState(() {
      _scanning = true;
      _error = null;
    });

    try {
      final qrToken = await Navigator.of(context).push<String>(
        PageRouteBuilder<String>(
          transitionDuration: const Duration(milliseconds: 420),
          reverseTransitionDuration: const Duration(milliseconds: 320),
          pageBuilder: (_, animation, secondaryAnimation) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: const StaffQrScannerScreen(),
            );
          },
        ),
      );

      if (!mounted) return;

      if (qrToken == null || qrToken.trim().isEmpty) {
        setState(() => _scanning = false);
        return;
      }

      setState(() {
        _loading = true;
        _scanning = false;
        _client = null;
        _plans = const [];
        _selectedPlan = null;
        _paymentConfirmed = false;
        _idempotencyKey = null;
      });

      final resolved = await _qrApi.resolveClientQr(
        establishmentId: widget.establishmentId,
        qrToken: qrToken.trim(),
      );

      final clientId = int.tryParse(resolved.coreClientId.trim());

      if (clientId == null || clientId <= 0) {
        throw const StaffSubscriptionSaleException(
          'Сервер вернул некорректный номер клиента.',
        );
      }

      final responses = await Future.wait<dynamic>([
        _salesApi.getClient(
          establishmentId: widget.establishmentId,
          clientId: clientId,
        ),
        _salesApi.getPlans(establishmentId: widget.establishmentId),
      ]);

      if (!mounted) return;

      final client = responses[0] as StaffSubscriptionSaleClient;
      final plans = responses[1] as List<StaffSubscriptionSalePlan>;

      setState(() {
        _client = client;
        _plans = plans;
        _selectedPlan = plans.isNotEmpty ? plans.first : null;
        _loading = false;
        _error = plans.isEmpty
            ? 'В заведении пока нет доступных тарифов для продажи.'
            : null;
      });

      HapticFeedback.mediumImpact();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _scanning = false;
        _loading = false;
        print('========== SALE SCREEN ERROR ==========');
        print(error);
        print('=======================================');
        _error = error.toString().replaceFirst('Exception: ', '').trim();
      });
    }
  }

  Future<void> _activate() async {
    final client = _client;
    final plan = _selectedPlan;

    if (client == null || plan == null || _activating) return;

    if (!_paymentConfirmed) {
      setState(() {
        _error = 'Подтвердите, что оплата уже принята на кассе.';
      });
      HapticFeedback.heavyImpact();
      return;
    }

    final hasSameActivePlan = client.activeSubscriptions.any(
      (subscription) => subscription.planId == plan.id,
    );

    if (hasSameActivePlan) {
      setState(() {
        _error =
            'У клиента уже есть активный абонемент этого тарифа. Повторная выдача заблокирована.';
      });
      HapticFeedback.heavyImpact();
      return;
    }

    final confirmed = await _showFinalConfirmation(client, plan);

    if (!confirmed || !mounted) return;

    final key =
        _idempotencyKey ??
        'staff-offline-${widget.establishmentId}-${client.id}-${plan.id}-${DateTime.now().microsecondsSinceEpoch}';

    _idempotencyKey = key;

    setState(() {
      _activating = true;
      _error = null;
    });

    try {
      final result = await _salesApi.activateOffline(
        establishmentId: widget.establishmentId,
        clientId: client.id,
        planId: plan.id,
        paymentMethod: _paymentMethod,
        receiptNumber: _receiptController.text,
        idempotencyKey: key,
      );

      if (!mounted) return;

      setState(() {
        _result = result;
        _activating = false;
      });

      _successController.forward(from: 0);
      HapticFeedback.heavyImpact();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _activating = false;
        print('========== SALE SCREEN ERROR ==========');
        print(error);
        print('=======================================');
        _error = error.toString().replaceFirst('Exception: ', '').trim();
      });

      HapticFeedback.heavyImpact();
    }
  }

  Future<bool> _showFinalConfirmation(
    StaffSubscriptionSaleClient client,
    StaffSubscriptionSalePlan plan,
  ) async {
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Закрыть',
      barrierColor: Colors.black.withOpacity(0.56),
      transitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: math.min(
                  MediaQuery.of(dialogContext).size.width - 28,
                  430,
                ),
                margin: const EdgeInsets.all(14),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(34),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.28),
                      blurRadius: 50,
                      offset: const Offset(0, 24),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(
                          colors: [_saleOrange, _salePink],
                        ),
                      ),
                      child: const Icon(
                        CupertinoIcons.checkmark_shield_fill,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Подтвердите продажу',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _saleInk,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '${client.name}\n${plan.name}  ${_money(plan.price)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _saleSoft,
                        fontSize: 15,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E1),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Text(
                        'Сотрудник подтверждает, что оплата уже получена через кассу заведения.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF8A5715),
                          fontSize: 13.5,
                          height: 1.4,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(54),
                              side: const BorderSide(color: Color(0xFFD8E2E7)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text(
                              'Отмена',
                              style: TextStyle(
                                color: _saleSoft,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: FilledButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(true),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(54),
                              backgroundColor: _saleViolet,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text(
                              'Активировать',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.86, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );

    return result == true;
  }

  void _reset() {
    setState(() {
      _client = null;
      _plans = const [];
      _selectedPlan = null;
      _result = null;
      _error = null;
      _paymentConfirmed = false;
      _paymentMethod = 'external_terminal';
      _receiptController.clear();
      _idempotencyKey = null;
    });

    _successController.reset();
    _scanClient();
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      return _buildSuccess();
    }

    return Scaffold(
      backgroundColor: _saleMintTop,
      body: Stack(
        children: [
          _background(),
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
                    child: _loading
                        ? _loader()
                        : _client == null
                        ? _emptyState()
                        : _saleForm(),
                  ),
                ),
              ],
            ),
          ),
          if (_activating)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.42),
                child: const Center(child: _ActivatingCard()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _background() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _ambientController,
        builder: (context, child) {
          final wave = math.sin(_ambientController.value * math.pi * 2);

          return DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_saleMintTop, _saleMintMid, _saleMintDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -80 + wave * 14,
                  right: -70,
                  child: _orb(230, Colors.white.withOpacity(0.13)),
                ),
                Positioned(
                  bottom: 80 - wave * 12,
                  left: -95,
                  child: _orb(260, _saleViolet.withOpacity(0.13)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _orb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 80, spreadRadius: 18)],
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Row(
        children: [
          _roundButton(
            CupertinoIcons.back,
            () => Navigator.of(context).pop(_result != null),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Продажа абонемента',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.45,
                  ),
                ),
                Text(
                  widget.establishmentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.76),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _roundButton(CupertinoIcons.qrcode_viewfinder, _scanClient),
        ],
      ),
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withOpacity(0.16),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: Colors.white, size: 23),
        ),
      ),
    );
  }

  Widget _loader() {
    return Container(
      margin: const EdgeInsets.only(top: 80),
      padding: const EdgeInsets.all(28),
      decoration: _whiteDecoration(),
      child: const Column(
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: _saleViolet,
            ),
          ),
          SizedBox(height: 18),
          Text(
            'Проверяем клиента и тарифы',
            style: TextStyle(
              color: _saleInk,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 38),
      padding: const EdgeInsets.all(24),
      decoration: _whiteDecoration(),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [_saleOrange, _salePink, _saleViolet],
              ),
            ),
            child: const Icon(
              CupertinoIcons.qrcode_viewfinder,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Отсканируйте QR клиента',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _saleInk,
              fontSize: 23,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            'Клиент открывает обычный QR на главном экране Flowru. Система сама найдёт его профиль.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _saleSoft,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_error != null) ...[const SizedBox(height: 18), _errorBox()],
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _scanClient,
              icon: const Icon(CupertinoIcons.qrcode_viewfinder),
              label: const Text('Открыть сканер'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(58),
                backgroundColor: _saleViolet,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _saleForm() {
    final client = _client!;

    return Column(
      children: [
        _clientCard(client),
        const SizedBox(height: 14),
        _planCard(),
        const SizedBox(height: 14),
        _paymentCard(),
        if (_error != null) ...[const SizedBox(height: 14), _errorBox()],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _activating ? null : _activate,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(62),
              backgroundColor: _saleViolet,
              disabledBackgroundColor: _saleViolet.withOpacity(0.44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.checkmark_shield_fill, size: 23),
                SizedBox(width: 10),
                Text(
                  'Активировать абонемент',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _clientCard(StaffSubscriptionSaleClient client) {
    final initial = client.name.trim().isEmpty
        ? 'К'
        : client.name.trim().characters.first.toUpperCase();

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: _whiteDecoration(),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(23),
              gradient: const LinearGradient(
                colors: [_saleMintTop, _saleMintDeep],
              ),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'КЛИЕНТ НАЙДЕН',
                  style: TextStyle(
                    color: _saleMintDeep,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  client.name,
                  style: const TextStyle(
                    color: _saleInk,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.35,
                  ),
                ),
                if (client.phone.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    _maskedPhone(client.phone),
                    style: const TextStyle(
                      color: _saleSoft,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: _scanClient,
            icon: const Icon(
              CupertinoIcons.arrow_2_circlepath,
              color: _saleViolet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _planCard() {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: _whiteDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Выберите абонемент',
            style: TextStyle(
              color: _saleInk,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 13),
          if (_plans.isEmpty)
            const Text(
              'Нет доступных тарифов',
              style: TextStyle(color: _saleSoft, fontWeight: FontWeight.w700),
            )
          else
            ..._plans.map(_planTile),
        ],
      ),
    );
  }

  Widget _planTile(StaffSubscriptionSalePlan plan) {
    final selected = _selectedPlan?.id == plan.id;
    final duplicate =
        _client?.activeSubscriptions.any((item) => item.planId == plan.id) ??
        false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected
            ? _saleViolet.withOpacity(0.10)
            : const Color(0xFFF4F8FA),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: duplicate
              ? null
              : () {
                  setState(() {
                    _selectedPlan = plan;
                    _error = null;
                    _idempotencyKey = null;
                  });
                  HapticFeedback.selectionClick();
                },
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected
                    ? _saleViolet.withOpacity(0.55)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: duplicate
                        ? const Color(0xFFFFE6E4)
                        : selected
                        ? _saleViolet
                        : Colors.white,
                  ),
                  child: Icon(
                    duplicate
                        ? CupertinoIcons.exclamationmark
                        : selected
                        ? CupertinoIcons.checkmark
                        : CupertinoIcons.ticket_fill,
                    color: duplicate
                        ? const Color(0xFFD84B42)
                        : selected
                        ? Colors.white
                        : _saleViolet,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: const TextStyle(
                          color: _saleInk,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        duplicate
                            ? 'Уже активен у клиента'
                            : '${plan.durationLabel}  ${plan.usageLabel}',
                        style: TextStyle(
                          color: duplicate
                              ? const Color(0xFFD84B42)
                              : _saleSoft,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _money(plan.price),
                  style: const TextStyle(
                    color: _saleInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _paymentCard() {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: _whiteDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Оплата на кассе',
            style: TextStyle(
              color: _saleInk,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _paymentChoice(
                value: 'external_terminal',
                label: 'Терминал',
                icon: CupertinoIcons.creditcard_fill,
              ),
              _paymentChoice(
                value: 'sbp',
                label: 'СБП',
                icon: CupertinoIcons.qrcode,
              ),
              _paymentChoice(
                value: 'cash',
                label: 'Наличные',
                icon: CupertinoIcons.money_rubl_circle_fill,
              ),
            ],
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _receiptController,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Номер чека  необязательно',
              prefixIcon: const Icon(CupertinoIcons.doc_text),
              filled: true,
              fillColor: const Color(0xFFF4F8FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(19),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 13),
          Material(
            color: _paymentConfirmed
                ? const Color(0xFFE7F9F0)
                : const Color(0xFFFFF3E1),
            borderRadius: BorderRadius.circular(21),
            child: InkWell(
              onTap: () {
                setState(() {
                  _paymentConfirmed = !_paymentConfirmed;
                  _error = null;
                });
                HapticFeedback.selectionClick();
              },
              borderRadius: BorderRadius.circular(21),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 27,
                      height: 27,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        color: _paymentConfirmed
                            ? const Color(0xFF18A868)
                            : Colors.white,
                        border: Border.all(
                          color: _paymentConfirmed
                              ? const Color(0xFF18A868)
                              : const Color(0xFFE4B66A),
                          width: 2,
                        ),
                      ),
                      child: _paymentConfirmed
                          ? const Icon(
                              CupertinoIcons.checkmark,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Подтверждаю, что оплата получена на кассе заведения',
                        style: TextStyle(
                          color: _saleInk,
                          fontSize: 13.5,
                          height: 1.4,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentChoice({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final selected = _paymentMethod == value;

    return ChoiceChip(
      selected: selected,
      onSelected: (_) {
        setState(() {
          _paymentMethod = value;
          _idempotencyKey = null;
        });
        HapticFeedback.selectionClick();
      },
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? Colors.white : _saleViolet,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        color: selected ? Colors.white : _saleInk,
        fontWeight: FontWeight.w900,
      ),
      selectedColor: _saleViolet,
      backgroundColor: const Color(0xFFF4F8FA),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _errorBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE9E7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: Color(0xFFD84B42),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error ?? '',
              style: const TextStyle(
                color: Color(0xFF9E342D),
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    final result = _result!;

    final pop = CurvedAnimation(
      parent: _successController,
      curve: const Interval(0, 0.68, curve: Curves.easeOutBack),
    );

    final fade = CurvedAnimation(
      parent: _successController,
      curve: const Interval(0.18, 1, curve: Curves.easeOutCubic),
    );

    return Scaffold(
      backgroundColor: _saleMintDeep,
      body: Stack(
        children: [
          _background(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(18),
                child: FadeTransition(
                  opacity: fade,
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 460),
                    padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
                    decoration: _whiteDecoration(radius: 38),
                    child: Column(
                      children: [
                        ScaleTransition(
                          scale: pop,
                          child: Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  _saleMintTop,
                                  _saleMintMid,
                                  _saleViolet,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _saleViolet.withOpacity(0.32),
                                  blurRadius: 42,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                            ),
                            child: const Icon(
                              CupertinoIcons.checkmark_alt,
                              color: Colors.white,
                              size: 57,
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),
                        const Text(
                          'Абонемент подключён',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _saleInk,
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          result.clientName,
                          style: const TextStyle(
                            color: _saleSoft,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(19),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            gradient: LinearGradient(
                              colors: [
                                _saleViolet.withOpacity(0.10),
                                _saleMintTop.withOpacity(0.12),
                              ],
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                result.planName,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _saleInk,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                _money(result.price),
                                style: const TextStyle(
                                  color: _saleViolet,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (result.endsAt != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Действует до ${_date(result.endsAt!)}',
                                  style: const TextStyle(
                                    color: _saleSoft,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 17),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.bell_fill,
                              color: _saleMintDeep,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Абонемент уже доступен в приложении клиента',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _saleSoft,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(58),
                              backgroundColor: _saleViolet,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                            child: const Text(
                              'Готово',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _reset,
                          child: const Text(
                            'Продать ещё один',
                            style: TextStyle(
                              color: _saleViolet,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _whiteDecoration({double radius = 30}) {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.96),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withOpacity(0.75)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF06303A).withOpacity(0.18),
          blurRadius: 34,
          offset: const Offset(0, 18),
        ),
      ],
    );
  }

  String _message(Object error) {
    if (error is StaffSubscriptionSaleException) {
      return error.message;
    }

    final raw = error.toString().replaceFirst('Exception: ', '').trim();

    return raw.isEmpty ? 'Не удалось выполнить операцию.' : raw;
  }
}

class _ActivatingCard extends StatelessWidget {
  const _ActivatingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(28),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 45,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: CircularProgressIndicator(
              strokeWidth: 3.2,
              color: _saleViolet,
            ),
          ),
          SizedBox(height: 17),
          Text(
            'Активируем абонемент',
            style: TextStyle(
              color: _saleInk,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

String _money(double value) {
  final rounded = value.round();
  final raw = rounded.toString();
  final buffer = StringBuffer();

  for (var index = 0; index < raw.length; index++) {
    final remaining = raw.length - index;

    buffer.write(raw[index]);

    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(' ');
    }
  }

  return '${buffer.toString()} ₽';
}

String _maskedPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');

  if (digits.length < 10) return phone;

  String normalized = digits;

  if (normalized.length == 10) {
    normalized = '7$normalized';
  }

  if (normalized.length != 11) {
    return phone;
  }

  if (normalized.startsWith('8')) {
    normalized = '7${normalized.substring(1)}';
  }

  return '+${normalized.substring(0, 1)} '
      '${normalized.substring(1, 4)} '
      '${normalized.substring(4, 7)}-'
      '${normalized.substring(7, 9)}-'
      '${normalized.substring(9, 11)}';
}

String _date(DateTime value) {
  const months = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];

  return '${value.day} ${months[value.month - 1]} ${value.year}';
}
