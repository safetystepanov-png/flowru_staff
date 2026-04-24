import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../staff/presentation/screens/staff_establishments_screen.dart';
import '../../data/auth_storage.dart';
import '../../data/user_api.dart';
import 'register_screen.dart';

// === ЦВЕТОВАЯ ПАЛИТРА ===
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
const Color kLoginBlue = Color(0xFF4E7CFF);
const Color kLoginPink = Color(0xFFFF5F8F);
const Color kLoginViolet = Color(0xFF7A63FF);

class LoginPhoneScreen extends StatefulWidget {
  const LoginPhoneScreen({super.key});
  @override
  State<LoginPhoneScreen> createState() => _LoginPhoneScreenState();
}

class _LoginPhoneScreenState extends State<LoginPhoneScreen> with TickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final UserApi _userApi = UserApi();
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _loading = false;
  bool _showPassword = false;
  String? _error;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _biometricChecking = true;
  bool _biometricLoading = false;
  bool _hasRefreshSession = false;

  late final AnimationController _introController;
  late final AnimationController _ambientController;
  late final AnimationController _pulseController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _ambientController = AnimationController(vsync: this, duration: const Duration(milliseconds: 10000))..repeat();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _fadeAnimation = CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic));
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _initSavedLoginAndBiometric();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _introController.dispose();
    _ambientController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // === ЛОГИКА: автозаполнение телефона + биометрия ===
  Future<void> _initSavedLoginAndBiometric() async {
    final savedPhone = await AuthStorage.getSavedPhone();
    final biometricEnabled = await AuthStorage.isBiometricEnabled();
    final refreshToken = await AuthStorage.getRefreshToken();
    
    if (!mounted) return;
    
    // Автозаполнение телефона если сохранён
    if (savedPhone != null && savedPhone.trim().isNotEmpty) {
      _phoneController.text = savedPhone.trim();
    }
    
    final hasRefreshSession = refreshToken != null && refreshToken.trim().isNotEmpty;
    bool available = false;
    if (!kIsWeb) {
      try {
        final canCheck = await _localAuth.canCheckBiometrics;
        final isSupported = await _localAuth.isDeviceSupported();
        available = canCheck || isSupported;
      } catch (_) {
        available = false;
      }
    }
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _biometricEnabled = biometricEnabled;
      _hasRefreshSession = hasRefreshSession;
      _biometricChecking = false;
    });
  }

  Future<void> _enableBiometricIfPossible() async {
    if (kIsWeb || !_biometricAvailable) return;
    await AuthStorage.setBiometricEnabled(true);
    if (!mounted) return;
    setState(() => _biometricEnabled = true);
  }

  Future<void> _submitWithCredentials({required String phone, required String password, bool saveCredentials = true}) async {
    if (phone.isEmpty) { setState(() => _error = 'Введите номер телефона'); return; }
    if (password.isEmpty) { setState(() => _error = 'Введите пароль'); return; }
    setState(() { _loading = true; _error = null; });
    late final AuthResult result;
    try {
      result = await _userApi.login(phone: phone, password: password, deviceId: kIsWeb ? 'staff-web' : 'staff-mobile', platform: kIsWeb ? 'web' : 'mobile');
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Ошибка входа: $e'; });
      return;
    }
    if (!mounted) return;
    if (!result.ok) { setState(() { _loading = false; _error = result.message; }); return; }
    try {
      await AuthStorage.saveAccessToken(result.accessToken);
      await AuthStorage.saveRefreshToken(result.refreshToken);
      if (saveCredentials) {
        // Сохраняем только телефон (без пароля — безопаснее)
        await AuthStorage.savePhoneOnly(result.phone.isNotEmpty ? result.phone : phone);
        await _enableBiometricIfPossible();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Ошибка сохранения сессии: $e'; });
      return;
    }
    if (!mounted) return;
    setState(() { _loading = false; _hasRefreshSession = true; });
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const StaffEstablishmentsScreen()), (route) => false);
  }

  Future<void> _submit() async => await _submitWithCredentials(phone: _phoneController.text.trim(), password: _passwordController.text, saveCredentials: true);

  Future<void> _loginWithBiometric() async {
    if (kIsWeb) { setState(() => _error = 'Биометрия в web-версии не поддерживается'); return; }
    if (_loading || _biometricLoading) return;
    final refreshToken = await AuthStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.trim().isEmpty) { setState(() => _error = 'Нет сохранённой сессии для входа'); return; }
    setState(() { _biometricLoading = true; _error = null; });
    try {
      final authenticated = await _localAuth.authenticate(localizedReason: 'Войдите в Flowru Staff', biometricOnly: true, persistAcrossBackgrounding: true);
      if (!authenticated) { if (!mounted) return; setState(() => _biometricLoading = false); return; }
      final result = await _userApi.refresh(refreshToken: refreshToken.trim(), deviceId: kIsWeb ? 'staff-web' : 'staff-mobile', platform: kIsWeb ? 'web' : 'mobile');
      if (!mounted) return;
      if (!result.ok) { await AuthStorage.clearSessionButKeepBiometric(); setState(() { _biometricLoading = false; _hasRefreshSession = false; _error = result.message; }); return; }
      await AuthStorage.saveAccessToken(result.accessToken);
      await AuthStorage.saveRefreshToken(result.refreshToken);
      await AuthStorage.setBiometricEnabled(true);
      if (!mounted) return;
      setState(() { _biometricLoading = false; _biometricEnabled = true; _hasRefreshSession = true; });
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const StaffEstablishmentsScreen()), (route) => false);
    } on PlatformException catch (e) {
      String message = 'Не удалось выполнить вход по биометрии';
      final code = e.code.toLowerCase();
      if (code.contains('notavailable') || code.contains('not_available')) message = 'Биометрия недоступна на этом устройстве';
      else if (code.contains('notenrolled')) message = 'В устройстве не настроен Face ID / Touch ID';
      else if (code.contains('lockedout')) message = 'Биометрия временно заблокирована';
      if (!mounted) return;
      setState(() { _biometricLoading = false; _error = message; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _biometricLoading = false; _error = 'Не удалось выполнить вход по Face ID / Touch ID'; });
    }
  }

  Future<void> _openRecoverySheet() async {
    final recoveredPhone = await showModalBottomSheet<String>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const _PasswordRecoverySheet());
    if (!mounted) return;
    if (recoveredPhone != null && recoveredPhone.trim().isNotEmpty) {
      _phoneController.text = recoveredPhone.trim();
      _passwordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пароль обновлён. Войдите с новым паролем.')));
    }
  }

  // === ВИЗУАЛЬНЫЕ КОМПОНЕНТЫ ===
  Widget _softBlob({required double width, required double height, required List<Color> colors}) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
        child: Container(
          width: width, height: height,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(width), gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        ),
      ),
    );
  }

  Widget _background() {
    return AnimatedBuilder(
      animation: Listenable.merge([_ambientController, _pulseController]),
      builder: (context, child) {
        final t = _ambientController.value;
        final p = _pulseController.value;
        final shiftA = math.sin(t * math.pi * 2) * 24;
        final shiftB = math.cos(t * math.pi * 2) * 18;
        final rotate = math.sin(t * math.pi * 2) * 0.025;
        return Stack(children: [
          Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [kLoginMintTop, kLoginMintMid, kLoginMintBottom, kLoginMintDeep], begin: Alignment.topLeft, end: Alignment.bottomRight, stops: [0.0, 0.30, 0.70, 1.0]))),
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.transparent, Colors.black.withOpacity(0.08)], begin: Alignment.topLeft, end: Alignment.bottomRight)))),
          Positioned(top: -90 + shiftA, right: -40 + shiftB, child: Transform.rotate(angle: rotate, child: _softBlob(width: 300, height: 300, colors: [Colors.white.withOpacity(0.22), kLoginAccent.withOpacity(0.14)]))),
          Positioned(left: -70, bottom: 70 - shiftB, child: Transform.rotate(angle: -rotate, child: _softBlob(width: 260, height: 260, colors: [kLoginBlue.withOpacity(0.18), Colors.white.withOpacity(0.1)]))),
          Positioned(top: 320 + shiftA, left: 90 + shiftB, child: Transform.rotate(angle: rotate * 0.8, child: _softBlob(width: 220, height: 220, colors: [kLoginPink.withOpacity(0.14), Colors.transparent]))),
          ...List.generate(6, (i) {
            final angle = (i / 6) * math.pi * 2 + t * math.pi * 0.3;
            final distance = 180 + 30 * math.sin(t * math.pi * 2 + i);
            final size = 4 + 2 * math.sin(p * math.pi * 2 + i);
            final opacity = 0.15 + 0.1 * math.sin(p * math.pi * 2 + i * 0.5);
            return Positioned(
              left: MediaQuery.of(context).size.width / 2 + math.cos(angle) * distance - size / 2,
              top: MediaQuery.of(context).size.height / 2 + math.sin(angle) * distance - size / 2,
              child: Opacity(opacity: opacity, child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: [kLoginBlue, kLoginPink, kLoginViolet, kLoginAccent][i % 4]))),
            );
          }),
        ]);
      },
    );
  }

  Widget _topBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(colors: [kLoginAccent, kLoginAccentSoft]),
        boxShadow: [BoxShadow(color: kLoginAccent.withOpacity(0.32), blurRadius: 16, offset: const Offset(0, 7))],
      ),
      child: const Text('FLOWRU STAFF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.white)),
    );
  }

  Widget _logoOrb() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = _pulseAnimation.value;
        return Transform.scale(
          scale: pulse,
          child: SizedBox(
            width: 100, height: 100,
            child: Stack(alignment: Alignment.center, children: [
              Transform.scale(scale: pulse * 1.15, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: kLoginAccent.withOpacity(0.35), blurRadius: 50, spreadRadius: 12), BoxShadow(color: kLoginBlue.withOpacity(0.2), blurRadius: 35, spreadRadius: 6)]))),
              Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Colors.white.withOpacity(0.28), Colors.white.withOpacity(0.12)]))),
              Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.96), boxShadow: [BoxShadow(color: kLoginBlue.withOpacity(0.14), blurRadius: 20, offset: const Offset(0, 12))])),
              Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [kLoginAccent, kLoginAccentSoft]), boxShadow: [BoxShadow(color: kLoginAccent.withOpacity(0.4), blurRadius: 26, offset: const Offset(0, 10))]), child: Center(child: Image.asset('assets/images/flowru_logo.png', width: 40, height: 40, fit: BoxFit.contain))),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildGlassInput({required TextEditingController controller, required String label, IconData? icon, TextInputType keyboardType = TextInputType.text, bool obscureText = false, Widget? suffixIcon, String? hintText}) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), color: Colors.white.withOpacity(0.94), border: Border.all(color: const Color(0xFFE7EEF0), width: 1.2)),
      child: TextField(
        controller: controller, obscureText: obscureText, keyboardType: keyboardType,
        style: const TextStyle(color: kLoginInk, fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: icon != null ? Icon(icon, color: kLoginInkSoft, size: 22) : null,
          suffixIcon: suffixIcon, labelText: label, hintText: hintText,
          labelStyle: const TextStyle(color: kLoginInkSoft, fontWeight: FontWeight.w600),
          hintStyle: const TextStyle(color: Color(0xFF9AA5B1), fontWeight: FontWeight.w400),
          floatingLabelStyle: const TextStyle(color: kLoginViolet),
          border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 19),
        ),
      ),
    );
  }

  Widget _glassButton({required VoidCallback? onPressed, required String text, required bool isLoading}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(colors: [kLoginBlue, kLoginViolet, kLoginPink]),
        boxShadow: [BoxShadow(color: kLoginBlue.withOpacity(0.28), blurRadius: 22, offset: const Offset(0, 12))],
      ),
      child: Material(color: Colors.transparent, child: InkWell(
        onTap: onPressed, borderRadius: BorderRadius.circular(30),
        child: Container(height: 60, alignment: Alignment.center, child: isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900))),
      )),
    );
  }

  Widget _outlineGlassButton({required String text, required VoidCallback onTap}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: OutlinedButton(
        onPressed: onTap, 
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: kLoginViolet, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), 
          padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 24),
        ), 
        child: Text(
          text, 
          style: const TextStyle(color: kLoginViolet, fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _biometricButton() {
    if (!_shouldShowBiometricButton) return const SizedBox.shrink();
    return AnimatedCrossFade(
      firstChild: const SizedBox.shrink(),
      secondChild: OutlinedButton.icon(
        onPressed: _biometricLoading ? null : _loginWithBiometric,
        icon: _biometricLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.1, color: kLoginBlue)) : const Icon(Icons.fingerprint, color: kLoginBlue),
        label: const Text('Войти по Face ID / Touch ID', style: TextStyle(color: kLoginBlue, fontSize: 15, fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(side: const BorderSide(color: kLoginBlue), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), padding: const EdgeInsets.symmetric(vertical: 15)),
      ),
      crossFadeState: _shouldShowBiometricButton ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 300),
    );
  }

  bool get _shouldShowBiometricButton {
    if (_biometricChecking || !_biometricAvailable || !_hasRefreshSession) return false;
    return _biometricEnabled || _hasRefreshSession;
  }

  Widget _errorBox(String message) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), color: const Color(0xFFFFF4F2).withOpacity(0.98), border: Border.all(color: const Color(0xFFFFD7D0))),
      child: Row(children: [const Icon(Icons.error_outline, color: Color(0xFFE85B63), size: 19), const SizedBox(width: 9), Expanded(child: Text(message, style: const TextStyle(color: Color(0xFFE85B63), fontWeight: FontWeight.w800)))]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLoginMintTop,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(children: [
          _background(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      width: 520,
                      padding: const EdgeInsets.fromLTRB(30, 30, 30, 34),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(48), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 36, offset: const Offset(0, 18))]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(48),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            padding: const EdgeInsets.all(26),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(48),
                              gradient: LinearGradient(colors: [kLoginCardStrong, kLoginCard], begin: Alignment.topLeft, end: Alignment.bottomRight),
                              border: Border.all(color: kLoginStroke),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _topBadge(),
                                const SizedBox(height: 20),
                                _logoOrb(),
                                const SizedBox(height: 18),
                                const Text('Вход сотрудника', style: TextStyle(fontSize: 33, fontWeight: FontWeight.w900, color: kLoginInk, letterSpacing: -0.9)),
                                const SizedBox(height: 9),
                                const Text('Введите номер телефона и пароль,\nчтобы открыть рабочее пространство.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: kLoginInkSoft, height: 1.42)),
                                const SizedBox(height: 30),
                                _buildGlassInput(
                                  controller: _phoneController, 
                                  label: 'Телефон', 
                                  icon: Icons.phone_android_outlined, 
                                  keyboardType: TextInputType.phone,
                                  hintText: '+7 978 547 30 14',
                                ),
                                const SizedBox(height: 18),
                                _buildGlassInput(
                                  controller: _passwordController, 
                                  label: 'Пароль', 
                                  icon: Icons.lock_outline_rounded, 
                                  obscureText: !_showPassword, 
                                  suffixIcon: IconButton(
                                    icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, color: kLoginInkSoft), 
                                    onPressed: () => setState(() => _showPassword = !_showPassword),
                                  ),
                                ),
                                if (_error != null) ...[const SizedBox(height: 18), _errorBox(_error!)],
                                const SizedBox(height: 26),
                                _glassButton(onPressed: _loading ? null : _submit, text: 'Войти', isLoading: _loading),
                                const SizedBox(height: 16),
                                _biometricButton(),
                                const SizedBox(height: 12),
                                TextButton(onPressed: _openRecoverySheet, child: const Text('Забыли пароль?', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: kLoginBlue))),
                                const SizedBox(height: 8),
                                _outlineGlassButton(text: 'Зарегистрироваться', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()))),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ========== ВОССТАНОВЛЕНИЕ ПАРОЛЯ ==========
