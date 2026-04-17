import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../auth/data/auth_session.dart';
import '../../../auth/data/auth_storage.dart';
import '../../../../core/config/app_config.dart';
import '../widgets/staff_glass_ui.dart';
import 'owner_requests_screen.dart';
import 'owner_schedule_planner_screen.dart';
import 'staff_announcements_screen.dart';
import 'staff_chat_screen.dart';
import 'staff_client_search_screen.dart';
import 'staff_establishment_history_screen.dart';
import 'staff_work_schedule_screen.dart';

const Color kHomeMintTop = Color(0xFF0CB7B3);
const Color kHomeMintMid = Color(0xFF08A9AB);
const Color kHomeMintBottom = Color(0xFF067D87);
const Color kHomeMintDeep = Color(0xFF055E66);

const Color kHomeAccent = Color(0xFFFFA11D);
const Color kHomeAccentSoft = Color(0xFFFFC45E);
const Color kHomeAccentRed = Color(0xFFFF6A5E);

const Color kHomeCard = Color(0xCCFFFFFF);
const Color kHomeCardStrong = Color(0xE8FFFFFF);
const Color kHomeStroke = Color(0xA6FFFFFF);

const Color kHomeInk = Color(0xFF103238);
const Color kHomeInkSoft = Color(0xFF58767D);
const Color kHomeShadow = Color(0x22062E36);

const Color kHomeBlue = Color(0xFF4E7CFF);
const Color kHomePink = Color(0xFFFF5F8F);
const Color kHomeViolet = Color(0xFF7A63FF);
const Color kHomePulseGreen = Color(0xFF22C55E);

class StaffHomeScreen extends StatefulWidget {
  final int establishmentId;
  final String establishmentName;
  final String role;

