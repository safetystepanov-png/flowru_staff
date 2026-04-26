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
const Color kLoginMintTop = Color(0xFF0C8795);
const Color kLoginMintMid = Color(0xFF21C7B6);
const Color kLoginMintBottom = Color(0xFF03717D);
const Color kLoginMintDeep = Color(0xFF024D5C);
const Color kLoginAccent = Color(0xFFFFA51E);
const Color kLoginAccentSoft = Color(0xFFFFD75F);
const Color kLoginCard = Color(0xDDF7FEFF);
const Color kLoginCardStrong = Color(0xF4FFFFFF);
const Color kLoginStroke = Color(0xBFFFFFFF);
const Color kLoginInk = Color(0xFF082F45);
const Color kLoginInkSoft = Color(0xFF55768B);
const Color kLoginBlue = Color(0xFF2E73FF);
const Color kLoginPink = Color(0xFFFF4B9A);
const Color kLoginViolet = Color(0xFF7B55FF);

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
    final savedPassword = await AuthStorage.getSavedPassword();
    final biometricEnabled = await AuthStorage.isBiometricEnabled();
    final refreshToken = await AuthStorage.getRefreshToken();

    if (!mounted) return;

    if (savedPhone != null && savedPhone.trim().isNotEmpty) {
      _phoneController.text = savedPhone.trim();
    }

    if (savedPassword != null && savedPassword.isNotEmpty) {
      _passwordController.text = savedPassword;
    }

    final hasRefreshSession = refreshToken != null && refreshToken.trim().isNotEmpty;
    bool available = false;

    if (!kIsWeb) {
      try {
        final canCheck = await _localAuth.canCheckBiometrics;
        final isSupported = await _localAuth.isDeviceSupported();
        final availableBiometrics = await _localAuth.getAvailableBiometrics();

        available = isSupported && (canCheck || availableBiometrics.isNotEmpty);

        print('🔐 BIOMETRIC CHECK:');
        print('  canCheck: $canCheck');
        print('  isSupported: $isSupported');
        print('  biometricEnabled: $biometricEnabled');
        print('  hasRefreshSession: $hasRefreshSession');
        print('  available: $available');
      } catch (e) {
        print('❌ BIOMETRIC ERROR: $e');
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
    if (kIsWeb) {
      print('⚠️ Web platform - biometric not available');
      return;
    }

    if (!_biometricAvailable) {
      print('⚠️ Biometric not available on device');
      return;
    }

    try {
      await AuthStorage.setBiometricEnabled(true);
      print('✅ Biometric enabled successfully');

      if (!mounted) return;
      setState(() => _biometricEnabled = true);
    } catch (e) {
      print('❌ Error enabling biometric: $e');
    }
  }

  Future<void> _submitWithCredentials({
    required String phone,
    required String password,
    bool saveCredentials = true,
  }) async {
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

    late final AuthResult result;
    try {
      result = await _userApi.login(
        phone: phone,
        password: password,
        deviceId: kIsWeb ? 'staff-web' : 'staff-mobile',
        platform: kIsWeb ? 'web' : 'mobile',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Ошибка входа: $e';
      });
      return;
    }

    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _loading = false;
        _error = result.message;
      });
      return;
    }

    try {
      await AuthStorage.saveAccessToken(result.accessToken);
      await AuthStorage.saveRefreshToken(result.refreshToken);
      TextInput.finishAutofillContext(shouldSave: true);

      if (saveCredentials) {
        final phoneToSave = result.phone.isNotEmpty ? result.phone : phone;
        await AuthStorage.savePhoneOnly(phoneToSave);
        print('✅ Phone saved: $phoneToSave');

        await AuthStorage.savePassword(password);
        print('✅ Password saved');

        await _enableBiometricIfPossible();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Ошибка сохранения сессии: $e';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _hasRefreshSession = true;
    });

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const StaffEstablishmentsScreen()),
      (route) => false,
    );
  }

  Future<void> _submit() async => await _submitWithCredentials(
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        saveCredentials: true,
      );

  Future<void> _loginWithBiometric() async {
    if (kIsWeb) {
      setState(() => _error = 'Биометрия в web-версии не поддерживается');
      return;
    }

    if (_loading || _biometricLoading) {
      print('⚠️ Already loading');
      return;
    }

    final refreshToken = await AuthStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.trim().isEmpty) {
      setState(() => _error = 'Нет сохранённой сессии для входа');
      print('❌ No refresh token');
      return;
    }

    print('🔐 Starting biometric authentication...');
    setState(() {
      _biometricLoading = true;
      _error = null;
    });

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Войдите в Flowru Staff',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      print('🔐 Authentication result: $authenticated');

      if (!authenticated) {
        if (!mounted) return;
        setState(() => _biometricLoading = false);
        print('❌ User cancelled biometric');
        return;
      }

      final result = await _userApi.refresh(
        refreshToken: refreshToken.trim(),
        deviceId: kIsWeb ? 'staff-web' : 'staff-mobile',
        platform: kIsWeb ? 'web' : 'mobile',
      );

      if (!mounted) return;

      if (!result.ok) {
        await AuthStorage.clearSessionButKeepBiometric();
        setState(() {
          _biometricLoading = false;
          _hasRefreshSession = false;
          _error = result.message;
        });
        print('❌ Refresh failed: ${result.message}');
        return;
      }

      await AuthStorage.saveAccessToken(result.accessToken);
      await AuthStorage.saveRefreshToken(result.refreshToken);
      await AuthStorage.setBiometricEnabled(true);

      if (!mounted) return;

      setState(() {
        _biometricLoading = false;
        _biometricEnabled = true;
        _hasRefreshSession = true;
      });

      print('✅ Biometric login successful!');

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const StaffEstablishmentsScreen()),
        (route) => false,
      );
    } on PlatformException catch (e) {
      print('❌ PlatformException: ${e.code} - ${e.message}');

      String message = 'Не удалось выполнить вход по биометрии';
      final code = e.code.toLowerCase();

      if (code.contains('notavailable') || code.contains('not_available')) {
        message = 'Биометрия недоступна на этом устройстве';
      } else if (code.contains('notenrolled')) {
        message = 'В устройстве не настроен Face ID / Touch ID';
      } else if (code.contains('lockedout')) {
        message = 'Биометрия временно заблокирована';
      } else if (code.contains('userfallback')) {
        message = 'Пользователь выбрал ввод пароля';
      }

      if (!mounted) return;
      setState(() {
        _biometricLoading = false;
        _error = message;
      });
    } catch (e) {
      print('❌ General error: $e');
      if (!mounted) return;
      setState(() {
        _biometricLoading = false;
        _error = 'Не удалось выполнить вход по Face ID / Touch ID';
      });
    }
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
        const SnackBar(content: Text('Пароль обновлён. Войдите с новым паролем.')),
      );
    }
  }

  // === ВИЗУАЛЬНЫЕ КОМПОНЕНТЫ ===
  Widget _softBlob({required double width, required double height, required List<Color> colors}) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(width),
            gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
        ),
      ),
    );
  }

  Widget _background() {
    return AnimatedBuilder(
      animation: Listenable.merge([_ambientController, _pulseController]),
      builder: (context, child) {
        final size = MediaQuery.of(context).size;
        final t = _ambientController.value;
        final p = _pulseController.value;
        final shiftA = math.sin(t * math.pi * 2) * 28;
        final shiftB = math.cos(t * math.pi * 2) * 22;

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
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.62, -0.92),
                    radius: 1.15,
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
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.92, 0.98),
                    radius: 0.95,
                    colors: [
                      kLoginBlue.withOpacity(0.26),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -105 + shiftA,
              right: -70 + shiftB,
              child: _softBlob(
                width: 330,
                height: 330,
                colors: [Colors.white.withOpacity(0.42), kLoginAccentSoft.withOpacity(0.18)],
              ),
            ),
            Positioned(
              left: -100 - shiftB,
              bottom: 24 + shiftA,
              child: _softBlob(
                width: 310,
                height: 310,
                colors: [kLoginBlue.withOpacity(0.30), Colors.white.withOpacity(0.12)],
              ),
            ),
            Positioned(
              top: size.height * 0.36 + shiftB,
              left: size.width * 0.06 + shiftA,
              child: _softBlob(
                width: 190,
                height: 190,
                colors: [kLoginPink.withOpacity(0.12), Colors.transparent],
              ),
            ),
            Positioned(
              right: -46,
              bottom: size.height * 0.26,
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
              final sizeDot = 3.0 + (i % 4) * 1.4 + 1.2 * math.sin(p * math.pi * 2 + i);
              final opacity = (0.15 + 0.22 * math.sin(p * math.pi * 2 + i * 0.45).abs()).clamp(0.08, 0.36);
              final dotColor = [Colors.white, kLoginAccentSoft, const Color(0xFFC9FFF0)][i % 3];

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

  Widget _topBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9E16), Color(0xFFFFD65C)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.58), width: 1.1),
        boxShadow: [
          BoxShadow(color: kLoginAccent.withOpacity(0.42), blurRadius: 20, offset: const Offset(0, 9)),
          BoxShadow(color: Colors.white.withOpacity(0.58), blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      child: const Text(
        'FLOWRU STAFF',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2.2, color: Colors.white),
      ),
    );
  }

  Widget _orbitDot(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.82),
        border: Border.all(color: Colors.white.withOpacity(0.65), width: 1),
        boxShadow: [BoxShadow(color: color.withOpacity(0.45), blurRadius: 12, spreadRadius: 1)],
      ),
    );
  }

  Widget _logoOrb({double size = 122}) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _ambientController]),
      builder: (context, child) {
        final pulse = _pulseAnimation.value;
        final t = _ambientController.value;

        return SizedBox(
          width: size + 62,
          height: size + 62,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: t * math.pi * 2,
                child: Container(
                  width: size + 48,
                  height: size + 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.42), width: 1.2),
                  ),
                ),
              ),
              Transform.rotate(
                angle: -t * math.pi * 2,
                child: Container(
                  width: size + 32,
                  height: size + 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: kLoginAccentSoft.withOpacity(0.55), width: 1.1),
                  ),
                ),
              ),
              Positioned(
                top: 15 + math.sin(t * math.pi * 2) * 7,
                left: 42,
                child: _orbitDot(kLoginAccentSoft, 7),
              ),
              Positioned(
                right: 28,
                top: 38 + math.cos(t * math.pi * 2) * 7,
                child: _orbitDot(Colors.white, 9),
              ),
              Positioned(
                right: 44,
                bottom: 28 + math.sin(t * math.pi * 2) * 5,
                child: _orbitDot(Colors.white, 8),
              ),
              Transform.scale(
                scale: pulse,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFFFFF07A), Color(0xFFFFC533), Color(0xFFFFA51E)],
                      stops: [0.0, 0.62, 1.0],
                    ),
                    border: Border.all(color: Colors.white.withOpacity(0.62), width: 1.4),
                    boxShadow: [
                      BoxShadow(color: kLoginAccentSoft.withOpacity(0.58), blurRadius: 34, spreadRadius: 8),
                      BoxShadow(color: kLoginAccent.withOpacity(0.32), blurRadius: 30, offset: const Offset(0, 14)),
                    ],
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/images/flowru_logo.png',
                      width: size * 0.58,
                      height: size * 0.58,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlassInput({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? hintText,
    Iterable<String>? autofillHints,
    TextInputAction? textInputAction,
    bool enableSuggestions = true,
    bool autocorrect = false,
    ValueChanged<String>? onSubmitted,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isSmallScreen ? 22 : 25),
        color: Colors.white.withOpacity(0.52),
        border: Border.all(color: Colors.white.withOpacity(0.92), width: 1.8),
        boxShadow: [
          BoxShadow(color: Colors.white.withOpacity(0.42), blurRadius: 12, offset: const Offset(0, -2)),
          BoxShadow(color: const Color(0xFF0D5A73).withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isSmallScreen ? 22 : 25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            autofillHints: autofillHints,
            textInputAction: textInputAction,
            enableSuggestions: enableSuggestions,
            autocorrect: autocorrect,
            onSubmitted: onSubmitted,
            style: TextStyle(
              color: kLoginInk,
              fontSize: isSmallScreen ? 18 : 22,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              prefixIcon: icon != null
                  ? Padding(
                      padding: const EdgeInsets.only(left: 14, right: 8),
                      child: Icon(icon, color: kLoginInkSoft, size: isSmallScreen ? 24 : 28),
                    )
                  : null,
              prefixIconConstraints: const BoxConstraints(minWidth: 56),
              suffixIcon: suffixIcon,
              labelText: label,
              hintText: hintText,
              labelStyle: TextStyle(
                color: kLoginInkSoft.withOpacity(0.90),
                fontWeight: FontWeight.w700,
                fontSize: isSmallScreen ? 18 : 22,
              ),
              hintStyle: TextStyle(
                color: kLoginInkSoft.withOpacity(0.52),
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 16 : 18,
              ),
              floatingLabelStyle: const TextStyle(color: kLoginViolet, fontWeight: FontWeight.w800),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 18 : 24,
                vertical: isSmallScreen ? 18 : 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassButton({
    required VoidCallback? onPressed,
    required String text,
    required bool isLoading,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          colors: [Color(0xFF2877FF), Color(0xFF7A4CFF), Color(0xFFFF4E96)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.1),
        boxShadow: [
          BoxShadow(color: kLoginBlue.withOpacity(0.30), blurRadius: 24, offset: const Offset(0, 13)),
          BoxShadow(color: kLoginPink.withOpacity(0.25), blurRadius: 24, offset: const Offset(0, 13)),
          BoxShadow(color: Colors.white.withOpacity(0.50), blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: isSmallScreen ? 56.0 : 64.0,
            alignment: Alignment.center,
            child: isLoading
                ? SizedBox(
                    width: isSmallScreen ? 20 : 24,
                    height: isSmallScreen ? 20 : 24,
                    child: const CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : Text(
                    text,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 22 : 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _outlineGlassButton({required String text, required VoidCallback onTap}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 20 : 34),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: kLoginViolet, width: 1.8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 16 : 18, horizontal: isSmallScreen ? 16 : 24),
          backgroundColor: Colors.white.withOpacity(0.18),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: kLoginViolet,
            fontSize: isSmallScreen ? 18 : 21,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.1,
          ),
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
        icon: _biometricLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.1, color: kLoginBlue))
            : const Icon(Icons.fingerprint, color: kLoginBlue),
        label: const Text('Войти по Face ID / Touch ID', style: TextStyle(color: kLoginBlue, fontSize: 15, fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: kLoginBlue),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
      crossFadeState: _shouldShowBiometricButton ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 300),
    );
  }

  bool get _shouldShowBiometricButton {
    if (_biometricChecking) return false;
    if (!_biometricAvailable) return false;
    if (!_hasRefreshSession) return false;
    return _biometricEnabled || _hasRefreshSession;
  }

  Widget _errorBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFFFFF4F2).withOpacity(0.98),
        border: Border.all(color: const Color(0xFFFFD7D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFE85B63), size: 19),
          const SizedBox(width: 9),
          Expanded(child: Text(message, style: const TextStyle(color: Color(0xFFE85B63), fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final isVerySmall = screenWidth < 360 || screenHeight < 640;
    final isSmallScreen = screenWidth < 400 || screenHeight < 700;
    final isMediumScreen = screenWidth >= 400 && screenWidth < 600;

    final cardWidth = isVerySmall
        ? screenWidth * 0.94
        : isSmallScreen
            ? screenWidth * 0.91
            : isMediumScreen
                ? screenWidth * 0.84
                : 500.0;

    final horizontalPadding = isVerySmall ? 10.0 : isSmallScreen ? 14.0 : 24.0;
    final cardPadding = 0.0;
    final innerPadding = isVerySmall ? 24.0 : isSmallScreen ? 28.0 : 40.0;

    final titleSize = isVerySmall ? 34.0 : isSmallScreen ? 40.0 : 50.0;
    final subtitleSize = isVerySmall ? 17.0 : isSmallScreen ? 19.0 : 24.0;
    final logoSize = isVerySmall ? 94.0 : isSmallScreen ? 108.0 : 126.0;

    final gapSmall = isVerySmall ? 8.0 : isSmallScreen ? 10.0 : 14.0;
    final gapMedium = isVerySmall ? 12.0 : isSmallScreen ? 16.0 : 20.0;
    final gapLarge = isVerySmall ? 20.0 : isSmallScreen ? 26.0 : 34.0;

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
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: isVerySmall ? 12 : 20),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        width: cardWidth,
                        constraints: BoxConstraints(
                          maxWidth: 500,
                          minWidth: (screenWidth * 0.85).clamp(0.0, 500.0),
                        ),
                        padding: EdgeInsets.fromLTRB(cardPadding, cardPadding, cardPadding, cardPadding),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(isVerySmall ? 34 : isSmallScreen ? 42 : 52),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.26),
                              blurRadius: isVerySmall ? 18 : isSmallScreen ? 24 : 34,
                              spreadRadius: 1,
                              offset: const Offset(0, 0),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.10),
                              blurRadius: isVerySmall ? 18 : isSmallScreen ? 26 : 40,
                              offset: Offset(0, isVerySmall ? 10 : isSmallScreen ? 14 : 20),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(isVerySmall ? 34 : isSmallScreen ? 42 : 52),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              padding: EdgeInsets.all(innerPadding),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(isVerySmall ? 34 : isSmallScreen ? 42 : 52),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.90),
                                    const Color(0xFFEFFFFF).withOpacity(0.78),
                                    Colors.white.withOpacity(0.68),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(color: Colors.white.withOpacity(0.86), width: 1.6),
                                boxShadow: [
                                  BoxShadow(color: Colors.white.withOpacity(0.34), blurRadius: 20, offset: const Offset(0, -3)),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _topBadge(),
                                  SizedBox(height: isVerySmall ? 8 : gapMedium),
                                  _logoOrb(size: logoSize),
                                  SizedBox(height: isVerySmall ? 0 : gapSmall),
                                  Text(
                                    'Вход сотрудника',
                                    style: TextStyle(
                                      fontSize: titleSize,
                                      fontWeight: FontWeight.w900,
                                      color: kLoginInk,
                                      letterSpacing: -1.5,
                                      height: 1.02,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: gapSmall),
                                  Text(
                                    'Введите номер телефона и пароль,\nчтобы открыть рабочее\nпространство.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: subtitleSize,
                                      fontWeight: FontWeight.w700,
                                      color: kLoginInkSoft,
                                      height: 1.34,
                                    ),
                                  ),
                                  SizedBox(height: gapLarge),
                                  AutofillGroup(
                                    child: Column(
                                      children: [
                                        _buildGlassInput(
                                          controller: _phoneController,
                                          label: 'Телефон',
                                          icon: Icons.phone_android_outlined,
                                          keyboardType: TextInputType.phone,
                                          hintText: '+7 999 555 30 55',
                                          autofillHints: const [AutofillHints.username],
                                          textInputAction: TextInputAction.next,
                                          enableSuggestions: false,
                                          autocorrect: false,
                                        ),
                                        SizedBox(height: gapMedium),
                                        _buildGlassInput(
                                          controller: _passwordController,
                                          label: 'Пароль',
                                          icon: Icons.lock_outline_rounded,
                                          obscureText: !_showPassword,
                                          autofillHints: const [AutofillHints.password],
                                          textInputAction: TextInputAction.done,
                                          enableSuggestions: false,
                                          autocorrect: false,
                                          onSubmitted: (_) => _submit(),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _showPassword ? Icons.visibility_off : Icons.visibility,
                                              color: kLoginInkSoft,
                                              size: isVerySmall ? 24 : isSmallScreen ? 26 : 30,
                                            ),
                                            onPressed: () => setState(() => _showPassword = !_showPassword),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_error != null) ...[
                                    SizedBox(height: gapMedium),
                                    _errorBox(_error!),
                                  ],
                                  SizedBox(height: gapLarge),
                                  _glassButton(
                                    onPressed: _loading ? null : _submit,
                                    text: 'Войти',
                                    isLoading: _loading,
                                  ),
                                  SizedBox(height: isVerySmall ? 8 : 12),
                                  _biometricButton(),
                                  SizedBox(height: isVerySmall ? 4 : 6),
                                  TextButton(
                                    onPressed: _openRecoverySheet,
                                    child: Text(
                                      'Забыли пароль?',
                                      style: TextStyle(
                                        fontSize: isVerySmall ? 18 : isSmallScreen ? 19 : 21,
                                        fontWeight: FontWeight.w900,
                                        color: kLoginBlue,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: isVerySmall ? 6 : 8),
                                  _outlineGlassButton(
                                    text: 'Зарегистрироваться',
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                    ),
                                  ),
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
          ],
        ),
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
        headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'phone': phone, 'code': code, 'new_password': newPassword, 'new_password_confirm': confirmPassword}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _confirming = false;
          _confirmSuccess = true;
          _confirmMessage = 'Пароль успешно изменён';
        });
        await Future.delayed(const Duration(milliseconds: 500));
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
                  decoration: _inputDecoration('Телефон сотрудника', hint: '+7 999 777 30 77'),
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
