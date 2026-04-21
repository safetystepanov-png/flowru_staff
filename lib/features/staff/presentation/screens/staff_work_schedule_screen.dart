import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/staff_published_schedule_api.dart';
import '../../data/staff_schedule_requests_api.dart';

const Color kScheduleMintTop = Color(0xFF0CB7B3);
const Color kScheduleMintMid = Color(0xFF08A9AB);
const Color kScheduleMintBottom = Color(0xFF067D87);
const Color kScheduleMintDeep = Color(0xFF055E66);

const Color kScheduleCard = Color(0xF7FFFFFF);
const Color kScheduleStroke = Color(0xFFE2EFEF);

const Color kScheduleInk = Color(0xFF103238);
const Color kScheduleInkSoft = Color(0xFF58767D);
const Color kScheduleBlue = Color(0xFF4E7CFF);
const Color kScheduleAccent = Color(0xFFFFA11D);
const Color kScheduleSuccess = Color(0xFF22C55E);
const Color kScheduleDanger = Color(0xFFEF4444);

enum _ScheduleApprovalState { none, pending, approved }

class StaffWorkScheduleScreen extends StatefulWidget {
  final int establishmentId;
  final String establishmentName;
  final String role;

  const StaffWorkScheduleScreen({
    super.key,
    required this.establishmentId,
    required this.establishmentName,
    required this.role,
  });

  @override
  State<StaffWorkScheduleScreen> createState() =>
      _StaffWorkScheduleScreenState();
}

