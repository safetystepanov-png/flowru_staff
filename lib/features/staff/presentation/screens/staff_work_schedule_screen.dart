import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/staff_published_schedule_api.dart';
import '../../data/staff_schedule_requests_api.dart';

const Color kScheduleMintTop = Color(0xFF0CB7B3);
const Color kScheduleMintMid = Color(0xFF08A9AB);
const Color kScheduleMintBottom = Color(0xFF067D87);
const Color kScheduleMintDeep = Color(0xFF055E66);

const Color kScheduleCard = Color(0xCCFFFFFF);
const Color kScheduleCardStrong = Color(0xE8FFFFFF);
const Color kScheduleStroke = Color(0xA6FFFFFF);

const Color kScheduleInk = Color(0xFF103238);
const Color kScheduleInkSoft = Color(0xFF58767D);
const Color kScheduleBlue = Color(0xFF4E7CFF);
const Color kSchedulePink = Color(0xFFFF5F8F);
const Color kScheduleViolet = Color(0xFF7A63FF);
const Color kScheduleAccent = Color(0xFFFFA11D);
const Color kScheduleSuccess = Color(0xFF22C55E);
const Color kScheduleDanger = Color(0xFFEF4444);

enum _ScheduleApprovalState {
  none,
  pending,
  approved,
}

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
  State<StaffWorkScheduleScreen> createState() => _StaffWorkScheduleScreenState();
}