class _PasswordRecoverySheet extends StatefulWidget {
  const _PasswordRecoverySheet();
  @override
  State<_PasswordRecoverySheet> createState() => _PasswordRecoverySheetState();
}

class _PasswordRecoverySheetState extends State<_PasswordRecoverySheet> {
  static const String _botUrl = 'https://t.me/Flowru_Staff_Recovery_bot';
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _requestingCode = false;
  bool _confirming = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  String? _requestMessage;
  bool _requestSuccess = false;
  String? _confirmMessage;
  bool _confirmSuccess = false;

  Future<void> _openBot() async {
    final uri = Uri.parse(_botUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось открыть Telegram.')));
  }

  String _extractErrorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        final message = decoded['message'];
        if (detail is String && detail.trim().isNotEmpty) return detail;
        if (message is String && message.trim().isNotEmpty) return message;
      }
    } catch (_) {}
    return 'Ошибка запроса (${response.statusCode})';
  }

  Future<void> _requestCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) { setState(() { _requestSuccess = false; _requestMessage = 'Введите номер телефона'; }); return; }
    setState(() { _requestingCode = true; _requestMessage = null; _requestSuccess = false; });
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/auth/password-reset/request'),
        headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        String message = 'Код отправлен';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['message'] is String) message = decoded['message'];
        } catch (_) {}
        setState(() { _requestingCode = false; _requestSuccess = true; _requestMessage = message; });
        return;
      }
      setState(() { _requestingCode = false; _requestSuccess = false; _requestMessage = _extractErrorMessage(response); });
    } catch (_) {
      if (!mounted) return;
      setState(() { _requestingCode = false; _requestSuccess = false; _requestMessage = 'Не удалось запросить код'; });
    }
  }

  Future<void> _confirmReset() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;
    if (phone.isEmpty) { setState(() { _confirmSuccess = false; _confirmMessage = 'Введите номер телефона'; }); return; }
    if (code.isEmpty) { setState(() { _confirmSuccess = false; _confirmMessage = 'Введите код из Telegram'; }); return; }
    if (newPassword.isEmpty) { setState(() { _confirmSuccess = false; _confirmMessage = 'Введите новый пароль'; }); return; }
    if (confirmPassword.isEmpty) { setState(() { _confirmSuccess = false; _confirmMessage = 'Подтвердите новый пароль'; }); return; }
    setState(() { _confirming = true; _confirmMessage = null; _confirmSuccess = false; });
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/auth/password-reset/confirm'),
        headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'phone': phone, 'code': code, 'new_password': newPassword, 'new_password_confirm': confirmPassword}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() { _confirming = false; _confirmSuccess = true; _confirmMessage = 'Пароль успешно изменён'; });
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        Navigator.of(context).pop(phone);
        return;
      }
      setState(() { _confirming = false; _confirmSuccess = false; _confirmMessage = _extractErrorMessage(response); });
    } catch (_) {
      if (!mounted) return;
      setState(() { _confirming = false; _confirmSuccess = false; _confirmMessage = 'Не удалось изменить пароль'; });
    }
  }

  InputDecoration _inputDecoration(String label, {Widget? suffixIcon, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: kLoginInkSoft, fontWeight: FontWeight.w700),
      hintStyle: const TextStyle(color: Color(0xFF89A1A7), fontWeight: FontWeight.w700),
      contentPadding: const EdgeInsets.symmetric(horizontal: 19, vertical: 19),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(19), borderSide: const BorderSide(color: Color(0xFFE7EEF0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(19), borderSide: const BorderSide(color: Color(0xFFE7EEF0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(19), borderSide: const BorderSide(color: kLoginViolet, width: 1.5)),
    );
  }

  Widget _messageBox(String text, {required bool success}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        color: success ? const Color(0xFFF0FFF6) : const Color(0xFFFFF4F2).withOpacity(0.97),
        border: Border.all(color: success ? const Color(0xFFB8EBC8) : const Color(0xFFFFD7D0)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: success ? const Color(0xFF1F8E4D) : const Color(0xFFE85B63), fontWeight: FontWeight.w800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(13, 13, 13, 13 + bottomInset),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: const Color(0xFFF8FCFD),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 34, offset: const Offset(0, 20))],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(19, 19, 19, 19),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(width: 48, height: 5, decoration: BoxDecoration(color: const Color(0xFFD7E4E8), borderRadius: BorderRadius.circular(999))),
                    const Spacer(),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(17),
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFE5EEF1)),
                          ),
                          child: const Icon(Icons.close_rounded, color: kLoginInk, size: 23),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [kLoginBlue, kLoginPink]),
                    boxShadow: [BoxShadow(color: kLoginBlue.withOpacity(0.24), blurRadius: 20, offset: const Offset(0, 11))],
                  ),
                  child: const Icon(Icons.lock_reset_rounded, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Восстановление пароля',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: kLoginInk, letterSpacing: -0.9),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Сначала откройте сервисный бот восстановления,\nнажмите Start, а потом запросите код.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14.5, height: 1.47, fontWeight: FontWeight.w700, color: kLoginInkSoft),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(21),
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE5EEF1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_rounded, size: 19, color: kLoginBlue),
                          SizedBox(width: 9),
                          Text('Что нужно сделать', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: kLoginInk)),
                        ],
                      ),
                      const SizedBox(height: 13),
                      const Text('1. Перейдите в бот восстановления', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kLoginInkSoft)),
                      const SizedBox(height: 7),
                      InkWell(
                        onTap: _openBot,
                        borderRadius: BorderRadius.circular(13),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color: const Color(0xFFF5F8FF),
                            border: Border.all(color: const Color(0xFFD9E4FF)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.open_in_new_rounded, color: kLoginBlue, size: 19),
                              SizedBox(width: 11),
                              Expanded(child: Text('@Flowru_Staff_Recovery_bot', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: kLoginBlue))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 11),
                      const Text('2. Внутри бота обязательно нажмите Start', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kLoginInkSoft)),
                      const SizedBox(height: 7),
                      const Text('3. Вернитесь сюда и запросите код', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kLoginInkSoft)),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openBot,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: kLoginBlue),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                          ),
                          icon: const Icon(Icons.telegram, color: kLoginBlue),
                          label: const Text('Открыть бот восстановления', style: TextStyle(color: kLoginBlue, fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration('Телефон сотрудника', hint: '+7 978 547 30 14'),
                ),
                const SizedBox(height: 13),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(19),
                    gradient: const LinearGradient(colors: [kLoginBlue, kLoginPink]),
                    boxShadow: [BoxShadow(color: kLoginBlue.withOpacity(0.22), blurRadius: 18, offset: const Offset(0, 9))],
                  ),
                  child: ElevatedButton(
                    onPressed: _requestingCode ? null : _requestCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
                    ),
                    child: _requestingCode
                        ? const SizedBox(width: 21, height: 21, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                        : const Text('Запросить код восстановления', style: TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w900)),
                  ),
                ),
                if (_requestMessage != null) ...[const SizedBox(height: 13), _messageBox(_requestMessage!, success: _requestSuccess)],
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(21),
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE5EEF1)),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration('Код из Telegram', hint: 'Например: 123456'),
                      ),
                      const SizedBox(height: 13),
                      TextField(
                        controller: _newPasswordController,
                        obscureText: !_showNewPassword,
                        decoration: _inputDecoration(
                          'Новый пароль',
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _showNewPassword = !_showNewPassword),
                            icon: Icon(_showNewPassword ? Icons.visibility_off : Icons.visibility, color: kLoginInkSoft),
                          ),
                        ),
                      ),
                      const SizedBox(height: 13),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: !_showConfirmPassword,
                        decoration: _inputDecoration(
                          'Подтвердите пароль',
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                            icon: Icon(_showConfirmPassword ? Icons.visibility_off : Icons.visibility, color: kLoginInkSoft),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _confirming ? null : _confirmReset,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kLoginViolet,
                            minimumSize: const Size.fromHeight(54),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
                          ),
                          child: _confirming
                              ? const SizedBox(width: 21, height: 21, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                              : const Text('Сменить пароль', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15.5)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_confirmMessage != null) ...[const SizedBox(height: 13), _messageBox(_confirmMessage!, success: _confirmSuccess)],
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}