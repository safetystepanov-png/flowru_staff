import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../auth/data/auth_session.dart';
import '../../../auth/data/auth_storage.dart';
import '../../../../core/config/app_config.dart';
import '../widgets/staff_glass_ui.dart';
import 'staff_announcements_screen.dart';
import 'staff_chat_screen.dart';
import 'staff_client_search_screen.dart';
import 'staff_establishment_history_screen.dart';

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
      duration: const Duration(milliseconds: 980),
    );

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5600),
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
        throw Exception('chat count failed');
      }
      if (annResponse.statusCode != 200) {
        throw Exception('ann count failed');
      }

      final chatDecoded = jsonDecode(chatResponse.body);
      final annDecoded = jsonDecode(annResponse.body);

      List<dynamic> chatItems;
      if (chatDecoded is List) {
        chatItems = chatDecoded;
      } else if (chatDecoded is Map<String, dynamic> && chatDecoded['items'] is List) {
        chatItems = chatDecoded['items'] as List<dynamic>;
      } else {
        chatItems = [];
      }

      List<dynamic> annItems;
      if (annDecoded is List) {
        annItems = annDecoded;
      } else if (annDecoded is Map<String, dynamic> && annDecoded['items'] is List) {
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить главную';
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

  String get _chatBadge {
    if (_chatCount <= 0) return '';
    return _chatCount > 99 ? '99+' : '$_chatCount';
  }

  String get _announcementBadge {
    if (_announcementCount <= 0) return '';
    return _announcementCount > 99 ? '99+' : '$_announcementCount';
  }

  Widget _stagger({
    required int index,
    required Widget child,
  }) {
    final start = (index * 0.09).clamp(0.0, 0.82);
    final end = (start + 0.22).clamp(0.0, 1.0);

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
            offset: Offset(0, 22 * (1 - t)),
            child: child,
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
        final shiftA = math.sin(t * math.pi * 2) * 24;
        final shiftB = math.cos(t * math.pi * 2) * 18;

        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [kStaffBgTop, kStaffBgBottom],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
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
                  kStaffBlue.withOpacity(0.11),
                  kStaffPink.withOpacity(0.05),
                ],
              ),
            ),
            Positioned(
              top: 220 + shiftB,
              left: -55,
              child: _softBlob(
                width: 210,
                height: 210,
                colors: [
                  kStaffViolet.withOpacity(0.12),
                  kStaffBlue.withOpacity(0.04),
                ],
              ),
            ),
            Positioned(
              bottom: 90 - shiftA,
              right: 8,
              child: _softBlob(
                width: 190,
                height: 190,
                colors: [
                  kStaffPink.withOpacity(0.10),
                  Colors.white.withOpacity(0.02),
                ],
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
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        const StaffLogoBadge(size: 58),
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
                  letterSpacing: -0.8,
                  color: kStaffInkPrimary,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Flowru Сотрудник',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: kStaffInkSecondary,
                ),
              ),
            ],
          ),
        ),
        _Pressable(
          onTap: _loadDashboard,
          borderRadius: 18,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.82),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: kStaffBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              CupertinoIcons.refresh,
              color: kStaffInkPrimary,
              size: 21,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _Pressable(
          onTap: () => AuthSession.logout(context),
          borderRadius: 18,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.82),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: kStaffBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.logout_rounded,
              color: kStaffInkPrimary,
              size: 21,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchHeroCard() {
    return _Pressable(
      onTap: _openClientSearch,
      borderRadius: 34,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(34),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.86),
                  Colors.white.withOpacity(0.72),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withOpacity(0.94)),
              boxShadow: [
                BoxShadow(
                  color: kStaffBlue.withOpacity(0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: kStaffPink.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
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
                        color: kStaffBlue.withOpacity(0.10),
                      ),
                      child: Text(
                        _roleLabel.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: kStaffInkPrimary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const StaffGradientIcon(
                      icon: CupertinoIcons.search_circle_fill,
                      size: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Найти клиента',
                        style: TextStyle(
                          fontSize: 30,
                          height: 1.02,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.9,
                          color: kStaffInkPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Главное действие на этом экране.\nПоиск по телефону или по данным клиента.',
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: kStaffInkSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  height: 58,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white.withOpacity(0.88),
                    border: Border.all(color: kStaffBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        CupertinoIcons.search,
                        color: kStaffInkSecondary,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Телефон, имя, номер клиента',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: kStaffInkSecondary,
                          ),
                        ),
                      ),
                      Icon(
                        CupertinoIcons.arrow_right_circle_fill,
                        color: kStaffViolet,
                        size: 24,
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

  Widget _buildTopModulesRow() {
    return Row(
      children: [
        Expanded(
          child: _ModuleCard(
            title: 'Чат',
            subtitle: _chatCount > 0 ? '$_chatBadge новых' : 'Без новых',
            icon: CupertinoIcons.chat_bubble_2_fill,
            badge: _chatCount > 0 ? _chatBadge : null,
            badgeColor: const Color(0xFFFF5F7A),
            glowColor: kStaffBlue,
            onTap: _openChat,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ModuleCard(
            title: 'Объявления',
            subtitle: _announcementCount > 0 ? 'Есть новые' : 'Пока пусто',
            icon: CupertinoIcons.bell_fill,
            badge: _announcementCount > 0 ? _announcementBadge : null,
            badgeColor: const Color(0xFF7D63FF),
            glowColor: kStaffPink,
            onTap: _openAnnouncements,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard() {
    return _Pressable(
      onTap: _openHistory,
      borderRadius: 30,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: Colors.white.withOpacity(0.68),
          border: Border.all(color: Colors.white.withOpacity(0.96)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            const StaffGradientIcon(
              icon: CupertinoIcons.time_solid,
              size: 24,
            ),
            const SizedBox(width: 15),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'История заведения',
                    style: TextStyle(
                      fontSize: 18.5,
                      fontWeight: FontWeight.w900,
                      color: kStaffInkPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Операции и события по заведению.',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: kStaffInkSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: Colors.white.withOpacity(0.82),
              ),
              child: const Icon(
                CupertinoIcons.chevron_right,
                size: 18,
                color: kStaffInkPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final hasChat = _chatCount > 0;
    final hasAnnouncements = _announcementCount > 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: Colors.white.withOpacity(0.64),
            border: Border.all(color: Colors.white.withOpacity(0.96)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Сводка',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: kStaffInkPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Состояние по основным разделам.',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: kStaffInkSecondary,
                ),
              ),
              const SizedBox(height: 16),
              _SummaryLine(
                title: 'Чат',
                subtitle: hasChat ? 'Есть новые сообщения' : 'Новых сообщений нет',
                active: hasChat,
                activeColor: kStaffBlue,
              ),
              const SizedBox(height: 12),
              _SummaryLine(
                title: 'Объявления',
                subtitle: hasAnnouncements
                    ? 'Есть активные объявления'
                    : 'Сейчас без объявлений',
                active: hasAnnouncements,
                activeColor: kStaffPink,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: kStaffInkPrimary,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: kStaffInkSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    if (_error == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFFFFF4F4),
        border: Border.all(color: const Color(0xFFFFDDDD)),
      ),
      child: const Row(
        children: [
          Icon(
            CupertinoIcons.exclamationmark_circle_fill,
            color: Color(0xFFD34D4D),
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
        width: 40,
        height: 40,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation(kStaffViolet),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kStaffBgTop,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: _loading
                ? _buildLoader()
                : RefreshIndicator(
                    color: kStaffViolet,
                    backgroundColor: Colors.white,
                    onRefresh: _loadDashboard,
                    child: ListView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      children: [
                        _stagger(index: 0, child: _buildTopBar()),
                        const SizedBox(height: 18),
                        _stagger(index: 1, child: _buildSearchHeroCard()),
                        const SizedBox(height: 14),
                        _stagger(index: 2, child: _buildTopModulesRow()),
                        const SizedBox(height: 16),
                        _stagger(index: 3, child: _buildError()),
                        if (_error != null) const SizedBox(height: 16),
                        _stagger(
                          index: 4,
                          child: _buildSectionTitle(
                            'Дополнительно',
                            'Ещё один важный рабочий раздел',
                          ),
                        ),
                        const SizedBox(height: 14),
                        _stagger(index: 5, child: _buildHistoryCard()),
                        const SizedBox(height: 22),
                        _stagger(
                          index: 6,
                          child: _buildSectionTitle(
                            'Активность',
                            'Состояние по основным разделам',
                          ),
                        ),
                        const SizedBox(height: 14),
                        _stagger(index: 7, child: _buildSummaryCard()),
                      ],
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
  final String? badge;
  final Color badgeColor;
  final Color glowColor;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badge,
    required this.badgeColor,
    required this.glowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      borderRadius: 30,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: Colors.white.withOpacity(0.72),
          border: Border.all(color: Colors.white.withOpacity(0.96)),
          boxShadow: [
            BoxShadow(
              color: glowColor.withOpacity(0.09),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: badgeColor,
                      boxShadow: [
                        BoxShadow(
                          color: badgeColor.withOpacity(0.26),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 24),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [kStaffBlue, kStaffPink],
                ),
              ),
              child: Icon(
                icon,
                size: 26,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: kStaffInkPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: kStaffInkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool active;
  final Color activeColor;

  const _SummaryLine({
    required this.title,
    required this.subtitle,
    required this.active,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : const Color(0xFFB6C6D3);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 13,
          height: 13,
          margin: const EdgeInsets.only(top: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.24),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: kStaffInkPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: kStaffInkSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}