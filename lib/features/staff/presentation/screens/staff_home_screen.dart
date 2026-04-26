import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/data/auth_storage.dart' as auth_storage;
import '../../../../core/config/app_config.dart';
import '../widgets/staff_glass_ui.dart';
import 'owner_requests_screen.dart';
import 'staff_announcements_screen.dart';
import 'staff_chat_screen.dart';
import 'staff_client_search_screen.dart';
import 'staff_establishment_history_screen.dart';
import 'staff_establishments_screen.dart';
import 'staff_work_schedule_screen.dart';

const Color kHomeMintTop = Color(0xFF0A8798);
const Color kHomeMintMid = Color(0xFF16C7B5);
const Color kHomeMintBottom = Color(0xFF047B8A);
const Color kHomeMintDeep = Color(0xFF034C61);

const Color kHomeAccent = Color(0xFFFFA51E);
const Color kHomeAccentSoft = Color(0xFFFFD65A);
const Color kHomeAccentRed = Color(0xFFFF6A5E);

const Color kHomeCard = Color(0xDDF7FEFF);
const Color kHomeCardStrong = Color(0xF4FFFFFF);
const Color kHomeStroke = Color(0xBFFFFFFF);

const Color kHomeInk = Color(0xFF082F45);
const Color kHomeInkSoft = Color(0xFF55768B);
const Color kHomeShadow = Color(0x22062E36);

const Color kHomeBlue = Color(0xFF2E73FF);
const Color kHomePink = Color(0xFFFF4B9A);
const Color kHomeViolet = Color(0xFF7B55FF);
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

class _StaffHomeScreenState extends State<StaffHomeScreen> with TickerProviderStateMixin {
  bool _loading = true;
  String? _error;

  int _chatCount = 0;
  int _announcementCount = 0;
  bool _announcementsHasNew = false;

  late final AnimationController _introController;
  late final AnimationController _ambientController;

  List<_PinnedAnnouncement> _pinnedAnnouncements = <_PinnedAnnouncement>[];
  int _heroCarouselIndex = 0;
  Timer? _heroTimer;
  bool _pinActionLoading = false;

  String _latestAnnouncementMarker = '';

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

  int get _heroSlidesCount => 1 + _pinnedAnnouncements.length;