class _StaffWorkScheduleScreenState extends State<StaffWorkScheduleScreen>
    with SingleTickerProviderStateMixin {
  static const String _myEmployeeId = 'me';

  late final AnimationController _ambientController;
  final StaffScheduleRequestsApi _requestsApi = const StaffScheduleRequestsApi();
  final StaffPublishedScheduleApi _publishedScheduleApi = const StaffPublishedScheduleApi();

  late DateTime _visibleMonth;
  Map<DateTime, List<_ShiftAssignment>> _assignments = <DateTime, List<_ShiftAssignment>>{};

  bool _showOnlyMine = false;
  bool _loadingRequestState = true;
  bool _loadingMonthSchedule = true;
  bool _submittingDraft = false;
  bool _submittingSwap = false;
  bool _monthPublished = false;

  _ScheduleApprovalState _nextMonthDraftState = _ScheduleApprovalState.none;
  List<int> _requestedNextMonthDays = <int>[];

  static const List<String> _monthNames = [
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

  static const List<String> _weekDaysShort = [
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
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7600),
    )..repeat();

    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _loadAll();
  }

  @override
  void dispose() {
    _ambientController.dispose();
    super.dispose();
  }

  bool get _isOwner {
    final role = widget.role.trim().toLowerCase();
    return role == 'owner' || role == 'admin';
  }

  DateTime _stripTime(DateTime date) => DateTime(date.year, date.month, date.day);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isToday(DateTime date) => _isSameDay(_stripTime(DateTime.now()), date);

  DateTime _nextMonthDate() => DateTime(_visibleMonth.year, _visibleMonth.month + 1);

  Future<void> _loadNextMonthRequestState() async {
    setState(() {
      _loadingRequestState = true;
    });

    try {
      final nextMonth = _nextMonthDate();
      final latest = await _requestsApi.getLatestMyRequest(
        establishmentId: widget.establishmentId,
        year: nextMonth.year,
        month: nextMonth.month,
      );

      if (!mounted) return;

      setState(() {
        if (latest == null) {
          _nextMonthDraftState = _ScheduleApprovalState.none;
          _requestedNextMonthDays = <int>[];
        } else {
          _requestedNextMonthDays = latest.selectedDays;
          if (latest.status == 'approved') {
            _nextMonthDraftState = _ScheduleApprovalState.approved;
          } else {
            _nextMonthDraftState = _ScheduleApprovalState.pending;
          }
        }
        _loadingRequestState = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingRequestState = false;
      });
    }
  }

  void _changeMonth(int delta) {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    setState(() {
      _visibleMonth = next;
      _assignments = <DateTime, List<_ShiftAssignment>>{};
      _monthPublished = false;
      _loadingMonthSchedule = true;
    });
    _loadAll();
  }


  Future<void> _loadAll() async {
    await Future.wait([
      _loadNextMonthRequestState(),
      _loadMonthSchedule(),
    ]);
  }

  Future<void> _loadMonthSchedule() async {
    setState(() {
      _loadingMonthSchedule = true;
    });

    try {
      final month = await _publishedScheduleApi.getScheduleMonth(
        establishmentId: widget.establishmentId,
        year: _visibleMonth.year,
        month: _visibleMonth.month,
      );

      final map = <DateTime, List<_ShiftAssignment>>{};
      for (final day in month.days) {
        map[_stripTime(day.date)] = day.items
            .map(
              (person) => _ShiftAssignment(
                employeeId: person.employeeUserId,
                employeeName: person.isMine ? 'Вы' : person.employeeName,
                role: (person.employeeRole?.trim().isNotEmpty ?? false)
                    ? person.employeeRole!.trim()
                    : 'Сотрудник',
                color: person.isMine ? kScheduleSuccess : kScheduleAccent,
                isMine: person.isMine,
              ),
            )
            .toList();
      }

      if (!mounted) return;
      setState(() {
        _assignments = map;
        _monthPublished = month.published;
        _loadingMonthSchedule = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _assignments = <DateTime, List<_ShiftAssignment>>{};
        _monthPublished = false;
        _loadingMonthSchedule = false;
      });
    }
  }

  List<DateTime> _calendarDays() {
    final firstDayOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final startOffset = firstDayOfMonth.weekday - 1;
    final firstVisibleDay = firstDayOfMonth.subtract(Duration(days: startOffset));

    return List<DateTime>.generate(
      42,
      (index) => firstVisibleDay.add(Duration(days: index)),
    );
  }

  List<_ShiftAssignment> _getAssignments(DateTime date) {
    final normalized = _stripTime(date);
    final items = _assignments[normalized] ?? const <_ShiftAssignment>[];
    if (_showOnlyMine) {
      return items.where((e) => e.employeeId == _myEmployeeId).toList();
    }
    return items;
  }

  int _myShiftsCountInMonth() {
    return _assignments.values
        .where((day) => day.any((item) => item.employeeId == _myEmployeeId))
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
      final mine = (_assignments[day] ?? const <_ShiftAssignment>[])
          .where((item) => item.employeeId == _myEmployeeId)
          .toList();
      if (mine.isNotEmpty) {
        return '${day.day} ${_monthNames[day.month - 1].toLowerCase()}';
      }
    }

    if (!_monthPublished) {
      return _isOwner
          ? 'График на месяц не заполнен'
          : 'График на месяц еще не опубликован';
    }

    return 'На этот месяц смен больше нет';
  }

  String _dateTitle(DateTime date) {
    return '${date.day} ${_monthNames[date.month - 1]}';
  }

  String _nextMonthLabel() {
    final next = _nextMonthDate();
    return '${_monthNames[next.month - 1]} ${next.year}';
  }

  String _draftStatusText() {
    if (_loadingRequestState) {
      return 'Проверяем статус на ${_nextMonthLabel().toLowerCase()}...';
    }

    switch (_nextMonthDraftState) {
      case _ScheduleApprovalState.none:
        return 'Пожелания на ${_nextMonthLabel().toLowerCase()} еще не отправлены';
      case _ScheduleApprovalState.pending:
        return 'Пожелания отправлены владельцу на согласование';
      case _ScheduleApprovalState.approved:
        return 'График согласован и закреплен';
    }
  }


  String _monthStatusText() {
    if (_loadingMonthSchedule) {
      return 'Загружаем график месяца...';
    }
    if (_monthPublished) {
      return 'График на месяц опубликован';
    }
    return _isOwner
        ? 'График на месяц не заполнен — заполните его'
        : 'График на месяц еще не опубликован владельцем';
  }

  Future<void> _showDayDetails(DateTime date) async {
    final rawItems = _assignments[_stripTime(date)] ?? const <_ShiftAssignment>[];
    final visibleItems = _showOnlyMine
        ? rawItems.where((item) => item.employeeId == _myEmployeeId).toList()
        : rawItems;
    final hasMine = rawItems.any((e) => e.employeeId == _myEmployeeId);

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FCFC),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFE3F0F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.14),
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'График на день',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: kScheduleInkSoft.withOpacity(0.92),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _dateTitle(date),
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: kScheduleInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.of(dialogContext).pop(),
                            child: const SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(CupertinoIcons.xmark, color: kScheduleInk),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _StatusBanner(
                      color: hasMine
                          ? kScheduleSuccess
                          : (rawItems.isEmpty ? kScheduleDanger : kScheduleAccent),
                      title: hasMine
                          ? 'У вас есть смена'
                          : (rawItems.isEmpty ? 'Смен на этот день нет' : 'Есть смены у команды'),
                      subtitle: hasMine
                          ? 'Ниже показаны детали вашей смены и смен команды.'
                          : (rawItems.isEmpty
                              ? 'На выбранную дату пока нет назначений.'
                              : 'На выбранную дату вы не назначены, но команда работает.'),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 330),
                      child: !_monthPublished
                          ? const _InfoMessageCard(
                              icon: CupertinoIcons.exclamationmark_circle_fill,
                              title: 'График еще пустой',
                              text: 'Как только график на месяц будет заполнен и опубликован, здесь появятся назначения сотрудников.',
                            )
                          : visibleItems.isEmpty
                              ? _InfoMessageCard(
                                  icon: CupertinoIcons.moon_stars_fill,
                                  title: _showOnlyMine
                                      ? 'У вас нет смены на этот день'
                                      : 'На этот день нет назначенных смен',
                                  text: _showOnlyMine
                                      ? 'Отключите фильтр «Только мои», если хотите посмотреть смены всей команды.'
                                      : 'На выбранную дату пока никого не назначили.',
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: visibleItems.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) => _ShiftTile(item: visibleItems[index]),
                                ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (_monthPublished && hasMine)
                          _DialogActionButton(
                            icon: CupertinoIcons.arrow_2_squarepath,
                            label: _submittingSwap ? 'Отправка...' : 'Попросить замену',
                            onTap: _submittingSwap
                                ? () {}
                                : () async {
                                    Navigator.of(dialogContext).pop();
                                    await _requestSwap(date);
                                  },
                          ),
                        _DialogActionButton(
                          icon: CupertinoIcons.square_list,
                          label: 'Подробнее',
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            _showMockAction('Позже здесь откроется полный журнал изменений по дню.');
                          },
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
    );
  }

  Future<void> _requestSwap(DateTime date) async {
    setState(() {
      _submittingSwap = true;
    });

    try {
      await _requestsApi.requestSwap(
        establishmentId: widget.establishmentId,
        shiftDate: date,
        reason: 'Запрос замены смены из мобильного приложения',
      );

      if (!mounted) return;
      _showMockAction('Заявка на замену смены отправлена владельцу.');
    } catch (e) {
      if (!mounted) return;
      _showMockAction('Не удалось отправить заявку на замену: $e');
    } finally {
      if (mounted) {
        setState(() {
          _submittingSwap = false;
        });
      }
    }
  }

  Future<void> _showComposeScheduleDialog() async {
    if (_isOwner) {
      _showMockAction('Здесь у владельца будет отдельное заполнение итогового графика. Этот экран не отправляет пожелания от имени владельца.');
      return;
    }

    if (_nextMonthDraftState == _ScheduleApprovalState.approved) {
      _showMockAction('График уже согласован. Изменения сможет внести только владелец.');
      return;
    }

    final nextMonth = _nextMonthDate();
    final daysInMonth = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
    final selected = _requestedNextMonthDays.toSet();

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Составить график',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: kScheduleInkSoft.withOpacity(0.92),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _nextMonthLabel(),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: kScheduleInk,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Material(
                              color: Colors.white,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => Navigator.of(dialogContext).pop(),
                                child: const SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: Icon(CupertinoIcons.xmark, color: kScheduleInk),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Отметьте дни, в которые вы готовы работать. После подтверждения пожелания уйдут владельцу на согласование.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            height: 1.42,
                            color: kScheduleInkSoft.withOpacity(0.96),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List<Widget>.generate(daysInMonth, (index) {
                            final day = index + 1;
                            final isSelected = selected.contains(day);
                            return Material(
                              color: isSelected
                                  ? kScheduleSuccess.withOpacity(0.16)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
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
                                    border: Border.all(
                                      color: isSelected
                                          ? kScheduleSuccess
                                          : const Color(0xFFE2EFEF),
                                      width: isSelected ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Text(
                                    '$day',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: isSelected ? kScheduleSuccess : kScheduleInk,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
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
                                label: _submittingDraft ? 'Отправка...' : 'Подтвердить',
                                isPrimary: true,
                                onTap: _submittingDraft
                                    ? () {}
                                    : () async {
                                        final selectedList = selected.toList()..sort();
                                        if (selectedList.isEmpty) {
                                          _showMockAction('Нужно выбрать хотя бы один день.');
                                          return;
                                        }

                                        Navigator.of(dialogContext).pop();

                                        setState(() {
                                          _submittingDraft = true;
                                        });

                                        try {
                                          final request = await _requestsApi.submitScheduleRequest(
                                            establishmentId: widget.establishmentId,
                                            year: nextMonth.year,
                                            month: nextMonth.month,
                                            selectedDays: selectedList,
                                          );

                                          if (!mounted) return;

                                          setState(() {
                                            _requestedNextMonthDays = request.selectedDays;
                                            _nextMonthDraftState = request.status == 'approved'
                                                ? _ScheduleApprovalState.approved
                                                : _ScheduleApprovalState.pending;
                                          });

                                          _showMockAction(
                                            'Пожелания на ${_nextMonthLabel().toLowerCase()} отправлены владельцу.',
                                          );
                                        } catch (e) {
                                          if (!mounted) return;
                                          _showMockAction('Не удалось отправить пожелания: $e');
                                        } finally {
                                          if (mounted) {
                                            setState(() {
                                              _submittingDraft = false;
                                            });
                                          }
                                        }
                                      },
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
        );
      },
    );
  }

  void _showMockAction(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
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
    return _GlassCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
            children: [
              Expanded(
                child: _ActionPill(
                  icon: CupertinoIcons.calendar_badge_plus,
                  label: _loadingRequestState
                      ? 'Проверка...'
                      : _nextMonthDraftState == _ScheduleApprovalState.approved
                          ? 'Согласовано'
                          : (_nextMonthDraftState == _ScheduleApprovalState.pending
                              ? 'На согласовании'
                              : 'Составить график'),
                  onTap: _showComposeScheduleDialog,
                  needsAttention: !_isOwner &&
                      !_loadingRequestState &&
                      _nextMonthDraftState == _ScheduleApprovalState.none,
                  isMuted: _isOwner || _submittingDraft,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionPill(
                  icon: _showOnlyMine
                      ? CupertinoIcons.person_crop_circle_fill
                      : CupertinoIcons.person_2,
                  label: _showOnlyMine ? 'Только мои' : 'Вся команда',
                  isActive: _showOnlyMine,
                  onTap: () {
                    setState(() {
                      _showOnlyMine = !_showOnlyMine;
                    });
                  },
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
          Expanded(child: _buildMySummary()),
          const SizedBox(width: 12),
          Expanded(child: _buildLegend()),
        ],
      ),
    );
  }

  Widget _buildMySummary() {
    return _GlassCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
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
            _monthPublished
                ? '${_myShiftsCountInMonth()} смен в этом месяце'
                : 'График не опубликован',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: kScheduleInk,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return _GlassCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
                    colors: [kScheduleAccent, Color(0xFFFFC45D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.info_circle_fill,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Инфо',
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
          const _LegendRow(color: kScheduleSuccess, label: 'Моя смена'),
          const SizedBox(height: 8),
          const _LegendRow(color: kScheduleAccent, label: 'Есть смены'),
          const SizedBox(height: 8),
          const _LegendRow(color: kScheduleDanger, label: 'Нет моей смены'),
          const SizedBox(height: 10),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                _draftStatusText(),
                style: const TextStyle(
                  fontSize: 12.2,
                  fontWeight: FontWeight.w800,
                  color: kScheduleInkSoft,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final days = _calendarDays();

    return _GlassCard(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
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
                            fontSize: 12.5,
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
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.92,
            ),
            itemBuilder: (context, index) {
              final date = days[index];
              final allItems = _assignments[_stripTime(date)] ?? const <_ShiftAssignment>[];
              final items = _getAssignments(date);
              final isCurrentMonth = date.month == _visibleMonth.month;
              final isToday = _isToday(date);
              final hasMine = allItems.any((item) => item.employeeId == _myEmployeeId);

              return _CalendarDayTile(
                date: date,
                isCurrentMonth: isCurrentMonth,
                isToday: isToday,
                hasMine: hasMine,
                labels: items.take(2).map((e) => e.shortLabel).toList(),
                extraCount: items.length > 2 ? items.length - 2 : 0,
                allCount: allItems.length,
                monthPublished: _monthPublished,
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
              child: RefreshIndicator(
                color: kScheduleViolet,
                backgroundColor: Colors.white,
                onRefresh: _loadAll,
                child: ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _buildHeaderControls(),
                    const SizedBox(height: 12),
                    _buildTopInfoRow(),
                    const SizedBox(height: 12),
                    _buildCalendar(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const _GlassCard({
    required this.child,
    required this.padding,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              colors: [
                kScheduleCardStrong,
                kScheduleCard,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: kScheduleStroke),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
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
    return Material(
      color: Colors.white.withOpacity(0.78),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: kScheduleInk, size: 20),
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final bool isMuted;
  final bool needsAttention;

  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.isMuted = false,
    this.needsAttention = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color fill = needsAttention
        ? kScheduleAccent.withOpacity(0.14)
        : (isMuted
            ? const Color(0xFFE7EBEE)
            : (isActive ? kScheduleBlue.withOpacity(0.12) : Colors.white.withOpacity(0.76)));
    final Color iconColor = needsAttention
        ? kScheduleAccent
        : (isMuted ? kScheduleInkSoft : (isActive ? kScheduleBlue : kScheduleInk));

    Widget attentionDot = const SizedBox.shrink();
    if (needsAttention) {
      attentionDot = TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.72, end: 1.08),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeInOut,
        builder: (context, scale, _) {
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: kScheduleAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: kScheduleAccent.withOpacity(0.30),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: iconColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12.7,
                    fontWeight: FontWeight.w900,
                    color: iconColor,
                  ),
                ),
              ),
              if (needsAttention) ...[
                const SizedBox(width: 8),
                attentionDot,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendRow({required this.color, required this.label});

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
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.28),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
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
  final bool hasMine;
  final List<String> labels;
  final int extraCount;
  final int allCount;
  final bool monthPublished;
  final VoidCallback onTap;

  const _CalendarDayTile({
    required this.date,
    required this.isCurrentMonth,
    required this.isToday,
    required this.hasMine,
    required this.labels,
    required this.extraCount,
    required this.allCount,
    required this.monthPublished,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double opacity = isCurrentMonth ? 1 : 0.28;
    final Color accent = !monthPublished
        ? const Color(0xFFDDE7EA)
        : hasMine
            ? kScheduleSuccess
            : (allCount == 0 ? kScheduleDanger : kScheduleAccent);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(7, 7, 7, 7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.78),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isToday ? kScheduleBlue : accent.withOpacity(0.88),
              width: isToday ? 1.8 : 1.15,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.10),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Opacity(
            opacity: opacity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${date.day}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: kScheduleInk,
                        ),
                      ),
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withOpacity(0.30),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: !monthPublished
                      ? Container(
                          width: double.infinity,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F8F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('', style: TextStyle(fontSize: 1)),
                        )
                      : allCount == 0
                      ? Container(
                          width: double.infinity,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: kScheduleDanger.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '—',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: kScheduleDanger,
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            ...labels.map(
                              (label) => Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                                decoration: BoxDecoration(
                                  color: hasMine
                                      ? kScheduleSuccess.withOpacity(0.14)
                                      : kScheduleAccent.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    color: hasMine ? kScheduleSuccess : kScheduleAccent,
                                  ),
                                ),
                              ),
                            ),
                            if (extraCount > 0)
                              Text(
                                '+$extraCount',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: kScheduleInkSoft,
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShiftTile extends StatelessWidget {
  final _ShiftAssignment item;

  const _ShiftTile({required this.item});

  @override
  Widget build(BuildContext context) {
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
              color: item.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                item.shortLabel,
                style: TextStyle(
                  color: item.color,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
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
                      const _StatusPill(color: kScheduleSuccess, label: 'Вы'),
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

  const _StatusPill({required this.color, required this.label});

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

class _DialogActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DialogActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: kScheduleInk),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: kScheduleInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogFooterButton extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _DialogFooterButton({
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPrimary ? kScheduleBlue : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
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
  final Color color;
  final bool isMine;

  const _ShiftAssignment({
    required this.employeeId,
    required this.employeeName,
    required this.role,
    required this.color,
    this.isMine = false,
  });

  String get shortLabel {
    if (employeeName.length <= 2) return employeeName.toUpperCase();
    return employeeName.substring(0, 2).toUpperCase();
  }
}
