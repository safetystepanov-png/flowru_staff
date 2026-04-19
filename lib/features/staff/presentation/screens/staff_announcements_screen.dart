import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/data/auth_storage.dart';
import '../../../../core/config/app_config.dart';

const Color kAnnMintTop = Color(0xFF0CB7B3);
const Color kAnnMintMid = Color(0xFF08A9AB);
const Color kAnnMintBottom = Color(0xFF067D87);
const Color kAnnMintDeep = Color(0xFF055E66);

const Color kAnnAccent = Color(0xFFFFA11D);
const Color kAnnAccentSoft = Color(0xFFFFC45E);

const Color kAnnCard = Color(0xCCFFFFFF);
const Color kAnnCardStrong = Color(0xE8FFFFFF);
const Color kAnnStroke = Color(0xA6FFFFFF);

const Color kAnnInk = Color(0xFF103238);
const Color kAnnInkSoft = Color(0xFF58767D);
const Color kAnnShadow = Color(0x22062E36);

const Color kAnnBlue = Color(0xFF4E7CFF);
const Color kAnnPink = Color(0xFFFF5F8F);
const Color kAnnViolet = Color(0xFF7A63FF);
const Color kAnnDanger = Color(0xFFE35D5B);
const Color kAnnSuccess = Color(0xFF22C55E);
const Color kAnnSuccessSoft = Color(0xFF4ADE80);
const Color kAnnWarn = Color(0xFFF97316);
const Color kAnnWarnSoft = Color(0xFFFB923C);

class StaffAnnouncementsScreen extends StatefulWidget {
  final int establishmentId;
  final String establishmentName;
  final bool isOwner;

  const StaffAnnouncementsScreen({
    super.key,
    required this.establishmentId,
    required this.establishmentName,
    required this.isOwner,
  });

  @override
  State<StaffAnnouncementsScreen> createState() =>
      _StaffAnnouncementsScreenState();
}