  String get _announcementsSeenKey => 'staff_announcements_seen_marker_${widget.establishmentId}';

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _persistCurrentEstablishment();
    });

    _loadDashboard();
  }

  Future<void> _persistCurrentEstablishment() async {
    await auth_storage.AuthStorage.saveSelectedEstablishment(
      establishmentId: widget.establishmentId,
      establishmentName: widget.establishmentName,
      role: widget.role,
    );
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _introController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final token = await auth_storage.AuthStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Access token not found');
    }
    return token;
  }

  Future<String?> _getSeenAnnouncementsMarker() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_announcementsSeenKey);
  }

  Future<void> _markAnnouncementsAsSeen() async {
    if (_latestAnnouncementMarker.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_announcementsSeenKey, _latestAnnouncementMarker);

    if (!mounted) return;
    setState(() {
      _announcementsHasNew = false;
    });
  }

  String _buildLatestAnnouncementMarker(List<dynamic> annItems) {
    if (annItems.isEmpty) return '';

    String latestId = '';
    String latestCreatedAt = '';

    for (final raw in annItems) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw as Map);
      final id = map['announcement_id']?.toString() ?? map['id']?.toString() ?? '';
      final createdAt = map['created_at']?.toString() ?? '';
      if (id.isEmpty && createdAt.isEmpty) continue;

      if (latestCreatedAt.isEmpty || createdAt.compareTo(latestCreatedAt) > 0) {
        latestId = id;
        latestCreatedAt = createdAt;
      }
    }

    if (latestId.isEmpty && latestCreatedAt.isEmpty) return '';
    return '$latestId|$latestCreatedAt';
  }

  Route<T> _buildAnimatedRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
        final slide = Tween<Offset>(
          begin: const Offset(0.06, 0.03),
          end: Offset.zero,
        ).animate(curved);
        final scale = Tween<double>(
          begin: 0.965,
          end: 1.0,
        ).animate(curved);

        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: slide,
            child: ScaleTransition(
              scale: scale,
              child: child,
            ),
          ),
        );
      },
    );
  }

  void _restartHeroTimer() {
    _heroTimer?.cancel();

    if (_heroSlidesCount <= 1) return;

    _heroTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted || _heroSlidesCount <= 1) return;
      setState(() {
        _heroCarouselIndex = (_heroCarouselIndex + 1) % _heroSlidesCount;
      });
    });
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

      final pinnedUri = Uri.parse(
        '${AppConfig.baseUrl}/api/v1/staff/announcements/pinned?establishment_id=${widget.establishmentId}',
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
        http.get(
          pinnedUri,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      ]);

      final chatResponse = responses[0];
      final annResponse = responses[1];
      final pinnedResponse = responses[2];

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
      if (pinnedResponse.statusCode != 200) {
        throw Exception(
          'pinned announcements failed: ${pinnedResponse.statusCode} body=${pinnedResponse.body}',
        );
      }

      final chatDecoded = jsonDecode(chatResponse.body);
      final annDecoded = jsonDecode(annResponse.body);
      final pinnedDecoded = jsonDecode(pinnedResponse.body);

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

      List<dynamic> pinnedItems;
      if (pinnedDecoded is List) {
        pinnedItems = pinnedDecoded;
      } else if (pinnedDecoded is Map<String, dynamic> && pinnedDecoded['items'] is List) {
        pinnedItems = pinnedDecoded['items'] as List<dynamic>;
      } else {
        pinnedItems = [];
      }

      final pinned = pinnedItems
          .whereType<Map>()
          .map((e) => _PinnedAnnouncement.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList();

      final latestMarker = _buildLatestAnnouncementMarker(annItems);
      final seenMarker = await _getSeenAnnouncementsMarker();
      final hasNewAnnouncements = latestMarker.isNotEmpty && latestMarker != seenMarker;

      if (!mounted) return;

      setState(() {
        _chatCount = chatItems.length;
        _announcementCount = annItems.length;
        _announcementsHasNew = hasNewAnnouncements;
        _latestAnnouncementMarker = latestMarker;
        _pinnedAnnouncements = pinned;
        if (_heroCarouselIndex >= _heroSlidesCount) {
          _heroCarouselIndex = 0;
        }
        _loading = false;
      });

      _restartHeroTimer();
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

  Future<void> _acknowledgePinned(_PinnedAnnouncement item) async {
    if (_pinActionLoading || _isOwner || item.isAcknowledged) return;

    setState(() {
      _pinActionLoading = true;
    });

    try {
      final token = await _token();

      final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/v1/staff/announcements/${item.announcementId}/acknowledge',
      );

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'establishment_id': widget.establishmentId,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'ack failed: ${response.statusCode} body=${response.body}',
        );
      }

      if (!mounted) return;

      setState(() {
        _pinnedAnnouncements = _pinnedAnnouncements.map((e) {
          if (e.announcementId != item.announcementId) return e;
          return e.copyWith(
            isAcknowledged: true,
            acknowledgedCount: e.acknowledgedCount + 1,
          );
        }).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ознакомление отмечено'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось отметить ознакомление: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _pinActionLoading = false;
      });
    }
  }

  void _openEstablishmentPicker() {
    Navigator.of(context).pushReplacement(
      _buildAnimatedRoute(
        const StaffEstablishmentsScreen(forceChooser: true),
      ),
    );
  }

  void _openClientSearch() {
    Navigator.of(context)
        .push(
          _buildAnimatedRoute(
            StaffClientSearchScreen(
              establishmentId: widget.establishmentId,
              establishmentName: widget.establishmentName,
            ),
          ),
        )
        .then((_) => _loadDashboard());
  }

  void _openMessenger() {
    Navigator.of(context)
        .push(
          _buildAnimatedRoute(
            StaffChatScreen(
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
    _markAnnouncementsAsSeen();

    Navigator.of(context)
        .push(
          _buildAnimatedRoute(
            StaffAnnouncementsScreen(
              establishmentId: widget.establishmentId,
              establishmentName: widget.establishmentName,
              isOwner: _isOwner,
            ),
          ),
        )
        .then((_) {
      if (!mounted) return;
      _loadDashboard();
    });
  }

  void _openHistory() {
    Navigator.of(context)
        .push(
          _buildAnimatedRoute(
            StaffEstablishmentHistoryScreen(
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
          _buildAnimatedRoute(
            StaffWorkScheduleScreen(
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
          _buildAnimatedRoute(
            OwnerRequestsScreen(
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
        final size = MediaQuery.of(context).size;
        final t = _ambientController.value;
        final shiftA = math.sin(t * math.pi * 2) * 26;
        final shiftB = math.cos(t * math.pi * 2) * 18;
        final rotate = math.sin(t * math.pi * 2) * 0.035;

        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF056D85),
                    Color(0xFF17BFB5),
                    Color(0xFFD8FFE0),
                    Color(0xFF0799A6),
                    Color(0xFF044B62),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.30, 0.52, 0.72, 1.0],
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.70, -0.95),
                      radius: 1.16,
                      colors: [
                        Colors.white.withOpacity(0.58),
                        Colors.white.withOpacity(0.10),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.36, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.96, 0.88),
                      radius: 0.95,
                      colors: [
                        kHomeBlue.withOpacity(0.26),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -105 + shiftA,
              right: -70 + shiftB,
              child: Transform.rotate(
                angle: rotate,
                child: _softBlob(
                  width: 340,
                  height: 340,
                  colors: [
                    Colors.white.withOpacity(0.42),
                    kHomeAccentSoft.withOpacity(0.18),
                  ],
                ),
              ),
            ),
            Positioned(
              left: -105 - shiftB,
              bottom: 30 + shiftA,
              child: Transform.rotate(
                angle: -rotate * 0.9,
                child: _softBlob(
                  width: 310,
                  height: 310,
                  colors: [
                    kHomeBlue.withOpacity(0.30),
                    Colors.white.withOpacity(0.12),
                  ],
                ),
              ),
            ),
            Positioned(
              top: size.height * 0.36 + shiftB,
              left: size.width * 0.06 + shiftA,
              child: _softBlob(
                width: 190,
                height: 190,
                colors: [
                  kHomePink.withOpacity(0.12),
                  Colors.transparent,
                ],
              ),
            ),
            Positioned(
              right: -46,
              bottom: size.height * 0.30,
              child: Opacity(
                opacity: 0.22,
                child: Container(
                  width: 118,
                  height: 118,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.32), width: 2),
                  ),
                ),
              ),
            ),
            ...List.generate(16, (i) {
              final angle = (i / 16) * math.pi * 2 + t * math.pi * 0.28;
              final distance = 145 + 110 * ((i % 5) / 5) + 20 * math.sin(t * math.pi * 2 + i);
              final sizeDot = 3.0 + (i % 4) * 1.4;
              final opacity = (0.13 + 0.22 * math.sin(t * math.pi * 2 + i * 0.45).abs()).clamp(0.08, 0.36);
              final dotColor = [Colors.white, kHomeAccentSoft, const Color(0xFFC9FFF0)][i % 3];

              return Positioned(
                left: (size.width / 2 + math.cos(angle) * distance - sizeDot / 2).clamp(0, size.width),
                top: (size.height / 2 + math.sin(angle) * distance - sizeDot / 2).clamp(0, size.height),
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: sizeDot,
                    height: sizeDot,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor,
                      boxShadow: [
                        BoxShadow(
                          color: dotColor.withOpacity(0.48),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
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
        imageFilter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(
          width: 76,
          height: 76,
          child: Center(
            child: StaffLogoBadge(size: 68),
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Text(
            'Flowru',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.8,
              color: Colors.white,
              height: 1.0,
              shadows: [
                Shadow(
                  color: Color(0x66042D3C),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
          ),
        ),
        _TopIconButton(
          icon: CupertinoIcons.building_2_fill,
          onTap: _openEstablishmentPicker,
        ),
        const SizedBox(width: 10),
        _TopIconButton(
          icon: CupertinoIcons.refresh,
          onTap: _loadDashboard,
        ),
        const SizedBox(width: 10),
        _TopIconButton(
          icon: Icons.logout_rounded,
          onTap: () async {
            await auth_storage.AuthStorage.clearAll();
            if (!context.mounted) return;
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          },
        ),
      ],
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      key: const ValueKey('hero_promo_banner'),
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.18),
            Colors.white.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.64),
          width: 1.7,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.25),
            blurRadius: 22,
            offset: const Offset(0, 0),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -34,
            top: 12,
            child: _OrbitRings(size: 210),
          ),
          Positioned(
            right: 4,
            top: 62,
            child: const _DecorPercent(),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 236,
                height: 40,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    colors: [kHomeAccent, kHomeAccentSoft],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.55),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kHomeAccent.withOpacity(0.36),
                      blurRadius: 18,
                      offset: const Offset(0, 9),
                    ),
                  ],
                ),
                child: Text(
                  _isOwner ? 'РЕЖИМ ВЛАДЕЛЬЦА' : 'ГЛАВНЫЙ ЭКРАН',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              const Text(
                'Быстрая работа\nс клиентами',
                style: TextStyle(
                  fontSize: 42,
                  height: 1.04,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Color(0x66042D3C),
                      blurRadius: 14,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: 320,
                child: Text(
                  _isOwner
                      ? 'Поиск, начисления, списания, награды и ключевые действия по заведению.'
                      : 'Поиск, чат, объявления и история\n— всё под рукой.',
                  style: TextStyle(
                    fontSize: 19,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withOpacity(0.90),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedAnnouncementBanner(_PinnedAnnouncement item, int index) {
    return Container(
      key: ValueKey('hero_pinned_${item.announcementId}_$index'),
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.18),
            Colors.white.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.64),
          width: 1.7,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.25),
            blurRadius: 22,
            offset: const Offset(0, 0),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 236,
                  height: 40,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      colors: [kHomeAccent, kHomeAccentSoft],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.55),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kHomeAccent.withOpacity(0.36),
                        blurRadius: 18,
                        offset: const Offset(0, 9),
                      ),
                    ],
                  ),
                  child: Text(
                    _isOwner ? 'ОБЪЯВЛЕНИЕ' : 'ВАЖНОЕ ОБЪЯВЛЕНИЕ',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 38,
                    height: 1.04,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Color(0x66042D3C),
                        blurRadius: 14,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Text(
                    item.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withOpacity(0.90),
                    ),
                  ),
                ),
                if (_isOwner)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white.withOpacity(0.16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.18),
                      ),
                    ),
                    child: Text(
                      'Ознакомлены: ${item.acknowledgedCount}/${item.totalStaffCount}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  _PinnedAccentPillButton(
                    text: 'Ознакомлен',
                    isLoading: _pinActionLoading,
                    isDone: item.isAcknowledged,
                    onTap: item.isAcknowledged
                        ? null
                        : () => _acknowledgePinned(item),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          const _DecorAnnouncement(),
        ],
      ),
    );
  }

  Widget _buildHeroCarousel() {
    Widget child;

    if (_heroCarouselIndex == 0) {
      child = _buildPromoBanner();
    } else {
      final pinned = _pinnedAnnouncements[_heroCarouselIndex - 1];
      child = _buildPinnedAnnouncementBanner(pinned, _heroCarouselIndex);
    }

    return SizedBox(
      width: double.infinity,
      height: 340,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 760),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          final slide = Tween<Offset>(
            begin: const Offset(0.10, 0.0),
            end: Offset.zero,
          ).animate(fade);
          final scale = Tween<double>(
            begin: 0.955,
            end: 1.0,
          ).animate(fade);

          return FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: slide,
              child: ScaleTransition(
                scale: scale,
                child: child,
              ),
            ),
          );
        },
        child: child,
      ),
    );
  }

  Widget _buildSearchHeroCard() {
    return _Pressable(
      onTap: _openClientSearch,
      borderRadius: 38,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(38),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 30,
              offset: const Offset(0, 18),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.26),
              blurRadius: 20,
              spreadRadius: 1,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(38),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(26, 28, 26, 26),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(38),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.96),
                    const Color(0xFFEFFFFF).withOpacity(0.86),
                    Colors.white.withOpacity(0.74),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white.withOpacity(0.92), width: 1.5),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -20,
                    right: -4,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Container(
                        width: 136,
                        height: 136,
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: const LinearGradient(colors: [kHomeAccent, kHomeAccentSoft]),
                              border: Border.all(color: Colors.white.withOpacity(0.55), width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: kHomeAccent.withOpacity(0.34),
                                  blurRadius: 18,
                                  offset: const Offset(0, 9),
                                ),
                              ],
                            ),
                            child: Text(
                              _roleLabel.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.0,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 66,
                            height: 66,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              color: Colors.white.withOpacity(0.54),
                              border: Border.all(color: Colors.white.withOpacity(0.76), width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 14,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              CupertinoIcons.search,
                              size: 34,
                              color: kHomeInk,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 34),
                      const Text(
                        'Найти клиента',
                        style: TextStyle(
                          fontSize: 42,
                          height: 1.02,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.4,
                          color: kHomeInk,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _isOwner
                            ? 'Главное действие владельца на экране.\nБыстрый вход в работу с клиентом.'
                            : 'Главное действие на экране.\nБыстрый поиск по телефону, имени\nили номеру клиента.',
                        style: const TextStyle(
                          fontSize: 20,
                          height: 1.34,
                          fontWeight: FontWeight.w700,
                          color: kHomeInkSoft,
                        ),
                      ),
                      const SizedBox(height: 26),
                      Container(
                        height: 76,
                        padding: const EdgeInsets.fromLTRB(20, 0, 10, 0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          color: Colors.white.withOpacity(0.72),
                          border: Border.all(color: Colors.white.withOpacity(0.92), width: 1.4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.white.withOpacity(0.44),
                              blurRadius: 10,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              CupertinoIcons.search,
                              color: kHomeInkSoft,
                              size: 31,
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Телефон, имя, номер клиента',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: kHomeInkSoft,
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            _MiniActionPill(),
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
            subtitle: '',
            icon: CupertinoIcons.chat_bubble_2_fill,
            glowColor: kHomeBlue,
            onTap: _openMessenger,
            showPulse: _chatCount > 0,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _ModuleCard(
            title: 'Объявления',
            subtitle: '',
            icon: CupertinoIcons.bell,
            glowColor: kHomeViolet,
            onTap: _openAnnouncements,
            showPulse: _announcementsHasNew,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard() {
    return _Pressable(
      onTap: _openHistory,
      borderRadius: 32,
      child: _GlassCard(
        padding: const EdgeInsets.all(20),
        radius: 32,
        child: Row(
          children: [
            const _FloatingGlyph(
              icon: CupertinoIcons.time,
              mainColor: kHomeMintTop,
              secondaryColor: kHomeBlue,
              size: 74,
              iconSize: 32,
            ),
            const SizedBox(width: 17),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'История',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: kHomeInk,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'События и действия по заведению',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: kHomeInkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _ChevronGlassButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkScheduleCard() {
    return _Pressable(
      onTap: _openWorkSchedule,
      borderRadius: 32,
      child: _GlassCard(
        padding: const EdgeInsets.all(20),
        radius: 32,
        child: Row(
          children: [
            const _FloatingGlyph(
              icon: CupertinoIcons.calendar,
              mainColor: kHomeViolet,
              secondaryColor: kHomeBlue,
              size: 74,
              iconSize: 32,
            ),
            const SizedBox(width: 17),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'График работы',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: kHomeInk,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Месяц, смены и рабочие дни',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: kHomeInkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _ChevronGlassButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerRequestsCard() {
    return _Pressable(
      onTap: _openOwnerRequests,
      borderRadius: 32,
      child: _GlassCard(
        padding: const EdgeInsets.all(20),
        radius: 32,
        child: Row(
          children: [
            const _FloatingGlyph(
              icon: CupertinoIcons.check_mark_circled,
              mainColor: kHomeAccent,
              secondaryColor: kHomePink,
              size: 74,
              iconSize: 32,
            ),
            const SizedBox(width: 17),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'График и согласования',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: kHomeInk,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Запросы сотрудников, замены и публикация графика',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: kHomeInkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _ChevronGlassButton(),
          ],
        ),
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
    int nextIndex = 0;

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
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        children: [
                          staggered(_buildTopBar()),
                          const SizedBox(height: 22),
                          staggered(_buildHeroCarousel()),
                          const SizedBox(height: 18),
                          staggered(_buildSearchHeroCard()),
                          const SizedBox(height: 18),
                          staggered(_buildTopModulesRow()),
                          const SizedBox(height: 18),
                          if (_error != null) ...[
                            staggered(_buildError()),
                            const SizedBox(height: 18),
                          ],
                          staggered(
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 2),
                              child: Text(
                                'Дополнительно',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: Color(0x66042D3C),
                                      blurRadius: 10,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (_isOwner) ...[
                            staggered(_buildOwnerRequestsCard()),
                            const SizedBox(height: 12),
                          ],
                          staggered(_buildHistoryCard()),
                          const SizedBox(height: 12),
                          if (!_isOwner) ...[
                            staggered(_buildWorkScheduleCard()),
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

class _PinnedAnnouncement {
  final String announcementId;
  final String title;
  final String body;
  final bool isAcknowledged;
  final int acknowledgedCount;
  final int totalStaffCount;

  const _PinnedAnnouncement({
    required this.announcementId,
    required this.title,
    required this.body,
    required this.isAcknowledged,
    required this.acknowledgedCount,
    required this.totalStaffCount,
  });

  factory _PinnedAnnouncement.fromJson(Map<String, dynamic> json) {
    return _PinnedAnnouncement(
      announcementId: json['announcement_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Объявление',
      body: json['body']?.toString() ?? '',
      isAcknowledged: json['is_acknowledged'] == true,
      acknowledgedCount: (json['acknowledged_count'] as num?)?.toInt() ?? 0,
      totalStaffCount: (json['total_staff_count'] as num?)?.toInt() ?? 0,
    );
  }

  _PinnedAnnouncement copyWith({
    String? announcementId,
    String? title,
    String? body,
    bool? isAcknowledged,
    int? acknowledgedCount,
    int? totalStaffCount,
  }) {
    return _PinnedAnnouncement(
      announcementId: announcementId ?? this.announcementId,
      title: title ?? this.title,
      body: body ?? this.body,
      isAcknowledged: isAcknowledged ?? this.isAcknowledged,
      acknowledgedCount: acknowledgedCount ?? this.acknowledgedCount,
      totalStaffCount: totalStaffCount ?? this.totalStaffCount,
    );
  }
}

class _PinnedAccentPillButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isDone;

  const _PinnedAccentPillButton({
    required this.text,
    this.onTap,
    this.isLoading = false,
    this.isDone = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(colors: [kHomeAccent, kHomeAccentSoft]),
            border: Border.all(color: Colors.white.withOpacity(0.44), width: 1),
            boxShadow: [
              BoxShadow(
                color: kHomeAccent.withOpacity(0.28),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isDone) ...[
                      const Icon(
                        CupertinoIcons.check_mark,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      text,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
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
      borderRadius: 24,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.52), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.28),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 30,
              shadows: const [
                Shadow(
                  color: Color(0x55042D3C),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
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
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.94),
                const Color(0xFFEFFFFF).withOpacity(0.80),
                Colors.white.withOpacity(0.70),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.88), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 22,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.32),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ChevronGlassButton extends StatelessWidget {
  const _ChevronGlassButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.70),
        border: Border.all(color: Colors.white.withOpacity(0.82)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(
        CupertinoIcons.chevron_right,
        size: 20,
        color: kHomeInk,
      ),
    );
  }
}

class _MiniActionPill extends StatelessWidget {
  const _MiniActionPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(colors: [kHomeAccent, kHomeAccentSoft]),
        border: Border.all(color: Colors.white.withOpacity(0.58), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: kHomeAccent.withOpacity(0.34),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        CupertinoIcons.arrow_right,
        color: Colors.white,
        size: 30,
      ),
    );
  }
}

class _OrbitRings extends StatelessWidget {
  final double size;

  const _OrbitRings({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (int i = 0; i < 4; i++)
            Container(
              width: size - (i * 26),
              height: size - (i * 26),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.16 - i * 0.025), width: 1),
              ),
            ),
          Positioned(
            right: 20,
            top: 54,
            child: _SmallGlowDot(color: Colors.white, size: 8),
          ),
          Positioned(
            left: 28,
            bottom: 62,
            child: _SmallGlowDot(color: kHomeAccentSoft, size: 5),
          ),
          Positioned(
            right: 72,
            bottom: 22,
            child: _SmallGlowDot(color: kHomeAccentSoft, size: 6),
          ),
        ],
      ),
    );
  }
}

class _SmallGlowDot extends StatelessWidget {
  final Color color;
  final double size;

  const _SmallGlowDot({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.90),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.58), blurRadius: 12, spreadRadius: 1),
        ],
      ),
    );
  }
}

class _DecorPercent extends StatelessWidget {
  const _DecorPercent();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 124,
      height: 134,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        color: Colors.white.withOpacity(0.14),
        border: Border.all(color: Colors.white.withOpacity(0.62), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.white.withOpacity(0.24), blurRadius: 14, offset: const Offset(0, 0)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 18,
            right: 16,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.82),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.white.withOpacity(0.40), blurRadius: 14),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Text(
                '%',
                style: TextStyle(
                  fontSize: 74,
                  fontWeight: FontWeight.w900,
                  color: kHomeAccentSoft.withOpacity(0.96),
                  letterSpacing: -3,
                  shadows: [
                    Shadow(
                      color: kHomeAccent.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
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
}

class _DecorAnnouncement extends StatelessWidget {
  const _DecorAnnouncement();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 128,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        color: Colors.white.withOpacity(0.14),
        border: Border.all(color: Colors.white.withOpacity(0.50), width: 1.4),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 14,
            right: 12,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.82),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Positioned.fill(
            child: Center(
              child: Icon(
                CupertinoIcons.bell_fill,
                size: 50,
                color: Colors.white,
              ),
            ),
          ),
          Positioned(
            bottom: 18,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(999),
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
                  mainColor.withOpacity(0.20),
                  secondaryColor.withOpacity(0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Container(
            width: size * 0.78,
            height: size * 0.78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.72),
              border: Border.all(color: Colors.white.withOpacity(0.82), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: mainColor.withOpacity(0.20),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
          ),
          Container(
            width: size * 0.60,
            height: size * 0.60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [mainColor, secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: mainColor.withOpacity(0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: iconSize,
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
      borderRadius: 34,
      child: _GlassCard(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        radius: 34,
        child: SizedBox(
          height: 160,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Transform.translate(
                offset: const Offset(0, -12),
                child: _FloatingGlyph(
                  icon: icon,
                  mainColor: glowColor,
                  secondaryColor: glowColor == kHomeBlue ? kHomeMintTop : kHomePink,
                  size: 96,
                  iconSize: 42,
                ),
              ),
              const Spacer(),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: kHomeInk,
                  letterSpacing: -0.7,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.34,
                    fontWeight: FontWeight.w700,
                    color: kHomeInkSoft,
                  ),
                ),
              ],
            ],
          ),
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

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
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
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kHomePulseGreen,
                  border: Border.all(color: Colors.white.withOpacity(0.74), width: 1),
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

class _PressableState extends State<_Pressable> with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 0,
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
    if (value) {
      _glowController.forward();
    } else {
      _glowController.reverse();
    }
  }

  void _tap() {
    HapticFeedback.mediumImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glow = _glowController.value;
        return GestureDetector(
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: _tap,
          child: AnimatedScale(
            scale: _pressed ? 0.965 : 1,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: AnimatedRotation(
              turns: _pressed ? -0.003 : 0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03 + (0.03 * glow)),
                      blurRadius: 8 + (10 * glow),
                      offset: Offset(0, 3 + (4 * glow)),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
