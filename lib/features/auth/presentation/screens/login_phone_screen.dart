import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../data/auth_storage.dart';
import '../../data/user_api.dart';
import '../../../../core/config/app_config.dart';
import '../../../staff/presentation/screens/staff_establishments_screen.dart';
import 'register_screen.dart';

const Color kLoginMintTop = Color(0xFF0CB7B3);
const Color kLoginMintMid = Color(0xFF08A9AB);
const Color kLoginMintBottom = Color(0xFF067D87);
const Color kLoginMintDeep = Color(0xFF055E66);

const Color kLoginAccent = Color(0xFFFFA11D);
const Color kLoginAccentSoft = Color(0xFFFFC45E);

const Color kLoginCard = Color(0xCCFFFFFF);
const Color kLoginCardStrong = Color(0xE8FFFFFF);
const Color kLoginStroke = Color(0xA6FFFFFF);

const Color kLoginInk = Color(0xFF103238);
const Color kLoginInkSoft = Color(0xFF58767D);
const Color kLoginShadow = Color(0x22062E36);

const Color kLoginBlue = Color(0xFF4E7CFF);
const Color kLoginPink = Color(0xFFFF5F8F);
const Color kLoginViolet = Color(0xFF7A63FF);

class LoginPhoneScreen extends StatefulWidget {
  const LoginPhoneScreen({super.key});

  @override
  State<LoginPhoneScreen> createState() => _LoginPhoneScreenState();
}

