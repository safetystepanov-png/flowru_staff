import 'dart:convert';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../auth/data/auth_storage.dart';
import '../../../../core/config/app_config.dart';
import '../widgets/staff_glass_ui.dart';

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
  State<StaffAnnouncementsScreen> createState() => _StaffAnnouncementsScreenState();
}

class _StaffAnnouncementsScreenState extends State<StaffAnnouncementsScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<_AnnouncementItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<String> _token() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Access token not found');
    }
    return token;
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

      if (!mounted) return;

      setState(() {
        _items = raw
            .map((e) => _AnnouncementItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить объявления';
      });
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
            return AlertDialog(
              title: const Text('Новое объявление'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Заголовок',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bodyController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Текст объявления',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: pinned,
                      onChanged: (v) {
                        setLocalState(() {
                          pinned = v;
                        });
                      },
                      title: const Text('Закрепить'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          final title = titleController.text.trim();
                          final body = bodyController.text.trim();

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
                  child: const Text('Создать'),
                ),
              ],
            );
          },
        );
      },
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

  Future<void> _openDetails(_AnnouncementItem item) async {
    bool acknowledged = item.acknowledged;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      color: Colors.white.withOpacity(0.88),
                      border: Border.all(color: Colors.white.withOpacity(0.94)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (item.isPinned)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: kStaffPink.withOpacity(0.14),
                                  ),
                                  child: const Text(
                                    'Закреплено',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: kStaffInkPrimary,
                                    ),
                                  ),
                                ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(CupertinoIcons.xmark),
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
                              color: kStaffInkPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatDate(item.createdAt),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: kStaffInkSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            item.body,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: kStaffInkPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (!widget.isOwner)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                gradient: LinearGradient(
                                  colors: acknowledged
                                      ? const [Color(0xFF7B8BA3), Color(0xFF8C9AB1)]
                                      : const [kStaffBlue, kStaffViolet],
                                ),
                              ),
                              child: ElevatedButton(
                                onPressed: () {
                                  setLocalState(() {
                                    acknowledged = true;
                                  });
                                  setState(() {
                                    final idx =
                                        _items.indexWhere((e) => e.id == item.id);
                                    if (idx >= 0) {
                                      _items[idx] = _items[idx].copyWith(
                                        acknowledged: true,
                                      );
                                    }
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: Text(
                                  acknowledged ? 'Ознакомлен' : 'Отметить как ознакомлен',
                                  style: const TextStyle(
                                    color: Colors.white,
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
              ),
            );
          },
        );
      },
    );
  }

  Widget _headerCard() {
    return StaffGlassPanel(
      radius: 28,
      glowColor: kStaffViolet.withOpacity(0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.establishmentName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: kStaffInkPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.isOwner
                ? 'Ты можешь создавать объявления для сотрудников'
                : 'Здесь важные объявления от владельца',
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: kStaffInkSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stateCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return StaffGlassPanel(
      radius: 26,
      child: Column(
        children: [
          StaffGradientIcon(icon: icon, size: 24),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: kStaffInkPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: kStaffInkSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _announcementCard(_AnnouncementItem item) {
    return StaffGlassPanel(
      radius: 24,
      glowColor: item.isPinned
          ? kStaffPink.withOpacity(0.10)
          : kStaffBlue.withOpacity(0.08),
      onTap: () => _openDetails(item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (item.isPinned)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: kStaffPink.withOpacity(0.14),
                  ),
                  child: const Text(
                    'Закреплено',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: kStaffInkPrimary,
                    ),
                  ),
                ),
              if (item.isPinned) const SizedBox(width: 8),
              if (!item.acknowledged && !widget.isOwner)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: kStaffViolet,
                    boxShadow: [
                      BoxShadow(
                        color: kStaffViolet.withOpacity(0.22),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Новое',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              const Spacer(),
              const Icon(
                CupertinoIcons.chevron_right,
                color: kStaffInkPrimary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 18,
              height: 1.18,
              fontWeight: FontWeight.w900,
              color: kStaffInkPrimary,
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
              color: kStaffInkSecondary,
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
                  color: kStaffInkSecondary,
                ),
              ),
              const Spacer(),
              if (!widget.isOwner)
                Text(
                  item.acknowledged ? 'Ознакомлен' : 'Не ознакомлен',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: item.acknowledged ? kStaffBlue : kStaffViolet,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kStaffBgTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Объявления',
          style: TextStyle(
            color: kStaffInkPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        iconTheme: const IconThemeData(color: kStaffInkPrimary),
      ),
      floatingActionButton: widget.isOwner
          ? FloatingActionButton.extended(
              onPressed: _saving ? null : _showCreateDialog,
              backgroundColor: kStaffViolet,
              foregroundColor: Colors.white,
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
            )
          : null,
      body: StaffScreenBackground(
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(kStaffViolet),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _headerCard(),
                      const SizedBox(height: 14),
                      if (_error != null)
                        _stateCard(
                          icon: CupertinoIcons.exclamationmark_circle_fill,
                          title: 'Ошибка',
                          subtitle: _error!,
                        )
                      else if (_items.isEmpty)
                        _stateCard(
                          icon: CupertinoIcons.bell_fill,
                          title: 'Объявлений пока нет',
                          subtitle: widget.isOwner
                              ? 'Создай первое объявление для сотрудников'
                              : 'Когда владелец добавит объявление, оно появится здесь',
                        )
                      else
                        ..._items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _announcementCard(item),
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

class _AnnouncementItem {
  final String id;
  final String title;
  final String body;
  final bool isPinned;
  final bool acknowledged;
  final String createdAt;

  _AnnouncementItem({
    required this.id,
    required this.title,
    required this.body,
    required this.isPinned,
    required this.acknowledged,
    required this.createdAt,
  });

  factory _AnnouncementItem.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = v?.toString().toLowerCase() ?? '';
      return s == 'true' || s == '1' || s == 'yes';
    }

    return _AnnouncementItem(
      id: json['announcement_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Объявление',
      body: json['body']?.toString() ?? '',
      isPinned: parseBool(json['is_pinned']),
      acknowledged: parseBool(
        json['acknowledged'] ?? json['is_read'] ?? json['seen'],
      ),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  _AnnouncementItem copyWith({
    bool? acknowledged,
  }) {
    return _AnnouncementItem(
      id: id,
      title: title,
      body: body,
      isPinned: isPinned,
      acknowledged: acknowledged ?? this.acknowledged,
      createdAt: createdAt,
    );
  }

  String get previewBody {
    final text = body.trim();
    if (text.isEmpty) return '';
    return text;
  }
}