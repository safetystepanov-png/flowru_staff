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
  bool _softLoading = false;
  Map<String, int> _dateCounts = <String, int>{};
  String _selectedSpecialist = 'all';

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

  Future<void> _load({bool soft = false}) async {
    setState(() {
      if (soft) {
        _softLoading = true;
      } else {
        _loading = true;
      }
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
        _softLoading = false;
      });

      await _loadDateCounts();
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

  bool _isVisibleDayAppointment(_AppointmentItem item) {
    return item.status != 'cancelled' &&
        item.status != 'no_show' &&
        item.status != 'cancelled_by_client';
  }

  int get _dayCount => _items.where(_isVisibleDayAppointment).length;

  bool _isActiveAppointment(_AppointmentItem item) {
    return item.status == 'new' || item.status == 'confirmed';
  }

  int get _activeCount => _items.where(_isActiveAppointment).length;

  int get _newCount => _items.where((item) => item.status == 'new').length;

  int get _confirmedCount =>
      _items.where((item) => item.status == 'confirmed').length;

  String _weekdayShort(DateTime date) {
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return days[date.weekday - 1];
  }

  String _dayMonth(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d.$m';
  }

  DateTime _dayAt(DateTime date, int hour, int minute) {
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  String _timeRangeLabel(DateTime? start, int durationMinutes) {
    if (start == null) return 'Время не указано';

    final end = start.add(Duration(minutes: durationMinutes));
    final sh = start.hour.toString().padLeft(2, '0');
    final sm = start.minute.toString().padLeft(2, '0');
    final eh = end.hour.toString().padLeft(2, '0');
    final em = end.minute.toString().padLeft(2, '0');

    return '$sh:$sm - $eh:$em';
  }

  String _nextFreeWindowText() {
    final minDuration = _services.isEmpty
        ? 30
        : _services
              .map((service) => service.durationMinutes)
              .where((minutes) => minutes > 0)
              .fold<int>(9999, (prev, value) => value < prev ? value : prev);

    final dayStart = _dayAt(_selectedDate, 10, 0);
    final dayEnd = _dayAt(_selectedDate, 20, 0);

    final busy =
        _items
            .where(_isActiveAppointment)
            .where((item) => item.appointmentAt != null)
            .map((item) {
              final start = item.appointmentAt!;
              final end = start.add(Duration(minutes: item.durationMinutes));
              return MapEntry(start, end);
            })
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));

    DateTime cursor = dayStart;

    for (final interval in busy) {
      final busyStart = interval.key;
      final busyEnd = interval.value;

      if (busyEnd.isBefore(dayStart) || busyEnd.isAtSameMomentAs(dayStart)) {
        continue;
      }

      if (busyStart.isAfter(dayEnd) || busyStart.isAtSameMomentAs(dayEnd)) {
        break;
      }

      final freeEnd = busyStart.isBefore(dayEnd) ? busyStart : dayEnd;
      final freeMinutes = freeEnd.difference(cursor).inMinutes;

      if (freeMinutes >= minDuration) {
        return 'Ближайшее свободное окно: ${_timeRangeLabel(cursor, freeMinutes)}';
      }

      if (busyEnd.isAfter(cursor)) {
        cursor = busyEnd;
      }
    }

    final tailMinutes = dayEnd.difference(cursor).inMinutes;
    if (tailMinutes >= minDuration) {
      return 'Ближайшее свободное окно: ${_timeRangeLabel(cursor, tailMinutes)}';
    }

    return 'Свободных окон под текущие услуги на этот день нет';
  }

  Widget _summaryPill({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 9),
            Text(
              value,
              style: const TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.45,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _soft,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadDateCounts() async {
    try {
      final token = await _token();
      final result = <String, int>{};

      for (final date in _dateTabs()) {
        final dateKey = _dateApi(date);
        final response = await http.get(
          Uri.parse(
            '${AppConfig.baseUrl}/api/v1/staff/appointments?establishment_id=${widget.establishmentId}&date=$dateKey',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );

        if (response.statusCode != 200) {
          continue;
        }

        final decoded = jsonDecode(response.body);
        if (decoded is! Map) {
          continue;
        }

        final rawItems = (decoded['items'] as List?) ?? const [];
        final count = rawItems.where((raw) {
          if (raw is! Map) return false;
          final status = (raw['status'] ?? '').toString();
          return status != 'cancelled' &&
              status != 'no_show' &&
              status != 'cancelled_by_client';
        }).length;

        if (count > 0) {
          result[dateKey] = count;
        }
      }

      if (!mounted) return;
      setState(() {
        _dateCounts = result;
      });
    } catch (_) {
      // Счётчики  вспомогательная часть экрана. Если не загрузились,
      // сам календарь и список записей должны продолжать работать.
    }
  }

  List<_AppointmentItem> get _visibleItems {
    if (_selectedSpecialist == 'all') {
      return _items;
    }

    // Задел под мастеров: пока backend не отдаёт master_id,
    // все существующие записи считаем "без назначенного специалиста".
    if (_selectedSpecialist == 'unassigned') {
      return _items;
    }

    return _items;
  }

  Widget _specialistFilter() {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _specialistChip(
            label: 'Все специалисты',
            value: 'all',
            icon: CupertinoIcons.person_2_fill,
          ),
          const SizedBox(width: 9),
          _specialistChip(
            label: 'Не назначен',
            value: 'unassigned',
            icon: CupertinoIcons.person_crop_circle_badge_exclam,
          ),
        ],
      ),
    );
  }

  Widget _specialistChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final selected = _selectedSpecialist == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSpecialist = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _deep : Colors.white.withOpacity(0.74),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? _deep : _stroke),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _deep.withOpacity(0.16),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : _soft),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : _ink,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero() {
    return _surface(
      color: Colors.white.withOpacity(0.78),
      radius: 34,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_blue, _mint],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: _blue.withOpacity(0.20),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.calendar_today,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dateLabel(_selectedDate),
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.65,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${_weekdayShort(_selectedDate)}, ${_dayMonth(_selectedDate)}  рабочее окно 10:00 - 20:00',
                      style: const TextStyle(
                        color: _soft,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
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
              _summaryPill(
                label: 'записей',
                value: '$_dayCount',
                icon: CupertinoIcons.person_2_fill,
                color: _deep,
              ),
              const SizedBox(width: 10),
              _summaryPill(
                label: 'новых',
                value: '$_newCount',
                icon: CupertinoIcons.bell_fill,
                color: _orange,
              ),
              const SizedBox(width: 10),
              _summaryPill(
                label: 'подтв.',
                value: '$_confirmedCount',
                icon: CupertinoIcons.check_mark_circled_solid,
                color: _blue,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: _mint.withOpacity(0.10),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _mint.withOpacity(0.18)),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.clock, color: _deep, size: 19),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    _nextFreeWindowText(),
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_services.isEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: _orange.withOpacity(0.11),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _orange.withOpacity(0.18)),
              ),
              child: const Text(
                'Услуги записи ещё не добавлены. Добавьте услуги в админке, чтобы сотрудники могли записывать клиентов офлайн.',
                style: TextStyle(
                  color: _ink,
                  fontSize: 12.8,
                  height: 1.28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dateChip(DateTime date) {
    final selected = _dateApi(date) == _dateApi(_selectedDate);
    final count = _dateCounts[_dateApi(date)] ?? 0;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDate = DateTime(date.year, date.month, date.day);
        });
        _load(soft: true);
      },
      child: SizedBox(
        width: 58,
        height: 76,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          colors: [_deep, _mint],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: selected ? null : Colors.white.withOpacity(0.72),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: selected ? Colors.white.withOpacity(0.32) : _stroke,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: _deep.withOpacity(0.18),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _weekdayShort(date),
                      style: TextStyle(
                        color: selected
                            ? Colors.white.withOpacity(0.82)
                            : _soft,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      date.day.toString(),
                      style: TextStyle(
                        color: selected ? Colors.white : _ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (count > 0)
              Positioned(
                top: -1,
                right: 1,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 22,
                    minHeight: 22,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _orange,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: _orange.withOpacity(0.34),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dateSelector() {
    return SizedBox(
      height: 76,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
        children: [for (final date in _dateTabs()) _dateChip(date)],
      ),
    );
  }

  Widget _appointmentsList() {
    final visibleItems = _visibleItems.where(_isVisibleDayAppointment).toList();

    if (visibleItems.isEmpty) {
      return _surface(
        radius: 32,
        color: Colors.white.withOpacity(0.82),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: _mint.withOpacity(0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                CupertinoIcons.calendar_badge_plus,
                size: 34,
                color: _deep,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'На этот день записей нет',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ink,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.35,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Онлайн-записи появятся здесь автоматически. Офлайн-запись можно добавить вручную, если клиент записался в салоне.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _soft,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Записи дня',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.45,
                  ),
                ),
              ),
              Text(
                '${visibleItems.length}',
                style: const TextStyle(
                  color: _soft,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        for (int i = 0; i < visibleItems.length; i++) ...[
          _appointmentCard(visibleItems[i]),
          if (i != visibleItems.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _appointmentCard(_AppointmentItem item) {
    final color = _statusColor(item.status);
    final serviceTitle = item.serviceTitle.isEmpty
        ? 'Услуга'
        : item.serviceTitle;
    final clientName = item.clientName.trim().isEmpty
        ? 'Клиент без имени'
        : item.clientName;
    final phone = item.clientPhone.trim();
    final comment = item.comment.trim();

    return _surface(
      radius: 30,
      color: Colors.white.withOpacity(0.88),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: color.withOpacity(0.18)),
                ),
                child: Icon(CupertinoIcons.clock_fill, color: color, size: 25),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _timeRangeLabel(item.appointmentAt, item.durationMinutes),
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.55,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$serviceTitle  ${item.durationMinutes} мин',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: color.withOpacity(0.18)),
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
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _bg.withOpacity(0.88),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _stroke.withOpacity(0.9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoLine(CupertinoIcons.person_fill, clientName),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  _infoLine(CupertinoIcons.phone_fill, phone),
                ],
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  _infoLine(CupertinoIcons.chat_bubble_text_fill, comment),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _statusActions(item),
        ],
      ),
    );
  }

  Widget _infoLine(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _soft, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: _ink,
              fontSize: 13.5,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
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

  Widget _errorBox() {
    if (_error == null || _error!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return _surface(
      radius: 24,
      color: _red.withOpacity(0.10),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: _red,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                color: _ink,
                fontSize: 13,
                height: 1.30,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
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
                        if (_softLoading) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: _mint.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: _mint.withOpacity(0.16),
                              ),
                            ),
                            child: const Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CupertinoActivityIndicator(),
                                ),
                                SizedBox(width: 9),
                                Text(
                                  'Обновляем день',
                                  style: TextStyle(
                                    color: _soft,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
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
