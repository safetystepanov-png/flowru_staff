import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/staff_owner_requests_api.dart';
import '../../data/staff_owner_schedule_api.dart';

const Color kOwnerPlanMintTop = Color(0xFF0CB7B3);
const Color kOwnerPlanMintMid = Color(0xFF08A9AB);
const Color kOwnerPlanMintBottom = Color(0xFF067D87);
const Color kOwnerPlanMintDeep = Color(0xFF055E66);

const Color kOwnerPlanInk = Color(0xFF103238);
const Color kOwnerPlanInkSoft = Color(0xFF58767D);
const Color kOwnerPlanBlue = Color(0xFF4E7CFF);
const Color kOwnerPlanPink = Color(0xFFFF5F8F);
const Color kOwnerPlanViolet = Color(0xFF7A63FF);
const Color kOwnerPlanAccent = Color(0xFFFFA11D);
const Color kOwnerPlanSuccess = Color(0xFF22C55E);

class OwnerSchedulePlannerScreen extends StatefulWidget {
  final int establishmentId;
  final String establishmentName;
  final String role;

  const OwnerSchedulePlannerScreen({
    super.key,
    required this.establishmentId,
    required this.establishmentName,
    required this.role,
  });

  @override
  State<OwnerSchedulePlannerScreen> createState() => _OwnerSchedulePlannerScreenState();
}