  const StaffHomeScreen({
    super.key,
    required this.establishmentId,
    required this.establishmentName,
    required this.role,
  });

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen>
    with TickerProviderStateMixin {
  bool _loading = true;
  String? _error;

  int _chatCount = 0;
  int _announcementCount = 0;

  late final AnimationController _introController;
  late final AnimationController _ambientController;

  bool get _isOwner {
    final role = widget.role.trim().toLowerCase();
    return role == 'owner' || role == 'admin';
  }

  String get _roleLabel {
    final role = widget.role.trim().toLowerCase();
    if (role == 'owner') return 'Владелец';
    if (role == 'admin') return 'Администратор';
    return 'Сотрудник';
  }

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7800),
    )..repeat();

    _loadDashboard();
  }

  @override
  void dispose() {
    _introController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Access token not found');
    }
    return token;
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await _token();

      final chatUri = Uri.parse(
        '${AppConfig.baseUrl}/api/v1/staff/chat/messages?establishment_id=${widget.establishmentId}',
      );

      final annUri = Uri.parse(
        '${AppConfig.baseUrl}/api/v1/staff/announcements?establishment_id=${widget.establishmentId}',
      );

      final responses = await Future.wait([
        http.get(
          chatUri,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
        http.get(
          annUri,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      ]);

      final chatResponse = responses[0];
      final annResponse = responses[1];

      if (chatResponse.statusCode != 200) {
        throw Exception(
          'chat count failed: ${chatResponse.statusCode} body=${chatResponse.body}',
        );
      }
      if (annResponse.statusCode != 200) {
        throw Exception(
          'ann count failed: ${annResponse.statusCode} body=${annResponse.body}',
        );
      }

      final chatDecoded = jsonDecode(chatResponse.body);
      final annDecoded = jsonDecode(annResponse.body);

      List<dynamic> chatItems;
      if (chatDecoded is List) {
        chatItems = chatDecoded;
      } else if (chatDecoded is Map<String, dynamic> &&
          chatDecoded['items'] is List) {
        chatItems = chatDecoded['items'] as List<dynamic>;
      } else {
        chatItems = [];
      }

      List<dynamic> annItems;
      if (annDecoded is List) {
        annItems = annDecoded;
      } else if (annDecoded is Map<String, dynamic> &&
          annDecoded['items'] is List) {
        annItems = annDecoded['items'] as List<dynamic>;
      } else {
        annItems = [];
      }

      if (!mounted) return;

      setState(() {
        _chatCount = chatItems.length;
        _announcementCount = annItems.length;
        _loading = false;
      });

      _introController.forward(from: 0);
    } catch (e, st) {
      debugPrint('HOME LOAD ERROR: $e');
      debugPrint('$st');

      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить главную: $e';
      });
      _introController.forward(from: 0);
    }
  }

  void _openClientSearch() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => StaffClientSearchScreen(
              establishmentId: widget.establishmentId,
              establishmentName: widget.establishmentName,
            ),
          ),
        )
        .then((_) => _loadDashboard());
  }

  void _openChat() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => StaffChatScreen(
              establishmentId: widget.establishmentId,
              establishmentName: widget.establishmentName,
            ),
          ),
        )
        .then((_) {
      if (!mounted) return;
      setState(() {
        _chatCount = 0;
      });
      _loadDashboard();
    });
  }

  void _openAnnouncements() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => StaffAnnouncementsScreen(
              establishmentId: widget.establishmentId,
              establishmentName: widget.establishmentName,
              isOwner: _isOwner,
            ),
          ),
        )
        .then((_) {
      if (!mounted) return;
      setState(() {
        _announcementCount = 0;
      });
      _loadDashboard();
    });
  }

  void _openHistory() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => StaffEstablishmentHistoryScreen(
              establishmentId: widget.establishmentId,
              establishmentName: widget.establishmentName,
            ),
          ),
        )
        .then((_) => _loadDashboard());
  }

  void _openWorkSchedule() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => StaffWorkScheduleScreen(
              establishmentId: widget.establishmentId,
              establishmentName: widget.establishmentName,
              role: widget.role,
            ),
          ),
        )
        .then((_) => _loadDashboard());
  }

  void _openOwnerRequests() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => OwnerRequestsScreen(
              establishmentId: widget.establishmentId,
              establishmentName: widget.establishmentName,
              role: widget.role,
            ),
          ),
        )
        .then((_) => _loadDashboard());
  }

  void _openOwnerPlanner() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => OwnerSchedulePlannerScreen(
              establishmentId: widget.establishmentId,
              establishmentName: widget.establishmentName,
              role: widget.role,
            ),
          ),
        )
        .then((_) => _loadDashboard());
  }

  Widget _stagger({
    required int index,
    required Widget child,
  }) {
    final start = (index * 0.08).clamp(0.0, 0.82);
    final end = (start + 0.24).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
      parent: _introController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = animation.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - t)),
            child: Transform.scale(
              scale: 0.985 + (0.015 * t),
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackground() {
    return AnimatedBuilder(
      animation: _ambientController,
      builder: (context, child) {
        final t = _ambientController.value;
        final shiftA = math.sin(t * math.pi * 2) * 18;
        final shiftB = math.cos(t * math.pi * 2) * 12;
        final rotate = math.sin(t * math.pi * 2) * 0.03;

        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kHomeMintTop,
                    kHomeMintMid,
                    kHomeMintBottom,
                    kHomeMintDeep,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.40, 0.78, 1.0],
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.07),
                        Colors.transparent,
                        Colors.black.withOpacity(0.10),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -90 + shiftA,
              right: -40,
              child: Transform.rotate(
                angle: rotate,
                child: _softBlob(
                  width: 280,
                  height: 280,
                  colors: [
                    Colors.white.withOpacity(0.16),
                    kHomeAccent.withOpacity(0.12),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 210 + shiftB,
              left: -70,
              child: Transform.rotate(
                angle: -rotate * 0.9,
                child: _softBlob(
                  width: 220,
                  height: 220,
                  colors: [
                    Colors.white.withOpacity(0.10),
                    kHomeBlue.withOpacity(0.06),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 60 - shiftA,
              right: -20,
              child: Transform.rotate(
                angle: rotate,
                child: _softBlob(
                  width: 210,
                  height: 210,
                  colors: [
                    kHomeAccentSoft.withOpacity(0.10),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
              ),
            ),
          ],
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

  Widget _buildTopBar() {
    return Row(
      children: [
        const SizedBox(
          width: 72,
          height: 72,
          child: Center(
            child: StaffLogoBadge(size: 54),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.establishmentName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.9,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.white.withOpacity(0.12),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: Text(
                  _roleLabel,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        _TopIconButton(
          icon: CupertinoIcons.refresh,
          onTap: _loadDashboard,
        ),
        const SizedBox(width: 8),
        _TopIconButton(
          icon: Icons.logout_rounded,
          onTap: () => AuthSession.logout(context),
        ),
      ],
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [
            Color(0x1FFFFFFF),
            Color(0x14FFFFFF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      colors: [kHomeAccent, kHomeAccentSoft],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kHomeAccent.withOpacity(0.30),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    _isOwner ? 'РЕЖИМ ВЛАДЕЛЬЦА' : 'ГЛАВНЫЙ ЭКРАН',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _isOwner ? 'Управление\nзаведением' : 'Быстрая работа\nс клиентами',
                  style: const TextStyle(
                    fontSize: 29,
                    height: 1.02,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isOwner
                      ? 'Согласования, график, объявления, история и контроль команды.'
                      : 'Поиск, чат, объявления и история — всё под рукой.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.84),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          const _DecorPercent(),
        ],
      ),
    );
  }

  Widget _buildSearchHeroCard() {
    return _Pressable(
      onTap: _openClientSearch,
      borderRadius: 34,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.11),
              blurRadius: 26,
              offset: const Offset(0, 18),
            ),
            BoxShadow(
              color: kHomeAccent.withOpacity(0.22),
              blurRadius: 30,
              spreadRadius: -4,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.96),
                    Colors.white.withOpacity(0.82),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white.withOpacity(0.94)),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -18,
                    right: -4,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Container(
                        width: 126,
                        height: 126,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              kHomeAccent.withOpacity(0.18),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -12,
                    right: -12,
                    bottom: 46,
                    child: IgnorePointer(
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                        child: Container(
                          height: 110,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                kHomeMintTop.withOpacity(0.05),
                                Colors.white.withOpacity(0.10),
                                Colors.white.withOpacity(0.0),
                              ],
                              stops: const [0.0, 0.45, 0.78, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: const LinearGradient(
                                colors: [kHomeAccent, kHomeAccentSoft],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: kHomeAccent.withOpacity(0.28),
                                  blurRadius: 14,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Text(
                              _roleLabel.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: kHomeInk.withOpacity(0.06),
                            ),
                            child: Icon(
                              _isOwner
                                  ? CupertinoIcons.person_2_fill
                                  : CupertinoIcons.search,
                              size: 26,
                              color: kHomeInk,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _isOwner ? 'Клиенты и команда' : 'Найти клиента',
                        style: const TextStyle(
                          fontSize: 31,
                          height: 1.02,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                          color: kHomeInk,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isOwner
                            ? 'Главная быстрая точка входа владельца: работа с клиентами и контроль процессов.'
                            : 'Главное действие на экране.\nБыстрый поиск по телефону, имени или номеру клиента.',
                        style: const TextStyle(
                          fontSize: 14.5,
                          height: 1.42,
                          fontWeight: FontWeight.w700,
                          color: kHomeInkSoft,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        height: 60,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          color: Colors.white.withOpacity(0.94),
                          border: Border.all(
                            color: const Color(0xFFE7EEF0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isOwner
                                  ? CupertinoIcons.person_2_fill
                                  : CupertinoIcons.search,
                              color: kHomeInkSoft,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _isOwner
                                    ? 'Клиенты, начисления, списания, награды'
                                    : 'Телефон, имя, номер клиента',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: kHomeInkSoft,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const _MiniActionPill(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopModulesRow() {
    return Row(
      children: [
        Expanded(
          child: _ModuleCard(
            title: 'Чат',
            subtitle: _chatCount > 0 ? 'Есть новые сообщения' : 'Все просмотрено',
            icon: CupertinoIcons.chat_bubble_2,
            glowColor: kHomeBlue,
            onTap: _openChat,
            showPulse: _chatCount > 0,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ModuleCard(
            title: 'Объявления',
            subtitle:
                _announcementCount > 0 ? 'Есть новые' : 'Все просмотрено',
            icon: CupertinoIcons.bell,
            glowColor: kHomePink,
            onTap: _openAnnouncements,
            showPulse: _announcementCount > 0,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard() {
    return _Pressable(
      onTap: _openHistory,
      borderRadius: 30,
      child: _GlassCard(
        padding: const EdgeInsets.all(18),
        radius: 30,
        child: Row(
          children: [
            const _FloatingGlyph(
              icon: CupertinoIcons.time,
              mainColor: kHomeMintTop,
              secondaryColor: kHomeBlue,
              size: 68,
              iconSize: 30,
            ),
            const SizedBox(width: 15),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'История',
                    style: TextStyle(
                      fontSize: 18.5,
                      fontWeight: FontWeight.w900,
                      color: kHomeInk,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'События и действия по заведению',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: kHomeInkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withOpacity(0.72),
                border: Border.all(color: Colors.white.withOpacity(0.72)),
              ),
              child: const Icon(
                CupertinoIcons.chevron_right,
                size: 18,
                color: kHomeInk,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkScheduleCard() {
    return _Pressable(
      onTap: _openWorkSchedule,
      borderRadius: 30,
      child: _GlassCard(
        padding: const EdgeInsets.all(18),
        radius: 30,
        child: Row(
          children: [
            const _FloatingGlyph(
              icon: CupertinoIcons.calendar,
              mainColor: kHomeViolet,
              secondaryColor: kHomeBlue,
              size: 68,
              iconSize: 30,
            ),
            const SizedBox(width: 15),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'График работы',
                    style: TextStyle(
                      fontSize: 18.5,
                      fontWeight: FontWeight.w900,
                      color: kHomeInk,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Месяц, смены и рабочие дни',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: kHomeInkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withOpacity(0.72),
                border: Border.all(color: Colors.white.withOpacity(0.72)),
              ),
              child: const Icon(
                CupertinoIcons.chevron_right,
                size: 18,
                color: kHomeInk,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerRequestsCard() {
    return _Pressable(
      onTap: _openOwnerRequests,
      borderRadius: 30,
      child: _GlassCard(
        padding: const EdgeInsets.all(18),
        radius: 30,
        child: Row(
          children: [
            const _FloatingGlyph(
              icon: CupertinoIcons.check_mark_circled,
              mainColor: kHomeAccent,
              secondaryColor: kHomePink,
              size: 68,
              iconSize: 30,
            ),
            const SizedBox(width: 15),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Согласования',
                    style: TextStyle(
                      fontSize: 18.5,
                      fontWeight: FontWeight.w900,
                      color: kHomeInk,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Графики, замены и запросы сотрудников',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: kHomeInkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withOpacity(0.72),
                border: Border.all(color: Colors.white.withOpacity(0.72)),
              ),
              child: const Icon(
                CupertinoIcons.chevron_right,
                size: 18,
                color: kHomeInk,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerPlannerCard() {
    return _Pressable(
      onTap: _openOwnerPlanner,
      borderRadius: 30,
      child: _GlassCard(
        padding: const EdgeInsets.all(18),
        radius: 30,
        child: Row(
          children: [
            const _FloatingGlyph(
              icon: CupertinoIcons.calendar_badge_plus,
              mainColor: kHomeBlue,
              secondaryColor: kHomeViolet,
              size: 68,
              iconSize: 30,
            ),
            const SizedBox(width: 15),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Заполнить график',
                    style: TextStyle(
                      fontSize: 18.5,
                      fontWeight: FontWeight.w900,
                      color: kHomeInk,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Сформировать и сохранить график месяца',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: kHomeInkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withOpacity(0.72),
                border: Border.all(color: Colors.white.withOpacity(0.72)),
              ),
              child: const Icon(
                CupertinoIcons.chevron_right,
                size: 18,
                color: kHomeInk,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipCard() {
    return _GlassCard(
      padding: const EdgeInsets.all(18),
      radius: 30,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FloatingGlyph(
            icon: CupertinoIcons.lightbulb_fill,
            mainColor: kHomeAccent,
            secondaryColor: kHomePink,
            size: 68,
            iconSize: 30,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isOwner ? 'Режим владельца' : 'Подсказка',
                  style: const TextStyle(
                    fontSize: 18.5,
                    fontWeight: FontWeight.w900,
                    color: kHomeInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isOwner
                      ? 'Сначала согласуйте пожелания, затем откройте «Заполнить график» и сохраните итоговый месяц.'
                      : 'Если появились новые сообщения или объявления, справа будет зелёная пульсация.',
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: kHomeInkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    if (_error == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFFFFF4F2).withOpacity(0.96),
        border: Border.all(color: const Color(0xFFFFD7D0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7E67).withOpacity(0.14),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(
            CupertinoIcons.exclamationmark_circle_fill,
            color: Color(0xFFE25B46),
            size: 20,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Не удалось загрузить главную',
              style: TextStyle(
                color: Color(0xFFB84C4C),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoader() {
    return const Center(
      child: SizedBox(
        width: 42,
        height: 42,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation(Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int nextIndex = 4;

    Widget staggered(Widget child) {
      final current = nextIndex;
      nextIndex += 1;
      return _stagger(index: current, child: child);
    }

    return Scaffold(
      backgroundColor: kHomeMintTop,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            _buildBackground(),
            SafeArea(
              child: _loading
                  ? _buildLoader()
                  : RefreshIndicator(
                      color: kHomeViolet,
                      backgroundColor: Colors.white,
                      onRefresh: _loadDashboard,
                      child: ListView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
                        children: [
                          _stagger(index: 0, child: _buildTopBar()),
                          const SizedBox(height: 18),
                          _stagger(index: 1, child: _buildPromoBanner()),
                          const SizedBox(height: 14),
                          _stagger(index: 2, child: _buildSearchHeroCard()),
                          const SizedBox(height: 14),
                          _stagger(index: 3, child: _buildTopModulesRow()),
                          const SizedBox(height: 16),
                          if (_error != null) ...[
                            staggered(_buildError()),
                            const SizedBox(height: 16),
                          ],
                          staggered(
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 2),
                              child: Text(
                                'Дополнительно',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (_isOwner) ...[
                            staggered(_buildOwnerRequestsCard()),
                            const SizedBox(height: 12),
                            staggered(_buildOwnerPlannerCard()),
                            const SizedBox(height: 12),
                          ],
                          staggered(_buildHistoryCard()),
                          const SizedBox(height: 12),
                          staggered(_buildWorkScheduleCard()),
                          const SizedBox(height: 12),
                          staggered(_buildTipCard()),
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

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      borderRadius: 18,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 21,
            ),
          ),
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
                kHomeCardStrong,
                kHomeCard,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: kHomeStroke),
            boxShadow: [
              BoxShadow(
                color: kHomeShadow.withOpacity(0.10),
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

class _MiniActionPill extends StatelessWidget {
  const _MiniActionPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [kHomeAccent, kHomeAccentSoft],
        ),
        boxShadow: [
          BoxShadow(
            color: kHomeAccent.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(
        CupertinoIcons.arrow_right,
        color: Colors.white,
        size: 17,
      ),
    );
  }
}

class _DecorPercent extends StatelessWidget {
  const _DecorPercent();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 108,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Colors.white.withOpacity(0.14),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 12,
            right: 10,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Text(
                '%',
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  color: kHomeAccent.withOpacity(0.97),
                  letterSpacing: -2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingGlyph extends StatelessWidget {
  final IconData icon;
  final Color mainColor;
  final Color secondaryColor;
  final double size;
  final double iconSize;

  const _FloatingGlyph({
    required this.icon,
    required this.mainColor,
    required this.secondaryColor,
    this.size = 76,
    this.iconSize = 34,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  mainColor.withOpacity(0.22),
                  secondaryColor.withOpacity(0.16),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Container(
            width: size * 0.74,
            height: size * 0.74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.86),
              boxShadow: [
                BoxShadow(
                  color: mainColor.withOpacity(0.20),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
          ),
          Container(
            width: size * 0.54,
            height: size * 0.54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [mainColor, secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: iconSize,
            ),
          ),
          Positioned(
            top: size * 0.11,
            right: size * 0.14,
            child: Container(
              width: size * 0.14,
              height: size * 0.14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.90),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color glowColor;
  final VoidCallback onTap;
  final bool showPulse;

  const _ModuleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.glowColor,
    required this.onTap,
    required this.showPulse,
  });

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      borderRadius: 30,
      child: _GlassCard(
        padding: const EdgeInsets.all(18),
        radius: 30,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _FloatingGlyph(
                  icon: icon,
                  mainColor: glowColor,
                  secondaryColor:
                      glowColor == kHomeBlue ? kHomeMintTop : kHomeViolet,
                  size: 82,
                  iconSize: 34,
                ),
                const Spacer(),
                if (showPulse) const _PulseDot(),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: kHomeInk,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.34,
                fontWeight: FontWeight.w700,
                color: kHomeInkSoft,
              ),
            ),
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
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final scale = 1.0 + (t * 1.8);
        final opacity = (1.0 - t).clamp(0.0, 1.0);

        return SizedBox(
          width: 28,
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kHomePulseGreen.withOpacity(0.35 * opacity),
                  ),
                ),
              ),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kHomePulseGreen,
                  boxShadow: [
                    BoxShadow(
                      color: kHomePulseGreen.withOpacity(0.55),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;

  const _Pressable({
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _tap() {
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: _tap,
      child: AnimatedScale(
        scale: _pressed ? 0.982 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: _pressed
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
