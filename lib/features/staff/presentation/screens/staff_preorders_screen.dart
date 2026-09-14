import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../auth/data/auth_storage.dart';
import '../../../auth/data/user_api.dart';
import '../../../../core/config/app_config.dart';
import 'staff_client_spend_screen.dart';

const Color _mint = Color(0xFF0BAEBB);
const Color _mintLight = Color(0xFF42E8DF);
const Color _deep = Color(0xFF064B64);
const Color _ink = Color(0xFF0A2B47);
const Color _soft = Color(0xFF557186);
const Color _bg = Color(0xFFEFF8F9);
const Color _stroke = Color(0xFFD8E9EE);
const Color _orange = Color(0xFFFFA51E);
const Color _blue = Color(0xFF246BFF);
const Color _green = Color(0xFF22C55E);
const Color _red = Color(0xFFFF6A5E);

class StaffPreordersScreen extends StatefulWidget {
  final int establishmentId;
  final String establishmentName;

  const StaffPreordersScreen({
    super.key,
    required this.establishmentId,
    required this.establishmentName,
  });

  @override
  State<StaffPreordersScreen> createState() => _StaffPreordersScreenState();
}

class _StaffPreordersScreenState extends State<StaffPreordersScreen>
    with SingleTickerProviderStateMixin {
  // FLOWRU_PREORDERS_CYRILLIC_FIX_V1_20260914
  // FLOWRU_PREORDERS_FLAT_V2_20260914
  // FLOWRU_STAFF_PREORDERS_V2_20260818
  bool _loading = true;
  bool _updating = false;
  String? _error;
  List<_PreorderItem> _items = [];

  // FLOWRU_STAFF_PREORDER_AVAILABILITY_UI_V1_20260908
  int _preorderSection = 0;
  bool _catalogLoading = false;
  bool _catalogLoaded = false;
  String? _catalogError;
  List<_StaffCatalogItem> _catalogItems = [];
  final Set<int> _catalogUpdatingIds = <int>{};

  // FLOWRU_PREORDERS_PREMIUM_V4_20260909
  String _catalogCategory = '__all__';
  String _catalogQuery = '';

  // FLOWRU_AVAILABILITY_PREMIUM_V2_20260909

  late final AnimationController _motion;
  Timer? _urgencyTicker;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _urgencyTicker = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) {
        setState(() {});
      }
    });

    _load();
  }

  @override
  void dispose() {
    _urgencyTicker?.cancel();
    _motion.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Сессия истекла. Войдите заново.');
    }
    return token.trim();
  }

  // FLOWRU_PREORDER_STAFF_SPEND_V2
  Future<void> _openClientSpend(_PreorderItem item) async {
    final clientId = item.clientId;

    if (clientId == null || clientId <= 0) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StaffClientSpendScreen(
          establishmentId: widget.establishmentId,
          establishmentName: widget.establishmentName,
          clientId: clientId.toString(),
          clientName: item.clientName.trim().isEmpty
              ? '\u041a\u043b\u0438\u0435\u043d\u0442'
              : item.clientName.trim(),
        ),
      ),
    );

    if (mounted) {
      await _load();
    }
  }

  Future<String> _refreshAccessToken() async {
    final refreshToken = await AuthStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.trim().isEmpty) {
      throw Exception('Сессия истекла. Войдите заново.');
    }

    final result = await UserApi().refresh(
      refreshToken: refreshToken.trim(),
      deviceId: kIsWeb ? 'staff-web' : 'staff-mobile',
      platform: kIsWeb ? 'web' : 'mobile',
    );

    if (!result.ok || result.accessToken.trim().isEmpty) {
      throw Exception('Сессия истекла. Войдите заново.');
    }

    await AuthStorage.saveAccessToken(result.accessToken.trim());

    if (result.refreshToken.trim().isNotEmpty) {
      await AuthStorage.saveRefreshToken(result.refreshToken.trim());
    }

    return result.accessToken.trim();
  }

  Future<Map<String, String>> _headers({
    bool json = false,
    bool forceRefresh = false,
  }) async {
    final token = forceRefresh ? await _refreshAccessToken() : await _token();

    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
    };
  }

  Future<void> _selectPreorderSection(int index) async {
    if (_preorderSection == index) return;

    setState(() {
      _preorderSection = index;
    });

    if (index == 1 && !_catalogLoaded && !_catalogLoading) {
      await _loadCatalog();
    }
  }

  Future<void> _loadCatalog() async {
    if (_catalogLoading) return;

    setState(() {
      _catalogLoading = true;
      _catalogError = null;
    });

    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/v1/staff/preorders/catalog'
        '?establishment_id=${widget.establishmentId}',
      );

      var response = await http.get(uri, headers: await _headers());

      if (response.statusCode == 401 || response.statusCode == 403) {
        response = await http.get(
          uri,
          headers: await _headers(forceRefresh: true),
        );
      }

      if (response.statusCode != 200) {
        throw Exception(
          _catalogStatusErrorMessage(response.statusCode, response.body),
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final rawItems = (decoded['items'] as List?) ?? const [];

      final parsed = rawItems
          .whereType<Map>()
          .map((raw) => _StaffCatalogItem.fromJson(raw.cast<String, dynamic>()))
          .where((item) => item.id > 0 && item.name.trim().isNotEmpty)
          .toList();

      if (!mounted) return;

      setState(() {
        _catalogItems = parsed;
        _catalogLoaded = true;
        _catalogLoading = false;
        _catalogError = null;
      });
    } catch (e) {
      if (!mounted) return;

      final message = e.toString().replaceFirst('Exception: ', '').trim();

      setState(() {
        _catalogLoading = false;
        _catalogError = message.isEmpty
            ? '\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u0437\u0430\u0433\u0440\u0443\u0437\u0438\u0442\u044c \u043d\u0430\u043b\u0438\u0447\u0438\u0435'
            : message;
      });
    }
  }

  String _catalogStatusErrorMessage(int statusCode, String body) {
    if (statusCode == 401 || statusCode == 403) {
      return '\u0421\u0435\u0441\u0441\u0438\u044f \u0438\u0441\u0442\u0435\u043a\u043b\u0430. \u0412\u043e\u0439\u0434\u0438\u0442\u0435 \u0437\u0430\u043d\u043e\u0432\u043e.';
    }

    try {
      final decoded = jsonDecode(body);

      if (decoded is Map && decoded['detail'] != null) {
        final detail = decoded['detail'].toString().trim();
        if (detail.isNotEmpty) return detail;
      }
    } catch (_) {}

    return '\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u043e\u0431\u043d\u043e\u0432\u0438\u0442\u044c \u043d\u0430\u043b\u0438\u0447\u0438\u0435';
  }

  Future<void> _setCatalogAvailability(
    _StaffCatalogItem item,
    bool value,
  ) async {
    if (_catalogUpdatingIds.contains(item.id)) return;

    final oldValue = item.isAvailable;

    setState(() {
      _catalogUpdatingIds.add(item.id);
      item.isAvailable = value;
    });

    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/v1/staff/preorders/catalog/'
        '${item.id}/availability',
      );

      final payload = <String, dynamic>{
        'establishment_id': widget.establishmentId,
        'is_available': value,
      };

      var response = await http.post(
        uri,
        headers: await _headers(json: true),
        body: jsonEncode(payload),
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        response = await http.post(
          uri,
          headers: await _headers(json: true, forceRefresh: true),
          body: jsonEncode(payload),
        );
      }

      if (response.statusCode != 200) {
        throw Exception(
          _catalogStatusErrorMessage(response.statusCode, response.body),
        );
      }

      if (!mounted) return;

      setState(() {
        _catalogUpdatingIds.remove(item.id);
        _catalogError = null;
      });
    } catch (e) {
      if (!mounted) return;

      final message = e.toString().replaceFirst('Exception: ', '').trim();

      setState(() {
        item.isAvailable = oldValue;
        _catalogUpdatingIds.remove(item.id);
        _catalogError = message.isEmpty
            ? '\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u0438\u0437\u043c\u0435\u043d\u0438\u0442\u044c \u043d\u0430\u043b\u0438\u0447\u0438\u0435'
            : message;
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/v1/staff/preorders?establishment_id=${widget.establishmentId}&limit=100',
      );

      var response = await http.get(uri, headers: await _headers());

      if (response.statusCode == 401 || response.statusCode == 403) {
        response = await http.get(
          uri,
          headers: await _headers(forceRefresh: true),
        );
      }

      if (response.statusCode != 200) {
        throw Exception(
          _statusErrorMessage(response.statusCode, response.body),
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final rawItems = (decoded['items'] as List?) ?? const [];

      if (!mounted) return;
      setState(() {
        _items = rawItems
            .map(
              (e) => _PreorderItem.fromJson((e as Map).cast<String, dynamic>()),
            )
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final message = e.toString().replaceFirst('Exception: ', '').trim();
        _loading = false;
        _error = message.isEmpty ? 'Не удалось загрузить предзаказы' : message;
      });
    }
  }

  String _statusErrorMessage(int statusCode, String body) {
    if (statusCode == 401 || statusCode == 403) {
      return 'Сессия истекла. Войдите заново.';
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] != null) {
        final detail = decoded['detail'].toString().trim();

        if (detail.toLowerCase().contains('invalid token')) {
          return 'Сессия истекла. Войдите заново.';
        }

        if (detail.isNotEmpty) return detail;
      }
    } catch (_) {}

    if (statusCode == 400) {
      return 'Проверьте сумму чека и настройки начисления';
    }

    return 'Не удалось обновить статус';
  }

  double? _parseAmount(String raw) {
    final normalized = raw
        .trim()
        .replaceAll(' ', '')
        .replaceAll('₽', '')
        .replaceAll(',', '.');

    if (normalized.isEmpty) return null;

    final value = double.tryParse(normalized);
    if (value == null || value <= 0) return null;

    return value;
  }

  String _formatMoney(double value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  Future<double?> _askCompletedAmount(_PreorderItem item) async {
    final controller = TextEditingController(
      text: item.amountTotal != null && item.amountTotal! > 0
          ? _formatMoney(item.amountTotal!)
          : '',
    );

    String? localError;

    final result = await showDialog<double>(
      context: context,
      barrierDismissible: !_updating,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
              contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              actionsPadding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
              title: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1ECAD3),
                          Color(0xFF118EAF),
                          Color(0xFF0B4E73),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.payments_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Сумма чека',
                      style: TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Введите сумму, которую клиент оплатил за заказ. После выдачи Flowru автоматически начислит бонусы.',
                    style: TextStyle(
                      color: _soft,
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Сумма чека, ₽',
                      hintText: 'Например, 350',
                      errorText: localError,
                      filled: true,
                      fillColor: _bg,
                      prefixIcon: const Icon(Icons.payments_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: _stroke),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: _stroke),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: _mint, width: 1.7),
                      ),
                    ),
                    onSubmitted: (_) {
                      final amount = _parseAmount(controller.text);
                      if (amount == null) {
                        setDialogState(() {
                          localError = 'Введите сумму больше 0';
                        });
                        return;
                      }
                      Navigator.of(dialogContext).pop(amount);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'Назад',
                    style: TextStyle(color: _soft, fontWeight: FontWeight.w900),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final amount = _parseAmount(controller.text);
                    if (amount == null) {
                      setDialogState(() {
                        localError = 'Введите сумму больше 0';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(amount);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _deep,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Выдать',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<void> _completePreorder(_PreorderItem item) async {
    if (_updating) return;

    final amount = await _askCompletedAmount(item);
    if (amount == null) return;

    await _setStatus(item, 'completed', amountTotal: amount);
  }

  Future<void> _setStatus(
    _PreorderItem item,
    String status, {
    double? amountTotal,
    String? staffComment,
  }) async {
    if (_updating) return;

    setState(() {
      _updating = true;
      _error = null;
    });

    try {
      final payload = <String, dynamic>{'status': status};

      if (staffComment != null && staffComment.trim().isNotEmpty) {
        payload['staff_comment'] = staffComment.trim();
      }

      if (status == 'completed') {
        payload['amount_total'] = amountTotal;
      }

      final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/v1/staff/preorders/${item.id}/status',
      );

      var response = await http.post(
        uri,
        headers: await _headers(json: true),
        body: jsonEncode(payload),
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        response = await http.post(
          uri,
          headers: await _headers(json: true, forceRefresh: true),
          body: jsonEncode(payload),
        );
      }

      if (response.statusCode != 200) {
        throw Exception(
          _statusErrorMessage(response.statusCode, response.body),
        );
      }

      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final message = e.toString().replaceFirst('Exception: ', '').trim();
        _error = message.isEmpty ? 'Не удалось обновить статус' : message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _updating = false;
        });
      }
    }
  }

  // FLOWRU_PREORDER_CANCEL_REASON_V2_20260909
  Future<void> _cancelPreorderWithReason(_PreorderItem item) async {
    if (_updating) return;

    final reason = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        const reasons = <String>[
          'Нет позиции в наличии',
          'Не успеваем приготовить',
          'Техническая проблема',
          'Заведение скоро закрывается',
          'Другая причина',
        ];

        return Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _stroke,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Text(
                item.status == 'new'
                    ? 'Почему отказываем в заказе?'
                    : 'Почему отменяем заказ?',
                style: const TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Причина сохранится в заказе.',
                style: TextStyle(
                  color: _soft,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              ...reasons.map(
                (value) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    value == 'Другая причина'
                        ? CupertinoIcons.pencil
                        : CupertinoIcons.xmark_circle_fill,
                    color: value == 'Другая причина' ? _soft : _red,
                    size: 20,
                  ),
                  title: Text(
                    value,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  trailing: const Icon(
                    CupertinoIcons.chevron_right,
                    color: _soft,
                    size: 15,
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(value),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || reason == null) return;

    String finalReason = reason;

    if (reason == 'Другая причина') {
      final controller = TextEditingController();

      final customReason = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Text(
              'Причина отказа',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 160,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Напишите причину'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Назад'),
              ),
              FilledButton(
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isNotEmpty) {
                    Navigator.of(dialogContext).pop(value);
                  }
                },
                child: const Text('Готово'),
              ),
            ],
          );
        },
      );

      controller.dispose();

      if (!mounted || customReason == null || customReason.trim().isEmpty) {
        return;
      }

      finalReason = customReason.trim();
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          item.status == 'new' ? 'Отказать в заказе?' : 'Отменить заказ?',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text('Причина: $finalReason'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Назад'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(item.status == 'new' ? 'Отказать' : 'Отменить'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    await _setStatus(item, 'cancelled', staffComment: finalReason);
  }

  List<_PreorderItem> get _activeItems {
    final result = _items
        .where(
          (e) =>
              e.status == 'new' || e.status == 'in_work' || e.status == 'ready',
        )
        .toList();

    result.sort((a, b) {
      int rank(String status) {
        if (status == 'new') return 1;
        if (status == 'in_work') return 2;
        if (status == 'ready') return 3;
        return 9;
      }

      final r = rank(a.status).compareTo(rank(b.status));
      if (r != 0) return r;
      return b.id.compareTo(a.id);
    });

    return result;
  }

  List<_PreorderItem> get _doneItems {
    final result = _items
        .where(
          (e) =>
              e.status == 'completed' ||
              e.status == 'cancelled' ||
              e.status == 'expired',
        )
        .toList();
    result.sort((a, b) => b.id.compareTo(a.id));
    return result;
  }

  int get _newCount => _items.where((e) => e.status == 'new').length;
  int get _inWorkCount => _items.where((e) => e.status == 'in_work').length;
  int get _readyCount => _items.where((e) => e.status == 'ready').length;

  String _statusText(String status) {
    switch (status) {
      case 'new':
        return 'Новый';
      case 'in_work':
        return 'В работе';
      case 'ready':
        return 'Готов';
      case 'completed':
        return 'Выдан';
      case 'cancelled':
        return 'Отменён';
      case 'expired':
        return 'Пропущен';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'new':
        return _orange;
      case 'in_work':
        return _blue;
      case 'ready':
        return _green;
      case 'completed':
        return _green;
      case 'cancelled':
        return _red;
      case 'expired':
        return _orange;
      default:
        return _soft;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'new':
        return CupertinoIcons.bell_fill;
      case 'in_work':
        return CupertinoIcons.flame_fill;
      case 'ready':
        return CupertinoIcons.checkmark_seal_fill;
      case 'completed':
        return CupertinoIcons.archivebox_fill;
      case 'cancelled':
        return CupertinoIcons.xmark_circle_fill;
      case 'expired':
        return CupertinoIcons.exclamationmark_triangle_fill;
      default:
        return CupertinoIcons.bag_fill;
    }
  }

  // FLOWRU_PREORDERS_VISUAL_V3_20260909

  Widget _ambientBlob({required double size, required Color color}) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withOpacity(0.19),
              color.withOpacity(0.055),
              color.withOpacity(0),
            ],
            stops: const [0, 0.48, 1],
          ),
        ),
      ),
    );
  }

  BoxDecoration _glassPanel({
    double radius = 28,
    Color? glow,
    double opacity = 0.76,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(opacity),
          Colors.white.withOpacity(opacity * 0.76),
          const Color(0xFFF1FBFC).withOpacity(opacity * 0.67),
        ],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withOpacity(0.90), width: 1.15),
      boxShadow: [
        BoxShadow(
          color: _deep.withOpacity(0.055),
          blurRadius: 30,
          offset: const Offset(0, 13),
        ),
        if (glow != null)
          BoxShadow(
            color: glow.withOpacity(0.070),
            blurRadius: 34,
            spreadRadius: -8,
          ),
        BoxShadow(
          color: Colors.white.withOpacity(0.56),
          blurRadius: 4,
          offset: const Offset(0, -2),
        ),
      ],
    );
  }

  // FLOWRU_PREORDERS_PREMIUM_V4_20260909
  Widget _ambientOrb({
    required double size,
    required Color color,
    double opacity = 1,
  }) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withOpacity(0.22),
                color.withOpacity(0.07),
                color.withOpacity(0),
              ],
              stops: const [0, 0.46, 1],
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassSurface({
    required Widget child,
    EdgeInsetsGeometry? padding,
    double radius = 28,
    Color glow = _mint,
    double glowStrength = 0.05,
    bool flat = false,
  }) {
    if (flat) {
      final edgeOpacity = (0.035 + glowStrength).clamp(0.045, 0.14).toDouble();

      return Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              glow.withOpacity(edgeOpacity),
              glow.withOpacity(edgeOpacity * 0.30),
              Colors.transparent,
            ],
            stops: const [0, 0.36, 1],
          ),
        ),
        child: child,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.87),
                Colors.white.withOpacity(0.66),
                const Color(0xFFEFFBFC).withOpacity(0.70),
              ],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withOpacity(0.92),
              width: 1.15,
            ),
            boxShadow: [
              BoxShadow(
                color: _deep.withOpacity(0.065),
                blurRadius: 30,
                offset: const Offset(0, 13),
              ),
              BoxShadow(
                color: glow.withOpacity(glowStrength),
                blurRadius: 30,
                spreadRadius: -8,
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.70),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _softIconTile({
    required IconData icon,
    required Color color,
    double size = 48,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.18), Colors.white.withOpacity(0.78)],
        ),
        borderRadius: BorderRadius.circular(size * 0.34),
        border: Border.all(color: Colors.white.withOpacity(0.86)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.12),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: size * 0.42),
    );
  }

  Widget _decorativeCube(Color color) {
    return Transform.rotate(
      angle: -0.10,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.98),
              color.withOpacity(0.15),
              color.withOpacity(0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.94), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.19),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: _deep.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(8, 10),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.66)],
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.22), blurRadius: 13),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _fadeIn({required Widget child, int delay = 0}) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 430 + delay),
      tween: Tween(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _heroMetric(String label, int value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.88), size: 18),
            const SizedBox(height: 9),
            Text(
              value.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 27,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.82),
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroCard() {
    final activeCount = _activeItems.length;

    Widget metric({
      required String label,
      required int value,
      required IconData icon,
      required Color color,
    }) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Container(
                width: 31,
                height: 31,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$value',
                      style: TextStyle(
                        color: value > 0 ? color : _ink,
                        fontSize: 20,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _soft,
                        fontSize: 9.7,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _glassSurface(
      flat: true,
      radius: 22,
      glow: _mint,
      glowStrength: 0.035,
      padding: const EdgeInsets.fromLTRB(3, 10, 3, 8),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: _mint.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  CupertinoIcons.bag_fill,
                  color: _mint,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '\u041f\u0440\u0435\u0434\u0437\u0430\u043a\u0430\u0437\u044b',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 21,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.45,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      activeCount == 0
                          ? '\u041d\u043e\u0432\u044b\u0445 \u0437\u0430\u043a\u0430\u0437\u043e\u0432 \u0441\u0435\u0439\u0447\u0430\u0441 \u043d\u0435\u0442'
                          : '$activeCount \u0430\u043a\u0442\u0438\u0432\u043d\u044b\u0445 \u2022 \u0442\u0440\u0435\u0431\u0443\u044e\u0442 \u0432\u043d\u0438\u043c\u0430\u043d\u0438\u044f',
                      style: const TextStyle(
                        color: _soft,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.circle_fill, size: 7, color: _green),
                    SizedBox(width: 5),
                    Text(
                      '\u043e\u043d\u043b\u0430\u0439\u043d',
                      style: TextStyle(
                        color: _green,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Container(
            height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _mint.withOpacity(0.36),
                  _blue.withOpacity(0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              metric(
                label: '\u041d\u043e\u0432\u044b\u0435',
                value: _newCount,
                icon: CupertinoIcons.bell_fill,
                color: const Color(0xFFFF5364),
              ),
              metric(
                label: '\u0413\u043e\u0442\u043e\u0432\u044f\u0442\u0441\u044f',
                value: _inWorkCount,
                icon: CupertinoIcons.flame_fill,
                color: _orange,
              ),
              metric(
                label: '\u0413\u043e\u0442\u043e\u0432\u044b',
                value: _readyCount,
                icon: CupertinoIcons.checkmark_seal_fill,
                color: _green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 11),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1ECAD3),
                  Color(0xFF118EAF),
                  Color(0xFF0B4E73),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _stroke),
            ),
            child: Text(
              count,
              style: const TextStyle(
                color: _soft,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoLine({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Text(
            '$label: ',
            style: const TextStyle(
              color: _soft,
              fontSize: 12.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentLine(_PreorderItem item) {
    final isCard = item.paymentMethod == 'card';
    final isCash = item.paymentMethod == 'cash';

    final color = isCard
        ? _blue
        : isCash
        ? _green
        : _soft;

    return _pill(icon: item.paymentIcon, text: item.paymentLabel, color: color);
  }

  Widget _accrualLine(_PreorderItem item) {
    final amount = item.amountTotal;
    final bonus = item.bonusAccrued;

    final parts = <String>[];
    if (amount != null && amount > 0) {
      parts.add('Чек ${_formatMoney(amount)} ₽');
    }
    if (bonus != null && bonus > 0) {
      parts.add('начислено ${_formatMoney(bonus)} баллов');
    }

    if (parts.isEmpty) return const SizedBox.shrink();

    return _pill(
      icon: CupertinoIcons.sparkles,
      text: parts.join(' • '),
      color: _green,
    );
  }

  Widget _actionButton({
    required String text,
    required Color color,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: SizedBox(
        height: 46,
        child: ElevatedButton.icon(
          onPressed: _updating ? null : onTap,
          icon: Icon(icon, size: 16),
          label: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            disabledBackgroundColor: color.withOpacity(0.34),
            disabledForegroundColor: Colors.white.withOpacity(0.72),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: const TextStyle(
              fontSize: 12.4,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  List<String> _flowOrderLines(_PreorderItem item) {
    return item.orderText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where((line) => !line.toLowerCase().startsWith('комментарий:'))
        .toList();
  }

  String? _flowOrderComment(_PreorderItem item) {
    for (final raw in item.orderText.split(RegExp(r'\r?\n'))) {
      final line = raw.trim();
      if (line.toLowerCase().startsWith('комментарий:')) {
        final colon = line.indexOf(':');
        if (colon >= 0 && colon + 1 < line.length) {
          final value = line.substring(colon + 1).trim();
          if (value.isNotEmpty) return value;
        }
      }
    }
    return null;
  }

  Widget _flowOrderContents(_PreorderItem item) {
    final lines = _flowOrderLines(item);
    final comment = _flowOrderComment(item);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lines.isEmpty)
          const Text(
            'Состав заказа не указан',
            style: TextStyle(
              color: _soft,
              fontSize: 12.8,
              fontWeight: FontWeight.w700,
            ),
          )
        else
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFB),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _stroke.withOpacity(0.80)),
            ),
            child: Column(
              children: [
                for (int i = 0; i < lines.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 23,
                          height: 23,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _mint.withOpacity(0.09),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: _deep,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            lines[i],
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 13.2,
                              height: 1.3,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i != lines.length - 1)
                    Divider(
                      height: 1,
                      indent: 43,
                      endIndent: 11,
                      color: _stroke.withOpacity(0.65),
                    ),
                ],
              ],
            ),
          ),
        if (comment != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.07),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: _orange.withOpacity(0.12)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  CupertinoIcons.text_bubble_fill,
                  color: _orange,
                  size: 15,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    comment,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 12.2,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // FLOWRU_PREORDERS_FLAT_V2_20260914

  String _staffMoney(double? value) {
    if (value == null) return '\u2014';

    if (value == value.roundToDouble()) {
      return '${value.toStringAsFixed(0)} \u20bd';
    }

    return '${value.toStringAsFixed(2)} \u20bd';
  }

  String _staffReadableOrderLine(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return value;

    final dash = value.indexOf(' \u2014 ');

    if (dash > 0) {
      final left = value.substring(0, dash).trim();
      final right = value.substring(dash + 3).trim();

      final leftKey = left.toLowerCase().replaceAll('\u0451', '\u0435');
      final rightKey = right.toLowerCase().replaceAll('\u0451', '\u0435');

      if (leftKey.isNotEmpty && rightKey.startsWith(leftKey)) {
        value = right;
      }
    }

    final parts = value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.length <= 1) return value;

    final base = parts.first;
    final extras = <String>[];

    const syrupHints = <String>[
      '\u0432\u0438\u0448\u043d',
      '\u0432\u0430\u043d\u0438\u043b',
      '\u043a\u0430\u0440\u0430\u043c\u0435\u043b',
      '\u0444\u0443\u043d\u0434\u0443\u043a',
      '\u043e\u0440\u0435\u0445',
      '\u0448\u043e\u043a\u043e\u043b\u0430\u0434',
      '\u0430\u0439\u0440\u0438\u0448',
      '\u043c\u044f\u0442\u0430',
      '\u0433\u0440\u0443\u0448',
      '\u043c\u0430\u043b\u0438\u043d',
      '\u043a\u043b\u0443\u0431\u043d\u0438\u0447',
      '\u043c\u0430\u043d\u0433\u043e',
      '\u0440\u043e\u0437\u0430',
      '\u043a\u043e\u0440\u0438\u0446\u0430',
      '\u043b\u0430\u0432\u0430\u043d\u0434',
      '\u0442\u0430\u0440\u0445\u0443\u043d',
      '\u044f\u0431\u043b\u043e\u043a',
      '\u043a\u043e\u043a\u043e\u0441',
    ];

    for (final extraRaw in parts.skip(1)) {
      final extra = extraRaw.trim();
      final lower = extra.toLowerCase().replaceAll('\u0451', '\u0435');

      if (lower.startsWith('\u0441\u0438\u0440\u043e\u043f')) {
        final clean = extra.replaceFirst(
          RegExp(
            r'^\u0441\u0438\u0440\u043e\u043f\s*:?\s*',
            caseSensitive: false,
            unicode: true,
          ),
          '',
        );

        extras.add('\u0421\u0438\u0440\u043e\u043f: $clean');
        continue;
      }

      if (lower.contains('\u0440\u0430\u0441\u0442\u0438\u0442\u0435\u043b') ||
          lower.contains('\u0430\u043b\u044c\u0442.') ||
          lower.contains('\u043c\u043e\u043b\u043e\u043a\u043e')) {
        extras.add(
          lower.startsWith('\u043c\u043e\u043b\u043e\u043a\u043e')
              ? extra
              : '\u041c\u043e\u043b\u043e\u043a\u043e: $extra',
        );
        continue;
      }

      if (syrupHints.any(lower.contains)) {
        extras.add('\u0421\u0438\u0440\u043e\u043f: $extra');
        continue;
      }

      extras.add('\u0414\u043e\u0431\u0430\u0432\u043a\u0430: $extra');
    }

    return '$base  \u2022  ${extras.join('  \u2022  ')}';
  }

  Widget _flowSection({
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required List<_PreorderItem> items,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: _glassSurface(
        flat: true,
        radius: 20,
        glow: color,
        glowStrength: 0.035,
        padding: const EdgeInsets.fromLTRB(3, 7, 2, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 17,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.25,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _soft,
                          fontSize: 10.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${items.length}',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.58),
                    color.withOpacity(0.10),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.46, 1],
                ),
              ),
            ),
            const SizedBox(height: 7),
            _ordersList(items),
          ],
        ),
      ),
    );
  }

  // FLOWRU_ORDER_BORDER_RUNTIME_FIX_20260914
  Widget _orderCard(_PreorderItem item, int index) {
    final statusColor = _statusColor(item.status);
    final left = _minutesLeft(item);
    final attention = _attentionText(item);
    final attentionColor = _attentionColor(item);

    final lines = _flowOrderLines(
      item,
    ).map(_staffReadableOrderLine).where((e) => e.trim().isNotEmpty).toList();

    final comment = _flowOrderComment(item);

    String actionText;
    IconData actionIcon;
    VoidCallback actionTap;

    if (item.status == 'new') {
      actionText = '\u041f\u0440\u0438\u043d\u044f\u0442\u044c';
      actionIcon = CupertinoIcons.checkmark_alt_circle_fill;
      actionTap = () => _setStatus(item, 'in_work');
    } else if (item.status == 'in_work') {
      actionText = '\u0413\u043e\u0442\u043e\u0432';
      actionIcon = CupertinoIcons.checkmark_seal_fill;
      actionTap = () => _setStatus(item, 'ready');
    } else {
      actionText = '\u0412\u044b\u0434\u0430\u0442\u044c';
      actionIcon = CupertinoIcons.archivebox_fill;
      actionTap = () => _completePreorder(item);
    }

    var timeValue = item.pickupLabel;

    if (item.status == 'in_work' && left != null) {
      timeValue = left < 0
          ? '\u041f\u0440\u043e\u0441\u0440\u043e\u0447\u0435\u043d\u043e ${left.abs()} \u043c\u0438\u043d'
          : '$left \u043c\u0438\u043d';
    } else if (item.status == 'ready') {
      timeValue =
          '\u0416\u0434\u0451\u0442 \u043a\u043b\u0438\u0435\u043d\u0442\u0430';
    }

    return _fadeIn(
      delay: index.clamp(0, 6) * 35,
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, _) {
          final pulse = item.status == 'new' ? _motion.value : 0.0;

          return Container(
            margin: const EdgeInsets.only(bottom: 11),
            padding: const EdgeInsets.fromLTRB(13, 12, 11, 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  statusColor.withOpacity(0.115 + pulse * 0.025),
                  statusColor.withOpacity(0.035),
                  Colors.transparent,
                ],
                stops: const [0, 0.38, 1],
              ),
              border: Border.all(
                color: statusColor.withOpacity(0.10),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '#${item.id}',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _statusText(item.status),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(CupertinoIcons.clock, size: 13, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      timeValue,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Text(
                  item.clientName.trim().isEmpty
                      ? '\u041a\u043b\u0438\u0435\u043d\u0442'
                      : item.clientName.trim(),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 15.8,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),

                const SizedBox(height: 9),

                if (lines.isEmpty)
                  const Text(
                    '\u0421\u043e\u0441\u0442\u0430\u0432 \u0437\u0430\u043a\u0430\u0437\u0430 \u043d\u0435 \u0443\u043a\u0430\u0437\u0430\u043d',
                    style: TextStyle(
                      color: _soft,
                      fontSize: 12.4,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  ...lines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.78),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              line,
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 12.8,
                                height: 1.30,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (comment != null && comment.trim().isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 7, 4, 7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _orange.withOpacity(0.09),
                          _orange.withOpacity(0.025),
                          Colors.transparent,
                        ],
                      ),
                      border: Border(
                        left: BorderSide(
                          color: _orange.withOpacity(0.72),
                          width: 3,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          CupertinoIcons.text_bubble_fill,
                          color: _orange,
                          size: 15,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            '\u041a\u043e\u043c\u043c\u0435\u043d\u0442\u0430\u0440\u0438\u0439: ${comment.trim()}',
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 12.3,
                              height: 1.32,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                Row(
                  children: [
                    const Text(
                      '\u0418\u0442\u043e\u0433\u043e:',
                      style: TextStyle(
                        color: _soft,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _staffMoney(item.amountTotal),
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.25,
                      ),
                    ),
                    const Spacer(),
                    if (item.clientPoints != null && item.clientPoints! > 0)
                      InkWell(
                        onTap: !_updating && item.clientId != null
                            ? () => _openClientSpend(item)
                            : null,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                CupertinoIcons.star_circle_fill,
                                color: _mint,
                                size: 15,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${item.clientPoints} \u0431\u0430\u043b\u043b\u043e\u0432',
                                style: const TextStyle(
                                  color: _deep,
                                  fontSize: 11.3,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                if (attention != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        CupertinoIcons.exclamationmark_triangle_fill,
                        color: attentionColor,
                        size: 14,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          attention,
                          style: TextStyle(
                            color: attentionColor,
                            fontSize: 11.3,
                            height: 1.25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: _updating ? null : actionTap,
                          icon: Icon(actionIcon, size: 17),
                          label: Text(actionText),
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: statusColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: statusColor.withOpacity(
                              0.35,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 13.8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: _updating
                              ? null
                              : () => _cancelPreorderWithReason(item),
                          icon: const Icon(
                            CupertinoIcons.xmark_circle,
                            size: 17,
                          ),
                          label: Text(
                            item.status == 'new'
                                ? '\u041e\u0442\u043a\u0430\u0437\u0430\u0442\u044c'
                                : '\u041e\u0442\u043c\u0435\u043d\u0438\u0442\u044c',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _red,
                            side: BorderSide(
                              color: _red.withOpacity(0.38),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            textStyle: const TextStyle(
                              fontSize: 12.4,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _doneRow(_PreorderItem item) {
    final statusColor = _statusColor(item.status);

    final lines = _flowOrderLines(
      item,
    ).map(_staffReadableOrderLine).where((e) => e.trim().isNotEmpty).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 5, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withOpacity(0.07),
            statusColor.withOpacity(0.018),
            Colors.transparent,
          ],
          stops: const [0, 0.42, 1],
        ),
        border: Border(
          bottom: BorderSide(color: _stroke.withOpacity(0.40), width: 0.8),
        ),
      ),
      child: Row(
        children: [
          Icon(_statusIcon(item.status), color: statusColor, size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.clientName.trim().isEmpty
                      ? _statusText(item.status)
                      : item.clientName.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 12.4,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  lines.isEmpty ? item.doneCompactTitle : lines.first,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _soft,
                    fontSize: 10.5,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.createdLabel,
            style: const TextStyle(
              color: _soft,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _parseLocalDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
  }

  DateTime? _deadlineOf(_PreorderItem item) {
    final pickupAt = _parseLocalDate(item.pickupAt);
    if (pickupAt != null) return pickupAt;

    final createdAt = _parseLocalDate(item.createdAt);
    final minutes = item.pickupMinutes ?? 0;
    if (createdAt == null || minutes <= 0) return null;

    return createdAt.add(Duration(minutes: minutes));
  }

  int? _minutesLeft(_PreorderItem item) {
    final deadline = _deadlineOf(item);
    if (deadline == null) return null;
    return deadline.difference(DateTime.now()).inMinutes;
  }

  bool _isIgnoredNewOrder(_PreorderItem item) {
    if (item.status != 'new') return false;
    final createdAt = _parseLocalDate(item.createdAt);
    if (createdAt == null) return false;
    return DateTime.now().difference(createdAt).inSeconds >= 90;
  }

  bool _isWarningOrder(_PreorderItem item) {
    if (item.status != 'in_work') return false;
    final left = _minutesLeft(item);
    if (left == null) return false;
    return left <= 10 && left > 5;
  }

  bool _isCriticalOrder(_PreorderItem item) {
    if (item.status != 'in_work') return false;
    final left = _minutesLeft(item);
    if (left == null) return false;
    return left <= 5 && left >= 0;
  }

  bool _isOverdueOrder(_PreorderItem item) {
    if (item.status != 'in_work') return false;
    final left = _minutesLeft(item);
    if (left == null) return false;
    return left < 0;
  }

  bool _needsPulse(_PreorderItem item) {
    return _isIgnoredNewOrder(item) ||
        _isCriticalOrder(item) ||
        _isOverdueOrder(item);
  }

  Color _attentionColor(_PreorderItem item) {
    if (_isOverdueOrder(item)) return const Color(0xFFE95436);
    if (_isCriticalOrder(item)) return const Color(0xFFFF7A1A);
    if (_isWarningOrder(item)) return const Color(0xFFF6A92B);
    if (_isIgnoredNewOrder(item)) return const Color(0xFF0BAEBB);
    return _mint;
  }

  String? _attentionText(_PreorderItem item) {
    if (_isOverdueOrder(item)) return 'Срок выдачи уже наступил';
    if (_isCriticalOrder(item)) return 'Время на приготовление истекает';
    if (_isWarningOrder(item)) return 'До выдачи осталось мало времени';
    if (_isIgnoredNewOrder(item)) return 'Заказ ждёт принятия в работу';
    return null;
  }

  Widget _attentionBanner(_PreorderItem item) {
    final text = _attentionText(item);
    if (text == null) return const SizedBox.shrink();

    final color = _attentionColor(item);
    final left = _minutesLeft(item);
    String? trailing;

    if (item.status == 'in_work' && left != null) {
      trailing = left >= 0 ? '$left мин' : 'просрочено';
    }

    return AnimatedBuilder(
      animation: _motion,
      builder: (context, _) {
        final pulse = _needsPulse(item);
        final opacity = pulse ? 0.11 + (_motion.value * 0.08) : 0.11;

        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(opacity),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: color.withOpacity(
                pulse ? 0.28 + (_motion.value * 0.18) : 0.22,
              ),
              width: pulse ? 1.4 : 1,
            ),
            boxShadow: pulse
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.12 + (_motion.value * 0.10)),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(CupertinoIcons.time_solid, color: color, size: 17),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Text(
                  trailing,
                  style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _ordersList(List<_PreorderItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;

        if (!isWide) {
          return Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                _orderCard(items[i], i),
                if (i != items.length - 1) const SizedBox(height: 13),
              ],
            ],
          );
        }

        return GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.18,
          ),
          itemBuilder: (context, index) => _orderCard(items[index], index),
        );
      },
    );
  }

  Widget _emptyState() {
    return _glassSurface(
      radius: 25,
      glow: _mint,
      glowStrength: 0.025,
      padding: const EdgeInsets.fromLTRB(17, 18, 17, 18),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE8FBFA), Color(0xFFD8F4F5)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _mint.withOpacity(0.10),
                  blurRadius: 15,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: const Icon(CupertinoIcons.tray, color: _deep, size: 22),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Активных предзаказов нет',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.20,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Новый заказ сразу появится здесь и подсветит вкладку «Заказы».',
                  style: TextStyle(
                    color: _soft,
                    fontSize: 11.1,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBanner() {
    if (_error == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: _red.withOpacity(0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _red.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: _red,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                color: _red,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _preorderSectionSwitcher() {
    final activeOrders = _activeItems.length;

    Widget segment({
      required int index,
      required String label,
      required IconData icon,
    }) {
      final selected = _preorderSection == index;
      final alert = index == 0 && activeOrders > 0;

      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _selectPreorderSection(index),
          child: AnimatedBuilder(
            animation: _motion,
            builder: (context, _) {
              final pulse = alert ? _motion.value : 0.0;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeOutCubic,
                height: 58,
                decoration: BoxDecoration(
                  gradient: selected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: alert
                              ? const [
                                  Color(0xFFFFFCFE),
                                  Color(0xFFFFF1F8),
                                  Color(0xFFFFFFFF),
                                ]
                              : const [
                                  Color(0xFFFFFFFF),
                                  Color(0xFFF7FCFD),
                                  Color(0xFFEFF9FA),
                                ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(20),
                  border: selected
                      ? Border.all(
                          color: Colors.white.withOpacity(0.98),
                          width: 1.2,
                        )
                      : null,
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: _deep.withOpacity(0.075),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: alert
                                ? _red.withOpacity(0.045 + pulse * 0.10)
                                : _mint.withOpacity(0.065),
                            blurRadius: 18 + pulse * 10,
                            spreadRadius: -3,
                          ),
                        ]
                      : const [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _softIconTile(
                      icon: icon,
                      color: selected ? _mint : _soft,
                      size: 34,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: selected ? _ink : _soft,
                        fontSize: 13.8,
                        fontWeight: selected
                            ? FontWeight.w900
                            : FontWeight.w700,
                      ),
                    ),
                    if (alert) ...[
                      const SizedBox(width: 8),
                      Container(
                        constraints: const BoxConstraints(minWidth: 23),
                        height: 23,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6574), Color(0xFFFF4055)],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: _red.withOpacity(0.20 + pulse * 0.24),
                              blurRadius: 8 + pulse * 9,
                              spreadRadius: pulse * 1.4,
                            ),
                          ],
                        ),
                        child: Text(
                          '$activeOrders',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.4,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.46),
                const Color(0xFFDDEFF2).withOpacity(0.55),
                Colors.white.withOpacity(0.26),
              ],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withOpacity(0.78),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: _deep.withOpacity(0.055),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              segment(index: 0, label: 'Заказы', icon: CupertinoIcons.bag_fill),
              segment(
                index: 1,
                label: 'Наличие',
                icon: CupertinoIcons.slider_horizontal_3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _availabilityContent() {
    if (_catalogLoading && !_catalogLoaded) {
      return [
        const SizedBox(height: 90),
        const Center(child: CupertinoActivityIndicator(radius: 15)),
      ];
    }

    if (_catalogError != null && !_catalogLoaded) {
      return [_availabilityErrorCard()];
    }

    if (_catalogItems.isEmpty) {
      return [_availabilityEmptyCard()];
    }

    final availableCount = _catalogItems
        .where((item) => item.isAvailable)
        .length;
    final stopCount = _catalogItems.length - availableCount;
    final categories = <String, int>{};

    for (final item in _catalogItems) {
      final raw = item.category.trim();
      final category = raw.isEmpty ? 'Без категории' : raw;
      categories[category] = (categories[category] ?? 0) + 1;
    }

    if (_catalogCategory != '__all__' &&
        !categories.containsKey(_catalogCategory)) {
      _catalogCategory = '__all__';
    }

    final query = _catalogQuery.trim().toLowerCase();
    final visibleItems = _catalogItems.where((item) {
      final rawCategory = item.category.trim();
      final category = rawCategory.isEmpty ? 'Без категории' : rawCategory;
      final categoryOk =
          _catalogCategory == '__all__' || category == _catalogCategory;
      final queryOk = query.isEmpty || item.name.toLowerCase().contains(query);
      return categoryOk && queryOk;
    }).toList();

    return [
      _availabilityHero(availableCount: availableCount, stopCount: stopCount),
      const SizedBox(height: 14),
      _availabilityCategoryBar(categories),
      const SizedBox(height: 10),
      _availabilitySearch(),
      if (_catalogError != null) _availabilityErrorCard(compact: true),
      Padding(
        padding: const EdgeInsets.fromLTRB(3, 18, 3, 9),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _catalogCategory == '__all__'
                    ? 'Все позиции'
                    : _catalogCategory,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 17.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.35,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.64),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withOpacity(0.84)),
              ),
              child: Text(
                '${visibleItems.length}',
                style: const TextStyle(
                  color: _soft,
                  fontSize: 10.8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
      if (visibleItems.isEmpty)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 34),
          alignment: Alignment.center,
          child: const Text(
            'Ничего не найдено',
            style: TextStyle(
              color: _soft,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        )
      else ...[
        for (int i = 0; i < visibleItems.length; i++)
          _fadeIn(
            delay: i.clamp(0, 5) * 30,
            child: _availabilityItemCard(visibleItems[i]),
          ),
      ],
      const SizedBox(height: 18),
    ];
  }

  Widget _availabilityCategoryBar(Map<String, int> categories) {
    Widget chip({
      required String key,
      required String label,
      required int count,
    }) {
      final selected = _catalogCategory == key;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _catalogCategory = key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF20C9C5), Color(0xFF0BAEBB)],
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.86),
                        Colors.white.withOpacity(0.58),
                      ],
                    ),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: selected
                    ? _mint.withOpacity(0.25)
                    : Colors.white.withOpacity(0.90),
              ),
              boxShadow: [
                BoxShadow(
                  color: selected
                      ? _mint.withOpacity(0.18)
                      : _deep.withOpacity(0.045),
                  blurRadius: selected ? 18 : 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : _ink,
                    fontSize: 12.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withOpacity(0.20)
                        : _mint.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: selected ? Colors.white : _mint,
                      fontSize: 9.7,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final chips = <Widget>[
      chip(key: '__all__', label: 'Все', count: _catalogItems.length),
    ];

    for (final entry in categories.entries) {
      chips.add(chip(key: entry.key, label: entry.key, count: entry.value));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(children: chips),
    );
  }

  Widget _availabilitySearch() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.58),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.86)),
            boxShadow: [
              BoxShadow(
                color: _deep.withOpacity(0.035),
                blurRadius: 13,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: TextField(
            onChanged: (value) => setState(() => _catalogQuery = value),
            decoration: const InputDecoration(
              hintText: 'Поиск по позициям',
              hintStyle: TextStyle(
                color: Color(0xFF8AA2B1),
                fontSize: 11.8,
                fontWeight: FontWeight.w700,
              ),
              prefixIcon: Icon(CupertinoIcons.search, color: _soft, size: 18),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 13),
            ),
            style: const TextStyle(
              color: _ink,
              fontSize: 12.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _availabilityHero({
    required int availableCount,
    required int stopCount,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        return _glassSurface(
          radius: 30,
          glow: _mint,
          glowStrength: 0.065,
          padding: const EdgeInsets.fromLTRB(19, 19, 19, 17),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -42,
                top: -55,
                child: _ambientOrb(size: 190, color: _mintLight, opacity: 0.92),
              ),
              if (!compact) ...[
                Positioned(right: 25, top: 15, child: _decorativeCube(_mint)),
                Positioned(
                  right: 94,
                  top: 8,
                  child: _ambientOrb(size: 42, color: const Color(0xFF80DFFF)),
                ),
                Positioned(
                  right: 106,
                  top: 80,
                  child: _ambientOrb(size: 28, color: _mintLight),
                ),
              ],
              Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF2DD6D0),
                              Color(0xFF0BAEBB),
                              Color(0xFF087D96),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(19),
                          boxShadow: [
                            BoxShadow(
                              color: _mint.withOpacity(0.24),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          CupertinoIcons.slider_horizontal_3,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: compact ? 0 : 105),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Наличие',
                                style: TextStyle(
                                  color: _ink,
                                  fontSize: 23,
                                  height: 1,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.58,
                                ),
                              ),
                              SizedBox(height: 7),
                              Text(
                                'Управляйте доступностью позиций для предзаказов',
                                style: TextStyle(
                                  color: _soft,
                                  fontSize: 12,
                                  height: 1.32,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (compact)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _green.withOpacity(0.085),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 7,
                                height: 7,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: _green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Синхр.',
                                style: TextStyle(
                                  color: _green,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _availabilityStat(
                          value: '$availableCount',
                          label: 'В наличии',
                          color: _green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _availabilityStat(
                          value: '$stopCount',
                          label: 'В стопе',
                          color: _red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.56),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white.withOpacity(0.78)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          CupertinoIcons.arrow_2_circlepath,
                          size: 15,
                          color: _mint,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Изменения сразу сохраняются в Flowru',
                            style: TextStyle(
                              color: _soft,
                              fontSize: 10.7,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _availabilityStat({
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.13),
            color.withOpacity(0.050),
            Colors.white.withOpacity(0.58),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.78)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.075),
            blurRadius: 17,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          _softIconTile(
            icon: color == _green
                ? Icons.inventory_2_rounded
                : Icons.block_rounded,
            color: color,
            size: 36,
          ),
          const SizedBox(width: 9),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 23,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.45,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _soft,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _availabilityItemCard(_StaffCatalogItem item) {
    final updating = _catalogUpdatingIds.contains(item.id);
    final available = item.isAvailable;
    final stateColor = available ? _green : _red;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(13, 11, 11, 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: available
              ? [
                  Colors.white.withOpacity(0.94),
                  const Color(0xFFF8FDFD).withOpacity(0.88),
                ]
              : [
                  const Color(0xFFFFFBFA).withOpacity(0.96),
                  const Color(0xFFFFF0EE).withOpacity(0.88),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: available
              ? Colors.white.withOpacity(0.94)
              : _red.withOpacity(0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: available
                ? _deep.withOpacity(0.055)
                : _red.withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  stateColor.withOpacity(0.17),
                  Colors.white.withOpacity(0.78),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.88)),
              boxShadow: [
                BoxShadow(
                  color: stateColor.withOpacity(0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: updating
                  ? CupertinoActivityIndicator(radius: 7.5, color: stateColor)
                  : Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: stateColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: stateColor.withOpacity(0.34),
                            blurRadius: 9,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: available ? _ink : _ink.withOpacity(0.67),
                    fontSize: 14.1,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.20,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: stateColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      available ? 'В наличии' : 'Стоп-лист',
                      style: TextStyle(
                        color: stateColor,
                        fontSize: 10.4,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.76),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: _deep.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Transform.scale(
              scale: 0.87,
              child: CupertinoSwitch(
                value: available,
                activeTrackColor: _mint,
                onChanged: updating
                    ? null
                    : (value) => _setCatalogAvailability(item, value),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _availabilityErrorCard({bool compact = false}) {
    final message =
        _catalogError ??
        '\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u0437\u0430\u0433\u0440\u0443\u0437\u0438\u0442\u044c \u0434\u0430\u043d\u043d\u044b\u0435';

    return Container(
      margin: EdgeInsets.only(top: compact ? 11 : 22, bottom: compact ? 0 : 8),
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      decoration: BoxDecoration(
        color: _red.withOpacity(0.065),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _red.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.exclamationmark_circle_fill,
            color: _red.withOpacity(0.92),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _soft,
                fontSize: 11.8,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: '\u041f\u043e\u0432\u0442\u043e\u0440\u0438\u0442\u044c',
            onPressed: _catalogLoading ? null : _loadCatalog,
            icon: const Icon(CupertinoIcons.refresh, size: 17, color: _mint),
          ),
        ],
      ),
    );
  }

  Widget _availabilityEmptyCard() {
    return _glassSurface(
      radius: 25,
      glow: _mint,
      glowStrength: 0.03,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 23),
      child: const Column(
        children: [
          Icon(CupertinoIcons.square_list, color: _mint, size: 28),
          SizedBox(height: 11),
          Text(
            'Каталог пуст',
            style: TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Позиции добавляются в админке Flowru',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _soft,
              fontSize: 11.7,
              height: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final newItems = _activeItems.where((e) => e.status == 'new').toList();
    final workItems = _activeItems.where((e) => e.status == 'in_work').toList();
    final readyItems = _activeItems.where((e) => e.status == 'ready').toList();
    final doneItems = _doneItems.take(8).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF3FBFC),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF8FDFD),
                    Color(0xFFEFF9FB),
                    Color(0xFFF4FCFB),
                  ],
                  stops: [0, 0.52, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: -150,
            right: -110,
            child: _ambientOrb(size: 390, color: const Color(0xFF72E6E0)),
          ),
          Positioned(
            top: 220,
            left: -190,
            child: _ambientOrb(size: 450, color: const Color(0xFFBDD7FF)),
          ),
          Positioned(
            bottom: -180,
            right: -130,
            child: _ambientOrb(size: 420, color: const Color(0xFFA8F2D8)),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 7),
                      child: Row(
                        children: [
                          _glassHeaderButton(
                            icon: CupertinoIcons.back,
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                          const SizedBox(width: 13),
                          const Expanded(
                            child: Text(
                              'Предзаказы',
                              style: TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.70,
                                fontSize: 25,
                              ),
                            ),
                          ),
                          _glassHeaderButton(
                            icon: CupertinoIcons.refresh_bold,
                            onPressed: _preorderSection == 0
                                ? _load
                                : _loadCatalog,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: (_preorderSection == 0 && _loading)
                          ? const Center(
                              child: CupertinoActivityIndicator(radius: 16),
                            )
                          : RefreshIndicator(
                              onRefresh: _preorderSection == 0
                                  ? _load
                                  : _loadCatalog,
                              color: _mint,
                              backgroundColor: Colors.white,
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  13,
                                  18,
                                  42,
                                ),
                                children: [
                                  _preorderSectionSwitcher(),
                                  const SizedBox(height: 16),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 380),
                                    switchInCurve: Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeInCubic,
                                    transitionBuilder: (child, animation) {
                                      final slide = Tween<Offset>(
                                        begin: const Offset(0.025, 0.018),
                                        end: Offset.zero,
                                      ).animate(animation);
                                      return FadeTransition(
                                        opacity: animation,
                                        child: SlideTransition(
                                          position: slide,
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: _preorderSection == 0
                                        ? Column(
                                            key: const ValueKey('orders-v4'),
                                            children: [
                                              _heroCard(),
                                              _errorBanner(),
                                              if (_activeItems.isEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 15,
                                                      ),
                                                  child: _emptyState(),
                                                )
                                              else ...[
                                                _flowSection(
                                                  title: 'Новые',
                                                  subtitle:
                                                      'Нужно принять решение',
                                                  color: const Color(
                                                    0xFFFF5364,
                                                  ),
                                                  icon:
                                                      CupertinoIcons.bell_fill,
                                                  items: newItems,
                                                ),
                                                _flowSection(
                                                  title: 'Готовятся',
                                                  subtitle:
                                                      'Следим за временем выдачи',
                                                  color: _orange,
                                                  icon:
                                                      CupertinoIcons.flame_fill,
                                                  items: workItems,
                                                ),
                                                _flowSection(
                                                  title: 'Готовы к выдаче',
                                                  subtitle:
                                                      'Можно встречать клиента',
                                                  color: _green,
                                                  icon: CupertinoIcons
                                                      .checkmark_seal_fill,
                                                  items: readyItems,
                                                ),
                                              ],
                                              if (doneItems.isNotEmpty) ...[
                                                const SizedBox(height: 18),
                                                _glassSurface(
                                                  flat: true,
                                                  radius: 25,
                                                  glow: _blue,
                                                  glowStrength: 0.02,
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                        15,
                                                        14,
                                                        15,
                                                        8,
                                                      ),
                                                  child: Column(
                                                    children: [
                                                      Row(
                                                        children: [
                                                          const Expanded(
                                                            child: Text(
                                                              'Недавние заказы',
                                                              style: TextStyle(
                                                                color: _ink,
                                                                fontSize: 16.5,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900,
                                                                letterSpacing:
                                                                    -0.25,
                                                              ),
                                                            ),
                                                          ),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 9,
                                                                  vertical: 6,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: Colors
                                                                  .white
                                                                  .withOpacity(
                                                                    0.68,
                                                                  ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    999,
                                                                  ),
                                                            ),
                                                            child: Text(
                                                              '${doneItems.length}',
                                                              style: const TextStyle(
                                                                color: _soft,
                                                                fontSize: 10.5,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(
                                                        height: 10,
                                                      ),
                                                      ...doneItems.map(
                                                        _doneRow,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          )
                                        : Column(
                                            key: const ValueKey(
                                              'availability-v4',
                                            ),
                                            children: _availabilityContent(),
                                          ),
                                  ),
                                ],
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

  Widget _glassHeaderButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.60),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.86)),
            boxShadow: [
              BoxShadow(
                color: _deep.withOpacity(0.045),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: onPressed,
            icon: Icon(icon, size: 21, color: _ink),
          ),
        ),
      ),
    );
  }
}

class _StaffCatalogItem {
  final int id;
  final int? categoryId;
  final String category;
  final String name;
  bool isAvailable;

  _StaffCatalogItem({
    required this.id,
    required this.categoryId,
    required this.category,
    required this.name,
    required this.isAvailable,
  });

  factory _StaffCatalogItem.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      return int.tryParse(value.toString());
    }

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;

      final normalized = value?.toString().trim().toLowerCase();

      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }

    return _StaffCatalogItem(
      id: parseInt(json['id']) ?? 0,
      categoryId: parseInt(json['category_id']),
      category: json['category']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      isAvailable: parseBool(json['is_available']),
    );
  }
}

class _PreorderItem {
  final int id;
  final int establishmentId;
  final int? clientId;

  // FLOWRU_PREORDER_STAFF_SPEND_V2
  final int? clientPoints;

  final String clientName;
  final String clientPhone;
  final String orderText;
  final String pickupType;
  final int? pickupMinutes;
  final String status;
  final String paymentMethod;
  final String createdAt;
  final String? pickupAt;
  final double? amountTotal;
  final double? bonusAccrued;

  _PreorderItem({
    required this.id,
    required this.establishmentId,
    required this.clientId,
    required this.clientPoints,
    required this.clientName,
    required this.clientPhone,
    required this.orderText,
    required this.pickupType,
    required this.pickupMinutes,
    required this.status,
    required this.paymentMethod,
    required this.createdAt,
    required this.pickupAt,
    required this.amountTotal,
    required this.bonusAccrued,
  });

  factory _PreorderItem.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString().replaceAll(',', '.'));
    }

    return _PreorderItem(
      id: parseInt(json['id']) ?? 0,
      establishmentId: parseInt(json['establishment_id']) ?? 0,
      clientId: parseInt(json['client_id']),
      clientPoints: parseInt(json['client_points']),
      clientName: json['client_name']?.toString() ?? '',
      clientPhone: json['client_phone']?.toString() ?? '',
      orderText: json['order_text']?.toString() ?? '',
      pickupType: json['pickup_type']?.toString() ?? 'in_minutes',
      pickupMinutes: parseInt(json['pickup_minutes']),
      status: json['status']?.toString() ?? 'new',
      paymentMethod: json['payment_method']?.toString() ?? 'unknown',
      createdAt: json['created_at']?.toString() ?? '',
      pickupAt: json['pickup_at']?.toString(),
      amountTotal: parseDouble(json['amount_total']),
      bonusAccrued: parseDouble(json['bonus_accrued']),
    );
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';

    try {
      final dt = DateTime.parse(raw).toLocal();
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    } catch (_) {
      return raw;
    }
  }

  String get doneCompactTitle {
    final order = orderText.trim().isEmpty
        ? 'Заказ без описания'
        : orderText.trim();
    final name = clientName.trim();

    if (status == 'expired') {
      if (name.isEmpty) return 'Пропущен: $order';
      return 'Пропущен: $name  $order';
    }

    if (name.isEmpty) return order;

    return 'Заказал: $name  $order';
  }

  String get paymentLabel {
    switch (paymentMethod) {
      case 'card':
        return 'Оплата картой';
      case 'cash':
        return 'Наличными';
      default:
        return 'Оплата не указана';
    }
  }

  IconData get paymentIcon {
    switch (paymentMethod) {
      case 'card':
        return Icons.credit_card_rounded;
      case 'cash':
        return Icons.payments_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String get createdLabel => _formatTime(createdAt);

  String get pickupLabel {
    final exact = _formatTime(pickupAt);
    if (exact != '') return exact;

    if (pickupType == 'asap') return 'как можно скорее';
    if (pickupType == 'at_time') return 'к выбранному времени';

    final minutes = pickupMinutes ?? 0;
    if (minutes <= 0) return 'как можно скорее';
    return 'через $minutes мин.';
  }
}
