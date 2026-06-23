import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../auth/data/auth_storage.dart';
import '../../../auth/data/user_api.dart';
import '../../../../core/config/app_config.dart';

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

class StaffAppointmentsScreen extends StatefulWidget {
  final int establishmentId;
  final String establishmentName;

  const StaffAppointmentsScreen({
    super.key,
    required this.establishmentId,
    required this.establishmentName,
  });

  @override
  State<StaffAppointmentsScreen> createState() =>
      _StaffAppointmentsScreenState();
}

class _StaffAppointmentsScreenState extends State<StaffAppointmentsScreen> {
  bool _loading = true;
  bool _updating = false;
  String? _error;

  DateTime _selectedDate = DateTime.now();
  List<_AppointmentItem> _items = [];
  List<_AppointmentService> _services = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<String> _token() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Сессия истекла. Войдите заново.');
    }
    return token.trim();
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

  Future<http.Response> _getWithRefresh(Uri uri) async {
    var response = await http.get(uri, headers: await _headers());

    if (response.statusCode == 401 || response.statusCode == 403) {
      response = await http.get(
        uri,
        headers: await _headers(forceRefresh: true),
      );
    }

    return response;
  }

  Future<http.Response> _postWithRefresh(
    Uri uri, {
    required Map<String, dynamic> body,
  }) async {
    var response = await http.post(
      uri,
      headers: await _headers(json: true),
      body: jsonEncode(body),
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      response = await http.post(
        uri,
        headers: await _headers(json: true, forceRefresh: true),
        body: jsonEncode(body),
      );
    }

    return response;
  }

  Future<http.Response> _patchWithRefresh(
    Uri uri, {
    required Map<String, dynamic> body,
  }) async {
    var response = await http.patch(
      uri,
      headers: await _headers(json: true),
      body: jsonEncode(body),
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      response = await http.patch(
        uri,
        headers: await _headers(json: true, forceRefresh: true),
        body: jsonEncode(body),
      );
    }

    return response;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final servicesResponse = await _getWithRefresh(
        Uri.parse(
          '${AppConfig.baseUrl}/api/v1/staff/appointment-services?establishment_id=${widget.establishmentId}',
        ),
      );

      if (servicesResponse.statusCode != 200) {
        throw Exception(
          _statusErrorMessage(
            servicesResponse.statusCode,
            servicesResponse.body,
          ),
        );
      }

      final appointmentsResponse = await _getWithRefresh(
        Uri.parse(
          '${AppConfig.baseUrl}/api/v1/staff/appointments?establishment_id=${widget.establishmentId}&date=${_dateApi(_selectedDate)}',
        ),
      );

      if (appointmentsResponse.statusCode != 200) {
        throw Exception(
          _statusErrorMessage(
            appointmentsResponse.statusCode,
            appointmentsResponse.body,
          ),
        );
      }

      final servicesDecoded =
          jsonDecode(servicesResponse.body) as Map<String, dynamic>;
      final appointmentsDecoded =
          jsonDecode(appointmentsResponse.body) as Map<String, dynamic>;

      final rawServices = (servicesDecoded['items'] as List?) ?? const [];
      final rawItems = (appointmentsDecoded['items'] as List?) ?? const [];

      if (!mounted) return;

      setState(() {
        _services = rawServices
            .map(
              (e) => _AppointmentService.fromJson(
                (e as Map).cast<String, dynamic>(),
              ),
            )
            .where((service) => service.id > 0)
            .toList();

        _items =
            rawItems
                .map(
                  (e) => _AppointmentItem.fromJson(
                    (e as Map).cast<String, dynamic>(),
                  ),
                )
                .toList()
              ..sort((a, b) {
                final ad = a.appointmentAt;
                final bd = b.appointmentAt;
                if (ad == null && bd == null) return a.id.compareTo(b.id);
                if (ad == null) return 1;
                if (bd == null) return -1;
                return ad.compareTo(bd);
              });

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '').trim();
        _loading = false;
      });
    }
  }

  String _statusErrorMessage(int statusCode, String body) {
    if (statusCode == 401 || statusCode == 403) {
      return 'Сессия истекла. Войдите заново.';
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final detail =
            decoded['detail'] ?? decoded['message'] ?? decoded['error'];
        final message = detail?.toString().trim() ?? '';
        if (message.isNotEmpty) return message;
      }
    } catch (_) {}

    if (statusCode == 409) {
      return 'Это время уже занято. Выберите другое время.';
    }

    return 'Не удалось выполнить действие';
  }

  Future<void> _changeStatus(_AppointmentItem item, String status) async {
    if (_updating) return;

    setState(() {
      _updating = true;
      _error = null;
    });

    try {
      final response = await _patchWithRefresh(
        Uri.parse(
          '${AppConfig.baseUrl}/api/v1/staff/appointments/${item.id}/status',
        ),
        body: {'establishment_id': widget.establishmentId, 'status': status},
      );

      if (response.statusCode != 200) {
        throw Exception(
          _statusErrorMessage(response.statusCode, response.body),
        );
      }

      await _load();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _updating = false;
        });
      }
    }
  }

  Future<void> _showOfflineDialog() async {
    if (_services.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала добавьте услуги записи в админке.'),
        ),
      );
      return;
    }

    final result = await showModalBottomSheet<_OfflineAppointmentDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _OfflineAppointmentSheet(
          services: _services,
          initialDate: _selectedDate,
        );
      },
    );

    if (result == null) return;

    await _createOfflineAppointment(result);
  }

  Future<void> _createOfflineAppointment(_OfflineAppointmentDraft draft) async {
    setState(() {
      _updating = true;
      _error = null;
    });

    try {
      final response = await _postWithRefresh(
        Uri.parse('${AppConfig.baseUrl}/api/v1/staff/appointments/offline'),
        body: {
          'establishment_id': widget.establishmentId,
          'service_id': draft.service.id,
          'client_name': draft.clientName,
          'client_phone': draft.clientPhone,
          'appointment_at': draft.appointmentAt.toIso8601String(),
          'comment': draft.comment,
        },
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          _statusErrorMessage(response.statusCode, response.body),
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Офлайн-запись добавлена')));

      _selectedDate = DateTime(
        draft.appointmentAt.year,
        draft.appointmentAt.month,
        draft.appointmentAt.day,
      );

      await _load();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '').trim();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_error ?? 'Не удалось добавить запись')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updating = false;
        });
      }
    }
  }

  String _dateApi(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = DateTime(date.year, date.month, date.day);
    final diff = current.difference(today).inDays;

    if (diff == 0) return 'Сегодня';
    if (diff == 1) return 'Завтра';

    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d.$m';
  }

  String _timeLabel(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _statusText(String status) {
    switch (status) {
      case 'new':
        return 'Новая';
      case 'confirmed':
        return 'Подтверждена';
      case 'completed':
        return 'Завершена';
      case 'cancelled':
        return 'Отменена';
      case 'no_show':
        return 'Не пришёл';
      default:
        return status.isEmpty ? 'Запись' : status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'new':
        return _orange;
      case 'confirmed':
        return _blue;
      case 'completed':
        return _green;
      case 'cancelled':
      case 'no_show':
        return _red;
      default:
        return _soft;
    }
  }

  List<DateTime> _dateTabs() {
    final now = DateTime.now();
    return List<DateTime>.generate(10, (index) {
      return DateTime(now.year, now.month, now.day + index);
    });
  }

  Widget _surface({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(18),
    double radius = 28,
    Color? color,
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white.withOpacity(0.86),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(0.70)),
        boxShadow: [
          BoxShadow(
            color: _deep.withOpacity(0.10),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(CupertinoIcons.chevron_left),
            color: _ink,
          ),
          const Expanded(
            child: Text(
              'Записи',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ink,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
          ),
          IconButton(
            onPressed: _load,
            icon: const Icon(CupertinoIcons.refresh),
            color: _ink,
          ),
        ],
      ),
    );
  }

  Widget _hero() {
    final active = _items
        .where((item) => item.status != 'cancelled' && item.status != 'no_show')
        .length;

    return _surface(
      color: Colors.white.withOpacity(0.72),
      radius: 32,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [_deep, _mint],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(
              CupertinoIcons.calendar,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.establishmentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  active > 0
                      ? '$active активных записей на день'
                      : 'На выбранный день активных записей нет',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _soft,
                    fontSize: 13.2,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateSelector() {
    final dates = _dateTabs();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (int i = 0; i < dates.length; i++) ...[
            _dateChip(dates[i]),
            if (i != dates.length - 1) const SizedBox(width: 9),
          ],
        ],
      ),
    );
  }

  Widget _dateChip(DateTime date) {
    final selected = _dateApi(date) == _dateApi(_selectedDate);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDate = date;
        });
        _load();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [_deep, _mint])
              : null,
          color: selected ? null : Colors.white.withOpacity(0.78),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? Colors.white.withOpacity(0.40) : _stroke,
          ),
        ),
        child: Text(
          _dateLabel(date),
          style: TextStyle(
            color: selected ? Colors.white : _ink,
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _errorBox() {
    final text = _error?.trim() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _red.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _red.withOpacity(0.20)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _red,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _appointmentsList() {
    if (_items.isEmpty) {
      return _surface(
        radius: 30,
        color: Colors.white.withOpacity(0.80),
        child: const Column(
          children: [
            Icon(CupertinoIcons.calendar_badge_plus, size: 44, color: _soft),
            SizedBox(height: 12),
            Text(
              'Записей пока нет',
              style: TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Клиенты смогут записываться онлайн, а сотрудники  добавлять офлайн-записи вручную.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _soft,
                fontSize: 13,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < _items.length; i++) ...[
          _appointmentCard(_items[i]),
          if (i != _items.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _appointmentCard(_AppointmentItem item) {
    final color = _statusColor(item.status);
    final serviceTitle = item.serviceTitle.isEmpty
        ? 'Услуга'
        : item.serviceTitle;

    return _surface(
      radius: 28,
      color: Colors.white.withOpacity(0.88),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  CupertinoIcons.calendar_today,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_timeLabel(item.appointmentAt)}  ${item.durationMinutes} мин',
                      style: const TextStyle(
                        color: _soft,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusText(item.status),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.clientName.isEmpty ? 'Клиент без имени' : item.clientName,
            style: const TextStyle(
              color: _ink,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (item.clientPhone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.clientPhone,
              style: const TextStyle(
                color: _soft,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (item.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              item.comment,
              style: const TextStyle(
                color: _soft,
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          _statusActions(item),
        ],
      ),
    );
  }

  Widget _statusActions(_AppointmentItem item) {
    final actions = <Widget>[];

    if (item.status == 'new') {
      actions.add(
        _actionButton(
          label: 'Подтвердить',
          color: _blue,
          onTap: () => _changeStatus(item, 'confirmed'),
        ),
      );
    }

    if (item.status == 'new' || item.status == 'confirmed') {
      actions.add(
        _actionButton(
          label: 'Завершить',
          color: _green,
          onTap: () => _changeStatus(item, 'completed'),
        ),
      );
      actions.add(
        _actionButton(
          label: 'Отмена',
          color: _red,
          onTap: () => _changeStatus(item, 'cancelled'),
        ),
      );
    }

    if (actions.isEmpty) {
      return const Text(
        'Запись закрыта',
        style: TextStyle(
          color: _soft,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: actions);
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _updating ? null : onTap,
      child: Opacity(
        opacity: _updating ? 0.55 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.20)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _addOfflineButton() {
    return GestureDetector(
      onTap: _updating ? null : _showOfflineDialog,
      child: Opacity(
        opacity: _updating ? 0.55 : 1,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [_deep, _mint],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _deep.withOpacity(0.20),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.plus_circle_fill, color: Colors.white),
              SizedBox(width: 9),
              Text(
                'Добавить офлайн-запись',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loader() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation(_deep),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_mint, _mintLight, _bg],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: _loading
                ? _loader()
                : RefreshIndicator(
                    color: _deep,
                    backgroundColor: Colors.white,
                    onRefresh: _load,
                    child: ListView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                      children: [
                        _topBar(),
                        _hero(),
                        const SizedBox(height: 14),
                        _dateSelector(),
                        const SizedBox(height: 14),
                        _errorBox(),
                        if (_error != null) const SizedBox(height: 14),
                        _addOfflineButton(),
                        const SizedBox(height: 16),
                        _appointmentsList(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _OfflineAppointmentSheet extends StatefulWidget {
  final List<_AppointmentService> services;
  final DateTime initialDate;

  const _OfflineAppointmentSheet({
    required this.services,
    required this.initialDate,
  });

  @override
  State<_OfflineAppointmentSheet> createState() =>
      _OfflineAppointmentSheetState();
}

class _OfflineAppointmentSheetState extends State<_OfflineAppointmentSheet> {
  late _AppointmentService _service;
  late DateTime _date;
  TimeOfDay _time = const TimeOfDay(hour: 12, minute: 0);

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _service = widget.services.first;
    _date = widget.initialDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  String _dateText(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d.$m.${date.year}';
  }

  DateTime get _appointmentAt {
    return DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
    );

    if (picked == null) return;

    setState(() {
      _date = picked;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);

    if (picked == null) return;

    setState(() {
      _time = picked;
    });
  }

  void _submit() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Введите имя клиента')));
      return;
    }

    if (phone.length < 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Введите телефон клиента')));
      return;
    }

    Navigator.of(context).pop(
      _OfflineAppointmentDraft(
        service: _service,
        clientName: name,
        clientPhone: phone,
        comment: _commentController.text.trim(),
        appointmentAt: _appointmentAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: SizedBox(
                    width: 46,
                    height: 5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _stroke,
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Офлайн-запись',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  value: _service.id,
                  decoration: _inputDecoration('Услуга'),
                  items: [
                    for (final service in widget.services)
                      DropdownMenuItem(
                        value: service.id,
                        child: Text(service.title),
                      ),
                  ],
                  onChanged: (value) {
                    final selected = widget.services.firstWhere(
                      (service) => service.id == value,
                      orElse: () => widget.services.first,
                    );

                    setState(() {
                      _service = selected;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _pickButton(
                        label: _dateText(_date),
                        icon: CupertinoIcons.calendar,
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _pickButton(
                        label:
                            '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                        icon: CupertinoIcons.clock,
                        onTap: _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: _inputDecoration('Имя клиента'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  decoration: _inputDecoration('Телефон клиента'),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _commentController,
                  decoration: _inputDecoration('Комментарий'),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: _submit,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(colors: [_deep, _mint]),
                    ),
                    child: const Text(
                      'Добавить запись',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white.withOpacity(0.84),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _stroke),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _stroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _mint, width: 1.4),
      ),
    );
  }

  Widget _pickButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.84),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _stroke),
        ),
        child: Row(
          children: [
            Icon(icon, color: _deep, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineAppointmentDraft {
  final _AppointmentService service;
  final String clientName;
  final String clientPhone;
  final String comment;
  final DateTime appointmentAt;

  const _OfflineAppointmentDraft({
    required this.service,
    required this.clientName,
    required this.clientPhone,
    required this.comment,
    required this.appointmentAt,
  });
}

class _AppointmentService {
  final int id;
  final String title;
  final int durationMinutes;
  final double price;

  const _AppointmentService({
    required this.id,
    required this.title,
    required this.durationMinutes,
    required this.price,
  });

  factory _AppointmentService.fromJson(Map<String, dynamic> json) {
    return _AppointmentService(
      id: _parseInt(json['id']) ?? 0,
      title: (json['title'] ?? 'Услуга').toString(),
      durationMinutes: _parseInt(json['duration_minutes']) ?? 60,
      price: _parseDouble(json['price']) ?? 0,
    );
  }
}

class _AppointmentItem {
  final int id;
  final int establishmentId;
  final int serviceId;
  final String serviceTitle;
  final String clientName;
  final String clientPhone;
  final String status;
  final String comment;
  final int durationMinutes;
  final DateTime? appointmentAt;

  const _AppointmentItem({
    required this.id,
    required this.establishmentId,
    required this.serviceId,
    required this.serviceTitle,
    required this.clientName,
    required this.clientPhone,
    required this.status,
    required this.comment,
    required this.durationMinutes,
    required this.appointmentAt,
  });

  factory _AppointmentItem.fromJson(Map<String, dynamic> json) {
    return _AppointmentItem(
      id: _parseInt(json['id']) ?? 0,
      establishmentId: _parseInt(json['establishment_id']) ?? 0,
      serviceId: _parseInt(json['service_id']) ?? 0,
      serviceTitle:
          (json['service_title'] ?? json['service_name'] ?? json['title'] ?? '')
              .toString(),
      clientName: (json['client_name'] ?? '').toString(),
      clientPhone: (json['client_phone'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      comment: (json['comment'] ?? '').toString(),
      durationMinutes: _parseInt(json['duration_minutes']) ?? 60,
      appointmentAt: _parseDateTime(json['appointment_at']),
    );
  }
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.'));
}

DateTime? _parseDateTime(dynamic value) {
  final text = (value ?? '').toString().trim();
  if (text.isEmpty) return null;

  try {
    return DateTime.parse(text).toLocal();
  } catch (_) {
    return null;
  }
}