class _StaffAnnouncementsScreenState extends State<StaffAnnouncementsScreen>
    with TickerProviderStateMixin {
  bool _loading = true;
  bool _saving = false;
  bool _deleteLoading = false;
  String? _error;
  List<_AnnouncementItem> _items = [];

  late final AnimationController _bgController;
  late final AnimationController _introController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6800),
    )..repeat();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _load();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _introController.dispose();
    super.dispose();
  }

  String get _seenAnnouncementsKey =>
      'staff_announcements_seen_marker_${widget.establishmentId}';

  Future<String> _token() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Access token not found');
    }
    return token;
  }

  String _buildLatestMarker(List<dynamic> raw) {
    if (raw.isEmpty) return '';

    String latestId = '';
    String latestCreatedAt = '';

    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item as Map);
      final id =
          map['announcement_id']?.toString() ?? map['id']?.toString() ?? '';
      final createdAt = map['created_at']?.toString() ?? '';

      if (createdAt.isEmpty && id.isEmpty) continue;

      if (latestCreatedAt.isEmpty || createdAt.compareTo(latestCreatedAt) > 0) {
        latestId = id;
        latestCreatedAt = createdAt;
      }
    }

    if (latestId.isEmpty && latestCreatedAt.isEmpty) return '';
    return '$latestId|$latestCreatedAt';
  }

  Future<void> _markAnnouncementsSeenByMarker(String marker) async {
    if (marker.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_seenAnnouncementsKey, marker);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await _token();
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/api/v1/staff/announcements?establishment_id=${widget.establishmentId}',
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          'announcements failed: ${response.statusCode} ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);

      List<dynamic> raw;
      if (decoded is List) {
        raw = decoded;
      } else if (decoded is Map<String, dynamic> && decoded['items'] is List) {
        raw = decoded['items'] as List<dynamic>;
      } else {
        raw = [];
      }

      final latestMarker = _buildLatestMarker(raw);
      await _markAnnouncementsSeenByMarker(latestMarker);

      if (!mounted) return;

      setState(() {
        _items = raw
            .map((e) => _AnnouncementItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });

      _introController.forward(from: 0);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить объявления';
      });
      _introController.forward(from: 0);
    }
  }

  Future<void> _showCreateDialog() async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    bool pinned = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: Colors.white.withOpacity(0.94),
                      border: Border.all(color: Colors.white.withOpacity(0.96)),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Новое объявление',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: kAnnInk,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Создай объявление для сотрудников заведения',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                              color: kAnnInkSoft,
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: titleController,
                            decoration: _dialogInputDecoration('Заголовок'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: bodyController,
                            maxLines: 5,
                            decoration: _dialogInputDecoration(
                              'Текст объявления',
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: kAnnAccent.withOpacity(0.08),
                            ),
                            child: SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              value: pinned,
                              onChanged: (v) {
                                setLocalState(() {
                                  pinned = v;
                                });
                              },
                              activeColor: kAnnAccent,
                              title: const Text(
                                'Закрепить',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: kAnnInk,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  child: const Text(
                                    'Отмена',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: kAnnInkSoft,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    gradient: const LinearGradient(
                                      colors: [kAnnAccent, kAnnAccentSoft],
                                    ),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _saving
                                        ? null
                                        : () async {
                                            final title =
                                                titleController.text.trim();
                                            final body =
                                                bodyController.text.trim();

                                            if (title.isEmpty || body.isEmpty) {
                                              return;
                                            }

                                            Navigator.of(dialogContext).pop();
                                            await _createAnnouncement(
                                              title: title,
                                              body: body,
                                              pinned: pinned,
                                            );
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    child: const Text(
                                      'Создать',
                                      style: TextStyle(
                                        color: Colors.white,
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

  InputDecoration _dialogInputDecoration(
    String label, {
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      alignLabelWithHint: alignLabelWithHint,
      labelStyle: const TextStyle(
        color: kAnnInkSoft,
        fontWeight: FontWeight.w700,
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.92),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFE7EEF0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFE7EEF0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(
          color: kAnnAccent,
          width: 1.4,
        ),
      ),
    );
  }

  Future<void> _createAnnouncement({
    required String title,
    required String body,
    required bool pinned,
  }) async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final token = await _token();

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/staff/announcements'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'establishment_id': widget.establishmentId,
          'title': title,
          'body': body,
          'is_pinned': pinned,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'create announcement failed: ${response.statusCode} ${response.body}',
        );
      }

      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось создать объявление';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _acknowledgeAnnouncement(_AnnouncementItem item) async {
    try {
      final token = await _token();

      final response = await http.post(
        Uri.parse(
          '${AppConfig.baseUrl}/api/v1/staff/announcements/${item.id}/acknowledge',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'establishment_id': widget.establishmentId,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'acknowledge failed: ${response.statusCode} ${response.body}',
        );
      }

      if (!mounted) return;

      setState(() {
        final idx = _items.indexWhere((e) => e.id == item.id);
        if (idx >= 0) {
          _items[idx] = _items[idx].copyWith(
            acknowledged: true,
            acknowledgedCount: _items[idx].acknowledgedCount + 1,
          );
        }
      });
    } catch (_) {
      rethrow;
    }
  }

  Future<void> _deleteAnnouncement(_AnnouncementItem item) async {
    setState(() {
      _deleteLoading = true;
    });

    try {
      final token = await _token();

      final response = await http.delete(
        Uri.parse(
          '${AppConfig.baseUrl}/api/v1/staff/announcements/${item.id}?establishment_id=${widget.establishmentId}',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          'delete announcement failed: ${response.statusCode} ${response.body}',
        );
      }

      if (!mounted) return;

      setState(() {
        _items.removeWhere((e) => e.id == item.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Объявление удалено'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось удалить объявление'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _deleteLoading = false;
      });
    }
  }

  Future<_AnnouncementAudienceData?> _loadAudience(String announcementId) async {
    try {
      final token = await _token();

      final response = await http.get(
        Uri.parse(
          '${AppConfig.baseUrl}/api/v1/staff/announcements/$announcementId/audience?establishment_id=${widget.establishmentId}',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return _AnnouncementAudienceData.fromJson(decoded);
      }
      if (decoded is Map) {
        return _AnnouncementAudienceData.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String _formatDate(String value) {
    if (value.isEmpty) return '';
    try {
      final dt = DateTime.parse(value).toLocal();
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final hh = dt.hour.toString().padLeft(2, '0');
      final mi = dt.minute.toString().padLeft(2, '0');
      return '$dd.$mm • $hh:$mi';
    } catch (_) {
      return value;
    }
  }

  Widget _ownerStatsStrip(_AnnouncementItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: kAnnAccent.withOpacity(0.10),
        border: Border.all(color: kAnnAccent.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.person_2_fill,
            size: 18,
            color: kAnnInk,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ознакомились: ${item.acknowledgedCount}/${item.totalStaffCount}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: kAnnInk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ackUserTile(_AnnouncementAckUser user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.90),
        border: Border.all(color: const Color(0xFFE7EEF0)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kAnnSuccess.withOpacity(0.12),
            ),
            child: Center(
              child: Text(
                user.shortLabel,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: kAnnSuccess,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              user.name,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: kAnnInk,
              ),
            ),
          ),
          if (user.acknowledgedAt.isNotEmpty)
            Text(
              _formatDate(user.acknowledgedAt),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kAnnInkSoft,
              ),
            ),
        ],
      ),
    );
  }

  Widget _pendingUserTile(_AnnouncementPendingUser user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.90),
        border: Border.all(color: const Color(0xFFE7EEF0)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kAnnWarn.withOpacity(0.12),
            ),
            child: Center(
              child: Text(
                user.shortLabel,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: kAnnWarn,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              user.name,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: kAnnInk,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: kAnnWarn.withOpacity(0.10),
            ),
            child: const Text(
              'Не ознакомлен',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: kAnnWarn,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          colors: [kAnnAccent, kAnnAccentSoft],
        ),
        boxShadow: [
          BoxShadow(
            color: kAnnAccent.withOpacity(0.22),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Text(
        'Закреплено',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }

  Future<void> _openDetails(_AnnouncementItem item) async {
    bool acknowledged = item.acknowledged;
    bool actionLoading = false;
    bool audienceLoading = widget.isOwner;
    _AnnouncementAudienceData? audienceData;

    if (widget.isOwner) {
      audienceData = await _loadAudience(item.id);
      audienceLoading = false;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> reloadAudience() async {
              if (!widget.isOwner) return;
              setLocalState(() {
                audienceLoading = true;
              });
              final loaded = await _loadAudience(item.id);
              if (!mounted) return;
              setLocalState(() {
                audienceData = loaded;
                audienceLoading = false;
              });
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: Colors.white.withOpacity(0.92),
                      border: Border.all(color: Colors.white.withOpacity(0.96)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (item.isPinned) _buildPinnedBadge(),
                                const Spacer(),
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(
                                    CupertinoIcons.xmark,
                                    color: kAnnInk,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 24,
                                height: 1.12,
                                fontWeight: FontWeight.w900,
                                color: kAnnInk,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatDate(item.createdAt),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: kAnnInkSoft,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              item.body,
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: kAnnInk,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 18),
                            if (widget.isOwner) ...[
                              _ownerStatsStrip(
                                audienceData == null
                                    ? item
                                    : item.copyWith(
                                        acknowledgedCount:
                                            audienceData!.acknowledgedCount,
                                        totalStaffCount:
                                            audienceData!.totalStaffCount,
                                      ),
                              ),
                              const SizedBox(height: 14),
                              if (audienceLoading)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    color: Colors.white.withOpacity(0.92),
                                    border: Border.all(
                                      color: const Color(0xFFE7EEF0),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          valueColor:
                                              AlwaysStoppedAnimation(kAnnViolet),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Загружаем список сотрудников...',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: kAnnInkSoft,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else ...[
                                const Text(
                                  'Ознакомились',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: kAnnInk,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if ((audienceData?.acknowledgedUsers.length ?? 0) >
                                    0)
                                  ...audienceData!.acknowledgedUsers
                                      .map(_ackUserTile)
                                else if (item.ackUsers.isNotEmpty)
                                  ...item.ackUsers.map(_ackUserTile)
                                else
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      color: Colors.white.withOpacity(0.90),
                                      border:
                                          Border.all(color: const Color(0xFFE7EEF0)),
                                    ),
                                    child: const Text(
                                      'Пока никто не ознакомился.',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        height: 1.4,
                                        fontWeight: FontWeight.w700,
                                        color: kAnnInkSoft,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 14),
                                const Text(
                                  'Не ознакомились',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: kAnnInk,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if ((audienceData?.pendingUsers.length ?? 0) > 0)
                                  ...audienceData!.pendingUsers
                                      .map(_pendingUserTile)
                                else
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      color: Colors.white.withOpacity(0.90),
                                      border:
                                          Border.all(color: const Color(0xFFE7EEF0)),
                                    ),
                                    child: const Text(
                                      'Все сотрудники уже ознакомились.',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        height: 1.4,
                                        fontWeight: FontWeight.w700,
                                        color: kAnnInkSoft,
                                      ),
                                    ),
                                  ),
                              ],
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: audienceLoading
                                          ? null
                                          : () => reloadAudience(),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        side: BorderSide(
                                          color: kAnnAccent.withOpacity(0.24),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                        ),
                                      ),
                                      child: const Text(
                                        'Обновить список',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: kAnnInk,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        gradient: const LinearGradient(
                                          colors: [kAnnAccent, kAnnAccentSoft],
                                        ),
                                      ),
                                      child: ElevatedButton(
                                        onPressed: _deleteLoading
                                            ? null
                                            : () async {
                                                Navigator.of(context).pop();
                                                await _deleteAnnouncement(item);
                                              },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                          ),
                                        ),
                                        child: _deleteLoading
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2.2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Text(
                                                'Удалить',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: LinearGradient(
                                    colors: acknowledged
                                        ? const [
                                            kAnnSuccess,
                                            kAnnSuccessSoft,
                                          ]
                                        : const [
                                            kAnnAccent,
                                            kAnnAccentSoft,
                                          ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (acknowledged
                                              ? kAnnSuccess
                                              : kAnnAccent)
                                          .withOpacity(0.24),
                                      blurRadius: 14,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: actionLoading || acknowledged
                                      ? null
                                      : () async {
                                          setLocalState(() {
                                            actionLoading = true;
                                          });

                                          try {
                                            await _acknowledgeAnnouncement(item);

                                            setLocalState(() {
                                              acknowledged = true;
                                            });

                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content:
                                                    Text('Ознакомление отмечено'),
                                                behavior:
                                                    SnackBarBehavior.floating,
                                              ),
                                            );
                                          } catch (_) {
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Не удалось отметить ознакомление',
                                                ),
                                                behavior:
                                                    SnackBarBehavior.floating,
                                              ),
                                            );
                                          } finally {
                                            if (mounted) {
                                              setLocalState(() {
                                                actionLoading = false;
                                              });
                                            }
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    minimumSize:
                                        const Size(double.infinity, 60),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 18,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: actionLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (acknowledged) ...[
                                              const Icon(
                                                CupertinoIcons.check_mark,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            Flexible(
                                              child: Text(
                                                acknowledged
                                                    ? 'Ознакомлен'
                                                    : 'Отметить как ознакомлен',
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 14.5,
                                                  height: 1.15,
                                                ),
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
                ),
              ),
            );
          },
        );
      },
    );
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
            offset: Offset(0, 22 * (1 - t)),
            child: child,
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
      animation: _bgController,
      builder: (context, child) {
        final t = _bgController.value;
        final shiftA = math.sin(t * math.pi * 2) * 18;
        final shiftB = math.cos(t * math.pi * 2) * 12;
        final rotate = math.sin(t * math.pi * 2) * 0.03;

        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kAnnMintTop,
                    kAnnMintMid,
                    kAnnMintBottom,
                    kAnnMintDeep,
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
              top: -84 + shiftA,
              right: -36,
              child: Transform.rotate(
                angle: rotate,
                child: _softBlob(
                  width: 280,
                  height: 280,
                  colors: [
                    Colors.white.withOpacity(0.16),
                    kAnnAccent.withOpacity(0.12),
                  ],
                ),
              ),
            ),
            Positioned(
              left: -64,
              top: 210 + shiftB,
              child: Transform.rotate(
                angle: -rotate,
                child: _softBlob(
                  width: 220,
                  height: 220,
                  colors: [
                    Colors.white.withOpacity(0.10),
                    kAnnBlue.withOpacity(0.07),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 48 - shiftA,
              right: -18,
              child: Transform.rotate(
                angle: rotate,
                child: _softBlob(
                  width: 210,
                  height: 210,
                  colors: [
                    kAnnAccentSoft.withOpacity(0.10),
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

  Widget _fabButton() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [kAnnAccent, kAnnAccentSoft],
        ),
        boxShadow: [
          BoxShadow(
            color: kAnnAccent.withOpacity(0.24),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: _saving ? null : _showCreateDialog,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : const Icon(CupertinoIcons.add),
        label: const Text(
          'Создать',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _stateCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return _GlassCard(
      radius: 28,
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          _EmptyOrb(icon: icon),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: kAnnInk,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: kAnnInkSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _announcementCard(_AnnouncementItem item) {
    return _Pressable(
      onTap: () => _openDetails(item),
      borderRadius: 28,
      child: _GlassCard(
        radius: 28,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (item.isPinned) _buildPinnedBadge(),
                const Spacer(),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withOpacity(0.72),
                    border: Border.all(color: Colors.white.withOpacity(0.72)),
                  ),
                  child: const Icon(
                    CupertinoIcons.chevron_right,
                    color: kAnnInk,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 18,
                height: 1.18,
                fontWeight: FontWeight.w900,
                color: kAnnInk,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.previewBody,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                height: 1.42,
                fontWeight: FontWeight.w700,
                color: kAnnInkSoft,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  _formatDate(item.createdAt),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: kAnnInkSoft,
                  ),
                ),
                const Spacer(),
                if (widget.isOwner)
                  Text(
                    '${item.acknowledgedCount}/${item.totalStaffCount}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: kAnnAccent,
                    ),
                  )
                else
                  Text(
                    item.acknowledged ? 'Ознакомлен' : 'Не ознакомлен',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: item.acknowledged ? kAnnSuccess : kAnnDanger,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAnnMintTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Объявления',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      floatingActionButton: widget.isOwner ? _fabButton() : null,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            _background(),
            SafeArea(
              top: false,
              child: _loading
                  ? const Center(
                      child: SizedBox(
                        width: 42,
                        height: 42,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation(kAnnViolet),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: kAnnViolet,
                      backgroundColor: Colors.white,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          if (_error != null)
                            _stagger(
                              index: 0,
                              child: _stateCard(
                                icon: CupertinoIcons.exclamationmark_circle_fill,
                                title: 'Ошибка',
                                subtitle: _error!,
                              ),
                            )
                          else if (_items.isEmpty)
                            _stagger(
                              index: 0,
                              child: _stateCard(
                                icon: CupertinoIcons.bell_fill,
                                title: 'Объявлений пока нет',
                                subtitle: widget.isOwner
                                    ? 'Создай первое объявление для сотрудников'
                                    : 'Когда владелец добавит объявление, оно появится здесь',
                              ),
                            )
                          else
                            ..._items.asMap().entries.map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _stagger(
                                  index: entry.key,
                                  child: _announcementCard(entry.value),
                                ),
                              ),
                            ),
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
                kAnnCardStrong,
                kAnnCard,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: kAnnStroke),
            boxShadow: [
              BoxShadow(
                color: kAnnShadow.withOpacity(0.10),
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

class _EmptyOrb extends StatelessWidget {
  final IconData icon;

  const _EmptyOrb({
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      height: 82,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  kAnnBlue.withOpacity(0.18),
                  kAnnViolet.withOpacity(0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.92),
            ),
            child: Icon(
              icon,
              color: kAnnInkSoft,
              size: 28,
            ),
          ),
        ],
      ),
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

class _AnnouncementAckUser {
  final String name;
  final String acknowledgedAt;

  const _AnnouncementAckUser({
    required this.name,
    required this.acknowledgedAt,
  });

  factory _AnnouncementAckUser.fromJson(Map<String, dynamic> json) {
    return _AnnouncementAckUser(
      name: json['name']?.toString() ??
          json['user_name']?.toString() ??
          json['full_name']?.toString() ??
          'Сотрудник',
      acknowledgedAt: json['acknowledged_at']?.toString() ?? '',
    );
  }

  String get shortLabel {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '—';
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    final single = parts.first.toUpperCase();
    return single.length >= 2 ? single.substring(0, 2) : single;
  }
}

class _AnnouncementPendingUser {
  final String name;

  const _AnnouncementPendingUser({
    required this.name,
  });

  factory _AnnouncementPendingUser.fromJson(Map<String, dynamic> json) {
    return _AnnouncementPendingUser(
      name: json['name']?.toString() ??
          json['user_name']?.toString() ??
          json['full_name']?.toString() ??
          'Сотрудник',
    );
  }

  String get shortLabel {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '—';
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    final single = parts.first.toUpperCase();
    return single.length >= 2 ? single.substring(0, 2) : single;
  }
}

class _AnnouncementAudienceData {
  final int acknowledgedCount;
  final int pendingCount;
  final int totalStaffCount;
  final List<_AnnouncementAckUser> acknowledgedUsers;
  final List<_AnnouncementPendingUser> pendingUsers;

  const _AnnouncementAudienceData({
    required this.acknowledgedCount,
    required this.pendingCount,
    required this.totalStaffCount,
    required this.acknowledgedUsers,
    required this.pendingUsers,
  });

  factory _AnnouncementAudienceData.fromJson(Map<String, dynamic> json) {
    final ackRaw = (json['acknowledged_users'] as List?) ?? const [];
    final pendingRaw = (json['pending_users'] as List?) ?? const [];

    return _AnnouncementAudienceData(
      acknowledgedCount: (json['acknowledged_count'] as num?)?.toInt() ?? 0,
      pendingCount: (json['pending_count'] as num?)?.toInt() ?? 0,
      totalStaffCount: (json['total_staff_count'] as num?)?.toInt() ?? 0,
      acknowledgedUsers: ackRaw
          .whereType<Map>()
          .map(
            (e) => _AnnouncementAckUser.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      pendingUsers: pendingRaw
          .whereType<Map>()
          .map(
            (e) => _AnnouncementPendingUser.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }
}

class _AnnouncementItem {
  final String id;
  final String title;
  final String body;
  final bool isPinned;
  final bool acknowledged;
  final String createdAt;
  final int acknowledgedCount;
  final int totalStaffCount;
  final bool canDelete;
  final List<_AnnouncementAckUser> ackUsers;

  _AnnouncementItem({
    required this.id,
    required this.title,
    required this.body,
    required this.isPinned,
    required this.acknowledged,
    required this.createdAt,
    required this.acknowledgedCount,
    required this.totalStaffCount,
    required this.canDelete,
    required this.ackUsers,
  });

  factory _AnnouncementItem.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = v?.toString().toLowerCase() ?? '';
      return s == 'true' || s == '1' || s == 'yes';
    }

    final rawUsers = (json['ack_users'] is List)
        ? json['ack_users'] as List<dynamic>
        : (json['acknowledged_users'] is List)
            ? json['acknowledged_users'] as List<dynamic>
            : const <dynamic>[];

    return _AnnouncementItem(
      id: json['announcement_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Объявление',
      body: json['body']?.toString() ?? '',
      isPinned: parseBool(json['is_pinned']),
      acknowledged: parseBool(
        json['acknowledged'] ??
            json['is_acknowledged'] ??
            json['is_read'] ??
            json['seen'],
      ),
      createdAt: json['created_at']?.toString() ?? '',
      acknowledgedCount: (json['acknowledged_count'] as num?)?.toInt() ?? 0,
      totalStaffCount: (json['total_staff_count'] as num?)?.toInt() ?? 0,
      canDelete: parseBool(json['can_delete']),
      ackUsers: rawUsers
          .whereType<Map>()
          .map((e) => _AnnouncementAckUser.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
    );
  }

  _AnnouncementItem copyWith({
    bool? acknowledged,
    int? acknowledgedCount,
    int? totalStaffCount,
  }) {
    return _AnnouncementItem(
      id: id,
      title: title,
      body: body,
      isPinned: isPinned,
      acknowledged: acknowledged ?? this.acknowledged,
      createdAt: createdAt,
      acknowledgedCount: acknowledgedCount ?? this.acknowledgedCount,
      totalStaffCount: totalStaffCount ?? this.totalStaffCount,
      canDelete: canDelete,
      ackUsers: ackUsers,
    );
  }

  String get previewBody {
    final text = body.trim();
    if (text.isEmpty) return '';
    return text;
  }
}