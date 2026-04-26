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
const Color kLoginMintTop = Color(0xFF0FCAC5);
const Color kLoginMintMid = Color(0xFF0BAEBB);
const Color kLoginMintBottom = Color(0xFF087D94);
const Color kLoginMintDeep = Color(0xFF064B64);
const Color kLoginAccent = Color(0xFFFFA51E);
const Color kLoginAccentSoft = Color(0xFFFFD966);
const Color kLoginCard = Color(0xD8FFFFFF);
const Color kLoginCardStrong = Color(0xF2FFFFFF);
const Color kLoginStroke = Color(0xD9FFFFFF);
const Color kLoginInk = Color(0xFF0A2B47);
const Color kLoginInkSoft = Color(0xFF557186);
const Color kLoginBlue = Color(0xFF246BFF);
const Color kLoginPink = Color(0xFFFF4F91);
const Color kLoginViolet = Color(0xFF7A4CFF);

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
    if (phone.isEmpty) { setState(() => _error = 'Введите номер телефона'); return; }
    if (password.isEmpty) { setState(() => _error = 'Введите пароль'); return; }
    
    setState(() { _loading = true; _error = null; });
    
    late final AuthResult result;
    try {
      result = await _userApi.login(
        phone: phone, 
        password: password, 
        deviceId: kIsWeb ? 'staff-web' : 'staff-mobile', 
        platform: kIsWeb ? 'web' : 'mobile'
      );
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Ошибка входа: $e'; });
      return;
    }
    
    if (!mounted) return;
    if (!result.ok) { 
      setState(() { _loading = false; _error = result.message; }); 
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
      setState(() { _loading = false; _error = 'Ошибка сохранения сессии: $e'; });
      return;
    }
    
    if (!mounted) return;
    setState(() { _loading = false; _hasRefreshSession = true; });
    
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const StaffEstablishmentsScreen()), 
      (route) => false
    );
  } // ✅ ДОБАВЛЕНА ЗАКРЫВАЮЩАЯ СКОБКА

  Future<void> _submit() async => await _submitWithCredentials(phone: _phoneController.text.trim(), password: _passwordController.text, saveCredentials: true);

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
    setState(() { _biometricLoading = true; _error = null; });
    
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
        platform: kIsWeb ? 'web' : 'mobile'
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
        (route) => false
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
      setState(() { _biometricLoading = false; _error = message; });
      
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
        final size = MediaQuery.of(context).size;
        final t = _ambientController.value;
        final p = _pulseController.value;
        final shiftA = math.sin(t * math.pi * 2) * 22;
        final shiftB = math.cos(t * math.pi * 2) * 18;

        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF087AA2),
                    Color(0xFF0CBBC5),
                    Color(0xFF66E2C4),
                    Color(0xFF073E63),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.36, 0.66, 1.0],
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.82, -0.88),
                    radius: 0.92,
                    colors: [
                      Colors.white.withOpacity(0.42),
                      Colors.white.withOpacity(0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.36, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -120 + shiftA,
              right: -80 + shiftB,
              child: _softBlob(
                width: 360,
                height: 360,
                colors: [Colors.white.withOpacity(0.30), kLoginAccentSoft.withOpacity(0.16)],
              ),
            ),
            Positioned(
              left: -130 - shiftB,
              bottom: -40 + shiftA,
              child: _softBlob(
                width: 310,
                height: 310,
                colors: [kLoginBlue.withOpacity(0.24), Colors.white.withOpacity(0.10)],
              ),
            ),
            Positioned(
              top: size.height * 0.36 + shiftB,
              right: -120,
              child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.13), width: 2),
                ),
              ),
            ),
            Positioned(
              left: -58,
              bottom: size.height * 0.13,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.18), width: 2),
                ),
              ),
            ),
            ...List.generate(18, (i) {
              final angle = (i * 1.73) + t * math.pi * 0.32;
              final x = (math.sin(i * 19.7) * 0.5 + 0.5) * size.width;
              final y = (math.cos(i * 13.1) * 0.5 + 0.5) * size.height;
              final driftX = math.cos(angle) * (8 + i % 5);
              final driftY = math.sin(angle) * (8 + i % 6);
              final dotSize = 2.0 + (i % 4) * 1.15;
              final opacity = (0.22 + 0.18 * math.sin(p * math.pi * 2 + i)).clamp(0.08, 0.42);

              return Positioned(
                left: x + driftX,
                top: y + driftY,
                child: IgnorePointer(
                  child: Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (i % 3 == 0 ? kLoginAccentSoft : Colors.white).withOpacity(opacity),
                      boxShadow: [
                        BoxShadow(
                          color: (i % 3 == 0 ? kLoginAccentSoft : Colors.white).withOpacity(opacity),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9C14), Color(0xFFFFC83F)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.52), width: 1),
        boxShadow: [
          BoxShadow(color: kLoginAccent.withOpacity(0.36), blurRadius: 18, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.white.withOpacity(0.42), blurRadius: 4, offset: const Offset(0, -1)),
        ],
      ),
      child: const Text(
        'FLOWRU STAFF',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.8, color: Colors.white),
      ),
    );
  }


  Widget _orbitalLogo(double logoSize, {required bool isVerySmall, required bool isSmallScreen}) {
    return AnimatedBuilder(
      animation: Listenable.merge([_ambientController, _pulseController]),
      builder: (context, child) {
        final orbitSize = logoSize * 1.48;
        final centerSize = logoSize * 0.82;
        final badgeSize = logoSize * 0.58;

        return SizedBox(
          width: orbitSize,
          height: orbitSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: centerSize,
                  height: centerSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: kLoginAccent.withOpacity(0.40),
                        blurRadius: isVerySmall ? 26 : isSmallScreen ? 34 : 46,
                        spreadRadius: isVerySmall ? 4 : isSmallScreen ? 7 : 10,
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.35),
                        blurRadius: 22,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              CustomPaint(
                size: Size.square(orbitSize),
                painter: _LoginOrbitPainter(progress: _ambientController.value),
              ),
              Container(
                width: centerSize,
                height: centerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFFFFEE7B), Color(0xFFFFBD2E), Color(0xFFFFA51E)],
                    stops: [0.0, 0.68, 1.0],
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.62), width: 1.2),
                  boxShadow: [
                    BoxShadow(color: kLoginAccent.withOpacity(0.42), blurRadius: 24, offset: const Offset(0, 10)),
                  ],
                ),
              ),
              Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.04)),
                child: Center(
                  child: Image.asset(
                    'assets/images/flowru_logo.png',
                    width: badgeSize * 0.86,
                    height: badgeSize * 0.86,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _logoOrb() => _orbitalLogo(88, isVerySmall: false, isSmallScreen: false);


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
        borderRadius: BorderRadius.circular(isSmallScreen ? 18 : 24),
        color: Colors.white.withOpacity(0.72),
        border: Border.all(color: Colors.white.withOpacity(0.92), width: 1.35),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0A5270).withOpacity(0.10), blurRadius: 18, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.white.withOpacity(0.75), blurRadius: 3, offset: const Offset(0, -1)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isSmallScreen ? 18 : 24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
              fontSize: isSmallScreen ? 14 : 16,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              prefixIcon: icon != null
                  ? Icon(
                      icon,
                      color: kLoginInkSoft,
                      size: isSmallScreen ? 19 : 22,
                    )
                  : null,
              suffixIcon: suffixIcon,
              labelText: label,
              hintText: hintText,
              labelStyle: TextStyle(
                color: kLoginInkSoft.withOpacity(0.88),
                fontWeight: FontWeight.w700,
                fontSize: isSmallScreen ? 13 : 15,
              ),
              hintStyle: TextStyle(
                color: const Color(0xFF9AA5B1).withOpacity(0.65),
                fontWeight: FontWeight.w500,
                fontSize: isSmallScreen ? 12 : 14,
              ),
              floatingLabelStyle: const TextStyle(color: kLoginViolet, fontWeight: FontWeight.w800),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 16 : 22,
                vertical: isSmallScreen ? 13 : 19,
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
        borderRadius: BorderRadius.circular(isSmallScreen ? 25 : 31),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E70FF), Color(0xFF7A4CFF), Color(0xFFFF4F91)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.70), width: 1.1),
        boxShadow: [
          BoxShadow(color: kLoginBlue.withOpacity(0.30), blurRadius: isSmallScreen ? 16 : 24, offset: Offset(0, isSmallScreen ? 7 : 12)),
          BoxShadow(color: kLoginPink.withOpacity(0.20), blurRadius: isSmallScreen ? 18 : 26, offset: Offset(0, isSmallScreen ? 8 : 14)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(isSmallScreen ? 25 : 31),
          child: Container(
            height: isSmallScreen ? 48.0 : 60.0,
            alignment: Alignment.center,
            child: isLoading
                ? SizedBox(
                    width: isSmallScreen ? 18 : 24,
                    height: isSmallScreen ? 18 : 24,
                    child: const CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : Text(
                    text,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 14 : 16,
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
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 24),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.34),
          side: const BorderSide(color: kLoginViolet, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isSmallScreen ? 26 : 30)),
          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 15 : 17, horizontal: isSmallScreen ? 16 : 24),
          shadowColor: kLoginViolet.withOpacity(0.18),
        ),
        child: Text(
          text,
          style: TextStyle(color: kLoginViolet, fontSize: isSmallScreen ? 14 : 15, fontWeight: FontWeight.w900),
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
    if (_biometricChecking) return false;
    if (!_biometricAvailable) return false;
    if (!_hasRefreshSession) return false;
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final isVerySmall = screenWidth < 360 || screenHeight < 640;
    final isSmallScreen = screenWidth < 400 || screenHeight < 700;
    final isMediumScreen = screenWidth >= 400 && screenWidth < 600;

    final cardWidth = isVerySmall
        ? screenWidth * 0.94
        : isSmallScreen
            ? screenWidth * 0.92
            : isMediumScreen
                ? screenWidth * 0.86
                : 500.0;

    final horizontalPadding = isVerySmall ? 12.0 : isSmallScreen ? 14.0 : 24.0;
    final cardPadding = isVerySmall ? 10.0 : isSmallScreen ? 14.0 : 22.0;
    final innerPadding = isVerySmall ? 10.0 : isSmallScreen ? 14.0 : 22.0;

    // Шрифты оставлены в прежнем диапазоне: визуал меняем, масштаб не раздуваем.
    final titleSize = isVerySmall ? 20.0 : isSmallScreen ? 22.0 : 30.0;
    final subtitleSize = isVerySmall ? 10.5 : isSmallScreen ? 11.5 : 14.0;
    final logoSize = isVerySmall ? 58.0 : isSmallScreen ? 66.0 : 88.0;

    final gapSmall = isVerySmall ? 3.0 : isSmallScreen ? 4.0 : 8.0;
    final gapMedium = isVerySmall ? 6.0 : isSmallScreen ? 8.0 : 14.0;
    final gapLarge = isVerySmall ? 10.0 : isSmallScreen ? 14.0 : 24.0;

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
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
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
                      padding: EdgeInsets.fromLTRB(cardPadding, cardPadding, cardPadding, cardPadding + 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(isVerySmall ? 26 : isSmallScreen ? 32 : 44),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.13),
                            blurRadius: isVerySmall ? 18 : isSmallScreen ? 24 : 38,
                            offset: Offset(0, isVerySmall ? 7 : isSmallScreen ? 12 : 18),
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.26),
                            blurRadius: 18,
                            spreadRadius: 1,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(isVerySmall ? 26 : isSmallScreen ? 32 : 44),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: Container(
                            padding: EdgeInsets.all(innerPadding),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(isVerySmall ? 26 : isSmallScreen ? 32 : 44),
                              gradient: LinearGradient(
                                colors: [kLoginCardStrong, kLoginCard, Colors.white.withOpacity(0.78)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(color: kLoginStroke, width: 1.2),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _topBadge(),
                                SizedBox(height: isVerySmall ? 6 : gapMedium),
                                _orbitalLogo(
                                  logoSize,
                                  isVerySmall: isVerySmall,
                                  isSmallScreen: isSmallScreen,
                                ),
                                SizedBox(height: isVerySmall ? 4 : gapMedium),
                                Text(
                                  'Вход сотрудника',
                                  style: TextStyle(
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.w900,
                                    color: kLoginInk,
                                    letterSpacing: -0.8,
                                    height: 1.1,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: isVerySmall ? 2 : gapSmall),
                                Text(
                                  'Введите номер телефона и пароль,\nчтобы открыть рабочее\nпространство.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: subtitleSize,
                                    fontWeight: FontWeight.w700,
                                    color: kLoginInkSoft,
                                    height: 1.3,
                                  ),
                                ),
                                SizedBox(height: isVerySmall ? 12 : gapLarge),
                                AutofillGroup(
                                  child: Column(
                                    children: [
                                      _buildGlassInput(
                                        controller: _phoneController,
                                        label: 'Телефон',
                                        icon: Icons.phone_android_outlined,
                                        keyboardType: TextInputType.phone,
                                        autofillHints: const [AutofillHints.username],
                                        textInputAction: TextInputAction.next,
                                        enableSuggestions: false,
                                        autocorrect: false,
                                      ),
                                      SizedBox(height: isVerySmall ? 8 : gapMedium),
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
                                            size: isVerySmall ? 16 : isSmallScreen ? 18 : 20,
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
                                  SizedBox(height: isVerySmall ? 8 : gapMedium),
                                  _errorBox(_error!),
                                ],
                                SizedBox(height: isVerySmall ? 10 : gapLarge),
                                _glassButton(
                                  onPressed: _loading ? null : _submit,
                                  text: 'Войти',
                                  isLoading: _loading,
                                ),
                                SizedBox(height: isVerySmall ? 6 : 10),
                                _biometricButton(),
                                SizedBox(height: isVerySmall ? 4 : 6),
                                TextButton(
                                  onPressed: _openRecoverySheet,
                                  child: Text(
                                    'Забыли пароль?',
                                    style: TextStyle(
                                      fontSize: isVerySmall ? 11.5 : isSmallScreen ? 12.5 : 14,
                                      fontWeight: FontWeight.w800,
                                      color: kLoginBlue,
                                    ),
                                  ),
                                ),
                                SizedBox(height: isVerySmall ? 2 : 4),
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
        ]),
      ),
    );
  }
}