class _OwnerSchedulePlannerScreenState extends State<OwnerSchedulePlannerScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ambientController;
  late final AnimationController _introController;

  final StaffOwnerRequestsApi _requestsApi = const StaffOwnerRequestsApi();
  final StaffOwnerScheduleApi _scheduleApi = const StaffOwnerScheduleApi();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  late DateTime _targetMonth;
  List<OwnerRequestItem> _requests = const [];
  final Map<DateTime, List<OwnerRequestItem>> _selectedByDay = {};

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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _targetMonth = DateTime(now.year, now.month + 1);

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7600),
    )..repeat();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 980),
    );

    _load();
  }

  @override
  void dispose() {
    _ambientController.dispose();
    _introController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedByDay.clear();
    });

    try {
      final bundle = await _requestsApi.getOwnerRequests(
        establishmentId: widget.establishmentId,
      );

      final filtered = bundle.items.where((item) {
        if (!item.isSchedule) return false;
        return item.year == _targetMonth.year &&
            item.month == _targetMonth.month &&
            item.status == 'approved';
      }).toList();

      for (final request in filtered) {
        for (final day in request.selectedDays) {
          final date = DateTime(_targetMonth.year, _targetMonth.month, day);
          _selectedByDay.putIfAbsent(date, () => <OwnerRequestItem>[]).add(request);
        }
      }

      if (!mounted) return;
      setState(() {
        _requests = filtered;
        _loading = false;
      });
      _introController.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить согласованные пожелания';
      });
      _introController.forward(from: 0);
    }
  }

  List<DateTime> _calendarDays() {
    final firstDay = DateTime(_targetMonth.year, _targetMonth.month, 1);
    final startOffset = firstDay.weekday - 1;
    final start = firstDay.subtract(Duration(days: startOffset));

    return List<DateTime>.generate(
      42,
      (index) => start.add(Duration(days: index)),
    );
  }

  int get _assignedCount {
    return _selectedByDay.values.fold<int>(0, (sum, items) => sum + items.length);
  }

  Future<void> _pickDay(DateTime date) async {
    if (date.month != _targetMonth.month) return;

    final approved = _requests.where((item) => item.selectedDays.contains(date.day)).toList();

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final selected = <int>{
          for (final item in (_selectedByDay[date] ?? const <OwnerRequestItem>[]))
            item.requestId,
        };

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
                                '${date.day} ${_monthNames[date.month - 1]}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: kOwnerPlanInk,
                                ),
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
                                  child: Icon(CupertinoIcons.xmark, color: kOwnerPlanInk),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (approved.isEmpty)
                          const _OwnerInfoCard(
                            icon: CupertinoIcons.person_crop_circle_badge_xmark,
                            title: 'Нет согласованных пожеланий',
                            text: 'На этот день пока нет сотрудников с подтвержденными пожеланиями.',
                          )
                        else
                          ...approved.map((item) {
                            final isSelected = selected.contains(item.requestId);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Material(
                                color: isSelected
                                    ? kOwnerPlanSuccess.withOpacity(0.12)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () {
                                    setLocalState(() {
                                      if (isSelected) {
                                        selected.remove(item.requestId);
                                      } else {
                                        selected.add(item.requestId);
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: isSelected
                                            ? kOwnerPlanSuccess
                                            : const Color(0xFFE4F0F1),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? kOwnerPlanSuccess.withOpacity(0.14)
                                                : kOwnerPlanAccent.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Icon(
                                            isSelected
                                                ? CupertinoIcons.check_mark
                                                : CupertinoIcons.person_fill,
                                            color: isSelected ? kOwnerPlanSuccess : kOwnerPlanAccent,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.employeeName,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w900,
                                                  color: kOwnerPlanInk,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Пожелание на ${item.selectedDays.length} дн.',
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: kOwnerPlanInkSoft,
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
                          }),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _OwnerFooterButton(
                                label: 'Очистить день',
                                isPrimary: false,
                                onTap: () {
                                  setState(() {
                                    _selectedByDay.remove(date);
                                  });
                                  Navigator.of(dialogContext).pop();
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _OwnerFooterButton(
                                label: 'Сохранить',
                                isPrimary: true,
                                onTap: () {
                                  final picked = approved.where((e) => selected.contains(e.requestId)).toList();
                                  setState(() {
                                    if (picked.isEmpty) {
                                      _selectedByDay.remove(date);
                                    } else {
                                      _selectedByDay[date] = picked;
                                    }
                                  });
                                  Navigator.of(dialogContext).pop();
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

  Future<void> _saveMonth() async {
    setState(() => _saving = true);

    try {
      final days = _selectedByDay.entries
          .where((e) => e.value.isNotEmpty)
          .map(
            (e) => OwnerScheduleSaveDay(
              date: e.key,
              items: e.value,
            ),
          )
          .toList();

      await _scheduleApi.saveScheduleMonth(
        establishmentId: widget.establishmentId,
        year: _targetMonth.year,
        month: _targetMonth.month,
        days: days,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('График месяца сохранен'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось сохранить график: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
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
                    kOwnerPlanMintTop,
                    kOwnerPlanMintMid,
                    kOwnerPlanMintBottom,
                    kOwnerPlanMintDeep,
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
                  kOwnerPlanAccent.withOpacity(0.12),
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
                  kOwnerPlanBlue.withOpacity(0.10),
                  Colors.white.withOpacity(0.06),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _headerCard() {
    return _OwnerGlassCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.establishmentName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: kOwnerPlanInk,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Заполнение графика на ${_monthNames[_targetMonth.month - 1].toLowerCase()} ${_targetMonth.year}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: kOwnerPlanInkSoft,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _OwnerMetricCard(
                  icon: CupertinoIcons.check_mark_circled_solid,
                  value: '${_requests.length}',
                  label: 'Согласовано',
                  colorA: kOwnerPlanSuccess,
                  colorB: kOwnerPlanBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OwnerMetricCard(
                  icon: CupertinoIcons.calendar,
                  value: '$_assignedCount',
                  label: 'Назначений',
                  colorA: kOwnerPlanAccent,
                  colorB: kOwnerPlanPink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _calendarCard() {
    final days = _calendarDays();

    return _OwnerGlassCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
      child: Column(
        children: [
          Row(
            children: const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text(
                          d,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: kOwnerPlanInkSoft,
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
              final isCurrentMonth = date.month == _targetMonth.month;
              final assigned = _selectedByDay[date] ?? const <OwnerRequestItem>[];

              return _OwnerDayTile(
                date: date,
                isCurrentMonth: isCurrentMonth,
                count: assigned.length,
                onTap: () => _pickDay(date),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _bottomActions() {
    return Row(
      children: [
        Expanded(
          child: _OwnerFooterButton(
            label: 'Обновить',
            isPrimary: false,
            onTap: _load,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _OwnerFooterButton(
            label: _saving ? 'Сохранение...' : 'Сохранить график',
            isPrimary: true,
            onTap: _saving ? () {} : _saveMonth,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kOwnerPlanMintTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Заполнить график',
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
                color: kOwnerPlanViolet,
                backgroundColor: Colors.white,
                onRefresh: _load,
                child: ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _headerCard(),
                    const SizedBox(height: 12),
                    if (_loading)
                      const _OwnerGlassCard(
                        radius: 26,
                        padding: EdgeInsets.symmetric(vertical: 34, horizontal: 20),
                        child: Center(
                          child: SizedBox(
                            width: 42,
                            height: 42,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation(kOwnerPlanViolet),
                            ),
                          ),
                        ),
                      )
                    else if (_error != null)
                      _OwnerGlassCard(
                        radius: 26,
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: kOwnerPlanInk,
                          ),
                        ),
                      )
                    else ...[
                      _calendarCard(),
                      const SizedBox(height: 12),
                      _bottomActions(),
                    ],
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

class _OwnerGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const _OwnerGlassCard({
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
            gradient: const LinearGradient(
              colors: [
                Color(0xE8FFFFFF),
                Color(0xCCFFFFFF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xA6FFFFFF)),
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

class _OwnerMetricCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color colorA;
  final Color colorB;

  const _OwnerMetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.colorA,
    required this.colorB,
  });

  @override
  Widget build(BuildContext context) {
    return _OwnerGlassCard(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [colorA, colorB],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: kOwnerPlanInk,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: kOwnerPlanInkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerDayTile extends StatelessWidget {
  final DateTime date;
  final bool isCurrentMonth;
  final int count;
  final VoidCallback onTap;

  const _OwnerDayTile({
    required this.date,
    required this.isCurrentMonth,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = isCurrentMonth ? 1.0 : 0.28;
    final accent = count > 0 ? kOwnerPlanSuccess : const Color(0xFFDDE7EA);

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
              color: accent,
              width: 1.15,
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
                          color: kOwnerPlanInk,
                        ),
                      ),
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: count == 0
                      ? Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F8F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        )
                      : Container(
                          width: double.infinity,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: kOwnerPlanSuccess.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: kOwnerPlanSuccess,
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
}

class _OwnerFooterButton extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _OwnerFooterButton({
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPrimary ? kOwnerPlanBlue : Colors.white,
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
                color: isPrimary ? Colors.white : kOwnerPlanInk,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OwnerInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _OwnerInfoCard({
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
            child: Icon(icon, color: kOwnerPlanBlue),
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
                    color: kOwnerPlanInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kOwnerPlanInkSoft,
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