class _StaffWorkScheduleScreenState extends State<StaffWorkScheduleScreen>
    with SingleTickerProviderStateMixin {
  final StaffScheduleRequestsApi _requestsApi = const StaffScheduleRequestsApi();
  final StaffPublishedScheduleApi _publishedApi =
      const StaffPublishedScheduleApi();

  late final AnimationController _ambientController;
  late DateTime _visibleMonth;

  bool _showOnlyMine = false;
  bool _loading = true;
  bool _monthPublished = false;
  bool _sendingDraft = false;
  bool _sendingSwap = false;

  _ScheduleApprovalState _draftState = _ScheduleApprovalState.none;
  List<int> _requestedDays = <int>[];
  Map<DateTime, List<_ShiftAssignment>> _assignments =
      <DateTime, List<_ShiftAssignment>>{};

  static const List<String> _monthNames = <String>[
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];

  static const List<String> _weekDaysShort = <String>[
    'Пн',
    'Вт',
    'Ср',
    'Чт',
    'Пт',
    'Сб',
    'Вс',
  ];

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7600),
    )..repeat();

    _loadAll();
  }

  @override
  void dispose() {
    _ambientController.dispose();
    super.dispose();
  }

  DateTime _stripTime(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isToday(DateTime d) => _isSameDay(_stripTime(DateTime.now()), d);

  List<DateTime> _calendarDays() {
    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final offset = firstDay.weekday - 1;
    final start = firstDay.subtract(Duration(days: offset));
    return List<DateTime>.generate(42, (i) => start.add(Duration(days: i)));
  }

  Set<int> _busyDaysInVisibleMonth() {
    final result = <int>{};
    _assignments.forEach((date, items) {
      if (date.year == _visibleMonth.year &&
          date.month == _visibleMonth.month &&
          items.isNotEmpty) {
        result.add(date.day);
      }
    });
    return result;
  }

  List<_ShiftAssignment> _allAssignments(DateTime date) =>
      _assignments[_stripTime(date)] ?? const <_ShiftAssignment>[];

  List<_ShiftAssignment> _visibleAssignments(DateTime date) {
    final items = _allAssignments(date);
    if (!_showOnlyMine) return items;
    return items.where((e) => e.isMine).toList();
  }

  int _myShiftsCountInMonth() {
    return _assignments.entries
        .where((entry) =>
            entry.key.year == _visibleMonth.year &&
            entry.key.month == _visibleMonth.month &&
            entry.value.any((e) => e.isMine))
        .length;
  }

  String _nextMyShiftLabel() {
    final today = _stripTime(DateTime.now());
    final monthDays = _calendarDays()
        .where((d) => d.month == _visibleMonth.month)
        .map(_stripTime)
        .toList();

    for (final day in monthDays) {
      if (day.isBefore(today)) continue;
      final mine = _allAssignments(day).where((item) => item.isMine);
      if (mine.isNotEmpty) {
        return '${day.day} ${_monthNames[day.month - 1].toLowerCase()}';
      }
    }

    return _monthPublished
        ? 'На этот месяц смен больше нет'
        : 'График на месяц ещё не опубликован';
  }

  String _draftActionLabel() {
    if (_monthPublished) {
      return 'График согласован';
    }

    return 'Заполнить график';
  }

  Future<void> _loadAll() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      await Future.wait(<Future<void>>[
        _loadDraftState(),
        _loadPublishedMonth(),
      ]);
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadDraftState() async {
    try {
      final request = await _requestsApi.getLatestMyRequest(
        establishmentId: widget.establishmentId,
        year: _visibleMonth.year,
        month: _visibleMonth.month,
      );

      if (!mounted) return;

      if (request == null) {
        setState(() {
          _requestedDays = <int>[];
          _draftState = _ScheduleApprovalState.none;
        });
        return;
      }

      setState(() {
        _requestedDays = List<int>.from(request.selectedDays)..sort();
        _draftState = request.status == 'approved'
            ? _ScheduleApprovalState.approved
            : _ScheduleApprovalState.pending;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _requestedDays = <int>[];
        _draftState = _ScheduleApprovalState.none;
      });
    }
  }

  String _normalizeDisplayName(String rawName, {required bool isMine}) {
    final value = rawName.trim();
    if (isMine) return 'Вы';
    if (value.isEmpty) return 'Сотрудник';

    final lower = value.toLowerCase();
    if (lower == 'staff user' ||
        lower == 'staff_user' ||
        lower == 'user' ||
        lower == 'employee' ||
        lower == 'сотрудник' ||
        lower == 'cashier') {
      return 'Сотрудник';
    }

    return value;
  }

  String _normalizeRole(String rawRole) {
    final value = rawRole.trim();
    if (value.isEmpty) return 'Сотрудник';

    final lower = value.toLowerCase();
    if (lower == 'cashier' ||
        lower == 'staff' ||
        lower == 'employee' ||
        lower == 'user' ||
        lower == 'staff_user' ||
        lower == 'сотрудник') {
      return 'Сотрудник';
    }

    return value;
  }

  Future<void> _loadPublishedMonth() async {
    try {
      final month = await _publishedApi.getScheduleMonth(
        establishmentId: widget.establishmentId,
        year: _visibleMonth.year,
        month: _visibleMonth.month,
      );

      final map = <DateTime, List<_ShiftAssignment>>{};

      for (final day in month.days) {
        final safeDate = _stripTime(day.date);

        final safeItems = day.items.map((person) {
          final safeName = _normalizeDisplayName(
            person.employeeName.trim(),
            isMine: person.isMine,
          );

          final rawRole = person.employeeRole?.trim() ?? '';
          final safeRole =
              rawRole.isNotEmpty ? _normalizeRole(rawRole) : 'Сотрудник';

          final rawBadge = person.employeeLabel?.trim() ?? '';
          final safeBadge = rawBadge.isNotEmpty ? rawBadge.toUpperCase() : null;

          return _ShiftAssignment(
            employeeId: person.employeeUserId.trim(),
            employeeName: safeName,
            role: safeRole,
            badge: safeBadge,
            isMine: person.isMine,
          );
        }).toList();

        map[safeDate] = safeItems;
      }

      if (!mounted) return;
      setState(() {
        _assignments = map;
        _monthPublished = month.published;
      });
    } catch (e, st) {
      debugPrint('WORK_SCHEDULE _loadPublishedMonth ERROR: $e');
      debugPrint('$st');

      if (!mounted) return;
      setState(() {
        _assignments = <DateTime, List<_ShiftAssignment>>{};
        _monthPublished = false;
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
      _assignments = <DateTime, List<_ShiftAssignment>>{};
      _monthPublished = false;
      _requestedDays = <int>[];
      _draftState = _ScheduleApprovalState.none;
    });
    _loadAll();
  }

  String _dateTitle(DateTime date) {
    return '${date.day} ${_monthNames[date.month - 1]}';
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _showSwapRequestDialog(DateTime date) async {
    if (_sendingSwap) return;

    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FCFC),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFE3F0F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Попросить замену · ${_dateTitle(date)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: kScheduleInk,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(CupertinoIcons.xmark),
                    ),
                  ],
                ),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Причина (необязательно)',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE2EFEF)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE2EFEF)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _DialogFooterButton(
                        label: 'Отмена',
                        isPrimary: false,
                        onTap: () => Navigator.of(dialogContext).pop(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DialogFooterButton(
                        label: _sendingSwap ? 'Отправка...' : 'Отправить',
                        isPrimary: true,
                        onTap: () async {
                          setState(() {
                            _sendingSwap = true;
                          });

                          try {
                            await _requestsApi.requestSwap(
                              establishmentId: widget.establishmentId,
                              shiftDate: _stripTime(date)
                                  .toIso8601String()
                                  .split('T')
                                  .first,
                              reason: controller.text.trim().isEmpty
                                  ? null
                                  : controller.text.trim(),
                            );

                            if (!mounted) return;
                            Navigator.of(dialogContext).pop();
                            _showSnack('Запрос на замену отправлен.');
                          } catch (e) {
                            _showSnack('Ошибка отправки: $e');
                          } finally {
                            if (!mounted) return;
                            setState(() {
                              _sendingSwap = false;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    controller.dispose();
  }

  Future<void> _showComposeScheduleDialog() async {
    if (_sendingDraft) return;

    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final selected = _requestedDays.toSet();
    final busyDays = _busyDaysInVisibleMonth();

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FCFC),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFE3F0F0)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Составить график · ${_monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: kScheduleInk,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(CupertinoIcons.xmark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _monthPublished
                          ? 'Можно выбрать только свободные дни без уже назначенных смен.'
                          : 'Выберите дни, в которые готовы работать в этом месяце.',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kScheduleInkSoft,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List<Widget>.generate(daysInMonth, (index) {
                            final day = index + 1;
                            final isBusy =
                                _monthPublished && busyDays.contains(day);
                            final isSelected = selected.contains(day);

                            return Opacity(
                              opacity: isBusy ? 0.42 : 1,
                              child: GestureDetector(
                                onTap: isBusy
                                    ? null
                                    : () {
                                        setLocalState(() {
                                          if (isSelected) {
                                            selected.remove(day);
                                          } else {
                                            selected.add(day);
                                          }
                                        });
                                      },
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: isSelected
                                        ? kScheduleSuccess.withOpacity(0.15)
                                        : (isBusy
                                            ? const Color(0xFFF0ECE5)
                                            : Colors.white),
                                    border: Border.all(
                                      color: isSelected
                                          ? kScheduleSuccess
                                          : (isBusy
                                              ? const Color(0xFFD7CFC0)
                                              : const Color(0xFFE2EFEF)),
                                      width: isSelected ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Text(
                                    '$day',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: isSelected
                                          ? kScheduleSuccess
                                          : (isBusy
                                              ? kScheduleInkSoft
                                              : kScheduleInk),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _DialogFooterButton(
                            label: 'Сбросить',
                            isPrimary: false,
                            onTap: () {
                              setLocalState(() {
                                selected.clear();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DialogFooterButton(
                            label: _sendingDraft ? 'Отправка...' : 'Отправить',
                            isPrimary: true,
                            onTap: () async {
                              final selectedDays = selected.toList()..sort();

                              if (selectedDays.isEmpty) {
                                _showSnack(
                                  'Выберите хотя бы один доступный день.',
                                );
                                return;
                              }

                              setState(() {
                                _sendingDraft = true;
                              });

                              try {
                                final result =
                                    await _requestsApi.submitScheduleRequest(
                                  establishmentId: widget.establishmentId,
                                  year: _visibleMonth.year,
                                  month: _visibleMonth.month,
                                  selectedDays: selectedDays,
                                );

                                if (!mounted) return;

                                setState(() {
                                  _requestedDays =
                                      List<int>.from(result.selectedDays)..sort();
                                  _draftState = result.status == 'approved'
                                      ? _ScheduleApprovalState.approved
                                      : _ScheduleApprovalState.pending;
                                });

                                Navigator.of(dialogContext).pop();
                                _showSnack('Запрос отправлен владельцу.');
                              } catch (e) {
                                _showSnack('Ошибка отправки: $e');
                              } finally {
                                if (!mounted) return;
                                setState(() {
                                  _sendingDraft = false;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showDayDetails(DateTime date) async {
    final rawItems = _allAssignments(date);
    final visibleItems = _visibleAssignments(date);
    final hasMine = rawItems.any((e) => e.isMine);

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            width: MediaQuery.of(context).size.width - 32,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FCFC),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFE3F0F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 560),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _dateTitle(date),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: kScheduleInk,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(CupertinoIcons.xmark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _StatusBanner(
                      color: !_monthPublished
                          ? kScheduleDanger
                          : hasMine
                              ? kScheduleSuccess
                              : kScheduleAccent,
                      title: !_monthPublished
                          ? 'График не опубликован'
                          : hasMine
                              ? 'У вас есть смена'
                              : (rawItems.isEmpty
                                  ? 'Свободный день'
                                  : 'Не моя смена'),
                      subtitle: !_monthPublished
                          ? 'Владелец ещё не опубликовал график на этот месяц.'
                          : hasMine
                              ? 'Для изменения опубликованной смены используйте запрос замены.'
                              : (rawItems.isEmpty
                                  ? 'На этот день нет назначений. Его можно запросить.'
                                  : 'На этот день уже назначены другие сотрудники.'),
                    ),
                    const SizedBox(height: 14),
                    if (!_monthPublished)
                      const _InfoMessageCard(
                        icon: CupertinoIcons.calendar,
                        title: 'График ещё не опубликован',
                        text:
                            'Когда владелец опубликует график, здесь появятся сотрудники и рабочие дни.',
                      )
                    else if (visibleItems.isEmpty)
                      _InfoMessageCard(
                        icon: rawItems.isEmpty
                            ? CupertinoIcons.plus_circle_fill
                            : CupertinoIcons.person_2_fill,
                        title: rawItems.isEmpty
                            ? 'День пока свободен'
                            : (_showOnlyMine
                                ? 'У вас нет смены на этот день'
                                : 'На день уже есть назначения'),
                        text: rawItems.isEmpty
                            ? 'Этот день можно запросить через кнопку «Составить график».'
                            : (_showOnlyMine
                                ? 'Отключите фильтр «Только мои», чтобы посмотреть всю команду.'
                                : 'Для уже назначенных смен используйте запрос замены.'),
                      )
                    else
                      Column(
                        children: List.generate(
                          visibleItems.length,
                          (index) => Padding(
                            padding: EdgeInsets.only(
                              bottom: index == visibleItems.length - 1 ? 0 : 10,
                            ),
                            child: _ShiftTile(item: visibleItems[index]),
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    if (_monthPublished && hasMine)
                      _DialogFooterButton(
                        label: 'Попросить замену',
                        isPrimary: true,
                        onTap: () {
                          Navigator.of(dialogContext).pop();
                          _showSwapRequestDialog(date);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _softBlob({
    required double width,
    required double height,
    required List<Color> colors,
  }) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(width),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
    );
  }

  Widget _background() {
    return AnimatedBuilder(
      animation: _ambientController,
      builder: (context, child) {
        final t = _ambientController.value;
        final shiftA = math.sin(t * math.pi * 2) * 18;
        final shiftB = math.cos(t * math.pi * 2) * 12;

        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kScheduleMintTop,
                    kScheduleMintMid,
                    kScheduleMintBottom,
                    kScheduleMintDeep,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.40, 0.78, 1.0],
                ),
              ),
            ),
            Positioned(
              top: -80 + shiftA,
              right: -40,
              child: _softBlob(
                width: 260,
                height: 260,
                colors: [
                  Colors.white.withOpacity(0.16),
                  kScheduleAccent.withOpacity(0.12),
                ],
              ),
            ),
            Positioned(
              bottom: 40 - shiftB,
              left: -40,
              child: _softBlob(
                width: 220,
                height: 220,
                colors: [
                  kScheduleBlue.withOpacity(0.10),
                  Colors.white.withOpacity(0.06),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeaderControls() {
    final bool needsAttention = !_monthPublished;

    return _SimpleCard(
      child: Column(
        children: [
          Row(
            children: [
              _CircleButton(
                icon: CupertinoIcons.chevron_left,
                onTap: () => _changeMonth(-1),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _monthNames[_visibleMonth.month - 1],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: kScheduleInk,
                      ),
                    ),
                    Text(
                      '${_visibleMonth.year}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: kScheduleInkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _CircleButton(
                icon: CupertinoIcons.chevron_right,
                onTap: () => _changeMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ActionPill(
                  icon: CupertinoIcons.calendar_badge_plus,
                  label: _draftActionLabel(),
                  onTap: _showComposeScheduleDialog,
                  needsAttention: needsAttention,
                  isApproved: _monthPublished,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionPill(
                  icon: _showOnlyMine
                      ? CupertinoIcons.person_crop_circle_fill
                      : CupertinoIcons.person_2,
                  label: _showOnlyMine ? 'Только мои' : 'Вся команда',
                  onTap: () {
                    setState(() {
                      _showOnlyMine = !_showOnlyMine;
                    });
                  },
                  isActive: _showOnlyMine,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopInfoRow() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildLegend()),
          const SizedBox(width: 12),
          Expanded(child: _buildMySummary()),
        ],
      ),
    );
  }

  Widget _buildMySummary() {
    return _SimpleCard(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 132),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [kScheduleSuccess, kScheduleBlue],
                    ),
                  ),
                  child: const Icon(
                    CupertinoIcons.briefcase_fill,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Мои смены',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: kScheduleInk,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${_myShiftsCountInMonth()} смен в этом месяце',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: kScheduleInk,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _nextMyShiftLabel(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: kScheduleInkSoft,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return _SimpleCard(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 132),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Инфо',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: kScheduleInk,
              ),
            ),
            SizedBox(height: 12),
            _LegendRow(color: kScheduleSuccess, label: 'Моя смена'),
            SizedBox(height: 8),
            _LegendRow(color: kScheduleAccent, label: 'Свободно / не моя'),
            SizedBox(height: 8),
            _LegendRow(color: kScheduleDanger, label: 'Не опубликовано'),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMonthHint() {
    final hasAssignments = _assignments.values.any((items) => items.isNotEmpty);

    if (_monthPublished || hasAssignments) {
      return const SizedBox.shrink();
    }

    final bool isApproved = _draftState == _ScheduleApprovalState.approved;
    final bool isPending = _draftState == _ScheduleApprovalState.pending;

    final String title;
    final String text;
    final IconData icon;

    if (isApproved) {
      title = 'График ещё не опубликован';
      text =
          'Ваши дни уже согласованы. После публикации владельцем здесь появятся смены.';
      icon = CupertinoIcons.calendar;
    } else if (isPending) {
      title = 'Заявка на график отправлена';
      text =
          'Дождитесь согласования владельцем. После этого график появится в календаре.';
      icon = CupertinoIcons.time;
    } else {
      title = 'Нет данных по графику';
      text =
          'На этот месяц вы ещё не отправляли доступные дни. Нажмите «Заполнить график».';
      icon = CupertinoIcons.calendar_badge_plus;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _SimpleCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, color: kScheduleBlue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      color: kScheduleInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: kScheduleInkSoft,
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

  Widget _buildCalendar() {
    final days = _calendarDays();

    return _SimpleCard(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
      child: Column(
        children: [
          Row(
            children: _weekDaysShort
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          day,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: kScheduleInkSoft,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          GridView.builder(
            shrinkWrap: true,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 0.70,
            ),
            itemBuilder: (context, index) {
              final date = days[index];
              final allItems = _allAssignments(date);
              final visibleItems = _visibleAssignments(date);
              final isCurrentMonth = date.month == _visibleMonth.month;
              final isToday = _isToday(date);
              final hasMine = allItems.any((item) => item.isMine);

              return _CalendarDayTile(
                date: date,
                isCurrentMonth: isCurrentMonth,
                isToday: isToday,
                published: _monthPublished,
                hasMine: hasMine,
                labels: visibleItems.take(3).map((e) => e.shortLabel).toList(),
                extraCount:
                    visibleItems.length > 3 ? visibleItems.length - 3 : 0,
                allCount: allItems.length,
                onTap: () => _showDayDetails(date),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kScheduleMintTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'График работы',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            _background(),
            SafeArea(
              top: false,
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        _buildHeaderControls(),
                        const SizedBox(height: 12),
                        _buildTopInfoRow(),
                        const SizedBox(height: 12),
                        _buildEmptyMonthHint(),
                        _buildCalendar(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimpleCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SimpleCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: kScheduleCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kScheduleStroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Color(0xEBFFFFFF),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: kScheduleInk, size: 20),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final bool needsAttention;
  final bool isApproved;

  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.needsAttention = false,
    this.isApproved = false,
  });

  @override
  Widget build(BuildContext context) {
    final fill = isApproved
        ? kScheduleSuccess.withOpacity(0.14)
        : needsAttention
            ? kScheduleAccent.withOpacity(0.14)
            : (isActive
                ? kScheduleBlue.withOpacity(0.12)
                : Colors.white.withOpacity(0.92));

    final iconColor = isApproved
        ? kScheduleSuccess
        : needsAttention
            ? kScheduleAccent
            : (isActive ? kScheduleBlue : kScheduleInk);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 66),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.8,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  color: iconColor,
                ),
              ),
            ),
            if (needsAttention) const _PulseDot(),
          ],
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.85, end: 1.15).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.only(left: 6),
        decoration: BoxDecoration(
          color: kScheduleAccent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: kScheduleAccent.withOpacity(0.35),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendRow({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: kScheduleInk,
            ),
          ),
        ),
      ],
    );
  }
}

class _CalendarDayTile extends StatelessWidget {
  final DateTime date;
  final bool isCurrentMonth;
  final bool isToday;
  final bool published;
  final bool hasMine;
  final List<String> labels;
  final int extraCount;
  final int allCount;
  final VoidCallback onTap;

  const _CalendarDayTile({
    required this.date,
    required this.isCurrentMonth,
    required this.isToday,
    required this.published,
    required this.hasMine,
    required this.labels,
    required this.extraCount,
    required this.allCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double contentOpacity = isCurrentMonth ? 1.0 : 0.30;
    final accent = !published
        ? kScheduleDanger
        : (hasMine ? kScheduleSuccess : kScheduleAccent);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(isCurrentMonth ? 0.95 : 0.84),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isToday ? kScheduleBlue : const Color(0xFFE1ECEC),
            width: isToday ? 1.8 : 1.0,
          ),
        ),
        padding: const EdgeInsets.all(5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${date.day}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: kScheduleInk.withOpacity(contentOpacity),
                    ),
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(contentOpacity),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: !published
                  ? Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: kScheduleDanger.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    )
                  : allCount == 0
                      ? Container(
                          width: double.infinity,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: kScheduleAccent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '—',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color:
                                  kScheduleAccent.withOpacity(contentOpacity),
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            for (final label in labels)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: hasMine
                                        ? kScheduleSuccess.withOpacity(0.14)
                                        : kScheduleAccent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    label,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 8.6,
                                      fontWeight: FontWeight.w900,
                                      color: hasMine
                                          ? kScheduleSuccess
                                          : kScheduleAccent,
                                    ),
                                  ),
                                ),
                              ),
                            if (extraCount > 0)
                              Text(
                                '+$extraCount',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: kScheduleInkSoft.withOpacity(
                                    contentOpacity,
                                  ),
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
}

class _ShiftTile extends StatelessWidget {
  final _ShiftAssignment item;

  const _ShiftTile({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final color = item.isMine ? kScheduleSuccess : kScheduleAccent;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4F0F1)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                item.shortLabel,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.employeeName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: kScheduleInk,
                        ),
                      ),
                    ),
                    if (item.isMine)
                      const _StatusPill(
                        color: kScheduleSuccess,
                        label: 'Вы',
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.role,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: kScheduleInkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final Color color;
  final String label;

  const _StatusPill({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final Color color;
  final String title;
  final String subtitle;

  const _StatusBanner({
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(CupertinoIcons.info_circle_fill, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.6,
                    fontWeight: FontWeight.w800,
                    color: kScheduleInkSoft,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogFooterButton extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback? onTap;

  const _DialogFooterButton({
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: isPrimary ? kScheduleBlue : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: isPrimary ? Colors.white : kScheduleInk,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoMessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _InfoMessageCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: kScheduleBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: kScheduleInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kScheduleInkSoft,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShiftAssignment {
  final String employeeId;
  final String employeeName;
  final String role;
  final String? badge;
  final bool isMine;

  const _ShiftAssignment({
    required this.employeeId,
    required this.employeeName,
    required this.role,
    required this.badge,
    required this.isMine,
  });

  String get shortLabel {
    final safeBadge = badge?.trim() ?? '';
    if (safeBadge.isNotEmpty) {
      return safeBadge.toUpperCase();
    }

    if (isMine) return 'ВЫ';

    final safeName = employeeName.trim();
    if (safeName.isEmpty) return '—';

    final parts = safeName
        .split(RegExp(r'\s+'))
        .where((e) => e.trim().isNotEmpty)
        .toList();

    if (parts.isEmpty) return '—';

    if (parts.length >= 2) {
      final first = parts[0].trim();
      final second = parts[1].trim();

      final firstLetter = first.isNotEmpty ? first.substring(0, 1) : '';
      final secondLetter = second.isNotEmpty ? second.substring(0, 1) : '';

      final result = '$firstLetter$secondLetter'.trim();
      if (result.isNotEmpty) return result.toUpperCase();
    }

    final word = parts.first.trim().toUpperCase();
    if (word.isEmpty) return '—';
    if (word.length >= 3) return word.substring(0, 3);
    return word;
  }
}