class _LoginOrbitPainter extends CustomPainter {
  _LoginOrbitPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.39;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..color = Colors.white.withOpacity(0.58);

    final accentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..color = kLoginAccentSoft.withOpacity(0.74);

    canvas.drawCircle(center, baseRadius, ringPaint);
    canvas.drawCircle(
      center,
      baseRadius * 1.16,
      ringPaint..color = Colors.white.withOpacity(0.32),
    );

    final rectA = Rect.fromCircle(center: center, radius: baseRadius * 1.16);
    final rectB = Rect.fromCircle(center: center, radius: baseRadius * 0.98);
    canvas.drawArc(rectA, -math.pi * 0.82 + progress * math.pi * 2, math.pi * 0.38, false, accentPaint);
    canvas.drawArc(
      rectB,
      math.pi * 0.18 + progress * math.pi * 2,
      math.pi * 0.24,
      false,
      accentPaint..color = Colors.white.withOpacity(0.66),
    );

    for (int i = 0; i < 4; i++) {
      final radius = i.isEven ? baseRadius * 1.16 : baseRadius;
      final angle = progress * math.pi * 2 + i * math.pi * 0.72;
      final dot = Offset(center.dx + math.cos(angle) * radius, center.dy + math.sin(angle) * radius);
      final dotPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = i.isEven ? kLoginAccentSoft.withOpacity(0.92) : Colors.white.withOpacity(0.85);
      canvas.drawCircle(dot, i.isEven ? 2.6 : 3.2, dotPaint);
      canvas.drawCircle(
        dot,
        i.isEven ? 4.7 : 5.2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = Colors.white.withOpacity(0.50),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LoginOrbitPainter oldDelegate) => oldDelegate.progress != progress;
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