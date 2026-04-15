import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../auth/data/auth_storage.dart';
import '../../../auth/data/user_api.dart';
import '../../../auth/presentation/screens/login_phone_screen.dart';
import '../../../staff/presentation/widgets/staff_glass_ui.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  String? _error;
  UserMe? _user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final accessToken = await AuthStorage.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('No token');
      }

      final user = await UserApi.getMe(accessToken);

      if (!mounted) return;
      setState(() {
        _user = user;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить профиль';
      });
    }
  }

  Future<void> _logout() async {
    await AuthStorage.clearAll();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginPhoneScreen(),
      ),
      (route) => false,
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

  String get _displayName {
    final name = (_user?.fullName ?? '').trim();
    if (name.isNotEmpty) return name;
    final phone = (_user?.phone ?? '').trim();
    if (phone.isNotEmpty) return phone;
    return 'Сотрудник';
  }

  String get _initials {
    final parts = _displayName
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'S';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Widget _profileCard() {
    return StaffGlassPanel(
      radius: 28,
      glowColor: kStaffBlue.withOpacity(0.10),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                colors: [kStaffBlue, kStaffViolet],
              ),
            ),
            child: Center(
              child: Text(
                _initials,
                style: const TextStyle(
                  fontSize: 26,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: kStaffInkPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _user?.phone ?? 'Телефон не указан',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kStaffInkSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoutButton() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [kStaffPink, kStaffViolet],
        ),
      ),
      child: ElevatedButton(
        onPressed: _logout,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: const Text(
          'Выйти из аккаунта',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
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
          'Профиль',
          style: TextStyle(
            color: kStaffInkPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        iconTheme: const IconThemeData(color: kStaffInkPrimary),
      ),
      body: StaffScreenBackground(
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(kStaffViolet),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    if (_error != null)
                      _stateCard(
                        icon: CupertinoIcons.exclamationmark_circle_fill,
                        title: 'Ошибка',
                        subtitle: _error!,
                      )
                    else ...[
                      _profileCard(),
                      const SizedBox(height: 16),
                      _logoutButton(),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}