class _LoginPhoneScreenState extends State<LoginPhoneScreen>
    with TickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final UserApi _userApi = UserApi();

  bool _loading = false;
  bool _showPassword = false;
  String? _error;

  late final AnimationController _introController;
  late final AnimationController _ambientController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7600),
    )..repeat();

    _fadeAnimation = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.055),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: Curves.easeOutCubic,
      ),
    );

    _introController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _introController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(
    String label, {
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffixIcon,
      labelStyle: const TextStyle(
        color: kLoginInkSoft,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF89A1A7),
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
          color: kLoginViolet,
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(
          color: Color(0xFFE85B63),
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(
          color: Color(0xFFE85B63),
          width: 1.4,
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (phone.isEmpty) {
      setState(() => _error = 'Введите номер телефона');
      return;
    }

    if (password.isEmpty) {
      setState(() => _error = 'Введите пароль');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _userApi.login(
      phone: phone,
      password: password,
      deviceId: 'staff-web',
      platform: 'web',
    );

    if (!mounted) return;

    if (!result.ok) {
      setState(() {
        _loading = false;
        _error = result.message;
      });
      return;
    }

    await AuthStorage.saveAccessToken(result.accessToken);
    await AuthStorage.saveRefreshToken(result.refreshToken);

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const StaffEstablishmentsScreen()),
      (route) => false,
    );
  }

  Future<void> _openRecoverySheet() async {
    final recoveredPhone = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PasswordRecoverySheet(),
    );

    if (!mounted) return;

    if (recoveredPhone != null && recoveredPhone.trim().isNotEmpty) {
      _phoneController.text = recoveredPhone.trim();
      _passwordController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пароль обновлён. Теперь войдите с новым паролем.'),
        ),
      );
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
        final shiftB = math.cos(t * math.pi * 2) * 14;
        final rotate = math.sin(t * math.pi * 2) * 0.03;

        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kLoginMintTop,
                    kLoginMintMid,
                    kLoginMintBottom,
                    kLoginMintDeep,
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
              top: -80 + shiftA,
              right: -36,
              child: Transform.rotate(
                angle: rotate,
                child: _softBlob(
                  width: 270,
                  height: 270,
                  colors: [
                    Colors.white.withOpacity(0.18),
                    kLoginAccent.withOpacity(0.13),
                  ],
                ),
              ),
            ),
            Positioned(
              left: -58,
              top: 210 + shiftB,
              child: Transform.rotate(
                angle: -rotate,
                child: _softBlob(
                  width: 220,
                  height: 220,
                  colors: [
                    Colors.white.withOpacity(0.10),
                    kLoginBlue.withOpacity(0.07),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 40 - shiftA,
              right: -18,
              child: Transform.rotate(
                angle: rotate,
                child: _softBlob(
                  width: 210,
                  height: 210,
                  colors: [
                    kLoginAccentSoft.withOpacity(0.10),
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

  Widget _topBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          colors: [kLoginAccent, kLoginAccentSoft],
        ),
        boxShadow: [
          BoxShadow(
            color: kLoginAccent.withOpacity(0.28),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Text(
        'FLOWRU STAFF',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _logoOrb() {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.28),
                  Colors.white.withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.92),
              boxShadow: [
                BoxShadow(
                  color: kLoginBlue.withOpacity(0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
          ),
          Image.asset(
            'assets/images/flowru_logo.png',
            width: 54,
            height: 54,
          ),
        ],
      ),
    );
  }

  Widget _prettySecondaryButton({
    required String text,
    required VoidCallback onTap,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.88),
        border: Border.all(color: Colors.white.withOpacity(0.95)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [kLoginBlue, kLoginViolet, kLoginPink],
          ).createShader(bounds),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _card() {
    return Container(
      width: 470,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 26,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: kLoginAccent.withOpacity(0.18),
            blurRadius: 28,
            spreadRadius: -4,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(34),
              gradient: LinearGradient(
                colors: [
                  kLoginCardStrong,
                  kLoginCard,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: kLoginStroke),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _topBadge(),
                const SizedBox(height: 18),
                _logoOrb(),
                const SizedBox(height: 16),
                const Text(
                  'Вход сотрудника',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 31,
                    fontWeight: FontWeight.w900,
                    color: kLoginInk,
                    letterSpacing: -0.9,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Введите номер телефона и пароль,\nчтобы открыть рабочее пространство.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    color: kLoginInkSoft,
                  ),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration(
                    'Телефон',
                    hint: '+7 978 547 30 14',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  decoration: _inputDecoration(
                    'Пароль',
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() => _showPassword = !_showPassword);
                      },
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: kLoginInkSoft,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (_error != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: const Color(0xFFFFF4F2).withOpacity(0.96),
                      border: Border.all(color: const Color(0xFFFFD7D0)),
                    ),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFE85B63),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [kLoginBlue, kLoginPink],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kLoginBlue.withOpacity(0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      minimumSize: const Size.fromHeight(58),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.3,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Войти',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _loading ? null : _openRecoverySheet,
                  child: const Text(
                    'Забыли пароль?',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: kLoginBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                _prettySecondaryButton(
                  text: 'Зарегистрироваться',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RegisterScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLoginMintTop,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            _background(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: _card(),
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
}

class _PasswordRecoverySheet extends StatefulWidget {
  const _PasswordRecoverySheet();

  @override
  State<_PasswordRecoverySheet> createState() => _PasswordRecoverySheetState();
}

class _PasswordRecoverySheetState extends State<_PasswordRecoverySheet> {
  static const String _botUsername = 'Flowru_Staff_Recovery_bot';
  static const String _botUrl = 'https://t.me/Flowru_Staff_Recovery_bot';

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _requestingCode = false;
  bool _confirming = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  String? _requestMessage;
  bool _requestSuccess = false;

  String? _confirmMessage;
  bool _confirmSuccess = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  InputDecoration _sheetInputDecoration(
    String label, {
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(
        color: kLoginInkSoft,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF89A1A7),
        fontWeight: FontWeight.w700,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE7EEF0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE7EEF0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: kLoginViolet,
          width: 1.4,
        ),
      ),
    );
  }

  Future<void> _openBot() async {
    final uri = Uri.parse(_botUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось открыть Telegram.'),
        ),
      );
    }
  }

  String _extractErrorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        final message = decoded['message'];

        if (detail is String && detail.trim().isNotEmpty) {
          return detail.trim();
        }
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } catch (_) {}

    return 'Ошибка запроса (${response.statusCode})';
  }

  Future<void> _requestCode() async {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      setState(() {
        _requestSuccess = false;
        _requestMessage = 'Введите номер телефона';
      });
      return;
    }

    setState(() {
      _requestingCode = true;
      _requestMessage = null;
      _requestSuccess = false;
    });

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/auth/password-reset/request'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'phone': phone,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        String message = 'Код отправлен';

        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            final msg = decoded['message'];
            if (msg is String && msg.trim().isNotEmpty) {
              message = msg.trim();
            }
          }
        } catch (_) {}

        setState(() {
          _requestingCode = false;
          _requestSuccess = true;
          _requestMessage = message;
        });
        return;
      }

      setState(() {
        _requestingCode = false;
        _requestSuccess = false;
        _requestMessage = _extractErrorMessage(response);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _requestingCode = false;
        _requestSuccess = false;
        _requestMessage = 'Не удалось запросить код';
      });
    }
  }

  Future<void> _confirmReset() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (phone.isEmpty) {
      setState(() {
        _confirmSuccess = false;
        _confirmMessage = 'Введите номер телефона';
      });
      return;
    }

    if (code.isEmpty) {
      setState(() {
        _confirmSuccess = false;
        _confirmMessage = 'Введите код из Telegram';
      });
      return;
    }

    if (newPassword.isEmpty) {
      setState(() {
        _confirmSuccess = false;
        _confirmMessage = 'Введите новый пароль';
      });
      return;
    }

    if (confirmPassword.isEmpty) {
      setState(() {
        _confirmSuccess = false;
        _confirmMessage = 'Подтвердите новый пароль';
      });
      return;
    }

    setState(() {
      _confirming = true;
      _confirmMessage = null;
      _confirmSuccess = false;
    });

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/auth/password-reset/confirm'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'phone': phone,
          'code': code,
          'new_password': newPassword,
          'new_password_confirm': confirmPassword,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _confirming = false;
          _confirmSuccess = true;
          _confirmMessage = 'Пароль успешно изменён';
        });

        await Future<void>.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;
        Navigator.of(context).pop(phone);
        return;
      }

      setState(() {
        _confirming = false;
        _confirmSuccess = false;
        _confirmMessage = _extractErrorMessage(response);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _confirming = false;
        _confirmSuccess = false;
        _confirmMessage = 'Не удалось изменить пароль';
      });
    }
  }

  Widget _messageBox(String text, {required bool success}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: success
            ? const Color(0xFFF0FFF6)
            : const Color(0xFFFFF4F2).withOpacity(0.96),
        border: Border.all(
          color: success
              ? const Color(0xFFB8EBC8)
              : const Color(0xFFFFD7D0),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: success ? const Color(0xFF1F8E4D) : const Color(0xFFE85B63),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottomInset),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: const Color(0xFFF8FCFD),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 32,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD7E4E8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const Spacer(),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.white,
                            border: Border.all(
                              color: const Color(0xFFE5EEF1),
                            ),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: kLoginInk,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [kLoginBlue, kLoginPink],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kLoginBlue.withOpacity(0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Восстановление пароля',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    color: kLoginInk,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Сначала откройте сервисный бот восстановления,\nнажмите Start, а потом запросите код.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    color: kLoginInkSoft,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE5EEF1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.info_rounded,
                            size: 18,
                            color: kLoginBlue,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Что нужно сделать',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: kLoginInk,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '1. Перейдите в бот восстановления',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: kLoginInkSoft,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _openBot,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: const Color(0xFFF5F8FF),
                            border: Border.all(
                              color: const Color(0xFFD9E4FF),
                            ),
                          ),
                          child: Row(
                            children: const [
                              Icon(
                                Icons.open_in_new_rounded,
                                color: kLoginBlue,
                                size: 18,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '@Flowru_Staff_Recovery_bot',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: kLoginBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '2. Внутри бота обязательно нажмите Start',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: kLoginInkSoft,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '3. Вернитесь сюда и запросите код',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: kLoginInkSoft,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openBot,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: const BorderSide(color: kLoginBlue),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.telegram, color: kLoginBlue),
                          label: const Text(
                            'Открыть бот восстановления',
                            style: TextStyle(
                              color: kLoginBlue,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _sheetInputDecoration(
                    'Телефон сотрудника',
                    hint: '+7 978 547 30 14',
                  ),
                ),
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [kLoginBlue, kLoginPink],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kLoginBlue.withOpacity(0.20),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _requestingCode ? null : _requestCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _requestingCode
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.3,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Запросить код восстановления',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
                if (_requestMessage != null) ...[
                  const SizedBox(height: 12),
                  _messageBox(
                    _requestMessage!,
                    success: _requestSuccess,
                  ),
                ],
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE5EEF1)),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        decoration: _sheetInputDecoration(
                          'Код из Telegram',
                          hint: 'Например: 123456',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _newPasswordController,
                        obscureText: !_showNewPassword,
                        decoration: _sheetInputDecoration(
                          'Новый пароль',
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _showNewPassword = !_showNewPassword;
                              });
                            },
                            icon: Icon(
                              _showNewPassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: kLoginInkSoft,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: !_showConfirmPassword,
                        decoration: _sheetInputDecoration(
                          'Подтвердите пароль',
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _showConfirmPassword = !_showConfirmPassword;
                              });
                            },
                            icon: Icon(
                              _showConfirmPassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: kLoginInkSoft,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _confirming ? null : _confirmReset,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kLoginViolet,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: _confirming
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.3,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Сменить пароль',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_confirmMessage != null) ...[
                  const SizedBox(height: 12),
                  _messageBox(
                    _confirmMessage!,
                    success: _confirmSuccess,
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}